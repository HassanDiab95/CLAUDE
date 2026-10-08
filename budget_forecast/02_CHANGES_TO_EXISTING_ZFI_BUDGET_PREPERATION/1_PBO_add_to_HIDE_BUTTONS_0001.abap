*======================================================================*
* CHANGE TO THE EXISTING PROGRAM ZFI_BUDGET_PREPERATION  (manual)
* Include ZFI_BUDGET_PREPER_INCLUDE_PBO, MODULE HIDE_BUTTONS_0001:
*   paste just BEFORE the ENDMODULE of HIDE_BUTTONS_0001.
*
* Shows the single "Budget Forecast" button only to users who can use
* the new Budget Forecast (creator, user with own forecasts, Final
* Reviewer or assistant). The role-based buttons are on the menu
* screen 0001 of the new program ZFI_BUD_2YF_ENTRY.
*======================================================================*

  " ---- Budget Forecast button (added 08.10.2026) ----
  DATA(lo_fcst_auth) = CAST zif_fi_bud_2yf_auth( NEW zcl_fi_bud_2yf_auth( ) ).
  DATA(lo_fcst_repo) = CAST zif_fi_bud_2yf_repository( NEW zcl_fi_bud_2yf_repository( ) ).

  DATA(lv_show_fcst) = xsdbool( lo_fcst_auth->is_creator( ) = abap_true
                             OR lo_fcst_auth->is_final_reviewer( ) = abap_true
                             OR lo_fcst_repo->user_has_forecast( sy-uname ) = abap_true ).

  IF lv_show_fcst = abap_false.
    LOOP AT SCREEN INTO DATA(ls_fcst_screen).
      IF ls_fcst_screen-name = 'FCST_MAIN'.
        ls_fcst_screen-active = '0'.
        MODIFY SCREEN FROM ls_fcst_screen.
      ENDIF.
    ENDLOOP.
  ENDIF.
  " ---- END Budget Forecast ----
