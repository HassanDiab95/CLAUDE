CLASS ZSD_WF_CREDIT_EXCEED_SO DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES BI_OBJECT .
    INTERFACES BI_PERSISTENT .
    INTERFACES IF_WORKFLOW .

    "for log
    METHODS GET_APPROVERS
      IMPORTING
        !BUSINESS_PARTNER           TYPE KUNAG OPTIONAL
        !OLD_USAGE                  TYPE UKM_CREDIT_USAGE OPTIONAL
        !NEW_USAGE                  TYPE UKM_CREDIT_USAGE OPTIONAL
        !REQ_LIMIT                  TYPE UKM_CREDIT_LIMIT OPTIONAL
        !CUR_LIMIT                  TYPE UKM_CREDIT_USAGE OPTIONAL
        !NEW_LIMIT                  TYPE UKM_CREDIT_USAGE OPTIONAL
        !OLD_LIMIT                  TYPE UKM_CREDIT_USAGE OPTIONAL
        !SALES_ORDER                TYPE VBAK-VBELN OPTIONAL
      EXPORTING
        !LEVELS                     TYPE INT2
        !CURRENT_LEVEL              TYPE INT2
        !LEVELS_OD                  TYPE INT2
        !CURRENT_LEVEL_OD           TYPE INT2
        VALUE(BP_NAME)              TYPE CHAR100
        !CREDIT_EXCEED_PER          TYPE UKM_COMM_ACTUAL
        !CREDIT_EXCEED_CURR         TYPE UKM_COMM_ACTUAL
        !OVER_DAYS                  TYPE INT2
        !OVER_PERCENT               TYPE NETWR
      CHANGING
        !CURRENCY                   TYPE UKM_SGM_CURRENCY OPTIONAL
        VALUE(USERS_WI)             TYPE ZWF_USERS_WI_TY OPTIONAL
        VALUE(USERS_OD)             TYPE ZWF_USERS_TY OPTIONAL
        VALUE(USERS_OD_WI)          TYPE ZWF_USERS_WI_TY OPTIONAL
        VALUE(EXCEED_FLAG)          TYPE CHAR1 OPTIONAL
        VALUE(OVERDUE_FLAG)         TYPE CHAR1 OPTIONAL
        VALUE(COMPANY_CODE)         TYPE BUKRS OPTIONAL
        VALUE(PAYMENT_TERM_TXT)     TYPE TEXT1_052 OPTIONAL
        VALUE(CREDIT_LIMIT_BIND)    TYPE UKM_CREDIT_LIMIT OPTIONAL
        VALUE(OVER_AMOUNT)          TYPE DMBTR OPTIONAL
        VALUE(LAST_EXCEPTION_DATE)  TYPE CMFRE OPTIONAL
        VALUE(LAST_EXCEPTION_VALUE) TYPE AMTBL_CM OPTIONAL
        VALUE(LOG_ID)               TYPE ZWF_LOG_ID OPTIONAL
        VALUE(LOG_ID_OD)            TYPE ZWF_LOG_ID OPTIONAL
        VALUE(COMBINED_FLAG)        TYPE CHAR1 OPTIONAL
      RETURNING
        VALUE(USERS)                TYPE ZWF_USERS_TY .
    METHODS REJECT_IN_LOOP
      IMPORTING
        !USERS         TYPE ZWF_USERS_TY OPTIONAL
        !CURRENT_LEVEL TYPE INT2 OPTIONAL
        !LOG_ID        TYPE ZWF_LOG_ID OPTIONAL
        !LOG_ID_OD     TYPE ZWF_LOG_ID OPTIONAL
        !LOG_AREA      TYPE CHAR2 DEFAULT 'EX'
        !WORK_ITEM_ID  TYPE SWW_WIID OPTIONAL
      CHANGING
        !REJECT_FLAG   TYPE CHAR1 OPTIONAL
        !APPROVE_FLAG  TYPE CHAR1 OPTIONAL .
    METHODS APPROVE_IN_LOOP
      IMPORTING
        !USERS         TYPE ZWF_USERS_TY OPTIONAL
        !LEVELS        TYPE INT2 OPTIONAL
        !LOG_ID        TYPE ZWF_LOG_ID OPTIONAL
        !LOG_ID_OD     TYPE ZWF_LOG_ID OPTIONAL
        !LOG_AREA      TYPE CHAR2 DEFAULT 'EX'
        !WORK_ITEM_ID  TYPE SWW_WIID OPTIONAL
      CHANGING
        !CURRENT_LEVEL TYPE INT2 OPTIONAL
        !FINAL_FLAG    TYPE CHAR1 OPTIONAL
        !APPROVE_FLAG  TYPE CHAR1 OPTIONAL
        !REJECT_FLAG   TYPE CHAR1 OPTIONAL .
    METHODS CREDIT_LIMIT_ACTION
      IMPORTING
        !BUSINESS_PARTNER TYPE BUT000-PARTNER OPTIONAL
        !I_OK             TYPE CHAR1 OPTIONAL
        !CURRENT_CREDIT   TYPE UKMBP_CMS_SGM-CREDIT_LIMIT OPTIONAL
        !REQ_LIMIT        TYPE UKMBP_CMS_SGM-CREDIT_LIMIT OPTIONAL
        !NEW_LIMIT        TYPE UKMBP_CMS_SGM-CREDIT_LIMIT OPTIONAL
        !OLD_LIMIT        TYPE UKMBP_CMS_SGM-CREDIT_LIMIT OPTIONAL
        !CREDIT_SEGMENT   TYPE UKM_CREDIT_SGMNT OPTIONAL
      EXPORTING
        !RETURN_MESSAGE   TYPE CHAR50 .
    METHODS CHECK_BUSINESS_PARTNER
      IMPORTING
        !BUSINESS_PARTNER_IN  TYPE BU_PARTNER
        !CREDIT_SEGMENT       TYPE UKM_CREDIT_SGMNT
        !REQ_LIMIT            TYPE UKMBP_CMS_SGM-CREDIT_LIMIT
      EXPORTING
        !BUSINESS_PARTNER_OUT TYPE BU_PARTNER .
    METHODS CHECK_SO_BLOCK
      IMPORTING
        !VBELN TYPE VBELN_VL
      EXPORTING
        !BLOCK TYPE CMPS_CM .
    METHODS RELEASE_SO
      IMPORTING
        VALUE(SALES_ORDER)    TYPE VBAK-VBELN OPTIONAL
        !LOG_ID               TYPE ZWF_LOG_ID OPTIONAL
        !LOG_ID_OD            TYPE ZWF_LOG_ID OPTIONAL
      EXPORTING
        VALUE(RETURN_MESSAGE) TYPE CHAR50 .
    METHODS CANCEL_SO
      IMPORTING
        !SALES_ORDER    TYPE VBAK-VBELN
        !REASON         TYPE VBAP-ABGRU DEFAULT '00'
        !LOG_ID         TYPE ZWF_LOG_ID OPTIONAL
        !LOG_ID_OD      TYPE ZWF_LOG_ID OPTIONAL
      EXPORTING
        !RETURN_MESSAGE TYPE CHAR50 .
    METHODS CREATE_INSTANCE_BO
      IMPORTING
        VALUE(IV_BP_ID) TYPE BP000-PARTNER OPTIONAL
        !WORK_ITEM_ID   TYPE SWWWIHEAD-WI_ID OPTIONAL
      EXPORTING
        !BO             TYPE SIBFLPORB .
    METHODS NOTIFY_START
      IMPORTING
        !LOG_ID        TYPE ZWF_LOG_ID OPTIONAL
        !LOG_AREA      TYPE CHAR2 DEFAULT 'EX'
        !CURRENT_LEVEL TYPE INT2 OPTIONAL
        !WORK_ITEM_ID  TYPE SWW_WIID OPTIONAL .

    METHODS BUILD_ALERT
      IMPORTING
        !LOG_ID        TYPE ZWF_LOG_ID OPTIONAL
        !LOG_ID_OD     TYPE ZWF_LOG_ID OPTIONAL
        !CURRENT_LEVEL TYPE INT2 OPTIONAL
      EXPORTING
        !ALERT_HTML    TYPE RSWEBPUB_T_W3HTML .
  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES ZWF_USERS TYPE ZWF_USERS .



