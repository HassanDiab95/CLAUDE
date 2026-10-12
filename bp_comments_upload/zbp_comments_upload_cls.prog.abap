*&---------------------------------------------------------------------*
*& Include        : ZBP_COMMENTS_UPLOAD_CLS
*& Package        : ZFI
*& Transaction    : ZBPCMT
*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : Nayera Makram
*&---------------------------------------------------------------------*
*& Purpose        : Local classes for BP comments upload: Excel reading,
*&                  template download, BP address BAPI wrapper (lock,
*&                  BAPI_BUPA_ADDRESS_CHANGE, commit), customer sync
*&                  check and ALV result log.
*&---------------------------------------------------------------------*
*& Created By     : Hassan Diab
*& Created On     : 12.10.2026
*& Request No.    : DS4K903324
*& Version        : 1.0
*&---------------------------------------------------------------------*
*& Change History
*&---------------------------------------------------------------------*
*& Ver | Date       | Author        | Request No.  | Description
*&-----|------------|---------------|--------------|--------------------
*& 1.0 | 12.10.2026 | Hassan Diab   | DS4K903324   | Initial creation.
*&---------------------------------------------------------------------*

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

    ty_address_guid      TYPE bapibus1006_addresses_int-addrguid,
    ty_address_guid_bapi TYPE but020-guid,
    tt_remarks      TYPE STANDARD TABLE OF bapiad_rem WITH DEFAULT KEY,
    tt_remarks_x    TYPE STANDARD TABLE OF bapiad_rex WITH DEFAULT KEY.

  CONSTANTS:
    BEGIN OF gc_status,
      success TYPE icon_d VALUE '@08@',
      warning TYPE icon_d VALUE '@09@',
      error   TYPE icon_d VALUE '@0A@',
    END OF gc_status.
ENDINTERFACE.

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
        default_extension       = 'xlsx'
        file_filter             = |Excel Files (*.xls,*.xlsx,*.xlsm)\|*.xls;*.xlsx;*.xlsm\|All Files (*.*)\|*.*|
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
      RAISE EXCEPTION TYPE lcx_upload_error EXPORTING iv_text = |File { iv_file } could not be read|.
    ENDIF.

    rv_xstring = cl_bcs_convert=>solix_to_xstring( it_solix = lt_bin
                                                   iv_size  = lv_len ).
  ENDMETHOD.
ENDCLASS.

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
        RAISE EXCEPTION TYPE lcx_upload_error EXPORTING previous = lx_excel.
    ENDTRY.

    IF lr_sheet IS NOT BOUND.
      RAISE EXCEPTION TYPE lcx_upload_error EXPORTING iv_text = TEXT-e01.
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

      IF lv_partner IS INITIAL AND lv_comment IS INITIAL.
        CONTINUE.
      ENDIF.

      INSERT VALUE #( row      = lv_row
                      partner  = |{ lv_partner ALPHA = IN WIDTH = 10 }|
                      comments = lv_comment
                      langu    = lv_langu ) INTO TABLE rt_upload.
    ENDLOOP.

    IF rt_upload IS INITIAL.
      RAISE EXCEPTION TYPE lcx_upload_error EXPORTING iv_text = TEXT-e01.
    ENDIF.
  ENDMETHOD.

  METHOD cell.
    ASSIGN COMPONENT iv_column OF STRUCTURE is_row TO FIELD-SYMBOL(<lv_value>).
    IF sy-subrc = 0.
      rv_value = <lv_value>.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_template DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_template,
        partner  TYPE char10,
        comments TYPE ad_remark1,
        langu    TYPE laiso,
      END OF ty_template,
      tt_template TYPE STANDARD TABLE OF ty_template WITH EMPTY KEY.

    METHODS download.

  PRIVATE SECTION.
    METHODS build_xlsx
      RETURNING VALUE(rv_xlsx) TYPE xstring
      RAISING   cx_salv_error.

    METHODS ask_target_file
      RETURNING VALUE(rv_file) TYPE string.
ENDCLASS.

