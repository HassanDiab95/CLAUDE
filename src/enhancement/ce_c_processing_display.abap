*&---------------------------------------------------------------------*
*& Function module CE_C_PROCESSING (function group CUKO, SAPLCUKO)
*& Implicit enhancement at the START of the function module.
*&
*& Call path in VA01 (item configuration):
*&   SAPMV45A FCODE_POCO -> SAPFV45S CONFIGURATION_FCODE/_PROCESSING
*&   -> FM V45CU_CONFIGURATION -> FM CE_C_PROCESSING (parameter DISPLAY)
*&
*& Sets DISPLAY = 'X' when the configuration is called from a sales order
*& in VA01 (create) with reference to a contract that matches the VA01
*& filter. The characteristic value assignment then opens display-only,
*& as in VA03. Same in VA02 while the order is in the approval cycle.
*& Any other caller (other transactions, other orders) is not affected.
*&
*& The order data is read from SAPMV45A with a dynamic ASSIGN, because
*& the function module has no access to the sales order globals.
*& Requirement: DISPLAY is passed by value (SE37 > CE_C_PROCESSING >
*& Import tab > "Pass Value" ticked). Otherwise the assignment is
*& rejected by the syntax check (see creation guide step 9d).
*&---------------------------------------------------------------------*
ENHANCEMENT 1 ZSD_SO_CON_CONFIG_DISPLAY.    "active version
*
  FIELD-SYMBOLS: <LS_ZZ_VBAK>  TYPE VBAK,
                 <LV_ZZ_TRTYP> TYPE T180-TRTYP.

  DATA LV_ZZ_DISPLAY TYPE ABAP_BOOL.

  CLEAR LV_ZZ_DISPLAY.

  " sales order data (only assigned when called from SAPMV45A)
  ASSIGN ('(SAPMV45A)VBAK')       TO <LS_ZZ_VBAK>.
  ASSIGN ('(SAPMV45A)T180-TRTYP') TO <LV_ZZ_TRTYP>.

  IF <LS_ZZ_VBAK> IS ASSIGNED AND <LV_ZZ_TRTYP> IS ASSIGNED.

    CASE <LV_ZZ_TRTYP>.
      WHEN 'H'.                                               " create (VA01)
        IF  <LS_ZZ_VBAK>-VGBEL IS NOT INITIAL
        AND <LS_ZZ_VBAK>-VGTYP = ZCL_SD_SO_CONTRACT_CTRL=>GC_VGTYP_CONTRACT
        AND ZCL_SD_SO_CONTRACT_CTRL=>IS_RELEVANT(
              IS_VBAK    = <LS_ZZ_VBAK>
              IV_PROCESS = ZCL_SD_SO_CONTRACT_CTRL=>GC_PROCESS-CREATE ) = ABAP_TRUE.
          LV_ZZ_DISPLAY = ABAP_TRUE.
        ENDIF.
      WHEN 'V'.                                               " change (VA02)
        IF ZCL_SD_SO_CHG_MONITOR=>IS_APPROVAL_PENDING( <LS_ZZ_VBAK>-VBELN ) = ABAP_TRUE.
          LV_ZZ_DISPLAY = ABAP_TRUE.
        ENDIF.
    ENDCASE.

  ENDIF.

  IF LV_ZZ_DISPLAY = ABAP_TRUE.
    DISPLAY = ABAP_TRUE.                                      " as VA03
  ENDIF.

ENDENHANCEMENT.
