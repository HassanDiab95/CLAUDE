"! <p>SD: VA02 change detection for sales orders with reference to a
"! contract (TSD CH4323, chapter 4-6).</p>
"! <ul>
"! <li>TAKE_SNAPSHOT (USEREXIT_READ_DOCUMENT): values when the order is opened</li>
"! <li>DETECT_CHANGES (USEREXIT_SAVE_DOCUMENT_PREPARE): compare with the snapshot</li>
"! <li>START_APPROVAL (USEREXIT_SAVE_DOCUMENT): workflow log (ZCL_SD_SO_CHG_LOG),
"!     old run closed + old workflow cancelled, workflow event raised in the
"!     update task, so the workflow only starts after a successful save</li>
"! <li>IS_APPROVAL_PENDING: order is in the approval cycle -> VA02 locked</li>
"! </ul>
"! Monitored: Material, Quantity, Net value, Net price, VC characteristic
"! values, items added, items deleted.
CLASS zcl_sd_so_chg_monitor DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Header delivery block for pending approval (TSD: final value to be confirmed)
    CONSTANTS gc_block TYPE vbak-lifsk VALUE 'XX'.

    CONSTANTS gc_wf_objtype TYPE sibftypeid VALUE 'ZCL_SD_SO_CHG_WF'.
    CONSTANTS gc_wf_event   TYPE sibfevent  VALUE 'CHANGE_APPROVAL_REQUIRED'.

    TYPES tt_change TYPE STANDARD TABLE OF string WITH EMPTY KEY.

    CLASS-METHODS take_snapshot
      IMPORTING iv_vbeln TYPE vbak-vbeln
                it_xvbap TYPE va_vbapvb_t.

    CLASS-METHODS detect_changes
      IMPORTING iv_vbeln          TYPE vbak-vbeln
                it_xvbap          TYPE va_vbapvb_t
      RETURNING VALUE(rt_changes) TYPE tt_change.

    CLASS-METHODS set_approval_required
      IMPORTING it_changes TYPE tt_change.

    CLASS-METHODS is_approval_required
      RETURNING VALUE(rv_required) TYPE abap_bool.

    CLASS-METHODS start_approval
      IMPORTING is_vbak TYPE vbak.

    CLASS-METHODS is_approval_pending
      IMPORTING iv_vbeln          TYPE vbak-vbeln
      RETURNING VALUE(rv_pending) TYPE abap_bool.

    "! Last approval was rejected: order open for change, but the delivery
    "! block cannot be removed until a new change is approved
    CLASS-METHODS is_block_kept
      IMPORTING iv_vbeln       TYPE vbak-vbeln
      RETURNING VALUE(rv_kept) TYPE abap_bool.

    "! Characteristic values of a configuration as one comparable string
    CLASS-METHODS get_config_values
      IMPORTING iv_cuobj         TYPE vbap-cuobj
      RETURNING VALUE(rv_values) TYPE string.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_snapshot,
        posnr  TYPE vbap-posnr,
        matnr  TYPE vbap-matnr,
        kwmeng TYPE vbap-kwmeng,
        netwr  TYPE vbap-netwr,
        netpr  TYPE vbap-netpr,
        config TYPE string,
      END OF ty_snapshot.

    CLASS-DATA gt_snapshot       TYPE SORTED TABLE OF ty_snapshot WITH UNIQUE KEY posnr.
    CLASS-DATA gv_snapshot_vbeln TYPE vbak-vbeln.
    CLASS-DATA gt_changes        TYPE tt_change.
    CLASS-DATA gv_required       TYPE abap_bool.
    CLASS-DATA gv_pending_vbeln  TYPE vbak-vbeln.
    CLASS-DATA gv_pending        TYPE abap_bool.
    CLASS-DATA gv_block_kept     TYPE abap_bool.

    CLASS-METHODS read_status
      IMPORTING iv_vbeln TYPE vbak-vbeln.
ENDCLASS.


