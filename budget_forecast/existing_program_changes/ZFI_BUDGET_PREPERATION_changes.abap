*======================================================================*
* Budget Forecast - changes to the EXISTING program
* ZFI_BUDGET_PREPERATION (transaction ZFI_BUDGET_PRE)
*
* Only two modules change. Nothing else in the Budget Preparation
* application (workflow, screen 0100, authorization forms) is touched.
*
*   1. ZFI_BUDGET_PREPER_INCLUDE_PBO : MODULE HIDE_BUTTONS_0001
*        -> add the block marked "Budget Forecast" before ENDMODULE
*   2. ZFI_BUDGET_PREPER_INCLUDE_PAI : MODULE USER_COMMAND_0001
*        -> add the three WHEN branches marked "Budget Forecast"
*   3. Screen 0001 : upload screens/ZFI_BUDGET_PREPERATION_0001.txt
*        (adds frame FCST_FRAME and buttons FCST_CREATE, FCST_CHANGE,
*         FCST_REPORT) or add them by hand in the layout editor.
*
* Also add to the change history header of each include:
*& 1.1 | 07.10.2026 | Hassan Diab   | <TBD>        | Budget Forecast buttons.
*======================================================================*


*----------------------------------------------------------------------*
* 1. ZFI_BUDGET_PREPER_INCLUDE_PBO - MODULE HIDE_BUTTONS_0001
*    Paste this block just before the ENDMODULE of HIDE_BUTTONS_0001
*    (after the existing LOOP AT SCREEN ... ENDLOOP).
*----------------------------------------------------------------------*
  " ---- Budget Forecast buttons (added 07.10.2026) ----
  "  Create Forecast : Budget Preparation creators (create role)
  "  Change Forecast : creators, or a user who already created one
  "  Forecast Report : Final Reviewers and FR assistants
  DATA: LV_SHOW_FCST_CRE TYPE C,
        LV_SHOW_FCST_CHG TYPE C,
        LV_SHOW_FCST_REP TYPE C,
        LV_FCST_OWN      TYPE I.

  CLEAR: LV_SHOW_FCST_CRE, LV_SHOW_FCST_CHG, LV_SHOW_FCST_REP, LV_FCST_OWN.

  IF GV_GLOB_CREATE = 'X'.
    LV_SHOW_FCST_CRE = 'X'.
    LV_SHOW_FCST_CHG = 'X'.
  ELSE.
    SELECT COUNT(*) FROM ZFI_BUD_FCST_H UP TO 1 ROWS
      INTO LV_FCST_OWN
      WHERE ERNAM = SY-UNAME.
    IF LV_FCST_OWN > 0.
      LV_SHOW_FCST_CHG = 'X'.
    ENDIF.
  ENDIF.

  " GV_GLOB_IS_FR is also set for FR assistants (GET_USER_GLOBAL_ROLES)
  IF GV_GLOB_IS_FR = 'X'.
    LV_SHOW_FCST_REP = 'X'.
  ENDIF.

  LOOP AT SCREEN.
    CASE SCREEN-NAME.
      WHEN 'FCST_CREATE'.
        IF LV_SHOW_FCST_CRE <> 'X'.
          SCREEN-ACTIVE = 0. MODIFY SCREEN.
        ENDIF.
      WHEN 'FCST_CHANGE'.
        IF LV_SHOW_FCST_CHG <> 'X'.
          SCREEN-ACTIVE = 0. MODIFY SCREEN.
        ENDIF.
      WHEN 'FCST_REPORT'.
        IF LV_SHOW_FCST_REP <> 'X'.
          SCREEN-ACTIVE = 0. MODIFY SCREEN.
        ENDIF.
    ENDCASE.
  ENDLOOP.
  " ---- END Budget Forecast ----


*----------------------------------------------------------------------*
* 2. ZFI_BUDGET_PREPER_INCLUDE_PAI - MODULE USER_COMMAND_0001
*    Add these branches inside CASE GV_UCOMM, after WHEN 'REPORT_BUD'.
*    The forecast is a separate program and does not use the Budget
*    Preparation workflow; it is only launched from here.
*----------------------------------------------------------------------*
    " ---- Budget Forecast (added 07.10.2026) ----
    WHEN 'FCST_CREATE'.
      TRY.
          CALL TRANSACTION 'ZFI_BUD_FCST_C' WITH AUTHORITY-CHECK.
        CATCH CX_SY_AUTHORIZATION_ERROR.
          MESSAGE 'You are not authorized for transaction ZFI_BUD_FCST_C'
                  TYPE 'S' DISPLAY LIKE 'E'.
      ENDTRY.
    WHEN 'FCST_CHANGE'.
      TRY.
          CALL TRANSACTION 'ZFI_BUD_FCST_M' WITH AUTHORITY-CHECK.
        CATCH CX_SY_AUTHORIZATION_ERROR.
          MESSAGE 'You are not authorized for transaction ZFI_BUD_FCST_M'
                  TYPE 'S' DISPLAY LIKE 'E'.
      ENDTRY.
    WHEN 'FCST_REPORT'.
      TRY.
          CALL TRANSACTION 'ZFI_BUD_FCST_R' WITH AUTHORITY-CHECK.
        CATCH CX_SY_AUTHORIZATION_ERROR.
          MESSAGE 'You are not authorized for transaction ZFI_BUD_FCST_R'
                  TYPE 'S' DISPLAY LIKE 'E'.
      ENDTRY.
    " ---- END Budget Forecast ----


*----------------------------------------------------------------------*
* Resulting MODULE USER_COMMAND_0001 (for reference)
*----------------------------------------------------------------------*
*MODULE USER_COMMAND_0001 INPUT.
*
*  CLEAR GV_UCOMM.
*  GV_UCOMM = SY-UCOMM.
*
*  CLEAR GV_MAIN_PURPOSE.
*
*  CASE GV_UCOMM.
*
*    WHEN 'CREATE_BUD'.
*      ...                                   "unchanged
*    WHEN 'REPORT_BUD'.
*      CALL TRANSACTION 'ZFI_BUDGET_PRE_REP'.
*
*    " ---- Budget Forecast (added 07.10.2026) ----
*    WHEN 'FCST_CREATE'.
*      ...                                   "block above
*    WHEN 'FCST_CHANGE'.
*      ...
*    WHEN 'FCST_REPORT'.
*      ...
*    " ---- END Budget Forecast ----
*
*  ENDCASE.
*
*ENDMODULE.
