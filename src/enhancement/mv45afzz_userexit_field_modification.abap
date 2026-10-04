*&---------------------------------------------------------------------*
*& Include MV45AFZZ - FORM USEREXIT_FIELD_MODIFICATION
*& Implicit enhancement at the start of the FORM (replaces the test
*& coding with the hard-coded COBL-PRCTR / sy-tcode check).
*&
*& Logic (TSD CH4323, 3.1 / 3.2):
*&   - Sales order in create mode (VA01)
*&   - VBAK-VGBEL is not initial and VBAK-VGTYP = 'G' (ref. to contract)
*&   - Active rule in ZSD_SO_CON_CTRL for
*&       VKORG + VTWEG + SPART + AUART_SO (= VBAK-AUART)
*&       + AUART_CON (= VBAK-AUART of the referenced contract)
*&   => close Material / Quantity / Net value fields for input
*&---------------------------------------------------------------------*
ENHANCEMENT 1 zsd_so_con_field_lock.

  IF t180-trtyp = 'H'                                         " create (VA01)
     AND vbak-vgbel IS NOT INITIAL
     AND vbak-vgtyp = zcl_sd_so_contract_ctrl=>gc_vgtyp_contract
     AND zcl_sd_so_contract_ctrl=>is_relevant( vbak ) = abap_true
     AND zcl_sd_so_contract_ctrl=>is_locked_field( screen-name ) = abap_true.
    screen-input = '0'.
    MODIFY SCREEN.
  ENDIF.

ENDENHANCEMENT.
