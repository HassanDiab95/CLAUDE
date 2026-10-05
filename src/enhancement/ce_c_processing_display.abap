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
*& as in VA03. Any other caller (other transactions, other orders) is
*& not affected.
*&
*& The order data is read from SAPMV45A with a dynamic ASSIGN, because
*& the function module has no access to the sales order globals.
*& Requirement: DISPLAY is passed by value (SE37 > CE_C_PROCESSING >
*& Import tab > "Pass Value" ticked). Otherwise the assignment is
*& rejected by the syntax check (see creation guide step 9d).
*&---------------------------------------------------------------------*
ENHANCEMENT 1 zsd_so_con_config_display.

  FIELD-SYMBOLS <ls_zz_vbak>  TYPE vbak.
  FIELD-SYMBOLS <lv_zz_trtyp> TYPE t180-trtyp.

  ASSIGN ('(SAPMV45A)VBAK')        TO <ls_zz_vbak>.
  ASSIGN ('(SAPMV45A)T180-TRTYP')  TO <lv_zz_trtyp>.

  IF  <ls_zz_vbak>  IS ASSIGNED
  AND <lv_zz_trtyp> IS ASSIGNED
  AND <lv_zz_trtyp> = 'H'                                     " create (VA01)
  AND zcl_sd_so_contract_ctrl=>is_relevant(
        is_vbak    = <ls_zz_vbak>
        iv_process = zcl_sd_so_contract_ctrl=>gc_process-create ) = abap_true.
    display = 'X'.                                            " as VA03
  ENDIF.

ENDENHANCEMENT.
