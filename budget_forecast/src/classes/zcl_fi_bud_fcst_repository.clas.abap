"! <p class="shorttext synchronized">Budget Forecast - persistence and master data access</p>
"! Technical Consultant : Hassan Diab / Functional Consultant : Ahmed Tawfik
"! Created 08.10.2026 - Request <TBD>
"!
"! Clean core: master data is read through the released CDS views
"! I_CompanyCode, I_CostCenter and I_CostCenterText (no direct access
"! to T001 / TKA02 / CSKS / CSKT). Only the custom Z tables are read
"! and written directly.
CLASS zcl_fi_bud_fcst_repository DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_fi_bud_fcst_repository.

  PRIVATE SECTION.
    CLASS-METHODS years_text
      IMPORTING iv_from        TYPE zfcst_year_from
                iv_to          TYPE zfcst_year_to
      RETURNING VALUE(rv_text) TYPE string.

ENDCLASS.



CLASS zcl_fi_bud_fcst_repository IMPLEMENTATION.

  METHOD zif_fi_bud_fcst_repository~company_exists.
    SELECT SINGLE @abap_true
      FROM i_companycode
      WHERE companycode = @iv_bukrs
      INTO @rv_exists.
  ENDMETHOD.


  METHOD zif_fi_bud_fcst_repository~get_controlling_area.
    SELECT SINGLE controllingarea
      FROM i_companycode
      WHERE companycode = @iv_bukrs
      INTO @rv_kokrs.

    " same fallback as ZFI_BUDGET_PREPERATION (KOKRS = BUKRS)
    IF rv_kokrs IS INITIAL.
      rv_kokrs = iv_bukrs.
    ENDIF.
  ENDMETHOD.


  METHOD zif_fi_bud_fcst_repository~cost_center_exists.
    DATA(lv_kokrs) = zif_fi_bud_fcst_repository~get_controlling_area( iv_bukrs ).

    SELECT SINGLE @abap_true
      FROM i_costcenter
      WHERE controllingarea    = @lv_kokrs
        AND costcenter         = @iv_kostl
        AND validitystartdate <= @iv_date
        AND validityenddate   >= @iv_date
      INTO @rv_exists.
  ENDMETHOD.


  METHOD zif_fi_bud_fcst_repository~get_cost_center_text.
    DATA(lv_kokrs) = zif_fi_bud_fcst_repository~get_controlling_area( iv_bukrs ).
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    SELECT SINGLE costcenterdescription
      FROM i_costcentertext
      WHERE controllingarea  = @lv_kokrs
        AND costcenter       = @iv_kostl
        AND language         = @sy-langu
        AND validityenddate >= @lv_today
      INTO @rv_text.
  ENDMETHOD.


  METHOD zif_fi_bud_fcst_repository~read_header.
    SELECT SINGLE *
      FROM zfi_bud_fcst_h
      WHERE bukrs      = @is_key-bukrs
        AND kostl      = @is_key-kostl
        AND fyear_from = @is_key-fyear_from
        AND fyear_to   = @is_key-fyear_to
      INTO @rs_header.

    IF sy-subrc <> 0.
      DATA(lv_years) = years_text( iv_from = is_key-fyear_from iv_to = is_key-fyear_to ).
      RAISE EXCEPTION TYPE zcx_fi_bud_fcst
        MESSAGE e007(zbud_fcst) WITH is_key-bukrs is_key-kostl lv_years.
    ENDIF.
  ENDMETHOD.


  METHOD zif_fi_bud_fcst_repository~get_creator.
    SELECT SINGLE ernam
      FROM zfi_bud_fcst_h
      WHERE bukrs      = @is_key-bukrs
        AND kostl      = @is_key-kostl
        AND fyear_from = @is_key-fyear_from
        AND fyear_to   = @is_key-fyear_to
      INTO @rv_creator.
  ENDMETHOD.


  METHOD zif_fi_bud_fcst_repository~read_items.
    SELECT *
      FROM zfi_bud_fcst_i
      WHERE bukrs      = @is_key-bukrs
        AND kostl      = @is_key-kostl
        AND fyear_from = @is_key-fyear_from
        AND fyear_to   = @is_key-fyear_to
      ORDER BY item_no
      INTO TABLE @rt_items.
  ENDMETHOD.


  METHOD zif_fi_bud_fcst_repository~read_change_log.
    SELECT *
      FROM zfi_bud_fcst_log
      WHERE bukrs      = @is_key-bukrs
        AND kostl      = @is_key-kostl
        AND fyear_from = @is_key-fyear_from
        AND fyear_to   = @is_key-fyear_to
      ORDER BY change_no, log_no
      INTO TABLE @rt_log.
  ENDMETHOD.


  METHOD zif_fi_bud_fcst_repository~read_user_forecast_years.
    SELECT DISTINCT fyear_from, fyear_to
      FROM zfi_bud_fcst_h
      WHERE ernam = @iv_user
      ORDER BY fyear_from DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @rt_years.
  ENDMETHOD.


  METHOD zif_fi_bud_fcst_repository~user_has_forecast.
    SELECT SINGLE @abap_true
      FROM zfi_bud_fcst_h
      WHERE ernam = @iv_user
      INTO @rv_result.
  ENDMETHOD.


  METHOD zif_fi_bud_fcst_repository~insert_forecast.
    " the primary key (BUKRS, KOSTL, FYEAR_FROM, FYEAR_TO) is the final
    " duplicate guard if two creators save the same combination at once
    INSERT zfi_bud_fcst_h FROM @is_header.
    IF sy-subrc <> 0.
      DATA(lv_creator) = zif_fi_bud_fcst_repository~get_creator( CORRESPONDING #( is_header ) ).
      DATA(lv_years)   = years_text( iv_from = is_header-fyear_from iv_to = is_header-fyear_to ).
      RAISE EXCEPTION TYPE zcx_fi_bud_fcst
        MESSAGE e006(zbud_fcst) WITH is_header-bukrs is_header-kostl lv_years lv_creator.
    ENDIF.

    INSERT zfi_bud_fcst_i FROM TABLE @it_items ACCEPTING DUPLICATE KEYS.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_fi_bud_fcst MESSAGE e016(zbud_fcst).
    ENDIF.
  ENDMETHOD.


  METHOD zif_fi_bud_fcst_repository~update_forecast.
    " optimistic lock: only update if nobody saved in between
    UPDATE zfi_bud_fcst_h
       SET change_count = @is_header-change_count,
           total_amount = @is_header-total_amount,
           aenam        = @is_header-aenam,
           aedat        = @is_header-aedat,
           aezet        = @is_header-aezet
     WHERE bukrs        = @is_header-bukrs
       AND kostl        = @is_header-kostl
       AND fyear_from   = @is_header-fyear_from
       AND fyear_to     = @is_header-fyear_to
       AND change_count = @iv_old_change_count.
    IF sy-dbcnt = 0.
      RAISE EXCEPTION TYPE zcx_fi_bud_fcst MESSAGE e015(zbud_fcst).
    ENDIF.

    DELETE FROM zfi_bud_fcst_i
     WHERE bukrs      = @is_header-bukrs
       AND kostl      = @is_header-kostl
       AND fyear_from = @is_header-fyear_from
       AND fyear_to   = @is_header-fyear_to.

    INSERT zfi_bud_fcst_i FROM TABLE @it_items ACCEPTING DUPLICATE KEYS.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_fi_bud_fcst MESSAGE e016(zbud_fcst).
    ENDIF.

    IF it_log IS NOT INITIAL.
      INSERT zfi_bud_fcst_log FROM TABLE @it_log ACCEPTING DUPLICATE KEYS.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_fi_bud_fcst MESSAGE e016(zbud_fcst).
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD years_text.
    rv_text = |{ iv_from }-{ iv_to }|.
  ENDMETHOD.

ENDCLASS.