ENDCLASS.



CLASS ZSD_WF_CREDIT_EXCEED_SO IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZSD_WF_CREDIT_EXCEED_SO->APPROVE_IN_LOOP
* +-------------------------------------------------------------------------------------------------+
* | [--->] USERS                          TYPE        ZWF_USERS_TY(optional)
* | [--->] LEVELS                         TYPE        INT2(optional)
* | [--->] LOG_ID                         TYPE        ZWF_LOG_ID(optional)
* | [--->] LOG_ID_OD                      TYPE        ZWF_LOG_ID(optional)
* | [--->] LOG_AREA                       TYPE        CHAR2 (default ='EX')
* | [--->] WORK_ITEM_ID                   TYPE        SWW_WIID(optional)
* | [<-->] CURRENT_LEVEL                  TYPE        INT2(optional)
* | [<-->] FINAL_FLAG                     TYPE        CHAR1(optional)
* | [<-->] APPROVE_FLAG                   TYPE        CHAR1(optional)
* | [<-->] REJECT_FLAG                    TYPE        CHAR1(optional)
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD APPROVE_IN_LOOP.

    APPROVE_FLAG = 'X'.
    CLEAR REJECT_FLAG.

    DATA(LV_FROM) = CURRENT_LEVEL.

    DATA GS_ACTOR TYPE ZWF_USERS.
    GS_ACTOR = VALUE #( USERS[ SEQUENCE = LV_FROM ] OPTIONAL ) .

    DATA(LV_NOTE) = ZCL_WF_NOTE_READER=>READ_FROM_WI( WORK_ITEM_ID ).

    DATA(LV_NEXT) = CURRENT_LEVEL.

    IF CURRENT_LEVEL = LEVELS.
      FINAL_FLAG = 'X'.
    ELSE.
      DATA GS_NEXT TYPE ZWF_USERS.
      LOOP AT USERS INTO GS_NEXT WHERE SEQUENCE > CURRENT_LEVEL.
        CURRENT_LEVEL = GS_NEXT-SEQUENCE.
        LV_NEXT       = GS_NEXT-SEQUENCE.
        EXIT.
      ENDLOOP.
    ENDIF.

    DATA(LV_ACTION) = COND ZWF_ACTION(
      WHEN FINAL_FLAG = 'X'
      THEN ZCL_WF_LOG_EX=>GC_ACTION-FINAL
      ELSE ZCL_WF_LOG_EX=>GC_ACTION-APPROVE ).

    DATA(LV_TO) = COND INT2( WHEN FINAL_FLAG = 'X'
                             THEN LV_FROM
                             ELSE LV_NEXT ).

