*================================================================*
*& Technical Consultant  : Hassan Diab (SNAGFREE)----------------*
*================================================================*
*&---------------------------------------------------------------------*
*& Include        : ZFI_BUDGET_FCST_TOP
*& Main Program   : ZFI_BUDGET_FORECAST
*& Package        : <ZFI>
*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : Ahmed Tawfik
*&---------------------------------------------------------------------*
*& Purpose        : Global declarations for the Budget Forecast
*&                   application: constants for the forecast window and
*&                   the update limit, header and item work areas, the
*&                   item table control and the screen mode flags.
*&---------------------------------------------------------------------*
*& Created By     : Hassan Diab
*& Created On     : 07.10.2026
*& Request No.    : <TBD>
*& Version        : 1.0
*&---------------------------------------------------------------------*

CONSTANTS: GC_TCODE_CREATE TYPE SY-TCODE VALUE 'ZFI_BUD_FCST_C',
           GC_TCODE_MODIFY TYPE SY-TCODE VALUE 'ZFI_BUD_FCST_M',
           GC_TCODE_REPORT TYPE SY-TCODE VALUE 'ZFI_BUD_FCST_R'.

" First forecast year = current calendar year + GC_YEAR_OFFSET.
" 2 -> in 2026 the forecast is 2028-2029 (as in the business template,
" the budget year 2027 itself is covered by Budget Preparation).
" Set to 1 if the forecast must start right after the current year.
CONSTANTS: GC_YEAR_OFFSET TYPE I VALUE 2.

" Maximum number of updates allowed on one forecast submission
CONSTANTS: GC_MAX_CHANGES TYPE I VALUE 2.

CONSTANTS: GC_CURRENCY TYPE WAERS VALUE 'SAR'.

DATA GV_UCOMM LIKE SY-UCOMM.

DATA GV_MODE.        "C: Create, M: Modify
DATA GV_STATUS.      "I: Initial, E: Header Info Entered
DATA GV_READONLY.    "X: Modify mode, but this forecast cannot be changed
DATA GV_INITIALIZED.

DATA GS_HEAD    TYPE ZFI_BUD_FCST_H.  "Header on the screen
DATA GS_HEAD_DB TYPE ZFI_BUD_FCST_H.  "Header as saved in the database

DATA GV_FCST_YEARS(9) TYPE C.         "Listbox value, e.g. '2028-2029'

DATA GV_KTEXT        TYPE CSKT-LTEXT.
DATA GV_CHANGES_TEXT TYPE CHAR20.

DATA GV_PROCEED_TO_ITEMS(50).

DATA: BEGIN OF GS_ITEM,
        SELECTED.
        INCLUDE STRUCTURE ZFI_BUD_FCST_I.
DATA  END OF GS_ITEM.

DATA GT_ITEM LIKE TABLE OF GS_ITEM.

DATA GT_ITEM_DB TYPE TABLE OF ZFI_BUD_FCST_I.  "Items as saved (modify)

CONTROLS: CT_FCST TYPE TABLEVIEW USING SCREEN 0100.
DATA:     G_CT_FCST_LINES LIKE SY-LOOPC.

" Creator roles of ZBUD_CREATORS that allow creating a budget
" (same decode as ROLE_TO_FLAGS in ZFI_BUDGET_PREPERATION)
DATA GR_CREATE_ROLE TYPE RANGE OF ZCREATOR_ROLE.
