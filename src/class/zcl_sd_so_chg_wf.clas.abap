"! <p>SD: Workflow object for the VA02 change approval (TSD CH4323, ch. 6).</p>
"! Key = sales order number. Raised event CHANGE_APPROVAL_REQUIRED starts
"! workflow ZSD_SO_CHG_APPR. All background steps of the workflow call the
"! methods of this class.
CLASS zcl_sd_so_chg_wf DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_workflow.

    EVENTS change_approval_required.

    TYPES tt_level TYPE STANDARD TABLE OF ze_sd_appr_level WITH EMPTY KEY.

    DATA vbeln       TYPE vbak-vbeln          READ-ONLY.
    DATA counter     TYPE ze_sd_appr_counter  READ-ONLY.   " current approval request
    DATA change_text TYPE ze_sd_appr_chg_text READ-ONLY.   " used in work item text
    DATA requester   TYPE xubname             READ-ONLY.   " user who changed the order

    METHODS constructor
      IMPORTING iv_vbeln TYPE vbak-vbeln.

    "! Step 1: cancel older running approval workflows of this order
    METHODS cancel_previous_workflows.

    "! Step 2: approval levels of the order (ZSD_SO_APPR_CFG)
    METHODS get_levels
      EXPORTING et_levels TYPE tt_level
                ev_count  TYPE i.

    "! Loop step: approvers (agents) of the level at position IV_INDEX
    METHODS get_level_agents
      IMPORTING it_levels TYPE tt_level
                iv_index  TYPE i
      EXPORTING ev_level  TYPE ze_sd_appr_level
                et_agents TYPE tswhactor.

    "! Loop step: e-mail to the approvers of the level (Outlook)
    METHODS send_approval_email
      IMPORTING iv_level  TYPE ze_sd_appr_level
                it_agents TYPE tswhactor.

    "! All levels approved: remove delivery block, log, inform requester
    METHODS set_approved
      IMPORTING iv_decided_by TYPE xubname
                iv_level      TYPE ze_sd_appr_level
      RAISING   cx_bo_temporary.

    "! Rejected: keep delivery block, log, inform requester
    METHODS set_rejected
      IMPORTING iv_decided_by TYPE xubname
                iv_level      TYPE ze_sd_appr_level.

    "! No approver maintained: keep delivery block, log, inform requester
    METHODS set_no_approver.

  PRIVATE SECTION.
    DATA ms_lpor TYPE sibflpor.

    METHODS update_log
      IMPORTING iv_status     TYPE ze_sd_appr_status
                iv_decided_by TYPE xubname OPTIONAL
                iv_level      TYPE ze_sd_appr_level OPTIONAL.

    METHODS notify_requester
      IMPORTING iv_subject TYPE so_obj_des
                iv_text    TYPE string.

    METHODS get_email
      IMPORTING iv_user         TYPE xubname
      RETURNING VALUE(rv_email) TYPE ad_smtpadr.

    METHODS send_email
      IMPORTING iv_email   TYPE ad_smtpadr
                iv_subject TYPE so_obj_des
                it_body    TYPE soli_tab.
ENDCLASS.


CLASS zcl_sd_so_chg_wf IMPLEMENTATION.

  METHOD constructor.
    vbeln   = iv_vbeln.
    ms_lpor = VALUE #( instid = iv_vbeln
                       typeid = zcl_sd_so_chg_monitor=>gc_wf_objtype
                       catid  = 'CL' ).

*   Latest approval request of the order
    SELECT counter, change_text, chg_user
      FROM zsd_so_appr_log
      WHERE vbeln = @iv_vbeln
      ORDER BY counter DESCENDING
      INTO (@counter, @change_text, @requester)
      UP TO 1 ROWS.
    ENDSELECT.
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


  METHOD cancel_previous_workflows.
    DATA lt_worklist TYPE STANDARD TABLE OF swr_wihdr.
    DATA lv_rc       TYPE sysubrc.

    CALL FUNCTION 'SAP_WAPI_WORKITEMS_TO_OBJECT'
      EXPORTING
        object_por      = ms_lpor
        top_level_items = abap_true
      TABLES
        worklist        = lt_worklist.

