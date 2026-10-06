*&---------------------------------------------------------------------*
*& Include MV45AFZZ - FORM USEREXIT_READ_DOCUMENT          (VA02)
*& Implicit enhancement at the END of the FORM.
*&
*& Takes a snapshot of the monitored values when the order is opened in
*& change mode: Material, Quantity, Net value, Net price and the
*& characteristic values of each item. USEREXIT_SAVE_DOCUMENT_PREPARE
*& compares against this snapshot.
*& Only for orders with reference to a contract that match the VA02
*& filter (ZSD_SO_CON_FLT, process VA02 or BOTH).
*& If the order is in the approval cycle, the user is told that the order
*& is locked (all fields are closed by USEREXIT_FIELD_MODIFICATION).
*&---------------------------------------------------------------------*
ENHANCEMENT 1 zsd_so_chg_snapshot.

  IF t180-trtyp = 'V'                                         " change (VA02)
     AND vbak-vgbel IS NOT INITIAL
     AND vbak-vgtyp = zcl_sd_so_contract_ctrl=>gc_vgtyp_contract
     AND zcl_sd_so_contract_ctrl=>is_relevant(
           is_vbak    = vbak
           iv_process = zcl_sd_so_contract_ctrl=>gc_process-change ) = abap_true.
    zcl_sd_so_chg_monitor=>take_snapshot( iv_vbeln = vbak-vbeln
                                          it_xvbap = xvbap[] ).

    IF zcl_sd_so_chg_monitor=>is_approval_pending( vbak-vbeln ) = abap_true.
      MESSAGE s398(00) WITH 'Order' vbak-vbeln
                            'is in the approval workflow - display only' ''.
    ENDIF.
  ENDIF.

ENDENHANCEMENT.
