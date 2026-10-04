*&---------------------------------------------------------------------*
*& Include MV45AFZB - FORM USEREXIT_CHECK_XVBAP_FOR_DELET   (safety net)
*&   FORM userexit_check_xvbap_for_delet USING us_error LIKE ...
*&                                             us_exit  LIKE ...
*& Implicit enhancement at the start of the FORM.
*&
*& Prevents deleting an item in VA01 for relevant orders, in case the
*& deletion is triggered by another function than POLO.
*& US_ERROR = 'X' tells SAPMV45A that the item must not be deleted.
*& Check the template comment of this FORM in your MV45AFZB before use.
*&---------------------------------------------------------------------*
ENHANCEMENT 1 zsd_so_con_no_delete_item.

  IF t180-trtyp = 'H'                                         " create (VA01)
     AND vbak-vgbel IS NOT INITIAL
     AND vbak-vgtyp = zcl_sd_so_contract_ctrl=>gc_vgtyp_contract
     AND zcl_sd_so_contract_ctrl=>is_relevant(
           is_vbak    = vbak
           iv_process = zcl_sd_so_contract_ctrl=>gc_process-create ) = abap_true.
    us_error = 'X'.
    MESSAGE s398(00) WITH 'Items of orders with reference to contract'
                          vbak-vgbel 'cannot be deleted' '' DISPLAY LIKE 'E'.
  ENDIF.

ENDENHANCEMENT.