*--- Begin of Enhancement | Hassan Diab | write to both logs ----------
    IF LOG_ID IS NOT INITIAL AND LOG_AREA <> 'OD'.

      DATA(LO_EX) = NEW ZCL_WF_LOG_EX( ).

      LO_EX->ADD_ITEM( IV_LOG_ID     = LOG_ID
                       IV_ACTION     = LV_ACTION
                       IV_WI_ID      = WORK_ITEM_ID
                       IV_LEVEL_FROM = LV_FROM
                       IV_LEVEL_TO   = LV_TO
                       IV_AGENT      = GS_ACTOR-BNAME
                       IV_AGENT_DESC = GS_ACTOR-USER_DESC
                       IV_NOTE       = LV_NOTE ).

      IF FINAL_FLAG = 'X'.
        LO_EX->FINISH( IV_LOG_ID = LOG_ID
                       IV_STATUS = ZCL_WF_LOG_EX=>GC_STATUS-APPROVED ).
      ELSE.
        LO_EX->SET_LEVEL( IV_LOG_ID = LOG_ID IV_LEVEL = LV_NEXT ).
      ENDIF.

    ENDIF.

    DATA(LV_OD_LOG) = COND ZWF_LOG_ID( WHEN LOG_AREA = 'OD'
                                       THEN LOG_ID
                                       ELSE LOG_ID_OD ).

    IF LV_OD_LOG IS NOT INITIAL.

      DATA(LO_OD) = NEW ZCL_WF_LOG_OD( ).

      LO_OD->ADD_ITEM( IV_LOG_ID     = LV_OD_LOG
                       IV_ACTION     = LV_ACTION
                       IV_WI_ID      = WORK_ITEM_ID
                       IV_LEVEL_FROM = LV_FROM
                       IV_LEVEL_TO   = LV_TO
                       IV_AGENT      = GS_ACTOR-BNAME
                       IV_AGENT_DESC = GS_ACTOR-USER_DESC
                       IV_NOTE       = LV_NOTE ).

      IF FINAL_FLAG = 'X'.
        LO_OD->FINISH( IV_LOG_ID = LV_OD_LOG
                       IV_STATUS = ZCL_WF_LOG_OD=>GC_STATUS-APPROVED ).
      ELSE.
        LO_OD->SET_LEVEL( IV_LOG_ID = LV_OD_LOG IV_LEVEL = LV_NEXT ).
      ENDIF.

    ENDIF.
*--- End of Enhancement -----------------------------------------------

*--- Begin of Enhancement | Hassan Diab | notify the next approver ----
* One mail per approval, not one per log. The combined case passes
* both log ids so the mail shows the exceed and the overdue blocks.

    IF FINAL_FLAG <> 'X'.

      DATA(LV_MAIL_AREA) = COND CHAR2(
        WHEN LOG_AREA = 'OD'
        THEN ZCL_WF_MAIL_CREDIT=>GC_KIND-OVERDUE
        ELSE ZCL_WF_MAIL_CREDIT=>GC_KIND-EXCEED ).

      NEW ZCL_WF_MAIL_CREDIT( )->NOTIFY_FROM_LOG(
        IV_AREA      = LV_MAIL_AREA
        IV_LOG_ID    = LOG_ID
        IV_LEVEL     = LV_NEXT
        IV_WI_ID     = WORK_ITEM_ID ).

    ENDIF.
*--- End of Enhancement -----------------------------------------------

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZSD_WF_CREDIT_EXCEED_SO->BI_OBJECT~DEFAULT_ATTRIBUTE_VALUE
* +-------------------------------------------------------------------------------------------------+
* | [<-()] RESULT                         TYPE REF TO DATA
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD BI_OBJECT~DEFAULT_ATTRIBUTE_VALUE.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZSD_WF_CREDIT_EXCEED_SO->BI_OBJECT~EXECUTE_DEFAULT_METHOD
* +-------------------------------------------------------------------------------------------------+
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD BI_OBJECT~EXECUTE_DEFAULT_METHOD.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZSD_WF_CREDIT_EXCEED_SO->BI_OBJECT~RELEASE
* +-------------------------------------------------------------------------------------------------+
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD BI_OBJECT~RELEASE.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZSD_WF_CREDIT_EXCEED_SO=>BI_PERSISTENT~FIND_BY_LPOR
* +-------------------------------------------------------------------------------------------------+
* | [--->] LPOR                           TYPE        SIBFLPOR
* | [<-()] RESULT                         TYPE REF TO BI_PERSISTENT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD BI_PERSISTENT~FIND_BY_LPOR.
    CREATE OBJECT RESULT TYPE ZSD_WF_CREDIT_EXCEED_SO.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZSD_WF_CREDIT_EXCEED_SO->BI_PERSISTENT~LPOR
* +-------------------------------------------------------------------------------------------------+
* | [<-()] RESULT                         TYPE        SIBFLPOR
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD BI_PERSISTENT~LPOR.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZSD_WF_CREDIT_EXCEED_SO->BI_PERSISTENT~REFRESH
* +-------------------------------------------------------------------------------------------------+
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD BI_PERSISTENT~REFRESH.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZSD_WF_CREDIT_EXCEED_SO->CANCEL_SO
* +-------------------------------------------------------------------------------------------------+
* | [--->] SALES_ORDER                    TYPE        VBAK-VBELN
* | [--->] REASON                         TYPE        VBAP-ABGRU (default ='00')
* | [--->] LOG_ID                         TYPE        ZWF_LOG_ID(optional)
* | [--->] LOG_ID_OD                      TYPE        ZWF_LOG_ID(optional)
* | [<---] RETURN_MESSAGE                 TYPE        CHAR50
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD CANCEL_SO.

*    CALL FUNCTION 'DEQUEUE_EVVBAKE'
*     EXPORTING
**       MODE_VBAK       = 'E'
**       MANDT           = SY-MANDT
*       VBELN           = SALES_ORDER
**       X_VBELN         = ' '
**       _SCOPE          = '3'
**       _SYNCHRON       = ' '
**       _COLLECT        = ' '
*              .

    DATA REASON_COPY TYPE VBAP-ABGRU.
    REASON_COPY = REASON.
    IF REASON_COPY IS INITIAL.
      REASON_COPY = '00'.
    ENDIF.
