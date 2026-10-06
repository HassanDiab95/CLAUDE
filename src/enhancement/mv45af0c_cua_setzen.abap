*&---------------------------------------------------------------------*
*& SAPMV45A - FORM CUA_SETZEN   (include MV45AF0C_CUA_SETZEN)
*& Implicit enhancement at the END of the FORM.
*&
*& Removes the item functions "Insert Row" (POAN) and "Delete Item"
*& (POLO) from the GUI status in VA01 for relevant orders, like VA03
*& (codes in ZCL_SD_SO_CONTRACT_CTRL=>GC_FCODE), and in VA02 while the
*& order is in the approval cycle.
*& Excluded function codes also make the matching pushbuttons above the
*& item table inactive (greyed out) and remove the menu entries.
*&
*& CUA_EXCLUDE is the exclusion table that SAPMV45A passes to
*& SET PF-STATUS ... EXCLUDING. Check the name in your release:
*& in the debugger, set a breakpoint on statement SET PF-STATUS.
*&---------------------------------------------------------------------*
ENHANCEMENT 1 ZSD_SO_CON_ITEM_FCODES.    "active version
*
  DATA LV_ZZ_LOCK TYPE ABAP_BOOL.

  CLEAR LV_ZZ_LOCK.

  CASE T180-TRTYP.
    WHEN 'H'.                                                 " create (VA01)
      IF  VBAK-VGBEL IS NOT INITIAL
      AND VBAK-VGTYP = ZCL_SD_SO_CONTRACT_CTRL=>GC_VGTYP_CONTRACT
      AND ZCL_SD_SO_CONTRACT_CTRL=>IS_RELEVANT(
            IS_VBAK    = VBAK
            IV_PROCESS = ZCL_SD_SO_CONTRACT_CTRL=>GC_PROCESS-CREATE ) = ABAP_TRUE.
        LV_ZZ_LOCK = ABAP_TRUE.
      ENDIF.
    WHEN 'V'.                                                 " change (VA02)
      IF ZCL_SD_SO_CHG_MONITOR=>IS_APPROVAL_PENDING( VBAK-VBELN ) = ABAP_TRUE.
        LV_ZZ_LOCK = ABAP_TRUE.
      ENDIF.
  ENDCASE.

  IF LV_ZZ_LOCK = ABAP_TRUE.
    DATA(LT_ZZ_FCODES) = ZCL_SD_SO_CONTRACT_CTRL=>GET_LOCKED_FCODES( ).
    LOOP AT LT_ZZ_FCODES INTO DATA(LV_ZZ_FCODE).
      CUA_EXCLUDE = LV_ZZ_FCODE.
      COLLECT CUA_EXCLUDE.
    ENDLOOP.
  ENDIF.

ENDENHANCEMENT.
