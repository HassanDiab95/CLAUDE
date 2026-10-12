*&---------------------------------------------------------------------*
*& Program        : ZBP_COMMENTS_UPLOAD
*& Package        : ZFI
*& Transaction    : ZBPCMT
*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : Nayera Makram
*&---------------------------------------------------------------------*
*& Purpose        : Upload Business Partner address comments (BP >
*&                  Address > Communication > Comments) from an Excel
*&                  file using BAPI_BUPA_ADDRESS_CHANGE, with test run,
*&                  template download and result log.
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

REPORT zbp_comments_upload.

TABLES sscrfields.

INCLUDE zbp_comments_upload_cls.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-b01.
  PARAMETERS: p_file TYPE string LOWER CASE,
              p_test AS CHECKBOX DEFAULT abap_true.
SELECTION-SCREEN END OF BLOCK b01.

SELECTION-SCREEN FUNCTION KEY 1.

INITIALIZATION.
  sscrfields-functxt_01 = VALUE smp_dyntxt( icon_id   = icon_export
                                            icon_text = TEXT-t01
                                            quickinfo = TEXT-t02 ).

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  p_file = lcl_frontend_file=>select_file( ).

AT SELECTION-SCREEN.
  CASE sscrfields-ucomm.
    WHEN 'FC01'.
      NEW lcl_template( )->download( ).
    WHEN 'ONLI'.
      IF p_file IS INITIAL.
        MESSAGE TEXT-e03 TYPE 'E'.
      ENDIF.
      IF lcl_frontend_file=>is_excel( p_file ) = abap_false.
        MESSAGE TEXT-e04 TYPE 'E'.
      ENDIF.
  ENDCASE.

START-OF-SELECTION.
  NEW lcl_app( )->run( iv_file        = p_file
                       iv_skip_header = abap_true
                       iv_test_mode   = p_test ).