*        CALL FUNCTION 'SD_ORDER_CREDIT_CANCEL'
*      EXPORTING
*        ABGRU = REASON_COPY
*        VBELN = SALES_ORDER.
*
*    IF SY-SUBRC = 0.
*      RETURN_MESSAGE = 'Sales Order Credit is Canceled'.
*    ENDIF.
*
*    DELETE FROM ZSD_WF_SO WHERE SALES_DOCUMENT = SALES_ORDER.

*--- Begin of Enhancement | Hassan Diab | workflow log ----------------
    IF LOG_ID IS NOT INITIAL.
      DATA(LO_EX) = NEW ZCL_WF_LOG_EX( ).
      LO_EX->ADD_ITEM( IV_LOG_ID = LOG_ID
                       IV_ACTION = ZCL_WF_LOG_EX=>GC_ACTION-CANCEL
                       IV_NOTE   = |Cancelled with reason { REASON_COPY }| ).
      LO_EX->FINISH( IV_LOG_ID = LOG_ID
                     IV_STATUS = ZCL_WF_LOG_EX=>GC_STATUS-CANCELLED ).
    ENDIF.

    IF LOG_ID_OD IS NOT INITIAL.
      DATA(LO_OD) = NEW ZCL_WF_LOG_OD( ).
      LO_OD->ADD_ITEM( IV_LOG_ID = LOG_ID_OD
                       IV_ACTION = ZCL_WF_LOG_OD=>GC_ACTION-CANCEL
                       IV_NOTE   = |Cancelled with reason { REASON_COPY }| ).
      LO_OD->FINISH( IV_LOG_ID = LOG_ID_OD
                     IV_STATUS = ZCL_WF_LOG_OD=>GC_STATUS-CANCELLED ).
    ENDIF.
*--- End of Enhancement ----------------------------------------------

    CALL FUNCTION 'SD_ORDER_CREDIT_CANCEL'
      EXPORTING
        ABGRU = REASON_COPY
        VBELN = SALES_ORDER.

    IF SY-SUBRC = 0.
      RETURN_MESSAGE = 'Sales Order Credit is Canceled'.
    ENDIF.
    DELETE FROM ZSD_WF_SO WHERE SALES_DOCUMENT = SALES_ORDER.
*
*    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
*      EXPORTING
*        WAIT = ABAP_TRUE.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZSD_WF_CREDIT_EXCEED_SO->CHECK_BUSINESS_PARTNER
* +-------------------------------------------------------------------------------------------------+
* | [--->] BUSINESS_PARTNER_IN            TYPE        BU_PARTNER
* | [--->] CREDIT_SEGMENT                 TYPE        UKM_CREDIT_SGMNT
* | [--->] REQ_LIMIT                      TYPE        UKMBP_CMS_SGM-CREDIT_LIMIT
* | [<---] BUSINESS_PARTNER_OUT           TYPE        BU_PARTNER
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD CHECK_BUSINESS_PARTNER.
    IF BUSINESS_PARTNER_IN IS INITIAL OR BUSINESS_PARTNER_IN CA '#' .
      SELECT MAX( PARTNER ) FROM UKMBP_CMS_SGM "INNER JOIN UKMCRED_SGM0C ON UKMBP_CMS_SGM~CREDIT_SGMNT = UKMBP_CMS_SGM~CREDIT_SGMNT
      INTO @BUSINESS_PARTNER_OUT
      WHERE CREDIT_SGMNT = @CREDIT_SEGMENT AND CRED_LIM_REQ = @REQ_LIMIT.
      IF SY-SUBRC <> 0.
        CLEAR BUSINESS_PARTNER_OUT.
      ENDIF.
    ELSE.
      BUSINESS_PARTNER_OUT = BUSINESS_PARTNER_IN.
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZSD_WF_CREDIT_EXCEED_SO->CHECK_SO_BLOCK
* +-------------------------------------------------------------------------------------------------+
* | [--->] VBELN                          TYPE        VBELN_VL
* | [<---] BLOCK                          TYPE        CMPS_CM
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD CHECK_SO_BLOCK.
    SELECT SINGLE CMGST, ABSTK FROM VBAK INTO @DATA(MY_BLOCK) WHERE VBELN = @VBELN.

    IF MY_BLOCK-CMGST = 'B' AND MY_BLOCK-ABSTK <> 'C'.
      BLOCK = 'X'.
    ELSE.
      CLEAR BLOCK.
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZSD_WF_CREDIT_EXCEED_SO->CREATE_INSTANCE_BO
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_BP_ID                       TYPE        BP000-PARTNER(optional)
* | [--->] WORK_ITEM_ID                   TYPE        SWWWIHEAD-WI_ID(optional)
* | [<---] BO                             TYPE        SIBFLPORB
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD CREATE_INSTANCE_BO.
    DATA LS_BO TYPE SIBFLPORB.
    LS_BO-INSTID = IV_BP_ID.
    LS_BO-TYPEID = 'ZCUSTOM_BO'.
    LS_BO-CATID  = 'BO'.
    BO = LS_BO.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZSD_WF_CREDIT_EXCEED_SO->CREDIT_LIMIT_ACTION
