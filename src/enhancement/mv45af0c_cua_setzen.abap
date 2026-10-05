*&---------------------------------------------------------------------*
*& SAPMV45A - FORM CUA_SETZEN   (include MV45AF0C_CUA_SETZEN)
*& Implicit enhancement at the END of the FORM.
*&
*& Removes the item functions "Insert Row" (POAN) and "Delete Item"
*& (POLO) from the GUI status in VA01 for relevant orders, like VA03
*& (codes in ZCL_SD_SO_CONTRACT_CTRL=>GC_FCODE).
*& Excluded function codes also make the matching pushbuttons above the
*& item table inactive (greyed out) and remove the menu entries.
*&
*& CUA_EXCLUDE is the exclusion table that SAPMV45A passes to
*& SET PF-STATUS ... EXCLUDING. Check the name in your release:
*& in the debugger, set a breakpoint on statement SET PF-STATUS.
*&---------------------------------------------------------------------*
ENHANCEMENT 1 zsd_so_con_item_fcodes.

  IF t180-trtyp = 'H'                                         " create (VA01)
     AND vbak-vgbel IS NOT INITIAL
     AND vbak-vgtyp = zcl_sd_so_contract_ctrl=>gc_vgtyp_contract
     AND zcl_sd_so_contract_ctrl=>is_relevant(
           is_vbak    = vbak
           iv_process = zcl_sd_so_contract_ctrl=>gc_process-create ) = abap_true.

    DATA(lt_zz_fcodes) = zcl_sd_so_contract_ctrl=>get_locked_fcodes( ).
    LOOP AT lt_zz_fcodes INTO DATA(lv_zz_fcode).
      cua_exclude = lv_zz_fcode.
      COLLECT cua_exclude.
    ENDLOOP.
  ENDIF.

ENDENHANCEMENT.