CLASS lcl_template IMPLEMENTATION.
  METHOD download.
    DATA(lv_file) = ask_target_file( ).
    IF lv_file IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        DATA(lv_xlsx) = build_xlsx( ).
      CATCH cx_salv_error INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    DATA(lt_bin) = cl_bcs_convert=>xstring_to_solix( lv_xlsx ).
    cl_gui_frontend_services=>gui_download(
      EXPORTING
        bin_filesize = xstrlen( lv_xlsx )
        filename     = lv_file
        filetype     = 'BIN'
      CHANGING
        data_tab     = lt_bin
      EXCEPTIONS
        OTHERS       = 1 ).
    IF sy-subrc = 0.
      MESSAGE |Template saved to { lv_file }| TYPE 'S'.
    ELSE.
      MESSAGE |Template could not be saved to { lv_file }| TYPE 'S' DISPLAY LIKE 'E'.
    ENDIF.
  ENDMETHOD.

  METHOD build_xlsx.
    DATA(lt_template) = VALUE tt_template( ( partner  = '20000000'
                                             comments = 'Sample comment'
                                             langu    = 'EN' ) ).

    cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                            CHANGING  t_table      = lt_template ).

    DATA(lo_columns) = lo_alv->get_columns( ).
    lo_columns->get_column( 'PARTNER' )->set_long_text( 'Business Partner' ).
    lo_columns->get_column( 'PARTNER' )->set_medium_text( 'Business Partner' ).
    lo_columns->get_column( 'PARTNER' )->set_short_text( 'BP' ).
    lo_columns->get_column( 'COMMENTS' )->set_long_text( 'Comments' ).
    lo_columns->get_column( 'COMMENTS' )->set_medium_text( 'Comments' ).
    lo_columns->get_column( 'COMMENTS' )->set_short_text( 'Comments' ).
    lo_columns->get_column( 'LANGU' )->set_long_text( 'Language (ISO, optional)' ).
    lo_columns->get_column( 'LANGU' )->set_medium_text( 'Language (ISO)' ).
    lo_columns->get_column( 'LANGU' )->set_short_text( 'Language' ).

    rv_xlsx = lo_alv->to_xml( xml_type = if_salv_bs_xml=>c_type_xlsx ).
  ENDMETHOD.

  METHOD ask_target_file.
    DATA lv_name TYPE string.
    DATA lv_path TYPE string.
    DATA lv_action TYPE i.

    cl_gui_frontend_services=>file_save_dialog(
      EXPORTING
        window_title      = CONV #( TEXT-f02 )
        default_extension = 'xlsx'
        default_file_name = 'BP_Comments_Upload_Template.xlsx'
        file_filter       = |Excel (*.xlsx)\|*.xlsx|
      CHANGING
        filename          = lv_name
        path              = lv_path
        fullpath          = rv_file
        user_action       = lv_action
      EXCEPTIONS
        OTHERS            = 1 ).
    IF sy-subrc <> 0 OR lv_action = cl_gui_frontend_services=>action_cancel.
      CLEAR rv_file.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

INTERFACE lif_bp_address_api.
  METHODS lock
    IMPORTING iv_partner        TYPE bu_partner
    RETURNING VALUE(rv_message) TYPE bapi_msg.

  METHODS unlock
    IMPORTING iv_partner TYPE bu_partner.

  METHODS get_standard_address_guid
    IMPORTING iv_partner     TYPE bu_partner
    EXPORTING ev_guid        TYPE lif_types=>ty_address_guid
              et_return      TYPE bapiret2_t.

  METHODS get_remarks
    IMPORTING iv_partner        TYPE bu_partner
              iv_guid           TYPE lif_types=>ty_address_guid
    RETURNING VALUE(rt_remarks) TYPE lif_types=>tt_remarks.

  METHODS change_remarks
    IMPORTING iv_partner       TYPE bu_partner
              iv_guid          TYPE lif_types=>ty_address_guid
              it_remarks       TYPE lif_types=>tt_remarks
              it_remarks_x     TYPE lif_types=>tt_remarks_x
    RETURNING VALUE(rt_return) TYPE bapiret2_t.

  METHODS get_customer_remark
    IMPORTING iv_partner  TYPE bu_partner
              iv_langu    TYPE spras
    EXPORTING ev_customer TYPE kunnr
              ev_remark   TYPE ad_remark1.

  METHODS commit.
  METHODS rollback.
ENDINTERFACE.

