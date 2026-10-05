*&---------------------------------------------------------------------*
*& SAPMV45A - FORM that calls the item configuration (characteristic
*& value assignment). Two implicit enhancements in the SAME FORM:
*&   Enhancement 1 at the START of the FORM
*&   Enhancement 2 at the END of the FORM
*&
*& Opens the characteristic value assignment in DISPLAY mode in VA01 for
*& orders with reference to a contract that match the VA01 filter, like
*& VA03: all characteristic values are closed for input.
*&
*& How it works: SAPMV45A decides between change and display mode of
*& the configuration from the transaction type T180-TRTYP ('A' =
*& display). It is set to 'A' only while the configuration is called and
*& restored afterwards. USEREXIT_FIELD_MODIFICATION restores it as well
*& (safety net if the FORM is left early with EXIT/RETURN).
*&
*& Find the FORM: VA01 > select item > /h > open the item configuration.
*& In the debugger set a breakpoint on function module CE_C_PROCESSING,
*& continue (F8), then look at the call stack: the SAPMV45A FORM one
*& level above the function module is the FORM to enhance.
*&---------------------------------------------------------------------*

*--- Enhancement 1: START of the FORM ---------------------------------*
ENHANCEMENT 1 zsd_so_con_config_display.

  zcl_sd_so_contract_ctrl=>config_display_on(
    EXPORTING is_vbak  = vbak
    CHANGING  cv_trtyp = t180-trtyp ).

ENDENHANCEMENT.


*--- Enhancement 2: END of the same FORM ------------------------------*
ENHANCEMENT 2 zsd_so_con_config_display.

  zcl_sd_so_contract_ctrl=>config_display_off(
    CHANGING cv_trtyp = t180-trtyp ).

ENDENHANCEMENT.