* +-------------------------------------------------------------------------------------------------+
* | [--->] BUSINESS_PARTNER               TYPE        BUT000-PARTNER(optional)
* | [--->] I_OK                           TYPE        CHAR1(optional)
* | [--->] CURRENT_CREDIT                 TYPE        UKMBP_CMS_SGM-CREDIT_LIMIT(optional)
* | [--->] REQ_LIMIT                      TYPE        UKMBP_CMS_SGM-CREDIT_LIMIT(optional)
* | [--->] NEW_LIMIT                      TYPE        UKMBP_CMS_SGM-CREDIT_LIMIT(optional)
* | [--->] OLD_LIMIT                      TYPE        UKMBP_CMS_SGM-CREDIT_LIMIT(optional)
* | [--->] CREDIT_SEGMENT                 TYPE        UKM_CREDIT_SGMNT(optional)
* | [<---] RETURN_MESSAGE                 TYPE        CHAR50
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD CREDIT_LIMIT_ACTION.
    DATA: MY_CREDIT_SEGMENT TYPE UKMBP_CMS_SGM-CREDIT_SGMNT.

    IF CREDIT_SEGMENT IS NOT INITIAL.
      MY_CREDIT_SEGMENT = CREDIT_SEGMENT.
    ELSE.
      SELECT SINGLE CREDIT_SGMNT FROM UKMBP_CMS_SGM INTO MY_CREDIT_SEGMENT WHERE PARTNER = BUSINESS_PARTNER
      AND CREDIT_LIMIT = CURRENT_CREDIT AND CRED_LIM_REQ = REQ_LIMIT.
    ENDIF.

    IF SY-SUBRC = 0.

      CALL FUNCTION 'ZWFBP_CREDIT_ACTION'
        EXPORTING
          I_PARTNER      = BUSINESS_PARTNER
          I_SEGMENT      = MY_CREDIT_SEGMENT
          I_OK           = I_OK
        IMPORTING
          RETURN_MESSAGE = RETURN_MESSAGE.

    ELSE.
      RETURN_MESSAGE = 'No Credit Segment found with this partner'.
    ENDIF.


  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZSD_WF_CREDIT_EXCEED_SO->GET_APPROVERS
* +-------------------------------------------------------------------------------------------------+
* | [--->] BUSINESS_PARTNER               TYPE        KUNAG(optional)
* | [--->] OLD_USAGE                      TYPE        UKM_CREDIT_USAGE(optional)
* | [--->] NEW_USAGE                      TYPE        UKM_CREDIT_USAGE(optional)
* | [--->] REQ_LIMIT                      TYPE        UKM_CREDIT_LIMIT(optional)
* | [--->] CUR_LIMIT                      TYPE        UKM_CREDIT_USAGE(optional)
* | [--->] NEW_LIMIT                      TYPE        UKM_CREDIT_USAGE(optional)
* | [--->] OLD_LIMIT                      TYPE        UKM_CREDIT_USAGE(optional)
* | [--->] SALES_ORDER                    TYPE        VBAK-VBELN(optional)
* | [<---] LEVELS                         TYPE        INT2
* | [<---] CURRENT_LEVEL                  TYPE        INT2
* | [<---] LEVELS_OD                      TYPE        INT2
* | [<---] CURRENT_LEVEL_OD               TYPE        INT2
* | [<---] BP_NAME                        TYPE        CHAR100
* | [<---] CREDIT_EXCEED_PER              TYPE        UKM_COMM_ACTUAL
* | [<---] CREDIT_EXCEED_CURR             TYPE        UKM_COMM_ACTUAL
* | [<---] OVER_DAYS                      TYPE        INT2
* | [<---] OVER_PERCENT                   TYPE        NETWR
* | [<-->] CURRENCY                       TYPE        UKM_SGM_CURRENCY(optional)
* | [<-->] USERS_WI                       TYPE        ZWF_USERS_WI_TY(optional)
* | [<-->] USERS_OD                       TYPE        ZWF_USERS_TY(optional)
* | [<-->] USERS_OD_WI                    TYPE        ZWF_USERS_WI_TY(optional)
* | [<-->] EXCEED_FLAG                    TYPE        CHAR1(optional)
* | [<-->] OVERDUE_FLAG                   TYPE        CHAR1(optional)
* | [<-->] COMPANY_CODE                   TYPE        BUKRS(optional)
* | [<-->] PAYMENT_TERM_TXT               TYPE        TEXT1_052(optional)
* | [<-->] CREDIT_LIMIT_BIND              TYPE        UKM_CREDIT_LIMIT(optional)
* | [<-->] OVER_AMOUNT                    TYPE        DMBTR(optional)
* | [<-->] LAST_EXCEPTION_DATE            TYPE        CMFRE(optional)
* | [<-->] LAST_EXCEPTION_VALUE           TYPE        AMTBL_CM(optional)
* | [<-->] LOG_ID                         TYPE        ZWF_LOG_ID(optional)
* | [<-->] LOG_ID_OD                      TYPE        ZWF_LOG_ID(optional)
* | [<-->] COMBINED_FLAG                  TYPE        CHAR1(optional)
* | [<-()] USERS                          TYPE        ZWF_USERS_TY
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD GET_APPROVERS.
    DATA(LO_CREDIT) = NEW ZCL_WF_SD_CREDIT( ).
