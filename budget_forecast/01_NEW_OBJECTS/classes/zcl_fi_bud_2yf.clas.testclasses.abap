*"* Local test classes of ZCL_FI_BUD_2YF (Test Classes include)
*"* Run with Ctrl+Shift+F10 in ADT / SE80 -> Test -> Unit Test.
*"* No database or e-mail access: repository, authorization and
*"* notifier are replaced by test doubles.

CLASS ltd_repository DEFINITION FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_fi_bud_2yf_repository PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_repository IMPLEMENTATION.
ENDCLASS.


CLASS ltd_auth DEFINITION FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_fi_bud_2yf_auth PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_auth IMPLEMENTATION.
ENDCLASS.


CLASS ltd_notifier DEFINITION FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_fi_bud_2yf_notifier PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_notifier IMPLEMENTATION.
ENDCLASS.


CLASS ltc_forecast DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_creator TYPE syuname VALUE 'CREATOR'.
    CONSTANTS c_today   TYPE d       VALUE '20261008'.

    DATA mo_cut TYPE REF TO zcl_fi_bud_2yf.

    METHODS setup.

    METHODS window_is_two_years_ahead   FOR TESTING.
    METHODS split_years_valid           FOR TESTING RAISING zcx_fi_bud_2yf.
    METHODS split_years_invalid         FOR TESTING.
    METHODS change_denied_other_user    FOR TESTING.
    METHODS change_denied_after_two     FOR TESTING.
    METHODS change_denied_next_year     FOR TESTING.
    METHODS change_allowed              FOR TESTING.
    METHODS items_priority_missing      FOR TESTING.
    METHODS items_amount_zero           FOR TESTING.
    METHODS log_amount_change           FOR TESTING.
    METHODS log_added_and_deleted_items FOR TESTING.
    METHODS no_log_without_change       FOR TESTING.

    METHODS key
      RETURNING VALUE(rs_key) TYPE zcl_fi_bud_2yf=>ty_key.
    METHODS item
      IMPORTING iv_item_no     TYPE zfcst_item_no
                iv_amount      TYPE zfcst_amount
      RETURNING VALUE(rs_item) TYPE zif_fi_bud_2yf_types=>ty_item.
    METHODS header
      IMPORTING iv_ernam         TYPE ernam DEFAULT c_creator
                iv_change_count  TYPE zfcst_change_cnt DEFAULT 0
                iv_erdat         TYPE d DEFAULT c_today
      RETURNING VALUE(rs_header) TYPE zcl_fi_bud_2yf=>ty_header.
ENDCLASS.


