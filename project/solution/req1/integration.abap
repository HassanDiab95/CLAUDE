*======================================================================*
* REQ1 - integration points for ZCL_SD_SO_RELEASE
* DRAFT - not compiled / not tested in SAP
*======================================================================*


*----------------------------------------------------------------------*
* 1. MV45AFZZ - FORM USEREXIT_SAVE_DOCUMENT
*    Replaces ENHANCEMENT ZEN_CMEXOD_KILL_WORKFLOW (kill only in VA02).
*    Runs for every save: VA01, VA02, BAPI, YSDA, ZSD_MASS_CLOSING ...
*----------------------------------------------------------------------*
ENHANCEMENT 1  ZEN_SO_RELEASE_SAVE.    "active version
  NEW ZCL_SD_SO_RELEASE( )->ON_ORDER_SAVED(
    IS_ORDER  = VALUE #( VBELN = VBAK-VBELN
                         BUKRS = VBAK-BUKRS_VF
                         VKORG = VBAK-VKORG
                         AUART = VBAK-AUART
                         KNKLI = VBAK-KNKLI
                         KKBER = VBAK-KKBER
                         WAERK = VBAK-WAERK
                         NETWR = VBAK-NETWR
                         ZTERM = VALUE #( XVBKD[ POSNR = '000000' ]-ZTERM OPTIONAL ) )
    IT_ITEMS  = CORRESPONDING #( XVBAP[] )
    IV_HAS_CN = XSDBOOL( LINE_EXISTS( XVBEP[ ETTYP = 'CN' ] ) ) ).
ENDENHANCEMENT.


*----------------------------------------------------------------------*
* 2. MV45AFZZ - FORM USEREXIT_DELETE_DOCUMENT
*    Add next to ZEN_CMEXOD_KILL_WORKFLOW_WDEL (or replace it).
*----------------------------------------------------------------------*
ENHANCEMENT 1  ZEN_SO_RELEASE_DELETE.    "active version
  CHECK XVBAK_UPDKZ = 'D' AND VBAK-VBELN IS NOT INITIAL.
  NEW ZCL_SD_SO_RELEASE( )->ON_ORDER_DELETED( VBAK-VBELN ).
ENDENHANCEMENT.


*----------------------------------------------------------------------*
* 3. MV45AFZZ - FORM USEREXIT_SAVE_DOCUMENT_PREPARE
*    Credit release only through the workflow while it runs.
*    Message ZSD_WF 015 to create: "Order &1 is in credit approval
*    workflow, release only through the workflow".
*----------------------------------------------------------------------*
ENHANCEMENT 1  ZEN_SO_RELEASE_NO_VKM.    "active version
  IF ( SY-TCODE = 'VKM1' OR SY-TCODE = 'VKM3' OR SY-TCODE = 'VKM4' )
     AND NEW ZCL_SD_SO_RELEASE( )->IS_IN_CREDIT_APPROVAL( VBAK-VBELN ) = ABAP_TRUE.
    MESSAGE E015(ZSD_WF) WITH VBAK-VBELN.
  ENDIF.
ENDENHANCEMENT.


*----------------------------------------------------------------------*
* 4. MV45AFZZ - FORM USEREXIT_MOVE_FIELD_TO_VBEP, ZSD_CHECK_APPROVAL
*    After the existing "not yet approved via YSDAX/YSDA" check.
*----------------------------------------------------------------------*
      IF VBEP-ETTYP <> 'CN'
         AND NEW ZCL_SD_SO_RELEASE( )->IS_PRODUCTION_RELEASE_ALLOWED( VBEP-VBELN ) = ABAP_FALSE.
        MESSAGE 'Change Schedule Line Error: credit approval workflow not yet completed' TYPE 'E'.
      ENDIF.

* Same enhancement, existing bug: ZSOAPPROVAL-BUKRS holds the PLANT
* (YSDA writes APPRV_WA-BUKRS = BUKRS, and that screen field is the
* plant). Replace   AND BUKRS = VBAK-BUKRS_VF
* with              AND BUKRS = VBAP-WERKS
* otherwise plants 1202 / 1501 never find their approval.


*----------------------------------------------------------------------*
* 5. MV45AFZZ - FORM USEREXIT_READ_DOCUMENT, ZEN_DISAB_VA02_CM_WF_RUNNINNG
*    Only if question 3 is answered "allow VA02 during the workflow":
*    keep the VA03 redirect only for orders NOT managed by the cycle.
*----------------------------------------------------------------------*
  CHECK SY-TCODE = 'VA02'
     AND VBAK-VBELN IS NOT INITIAL
     AND NEW ZCL_WF_SD_CREDIT( )->IS_ORDER_LOCKED( VBAK-VBELN ) = ABAP_TRUE
     AND NEW ZCL_SD_SO_RELEASE( )->CAN_START_CREDIT_WF( VBAK-VBELN )
         = ZCL_SD_SO_RELEASE=>GC_START-UNMANAGED.
  MESSAGE S014(ZSD_WF) WITH VBAK-VBELN DISPLAY LIKE 'E'.
  SET PARAMETER ID 'AUN' FIELD VBAK-VBELN.
  LEAVE TO TRANSACTION 'VA03' AND SKIP FIRST SCREEN.


*----------------------------------------------------------------------*
* 6. ZCL_WF_SD_CREDIT->IS_START_ALLOWED  (check FM Z_FM_SD_WF_CHECK_CREDIT)
*    After the TVARVC start date check, before CHECK_SO_BLOCK.
*----------------------------------------------------------------------*
    " production orders: YSDA / YSDAX first, and only one workflow
    IF NEW ZCL_SD_SO_RELEASE( )->CAN_START_CREDIT_WF( IV_VBELN )
       = ZCL_SD_SO_RELEASE=>GC_START-NO.
      RETURN.
    ENDIF.