*    IF SALES_ORDER IS NOT INITIAL AND NEW ZCL_WF_SD_CREDIT( )->IS_ORDER_LOCKED( SALES_ORDER ) = ABAP_TRUE.
*      SELECT SINGLE LAST_CHANGED_BY_USER FROM VBAK INTO @DATA(LV_LAST_CHANGED_BY_USER) WHERE VBELN = @SALES_ORDER.
*      LO_CREDIT->KILL_RUNNING_WORKFLOW(
*        IV_VBELN  = SALES_ORDER
*        IV_REASON = |Sales order changed in VA02 by { LV_LAST_CHANGED_BY_USER }. | &&
*                    |Approval killed, credit check will re-run.| ).
*    ENDIF.
    DATA(LS_ORDER) = LO_CREDIT->GET_ORDER_DATA( SALES_ORDER ).

    IF LS_ORDER-BUKRS IS INITIAL.
      RETURN.
    ENDIF.

    COMPANY_CODE = LS_ORDER-BUKRS.

    DATA(LS_PARTNER) = LO_CREDIT->GET_PARTNER_DATA( IV_CUSTOMER = BUSINESS_PARTNER
                                                    IV_KKBER    = LS_ORDER-KKBER ).

    BP_NAME = LS_PARTNER-BP_NAME.

    IF LS_PARTNER-PARTNER IS INITIAL.
      RETURN.
    ENDIF.

    DATA(LS_EXCEPTION) = LO_CREDIT->GET_LAST_EXCEPTION( BUSINESS_PARTNER ).

    LAST_EXCEPTION_DATE  = LS_EXCEPTION-LAST_DATE.
    LAST_EXCEPTION_VALUE = LS_EXCEPTION-LAST_VALUE.

    DATA(LS_CREDIT) = LO_CREDIT->GET_CREDIT_DATA(
      IV_SALESORD_DATA = LS_ORDER
      IV_PARTNER       = LS_PARTNER-PARTNER
      IV_SEGMENT       = LS_PARTNER-CREDIT_SEGMENT ).

    CURRENCY = LS_CREDIT-CURRENCY.

    IF LS_CREDIT-LIMIT <= 0.
      RETURN.
    ENDIF.

    CREDIT_LIMIT_BIND  = LS_CREDIT-LIMIT.
    CREDIT_EXCEED_CURR = LS_CREDIT-EXCEED_CURR.
    CREDIT_EXCEED_PER  = LS_CREDIT-EXCEED_PER.

    IF LS_CREDIT-EXCEED_CURR > 0.

      DATA(LT_EXCEED_RANGES) = LO_CREDIT->GET_EXCEED_RANGES(
        IV_BUKRS  = COMPANY_CODE
        IS_CREDIT = LS_CREDIT ).

      USERS = LO_CREDIT->GET_APPROVERS(
        IV_WF_TYPE      = ZCL_WF_SD_CREDIT=>GC_WF_TYPE-EXCEED
        IV_BUKRS        = COMPANY_CODE
        IV_CREDIT_GROUP = LS_PARTNER-CREDIT_GROUP
        IT_RANGES       = LT_EXCEED_RANGES
        IV_VBELN        = SALES_ORDER ).

*     TESTMETHOD overwrites every approver with the current user.
*     Must stay commented in QAS and PRD.
*      LO_CREDIT->TESTMETHOD( EXPORTING UNAME = SY-UNAME CHANGING USERS = USERS ).

      IF USERS IS NOT INITIAL.
        EXCEED_FLAG   = ABAP_TRUE.
        LEVELS        = LO_CREDIT->GET_MAX_LEVEL( USERS ).
        CURRENT_LEVEL = LO_CREDIT->GET_MIN_LEVEL( USERS ).
        USERS_WI      = LO_CREDIT->BUILD_WI_USERS( USERS ).

*--- Begin of Enhancement | Hassan Diab | exceed log -----------------
        DATA LV_RANGE_EX TYPE ZRANGE_CODE.
        READ TABLE LT_EXCEED_RANGES INDEX 1 INTO LV_RANGE_EX.

        LOG_ID = NEW ZCL_WF_LOG_EX( )->START(
          IS_DATA  = VALUE #( WF_TYPE        = ZCL_WF_SD_CREDIT=>GC_WF_TYPE-EXCEED
                              VBELN          = SALES_ORDER
                              BP_ID          = CONV #( BUSINESS_PARTNER )
                              BP_NAME        = BP_NAME
                              BUKRS          = COMPANY_CODE
                              WERKS          = LS_ORDER-WERKS
                              ERNAM          = LS_ORDER-ERNAM
                              NETWR          = LS_ORDER-NETWR
                              WAERK          = LS_ORDER-WAERK
                              KKBER          = LS_ORDER-KKBER
                              SPART          = LS_ORDER-SPART
                              CREDIT_GROUP   = LS_PARTNER-CREDIT_GROUP
                              RANGE_CODE     = LV_RANGE_EX
                              CUR_LIMIT      = LS_CREDIT-LIMIT
                              EXPOSURE       = LS_CREDIT-EXPOSURE
                              EXCEED_CURR    = LS_CREDIT-EXCEED_CURR
                              EXCEED_PER     = LS_CREDIT-EXCEED_PER
                              CURRENCY       = CURRENCY
                              LAST_EXC_DATE  = LAST_EXCEPTION_DATE
                              LAST_EXC_VALUE = LAST_EXCEPTION_VALUE
                              LEVELS         = LEVELS )
          IT_USERS = USERS ).
*--- End of Enhancement ----------------------------------------------
      ENDIF.
    ENDIF.

    DATA(LS_OVERDUE) = LO_CREDIT->GET_OVERDUE_DATA(
      IV_CUSTOMER = BUSINESS_PARTNER
      IV_BUKRS    = COMPANY_CODE
      IV_VBELN    = SALES_ORDER ).

    OVER_AMOUNT      = LS_OVERDUE-AMOUNT.
    OVER_DAYS        = LS_OVERDUE-DAYS.
    OVER_PERCENT     = LS_OVERDUE-PERCENT.
    PAYMENT_TERM_TXT = LS_OVERDUE-TERM_TEXT.

    IF ( LS_OVERDUE-PERCENT > 0 AND LS_OVERDUE-AMOUNT > 0 ).

      DATA(LT_OVERDUE_RANGES) = LO_CREDIT->GET_OVERDUE_RANGES(
        IV_BUKRS   = COMPANY_CODE
        IV_PERCENT = LS_OVERDUE-PERCENT ).

      USERS_OD = LO_CREDIT->GET_APPROVERS(
        IV_WF_TYPE      = ZCL_WF_SD_CREDIT=>GC_WF_TYPE-OVERDUE
        IV_BUKRS        = COMPANY_CODE
        IV_CREDIT_GROUP = LS_PARTNER-CREDIT_GROUP
        IT_RANGES       = LT_OVERDUE_RANGES
        IV_VBELN        = SALES_ORDER ).

