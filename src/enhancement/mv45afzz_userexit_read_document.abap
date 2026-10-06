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
*&
*& If the order is in the approval cycle, a dialog user is sent to VA03
*& for the same order. VA02 would keep the order enqueued and the
*& release (BAPI_SALESORDER_CHANGE) of the approver would fail with
*& "Sales document ... is currently being processed by ...".
*& Not for BAPI / batch input / background (e.g. the release step of the
*& workflow itself): there the order must stay in change mode.
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
      IF call_bapi IS INITIAL                                 " not a BAPI
         AND sy-binpt IS INITIAL                              " not batch input
         AND sy-batch IS INITIAL.                             " not background
*       Free the order and open it in display mode (VA03)
        CALL FUNCTION 'DEQUEUE_ALL'.
        SET PARAMETER ID 'AUN' FIELD vbak-vbeln.
        MESSAGE s398(00) WITH 'Order' vbak-vbeln
                              'is in the approval workflow - display only' ''.
        LEAVE TO TRANSACTION 'VA03' AND SKIP FIRST SCREEN.
      ENDIF.
*     Fallback: all fields stay closed (USEREXIT_FIELD_MODIFICATION)
      MESSAGE s398(00) WITH 'Order' vbak-vbeln
                            'is in the approval workflow - display only' ''.
    ELSEIF zcl_sd_so_chg_monitor=>is_block_kept( vbak-vbeln ) = abap_true.
      MESSAGE s398(00) WITH 'Change of order' vbak-vbeln
                            'was rejected - delivery block stays until'
                            'a new change is approved'.
    ENDIF.
  ENDIF.

ENDENHANCEMENT.
