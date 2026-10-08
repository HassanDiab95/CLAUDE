"! <p class="shorttext synchronized">Budget Forecast - business object (rules, save, change log)</p>
"! Technical Consultant : Hassan Diab / Functional Consultant : Ahmed Tawfik
"! Created 08.10.2026 - Request <TBD>
"!
"! All business rules of the Budget Forecast live here, independent of
"! the UI (screen 0100 / report). Persistence, authorization and e-mail
"! are injected through interfaces, so the rules are covered by ABAP Unit
"! (see the local test classes) without database or mail access.
"!
"! Rules
"!   - forecast years = current year + c_year_offset and the year after
"!   - create only by a Budget Preparation creator of the cost center
"!   - one forecast per company / cost center / years (duplicate check)
"!   - change only by the creator, at most c_max_changes times, and only
"!     in the calendar year the forecast was created in
"!   - every change writes a field level change log (ZFI_BUD_FCST_LOG)
"!   - every create / change notifies all Final Reviewers + assistants
CLASS zcl_fi_bud_2yf DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_key          TYPE zif_fi_bud_2yf_types=>ty_key.
    TYPES ty_years        TYPE zif_fi_bud_2yf_types=>ty_years.
    TYPES tt_years        TYPE zif_fi_bud_2yf_types=>tt_years.
    TYPES ty_header       TYPE zif_fi_bud_2yf_types=>ty_header.
    TYPES tt_items        TYPE zif_fi_bud_2yf_types=>tt_items.
    TYPES tt_log          TYPE zif_fi_bud_2yf_types=>tt_log.
    TYPES ty_change_check TYPE zif_fi_bud_2yf_types=>ty_change_check.
    TYPES ty_save_result  TYPE zif_fi_bud_2yf_types=>ty_save_result.
    TYPES ty_mode         TYPE zif_fi_bud_2yf_types=>ty_mode.

    DATA mo_repository TYPE REF TO zif_fi_bud_2yf_repository READ-ONLY.
    DATA mo_auth       TYPE REF TO zif_fi_bud_2yf_auth READ-ONLY.

    "! All parameters are optional: production code passes nothing,
    "! unit tests inject test doubles, a fixed user and a fixed date.
    METHODS constructor
      IMPORTING io_repository TYPE REF TO zif_fi_bud_2yf_repository OPTIONAL
                io_auth       TYPE REF TO zif_fi_bud_2yf_auth OPTIONAL
                io_notifier   TYPE REF TO zif_fi_bud_2yf_notifier OPTIONAL
                iv_user       TYPE syuname OPTIONAL
                iv_today      TYPE d OPTIONAL.

    "! '2028-2029'
    CLASS-METHODS years_text
      IMPORTING iv_from        TYPE zfcst_year_from
                iv_to          TYPE zfcst_year_to
      RETURNING VALUE(rv_text) TYPE string.

    "! '2028-2029' -> 2028 / 2029 (message 003 when invalid)
    CLASS-METHODS split_years
      IMPORTING iv_years        TYPE csequence
      RETURNING VALUE(rs_years) TYPE ty_years
      RAISING   zcx_fi_bud_2yf.

    "! The two years a new forecast can be created for
    METHODS get_forecast_window
      RETURNING VALUE(rs_years) TYPE ty_years.

    "! Listbox values: create = forecast window, modify = own forecasts
    METHODS get_selectable_years
      IMPORTING iv_mode         TYPE ty_mode
      RETURNING VALUE(rt_years) TYPE tt_years.

    "! May the user open the application at all?
    METHODS is_entry_allowed
      IMPORTING iv_mode           TYPE ty_mode
      RETURNING VALUE(rv_allowed) TYPE abap_bool.

    "! Company, cost center, years, creator role, duplicate / ownership
    METHODS validate_header
      IMPORTING iv_mode TYPE ty_mode
                is_key  TYPE ty_key
      RAISING   zcx_fi_bud_2yf.

    "! Creator only, max. c_max_changes updates, creation year only.
    "! MSGNO = 020 when allowed, else 008 / 021 / 022.
    METHODS check_change_allowed
      IMPORTING is_header       TYPE ty_header
      RETURNING VALUE(rs_check) TYPE ty_change_check.

    "! Mandatory columns of the template; raises with field + line
    METHODS validate_items
      IMPORTING is_key   TYPE ty_key
                it_items TYPE tt_items
      RAISING   zcx_fi_bud_2yf.

    METHODS has_changes
      IMPORTING is_key            TYPE ty_key
                it_items_old      TYPE tt_items
                it_items_new      TYPE tt_items
      RETURNING VALUE(rv_changed) TYPE abap_bool.

    METHODS create
      IMPORTING is_key           TYPE ty_key
                it_items         TYPE tt_items
      RETURNING VALUE(rs_result) TYPE ty_save_result
      RAISING   zcx_fi_bud_2yf.

    METHODS change
      IMPORTING is_header_db     TYPE ty_header
                it_items_db      TYPE tt_items
                it_items         TYPE tt_items
      RETURNING VALUE(rs_result) TYPE ty_save_result
      RAISING   zcx_fi_bud_2yf.

    "! Field level differences between the saved and the new version:
    "! one line per changed field, added item or deleted item
    METHODS build_change_log
      IMPORTING is_header_old TYPE ty_header
                is_header_new TYPE ty_header
                it_items_old  TYPE tt_items
                it_items_new  TYPE tt_items
      RETURNING VALUE(rt_log) TYPE tt_log.

    "! Sets key fields, sequence numbers and currency of the items
    METHODS normalize_items
      IMPORTING is_key          TYPE ty_key
                it_items        TYPE tt_items
      RETURNING VALUE(rt_items) TYPE tt_items.

    CLASS-METHODS total_amount
      IMPORTING it_items        TYPE tt_items
      RETURNING VALUE(rv_total) TYPE zfcst_amount.

  PRIVATE SECTION.
    "! Item columns compared for the change log (and required on save)
    CONSTANTS c_logged_fields TYPE string
      VALUE `BUDGET_YEAR PROJ_NAME PROJ_DESC PRIORITY AMOUNT BUD_TYPE PROJ_TYPE`.

    DATA mo_notifier TYPE REF TO zif_fi_bud_2yf_notifier.
    DATA mv_user     TYPE syuname.
    DATA mv_today    TYPE d.

    CLASS-METHODS field_text
      IMPORTING iv_fieldname   TYPE fieldname
                ia_value       TYPE any
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-METHODS value_text
      IMPORTING ia_value       TYPE any
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-METHODS item_summary
      IMPORTING is_item        TYPE zif_fi_bud_2yf_types=>ty_item
      RETURNING VALUE(rv_text) TYPE string.

    METHODS notify
      IMPORTING is_header       TYPE ty_header
                iv_mode         TYPE ty_mode
                iv_item_count   TYPE i
      RETURNING VALUE(rv_error) TYPE string.