CLASS ltc_forecast IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( io_repository = NEW ltd_repository( )
                    io_auth       = NEW ltd_auth( )
                    io_notifier   = NEW ltd_notifier( )
                    iv_user       = c_creator
                    iv_today      = c_today ).
  ENDMETHOD.


  METHOD key.
    rs_key = VALUE #( bukrs = '1000' kostl = '0010005000' fyear_from = '2028' fyear_to = '2029' ).
  ENDMETHOD.


  METHOD item.
    rs_item = VALUE #( item_no     = iv_item_no
                       budget_year = '2028'
                       proj_name   = |Project { iv_item_no }|
                       proj_desc   = |Project { iv_item_no }|
                       priority    = 'BASIS'
                       amount      = iv_amount
                       bud_type    = 'CAPEX'
                       proj_type   = 'STRATEGIC' ).
  ENDMETHOD.


  METHOD header.
    rs_header = VALUE #( BASE CORRESPONDING #( key( ) )
                         ernam        = iv_ernam
                         erdat        = iv_erdat
                         change_count = iv_change_count
                         waers        = 'SAR' ).
  ENDMETHOD.


  METHOD window_is_two_years_ahead.
    DATA(ls_years) = mo_cut->get_forecast_window( ).

    cl_abap_unit_assert=>assert_equals( exp = '2028' act = ls_years-fyear_from ).
    cl_abap_unit_assert=>assert_equals( exp = '2029' act = ls_years-fyear_to ).
  ENDMETHOD.


  METHOD split_years_valid.
    DATA(ls_years) = zcl_fi_bud_2yf=>split_years( '2028-2029' ).

    cl_abap_unit_assert=>assert_equals( exp = '2028' act = ls_years-fyear_from ).
    cl_abap_unit_assert=>assert_equals( exp = '2029' act = ls_years-fyear_to ).
  ENDMETHOD.


  METHOD split_years_invalid.
    TRY.
        zcl_fi_bud_2yf=>split_years( '2028-2030' ).
        cl_abap_unit_assert=>fail( 'Non-consecutive years must be rejected' ).
      CATCH zcx_fi_bud_2yf ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.


  METHOD change_denied_other_user.
    DATA(ls_check) = mo_cut->check_change_allowed( header( iv_ernam = 'OTHER' ) ).

    cl_abap_unit_assert=>assert_false( ls_check-allowed ).
    cl_abap_unit_assert=>assert_equals( exp = '008' act = ls_check-msgno ).
  ENDMETHOD.


  METHOD change_denied_after_two.
    DATA(ls_check) = mo_cut->check_change_allowed( header( iv_change_count = 2 ) ).

    cl_abap_unit_assert=>assert_false( ls_check-allowed ).
    cl_abap_unit_assert=>assert_equals( exp = '021' act = ls_check-msgno ).
  ENDMETHOD.


  METHOD change_denied_next_year.
    DATA(ls_check) = mo_cut->check_change_allowed( header( iv_erdat = '20251215' ) ).

    cl_abap_unit_assert=>assert_false( ls_check-allowed ).
    cl_abap_unit_assert=>assert_equals( exp = '022' act = ls_check-msgno ).
  ENDMETHOD.


  METHOD change_allowed.
    DATA(ls_check) = mo_cut->check_change_allowed( header( iv_change_count = 1 ) ).

    cl_abap_unit_assert=>assert_true( ls_check-allowed ).
  ENDMETHOD.


  METHOD items_priority_missing.
    DATA(ls_item) = item( iv_item_no = 1 iv_amount = 100 ).
    CLEAR ls_item-priority.

    TRY.
        mo_cut->validate_items( is_key = key( ) it_items = VALUE #( ( ls_item ) ) ).
        cl_abap_unit_assert=>fail( 'Missing priority must be rejected' ).
      CATCH zcx_fi_bud_2yf INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( exp = 'PRIORITY' act = lx_error->mv_fieldname ).
        cl_abap_unit_assert=>assert_equals( exp = 1 act = lx_error->mv_item_index ).
    ENDTRY.
  ENDMETHOD.


  METHOD items_amount_zero.
    TRY.
        mo_cut->validate_items( is_key   = key( )
                                it_items = VALUE #( ( item( iv_item_no = 1 iv_amount = 0 ) ) ) ).
        cl_abap_unit_assert=>fail( 'Zero amount must be rejected' ).
      CATCH zcx_fi_bud_2yf INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( exp = 'AMOUNT' act = lx_error->mv_fieldname ).
    ENDTRY.
  ENDMETHOD.


  METHOD log_amount_change.
    DATA(lt_old) = VALUE zcl_fi_bud_2yf=>tt_items( ( item( iv_item_no = 1 iv_amount = 1500000 ) ) ).
    DATA(lt_new) = VALUE zcl_fi_bud_2yf=>tt_items( ( item( iv_item_no = 1 iv_amount = 1750000 ) ) ).

    DATA(ls_old_header) = VALUE zcl_fi_bud_2yf=>ty_header( BASE header( ) total_amount = 1500000 ).
    DATA(ls_new_header) = VALUE zcl_fi_bud_2yf=>ty_header( BASE header( iv_change_count = 1 )
                                                            total_amount = 1750000
                                                            aenam        = c_creator
                                                            aedat        = c_today
                                                            aezet        = '101500' ).

    DATA(lt_log) = mo_cut->build_change_log( is_header_old = ls_old_header
                                             is_header_new = ls_new_header
                                             it_items_old  = lt_old
                                             it_items_new  = lt_new ).

    " total amount + item amount
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( lt_log ) ).

    DATA(ls_item_log) = lt_log[ fieldname = 'AMOUNT' ].
    cl_abap_unit_assert=>assert_equals( exp = 1          act = ls_item_log-item_no ).
    cl_abap_unit_assert=>assert_equals( exp = 'U'        act = ls_item_log-chg_ind ).
    cl_abap_unit_assert=>assert_equals( exp = 1          act = ls_item_log-change_no ).
    cl_abap_unit_assert=>assert_equals( exp = c_creator  act = ls_item_log-changed_by ).
    cl_abap_unit_assert=>assert_equals( exp = c_today    act = ls_item_log-changed_on ).
    cl_abap_unit_assert=>assert_equals( exp = '101500'   act = ls_item_log-changed_at ).
    cl_abap_unit_assert=>assert_differs( exp = ls_item_log-value_old act = ls_item_log-value_new ).
  ENDMETHOD.


  METHOD log_added_and_deleted_items.
    DATA(lt_old) = VALUE zcl_fi_bud_2yf=>tt_items( ( item( iv_item_no = 1 iv_amount = 100 ) )
                                                    ( item( iv_item_no = 2 iv_amount = 200 ) ) ).
    DATA(lt_new) = VALUE zcl_fi_bud_2yf=>tt_items( ( item( iv_item_no = 1 iv_amount = 100 ) ) ).

    DATA(lt_log) = mo_cut->build_change_log( is_header_old = header( )
                                             is_header_new = header( iv_change_count = 1 )
                                             it_items_old  = lt_old
                                             it_items_new  = lt_new ).

    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_log[ item_no = 2 chg_ind = 'D' ] ) ) ).

    lt_log = mo_cut->build_change_log( is_header_old = header( )
                                       is_header_new = header( iv_change_count = 1 )
                                       it_items_old  = lt_new
                                       it_items_new  = lt_old ).

    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_log[ item_no = 2 chg_ind = 'I' ] ) ) ).
  ENDMETHOD.


  METHOD no_log_without_change.
    DATA(lt_items) = VALUE zcl_fi_bud_2yf=>tt_items( ( item( iv_item_no = 1 iv_amount = 100 ) ) ).

    DATA(lt_log) = mo_cut->build_change_log( is_header_old = header( )
                                             is_header_new = header( iv_change_count = 1 )
                                             it_items_old  = lt_items
                                             it_items_new  = lt_items ).

    cl_abap_unit_assert=>assert_initial( lt_log ).
    cl_abap_unit_assert=>assert_false( mo_cut->has_changes( is_key       = key( )
                                                            it_items_old = lt_items
                                                            it_items_new = lt_items ) ).
  ENDMETHOD.

ENDCLASS.
