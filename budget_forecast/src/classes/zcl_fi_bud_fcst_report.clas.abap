"! <p class="shorttext synchronized">Budget Forecast - consolidated report with change history</p>
"! Technical Consultant : Hassan Diab / Functional Consultant : Ahmed Tawfik
"! Created 08.10.2026 - Request <TBD>
"!
"! - one ALV with every submitted forecast (header + items), subtotal per
"!   submission, grand total, standard spreadsheet export or a direct
"!   .xlsx download
"! - double-click on a line of a forecast that was updated opens a popup
"!   with its change history: update no., changed by (name), date, time,
"!   item, field, old value, new value
"! - only for Final Reviewers and Final Reviewer assistants
CLASS zcl_fi_bud_fcst_report DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES tt_bukrs_range TYPE RANGE OF bukrs.
    TYPES tt_kostl_range TYPE RANGE OF kostl.
    TYPES tt_fyear_range TYPE RANGE OF zfcst_year_from.
    TYPES tt_ernam_range TYPE RANGE OF ernam.

    TYPES: BEGIN OF ty_out,
             bukrs        TYPE zfi_bud_fcst_h-bukrs,
             kostl        TYPE zfi_bud_fcst_h-kostl,
             ktext        TYPE kltxt,
             fcst_years   TYPE c LENGTH 9,
             item_no      TYPE zfi_bud_fcst_i-item_no,
             budget_year  TYPE zfi_bud_fcst_i-budget_year,
             proj_name    TYPE zfi_bud_fcst_i-proj_name,
             proj_desc    TYPE zfi_bud_fcst_i-proj_desc,
             priority     TYPE zfi_bud_fcst_i-priority,
             amount       TYPE zfi_bud_fcst_i-amount,
             waers        TYPE zfi_bud_fcst_i-waers,
             bud_type     TYPE zfi_bud_fcst_i-bud_type,
             proj_type    TYPE zfi_bud_fcst_i-proj_type,
             change_count TYPE zfi_bud_fcst_h-change_count,
             ernam        TYPE zfi_bud_fcst_h-ernam,
             erdat        TYPE zfi_bud_fcst_h-erdat,
             aenam        TYPE zfi_bud_fcst_h-aenam,
             aedat        TYPE zfi_bud_fcst_h-aedat,
             fyear_from   TYPE zfi_bud_fcst_h-fyear_from,
             fyear_to     TYPE zfi_bud_fcst_h-fyear_to,
           END OF ty_out,
           tt_out TYPE STANDARD TABLE OF ty_out WITH EMPTY KEY.

    TYPES: BEGIN OF ty_log_out,
             change_no  TYPE zfi_bud_fcst_log-change_no,
             changed_by TYPE zfi_bud_fcst_log-changed_by,
             user_name  TYPE ad_namtext,
             changed_on TYPE zfi_bud_fcst_log-changed_on,
             changed_at TYPE zfi_bud_fcst_log-changed_at,
             item_no    TYPE zfi_bud_fcst_log-item_no,
             action     TYPE c LENGTH 10,
             field_text TYPE zfi_bud_fcst_log-field_text,
             value_old  TYPE zfi_bud_fcst_log-value_old,
             value_new  TYPE zfi_bud_fcst_log-value_new,
           END OF ty_log_out,
           tt_log_out TYPE STANDARD TABLE OF ty_log_out WITH EMPTY KEY.

    METHODS constructor
      IMPORTING it_bukrs      TYPE tt_bukrs_range OPTIONAL
                it_kostl      TYPE tt_kostl_range OPTIONAL
                it_fyear      TYPE tt_fyear_range OPTIONAL
                it_ernam      TYPE tt_ernam_range OPTIONAL
                io_repository TYPE REF TO zif_fi_bud_fcst_repository OPTIONAL
                io_auth       TYPE REF TO zif_fi_bud_fcst_auth OPTIONAL.

    "! Select, (optionally) download and display the report
    METHODS run
      IMPORTING iv_download TYPE abap_bool DEFAULT abap_false
      RAISING   zcx_fi_bud_fcst.

  PRIVATE SECTION.
    DATA mt_bukrs      TYPE tt_bukrs_range.
    DATA mt_kostl      TYPE tt_kostl_range.
    DATA mt_fyear      TYPE tt_fyear_range.
    DATA mt_ernam      TYPE tt_ernam_range.
    DATA mo_repository TYPE REF TO zif_fi_bud_fcst_repository.
    DATA mo_auth       TYPE REF TO zif_fi_bud_fcst_auth.
    DATA mt_out        TYPE tt_out.
    DATA mt_log_out    TYPE tt_log_out.
    DATA mo_salv       TYPE REF TO cl_salv_table.

    METHODS select_data.

    METHODS build_alv
      RAISING cx_salv_error.

    METHODS download_xlsx.

    METHODS show_change_log
      IMPORTING is_out TYPE ty_out.

    METHODS on_double_click
      FOR EVENT double_click OF cl_salv_events_table
      IMPORTING row column.

    CLASS-METHODS set_column_texts
      IMPORTING io_columns TYPE REF TO cl_salv_columns_table
                it_texts   TYPE string_table.

    CLASS-METHODS user_name
      IMPORTING iv_user        TYPE syuname
      RETURNING VALUE(rv_name) TYPE ad_namtext.

