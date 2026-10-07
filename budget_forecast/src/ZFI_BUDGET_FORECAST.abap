*================================================================*
*& Technical Consultant  : Hassan Diab (SNAGFREE)----------------*
*================================================================*
*&---------------------------------------------------------------------*
*& Program        : ZFI_BUDGET_FORECAST
*& Transactions   : ZFI_BUD_FCST_C (Create) / ZFI_BUD_FCST_M (Modify)
*& Type           : Module Pool
*& Package        : <ZFI>
*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : Ahmed Tawfik
*&---------------------------------------------------------------------*
*& Purpose        : Budget Forecast application. Lets the Budget
*&                   Preparation creators submit a two year forecast
*&                   budget per company code / cost center, and lets the
*&                   creator of a submission update it at most two
*&                   times. A submission does not go through the Budget
*&                   Preparation workflow: every create and change only
*&                   notifies the Final Reviewers and their assistants
*&                   by e-mail. The consolidated report is the separate
*&                   program ZFI_BUDGET_FORECAST_REP.
*&                   Called from screen 0001 of ZFI_BUDGET_PREPERATION.
*&---------------------------------------------------------------------*
*& Screens        : 0100 - Create / Modify Budget Forecast
*&---------------------------------------------------------------------*
*& Created By     : Hassan Diab
*& Created On     : 07.10.2026
*& Request No.    : <TBD>
*& Version        : 1.0
*&---------------------------------------------------------------------*
*& Change History
*&---------------------------------------------------------------------*
*& Ver | Date       | Author        | Request No.  | Description
*&-----|------------|---------------|--------------|--------------------
*& 1.0 | 07.10.2026 | Hassan Diab   | <TBD>        | Initial creation.
*&---------------------------------------------------------------------*
PROGRAM ZFI_BUDGET_FORECAST MESSAGE-ID ZBUD_FCST.

INCLUDE ZFI_BUDGET_FCST_TOP.

INCLUDE ZFI_BUDGET_FCST_F01.

INCLUDE ZFI_BUDGET_FCST_PBO.

INCLUDE ZFI_BUDGET_FCST_PAI.
