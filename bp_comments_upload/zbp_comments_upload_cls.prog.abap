*&---------------------------------------------------------------------*
*& Include ZBP_COMMENTS_UPLOAD_CLS
*&---------------------------------------------------------------------*
*& Local classes for report ZBP_COMMENTS_UPLOAD
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
* Types shared by all classes
*----------------------------------------------------------------------*
INTERFACE lif_types.
  TYPES:
    BEGIN OF ty_upload,
      row      TYPE i,
      partner  TYPE bu_partner,
      comments TYPE string,
      langu    TYPE laiso,
    END OF ty_upload,
    tt_upload TYPE STANDARD TABLE OF ty_upload WITH EMPTY KEY,

    BEGIN OF ty_result,
      status   TYPE icon_d,
      row      TYPE i,
      partner  TYPE bu_partner,
      comments TYPE ad_remark1,
      langu    TYPE laiso,
      message  TYPE bapi_msg,
    END OF ty_result,
    tt_result TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY,

    tt_remarks   TYPE STANDARD TABLE OF bapiadrem  WITH DEFAULT KEY,
    tt_remarks_x TYPE STANDARD TABLE OF bapiadremx WITH DEFAULT KEY.

  CONSTANTS:
    BEGIN OF gc_status,
      success TYPE icon_d VALUE '@08@',   " green light
      warning TYPE icon_d VALUE '@09@',   " yellow light
      error   TYPE icon_d VALUE '@0A@',   " red light
    END OF gc_status.
ENDINTERFACE.

*----------------------------------------------------------------------*
* Exception
*----------------------------------------------------------------------*
CLASS lcx_upload_error DEFINITION INHERITING FROM cx_static_check FINAL.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_text   TYPE csequence OPTIONAL
                previous  LIKE previous OPTIONAL
      PREFERRED PARAMETER iv_text.
    METHODS get_text REDEFINITION.
  PRIVATE SECTION.
    DATA mv_text TYPE string.
ENDCLASS.

CLASS lcx_upload_error IMPLEMENTATION.
  METHOD constructor.
    super->constructor( previous = previous ).
    mv_text = iv_text.
  ENDMETHOD.

  METHOD get_text.
    result = COND #( WHEN mv_text IS NOT INITIAL THEN mv_text
                     WHEN previous IS BOUND     THEN previous->get_text( )
                     ELSE super->get_text( ) ).
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
* File access (presentation server)
*----------------------------------------------------------------------*
INTERFACE lif_file_reader.
  METHODS read_binary
    IMPORTING iv_file          TYPE string
    RETURNING VALUE(rv_xstring) TYPE xstring
    RAISING   lcx_upload_error.
ENDINTERFACE.

CLASS lcl_frontend_file DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES lif_file_reader.
    CLASS-METHODS select_file RETURNING VALUE(rv_file) TYPE string.
ENDCLASS.

