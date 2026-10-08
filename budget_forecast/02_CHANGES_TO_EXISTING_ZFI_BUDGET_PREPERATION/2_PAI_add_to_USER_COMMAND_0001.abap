*======================================================================*
* CHANGE TO THE EXISTING PROGRAM ZFI_BUDGET_PREPERATION  (manual)
* Include ZFI_BUDGET_PREPER_INCLUDE_PAI, MODULE USER_COMMAND_0001:
*   paste inside CASE GV_UCOMM, right after the branch WHEN 'REPORT_BUD'.
*
* Opens the menu screen 0001 of the new program ZFI_BUD_2YF_ENTRY
* (transaction ZFI_BUD_2YF). No existing logic is changed.
*======================================================================*

    " ---- Budget Forecast (added 08.10.2026) ----
    WHEN 'FCST_MAIN'.
      TRY.
          CALL TRANSACTION 'ZFI_BUD_2YF' WITH AUTHORITY-CHECK.
        CATCH CX_SY_AUTHORIZATION_ERROR.
          MESSAGE 'You are not authorized for transaction ZFI_BUD_2YF'
                  TYPE 'S' DISPLAY LIKE 'E'.
      ENDTRY.
    " ---- END Budget Forecast ----