ENDCLASS.



CLASS zcl_fi_bud_fcst_report IMPLEMENTATION.

  METHOD constructor.
    mt_bukrs = it_bukrs.
    mt_kostl = it_kostl.
    mt_fyear = it_fyear.
    mt_ernam = it_ernam.

    mo_repository = COND #( WHEN io_repository IS BOUND THEN io_repository
                            ELSE NEW zcl_fi_bud_fcst_repository( ) ).
    mo_auth       = COND #( WHEN io_auth IS BOUND THEN io_auth
                            ELSE NEW zcl_fi_bud_fcst_auth( ) ).
  ENDMETHOD.


  METHOD run.
    IF mo_auth->is_final_reviewer( ) = abap_false.
      RAISE EXCEPTION TYPE zcx_fi_bud_fcst MESSAGE e023(zbud_fcst).
    ENDIF.

    select_data( ).
    IF mt_out IS INITIAL.
      RAISE EXCEPTION TYPE zcx_fi_bud_fcst MESSAGE e024(zbud_fcst).
    ENDIF.

    TRY.
        build_alv( ).
      CATCH cx_salv_error INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    IF iv_download = abap_true.
      download_xlsx( ).
    ENDIF.

    mo_salv->display( ).
  ENDMETHOD.


  METHOD select_data.
    TYPES: BEGIN OF ty_text,
             bukrs TYPE bukrs,
             kostl TYPE kostl,
             ktext TYPE kltxt,
           END OF ty_text.
    DATA lt_texts TYPE HASHED TABLE OF ty_text WITH UNIQUE KEY bukrs kostl.
    DATA lr_text  TYPE REF TO ty_text.

    SELECT h~bukrs, h~kostl, h~fyear_from, h~fyear_to, h~change_count,
           h~ernam, h~erdat, h~aenam, h~aedat,
           i~item_no, i~budget_year, i~proj_name, i~proj_desc, i~priority,
           i~amount, i~waers, i~bud_type, i~proj_type
      FROM zfi_bud_fcst_h AS h
      INNER JOIN zfi_bud_fcst_i AS i
        ON  i~bukrs      = h~bukrs
        AND i~kostl      = h~kostl
        AND i~fyear_from = h~fyear_from
        AND i~fyear_to   = h~fyear_to
      WHERE h~bukrs      IN @mt_bukrs
        AND h~kostl      IN @mt_kostl
        AND h~fyear_from IN @mt_fyear
        AND h~ernam      IN @mt_ernam
      ORDER BY h~bukrs, h~kostl, h~fyear_from, i~item_no
      INTO CORRESPONDING FIELDS OF TABLE @mt_out.

    " cost center text (released CDS view via repository), buffered
    LOOP AT mt_out ASSIGNING FIELD-SYMBOL(<ls_out>).
      <ls_out>-fcst_years = zcl_fi_bud_fcst=>years_text( iv_from = <ls_out>-fyear_from
                                                         iv_to   = <ls_out>-fyear_to ).

      READ TABLE lt_texts REFERENCE INTO lr_text
           WITH TABLE KEY bukrs = <ls_out>-bukrs kostl = <ls_out>-kostl.
      IF sy-subrc <> 0.
        INSERT VALUE #( bukrs = <ls_out>-bukrs
                        kostl = <ls_out>-kostl
                        ktext = mo_repository->get_cost_center_text( iv_bukrs = <ls_out>-bukrs
                                                                     iv_kostl = <ls_out>-kostl ) )
          INTO TABLE lt_texts REFERENCE INTO lr_text.
      ENDIF.
      <ls_out>-ktext = lr_text->ktext.
    ENDLOOP.
  ENDMETHOD.


  METHOD build_alv.
    cl_salv_table=>factory( IMPORTING r_salv_table = mo_salv
                            CHANGING  t_table      = mt_out ).

    mo_salv->get_functions( )->set_all( abap_true ).

    DATA(lo_display) = mo_salv->get_display_settings( ).
    lo_display->set_striped_pattern( abap_true ).
    lo_display->set_list_header( CONV #(
      |Consolidated Budget Forecast Report ({ lines( mt_out ) } items) - | &&
      |double-click a line with Updates Used > 0 to see its change history| ) ).

    DATA(lo_layout) = mo_salv->get_layout( ).
    lo_layout->set_key( VALUE #( report = sy-cprog ) ).  "the calling report
    lo_layout->set_save_restriction( if_salv_c_layout=>restrict_none ).
    lo_layout->set_default( abap_true ).

    DATA(lo_columns) = mo_salv->get_columns( ).
    lo_columns->set_optimize( abap_true ).

    set_column_texts( io_columns = lo_columns
                      it_texts   = VALUE #( ( `BUKRS=Company Code` )
                                            ( `KOSTL=Cost Center` )
                                            ( `KTEXT=Department` )
                                            ( `FCST_YEARS=Forecast Years` )
                                            ( `ITEM_NO=Sequence` )
                                            ( `BUDGET_YEAR=Budget Year` )
                                            ( `PROJ_NAME=Project Name` )
                                            ( `PROJ_DESC=Project Description` )
                                            ( `PRIORITY=Project Priority` )
                                            ( `AMOUNT=Project Budget` )
                                            ( `WAERS=Currency` )
                                            ( `BUD_TYPE=Opex / Capex` )
                                            ( `PROJ_TYPE=Project Type` )
                                            ( `CHANGE_COUNT=Updates Used` )
                                            ( `ERNAM=Created By` )
                                            ( `ERDAT=Created On` )
                                            ( `AENAM=Last Changed By` )
                                            ( `AEDAT=Last Changed On` ) ) ).

    " technical key fields, only needed for the double-click
    lo_columns->get_column( 'FYEAR_FROM' )->set_technical( abap_true ).
    lo_columns->get_column( 'FYEAR_TO' )->set_technical( abap_true ).

    " grand total and subtotal per forecast submission
    mo_salv->get_aggregations( )->add_aggregation( columnname = 'AMOUNT' ).

    DATA(lo_sorts) = mo_salv->get_sorts( ).
    lo_sorts->add_sort( columnname = 'BUKRS' ).
    lo_sorts->add_sort( columnname = 'KOSTL' ).
    lo_sorts->add_sort( columnname = 'FCST_YEARS' subtotal = abap_true ).
    lo_sorts->add_sort( columnname = 'ITEM_NO' ).

    SET HANDLER on_double_click FOR mo_salv->get_event( ).
  ENDMETHOD.


  METHOD on_double_click.
    " ROW is the index in MT_OUT (also after sorting in the ALV)
    DATA(ls_out) = VALUE ty_out( mt_out[ row ] OPTIONAL ).
    IF ls_out IS INITIAL.
      RETURN.
    ENDIF.

    IF ls_out-change_count = 0.
      MESSAGE s027(zbud_fcst) WITH ls_out-bukrs ls_out-kostl ls_out-fcst_years.
      RETURN.
    ENDIF.

    show_change_log( ls_out ).
  ENDMETHOD.


  METHOD show_change_log.
    DATA(lt_log) = mo_repository->read_change_log( VALUE #( bukrs      = is_out-bukrs
                                                            kostl      = is_out-kostl
                                                            fyear_from = is_out-fyear_from
                                                            fyear_to   = is_out-fyear_to ) ).
    IF lt_log IS INITIAL.
      MESSAGE s027(zbud_fcst) WITH is_out-bukrs is_out-kostl is_out-fcst_years.
      RETURN.
    ENDIF.

    mt_log_out = VALUE #(
      FOR ls_log IN lt_log
      ( VALUE #( BASE CORRESPONDING #( ls_log )
                 user_name = user_name( ls_log-changed_by )
                 action    = SWITCH #( ls_log-chg_ind
                               WHEN zif_fi_bud_fcst_types=>c_chg_ind-insert THEN 'Added'
                               WHEN zif_fi_bud_fcst_types=>c_chg_ind-delete THEN 'Deleted'
                               ELSE 'Changed' ) ) ) ).

    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_popup)
                                CHANGING  t_table      = mt_log_out ).

        lo_popup->set_screen_popup( start_column = 5
                                    end_column   = 180
                                    start_line   = 3
                                    end_line     = 20 ).

        lo_popup->get_display_settings( )->set_list_header( CONV #(
          |Change history - Company { is_out-bukrs } / Cost Center { is_out-kostl ALPHA = OUT } / | &&
          |{ is_out-fcst_years } ({ is_out-change_count } of { zif_fi_bud_fcst_types=>c_max_changes } updates)| ) ).
        lo_popup->get_display_settings( )->set_striped_pattern( abap_true ).
        lo_popup->get_functions( )->set_all( abap_true ).

        DATA(lo_columns) = lo_popup->get_columns( ).
        lo_columns->set_optimize( abap_true ).
        set_column_texts( io_columns = lo_columns
                          it_texts   = VALUE #( ( `CHANGE_NO=Update No.` )
                                                ( `CHANGED_BY=Changed By` )
                                                ( `USER_NAME=Name` )
                                                ( `CHANGED_ON=Date` )
                                                ( `CHANGED_AT=Time` )
                                                ( `ITEM_NO=Item` )
                                                ( `ACTION=Action` )
                                                ( `FIELD_TEXT=Field` )
                                                ( `VALUE_OLD=Old Value` )
                                                ( `VALUE_NEW=New Value` ) ) ).

        DATA(lo_sorts) = lo_popup->get_sorts( ).
        lo_sorts->add_sort( columnname = 'CHANGE_NO' ).
        lo_sorts->add_sort( columnname = 'ITEM_NO' ).

        lo_popup->display( ).

      CATCH cx_salv_error INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD download_xlsx.
    DATA lv_filename TYPE string.
    DATA lv_path     TYPE string.
    DATA lv_fullpath TYPE string.

    DATA(lv_xstring) = mo_salv->to_xml( xml_type = if_salv_bs_xml=>c_type_xlsx ).
    DATA(lt_solix)   = cl_bcs_convert=>xstring_to_solix( iv_xstring = lv_xstring ).

    cl_gui_frontend_services=>file_save_dialog(
      EXPORTING
        window_title      = 'Save Budget Forecast Report'
        default_extension = 'xlsx'
        default_file_name = |Budget Forecast-{ sy-datum }-{ sy-uzeit }.xlsx|
        file_filter       = 'Excel Files (*.xlsx)|*.xlsx|All Files (*.*)|*.*'
      CHANGING
        filename          = lv_filename
        path              = lv_path
        fullpath          = lv_fullpath
      EXCEPTIONS
        OTHERS            = 1 ).
    IF sy-subrc <> 0 OR lv_fullpath IS INITIAL.
      MESSAGE 'Download cancelled by user.' TYPE 'S'.
      RETURN.
    ENDIF.

    cl_gui_frontend_services=>gui_download(
      EXPORTING
        filename     = lv_fullpath
        filetype     = 'BIN'
        bin_filesize = xstrlen( lv_xstring )
      CHANGING
        data_tab     = lt_solix
      EXCEPTIONS
        OTHERS       = 1 ).

    IF sy-subrc = 0.
      MESSAGE |File exported successfully: { lv_fullpath }| TYPE 'S'.
    ELSE.
      MESSAGE 'Error occurred during file download!' TYPE 'S' DISPLAY LIKE 'E'.
    ENDIF.
  ENDMETHOD.


  METHOD set_column_texts.
    LOOP AT it_texts INTO DATA(lv_entry).
      SPLIT lv_entry AT '=' INTO DATA(lv_name) DATA(lv_text).
      TRY.
          DATA(lo_column) = io_columns->get_column( CONV #( lv_name ) ).
          lo_column->set_long_text( CONV #( lv_text ) ).
          lo_column->set_medium_text( CONV #( lv_text ) ).
          lo_column->set_short_text( CONV #( lv_text ) ).
        CATCH cx_salv_not_found ##NO_HANDLER.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  METHOD user_name.
    DATA ls_address TYPE bapiaddr3.
    DATA lt_return  TYPE STANDARD TABLE OF bapiret2 WITH EMPTY KEY.

    CALL FUNCTION 'BAPI_USER_GET_DETAIL'
      EXPORTING
        username = iv_user
      IMPORTING
        address  = ls_address
      TABLES
        return   = lt_return.

    rv_name = ls_address-fullname.
  ENDMETHOD.

ENDCLASS.