*   Running workflows of this order; the newest one is the current workflow
    DELETE lt_worklist WHERE wi_type <> 'F'
                          OR wi_stat = 'COMPLETED'
                          OR wi_stat = 'CANCELLED'.
    SORT lt_worklist BY wi_id DESCENDING.
    DELETE lt_worklist INDEX 1.

    LOOP AT lt_worklist INTO DATA(ls_wi).
      CALL FUNCTION 'SAP_WAPI_ADM_WORKFLOW_CANCEL'
        EXPORTING
          workitem_id = ls_wi-wi_id
        IMPORTING
          return_code = lv_rc.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_levels.
    CLEAR: et_levels, ev_count.

    SELECT SINGLE vkorg, auart FROM vbak
      WHERE vbeln = @vbeln
      INTO @DATA(ls_vbak).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SELECT DISTINCT appr_lvl FROM zsd_so_appr_cfg
      WHERE vkorg  = @ls_vbak-vkorg
        AND auart  = @ls_vbak-auart
        AND active = @abap_true
      ORDER BY appr_lvl
      INTO TABLE @et_levels.

    ev_count = lines( et_levels ).
  ENDMETHOD.


  METHOD get_level_agents.
    CLEAR: ev_level, et_agents.

    READ TABLE it_levels INDEX iv_index INTO ev_level.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SELECT SINGLE vkorg, auart FROM vbak
      WHERE vbeln = @vbeln
      INTO @DATA(ls_vbak).

    SELECT approver FROM zsd_so_appr_cfg
      WHERE vkorg    = @ls_vbak-vkorg
        AND auart    = @ls_vbak-auart
        AND appr_lvl = @ev_level
        AND active   = @abap_true
      INTO TABLE @DATA(lt_approvers).

    et_agents = VALUE #( FOR ls_appr IN lt_approvers
                         ( otype = 'US' objid = ls_appr-approver ) ).
  ENDMETHOD.


  METHOD send_approval_email.
    SELECT SINGLE low FROM tvarvc
      WHERE name = 'ZSD_SO_APPR_INBOX_URL'
        AND type = 'P'
      INTO @DATA(lv_url).

    SELECT SINGLE vkorg, auart FROM vbak
      WHERE vbeln = @vbeln
      INTO @DATA(ls_vbak).

    DATA(lv_subject) = CONV so_obj_des( |Approval required: Sales Order { vbeln ALPHA = OUT }| ).

    DATA(lt_body) = VALUE soli_tab(
      ( line = |<p>Dear approver,</p>| )
      ( line = |<p>Sales order <b>{ vbeln ALPHA = OUT }</b> was changed by { requester }| )
      ( line = | and needs your approval (level { iv_level }).</p>| )
      ( line = |<p>Changes:</p><p>| )
      ( line = change_text )
      ( line = |</p><p>The order has delivery block { zcl_sd_so_chg_monitor=>gc_block } until it is approved.</p>| )
      ( line = |<p>Please approve or reject the work item in your Fiori inbox:</p>| )
      ( line = |<p><a href="{ lv_url }">My Inbox</a></p>| ) ).

    LOOP AT it_agents INTO DATA(ls_agent).
