*================================================================*
*& Technical Consultant  : Hassan Diab (SNAGFREE)----------------*
*================================================================*
*&---------------------------------------------------------------------*
*& Program        : ZFI_BUD_2YF_REPORT
*& Transaction    : ZFI_BUD_2YF_R
*& Type           : Executable Program (Report)
*& Package        : <ZFI>
*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : Ahmed Tawfik
*&---------------------------------------------------------------------*
*& Purpose        : Consolidated Budget Forecast report for the Final
*&                   Reviewers and their assistants, with Excel export
*&                   and the change history of each forecast (double-
*&                   click). The logic is in ZCL_FI_BUD_2YF_REPORT;
*&                   this program only holds the selection screen.
*&---------------------------------------------------------------------*
*& Created By     : Hassan Diab
*& Created On     : 07.10.2026
*& Request No.    : <TBD>
*& Version        : 2.0
*&---------------------------------------------------------------------*
*& Change History
*&---------------------------------------------------------------------*
*& Ver | Date       | Author        | Request No.  | Description
*&-----|------------|---------------|--------------|--------------------
*& 1.0 | 07.10.2026 | Hassan Diab   | <TBD>        | Initial creation.
*& 2.0 | 08.10.2026 | Hassan Diab   | <TBD>        | OOP redesign, change
*&     |            |               |              | history on double-click.
*&---------------------------------------------------------------------*
REPORT zfi_bud_2yf_report.

DATA gs_selection TYPE zfi_bud_fcst_h.  "only for the SELECT-OPTIONS types

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-b01.
  SELECT-OPTIONS: s_bukrs FOR gs_selection-bukrs,
                  s_kostl FOR gs_selection-kostl,
                  s_fyear FOR gs_selection-fyear_from,
                  s_ernam FOR gs_selection-ernam.
SELECTION-SCREEN END OF BLOCK b01.

SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE TEXT-b02.
  PARAMETERS p_xlsx AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK b02.

INITIALIZATION.
  IF CAST zif_fi_bud_2yf_auth( NEW zcl_fi_bud_2yf_auth( ) )->is_final_reviewer( ) = abap_false.
    MESSAGE s023(zbud_fcst) DISPLAY LIKE 'E'.
    LEAVE PROGRAM.
  ENDIF.

START-OF-SELECTION.
  TRY.
      NEW zcl_fi_bud_2yf_report( it_bukrs = s_bukrs[]
                                  it_kostl = s_kostl[]
                                  it_fyear = s_fyear[]
                                  it_ernam = s_ernam[] )->run( iv_download = p_xlsx ).
    CATCH zcx_fi_bud_2yf INTO DATA(gx_error).
      MESSAGE gx_error TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.
