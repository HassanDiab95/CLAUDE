"! <p class="shorttext synchronized">Budget Forecast - persistence and master data access</p>
"! The repository never commits; the business object owns the LUW.
INTERFACE zif_fi_bud_fcst_repository PUBLIC.

  "! Company code exists (released CDS view I_CompanyCode)
  METHODS company_exists
    IMPORTING iv_bukrs         TYPE bukrs
    RETURNING VALUE(rv_exists) TYPE abap_bool.

  "! Controlling area of the company code (I_CompanyCode)
  METHODS get_controlling_area
    IMPORTING iv_bukrs        TYPE bukrs
    RETURNING VALUE(rv_kokrs) TYPE kokrs.

  "! Cost center valid on the date (released CDS view I_CostCenter)
  METHODS cost_center_exists
    IMPORTING iv_bukrs         TYPE bukrs
              iv_kostl         TYPE kostl
              iv_date          TYPE d
    RETURNING VALUE(rv_exists) TYPE abap_bool.

  "! Cost center description (released CDS view I_CostCenterText)
  METHODS get_cost_center_text
    IMPORTING iv_bukrs       TYPE bukrs
              iv_kostl       TYPE kostl
    RETURNING VALUE(rv_text) TYPE kltxt.

  METHODS read_header
    IMPORTING is_key           TYPE zif_fi_bud_fcst_types=>ty_key
    RETURNING VALUE(rs_header) TYPE zif_fi_bud_fcst_types=>ty_header
    RAISING   zcx_fi_bud_fcst.

  "! Creator of the forecast, initial if it does not exist
  METHODS get_creator
    IMPORTING is_key            TYPE zif_fi_bud_fcst_types=>ty_key
    RETURNING VALUE(rv_creator) TYPE ernam.

  METHODS read_items
    IMPORTING is_key          TYPE zif_fi_bud_fcst_types=>ty_key
    RETURNING VALUE(rt_items) TYPE zif_fi_bud_fcst_types=>tt_items.

  METHODS read_change_log
    IMPORTING is_key        TYPE zif_fi_bud_fcst_types=>ty_key
    RETURNING VALUE(rt_log) TYPE zif_fi_bud_fcst_types=>tt_log.

  "! Forecast years of the forecasts a user created (modify listbox)
  METHODS read_user_forecast_years
    IMPORTING iv_user         TYPE syuname
    RETURNING VALUE(rt_years) TYPE zif_fi_bud_fcst_types=>tt_years.

  METHODS user_has_forecast
    IMPORTING iv_user          TYPE syuname
    RETURNING VALUE(rv_result) TYPE abap_bool.

  "! Insert a new forecast. Duplicate key -> message 006
  METHODS insert_forecast
    IMPORTING is_header TYPE zif_fi_bud_fcst_types=>ty_header
              it_items  TYPE zif_fi_bud_fcst_types=>tt_items
    RAISING   zcx_fi_bud_fcst.

  "! Update a forecast with optimistic locking on CHANGE_COUNT and
  "! write its change log. Changed in between -> message 015
  METHODS update_forecast
    IMPORTING is_header           TYPE zif_fi_bud_fcst_types=>ty_header
              iv_old_change_count TYPE zfcst_change_cnt
              it_items            TYPE zif_fi_bud_fcst_types=>tt_items
              it_log              TYPE zif_fi_bud_fcst_types=>tt_log
    RAISING   zcx_fi_bud_fcst.

ENDINTERFACE.
