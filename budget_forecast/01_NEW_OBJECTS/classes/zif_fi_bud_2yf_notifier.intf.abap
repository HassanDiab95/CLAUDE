"! <p class="shorttext synchronized">Budget Forecast - e-mail notification</p>
INTERFACE zif_fi_bud_2yf_notifier PUBLIC.

  "! Notify all Final Reviewers and assistants about a created /
  "! changed forecast (with the changed values, if IT_LOG is passed).
  "! Commits the send request itself.
  "! @parameter rv_error | Error text, initial when sent
  METHODS notify
    IMPORTING is_header           TYPE zif_fi_bud_2yf_types=>ty_header
              iv_mode             TYPE zif_fi_bud_2yf_types=>ty_mode
              iv_item_count       TYPE i
              iv_cost_center_text TYPE kltxt
              it_log              TYPE zif_fi_bud_2yf_types=>tt_log OPTIONAL
              it_items            TYPE zif_fi_bud_2yf_types=>tt_items OPTIONAL
    RETURNING VALUE(rv_error)     TYPE string.

ENDINTERFACE.