CLASS lcl_frontend_file IMPLEMENTATION.
  METHOD select_file.
    DATA lt_files TYPE filetable.
    DATA lv_rc    TYPE i.

    cl_gui_frontend_services=>file_open_dialog(
      EXPORTING
        window_title            = CONV #( TEXT-f01 )
        file_filter             = |Excel (*.xlsx)\|*.xlsx\|{ cl_gui_frontend_services=>filetype_all }|
        multiselection          = abap_false
      CHANGING
        file_table              = lt_files
        rc                      = lv_rc
      EXCEPTIONS
        OTHERS                  = 1 ).
    IF sy-subrc = 0 AND lv_rc = 1.
      rv_file = VALUE #( lt_files[ 1 ]-filename OPTIONAL ).
    ENDIF.
  ENDMETHOD.

  METHOD lif_file_reader~read_binary.
    DATA lt_bin TYPE solix_tab.
    DATA lv_len TYPE i.

    cl_gui_frontend_services=>gui_upload(
      EXPORTING
        filename   = iv_file
        filetype   = 'BIN'
      IMPORTING
        filelength = lv_len
      CHANGING
        data_tab   = lt_bin
      EXCEPTIONS
        OTHERS     = 1 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION NEW lcx_upload_error( |File { iv_file } could not be read| ).
    ENDIF.

    rv_xstring = cl_bcs_convert=>solix_to_xstring( it_solix = lt_bin
                                                   iv_size  = lv_len ).
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
* Excel parser (.xlsx -> upload records)
*----------------------------------------------------------------------*
CLASS lcl_excel_parser DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING io_file_reader TYPE REF TO lif_file_reader.

    METHODS parse
      IMPORTING iv_file          TYPE string
                iv_skip_header   TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(rt_upload) TYPE lif_types=>tt_upload
      RAISING   lcx_upload_error.

  PRIVATE SECTION.
    DATA mo_file_reader TYPE REF TO lif_file_reader.

    METHODS cell
      IMPORTING is_row         TYPE any
                iv_column      TYPE i
      RETURNING VALUE(rv_value) TYPE string.
ENDCLASS.

CLASS lcl_excel_parser IMPLEMENTATION.
  METHOD constructor.
    mo_file_reader = io_file_reader.
  ENDMETHOD.

  METHOD parse.
    FIELD-SYMBOLS <lt_sheet> TYPE STANDARD TABLE.

    DATA(lv_xstring) = mo_file_reader->read_binary( iv_file ).

    TRY.
        DATA(lo_xlsx) = NEW cl_fdt_xl_spreadsheet( document_name = iv_file
                                                   xdocument     = lv_xstring ).
        lo_xlsx->if_fdt_doc_spreadsheet~get_worksheet_names(
          IMPORTING worksheet_names = DATA(lt_sheets) ).
        DATA(lr_sheet) = lo_xlsx->if_fdt_doc_spreadsheet~get_itab_from_worksheet(
                           VALUE #( lt_sheets[ 1 ] OPTIONAL ) ).
      CATCH cx_fdt_excel_core INTO DATA(lx_excel).
        RAISE EXCEPTION NEW lcx_upload_error( previous = lx_excel ).
    ENDTRY.

    IF lr_sheet IS NOT BOUND.
      RAISE EXCEPTION NEW lcx_upload_error( TEXT-e01 ).
    ENDIF.
    ASSIGN lr_sheet->* TO <lt_sheet>.

    LOOP AT <lt_sheet> ASSIGNING FIELD-SYMBOL(<ls_row>).
      DATA(lv_row) = sy-tabix.
      IF iv_skip_header = abap_true AND lv_row = 1.
        CONTINUE.
      ENDIF.

      DATA(lv_partner) = condense( cell( is_row = <ls_row> iv_column = 1 ) ).
      DATA(lv_comment) = condense( cell( is_row = <ls_row> iv_column = 2 ) ).
      DATA(lv_langu)   = to_upper( condense( cell( is_row = <ls_row> iv_column = 3 ) ) ).

      " skip completely empty lines
      IF lv_partner IS INITIAL AND lv_comment IS INITIAL.
        CONTINUE.
      ENDIF.

      INSERT VALUE #( row      = lv_row
                      partner  = |{ lv_partner ALPHA = IN WIDTH = 10 }|
                      comments = lv_comment
                      langu    = lv_langu ) INTO TABLE rt_upload.
    ENDLOOP.

    IF rt_upload IS INITIAL.
      RAISE EXCEPTION NEW lcx_upload_error( TEXT-e01 ).
    ENDIF.
  ENDMETHOD.

  METHOD cell.
    ASSIGN COMPONENT iv_column OF STRUCTURE is_row TO FIELD-SYMBOL(<lv_value>).
    IF sy-subrc = 0.
      rv_value = <lv_value>.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
* BP address API (wrapper around standard BAPIs)
*----------------------------------------------------------------------*
INTERFACE lif_bp_address_api.
  METHODS get_standard_address_guid
    IMPORTING iv_partner     TYPE bu_partner
    EXPORTING ev_guid        TYPE bu_address_guid_bapi
              et_return      TYPE bapiret2_t.

  METHODS get_remarks
    IMPORTING iv_partner        TYPE bu_partner
              iv_guid           TYPE bu_address_guid_bapi
    RETURNING VALUE(rt_remarks) TYPE lif_types=>tt_remarks.

  METHODS change_remarks
    IMPORTING iv_partner       TYPE bu_partner
              iv_guid          TYPE bu_address_guid_bapi
              it_remarks       TYPE lif_types=>tt_remarks
              it_remarks_x     TYPE lif_types=>tt_remarks_x
    RETURNING VALUE(rt_return) TYPE bapiret2_t.

  METHODS commit.
  METHODS rollback.
ENDINTERFACE.

CLASS lcl_bp_address_api DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES lif_bp_address_api.
ENDCLASS.

CLASS lcl_bp_address_api IMPLEMENTATION.
  METHOD lif_bp_address_api~get_standard_address_guid.
    DATA lt_addresses TYPE STANDARD TABLE OF bapibus1006_addresses WITH EMPTY KEY.

    CLEAR: ev_guid, et_return.
    CALL FUNCTION 'BAPI_BUPA_ADDRESSES_GET'
      EXPORTING
        businesspartner     = iv_partner
      IMPORTING
        standardaddressguid = ev_guid
      TABLES
        addresses           = lt_addresses
        return              = et_return.
  ENDMETHOD.

  METHOD lif_bp_address_api~get_remarks.
    DATA lt_return TYPE bapiret2_t.

    CALL FUNCTION 'BAPI_BUPA_ADDRESS_GETDETAIL'
      EXPORTING
        businesspartner = iv_partner
        addressguid     = iv_guid
      TABLES
        bapiadrem       = rt_remarks
        return          = lt_return.
  ENDMETHOD.

  METHOD lif_bp_address_api~change_remarks.
    DATA(lt_remarks)   = it_remarks.
    DATA(lt_remarks_x) = it_remarks_x.

    CALL FUNCTION 'BAPI_BUPA_ADDRESS_CHANGE'
      EXPORTING
        businesspartner = iv_partner
        addressguid     = iv_guid
      TABLES
        bapiadrem       = lt_remarks
        bapiadrem_x     = lt_remarks_x
        return          = rt_return.
  ENDMETHOD.

  METHOD lif_bp_address_api~commit.
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = abap_true.
  ENDMETHOD.

  METHOD lif_bp_address_api~rollback.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
* Business logic: validate + update comments
*----------------------------------------------------------------------*
CLASS lcl_comment_updater DEFINITION FINAL.
  PUBLIC SECTION.
    CONSTANTS gc_max_length TYPE i VALUE 50.   " ADRCT-REMARK

    METHODS constructor
      IMPORTING io_api TYPE REF TO lif_bp_address_api.

    METHODS process
      IMPORTING it_upload        TYPE lif_types=>tt_upload
                iv_test_mode     TYPE abap_bool
      RETURNING VALUE(rt_result) TYPE lif_types=>tt_result.

  PRIVATE SECTION.
    DATA mo_api TYPE REF TO lif_bp_address_api.

    METHODS process_line
      IMPORTING is_upload        TYPE lif_types=>ty_upload
                iv_test_mode     TYPE abap_bool
      RETURNING VALUE(rs_result) TYPE lif_types=>ty_result.

    METHODS validate
      IMPORTING is_upload         TYPE lif_types=>ty_upload
      RETURNING VALUE(rv_message) TYPE bapi_msg.

    METHODS resolve_language
      IMPORTING iv_langu_iso    TYPE laiso
      EXPORTING ev_langu        TYPE spras
                ev_langu_iso    TYPE laiso.

    METHODS first_error
      IMPORTING it_return         TYPE bapiret2_t
      RETURNING VALUE(rv_message) TYPE bapi_msg.
ENDCLASS.

CLASS lcl_comment_updater IMPLEMENTATION.
  METHOD constructor.
    mo_api = io_api.
  ENDMETHOD.

  METHOD process.
    rt_result = VALUE #( FOR ls_upload IN it_upload
                         ( process_line( is_upload    = ls_upload
                                         iv_test_mode = iv_test_mode ) ) ).
  ENDMETHOD.

  METHOD process_line.
    rs_result = VALUE #( row      = is_upload-row
                         partner  = is_upload-partner
                         comments = is_upload-comments
                         langu    = is_upload-langu ).

    rs_result-message = validate( is_upload ).
    IF rs_result-message IS NOT INITIAL.
      rs_result-status = lif_types=>gc_status-error.
      RETURN.
    ENDIF.

    " 1. standard address of the BP
    mo_api->get_standard_address_guid( EXPORTING iv_partner = is_upload-partner
                                       IMPORTING ev_guid    = DATA(lv_guid)
                                                 et_return  = DATA(lt_return) ).
    rs_result-message = first_error( lt_return ).
    IF rs_result-message IS INITIAL AND lv_guid IS INITIAL.
      rs_result-message = |No standard address found for BP { is_upload-partner ALPHA = OUT }|.
    ENDIF.
    IF rs_result-message IS NOT INITIAL.
      rs_result-status = lif_types=>gc_status-error.
      RETURN.
    ENDIF.

    " 2. insert or update the comment for the requested language
    resolve_language( EXPORTING iv_langu_iso = is_upload-langu
                      IMPORTING ev_langu     = DATA(lv_langu)
                                ev_langu_iso = rs_result-langu ).

    DATA(lt_existing) = mo_api->get_remarks( iv_partner = is_upload-partner
                                             iv_guid    = lv_guid ).
    DATA(lv_updflag) = COND bapiupdate( WHEN line_exists( lt_existing[ langu = lv_langu ] )
                                        THEN 'U' ELSE 'I' ).

    lt_return = mo_api->change_remarks(
      iv_partner   = is_upload-partner
      iv_guid      = lv_guid
      it_remarks   = VALUE #( ( langu     = lv_langu
                                langu_iso = rs_result-langu
                                adr_notes = is_upload-comments ) )
      it_remarks_x = VALUE #( ( langu      = abap_true
                                langu_iso  = abap_true
                                adr_notes  = abap_true
                                updateflag = lv_updflag ) ) ).

    rs_result-message = first_error( lt_return ).
    IF rs_result-message IS NOT INITIAL.
      mo_api->rollback( ).
      rs_result-status = lif_types=>gc_status-error.
      RETURN.
    ENDIF.

    " 3. commit / simulate
    IF iv_test_mode = abap_true.
      mo_api->rollback( ).
      rs_result-status  = lif_types=>gc_status-warning.
      rs_result-message = TEXT-m02.
    ELSE.
      mo_api->commit( ).
      rs_result-status  = lif_types=>gc_status-success.
      rs_result-message = TEXT-m01.
    ENDIF.
  ENDMETHOD.

  METHOD validate.
    rv_message = COND #(
      WHEN is_upload-partner CO '0 '
        THEN TEXT-e02
      WHEN strlen( is_upload-comments ) > gc_max_length
        THEN |Comment exceeds { gc_max_length } characters ({ strlen( is_upload-comments ) })| ).
  ENDMETHOD.

  METHOD resolve_language.
    ev_langu_iso = iv_langu_iso.
    IF ev_langu_iso IS INITIAL.
      cl_i18n_languages=>sap1_to_sap2( EXPORTING im_lang_sap1  = sy-langu
                                       RECEIVING re_lang_sap2  = ev_langu_iso
                                       EXCEPTIONS OTHERS       = 0 ).
    ENDIF.
    cl_i18n_languages=>sap2_to_sap1( EXPORTING im_lang_sap2  = ev_langu_iso
                                     RECEIVING re_lang_sap1  = ev_langu
                                     EXCEPTIONS OTHERS       = 0 ).
    IF ev_langu IS INITIAL.
      ev_langu = sy-langu.
    ENDIF.
  ENDMETHOD.

  METHOD first_error.
    rv_message = VALUE #( it_return[ type = 'E' ]-message
                          DEFAULT VALUE #( it_return[ type = 'A' ]-message OPTIONAL ) ).
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
* Output (SALV)
*----------------------------------------------------------------------*
CLASS lcl_result_view DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS display
      CHANGING ct_result TYPE lif_types=>tt_result.
