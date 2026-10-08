"! <p class="shorttext synchronized">Budget Forecast - authorization (Budget Preparation roles)</p>
INTERFACE zif_fi_bud_fcst_auth PUBLIC.

  "! User holds a Budget Preparation creator role with "create"
  "! (ZBUD_CREATORS) - for the given cost center, or any if initial
  METHODS is_creator
    IMPORTING iv_kostl         TYPE kostl OPTIONAL
    RETURNING VALUE(rv_result) TYPE abap_bool.

  "! User is a Final Reviewer (ZFI_BUD_WF_AGENT level FR) or a
  "! Final Reviewer assistant (ZFIBUD_ASSISTANT)
  METHODS is_final_reviewer
    RETURNING VALUE(rv_result) TYPE abap_bool.

  "! All active Final Reviewers and assistants (e-mail recipients)
  METHODS get_notification_recipients
    RETURNING VALUE(rt_users) TYPE zif_fi_bud_fcst_types=>tt_users.

ENDINTERFACE.
