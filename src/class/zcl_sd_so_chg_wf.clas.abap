*&---------------------------------------------------------------------*
*& Class          : ZCL_SD_SO_CHG_WF
*& Workflow       : ZSD_SO_CHG_APPR (WS9xxxxxxx)
*& Package        : ZSD
*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : <Functional consultant>
*&---------------------------------------------------------------------*
*& Purpose        : Workflow object (IF_WORKFLOW) of the sales order
*&                  change approval (CH4323). Key = sales order.
*&                  Event CHANGE_APPROVAL_REQUIRED (parameter LOG_ID)
*&                  starts the workflow; every background step calls one
*&                  method of this class.
*& Note           : No COMMIT WORK here; the workflow step commits.
*&---------------------------------------------------------------------*
*& Created By     : Hassan Diab
*& Created On     : 06.10.2026
*& Request No.    : <Request>
*& Version        : 1.0
*&---------------------------------------------------------------------*
*& Change History
*&---------------------------------------------------------------------*
*& Ver | Date       | Author        | Request No.  | Description
*&-----|------------|---------------|--------------|--------------------
*& 1.0 | 06.10.2026 | Hassan Diab   | <Request>    | Initial Creation
*&---------------------------------------------------------------------*
CLASS zcl_sd_so_chg_wf DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_workflow.

    EVENTS change_approval_required
      EXPORTING VALUE(log_id) TYPE sysuuid_c32.

    DATA vbeln TYPE vbak-vbeln READ-ONLY.

    METHODS constructor
      IMPORTING iv_vbeln TYPE vbak-vbeln.

    "! Step 1: store the workflow ID, log START, return the number of levels.
    "! No level maintained -> run ends with status E, order stays blocked.
    METHODS start
      IMPORTING iv_log_id TYPE sysuuid_c32
                iv_wf_id  TYPE sww_wiid OPTIONAL
      EXPORTING ev_levels TYPE i.

    "! Loop step: level at position IV_INDEX -> pending, e-mail to the
    "! approver, agent and HTML description for the decision step
    METHODS prepare_level
      IMPORTING iv_log_id TYPE sysuuid_c32
                iv_index  TYPE i
      EXPORTING ev_level  TYPE zsd_so_level
                et_agents TYPE tswhactor
                et_html   TYPE w3htmltab.

    "! After the user decision: level approved / rejected
    METHODS decide
      IMPORTING iv_log_id     TYPE sysuuid_c32
                iv_level      TYPE zsd_so_level
                iv_approved   TYPE abap_bool
                iv_decided_by TYPE xubname OPTIONAL.

    "! All levels approved: remove delivery block, close run, mail requester
    METHODS finish_approved
      IMPORTING iv_log_id TYPE sysuuid_c32
      RAISING   cx_bo_temporary.

    "! Rejected: order stays blocked, close run, mail requester
    METHODS finish_rejected
      IMPORTING iv_log_id TYPE sysuuid_c32.

  PRIVATE SECTION.
    DATA ms_lpor TYPE sibflpor.

    METHODS find_running_workflow
      RETURNING VALUE(rv_wf_id) TYPE sww_wiid.
ENDCLASS.


