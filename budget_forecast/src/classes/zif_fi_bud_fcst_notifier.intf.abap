"! <p class="shorttext synchronized">Budget Forecast - e-mail notification</p>
INTERFACE zif_fi_bud_fcst_notifier PUBLIC.

  "! Notify all Final Reviewers and assistants about a created /
  "! changed forecast. Commits the send request itself.
  "! @parameter rv_error | Error text, initial when sent
  METHODS notify
    IMPORTING is_header           TYPE zif_fi_bud_fcst_types=>ty_header
              iv_mode             TYPE zif_fi_bud_fcst_types=>ty_mode
              iv_item_count       TYPE i
              iv_cost_center_text TYPE kltxt
    RETURNING VALUE(rv_error)     TYPE string.

ENDINTERFACE.
