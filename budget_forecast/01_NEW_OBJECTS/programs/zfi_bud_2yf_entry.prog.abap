*================================================================*
*& Technical Consultant  : Hassan Diab (SNAGFREE)----------------*
*================================================================*
*&---------------------------------------------------------------------*
*& Program        : ZFI_BUD_2YF_ENTRY
*& Transactions   : ZFI_BUD_2YF_C (Create) / ZFI_BUD_2YF_M (Modify)
*& Type           : Module Pool
*& Package        : <ZFI>
*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : Ahmed Tawfik
*&---------------------------------------------------------------------*
*& Purpose        : UI of the Budget Forecast application (screen 0100).
*&                   The program only holds the screen fields and a
*&                   local screen controller (LCL_SCREEN_0100). All
*&                   business rules, persistence, authorization and the
*&                   e-mail notification are in the global classes
*&                   ZCL_FI_BUD_2YF* (see ZCL_FI_BUD_2YF).
*&                   Called from screen 0001 of ZFI_BUDGET_PREPERATION.
*&---------------------------------------------------------------------*
*& Screens        : 0100 - Create / Modify Budget Forecast
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
*&     |            |               |              | log of every update.
*&---------------------------------------------------------------------*
PROGRAM zfi_bud_2yf_entry.

INCLUDE zfi_bud_2yf_entry_top.   " screen fields + controller definition

INCLUDE zfi_bud_2yf_entry_c01.   " controller implementation

INCLUDE zfi_bud_2yf_entry_pbo.   " PBO modules (delegate to controller)

INCLUDE zfi_bud_2yf_entry_pai.   " PAI modules (delegate to controller)
