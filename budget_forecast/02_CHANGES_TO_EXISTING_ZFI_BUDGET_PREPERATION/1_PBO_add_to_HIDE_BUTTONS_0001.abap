*======================================================================*
* CHANGE TO THE EXISTING PROGRAM ZFI_BUDGET_PREPERATION  (manual)
* Include ZFI_BUDGET_PREPER_INCLUDE_PBO, MODULE HIDE_BUTTONS_0001:
*   paste just BEFORE the ENDMODULE of HIDE_BUTTONS_0001.
*
* This block only connects screen 0001 to the NEW, separate Budget
* Forecast objects (ZFI_BUD_2YF_*). No existing logic is changed.
*======================================================================*

  " ---- Budget Forecast buttons (added 07.10.2026) ----
  "  Create Forecast : Budget Preparation creators (create role)
  "  Change Forecast : creators, or a user who already created one
  "  Forecast Report : Final Reviewers and FR assistants
  "  The rules are in the Budget Forecast classes, not repeated here.
  DATA(lo_fcst_auth) = CAST zif_fi_bud_2yf_auth( NEW zcl_fi_bud_2yf_auth( ) ).
  DATA(lo_fcst_repo) = CAST zif_fi_bud_2yf_repository( NEW zcl_fi_bud_2yf_repository( ) ).

  DATA(lv_show_fcst_create) = lo_fcst_auth->is_creator( ).
  DATA(lv_show_fcst_change) = xsdbool( lv_show_fcst_create = abap_true
                                    OR lo_fcst_repo->user_has_forecast( sy-uname ) = abap_true ).
  DATA(lv_show_fcst_report) = lo_fcst_auth->is_final_reviewer( ).

  LOOP AT SCREEN INTO DATA(ls_fcst_screen).
    DATA(lv_fcst_visible) = SWITCH abap_bool( ls_fcst_screen-name
                              WHEN 'FCST_CREATE' THEN lv_show_fcst_create
                              WHEN 'FCST_CHANGE' THEN lv_show_fcst_change
                              WHEN 'FCST_REPORT' THEN lv_show_fcst_report
                              ELSE abap_true ).
    IF lv_fcst_visible = abap_false.
      ls_fcst_screen-active = '0'.
      MODIFY SCREEN FROM ls_fcst_screen.
    ENDIF.
  ENDLOOP.
  " ---- END Budget Forecast ----
