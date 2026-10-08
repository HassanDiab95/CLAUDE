*======================================================================*
* CHANGE TO THE EXISTING PROGRAM ZFI_BUDGET_PREPERATION  (manual)
* Include ZFI_BUDGET_PREPER_INCLUDE_PAI, MODULE USER_COMMAND_0001:
*   paste inside CASE GV_UCOMM, right after the branch WHEN 'REPORT_BUD'.
*
* This block only connects screen 0001 to the NEW, separate Budget
* Forecast objects (ZFI_BUD_2YF_*). No existing logic is changed.
*======================================================================*

    " ---- Budget Forecast (added 07.10.2026) ----
    WHEN 'FCST_CREATE'.
      TRY.
          CALL TRANSACTION 'ZFI_BUD_2YF_C' WITH AUTHORITY-CHECK.
        CATCH CX_SY_AUTHORIZATION_ERROR.
          MESSAGE 'You are not authorized for transaction ZFI_BUD_2YF_C'
                  TYPE 'S' DISPLAY LIKE 'E'.
      ENDTRY.
    WHEN 'FCST_CHANGE'.
      TRY.
          CALL TRANSACTION 'ZFI_BUD_2YF_M' WITH AUTHORITY-CHECK.
        CATCH CX_SY_AUTHORIZATION_ERROR.
          MESSAGE 'You are not authorized for transaction ZFI_BUD_2YF_M'
                  TYPE 'S' DISPLAY LIKE 'E'.
      ENDTRY.
    WHEN 'FCST_REPORT'.
      TRY.
          CALL TRANSACTION 'ZFI_BUD_2YF_R' WITH AUTHORITY-CHECK.
        CATCH CX_SY_AUTHORIZATION_ERROR.
          MESSAGE 'You are not authorized for transaction ZFI_BUD_2YF_R'
                  TYPE 'S' DISPLAY LIKE 'E'.
      ENDTRY.
    " ---- END Budget Forecast ----