*----------------------------------------------------------------------*
* 7. YSDA and YSDAX - FORM SCREEN_START
*    Inside SELECT ... ENDSELECT, right after the INTO list:
*    approved items stay CN while the credit workflow runs, but are
*    not shown again.
*----------------------------------------------------------------------*
      SELECT SINGLE @ABAP_TRUE FROM ZSOAPPROVAL
        WHERE VBELN      = @SO_WA-SO_NUM
          AND POSNR      = @SO_WA-POSNR
          AND SD_APPROVE = 'X'
          AND FI_APPROVE = 'X'
        INTO @DATA(LV_APPROVED).
      IF SY-SUBRC = 0.
        CLEAR: SO_WA, LV_APPROVED.     " INTO list does not fill all fields
        CONTINUE.
      ENDIF.


*----------------------------------------------------------------------*
* 8. YSDA and YSDAX - FORM APPROVE_FUN
*    a) Replace the whole body of
*         IF SD_APPROVE = 'X' AND FI_APPROVE = 'X'. ... ENDIF.
*       (the SELECT ETENR / BAPI CN->CP / commit) with:
*----------------------------------------------------------------------*
    IF SD_APPROVE = 'X' AND FI_APPROVE = 'X'.

      " the release class decides: CN->CP now, or credit workflow first
      NEW ZCL_SD_SO_RELEASE( )->ON_COSTING_DECISION( SO_WA-SO_NUM ).

      WA_LOG-LOGDATE = SY-DATUM.
      WA_LOG-TIME    = SY-UZEIT.
      WA_LOG-USER_NAME = SY-UNAME.
      WA_LOG-EVENT   = 'APPROVAL'.
      WA_LOG-SO_NUMBER = SO_WA-SO_NUM.
      " ... existing log number logic and INSERT YSP_MTOSO_LOG unchanged

    ENDIF.

*    b) YSDA only - ELSEIF ZPOSNUM = 'FI' branch: keep clearing Z8 but
*       delete the SELECT ETENR ... ENDSELECT and the SCHEDULE_LINES /
*       SCHEDULE_LINESX parameters of that BAPI call. FI approval alone
*       must not release production any more. Also REFRESH
*       ORDER_ITEM_IN, ORDER_ITEM_INX, LT_SCHDL, LT_SCHDLX, LT_RETURN
*       at the start of each selected row (today they keep the lines of
*       the previous row).


*----------------------------------------------------------------------*
* 9. YSDA and YSDAX - FORM REJECT_FUN, after BAPI_TRANSACTION_COMMIT
*----------------------------------------------------------------------*
  NEW ZCL_SD_SO_RELEASE( )->ON_COSTING_DECISION( SO_WA-SO_NUM ).


*----------------------------------------------------------------------*
* 10. Workflow WS99000010 - three background steps
*     (place to confirm with the workflow classes, question 8)
*----------------------------------------------------------------------*
*  a) First step, before the approver levels are read:
*       ON_CREDIT_STARTED( IV_VBELN = &SALES_ORDER&  IV_WI_ID = &_WORKITEM.ID& )
*     Result = duplicate -> condition step -> end the workflow
*     (another workflow is already running for this order).
*
*  b) After the final approval (where the credit block is released):
*       ON_CREDIT_APPROVED( &SALES_ORDER& )      -> CN -> CP
*     Raise CX_BO_TEMPORARY in the wrapper if it returns false, so the
*     step retries (order locked in VA02); the job is the second net.
*
*  c) After the rejection:
*       ON_CREDIT_REJECTED( IV_VBELN = &SALES_ORDER&  IV_NOTE = <decision note> )
*
*  Wrapper for a workflow class (must implement IF_WORKFLOW):
  METHOD RELEASE_AFTER_CREDIT.          " IMPORTING IV_VBELN  RAISING CX_BO_TEMPORARY
    IF NEW ZCL_SD_SO_RELEASE( )->ON_CREDIT_APPROVED( IV_VBELN ) = ABAP_FALSE.
      RAISE EXCEPTION TYPE CX_BO_TEMPORARY.
    ENDIF.
  ENDMETHOD.


*----------------------------------------------------------------------*
* 11. Job ZSD_SO_REL_RECONCILE - every 30 minutes
*----------------------------------------------------------------------*
REPORT ZSD_SO_REL_RECONCILE.

SELECT VBELN
  FROM ZSD_SO_REL_H
  WHERE OVERALL_STATUS IN ( '1', '2' )        " not released, not rejected
     OR PROD_STATUS    = 'E'                  " release failed
  INTO TABLE @DATA(LT_ORDER).

DATA(LO_REL) = NEW ZCL_SD_SO_RELEASE( ).

LOOP AT LT_ORDER INTO DATA(LS_ORDER).
  DATA(LV_NOTE) = LO_REL->RECONCILE( LS_ORDER-VBELN ).
  IF LV_NOTE IS NOT INITIAL.
    WRITE: / LS_ORDER-VBELN, LV_NOTE.
  ENDIF.
ENDLOOP.

COMMIT WORK.


*----------------------------------------------------------------------*
* 12. Monitor (recommended): ALV report ZSD_SO_REL_MON on ZSD_SO_REL_H
*     with drill-down to ZSD_SO_REL_LOG, VA03 and the work item (SWI1).
*     Selection: sales org, order, overall status, dates.
*----------------------------------------------------------------------*