ENDCLASS.

CLASS lcl_result_view IMPLEMENTATION.
  METHOD display.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                                CHANGING  t_table      = ct_result ).

        lo_alv->get_functions( )->set_all( abap_true ).
        lo_alv->get_columns( )->set_optimize( abap_true ).
        lo_alv->get_display_settings( )->set_striped_pattern( abap_true ).

        DATA(lo_columns) = lo_alv->get_columns( ).
        CAST cl_salv_column_table( lo_columns->get_column( 'STATUS' ) )->set_icon( abap_true ).
        lo_columns->get_column( 'STATUS' )->set_long_text( 'Status' ).
        lo_columns->get_column( 'ROW' )->set_long_text( 'Excel Row' ).
        lo_columns->get_column( 'COMMENTS' )->set_long_text( 'Comments' ).

        lo_alv->display( ).
      CATCH cx_salv_error INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'I' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
* Application controller
*----------------------------------------------------------------------*
CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING io_file_reader TYPE REF TO lif_file_reader    OPTIONAL
                io_api         TYPE REF TO lif_bp_address_api OPTIONAL.

    METHODS run
      IMPORTING iv_file        TYPE string
                iv_skip_header TYPE abap_bool
                iv_test_mode   TYPE abap_bool.

  PRIVATE SECTION.
    DATA mo_parser  TYPE REF TO lcl_excel_parser.
    DATA mo_updater TYPE REF TO lcl_comment_updater.