*      LO_CREDIT->TESTMETHOD( EXPORTING UNAME = SY-UNAME CHANGING USERS = USERS_OD ).

      IF USERS_OD IS NOT INITIAL.
        OVERDUE_FLAG     = ABAP_TRUE.
        LEVELS_OD        = LO_CREDIT->GET_MAX_LEVEL( USERS_OD ).
        CURRENT_LEVEL_OD = LO_CREDIT->GET_MIN_LEVEL( USERS_OD ).
        USERS_OD_WI      = LO_CREDIT->BUILD_WI_USERS( USERS_OD ).

*--- Begin of Enhancement | Hassan Diab | overdue log ----------------
        DATA LV_RANGE_OD TYPE ZRANGE_CODE.
        READ TABLE LT_OVERDUE_RANGES INDEX 1 INTO LV_RANGE_OD.
        LOG_ID_OD = NEW ZCL_WF_LOG_OD( )->START(
          IS_DATA  = VALUE #( WF_TYPE          = ZCL_WF_SD_CREDIT=>GC_WF_TYPE-OVERDUE
                              VBELN            = SALES_ORDER
                              BP_ID            = CONV #( BUSINESS_PARTNER )
                              BP_NAME          = BP_NAME
                              BUKRS            = COMPANY_CODE
                              WERKS            = LS_ORDER-WERKS
                              NETWR            = LS_ORDER-NETWR
                              WAERK            = LS_ORDER-WAERK
                              ERNAM            = LS_ORDER-ERNAM
                              KKBER            = LS_ORDER-KKBER
                              SPART            = LS_ORDER-SPART
                              CREDIT_GROUP     = LS_PARTNER-CREDIT_GROUP
                              RANGE_CODE       = LV_RANGE_OD
                              OVER_AMOUNT      = LS_OVERDUE-AMOUNT
                              OVER_DAYS        = LS_OVERDUE-DAYS
                              OVER_PERCENT     = LS_OVERDUE-PERCENT
                              PAYMENT_TERM     = LS_OVERDUE-PAYMENT_TERM
                              PAYMENT_TERM_TXT = LS_OVERDUE-TERM_TEXT
                              CURRENCY         = CURRENCY
                              LEVELS           = LEVELS_OD )
*          IT_USERS = USERS_OD
          IT_USERS = COND #( WHEN EXCEED_FLAG = ABAP_TRUE THEN USERS ELSE USERS_OD )

          ).
*--- End of Enhancement ----------------------------------------------
      ENDIF.

    ENDIF.

*--- Begin of Enhancement | Hassan Diab | combined branch -------------
    IF EXCEED_FLAG = ABAP_TRUE AND OVERDUE_FLAG = ABAP_TRUE.

      CLEAR: OVERDUE_FLAG,
             USERS_OD,
             USERS_OD_WI,
             LEVELS_OD,
             CURRENT_LEVEL_OD.

    ENDIF.
*--- End of Enhancement -----------------------------------------------


    IF EXCEED_FLAG = ABAP_TRUE OR OVERDUE_FLAG = ABAP_TRUE.
      LO_CREDIT->SET_ORDER_LOCK( SALES_ORDER ).
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZSD_WF_CREDIT_EXCEED_SO->REJECT_IN_LOOP
* +-------------------------------------------------------------------------------------------------+
* | [--->] USERS                          TYPE        ZWF_USERS_TY(optional)
* | [--->] CURRENT_LEVEL                  TYPE        INT2(optional)
* | [--->] LOG_ID                         TYPE        ZWF_LOG_ID(optional)
* | [--->] LOG_ID_OD                      TYPE        ZWF_LOG_ID(optional)
* | [--->] LOG_AREA                       TYPE        CHAR2 (default ='EX')
* | [--->] WORK_ITEM_ID                   TYPE        SWW_WIID(optional)
* | [<-->] REJECT_FLAG                    TYPE        CHAR1(optional)
* | [<-->] APPROVE_FLAG                   TYPE        CHAR1(optional)
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD REJECT_IN_LOOP.

    REJECT_FLAG = 'X'.
    CLEAR APPROVE_FLAG.

    DATA GS_ACTOR TYPE ZWF_USERS.
    GS_ACTOR = VALUE #( USERS[ SEQUENCE = CURRENT_LEVEL ] OPTIONAL ).

    "--- the note is an SOFM attachment on the work item --------------
    DATA(LV_NOTE) = ZCL_WF_NOTE_READER=>READ_FROM_WI( WORK_ITEM_ID ).

