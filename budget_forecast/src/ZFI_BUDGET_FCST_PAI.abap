*================================================================*
*& Technical Consultant  : Hassan Diab (SNAGFREE)----------------*
*================================================================*
*&---------------------------------------------------------------------*
*& Include        : ZFI_BUDGET_FCST_PAI
*& Main Program   : ZFI_BUDGET_FORECAST
*& Package        : <ZFI>
*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : Ahmed Tawfik
*&---------------------------------------------------------------------*
*& Purpose        : Process After Input modules of screen 0100: exit
*&                   handling, header validation, table control
*&                   transfer and the user command dispatcher.
*&---------------------------------------------------------------------*
*& Created By     : Hassan Diab
*& Created On     : 07.10.2026
*& Request No.    : <TBD>
*& Version        : 1.0
*&---------------------------------------------------------------------*
MODULE EXIT_0100 INPUT.

  DATA: LV_YES       TYPE C,
        LV_EXIT_CODE TYPE SY-UCOMM.

  LV_EXIT_CODE = SY-UCOMM.   "the popup below overwrites SY-UCOMM

  CASE LV_EXIT_CODE.
    WHEN 'BACK' OR 'CANCEL' OR 'EXIT'.
      " exit commands skip the field transport, so the last typed values
      " are not in GT_ITEM yet -> always ask while items are editable
      IF GV_STATUS = 'E' AND GV_READONLY IS INITIAL.
        PERFORM CONFIRM USING 'Unsaved data will be lost. Leave anyway?'
                        CHANGING LV_YES.
        IF LV_YES IS INITIAL.
          RETURN.
        ENDIF.
      ENDIF.

      IF LV_EXIT_CODE = 'EXIT'.
        LEAVE PROGRAM.
      ELSE.
        LEAVE TO SCREEN 0.
      ENDIF.
  ENDCASE.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module CHECK_HEADER INPUT
*&  Only while the header is being entered.
*&---------------------------------------------------------------------*
MODULE CHECK_HEADER INPUT.

  CHECK GV_STATUS = 'I'.

  PERFORM VALIDATE_HEADER.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module CT_FCST_MODIFY INPUT
*&  Only the input columns are transported, so the key fields of the
*&  row are never overwritten from the work area.
*&---------------------------------------------------------------------*
MODULE CT_FCST_MODIFY INPUT.

  MODIFY GT_ITEM FROM GS_ITEM INDEX CT_FCST-CURRENT_LINE
         TRANSPORTING BUDGET_YEAR PROJ_NAME PROJ_DESC PRIORITY
                      AMOUNT BUD_TYPE PROJ_TYPE.

ENDMODULE.

MODULE CT_FCST_MARK INPUT.

  MODIFY GT_ITEM FROM GS_ITEM INDEX CT_FCST-CURRENT_LINE
         TRANSPORTING SELECTED.

ENDMODULE.
*&---------------------------------------------------------------------*
*& Module USER_COMMAND_0100 INPUT
*&---------------------------------------------------------------------*
MODULE USER_COMMAND_0100 INPUT.

  CLEAR GV_UCOMM.
  GV_UCOMM = SY-UCOMM.
  CLEAR SY-UCOMM.

  " Enter on the header = proceed to the items
  IF GV_STATUS = 'I' AND ( GV_UCOMM = 'ENTER' OR GV_UCOMM IS INITIAL ).
    GV_UCOMM = 'PROCESS'.
  ENDIF.

  PERFORM DO_CALCULATION.

  CASE GV_UCOMM.

    WHEN 'PROCESS'.
      IF GV_STATUS = 'I'.
        PERFORM PROCESS_HEADER.
      ENDIF.

    WHEN 'OTHER'.
      PERFORM OTHER_FORECAST.

    WHEN 'INSERT_LINE'.
      IF GV_STATUS = 'E' AND GV_READONLY IS INITIAL.
        PERFORM INSERT_ROW.
      ENDIF.

    WHEN 'DELETE_LINE'.
      IF GV_STATUS = 'E' AND GV_READONLY IS INITIAL.
        PERFORM DELETE_ROW.
        PERFORM DO_CALCULATION.
      ENDIF.

    WHEN 'SEL_ALL'.
      PERFORM SELECT_ALL USING 'X'.

    WHEN 'DESEL_ALL'.
      PERFORM SELECT_ALL USING ' '.

    WHEN 'SAVE'.
      CASE GV_MODE.
        WHEN 'C'.
          PERFORM SAVE_FOR_CREATE.
        WHEN 'M'.
          PERFORM SAVE_FOR_CHANGE.
      ENDCASE.

  ENDCASE.

ENDMODULE.