ENDCLASS.



CLASS zcl_fi_bud_2yf IMPLEMENTATION.

  METHOD constructor.
    mv_user  = COND #( WHEN iv_user IS NOT INITIAL THEN iv_user ELSE sy-uname ).
    mv_today = COND #( WHEN iv_today IS NOT INITIAL THEN iv_today
                       ELSE cl_abap_context_info=>get_system_date( ) ).

    mo_repository = COND #( WHEN io_repository IS BOUND THEN io_repository
                            ELSE NEW zcl_fi_bud_2yf_repository( ) ).
    mo_auth       = COND #( WHEN io_auth IS BOUND THEN io_auth
                            ELSE NEW zcl_fi_bud_2yf_auth( iv_user = mv_user iv_date = mv_today ) ).
    mo_notifier   = COND #( WHEN io_notifier IS BOUND THEN io_notifier
                            ELSE NEW zcl_fi_bud_2yf_notifier( mo_auth ) ).
  ENDMETHOD.


  METHOD years_text.
    rv_text = |{ iv_from }-{ iv_to }|.
  ENDMETHOD.


  METHOD split_years.
    SPLIT iv_years AT '-' INTO DATA(lv_from) DATA(lv_to).

    " format check first: two 4-digit years
    IF strlen( lv_from ) <> 4 OR lv_from CN '0123456789' OR
       strlen( lv_to )   <> 4 OR lv_to   CN '0123456789'.
      RAISE EXCEPTION TYPE zcx_fi_bud_2yf MESSAGE e003(zbud_fcst).
    ENDIF.

    " numeric compare: the second year must follow the first
    rs_years = VALUE #( fyear_from = lv_from fyear_to = lv_to ).
    IF CONV i( rs_years-fyear_to ) <> CONV i( rs_years-fyear_from ) + 1.
      RAISE EXCEPTION TYPE zcx_fi_bud_2yf MESSAGE e003(zbud_fcst).
    ENDIF.
  ENDMETHOD.


  METHOD get_forecast_window.
    rs_years-fyear_from = mv_today(4) + zif_fi_bud_2yf_types=>c_year_offset.
    rs_years-fyear_to   = rs_years-fyear_from + 1.
  ENDMETHOD.


  METHOD get_selectable_years.
    rt_years = SWITCH #( iv_mode
                 WHEN zif_fi_bud_2yf_types=>c_mode-create
                 THEN VALUE #( ( get_forecast_window( ) ) )
                 ELSE mo_repository->read_user_forecast_years( mv_user ) ).
  ENDMETHOD.


  METHOD is_entry_allowed.
    rv_allowed = mo_auth->is_creator( ).

    " modify: also a user who created a forecast but lost the role
    IF rv_allowed = abap_false AND iv_mode = zif_fi_bud_2yf_types=>c_mode-modify.
      rv_allowed = mo_repository->user_has_forecast( mv_user ).
    ENDIF.
  ENDMETHOD.


  METHOD validate_header.
    DATA lv_creator TYPE ernam.

    IF mo_repository->company_exists( is_key-bukrs ) = abap_false.
      RAISE EXCEPTION TYPE zcx_fi_bud_2yf MESSAGE e001(zbud_fcst) WITH is_key-bukrs.
    ENDIF.

    IF mo_repository->cost_center_exists( iv_bukrs = is_key-bukrs
                                          iv_kostl = is_key-kostl
                                          iv_date  = mv_today ) = abap_false.
      DATA(lv_kokrs) = mo_repository->get_controlling_area( is_key-bukrs ).
      RAISE EXCEPTION TYPE zcx_fi_bud_2yf MESSAGE e002(zbud_fcst) WITH is_key-kostl lv_kokrs.
    ENDIF.

    DATA(lv_years) = years_text( iv_from = is_key-fyear_from iv_to = is_key-fyear_to ).

    CASE iv_mode.

      WHEN zif_fi_bud_2yf_types=>c_mode-create.
        DATA(ls_window) = get_forecast_window( ).
        IF is_key-fyear_from <> ls_window-fyear_from.
          DATA(lv_window) = years_text( iv_from = ls_window-fyear_from iv_to = ls_window-fyear_to ).
          RAISE EXCEPTION TYPE zcx_fi_bud_2yf MESSAGE e004(zbud_fcst) WITH lv_window.
        ENDIF.

        IF mo_auth->is_creator( is_key-kostl ) = abap_false.
          RAISE EXCEPTION TYPE zcx_fi_bud_2yf MESSAGE e005(zbud_fcst) WITH is_key-kostl.
        ENDIF.

        " duplicate prevention: Company + Department + Years
        lv_creator = mo_repository->get_creator( is_key ).
        IF lv_creator IS NOT INITIAL.
          RAISE EXCEPTION TYPE zcx_fi_bud_2yf
            MESSAGE e006(zbud_fcst) WITH is_key-bukrs is_key-kostl lv_years lv_creator.
        ENDIF.

      WHEN zif_fi_bud_2yf_types=>c_mode-modify.
        lv_creator = mo_repository->get_creator( is_key ).
        IF lv_creator IS INITIAL.
          RAISE EXCEPTION TYPE zcx_fi_bud_2yf
            MESSAGE e007(zbud_fcst) WITH is_key-bukrs is_key-kostl lv_years.
        ENDIF.

        " only the creator of the forecast request may open it here
        IF lv_creator <> mv_user.
          RAISE EXCEPTION TYPE zcx_fi_bud_2yf MESSAGE e008(zbud_fcst) WITH lv_creator.
        ENDIF.

    ENDCASE.
  ENDMETHOD.


  METHOD check_change_allowed.
    rs_check = COND #(
      WHEN is_header-ernam <> mv_user
        THEN VALUE #( msgno = '008' msgv1 = is_header-ernam )
      WHEN is_header-change_count >= zif_fi_bud_2yf_types=>c_max_changes
        THEN VALUE #( msgno = '021' msgv1 = |{ zif_fi_bud_2yf_types=>c_max_changes }| )
      WHEN mv_today(4) > is_header-erdat(4)
        THEN VALUE #( msgno = '022' msgv1 = is_header-erdat(4) )
      ELSE VALUE #( allowed = abap_true msgno = '020' ) ).
  ENDMETHOD.


  METHOD validate_items.
    IF it_items IS INITIAL.
      RAISE EXCEPTION TYPE zcx_fi_bud_2yf MESSAGE e009(zbud_fcst).
    ENDIF.

    LOOP AT it_items INTO DATA(ls_item).
      DATA(lv_index) = sy-tabix.

      IF ls_item-budget_year <> is_key-fyear_from AND ls_item-budget_year <> is_key-fyear_to.
        RAISE EXCEPTION TYPE zcx_fi_bud_2yf
          MESSAGE e025(zbud_fcst) WITH ls_item-item_no is_key-fyear_from is_key-fyear_to
          EXPORTING fieldname = 'BUDGET_YEAR' item_index = lv_index.
      ENDIF.

      DATA(lv_missing) = COND fieldname(
        WHEN ls_item-proj_name IS INITIAL THEN 'PROJ_NAME'
        WHEN ls_item-proj_desc IS INITIAL THEN 'PROJ_DESC'
        WHEN ls_item-priority  IS INITIAL THEN 'PRIORITY'
        WHEN ls_item-bud_type  IS INITIAL THEN 'BUD_TYPE'
        WHEN ls_item-proj_type IS INITIAL THEN 'PROJ_TYPE' ).

      IF lv_missing IS NOT INITIAL.
        ASSIGN COMPONENT lv_missing OF STRUCTURE ls_item TO FIELD-SYMBOL(<lv_value>).
        DATA(lv_label) = field_text( iv_fieldname = lv_missing ia_value = <lv_value> ).
        RAISE EXCEPTION TYPE zcx_fi_bud_2yf
          MESSAGE e010(zbud_fcst) WITH ls_item-item_no lv_label
          EXPORTING fieldname = lv_missing item_index = lv_index.
      ENDIF.

      IF ls_item-amount <= 0.
        RAISE EXCEPTION TYPE zcx_fi_bud_2yf
          MESSAGE e011(zbud_fcst) WITH ls_item-item_no
          EXPORTING fieldname = 'AMOUNT' item_index = lv_index.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD has_changes.
    rv_changed = xsdbool( normalize_items( is_key = is_key it_items = it_items_old ) <>
                          normalize_items( is_key = is_key it_items = it_items_new ) ).
  ENDMETHOD.


  METHOD create.
    " the window moves on 1 January - re-check if the screen stayed open
    DATA(ls_window) = get_forecast_window( ).
    IF is_key-fyear_from <> ls_window-fyear_from.
      DATA(lv_window) = years_text( iv_from = ls_window-fyear_from iv_to = ls_window-fyear_to ).
      RAISE EXCEPTION TYPE zcx_fi_bud_2yf MESSAGE e004(zbud_fcst) WITH lv_window.
    ENDIF.

    validate_items( is_key = is_key it_items = it_items ).

    DATA(lt_items) = normalize_items( is_key = is_key it_items = it_items ).

    rs_result-header = VALUE #( BASE CORRESPONDING ty_header( is_key )
                                waers        = zif_fi_bud_2yf_types=>c_currency
                                total_amount = total_amount( lt_items )
                                change_count = 0
                                ernam        = mv_user
                                erdat        = mv_today
                                erzet        = cl_abap_context_info=>get_system_time( ) ).

    TRY.
        mo_repository->insert_forecast( is_header = rs_result-header it_items = lt_items ).
      CATCH zcx_fi_bud_2yf INTO DATA(lx_error).
        ROLLBACK WORK.
        RAISE EXCEPTION lx_error.
    ENDTRY.

    COMMIT WORK AND WAIT.

    rs_result-mail_error = notify( is_header     = rs_result-header
                                   iv_mode       = zif_fi_bud_2yf_types=>c_mode-create
                                   iv_item_count = lines( lt_items ) ).
  ENDMETHOD.


  METHOD change.
    " re-check the rules (another day / year may have started meanwhile)
    DATA(ls_check) = check_change_allowed( is_header_db ).
    IF ls_check-allowed = abap_false.
      RAISE EXCEPTION TYPE zcx_fi_bud_2yf
        MESSAGE ID zif_fi_bud_2yf_types=>c_msgid TYPE 'E' NUMBER ls_check-msgno
        WITH ls_check-msgv1.
    ENDIF.

    DATA(ls_key) = CORRESPONDING ty_key( is_header_db ).

    validate_items( is_key = ls_key it_items = it_items ).

    DATA(lt_old) = normalize_items( is_key = ls_key it_items = it_items_db ).
    DATA(lt_new) = normalize_items( is_key = ls_key it_items = it_items ).

    IF lt_old = lt_new.
      RAISE EXCEPTION TYPE zcx_fi_bud_2yf MESSAGE e014(zbud_fcst).
    ENDIF.

    rs_result-header = VALUE #( BASE is_header_db
                                change_count = is_header_db-change_count + 1
                                total_amount = total_amount( lt_new )
                                aenam        = mv_user
                                aedat        = mv_today
                                aezet        = cl_abap_context_info=>get_system_time( ) ).

    DATA(lt_log) = build_change_log( is_header_old = is_header_db
                                     is_header_new = rs_result-header
                                     it_items_old  = lt_old
                                     it_items_new  = lt_new ).

    TRY.
        mo_repository->update_forecast( is_header           = rs_result-header
                                        iv_old_change_count = is_header_db-change_count
                                        it_items            = lt_new
                                        it_log              = lt_log ).
      CATCH zcx_fi_bud_2yf INTO DATA(lx_error).
        ROLLBACK WORK.
        RAISE EXCEPTION lx_error.
    ENDTRY.

    COMMIT WORK AND WAIT.

    rs_result-mail_error = notify( is_header     = rs_result-header
                                   iv_mode       = zif_fi_bud_2yf_types=>c_mode-modify
                                   iv_item_count = lines( lt_new ) ).
  ENDMETHOD.


  METHOD build_change_log.
    DATA ls_old TYPE zif_fi_bud_2yf_types=>ty_item.

    SPLIT c_logged_fields AT space INTO TABLE DATA(lt_fields).

    " common part of every log line: forecast key + who / when
    DATA(ls_base) = VALUE zif_fi_bud_2yf_types=>ty_log(
                      bukrs      = is_header_new-bukrs
                      kostl      = is_header_new-kostl
                      fyear_from = is_header_new-fyear_from
                      fyear_to   = is_header_new-fyear_to
                      change_no  = is_header_new-change_count
                      changed_by = is_header_new-aenam
                      changed_on = is_header_new-aedat
                      changed_at = is_header_new-aezet ).

    " header: total forecast amount
    IF is_header_old-total_amount <> is_header_new-total_amount.
      APPEND VALUE #( BASE ls_base
                      chg_ind    = zif_fi_bud_2yf_types=>c_chg_ind-update
                      fieldname  = 'TOTAL_AMOUNT'
                      field_text = field_text( iv_fieldname = 'TOTAL_AMOUNT'
                                               ia_value     = is_header_new-total_amount )
                      value_old  = value_text( is_header_old-total_amount )
                      value_new  = value_text( is_header_new-total_amount ) ) TO rt_log.
    ENDIF.

    " items: changed fields and added items
    LOOP AT it_items_new INTO DATA(ls_new).
      ls_old = VALUE #( it_items_old[ item_no = ls_new-item_no ] OPTIONAL ).

      IF ls_old IS INITIAL.
        APPEND VALUE #( BASE ls_base
                        item_no    = ls_new-item_no
                        chg_ind    = zif_fi_bud_2yf_types=>c_chg_ind-insert
                        fieldname  = '*'
                        field_text = `Item added`
                        value_new  = item_summary( ls_new ) ) TO rt_log.
        CONTINUE.
      ENDIF.

      LOOP AT lt_fields INTO DATA(lv_field).
        ASSIGN COMPONENT lv_field OF STRUCTURE ls_old TO FIELD-SYMBOL(<lv_old>).
        ASSIGN COMPONENT lv_field OF STRUCTURE ls_new TO FIELD-SYMBOL(<lv_new>).
        IF <lv_old> <> <lv_new>.
          APPEND VALUE #( BASE ls_base
                          item_no    = ls_new-item_no
                          chg_ind    = zif_fi_bud_2yf_types=>c_chg_ind-update
                          fieldname  = lv_field
                          field_text = field_text( iv_fieldname = CONV #( lv_field ) ia_value = <lv_new> )
                          value_old  = value_text( <lv_old> )
                          value_new  = value_text( <lv_new> ) ) TO rt_log.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    " items: deleted items
    LOOP AT it_items_old INTO ls_old WHERE item_no IS NOT INITIAL.
      IF NOT line_exists( it_items_new[ item_no = ls_old-item_no ] ).
        APPEND VALUE #( BASE ls_base
                        item_no    = ls_old-item_no
                        chg_ind    = zif_fi_bud_2yf_types=>c_chg_ind-delete
                        fieldname  = '*'
                        field_text = `Item deleted`
                        value_old  = item_summary( ls_old ) ) TO rt_log.
      ENDIF.
    ENDLOOP.

    LOOP AT rt_log ASSIGNING FIELD-SYMBOL(<ls_log>).
      <ls_log>-log_no = sy-tabix.
    ENDLOOP.
  ENDMETHOD.


  METHOD normalize_items.
    rt_items = VALUE #( FOR ls_item IN it_items INDEX INTO lv_index
                        ( VALUE #( BASE ls_item
                                   mandt      = sy-mandt
                                   bukrs      = is_key-bukrs
                                   kostl      = is_key-kostl
                                   fyear_from = is_key-fyear_from
                                   fyear_to   = is_key-fyear_to
                                   item_no    = lv_index
                                   waers      = zif_fi_bud_2yf_types=>c_currency ) ) ).
  ENDMETHOD.


  METHOD total_amount.
    rv_total = REDUCE #( INIT lv_sum TYPE zfcst_amount
                         FOR ls_item IN it_items
                         NEXT lv_sum = lv_sum + ls_item-amount ).
  ENDMETHOD.


  METHOD field_text.
    DATA ls_dfies TYPE dfies.

    rv_text = iv_fieldname.

    TRY.
        DATA(lo_element) = CAST cl_abap_elemdescr( cl_abap_typedescr=>describe_by_data( ia_value ) ).
        lo_element->get_ddic_field( EXPORTING  p_langu    = sy-langu
                                    RECEIVING  p_flddescr = ls_dfies
                                    EXCEPTIONS OTHERS     = 1 ).
        IF sy-subrc = 0 AND ls_dfies-scrtext_m IS NOT INITIAL.
          rv_text = ls_dfies-scrtext_m.
        ENDIF.
      CATCH cx_sy_move_cast_error.
        RETURN.
    ENDTRY.
  ENDMETHOD.


  METHOD value_text.
    IF cl_abap_typedescr=>describe_by_data( ia_value )->type_kind = cl_abap_typedescr=>typekind_packed.
      DATA(lv_number) = CONV decfloat34( ia_value ).
      rv_text = |{ lv_number NUMBER = USER }|.
    ELSE.
      rv_text = |{ ia_value }|.
    ENDIF.
  ENDMETHOD.


  METHOD item_summary.
    rv_text = |{ is_item-budget_year } / { is_item-proj_name } / { is_item-priority } / | &&
              |{ value_text( is_item-amount ) } { is_item-waers } / { is_item-bud_type } / { is_item-proj_type }|.
  ENDMETHOD.


  METHOD notify.
    rv_error = mo_notifier->notify(
      is_header           = is_header
      iv_mode             = iv_mode
      iv_item_count       = iv_item_count
      iv_cost_center_text = mo_repository->get_cost_center_text( iv_bukrs = is_header-bukrs
                                                                 iv_kostl = is_header-kostl ) ).
  ENDMETHOD.

ENDCLASS.
