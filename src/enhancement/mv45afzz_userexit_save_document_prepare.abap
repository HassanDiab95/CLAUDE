*&---------------------------------------------------------------------*
*& Include MV45AFZZ - FORM USEREXIT_SAVE_DOCUMENT_PREPARE  (VA02)
*& Implicit enhancement at the START of the FORM.
*&
*& TSD 4.4 / 5:
*&   - Compare the order with the snapshot taken when it was opened.
*&   - At least one monitored change -> header delivery block XX and
*&     "approval required" (one approval per save, however many fields).
*&   - No monitored change but an approval is still pending -> keep the
*&     delivery block (it cannot be removed manually while pending).
*& No error message: the save always goes through.
*&---------------------------------------------------------------------*
ENHANCEMENT 1 zsd_so_chg_detect.

  IF t180-trtyp = 'V'                                         " change (VA02)
     AND vbak-vgbel IS NOT INITIAL
     AND vbak-vgtyp = zcl_sd_so_contract_ctrl=>gc_vgtyp_contract
     AND zcl_sd_so_contract_ctrl=>is_relevant(
           is_vbak    = vbak
           iv_process = zcl_sd_so_contract_ctrl=>gc_process-change ) = abap_true.

    DATA(lt_zz_changes) = zcl_sd_so_chg_monitor=>detect_changes( iv_vbeln = vbak-vbeln
                                                                 it_xvbap = xvbap[] ).
    IF lt_zz_changes IS NOT INITIAL.
      vbak-lifsk = zcl_sd_so_chg_monitor=>gc_block.
      zcl_sd_so_chg_monitor=>set_approval_required( lt_zz_changes ).
    ELSEIF zcl_sd_so_chg_monitor=>is_approval_pending( vbak-vbeln ) = abap_true.
      vbak-lifsk = zcl_sd_so_chg_monitor=>gc_block.
    ENDIF.
  ENDIF.

ENDENHANCEMENT.
