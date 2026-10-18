*&---------------------------------------------------------------------*
*& Object Name    : MV45AFZZ / FORM USEREXIT_SAVE_DOCUMENT
*& Enhancement    : ZEN_CMEXOD_KILL_WORKFLOW
*& Object Type    : Enhancement Implementation (implicit, SD user exit)
*& Package        : ZSD
*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : Nourhan Leila
*&---------------------------------------------------------------------*
*& Purpose        : When a sales order that is in credit approval is
*&                   changed and saved, cancel the running approval so
*&                   the credit check can run again on the new values.
*& Description    : Fires only in change mode on an order that carries
*&                   a ZSD_WF_SO lock row. The actual kill, the log
*&                   closing and the lock removal are done by
*&                   ZCL_WF_SD_CREDIT->KILL_RUNNING_WORKFLOW.
*& Note           : STATICS LT_DONE prevents a second save inside the
*&                   same program run from killing the workflow that
*&                   the first save has just started. The class side
*&                   guard (LT_WI IS INITIAL) is the second line of
*&                   defence and must be in place as well.
*&---------------------------------------------------------------------*
*& Created By     : Hassan Diab
*& Created On     : 04.10.2026
*& Request No.    : DE3K932647
*& Version        : 2.0
*&---------------------------------------------------------------------*
*& Change History
*&---------------------------------------------------------------------*
*& Ver | Date       | Author      | Request No.  | Description
*&-----|------------|-------------|--------------|---------------------
*& 1.0 | 04.10.2026 | Hassan Diab | DE3K932647   | Initial Version
*& 2.0 | 19.10.2026 | Hassan Diab | DE3K932647   | Re-entrancy guard,
*&     |            |             |              | BREAK-POINT removed
*&---------------------------------------------------------------------*

ENHANCEMENT 1  ZEN_CMEXOD_KILL_WORKFLOW.    "active version

*--- Begin of Enhancement | Hassan Diab | kill on change --------------
* The ZSD_WF_SO row alone does not prove that an older run is active.
* A workflow started earlier in this same save inserts it too, and at
* that moment its work items do not exist yet. Killing there closed
* the new log and removed the lock while the workflow kept running.

  STATICS LT_DONE TYPE SORTED TABLE OF VBELN_VA WITH UNIQUE DEFAULT KEY.

  CHECK ( T180-TRTYP = 'V' AND T180-TCODE = 'VA02' )
     AND VBAK-VBELN IS NOT INITIAL.

  READ TABLE LT_DONE TRANSPORTING NO FIELDS
       WITH KEY TABLE_LINE = VBAK-VBELN.
  CHECK SY-SUBRC <> 0.

  DATA(LO_CREDIT) = NEW ZCL_WF_SD_CREDIT( ).

  CHECK LO_CREDIT->IS_ORDER_LOCKED( VBAK-VBELN ) = ABAP_TRUE.

  INSERT VBAK-VBELN INTO TABLE LT_DONE.

  LO_CREDIT->KILL_RUNNING_WORKFLOW(
    IV_VBELN  = VBAK-VBELN
    IV_REASON = |Sales order changed in { SY-TCODE } by { SY-UNAME }. | &&
                |Approval cancelled, credit check will re-run.| ).

*--- End of Enhancement -----------------------------------------------

ENDENHANCEMENT.