ENDCLASS.

CLASS lcl_app IMPLEMENTATION.
  METHOD constructor.
    mo_parser  = NEW #( COND #( WHEN io_file_reader IS BOUND THEN io_file_reader
                                ELSE NEW lcl_frontend_file( ) ) ).
    mo_updater = NEW #( COND #( WHEN io_api IS BOUND THEN io_api
                                ELSE NEW lcl_bp_address_api( ) ) ).
  ENDMETHOD.

  METHOD run.
    TRY.
        DATA(lt_upload) = mo_parser->parse( iv_file        = iv_file
                                            iv_skip_header = iv_skip_header ).
      CATCH lcx_upload_error INTO DATA(lx_error).
        MESSAGE lx_error TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    DATA(lt_result) = mo_updater->process( it_upload    = lt_upload
                                           iv_test_mode = iv_test_mode ).

    NEW lcl_result_view( )->display( CHANGING ct_result = lt_result ).
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
* ABAP Unit tests
*----------------------------------------------------------------------*
CLASS ltd_bp_address_api DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES lif_bp_address_api.
    DATA mv_guid        TYPE bu_address_guid_bapi VALUE '00000000000000000000000000000001'.
    DATA mt_existing    TYPE lif_types=>tt_remarks.
    DATA mt_change_ret  TYPE bapiret2_t.
    DATA mt_sent_x      TYPE lif_types=>tt_remarks_x.
    DATA mv_commits     TYPE i.
    DATA mv_rollbacks   TYPE i.