*--- Begin of Enhancement | Hassan Diab | write to both logs ----------
    IF LOG_ID IS NOT INITIAL AND LOG_AREA <> 'OD'.

      DATA(LO_EX) = NEW ZCL_WF_LOG_EX( ).

      LO_EX->ADD_ITEM( IV_LOG_ID     = LOG_ID
                       IV_ACTION     = ZCL_WF_LOG_EX=>GC_ACTION-REJECT
                       IV_WI_ID      = WORK_ITEM_ID
                       IV_LEVEL_FROM = CURRENT_LEVEL
                       IV_AGENT      = GS_ACTOR-BNAME
                       IV_AGENT_DESC = GS_ACTOR-USER_DESC
                       IV_NOTE       = LV_NOTE ).

      LO_EX->FINISH( IV_LOG_ID = LOG_ID
                     IV_STATUS = ZCL_WF_LOG_EX=>GC_STATUS-REJECTED ).

    ENDIF.

    DATA(LV_OD_LOG) = COND ZWF_LOG_ID( WHEN LOG_AREA = 'OD'
                                       THEN LOG_ID
                                       ELSE LOG_ID_OD ).

    IF LV_OD_LOG IS NOT INITIAL.

      DATA(LO_OD) = NEW ZCL_WF_LOG_OD( ).

      LO_OD->ADD_ITEM( IV_LOG_ID     = LV_OD_LOG
                       IV_ACTION     = ZCL_WF_LOG_OD=>GC_ACTION-REJECT
                       IV_WI_ID      = WORK_ITEM_ID
                       IV_LEVEL_FROM = CURRENT_LEVEL
                       IV_AGENT      = GS_ACTOR-BNAME
                       IV_AGENT_DESC = GS_ACTOR-USER_DESC
                       IV_NOTE       = LV_NOTE ).

      LO_OD->FINISH( IV_LOG_ID = LV_OD_LOG
                     IV_STATUS = ZCL_WF_LOG_OD=>GC_STATUS-REJECTED ).

    ENDIF.
*--- End of Enhancement -----------------------------------------------

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZSD_WF_CREDIT_EXCEED_SO->RELEASE_SO
* +-------------------------------------------------------------------------------------------------+
* | [--->] SALES_ORDER                    TYPE        VBAK-VBELN(optional)
* | [--->] LOG_ID                         TYPE        ZWF_LOG_ID(optional)
* | [--->] LOG_ID_OD                      TYPE        ZWF_LOG_ID(optional)
* | [<---] RETURN_MESSAGE                 TYPE        CHAR50
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD RELEASE_SO.

*    CALL FUNCTION 'SD_ORDER_CREDIT_RELEASE'
*      EXPORTING
*        VBELN = SALES_ORDER.
*
*    RETURN_MESSAGE = |Sales order { SALES_ORDER ALPHA = OUT } credit released|.
*
*    DELETE FROM ZSD_WF_SO WHERE SALES_DOCUMENT = SALES_ORDER.
    RETURN_MESSAGE = |Sales order { SALES_ORDER ALPHA = OUT } credit released|.

*--- Begin of Enhancement | Hassan Diab | workflow log ----------------
    DATA(LV_NOTE) = CONV ZWF_NOTE(
      |Sales order { SALES_ORDER ALPHA = OUT } released| ).

    IF LOG_ID IS NOT INITIAL.
      NEW ZCL_WF_LOG_EX( )->ADD_ITEM(
        IV_LOG_ID = LOG_ID
        IV_ACTION = ZCL_WF_LOG_EX=>GC_ACTION-RELEASE
        IV_AGENT  = SY-UNAME
        IV_NOTE   = LV_NOTE ).
    ENDIF.

    IF LOG_ID_OD IS NOT INITIAL.
      NEW ZCL_WF_LOG_OD( )->ADD_ITEM(
        IV_LOG_ID = LOG_ID_OD
        IV_ACTION = ZCL_WF_LOG_OD=>GC_ACTION-RELEASE
        IV_AGENT  = SY-UNAME
        IV_NOTE   = LV_NOTE ).
    ENDIF.

    CALL FUNCTION 'SD_ORDER_CREDIT_RELEASE'
      EXPORTING
        VBELN = SALES_ORDER.
    DELETE FROM ZSD_WF_SO WHERE SALES_DOCUMENT = SALES_ORDER.
*--- End of Enhancement ----------------------------------------------
*    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
*      EXPORTING
*        WAIT = ABAP_TRUE.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZSD_WF_CREDIT_EXCEED_SO->BUILD_ALERT
* +-------------------------------------------------------------------------------------------------+
* | [--->] LOG_ID                         TYPE        ZWF_LOG_ID(optional)
* | [--->] LOG_ID_OD                      TYPE        ZWF_LOG_ID(optional)
* | [--->] CURRENT_LEVEL                  TYPE        INT2(optional)
* | [<---] ALERT_HTML                     TYPE        RSWEBPUB_T_W3HTML
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD BUILD_ALERT.
    ALERT_HTML = NEW ZCL_WF_SD_ALERT( )->BUILD_W3HTML(
                   IV_LOG_EX = LOG_ID
                   IV_LOG_OD = LOG_ID_OD
                   IV_LEVEL  = CURRENT_LEVEL ).
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZSD_WF_CREDIT_EXCEED_SO->NOTIFY_START
* +-------------------------------------------------------------------------------------------------+
* | [--->] LOG_ID                         TYPE        ZWF_LOG_ID(optional)
* | [--->] LOG_AREA                       TYPE        CHAR2 (default ='EX')
* | [--->] CURRENT_LEVEL                  TYPE        INT2(optional)
* | [--->] WORK_ITEM_ID                   TYPE        SWW_WIID(optional)
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD NOTIFY_START.

    CHECK LOG_ID IS NOT INITIAL AND CURRENT_LEVEL IS NOT INITIAL.

    DATA(LV_AREA) = COND CHAR2(
      WHEN LOG_AREA = 'OD'
      THEN ZCL_WF_MAIL_CREDIT=>GC_KIND-OVERDUE
      ELSE ZCL_WF_MAIL_CREDIT=>GC_KIND-EXCEED ).

    NEW ZCL_WF_MAIL_CREDIT( )->NOTIFY_FROM_LOG(
      IV_AREA   = LV_AREA
      IV_LOG_ID = LOG_ID
      IV_LEVEL  = CURRENT_LEVEL
      IV_WI_ID  = WORK_ITEM_ID ).

  ENDMETHOD.
ENDCLASS.