*&---------------------------------------------------------------------*
*& Include LV69AFZZ - FORM USEREXIT_FIELD_MODIFICATION   (optional)
*& Locks the agreed copied price on the item condition screen in VA01
*& (TSD 3.2 "Net Value / agreed copied price-related data").
*& VBAK is not available in SAPLV69A, so the result buffered by
*& USEREXIT_FIELD_MODIFICATION in MV45AFZZ is reused. That form runs on
*& the overview PBO of every order before the conditions can be opened,
*& so the buffer always belongs to the current document.
*&---------------------------------------------------------------------*
ENHANCEMENT 1 zsd_so_con_price_lock.

  IF sy-tcode = 'VA01'
     AND zcl_sd_so_contract_ctrl=>is_current_doc_relevant( ) = abap_true.
    CASE screen-name.
      WHEN 'KOMV-KBETR' OR 'KOMV-KPEIN' OR 'KOMV-KMEIN'.
        screen-input = '0'.
        MODIFY SCREEN.
    ENDCASE.
  ENDIF.

ENDENHANCEMENT.
