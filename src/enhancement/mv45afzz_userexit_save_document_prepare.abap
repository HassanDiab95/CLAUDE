*&---------------------------------------------------------------------*
*& Include MV45AFZZ - FORM USEREXIT_SAVE_DOCUMENT_PREPARE   (safety net)
*& Implicit enhancement at the start of the FORM.
*&
*& VA01, relevant orders only: the characteristic values of every item
*& configuration must be the same as in the referenced contract item.
*& If not, the save is cancelled and the user returns to the order.
*& This covers every way of changing the configuration (configuration
*& screen, item detail, BAPI/IDoc using the dialog).
*&---------------------------------------------------------------------*
ENHANCEMENT 1 zsd_so_con_config_check.

  IF t180-trtyp = 'H'                                         " create (VA01)
     AND vbak-vgbel IS NOT INITIAL
     AND vbak-vgtyp = zcl_sd_so_contract_ctrl=>gc_vgtyp_contract
     AND zcl_sd_so_contract_ctrl=>is_relevant(
           is_vbak    = vbak
           iv_process = zcl_sd_so_contract_ctrl=>gc_process-create ) = abap_true.

    LOOP AT xvbap WHERE updkz <> 'D'
                    AND cuobj IS NOT INITIAL
                    AND vgbel IS NOT INITIAL.
      IF zcl_sd_so_contract_ctrl=>is_config_changed( iv_cuobj = xvbap-cuobj
                                                     iv_vgbel = xvbap-vgbel
                                                     iv_vgpos = xvbap-vgpos ) = abap_true.
        MESSAGE s398(00) WITH 'Item' xvbap-posnr
                              ': configuration must not differ from contract'
                              xvbap-vgbel DISPLAY LIKE 'E'.
*       Cancel the save and return to the order (standard SAPMV45A pattern)
        PERFORM folge_gleichsetzen(sapfv45k).
        fcode = 'ENT1'.
        SET SCREEN syst-dynnr.
        LEAVE SCREEN.
      ENDIF.
    ENDLOOP.
  ENDIF.

ENDENHANCEMENT.