CLASS zcl_sd_so_chg_monitor IMPLEMENTATION.

  METHOD take_snapshot.
    CLEAR: gt_snapshot, gt_changes, gv_required, gv_pending_vbeln, gv_pending, gv_block_kept.
    gv_snapshot_vbeln = iv_vbeln.

    LOOP AT it_xvbap INTO DATA(ls_item).
      INSERT VALUE #( posnr  = ls_item-posnr
                      matnr  = ls_item-matnr
                      kwmeng = ls_item-kwmeng
                      netwr  = ls_item-netwr
                      netpr  = ls_item-netpr
                      config = get_config_values( ls_item-cuobj ) ) INTO TABLE gt_snapshot.
    ENDLOOP.
  ENDMETHOD.


  METHOD detect_changes.
*   Only compare against a snapshot of the same order
    IF iv_vbeln IS INITIAL OR iv_vbeln <> gv_snapshot_vbeln.
      RETURN.
    ENDIF.

    LOOP AT it_xvbap INTO DATA(ls_item).
      DATA(lv_posnr) = |{ ls_item-posnr ALPHA = OUT }|.

      CASE ls_item-updkz.
        WHEN 'D'.
          APPEND |Item { lv_posnr }: deleted| TO rt_changes.
          CONTINUE.
        WHEN 'I'.
          APPEND |Item { lv_posnr }: added (material { ls_item-matnr ALPHA = OUT })| TO rt_changes.
          CONTINUE.
      ENDCASE.

      READ TABLE gt_snapshot INTO DATA(ls_old) WITH TABLE KEY posnr = ls_item-posnr.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      IF ls_item-matnr <> ls_old-matnr.
        APPEND |Item { lv_posnr }: material { ls_old-matnr ALPHA = OUT } -> { ls_item-matnr ALPHA = OUT }| TO rt_changes.
      ENDIF.
      IF ls_item-kwmeng <> ls_old-kwmeng.
        APPEND |Item { lv_posnr }: quantity { ls_old-kwmeng NUMBER = USER } -> { ls_item-kwmeng NUMBER = USER }| TO rt_changes.
      ENDIF.
      IF ls_item-netwr <> ls_old-netwr.
        APPEND |Item { lv_posnr }: net value { ls_old-netwr NUMBER = USER } -> { ls_item-netwr NUMBER = USER }| TO rt_changes.
      ENDIF.
      IF ls_item-netpr <> ls_old-netpr.
        APPEND |Item { lv_posnr }: net price { ls_old-netpr NUMBER = USER } -> { ls_item-netpr NUMBER = USER }| TO rt_changes.
      ENDIF.
      IF ls_item-cuobj IS NOT INITIAL
     AND get_config_values( ls_item-cuobj ) <> ls_old-config.
        APPEND |Item { lv_posnr }: characteristic values changed| TO rt_changes.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD set_approval_required.
    gt_changes  = it_changes.
    gv_required = abap_true.
  ENDMETHOD.


  METHOD is_approval_required.
    rv_required = gv_required.
  ENDMETHOD.


  METHOD start_approval.
    DATA ls_header TYPE zsd_so_chg_lh.
    DATA lo_container TYPE REF TO if_swf_ifs_parameter_container.

    IF gv_required = abap_false OR is_vbak-vbeln IS INITIAL.
      RETURN.
    ENDIF.

    ls_header-vbeln       = is_vbak-vbeln.
    ls_header-contract    = is_vbak-vgbel.
    ls_header-auart       = is_vbak-auart.
    ls_header-vkorg       = is_vbak-vkorg.
    ls_header-vtweg       = is_vbak-vtweg.
    ls_header-spart       = is_vbak-spart.
    ls_header-kunnr       = is_vbak-kunnr.
    ls_header-netwr       = is_vbak-netwr.
    ls_header-waerk       = is_vbak-waerk.
    ls_header-change_text = concat_lines_of( table = gt_changes sep = `; ` ).
    ls_header-trigger_evt = gc_wf_event.
    ls_header-trigger_by  = sy-uname.
    ls_header-trigger_on  = sy-datum.
    ls_header-trigger_at  = sy-uzeit.
    SELECT SINGLE name1 FROM kna1 WHERE kunnr = @is_vbak-kunnr INTO @ls_header-cust_name.