ENDCLASS.

CLASS ltd_bp_address_api IMPLEMENTATION.
  METHOD lif_bp_address_api~get_standard_address_guid.
    ev_guid = mv_guid.
    CLEAR et_return.
  ENDMETHOD.

  METHOD lif_bp_address_api~get_remarks.
    rt_remarks = mt_existing.
  ENDMETHOD.

  METHOD lif_bp_address_api~change_remarks.
    mt_sent_x = it_remarks_x.
    rt_return = mt_change_ret.
  ENDMETHOD.

  METHOD lif_bp_address_api~commit.
    mv_commits += 1.
  ENDMETHOD.

  METHOD lif_bp_address_api~rollback.
    mv_rollbacks += 1.
  ENDMETHOD.
ENDCLASS.

CLASS ltc_comment_updater DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA mo_api TYPE REF TO ltd_bp_address_api.
    DATA mo_cut TYPE REF TO lcl_comment_updater.

    METHODS setup.
    METHODS run_one
      IMPORTING is_upload        TYPE lif_types=>ty_upload
                iv_test_mode     TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rs_result) TYPE lif_types=>ty_result.

    METHODS insert_new_comment_commits FOR TESTING.
    METHODS existing_comment_is_updated FOR TESTING.
    METHODS test_mode_rolls_back FOR TESTING.
    METHODS bapi_error_rolls_back FOR TESTING.
    METHODS empty_partner_rejected FOR TESTING.
    METHODS too_long_comment_rejected FOR TESTING.
