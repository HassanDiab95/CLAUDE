*&---------------------------------------------------------------------*
*& Include MV45AFZZ - FORM USEREXIT_SAVE_DOCUMENT          (VA02)
*& Implicit enhancement at the START of the FORM.
*&
*& Called during the save, before COMMIT WORK (same LUW as the order):
*&   - creates the workflow log run (ZSD_SO_CHG_LH/LL/LE, status P) with
*&     one CHANGE event per changed field
*&   - closes an older run of the same order (status F) and cancels its
*&     workflow
*&   - raises event CHANGE_APPROVAL_REQUIRED (LOG_ID) of ZCL_SD_SO_CHG_WF
*&     in the update task -> workflow ZSD_SO_CHG_APPR starts only after
*&     the order was saved successfully. One event per save.
*&---------------------------------------------------------------------*
ENHANCEMENT 1 zsd_so_chg_start_wf.

  IF t180-trtyp = 'V'                                         " change (VA02)
     AND zcl_sd_so_chg_monitor=>is_approval_required( ) = abap_true.
    zcl_sd_so_chg_monitor=>start_approval( vbak ).
  ENDIF.

ENDENHANCEMENT.
