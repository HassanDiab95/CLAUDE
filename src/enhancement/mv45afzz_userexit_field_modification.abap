*&---------------------------------------------------------------------*
*& Include MV45AFZZ - FORM USEREXIT_FIELD_MODIFICATION
*& Implicit enhancement at the start of the FORM (replaces the test
*& coding with the hard-coded COBL-PRCTR / sy-tcode check).
*&
*& Logic (TSD CH4323, 3.1 / 3.2):
*&   - Sales order in create mode (VA01)
*&   - VBAK-VGBEL is not initial and VBAK-VGTYP = 'G' (ref. to contract)
*&   - Active filter lines of process VA01 in ZSD_SO_CON_FLT whose ranges
*&       contain VKORG / VTWEG / SPART / AUART_SO (= VBAK-AUART)
*&       / AUART_CON (= VBAK-AUART of the referenced contract)
*&       (a field without lines is not restricted)
*&   => close Material / Quantity / Net value fields for input
*& VA02: while the order is in the approval cycle (workflow log status P)
*&   the whole order is closed for change (all fields display-only,
*&   delivery block included).
*&   After a rejection the order is open for change again, but the
*&   delivery block VBAK-LIFSK stays closed until a new change is approved.
*&---------------------------------------------------------------------*
ENHANCEMENT 1 ZSD_SO_CON_FIELD_LOCK.    "active version
*
  CONSTANTS LC_ZZ_OFF TYPE C LENGTH 1 VALUE '0'.

  CASE T180-TRTYP.
    WHEN 'H'.                                                 " create (VA01)
      IF  ZCL_SD_SO_CONTRACT_CTRL=>IS_LOCKED_FIELD( SCREEN-NAME ) = ABAP_TRUE
      AND VBAK-VGBEL IS NOT INITIAL
      AND VBAK-VGTYP = ZCL_SD_SO_CONTRACT_CTRL=>GC_VGTYP_CONTRACT
      AND ZCL_SD_SO_CONTRACT_CTRL=>IS_RELEVANT(
            IS_VBAK    = VBAK
            IV_PROCESS = ZCL_SD_SO_CONTRACT_CTRL=>GC_PROCESS-CREATE ) = ABAP_TRUE.
        SCREEN-INPUT = LC_ZZ_OFF.
        MODIFY SCREEN.
      ENDIF.
    WHEN 'V'.                                                 " change (VA02)
      IF SCREEN-INPUT = '1'.
        IF ZCL_SD_SO_CHG_MONITOR=>IS_APPROVAL_PENDING( VBAK-VBELN ) = ABAP_TRUE.
          " in approval: whole order closed
          SCREEN-INPUT = LC_ZZ_OFF.
          MODIFY SCREEN.
        ELSEIF SCREEN-NAME = 'VBAK-LIFSK'
           AND ZCL_SD_SO_CHG_MONITOR=>IS_BLOCK_KEPT( VBAK-VBELN ) = ABAP_TRUE.
          " rejected: order open, delivery block stays
          SCREEN-INPUT = LC_ZZ_OFF.
          MODIFY SCREEN.
        ENDIF.
      ENDIF.
  ENDCASE.

ENDENHANCEMENT.