ENDCLASS.

CLASS ltc_comment_updater IMPLEMENTATION.
  METHOD setup.
    mo_api = NEW #( ).
    mo_cut = NEW #( mo_api ).
  ENDMETHOD.

  METHOD run_one.
    rs_result = mo_cut->process( it_upload    = VALUE #( ( is_upload ) )
                                 iv_test_mode = iv_test_mode )[ 1 ].
  ENDMETHOD.

  METHOD insert_new_comment_commits.
    DATA(ls_result) = run_one( VALUE #( row = 2 partner = '0020000000' comments = 'Test' langu = 'EN' ) ).

    cl_abap_unit_assert=>assert_equals( exp = lif_types=>gc_status-success act = ls_result-status ).
    cl_abap_unit_assert=>assert_equals( exp = 'I' act = mo_api->mt_sent_x[ 1 ]-updateflag ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = mo_api->mv_commits ).
  ENDMETHOD.

  METHOD existing_comment_is_updated.
    mo_api->mt_existing = VALUE #( ( langu = 'E' langu_iso = 'EN' adr_notes = 'Old' ) ).

    run_one( VALUE #( row = 2 partner = '0020000000' comments = 'New' langu = 'EN' ) ).

    cl_abap_unit_assert=>assert_equals( exp = 'U' act = mo_api->mt_sent_x[ 1 ]-updateflag ).
  ENDMETHOD.

  METHOD test_mode_rolls_back.
    DATA(ls_result) = run_one( is_upload    = VALUE #( row = 2 partner = '0020000000' comments = 'Test' )
                               iv_test_mode = abap_true ).

    cl_abap_unit_assert=>assert_equals( exp = lif_types=>gc_status-warning act = ls_result-status ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = mo_api->mv_commits ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = mo_api->mv_rollbacks ).
  ENDMETHOD.

  METHOD bapi_error_rolls_back.
    mo_api->mt_change_ret = VALUE #( ( type = 'E' message = 'BP is locked' ) ).

    DATA(ls_result) = run_one( VALUE #( row = 2 partner = '0020000000' comments = 'Test' ) ).

    cl_abap_unit_assert=>assert_equals( exp = lif_types=>gc_status-error act = ls_result-status ).
    cl_abap_unit_assert=>assert_equals( exp = 'BP is locked' act = ls_result-message ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = mo_api->mv_commits ).
  ENDMETHOD.

  METHOD empty_partner_rejected.
    DATA(ls_result) = run_one( VALUE #( row = 2 partner = '0000000000' comments = 'Test' ) ).

    cl_abap_unit_assert=>assert_equals( exp = lif_types=>gc_status-error act = ls_result-status ).
    cl_abap_unit_assert=>assert_initial( mo_api->mt_sent_x ).
  ENDMETHOD.

  METHOD too_long_comment_rejected.
    DATA(ls_result) = run_one( VALUE #( row = 2 partner = '0020000000' comments = repeat( val = 'X' occ = 51 ) ) ).

    cl_abap_unit_assert=>assert_equals( exp = lif_types=>gc_status-error act = ls_result-status ).
    cl_abap_unit_assert=>assert_initial( mo_api->mt_sent_x ).
  ENDMETHOD.
ENDCLASS.
