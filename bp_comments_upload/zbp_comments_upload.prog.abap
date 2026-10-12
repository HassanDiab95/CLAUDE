*&---------------------------------------------------------------------*
*& Report ZBP_COMMENTS_UPLOAD
*&---------------------------------------------------------------------*
*& Upload Business Partner address "Comments" (BP > Address >
*& Communication > Comments, table ADRCT-REMARK) from an Excel file.
*&
*& Excel layout (first worksheet, first row = header):
*&   Column A : Business Partner number   (e.g. 20000000)
*&   Column B : Comments                  (max. 50 characters)
*&   Column C : Language (optional, ISO e.g. EN / AR, default logon lang.)
*&
*& Update is done through the standard BAPI BAPI_BUPA_ADDRESS_CHANGE
*& (table BAPIADREM) on the BP standard address. All non-released
*& calls (GUI upload, BAPIs, COMMIT) are encapsulated behind
*& interfaces so the business logic stays testable (ABAP Unit).
*&---------------------------------------------------------------------*
REPORT zbp_comments_upload.

INCLUDE zbp_comments_upload_cls.

*----------------------------------------------------------------------*
* Selection screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-b01.
  PARAMETERS: p_file TYPE string LOWER CASE OBLIGATORY,
              p_head AS CHECKBOX DEFAULT abap_true,
              p_test AS CHECKBOX DEFAULT abap_true.
SELECTION-SCREEN END OF BLOCK b01.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  p_file = lcl_frontend_file=>select_file( ).

START-OF-SELECTION.
  NEW lcl_app( )->run( iv_file        = p_file
                       iv_skip_header = p_head
                       iv_test_mode   = p_test ).
