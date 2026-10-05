"! <p>SD: VA02 change detection for sales orders with reference to a
"! contract (TSD CH4323, chapter 4-6).</p>
"! <ul>
"! <li>TAKE_SNAPSHOT (USEREXIT_READ_DOCUMENT): values when the order is opened</li>
"! <li>DETECT_CHANGES (USEREXIT_SAVE_DOCUMENT_PREPARE): compare with the snapshot</li>
"! <li>START_APPROVAL (USEREXIT_SAVE_DOCUMENT): log entry + workflow event,
"!     raised in the update task, so the workflow only starts after a
"!     successful save</li>
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

    CONSTANTS:
      BEGIN OF gc_status,
        pending     TYPE ze_sd_appr_status VALUE 'P',
        approved    TYPE ze_sd_appr_status VALUE 'A',
        rejected    TYPE ze_sd_appr_status VALUE 'R',
        cancelled   TYPE ze_sd_appr_status VALUE 'C',   " replaced by a newer change
        no_approver TYPE ze_sd_appr_status VALUE 'E',   " no approver maintained
      END OF gc_status.

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
      IMPORTING iv_vbeln TYPE vbak-vbeln.

    CLASS-METHODS is_approval_pending
      IMPORTING iv_vbeln          TYPE vbak-vbeln
      RETURNING VALUE(rv_pending) TYPE abap_bool.

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
ENDCLASS.


CLASS zcl_sd_so_chg_monitor IMPLEMENTATION.

  METHOD take_snapshot.
    CLEAR: gt_snapshot, gt_changes, gv_required, gv_pending_vbeln, gv_pending.
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
    DATA ls_log TYPE zsd_so_appr_log.

    IF gv_required = abap_false OR iv_vbeln IS INITIAL.
      RETURN.
    ENDIF.

*   A new change replaces an approval that is still pending
    UPDATE zsd_so_appr_log SET status = @gc_status-cancelled
      WHERE vbeln  = @iv_vbeln
        AND status = @gc_status-pending.

    SELECT MAX( counter ) FROM zsd_so_appr_log
      WHERE vbeln = @iv_vbeln
      INTO @DATA(lv_counter).

    ls_log-vbeln       = iv_vbeln.
    ls_log-counter     = lv_counter + 1.
    ls_log-status      = gc_status-pending.
    ls_log-chg_user    = sy-uname.
    ls_log-chg_date    = sy-datum.
    ls_log-chg_time    = sy-uzeit.
    ls_log-change_text = concat_lines_of( table = gt_changes sep = `; ` ).
    INSERT zsd_so_appr_log FROM @ls_log.

*   Workflow event: raised in the update task = only after successful save.
*   One event per save, even if several fields changed.
    TRY.
        cl_swf_evt_event=>raise_in_update_task(
          im_objcateg = cl_swf_evt_event=>mc_objcateg_cl
          im_objtype  = gc_wf_objtype
          im_event    = gc_wf_event
          im_objkey   = CONV #( iv_vbeln ) ).
      CATCH cx_swf_evt_invalid_objtype cx_swf_evt_invalid_event.
*       Block and pending log stay; the WF administrator restarts (SWUE)
    ENDTRY.

    CLEAR: gt_changes, gv_required.
    gv_pending_vbeln = iv_vbeln.
    gv_pending       = abap_true.
  ENDMETHOD.


  METHOD is_approval_pending.
    IF iv_vbeln IS INITIAL.
      RETURN.
    ENDIF.

    IF iv_vbeln <> gv_pending_vbeln.
      gv_pending_vbeln = iv_vbeln.
      SELECT SINGLE @abap_true FROM zsd_so_appr_log
        WHERE vbeln  = @iv_vbeln
          AND status = @gc_status-pending
        INTO @gv_pending.
      IF sy-subrc <> 0.
        gv_pending = abap_false.
      ENDIF.
    ENDIF.

    rv_pending = gv_pending.
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