*   New run: header + one level row per approver of ZSD_SO_APPR_CFG
    DATA(lv_log_id) = zcl_sd_so_chg_log=>create_log(
                        is_header   = ls_header
                        it_approver = zcl_sd_so_chg_log=>get_approvers( iv_vkorg = is_vbak-vkorg
                                                                        iv_auart = is_vbak-auart ) ).
    IF lv_log_id IS INITIAL.
      RETURN.
    ENDIF.

*   One CHANGE event per changed field (shown in the e-mail and the log report)
    LOOP AT gt_changes INTO DATA(lv_change).
      zcl_sd_so_chg_log=>add_event( iv_log_id = lv_log_id
                                    iv_event  = zcl_sd_so_chg_log=>gc_event-change
                                    iv_uname  = sy-uname
                                    iv_text   = lv_change ).
    ENDLOOP.

*   Older run still in process (change by BAPI / IDoc while VA02 is locked):
*   close it and cancel (kill) its workflow
    zcl_sd_so_chg_log=>close_previous( iv_vbeln      = is_vbak-vbeln
                                       iv_new_log_id = lv_log_id
                                       iv_user       = sy-uname ).

*   Workflow event with LOG_ID, raised in the update task = only after a
*   successful save. One event per save, however many fields changed.
    TRY.
        lo_container = cl_swf_evt_event=>get_event_container(
                         im_objcateg = cl_swf_evt_event=>mc_objcateg_cl
                         im_objtype  = gc_wf_objtype
                         im_event    = gc_wf_event ).
        lo_container->set( name = 'LOG_ID' value = lv_log_id ).

        cl_swf_evt_event=>raise_in_update_task(
          im_objcateg        = cl_swf_evt_event=>mc_objcateg_cl
          im_objtype         = gc_wf_objtype
          im_event           = gc_wf_event
          im_objkey          = CONV #( is_vbak-vbeln )
          im_event_container = lo_container ).
      CATCH cx_root INTO DATA(lx_event).
        zcl_sd_so_chg_log=>add_event( iv_log_id = lv_log_id
                                      iv_event  = zcl_sd_so_chg_log=>gc_event-error
                                      iv_text   = lx_event->get_text( ) ).
    ENDTRY.

    CLEAR: gt_changes, gv_required.
    gv_pending_vbeln = is_vbak-vbeln.
    gv_pending       = abap_true.
    gv_block_kept    = abap_false.
  ENDMETHOD.


  METHOD is_approval_pending.
    read_status( iv_vbeln ).
    rv_pending = gv_pending.
  ENDMETHOD.


  METHOD is_block_kept.
    read_status( iv_vbeln ).
    rv_kept = gv_block_kept.
  ENDMETHOD.


  METHOD read_status.
*   Buffered per order: called for every screen field in VA02
    IF iv_vbeln IS INITIAL OR iv_vbeln = gv_pending_vbeln.
      RETURN.
    ENDIF.

    gv_pending_vbeln = iv_vbeln.
    gv_pending       = zcl_sd_so_chg_log=>is_running( iv_vbeln ).
    gv_block_kept    = xsdbool( gv_pending = abap_false
                                AND zcl_sd_so_chg_log=>is_rejected( iv_vbeln ) = abap_true ).
  ENDMETHOD.


  METHOD get_config_values.
    DATA lt_conf TYPE STANDARD TABLE OF conf_out.

    IF iv_cuobj IS INITIAL.
      RETURN.
    ENDIF.

    CALL FUNCTION 'VC_I_GET_CONFIGURATION'
      EXPORTING
        instance           = iv_cuobj
        language           = sy-langu
      TABLES
        configuration      = lt_conf
      EXCEPTIONS
        instance_not_found = 1
        internal_error     = 2
        OTHERS             = 3.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SORT lt_conf BY atnam atwrt.
    LOOP AT lt_conf INTO DATA(ls_conf).
      rv_values = |{ rv_values }{ ls_conf-atnam }={ ls_conf-atwrt };|.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