*     E-mail from the approver table, otherwise from the user master (SU01)
      SELECT SINGLE email FROM zsd_so_appr_cfg
        WHERE vkorg    = @ls_vbak-vkorg
          AND auart    = @ls_vbak-auart
          AND appr_lvl = @iv_level
          AND approver = @ls_agent-objid
        INTO @DATA(lv_email).
      IF lv_email IS INITIAL.
        lv_email = get_email( CONV #( ls_agent-objid ) ).
      ENDIF.
      IF lv_email IS NOT INITIAL.
        send_email( iv_email = lv_email iv_subject = lv_subject it_body = lt_body ).
      ENDIF.
      CLEAR lv_email.
    ENDLOOP.
  ENDMETHOD.


  METHOD set_approved.
    DATA ls_header_in  TYPE bapisdh1.
    DATA ls_header_inx TYPE bapisdh1x.
    DATA lt_return     TYPE STANDARD TABLE OF bapiret2.

*   Status first: the save of the BAPI below must not see a pending approval
    update_log( iv_status = zcl_sd_so_chg_monitor=>gc_status-approved
                iv_decided_by = iv_decided_by
                iv_level      = iv_level ).

    ls_header_in-dlv_block    = space.
    ls_header_inx-updateflag  = 'U'.
    ls_header_inx-dlv_block   = abap_true.

    CALL FUNCTION 'BAPI_SALESORDER_CHANGE'
      EXPORTING
        salesdocument    = vbeln
        order_header_in  = ls_header_in
        order_header_inx = ls_header_inx
      TABLES
        return           = lt_return.

    IF line_exists( lt_return[ type = 'E' ] ) OR line_exists( lt_return[ type = 'A' ] ).
*     e.g. order locked by a user: temporary error, the workflow retries
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      RAISE EXCEPTION TYPE cx_bo_temporary.
    ENDIF.
*   COMMIT WORK is done by the workflow runtime after the background step

    notify_requester(
      iv_subject = CONV #( |Sales Order { vbeln ALPHA = OUT } approved| )
      iv_text    = |Your change of sales order { vbeln ALPHA = OUT } was approved by { iv_decided_by }. | &&
                   |Delivery block { zcl_sd_so_chg_monitor=>gc_block } was removed.| ).
  ENDMETHOD.


  METHOD set_rejected.
    update_log( iv_status     = zcl_sd_so_chg_monitor=>gc_status-rejected
                iv_decided_by = iv_decided_by
                iv_level      = iv_level ).

    notify_requester(
      iv_subject = CONV #( |Sales Order { vbeln ALPHA = OUT } rejected| )
      iv_text    = |Your change of sales order { vbeln ALPHA = OUT } was rejected by { iv_decided_by } | &&
                   |(level { iv_level }). Delivery block { zcl_sd_so_chg_monitor=>gc_block } remains.| ).
  ENDMETHOD.


  METHOD set_no_approver.
    update_log( iv_status = zcl_sd_so_chg_monitor=>gc_status-no_approver ).

    notify_requester(
      iv_subject = CONV #( |Sales Order { vbeln ALPHA = OUT }: no approver| )
      iv_text    = |No approver is maintained in ZSD_SO_APPR_CFG for sales order { vbeln ALPHA = OUT }. | &&
                   |Delivery block { zcl_sd_so_chg_monitor=>gc_block } remains.| ).
  ENDMETHOD.


  METHOD update_log.
    UPDATE zsd_so_appr_log
      SET status       = @iv_status,
          decided_by   = @iv_decided_by,
          decided_date = @sy-datum,
          decided_time = @sy-uzeit,
          appr_lvl     = @iv_level
      WHERE vbeln   = @vbeln
        AND counter = @counter.
  ENDMETHOD.


  METHOD notify_requester.
    DATA(lv_email) = get_email( requester ).
    IF lv_email IS INITIAL.
      RETURN.
    ENDIF.

    send_email( iv_email   = lv_email
                iv_subject = iv_subject
                it_body    = VALUE #( ( line = |<p>{ iv_text }</p>| ) ) ).
  ENDMETHOD.


  METHOD get_email.
    DATA ls_address TYPE bapiaddr3.
    DATA lt_return  TYPE STANDARD TABLE OF bapiret2.

    CALL FUNCTION 'BAPI_USER_GET_DETAIL'
      EXPORTING
        username = iv_user
      IMPORTING
        address  = ls_address
      TABLES
        return   = lt_return.

    rv_email = ls_address-e_mail.
  ENDMETHOD.


  METHOD send_email.
    TRY.
        DATA(lo_request) = cl_bcs=>create_persistent( ).
        lo_request->set_document( cl_document_bcs=>create_document(
                                    i_type    = 'HTM'
                                    i_text    = it_body
                                    i_subject = iv_subject ) ).
        lo_request->add_recipient( cl_cam_address_bcs=>create_internet_address( iv_email ) ).
        lo_request->set_send_immediately( abap_true ).
        lo_request->send( ).
*       Sent with the COMMIT WORK of the workflow runtime (check in SOST)
      CATCH cx_bcs.
*       E-mail errors must not stop the approval; visible in SOST / WF log
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
