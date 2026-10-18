*&---------------------------------------------------------------------*
*& Object Name    : ZCL_WF_SD_SO_REL_STEP
*& Object Type    : Class (SE24, package ZSD)
*&---------------------------------------------------------------------*
*& Purpose        : Background steps of WS99000010 for the release cycle
*&                   (ZCL_SD_SO_RELEASE). One standard task (PFTC) per
*&                   static method:
*&                     CREDIT_STARTED  - first step of the workflow
*&                     CREDIT_APPROVED - after the final approval
*&                     CREDIT_REJECTED - before the existing cancel step
*&                   All three are "Background processing" tasks with
*&                   synchronous object method.
*&---------------------------------------------------------------------*
*& Status         : DRAFT - not compiled / not tested in SAP
*&---------------------------------------------------------------------*
CLASS ZCL_WF_SD_SO_REL_STEP DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES IF_WORKFLOW.

    "! First step. EV_DUPLICATE = 'X' -> another workflow already runs
    "! for this order; the workflow must end (condition step after it).
    CLASS-METHODS CREDIT_STARTED
      IMPORTING IV_VBELN     TYPE VBELN_VA
                IV_WI_ID     TYPE SWW_WIID
      EXPORTING EV_DUPLICATE TYPE XFELD.

    "! After the final approval (after the credit block is released).
    "! CX_BO_TEMPORARY -> the step goes into retry (order locked in VA02).
    CLASS-METHODS CREDIT_APPROVED
      IMPORTING IV_VBELN TYPE VBELN_VA
      RAISING   CX_BO_TEMPORARY.

    "! Credit rejected: records every line as YSDA / YSDAX decided it.
    "! Runs BEFORE the existing REJECT_STEP, which cancels the order.
    CLASS-METHODS CREDIT_REJECTED
      IMPORTING IV_VBELN TYPE VBELN_VA
                IV_NOTE  TYPE ZWF_NOTE OPTIONAL
                IV_ABGRU TYPE ABGRU_VA OPTIONAL.

ENDCLASS.



CLASS ZCL_WF_SD_SO_REL_STEP IMPLEMENTATION.


  METHOD CREDIT_STARTED.

    EV_DUPLICATE = NEW ZCL_SD_SO_RELEASE( )->ON_CREDIT_STARTED(
                     IV_VBELN = IV_VBELN
                     IV_WI_ID = IV_WI_ID ).

  ENDMETHOD.


  METHOD CREDIT_APPROVED.

    IF NEW ZCL_SD_SO_RELEASE( )->ON_CREDIT_APPROVED( IV_VBELN ) = ABAP_FALSE.
      RAISE EXCEPTION TYPE CX_BO_TEMPORARY.
    ENDIF.

  ENDMETHOD.


  METHOD CREDIT_REJECTED.

    NEW ZCL_SD_SO_RELEASE( )->ON_CREDIT_REJECTED( IV_VBELN = IV_VBELN
                                                  IV_NOTE  = IV_NOTE
                                                  IV_ABGRU = IV_ABGRU ).

  ENDMETHOD.


*--- IF_WORKFLOW (only static methods are used - empty implementations) -
  METHOD BI_PERSISTENT~FIND_BY_LPOR.
  ENDMETHOD.

  METHOD BI_PERSISTENT~LPOR.
  ENDMETHOD.

  METHOD BI_PERSISTENT~REFRESH.
  ENDMETHOD.

  METHOD BI_OBJECT~DEFAULT_ATTRIBUTE_VALUE.
  ENDMETHOD.

  METHOD BI_OBJECT~EXECUTE_DEFAULT_METHOD.
  ENDMETHOD.

  METHOD BI_OBJECT~RELEASE.
  ENDMETHOD.
ENDCLASS.