CLASS zcl_sd_so_chg_wf IMPLEMENTATION.

  METHOD constructor.
    vbeln   = iv_vbeln.
    ms_lpor = VALUE #( instid = iv_vbeln
                       typeid = zcl_sd_so_chg_monitor=>gc_wf_objtype
                       catid  = 'CL' ).
  ENDMETHOD.


  METHOD bi_persistent~find_by_lpor.
    result = NEW zcl_sd_so_chg_wf( CONV #( lpor-instid ) ).
  ENDMETHOD.


  METHOD bi_persistent~lpor.
    result = ms_lpor.
  ENDMETHOD.


  METHOD bi_persistent~refresh.
  ENDMETHOD.


  METHOD bi_object~default_attribute_value.
    result = REF #( vbeln ).
  ENDMETHOD.


  METHOD bi_object~execute_default_method.
*   Work item "display object": open the order in VA03
    SET PARAMETER ID 'AUN' FIELD vbeln.
    CALL TRANSACTION 'VA03' WITH AUTHORITY-CHECK AND SKIP FIRST SCREEN.
  ENDMETHOD.


  METHOD bi_object~release.
  ENDMETHOD.


  METHOD start.
    CLEAR ev_levels.

    DATA(lv_wf_id) = iv_wf_id.
    IF lv_wf_id IS INITIAL.
      lv_wf_id = find_running_workflow( ).
    ENDIF.
    zcl_sd_so_chg_log=>set_wf_id( iv_log_id = iv_log_id iv_wf_id = lv_wf_id ).

    zcl_sd_so_chg_log=>add_event( iv_log_id = iv_log_id
                                  iv_event  = zcl_sd_so_chg_log=>gc_event-start
                                  iv_text   = |Workflow { lv_wf_id ALPHA = OUT } started| ).

    ev_levels = lines( zcl_sd_so_chg_log=>get_levels( iv_log_id ) ).

    IF ev_levels = 0.
      zcl_sd_so_chg_log=>add_event( iv_log_id = iv_log_id
                                    iv_event  = zcl_sd_so_chg_log=>gc_event-error
                                    iv_text   = 'No approver maintained in ZSD_SO_APPR_CFG - order stays blocked' ).
      zcl_sd_so_chg_log=>finish( iv_log_id = iv_log_id
                                 iv_status = zcl_sd_so_chg_log=>gc_status-error ).
      NEW zcl_sd_so_chg_notify( )->notify_requester( iv_log_id = iv_log_id
                                                      iv_result = zcl_sd_so_chg_log=>gc_status-error ).
    ENDIF.
  ENDMETHOD.


  METHOD prepare_level.
    CLEAR: ev_level, et_agents, et_html.

    DATA(lt_levels) = zcl_sd_so_chg_log=>get_levels( iv_log_id ).
    READ TABLE lt_levels INTO DATA(ls_level) INDEX iv_index.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    ev_level  = ls_level-appr_level.
    et_agents = VALUE #( ( otype = 'US' objid = ls_level-uname ) ).

    zcl_sd_so_chg_log=>set_current_level( iv_log_id = iv_log_id iv_level = ev_level ).
    zcl_sd_so_chg_log=>set_level_status( iv_log_id = iv_log_id
                                         iv_level  = ev_level
                                         iv_status = zcl_sd_so_chg_log=>gc_level-pending ).
    zcl_sd_so_chg_log=>add_event( iv_log_id = iv_log_id
                                  iv_event  = zcl_sd_so_chg_log=>gc_event-level
                                  iv_level  = ev_level
                                  iv_uname  = ls_level-uname
                                  iv_text   = ls_level-full_name ).

*   E-mail (Outlook): work item waiting in Fiori My Inbox
    DATA(lo_notify) = NEW zcl_sd_so_chg_notify( ).
    lo_notify->notify_approver( iv_log_id = iv_log_id
                                iv_level  = ev_level ).

*   Same content as HTML description of the decision work item (My Inbox)
    et_html = lo_notify->build_inbox_html( iv_log_id = iv_log_id
                                           iv_level  = ev_level ).

    zcl_sd_so_chg_log=>add_event( iv_log_id = iv_log_id
                                  iv_event  = zcl_sd_so_chg_log=>gc_event-inbox
                                  iv_level  = ev_level
                                  iv_uname  = ls_level-uname ).
  ENDMETHOD.


  METHOD decide.
    DATA(lv_status) = COND zsd_so_wf_status( WHEN iv_approved = abap_true
                                             THEN zcl_sd_so_chg_log=>gc_level-approved
                                             ELSE zcl_sd_so_chg_log=>gc_level-rejected ).
    DATA(lv_event)  = COND zsd_so_wf_event( WHEN iv_approved = abap_true
                                            THEN zcl_sd_so_chg_log=>gc_event-approve
                                            ELSE zcl_sd_so_chg_log=>gc_event-reject ).

    zcl_sd_so_chg_log=>set_level_status( iv_log_id = iv_log_id
                                         iv_level  = iv_level
                                         iv_status = lv_status
                                         iv_uname  = iv_decided_by ).
    zcl_sd_so_chg_log=>add_event( iv_log_id = iv_log_id
                                  iv_event  = lv_event
                                  iv_level  = iv_level
                                  iv_uname  = iv_decided_by ).
  ENDMETHOD.


  METHOD finish_approved.
    DATA ls_header_in  TYPE bapisdh1.
    DATA ls_header_inx TYPE bapisdh1x.
    DATA lt_return     TYPE STANDARD TABLE OF bapiret2.

*   Sales order of this run: from the log header (independent of the
*   object binding of the workflow step); instance key only as fallback
    DATA(ls_head)  = zcl_sd_so_chg_log=>get_header( iv_log_id ).
    DATA(lv_vbeln) = COND vbak-vbeln( WHEN ls_head-vbeln IS NOT INITIAL
                                      THEN ls_head-vbeln
                                      ELSE vbeln ).
    IF lv_vbeln IS INITIAL.
      zcl_sd_so_chg_log=>add_event( iv_log_id = iv_log_id
                                    iv_event  = zcl_sd_so_chg_log=>gc_event-rel_err
                                    iv_text   = 'Sales order number not found in log header - release not possible' ).
      RETURN.
    ENDIF.

*   Release only after the LAST level: every level of the run must be approved
    DATA(lt_levels) = zcl_sd_so_chg_log=>get_levels( iv_log_id ).
    IF lt_levels IS INITIAL
    OR line_exists( lt_levels[ status = zcl_sd_so_chg_log=>gc_level-waiting ] )
    OR line_exists( lt_levels[ status = zcl_sd_so_chg_log=>gc_level-pending ] )
    OR line_exists( lt_levels[ status = zcl_sd_so_chg_log=>gc_level-rejected ] )
    OR line_exists( lt_levels[ status = zcl_sd_so_chg_log=>gc_level-not_reached ] ).
      zcl_sd_so_chg_log=>add_event( iv_log_id = iv_log_id
                                    iv_event  = zcl_sd_so_chg_log=>gc_event-error
                                    iv_text   = 'Release refused: not all levels approved - order stays blocked' ).
      RETURN.
    ENDIF.

*   Close the run first: the order save of the BAPI below must not see a
*   running approval (otherwise the block would be set again)
    zcl_sd_so_chg_log=>finish( iv_log_id = iv_log_id
                               iv_status = zcl_sd_so_chg_log=>gc_status-approved ).

    ls_header_in-dlv_block   = space.
    ls_header_inx-updateflag = 'U'.
    ls_header_inx-dlv_block  = abap_true.

    CALL FUNCTION 'BAPI_SALESORDER_CHANGE'
      EXPORTING
        salesdocument    = lv_vbeln
        order_header_in  = ls_header_in
        order_header_inx = ls_header_inx
      TABLES
        return           = lt_return.

    LOOP AT lt_return INTO DATA(ls_return) WHERE type CA 'EA'.
      EXIT.
    ENDLOOP.
    IF sy-subrc = 0.
*     e.g. order locked: undo, log, temporary error -> workflow retries
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      zcl_sd_so_chg_log=>add_event( iv_log_id = iv_log_id
                                    iv_event  = zcl_sd_so_chg_log=>gc_event-rel_err
                                    iv_text   = ls_return-message ).
      RAISE EXCEPTION TYPE cx_bo_temporary.
    ENDIF.
*   COMMIT WORK is done by the workflow runtime after the background step

    zcl_sd_so_chg_log=>add_event( iv_log_id = iv_log_id
                                  iv_event  = zcl_sd_so_chg_log=>gc_event-release
                                  iv_text   = |Delivery block { zcl_sd_so_chg_monitor=>gc_block } removed| ).

    NEW zcl_sd_so_chg_notify( )->notify_requester( iv_log_id = iv_log_id
                                                    iv_result = zcl_sd_so_chg_log=>gc_status-approved ).
  ENDMETHOD.


  METHOD finish_rejected.
    zcl_sd_so_chg_log=>add_event( iv_log_id = iv_log_id
                                  iv_event  = zcl_sd_so_chg_log=>gc_event-close
                                  iv_text   = |Delivery block { zcl_sd_so_chg_monitor=>gc_block } remains| ).
    zcl_sd_so_chg_log=>finish( iv_log_id = iv_log_id
                               iv_status = zcl_sd_so_chg_log=>gc_status-rejected ).

    NEW zcl_sd_so_chg_notify( )->notify_requester( iv_log_id = iv_log_id
                                                    iv_result = zcl_sd_so_chg_log=>gc_status-rejected ).
  ENDMETHOD.


  METHOD find_running_workflow.
    DATA lt_worklist TYPE STANDARD TABLE OF swr_wihdr.

*   Newest running top-level workflow of this order = the current one
    CALL FUNCTION 'SAP_WAPI_WORKITEMS_TO_OBJECT'
      EXPORTING
        object_por      = ms_lpor
        top_level_items = abap_true
      TABLES
        worklist        = lt_worklist.

    DELETE lt_worklist WHERE wi_type <> 'F'
                          OR wi_stat = 'COMPLETED'
                          OR wi_stat = 'CANCELLED'.
    SORT lt_worklist BY wi_id DESCENDING.
    READ TABLE lt_worklist INTO DATA(ls_wi) INDEX 1.
    IF sy-subrc = 0.
      rv_wf_id = ls_wi-wi_id.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
