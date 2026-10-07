*================================================================*
*& Technical Consultant  : Hassan Diab (SNAGFREE)----------------*
*================================================================*
*&---------------------------------------------------------------------*
*& Include        : ZFI_BUDGET_FCST_PBO
*& Main Program   : ZFI_BUDGET_FORECAST
*& Package        : <ZFI>
*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : Ahmed Tawfik
*&---------------------------------------------------------------------*
*& Purpose        : Process Before Output modules of screen 0100: GUI
*&                   status and title, listbox values, table control
*&                   lines, and the input / display switching between
*&                   header entry, item entry and display only.
*&---------------------------------------------------------------------*
*& Created By     : Hassan Diab
*& Created On     : 07.10.2026
*& Request No.    : <TBD>
*& Version        : 1.0
*&---------------------------------------------------------------------*
MODULE STATUS_0100 OUTPUT.

  DATA LT_EXCL TYPE TABLE OF SY-UCOMM.

  PERFORM INIT_PROGRAM.

  CLEAR LT_EXCL.
  IF GV_STATUS = 'I' OR GV_READONLY = 'X'.
    APPEND 'SAVE' TO LT_EXCL.
  ENDIF.

  SET PF-STATUS 'GUI_0100' EXCLUDING LT_EXCL.

  CASE GV_MODE.
    WHEN 'C'.
      SET TITLEBAR 'TITLE_0100' WITH 'Create'.
    WHEN 'M'.
      IF GV_READONLY = 'X'.
        SET TITLEBAR 'TITLE_0100' WITH 'Display'.
      ELSE.
        SET TITLEBAR 'TITLE_0100' WITH 'Modify'.
      ENDIF.
  ENDCASE.

  PERFORM SET_LISTBOXES.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module SCREEN_EDITS_0100 OUTPUT
*&  Group1 '1' = header fields + "Create/Change Items" button
*&  Group1 '2' = item edit buttons (insert / delete / select)
*&  Group1 '3' = "Other Forecast" button
*&---------------------------------------------------------------------*
MODULE SCREEN_EDITS_0100 OUTPUT.

  LOOP AT SCREEN.
    CASE SCREEN-GROUP1.
      WHEN '1'.
        IF GV_STATUS = 'I'.
          SCREEN-INPUT = 1.
        ELSE.
          SCREEN-INPUT = 0.
        ENDIF.
      WHEN '2'.
        IF GV_STATUS = 'E' AND GV_READONLY IS INITIAL.
          SCREEN-INPUT = 1.
        ELSE.
          SCREEN-INPUT = 0.
        ENDIF.
      WHEN '3'.
        IF GV_STATUS = 'E'.
          SCREEN-INPUT = 1.
        ELSE.
          SCREEN-INPUT = 0.
        ENDIF.
    ENDCASE.
    MODIFY SCREEN.
  ENDLOOP.

ENDMODULE.

MODULE CT_FCST_CHANGE_TC_ATTR OUTPUT.

  DESCRIBE TABLE GT_ITEM LINES CT_FCST-LINES.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module CT_FCST_GET_LINES OUTPUT
*&  Per table control line: number of visible lines, and the row
*&  fields locked when the forecast is display only.
*&---------------------------------------------------------------------*
MODULE CT_FCST_GET_LINES OUTPUT.

  G_CT_FCST_LINES = SY-LOOPC.

  IF GV_STATUS <> 'E' OR GV_READONLY = 'X'.
    LOOP AT SCREEN.
      IF SCREEN-NAME CP 'GS_ITEM-*'.
        SCREEN-INPUT = 0.
        MODIFY SCREEN.
      ENDIF.
    ENDLOOP.
  ENDIF.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module GET_TEXTS OUTPUT
*&---------------------------------------------------------------------*
MODULE GET_TEXTS OUTPUT.

  DATA LV_KOKRS TYPE KOKRS.

  CLEAR GV_KTEXT.
  IF GS_HEAD-KOSTL IS NOT INITIAL AND GS_HEAD-BUKRS IS NOT INITIAL.
    PERFORM GET_KOKRS USING GS_HEAD-BUKRS CHANGING LV_KOKRS.
    SELECT SINGLE LTEXT FROM CSKT INTO GV_KTEXT
      WHERE SPRAS  = SY-LANGU
        AND KOKRS  = LV_KOKRS
        AND KOSTL  = GS_HEAD-KOSTL
        AND DATBI >= SY-DATUM.
  ENDIF.

  PERFORM SET_CHANGES_TEXT.

ENDMODULE.