CLASS lcl_bp_address_api DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES lif_bp_address_api.
ENDCLASS.

CLASS lcl_bp_address_api IMPLEMENTATION.
  METHOD lif_bp_address_api~lock.
    CALL FUNCTION 'ENQUEUE_EBU_PARTNR'
      EXPORTING
        partner        = iv_partner
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE 'E' NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO rv_message.
      IF rv_message IS INITIAL.
        rv_message = |BP { iv_partner ALPHA = OUT } is locked|.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD lif_bp_address_api~unlock.
    CALL FUNCTION 'DEQUEUE_EBU_PARTNR'
      EXPORTING
        partner = iv_partner.
  ENDMETHOD.

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
    DATA(lv_guid_bapi) = CONV lif_types=>ty_address_guid_bapi( iv_guid ).

    CALL FUNCTION 'BAPI_BUPA_ADDRESS_GETDETAIL'
      EXPORTING
        businesspartner = iv_partner
        addressguid     = lv_guid_bapi
        reset_buffer    = abap_true
      TABLES
        bapiad_rem      = rt_remarks
        return          = lt_return.
  ENDMETHOD.

  METHOD lif_bp_address_api~change_remarks.
    DATA(lt_remarks)   = it_remarks.
    DATA(lt_remarks_x) = it_remarks_x.

    DATA(lv_guid_bapi) = CONV lif_types=>ty_address_guid_bapi( iv_guid ).

    CALL FUNCTION 'BAPI_BUPA_ADDRESS_CHANGE'
      EXPORTING
        businesspartner = iv_partner
        addressguid     = lv_guid_bapi
      TABLES
        bapiad_rem      = lt_remarks
        bapiad_re_x     = lt_remarks_x
        return          = rt_return.
  ENDMETHOD.

  METHOD lif_bp_address_api~get_customer_remark.
    CLEAR: ev_customer, ev_remark.

    SELECT SINGLE k~kunnr, k~adrnr
      FROM but000 AS b
      INNER JOIN cvi_cust_link AS l ON l~partner_guid = b~partner_guid
      INNER JOIN kna1 AS k          ON k~kunnr        = l~customer
      WHERE b~partner = @iv_partner
      INTO @DATA(ls_customer).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    ev_customer = ls_customer-kunnr.
    SELECT SINGLE remark FROM adrct
      WHERE addrnumber = @ls_customer-adrnr
        AND nation     = @space
        AND langu      = @iv_langu
      INTO @ev_remark.
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

CLASS lcl_comment_updater DEFINITION FINAL.
  PUBLIC SECTION.
    CONSTANTS gc_max_length TYPE i VALUE 50.

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

    METHODS update_comment
      IMPORTING is_upload        TYPE lif_types=>ty_upload
                is_result        TYPE lif_types=>ty_result
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

    rs_result-message = mo_api->lock( is_upload-partner ).
    IF rs_result-message IS NOT INITIAL.
      rs_result-status = lif_types=>gc_status-error.
      RETURN.
    ENDIF.

    rs_result = update_comment( is_upload    = is_upload
                                is_result    = rs_result
                                iv_test_mode = iv_test_mode ).

    mo_api->unlock( is_upload-partner ).
  ENDMETHOD.

  METHOD update_comment.
    rs_result = is_result.

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

    IF iv_test_mode = abap_true.
      mo_api->rollback( ).
      rs_result-status  = lif_types=>gc_status-warning.
      rs_result-message = TEXT-m02.
      RETURN.
    ENDIF.

    mo_api->commit( ).

    mo_api->get_customer_remark( EXPORTING iv_partner  = is_upload-partner
                                           iv_langu    = lv_langu
                                 IMPORTING ev_customer = DATA(lv_customer)
                                           ev_remark   = DATA(lv_cust_remark) ).
    IF lv_customer IS NOT INITIAL AND lv_cust_remark <> rs_result-comments.
      rs_result-status  = lif_types=>gc_status-warning.
      rs_result-message = |BP updated, but customer { lv_customer ALPHA = OUT } | &&
                          |is not synchronised - check CVI (MDS_LOAD_COCKPIT)|.
      RETURN.
    ENDIF.

    rs_result-status  = lif_types=>gc_status-success.
    rs_result-message = TEXT-m01.
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
