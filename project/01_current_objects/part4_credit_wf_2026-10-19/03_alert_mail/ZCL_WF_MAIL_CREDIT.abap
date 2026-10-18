CLASS ZCL_WF_MAIL_CREDIT DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS: BEGIN OF GC_KIND,
                 CREDIT_LIMIT TYPE CHAR2 VALUE 'CL',
                 EXCEED       TYPE CHAR2 VALUE 'EX',
                 OVERDUE      TYPE CHAR2 VALUE 'OD',
               END OF GC_KIND.

    CONSTANTS: BEGIN OF GC_ACTION,
                 SENT   TYPE ZWF_ACTION VALUE 'MAIL',
                 FAILED TYPE ZWF_ACTION VALUE 'MERR',
               END OF GC_ACTION.

    " Everything the mail can show. Fill what applies.
    TYPES: BEGIN OF TY_S_DATA,
             KIND             TYPE CHAR2,
             LOG_ID           TYPE ZWF_LOG_ID,
             LOG_ID_OD        TYPE ZWF_LOG_ID,

             " document - read at runtime, never stored
             VBELN            TYPE VBELN_VA,
             ERDAT            TYPE ERDAT,
             ERNAM            TYPE ERNAM,
             ERNAM_NAME       TYPE AD_NAMTEXT,
             NETWR            TYPE NETWR,
             WAERK            TYPE WAERK,
             WERKS            TYPE WERKS_D,

             " partner
             BP_ID            TYPE BU_PARTNER,
             BP_NAME          TYPE CHAR100,
             BUKRS            TYPE BUKRS,
             BUTXT            TYPE BUTXT,
             CREDIT_GROUP     TYPE UKM_CRED_GROUP,

             " credit
             CURRENCY         TYPE UKM_SGM_CURRENCY,
             CUR_LIMIT        TYPE UKM_CREDIT_LIMIT,
             REQ_LIMIT        TYPE UKM_CREDIT_LIMIT,
             EXPOSURE         TYPE UKM_COMM_ACTUAL,
             EXCEED_CURR      TYPE UKM_COMM_ACTUAL,
             EXCEED_PER       TYPE UKM_COMM_ACTUAL,

             " overdue
             OVER_AMOUNT      TYPE DMBTR,
             OVER_DAYS        TYPE INT2,
             OVER_PERCENT     TYPE NETWR,
             PAYMENT_TERM_TXT TYPE TEXT1_052,

             " last exception
             LAST_EXC_DATE    TYPE CMFRE,
             LAST_EXC_VALUE   TYPE AMTBL_CM,

             " approval
             CURRENT_LEVEL    TYPE INT2,
             LEVELS           TYPE INT2,
             APPROVER         TYPE XUBNAME,
             APPROVER_DESC    TYPE ZUSER_DESC,
             APPROVER_NAME    TYPE AD_NAMTEXT,
             RECIPIENT_EMAIL  TYPE AD_SMTPADR,
             WI_ID            TYPE SWW_WIID,
             RETURNED         TYPE ABAP_BOOL,

             " which blocks apply
             HAS_LIMIT        TYPE ABAP_BOOL,
             HAS_EXCEED       TYPE ABAP_BOOL,
             HAS_OVERDUE      TYPE ABAP_BOOL,

             STATUS           TYPE ZWF_STATUS1,
           END OF TY_S_DATA.

    "! Build and send from a log. Reads the header, the planned
    "! approver at the level, and the sales order at runtime.
    METHODS NOTIFY_FROM_LOG
      IMPORTING IV_AREA        TYPE CHAR2
                IV_LOG_ID      TYPE ZWF_LOG_ID
                IV_LEVEL       TYPE INT2
                IV_WI_ID       TYPE SWW_WIID  OPTIONAL
                IV_RETURNED    TYPE ABAP_BOOL DEFAULT ABAP_FALSE
      RETURNING VALUE(RV_SENT) TYPE ABAP_BOOL.

    METHODS NOTIFY_APPROVER
      IMPORTING IS_DATA        TYPE TY_S_DATA
      RETURNING VALUE(RV_SENT) TYPE ABAP_BOOL.

    METHODS LOAD_FROM_LOG
      IMPORTING IV_AREA        TYPE CHAR2
                IV_LOG_ID      TYPE ZWF_LOG_ID
      RETURNING VALUE(RS_DATA) TYPE TY_S_DATA.

    METHODS BUILD_BODY
      IMPORTING IS_DATA        TYPE TY_S_DATA
      RETURNING VALUE(RT_BODY) TYPE BCSY_TEXT.

    METHODS GET_MESSAGE
      RETURNING VALUE(RV_TEXT) TYPE STRING.
  PRIVATE SECTION.

    DATA MV_MESSAGE TYPE STRING.

    METHODS APPROVER_AT_LEVEL
      IMPORTING IV_AREA   TYPE CHAR2
                IV_LOG_ID TYPE ZWF_LOG_ID
                IV_LEVEL  TYPE INT2
      EXPORTING EV_BNAME  TYPE XUBNAME
                EV_DESC   TYPE ZUSER_DESC.

    METHODS LOAD_ORDER
      CHANGING CS_DATA TYPE TY_S_DATA.

    METHODS LOG_RESULT
      IMPORTING IS_DATA  TYPE TY_S_DATA
                IV_SENT  TYPE ABAP_BOOL
                IV_ERROR TYPE STRING OPTIONAL.

    METHODS ACCENT
      IMPORTING IS_DATA          TYPE TY_S_DATA
      RETURNING VALUE(RV_COLOUR) TYPE STRING.

    METHODS TITLE
      IMPORTING IS_DATA         TYPE TY_S_DATA
      RETURNING VALUE(RV_TITLE) TYPE STRING.

    METHODS SUBJECT
      IMPORTING IS_DATA        TYPE TY_S_DATA
      RETURNING VALUE(RV_SUBJ) TYPE SO_OBJ_DES.

    METHODS AMOUNT
      IMPORTING IV_VALUE       TYPE P
                IV_CURRENCY    TYPE WAERS_CURC OPTIONAL
      RETURNING VALUE(RV_TEXT) TYPE STRING.

    METHODS CALLOUT_BLOCK
      IMPORTING IS_DATA        TYPE TY_S_DATA
                IO_HTML        TYPE REF TO ZCL_MAIL_HTML
      RETURNING VALUE(RT_HTML) TYPE BCSY_TEXT.

    METHODS BLOCK_DOCUMENT
      IMPORTING IS_DATA        TYPE TY_S_DATA
                IO_HTML        TYPE REF TO ZCL_MAIL_HTML
      RETURNING VALUE(RT_HTML) TYPE BCSY_TEXT.

    METHODS BLOCK_PARTNER
      IMPORTING IS_DATA        TYPE TY_S_DATA
                IO_HTML        TYPE REF TO ZCL_MAIL_HTML
      RETURNING VALUE(RT_HTML) TYPE BCSY_TEXT.

    METHODS BLOCK_LIMIT
      IMPORTING IS_DATA        TYPE TY_S_DATA
                IO_HTML        TYPE REF TO ZCL_MAIL_HTML
      RETURNING VALUE(RT_HTML) TYPE BCSY_TEXT.

    METHODS BLOCK_EXCEED
      IMPORTING IS_DATA        TYPE TY_S_DATA
                IO_HTML        TYPE REF TO ZCL_MAIL_HTML
      RETURNING VALUE(RT_HTML) TYPE BCSY_TEXT.

    METHODS BLOCK_OVERDUE
      IMPORTING IS_DATA        TYPE TY_S_DATA
                IO_HTML        TYPE REF TO ZCL_MAIL_HTML
      RETURNING VALUE(RT_HTML) TYPE BCSY_TEXT.

    METHODS BLOCK_APPROVAL
      IMPORTING IS_DATA        TYPE TY_S_DATA
                IO_HTML        TYPE REF TO ZCL_MAIL_HTML
      RETURNING VALUE(RT_HTML) TYPE BCSY_TEXT.

ENDCLASS.



CLASS ZCL_WF_MAIL_CREDIT IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_MAIL_CREDIT->ACCENT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_DATA                        TYPE        TY_S_DATA
* | [<-()] RV_COLOUR                      TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD ACCENT.

    RV_COLOUR = COND #(
      WHEN IS_DATA-HAS_LIMIT   = ABAP_TRUE THEN ZCL_MAIL_HTML=>GC_COLOUR-BLUE
      WHEN IS_DATA-HAS_EXCEED  = ABAP_TRUE THEN ZCL_MAIL_HTML=>GC_COLOUR-AMBER
      WHEN IS_DATA-HAS_OVERDUE = ABAP_TRUE THEN ZCL_MAIL_HTML=>GC_COLOUR-RED
      ELSE                                      ZCL_MAIL_HTML=>GC_COLOUR-BLUE ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_MAIL_CREDIT->AMOUNT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_VALUE                       TYPE        P
* | [--->] IV_CURRENCY                    TYPE        WAERS_CURC(optional)
* | [<-()] RV_TEXT                        TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD AMOUNT.

    DATA LV_OUT TYPE C LENGTH 30.

    WRITE IV_VALUE TO LV_OUT CURRENCY IV_CURRENCY.

    CONDENSE LV_OUT.

    IF IV_CURRENCY IS NOT INITIAL.
      RV_TEXT = |{ LV_OUT } { IV_CURRENCY }|.
    ELSE.
      RV_TEXT = LV_OUT.
    ENDIF.

    CONDENSE RV_TEXT.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_MAIL_CREDIT->APPROVER_AT_LEVEL
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_AREA                        TYPE        CHAR2
* | [--->] IV_LOG_ID                      TYPE        ZWF_LOG_ID
* | [--->] IV_LEVEL                       TYPE        INT2
* | [<---] EV_BNAME                       TYPE        XUBNAME
* | [<---] EV_DESC                        TYPE        ZUSER_DESC
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD APPROVER_AT_LEVEL.

    CLEAR: EV_BNAME, EV_DESC.

    DATA LV_TAB TYPE TABNAME.

    LV_TAB = SWITCH #( IV_AREA
               WHEN GC_KIND-CREDIT_LIMIT THEN 'ZWF_LOG_CL_I'
               WHEN GC_KIND-EXCEED       THEN 'ZWF_LOG_EX_I'
               WHEN GC_KIND-OVERDUE      THEN 'ZWF_LOG_OD_I'
               ELSE                           SPACE ).

    CHECK LV_TAB IS NOT INITIAL.

    DATA LR_ITM TYPE REF TO DATA.

    FIELD-SYMBOLS <LS_ITM> TYPE ANY.
    FIELD-SYMBOLS <LV_ANY> TYPE ANY.

    CREATE DATA LR_ITM TYPE (LV_TAB).
    ASSIGN LR_ITM->* TO <LS_ITM>.

    " the STRT rows hold the planned approver chain
    SELECT SINGLE * FROM (LV_TAB)
      WHERE LOG_ID   = @IV_LOG_ID
        AND ACTION   = 'STRT'
        AND LEVEL_TO = @IV_LEVEL
      INTO @<LS_ITM>.

    CHECK SY-SUBRC = 0.

    ASSIGN COMPONENT 'AGENT' OF STRUCTURE <LS_ITM> TO <LV_ANY>.
    IF SY-SUBRC = 0. EV_BNAME = <LV_ANY>. ENDIF.

    ASSIGN COMPONENT 'AGENT_DESC' OF STRUCTURE <LS_ITM> TO <LV_ANY>.
    IF SY-SUBRC = 0. EV_DESC = <LV_ANY>. ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_MAIL_CREDIT->BLOCK_APPROVAL
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_DATA                        TYPE        TY_S_DATA
* | [--->] IO_HTML                        TYPE REF TO ZCL_MAIL_HTML
* | [<-()] RT_HTML                        TYPE        BCSY_TEXT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD BLOCK_APPROVAL.

    RT_HTML = IO_HTML->SECTION_TITLE( 'Your Approval Step' ).

    DATA(LT_PAIR) = VALUE ZCL_MAIL_HTML=>TT_PAIR(
      ( LABEL = 'Approval Level'
        VALUE = |{ IS_DATA-CURRENT_LEVEL } of { IS_DATA-LEVELS }|
        BOLD  = ABAP_TRUE )
      ( LABEL = 'Your Role'
        VALUE = CONV STRING( IS_DATA-APPROVER_DESC ) )
      ( LABEL = 'Log Reference'
        VALUE = |{ IS_DATA-LOG_ID ALPHA = OUT }| ) ).

    APPEND LINES OF IO_HTML->PAIR_TABLE( LT_PAIR ) TO RT_HTML.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_MAIL_CREDIT->BLOCK_DOCUMENT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_DATA                        TYPE        TY_S_DATA
* | [--->] IO_HTML                        TYPE REF TO ZCL_MAIL_HTML
* | [<-()] RT_HTML                        TYPE        BCSY_TEXT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD BLOCK_DOCUMENT.

    RT_HTML = IO_HTML->SECTION_TITLE( 'Sales Order' ).

    DATA(LT_PAIR) = VALUE ZCL_MAIL_HTML=>TT_PAIR(
      ( LABEL = 'Sales Order'
        VALUE = |{ IS_DATA-VBELN ALPHA = OUT }|
        BOLD  = ABAP_TRUE )
      ( LABEL = 'Creation Date'
        VALUE = |{ IS_DATA-ERDAT DATE  = USER }| )
      ( LABEL = 'Created By'
        VALUE = COND #( WHEN IS_DATA-ERNAM_NAME IS NOT INITIAL
      THEN |{ IS_DATA-ERNAM } - { IS_DATA-ERNAM_NAME }|
      ELSE CONV STRING( IS_DATA-ERNAM ) ) )
      ( LABEL = 'Plant'
        VALUE = CONV STRING( IS_DATA-WERKS ) )
      ( LABEL = 'Net Value'
        VALUE = AMOUNT( IV_VALUE    = IS_DATA-NETWR
                        IV_CURRENCY = IS_DATA-WAERK )
        BOLD  = ABAP_TRUE ) ).

    APPEND LINES OF IO_HTML->PAIR_TABLE( LT_PAIR ) TO RT_HTML.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_MAIL_CREDIT->BLOCK_EXCEED
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_DATA                        TYPE        TY_S_DATA
* | [--->] IO_HTML                        TYPE REF TO ZCL_MAIL_HTML
* | [<-()] RT_HTML                        TYPE        BCSY_TEXT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD BLOCK_EXCEED.

    RT_HTML = IO_HTML->SECTION_TITLE( 'Credit Exposure' ).

    DATA(LT_PAIR) = VALUE ZCL_MAIL_HTML=>TT_PAIR(
      ( LABEL = 'Credit Limit'
        VALUE = AMOUNT( IV_VALUE    = IS_DATA-CUR_LIMIT
                        IV_CURRENCY = IS_DATA-CURRENCY ) )
      ( LABEL = 'Current Exposure'
        VALUE = AMOUNT( IV_VALUE    = IS_DATA-EXPOSURE
                        IV_CURRENCY = IS_DATA-CURRENCY ) )
      ( LABEL = 'Exceeded By'
        VALUE = AMOUNT( IV_VALUE    = IS_DATA-EXCEED_CURR
                        IV_CURRENCY = IS_DATA-CURRENCY )
        COLOR = ZCL_MAIL_HTML=>GC_COLOUR-RED
        BOLD  = ABAP_TRUE )
      ( LABEL = 'Exceeded Percentage'
        VALUE = |{ IS_DATA-EXCEED_PER DECIMALS = 2 } %|
        COLOR = ZCL_MAIL_HTML=>GC_COLOUR-RED
        BOLD  = ABAP_TRUE ) ).

    IF IS_DATA-LAST_EXC_DATE IS NOT INITIAL.
      APPEND VALUE #( LABEL = 'Last Exception Granted'
                      VALUE = |{ IS_DATA-LAST_EXC_DATE DATE = USER } - | &&
                      |{ AMOUNT(         IV_VALUE    = IS_DATA-LAST_EXC_VALUE
                                         IV_CURRENCY = IS_DATA-CURRENCY ) }| )
             TO LT_PAIR.
    ENDIF.

    APPEND LINES OF IO_HTML->PAIR_TABLE( LT_PAIR ) TO RT_HTML.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_MAIL_CREDIT->BLOCK_LIMIT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_DATA                        TYPE        TY_S_DATA
* | [--->] IO_HTML                        TYPE REF TO ZCL_MAIL_HTML
* | [<-()] RT_HTML                        TYPE        BCSY_TEXT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD BLOCK_LIMIT.

    RT_HTML = IO_HTML->SECTION_TITLE( 'Credit Limit Request' ).

    DATA(LT_PAIR) = VALUE ZCL_MAIL_HTML=>TT_PAIR(
      ( LABEL = 'Customer'
        VALUE = COND #( WHEN IS_DATA-BP_NAME IS NOT INITIAL
      THEN |{ IS_DATA-BP_ID ALPHA       = OUT } - { IS_DATA-BP_NAME }|
      ELSE |{ IS_DATA-BP_ID ALPHA       = OUT }| )
        BOLD  = ABAP_TRUE )
      ( LABEL = 'Old Credit Limit'
        VALUE = AMOUNT(     IV_VALUE    = IS_DATA-CUR_LIMIT
                            IV_CURRENCY = IS_DATA-CURRENCY ) )
      ( LABEL = 'New Credit Limit Requested'
        VALUE = AMOUNT(     IV_VALUE    = IS_DATA-REQ_LIMIT
                            IV_CURRENCY = IS_DATA-CURRENCY )
        COLOR = ZCL_MAIL_HTML=>GC_COLOUR-RED
        BOLD  = ABAP_TRUE )
      ( LABEL = 'Increase'
        VALUE = AMOUNT(     IV_VALUE    = IS_DATA-REQ_LIMIT - IS_DATA-CUR_LIMIT
                            IV_CURRENCY = IS_DATA-CURRENCY )
        BOLD  = ABAP_TRUE ) ).

    " an approver deciding a limit wants to see the overdue position
    IF IS_DATA-OVER_AMOUNT IS NOT INITIAL.
      APPEND VALUE #( LABEL = 'Current Overdue'
                      VALUE = AMOUNT( IV_VALUE    = IS_DATA-OVER_AMOUNT
                                      IV_CURRENCY = IS_DATA-CURRENCY )
                      COLOR = ZCL_MAIL_HTML=>GC_COLOUR-RED ) TO LT_PAIR.
    ENDIF.

    IF IS_DATA-PAYMENT_TERM_TXT IS NOT INITIAL.
      APPEND VALUE #( LABEL = 'Payment Terms'
                      VALUE = CONV STRING( IS_DATA-PAYMENT_TERM_TXT ) )
             TO LT_PAIR.
    ENDIF.

    IF IS_DATA-LAST_EXC_DATE IS NOT INITIAL.
      APPEND VALUE #( LABEL = 'Last Exception Granted'
                      VALUE = |{ IS_DATA-LAST_EXC_DATE DATE = USER } - | &&
                      |{ AMOUNT(         IV_VALUE    = IS_DATA-LAST_EXC_VALUE
                                         IV_CURRENCY = IS_DATA-CURRENCY ) }| )
             TO LT_PAIR.
    ENDIF.

    APPEND LINES OF IO_HTML->PAIR_TABLE( LT_PAIR ) TO RT_HTML.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_MAIL_CREDIT->BLOCK_OVERDUE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_DATA                        TYPE        TY_S_DATA
* | [--->] IO_HTML                        TYPE REF TO ZCL_MAIL_HTML
* | [<-()] RT_HTML                        TYPE        BCSY_TEXT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD BLOCK_OVERDUE.

    RT_HTML = IO_HTML->SECTION_TITLE( 'Overdue Position' ).

    DATA(LT_PAIR) = VALUE ZCL_MAIL_HTML=>TT_PAIR(
      ( LABEL = 'Overdue Amount'
        VALUE = AMOUNT( IV_VALUE    = IS_DATA-OVER_AMOUNT
                        IV_CURRENCY = IS_DATA-CURRENCY )
        COLOR = ZCL_MAIL_HTML=>GC_COLOUR-RED
        BOLD  = ABAP_TRUE )
      ( LABEL = 'Days Overdue'
        VALUE = |{ IS_DATA-OVER_DAYS }|
        COLOR = ZCL_MAIL_HTML=>GC_COLOUR-RED
        BOLD  = ABAP_TRUE )
      ( LABEL = 'Overdue Percentage'
        VALUE = |{ IS_DATA-OVER_PERCENT DECIMALS = 2 } %| )
      ( LABEL = 'Payment Terms'
        VALUE = CONV STRING( IS_DATA-PAYMENT_TERM_TXT ) ) ).

    APPEND LINES OF IO_HTML->PAIR_TABLE( LT_PAIR ) TO RT_HTML.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_MAIL_CREDIT->BLOCK_PARTNER
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_DATA                        TYPE        TY_S_DATA
* | [--->] IO_HTML                        TYPE REF TO ZCL_MAIL_HTML
* | [<-()] RT_HTML                        TYPE        BCSY_TEXT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD BLOCK_PARTNER.

    RT_HTML = IO_HTML->SECTION_TITLE( 'Business Partner' ).

    DATA(LT_PAIR) = VALUE ZCL_MAIL_HTML=>TT_PAIR(
      ( LABEL = 'Partner'
        VALUE = |{ IS_DATA-BP_ID ALPHA = OUT }|
        BOLD  = ABAP_TRUE )
      ( LABEL = 'Name'
        VALUE = CONV STRING( IS_DATA-BP_NAME ) )
      ( LABEL = 'Company Code'
        VALUE = COND #( WHEN IS_DATA-BUTXT IS NOT INITIAL
                        THEN |{ IS_DATA-BUKRS } - { IS_DATA-BUTXT }|
                        ELSE CONV STRING( IS_DATA-BUKRS ) ) )
      ( LABEL = 'Credit Group'
        VALUE = CONV STRING( IS_DATA-CREDIT_GROUP ) ) ).

    APPEND LINES OF IO_HTML->PAIR_TABLE( LT_PAIR ) TO RT_HTML.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_MAIL_CREDIT->BUILD_BODY
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_DATA                        TYPE        TY_S_DATA
* | [<-()] RT_BODY                        TYPE        BCSY_TEXT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD build_body.

    rt_body = NEW zcl_wf_sd_alert( )->build_html(
                iv_log_ex   = COND #( WHEN is_data-kind <> 'OD'
                                      THEN is_data-log_id )
                iv_log_od   = COND #( WHEN is_data-kind = 'OD'
                                      THEN is_data-log_id
                                      ELSE is_data-log_id_od )
                iv_level    = is_data-current_level
                iv_full_doc = abap_true ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_MAIL_CREDIT->CALLOUT_BLOCK
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_DATA                        TYPE        TY_S_DATA
* | [--->] IO_HTML                        TYPE REF TO ZCL_MAIL_HTML
* | [<-()] RT_HTML                        TYPE        BCSY_TEXT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD CALLOUT_BLOCK.

    IF IS_DATA-HAS_LIMIT = ABAP_TRUE.

      RT_HTML = IO_HTML->CALLOUT(
        IV_TEXT   = |Requested credit limit | &&
                    |{ AMOUNT( IV_VALUE    = IS_DATA-REQ_LIMIT
                               IV_CURRENCY = IS_DATA-CURRENCY ) }|
        IV_COLOUR = ZCL_MAIL_HTML=>GC_COLOUR-BLUE ).
      RETURN.

    ENDIF.

    IF IS_DATA-HAS_EXCEED = ABAP_TRUE.

      APPEND LINES OF IO_HTML->CALLOUT(
        IV_TEXT   = |Credit limit exceeded by | &&
                    |{ AMOUNT( IV_VALUE    = IS_DATA-EXCEED_CURR
                               IV_CURRENCY = IS_DATA-CURRENCY ) } | &&
                    |({ IS_DATA-EXCEED_PER DECIMALS = 2 } %)|
        IV_COLOUR = ZCL_MAIL_HTML=>GC_COLOUR-AMBER ) TO RT_HTML.

    ENDIF.

    IF IS_DATA-HAS_OVERDUE = ABAP_TRUE.

      APPEND LINES OF IO_HTML->CALLOUT(
        IV_TEXT   = |Overdue | &&
                    |{ AMOUNT( IV_VALUE    = IS_DATA-OVER_AMOUNT
                               IV_CURRENCY = IS_DATA-CURRENCY ) } | &&
                    |for { IS_DATA-OVER_DAYS } day(s)|
        IV_COLOUR = ZCL_MAIL_HTML=>GC_COLOUR-RED ) TO RT_HTML.

    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_MAIL_CREDIT->GET_MESSAGE
* +-------------------------------------------------------------------------------------------------+
* | [<-()] RV_TEXT                        TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD GET_MESSAGE.

    RV_TEXT = MV_MESSAGE.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_MAIL_CREDIT->LOAD_FROM_LOG
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_AREA                        TYPE        CHAR2
* | [--->] IV_LOG_ID                      TYPE        ZWF_LOG_ID
* | [<-()] RS_DATA                        TYPE        TY_S_DATA
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD LOAD_FROM_LOG.

    DATA LR_HDR TYPE REF TO DATA.
    DATA LV_TAB TYPE TABNAME.

    FIELD-SYMBOLS <LS_HDR> TYPE ANY.

    LV_TAB = SWITCH #( IV_AREA
               WHEN GC_KIND-CREDIT_LIMIT THEN 'ZWF_LOG_CL_H'
               WHEN GC_KIND-EXCEED       THEN 'ZWF_LOG_EX_H'
               WHEN GC_KIND-OVERDUE      THEN 'ZWF_LOG_OD_H'
               ELSE                           SPACE ).

    CHECK LV_TAB IS NOT INITIAL.

    CREATE DATA LR_HDR TYPE (LV_TAB).
    ASSIGN LR_HDR->* TO <LS_HDR>.

    SELECT SINGLE * FROM (LV_TAB)
      WHERE LOG_ID = @IV_LOG_ID
      INTO @<LS_HDR>.

    CHECK SY-SUBRC = 0.

    MOVE-CORRESPONDING <LS_HDR> TO RS_DATA.

    RS_DATA-KIND   = IV_AREA.
    RS_DATA-LOG_ID = IV_LOG_ID.

    IF RS_DATA-VBELN IS NOT INITIAL.

      IF IV_AREA = GC_KIND-EXCEED.
        SELECT SINGLE MAX( LOG_ID ) FROM ZWF_LOG_OD_H
          WHERE VBELN = @RS_DATA-VBELN AND STATUS = 'I'
          INTO @RS_DATA-LOG_ID_OD.
      ENDIF.

    ENDIF.

    " which blocks apply - driven by the data, not the workflow type
    RS_DATA-HAS_LIMIT   = XSDBOOL( RS_DATA-REQ_LIMIT   IS NOT INITIAL ).
    RS_DATA-HAS_EXCEED  = XSDBOOL( RS_DATA-EXCEED_CURR > 0 ).
    RS_DATA-HAS_OVERDUE = XSDBOOL( RS_DATA-OVER_AMOUNT > 0 ).

    SELECT SINGLE BUTXT FROM T001
      WHERE BUKRS = @RS_DATA-BUKRS
      INTO @RS_DATA-BUTXT.

    LOAD_ORDER( CHANGING CS_DATA = RS_DATA ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_MAIL_CREDIT->LOAD_ORDER
* +-------------------------------------------------------------------------------------------------+
* | [<-->] CS_DATA                        TYPE        TY_S_DATA
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD LOAD_ORDER.

    " the sales order data is never stored in the log tables
    CHECK CS_DATA-VBELN IS NOT INITIAL.

    SELECT SINGLE ERDAT, ERNAM, NETWR, WAERK
      FROM VBAK
      WHERE VBELN = @CS_DATA-VBELN
      INTO ( @CS_DATA-ERDAT,
             @CS_DATA-ERNAM,
             @CS_DATA-NETWR,
             @CS_DATA-WAERK ).

    CHECK SY-SUBRC = 0.

    ZCL_MAIL_SENDER=>USER_DETAIL( EXPORTING IV_BNAME = CONV #( CS_DATA-ERNAM )
                                  IMPORTING EV_NAME  = CS_DATA-ERNAM_NAME ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_MAIL_CREDIT->LOG_RESULT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_DATA                        TYPE        TY_S_DATA
* | [--->] IV_SENT                        TYPE        ABAP_BOOL
* | [--->] IV_ERROR                       TYPE        STRING(optional)
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD LOG_RESULT.

    CHECK IS_DATA-LOG_ID IS NOT INITIAL.

    DATA LV_ACTION TYPE ZWF_ACTION.
    DATA LV_NOTE   TYPE ZWF_NOTE.

    IF IV_SENT = ABAP_TRUE.

      LV_ACTION = GC_ACTION-SENT.
      LV_NOTE   = |Notification sent to { IS_DATA-APPROVER }| &&
                  COND #( WHEN IS_DATA-APPROVER_NAME IS NOT INITIAL
                          THEN | - { IS_DATA-APPROVER_NAME }| ) &&
                  | ({ IS_DATA-RECIPIENT_EMAIL })|.

    ELSE.

      LV_ACTION = GC_ACTION-FAILED.
      LV_NOTE   = |Notification NOT sent to { IS_DATA-APPROVER }: | &&
                  |{ IV_ERROR }|.

    ENDIF.

    CASE IS_DATA-KIND.

      WHEN GC_KIND-CREDIT_LIMIT.
        NEW ZCL_WF_LOG_CL( )->ADD_ITEM(
          IV_LOG_ID     = IS_DATA-LOG_ID
          IV_ACTION     = LV_ACTION
          IV_WI_ID      = IS_DATA-WI_ID
          IV_LEVEL_TO   = IS_DATA-CURRENT_LEVEL
          IV_AGENT      = IS_DATA-APPROVER
          IV_AGENT_DESC = IS_DATA-APPROVER_DESC
          IV_NOTE       = LV_NOTE ).

      WHEN GC_KIND-EXCEED.
        NEW ZCL_WF_LOG_EX( )->ADD_ITEM(
          IV_LOG_ID     = IS_DATA-LOG_ID
          IV_ACTION     = LV_ACTION
          IV_WI_ID      = IS_DATA-WI_ID
          IV_LEVEL_TO   = IS_DATA-CURRENT_LEVEL
          IV_AGENT      = IS_DATA-APPROVER
          IV_AGENT_DESC = IS_DATA-APPROVER_DESC
          IV_NOTE       = LV_NOTE ).

      WHEN GC_KIND-OVERDUE.
        NEW ZCL_WF_LOG_OD( )->ADD_ITEM(
          IV_LOG_ID     = IS_DATA-LOG_ID
          IV_ACTION     = LV_ACTION
          IV_WI_ID      = IS_DATA-WI_ID
          IV_LEVEL_TO   = IS_DATA-CURRENT_LEVEL
          IV_AGENT      = IS_DATA-APPROVER
          IV_AGENT_DESC = IS_DATA-APPROVER_DESC
          IV_NOTE       = LV_NOTE ).

    ENDCASE.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_MAIL_CREDIT->NOTIFY_APPROVER
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_DATA                        TYPE        TY_S_DATA
* | [<-()] RV_SENT                        TYPE        ABAP_BOOL
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD NOTIFY_APPROVER.

    CLEAR MV_MESSAGE.

    DATA(LS_DATA) = IS_DATA.

    IF LS_DATA-APPROVER IS INITIAL.
      MV_MESSAGE = 'No approver supplied'.
      LOG_RESULT( IS_DATA  = LS_DATA
                  IV_SENT  = ABAP_FALSE
                  IV_ERROR = MV_MESSAGE ).
      RETURN.
    ENDIF.

    " who are we writing to
    DATA LV_FOUND TYPE ABAP_BOOL.

    ZCL_MAIL_SENDER=>USER_DETAIL(
      EXPORTING
        IV_BNAME = LS_DATA-APPROVER
      IMPORTING
        EV_NAME  = LS_DATA-APPROVER_NAME
        EV_EMAIL = LS_DATA-RECIPIENT_EMAIL
        EV_FOUND = LV_FOUND ).

    IF LV_FOUND = ABAP_FALSE.
      MV_MESSAGE = |User { LS_DATA-APPROVER } does not exist|.
      LOG_RESULT( IS_DATA  = LS_DATA
                  IV_SENT  = ABAP_FALSE
                  IV_ERROR = MV_MESSAGE ).
      RETURN.
    ENDIF.

    IF LS_DATA-RECIPIENT_EMAIL IS INITIAL.
      MV_MESSAGE = |User { LS_DATA-APPROVER } has no e-mail address|.
      LOG_RESULT( IS_DATA  = LS_DATA
                  IV_SENT  = ABAP_FALSE
                  IV_ERROR = MV_MESSAGE ).
      RETURN.
    ENDIF.

    DATA(LT_BODY) = BUILD_BODY( LS_DATA ).

    DATA(LO_MAIL) = NEW ZCL_MAIL_SENDER( ).

    RV_SENT = LO_MAIL->SEND(
      IT_BODY     = LT_BODY
      IV_SUBJECT  = SUBJECT( LS_DATA )
      IT_TO       = VALUE #( ( LS_DATA-RECIPIENT_EMAIL ) )
      IV_PRIORITY = ZCL_MAIL_SENDER=>GC_PRIO-HIGH ).

    IF RV_SENT = ABAP_FALSE.
      MV_MESSAGE = LO_MAIL->GET_MESSAGE( ).
    ENDIF.

    LOG_RESULT( IS_DATA  = LS_DATA
                IV_SENT  = RV_SENT
                IV_ERROR = MV_MESSAGE ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_MAIL_CREDIT->NOTIFY_FROM_LOG
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_AREA                        TYPE        CHAR2
* | [--->] IV_LOG_ID                      TYPE        ZWF_LOG_ID
* | [--->] IV_LEVEL                       TYPE        INT2
* | [--->] IV_WI_ID                       TYPE        SWW_WIID(optional)
* | [--->] IV_RETURNED                    TYPE        ABAP_BOOL (default =ABAP_FALSE)
* | [<-()] RV_SENT                        TYPE        ABAP_BOOL
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD NOTIFY_FROM_LOG.

    CLEAR MV_MESSAGE.

    DATA(LS_DATA) = LOAD_FROM_LOG( IV_AREA   = IV_AREA
                                   IV_LOG_ID = IV_LOG_ID ).

    IF LS_DATA-LOG_ID IS INITIAL.
      MV_MESSAGE = |Log { IV_LOG_ID } not found in area { IV_AREA }|.
      RETURN.
    ENDIF.

    IF LS_DATA-STATUS <> 'I'.
      MV_MESSAGE = |Log { IV_LOG_ID } is no longer in process | &&
                   |(status { LS_DATA-STATUS })|.
      RETURN.
    ENDIF.

    APPROVER_AT_LEVEL( EXPORTING IV_AREA   = IV_AREA
                                 IV_LOG_ID = IV_LOG_ID
                                 IV_LEVEL  = IV_LEVEL
                       IMPORTING EV_BNAME  = LS_DATA-APPROVER
                                 EV_DESC   = LS_DATA-APPROVER_DESC ).

    IF LS_DATA-APPROVER IS INITIAL.
      MV_MESSAGE = |No planned approver at level { IV_LEVEL }|.
      RETURN.
    ENDIF.

    LS_DATA-CURRENT_LEVEL = IV_LEVEL.
    LS_DATA-WI_ID         = IV_WI_ID.
    LS_DATA-RETURNED      = IV_RETURNED.

    RV_SENT = NOTIFY_APPROVER( LS_DATA ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_MAIL_CREDIT->SUBJECT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_DATA                        TYPE        TY_S_DATA
* | [<-()] RV_SUBJ                        TYPE        SO_OBJ_DES
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD SUBJECT.

    DATA LV_TEXT TYPE STRING.

    IF IS_DATA-HAS_LIMIT = ABAP_TRUE.
      LV_TEXT = |Credit limit approval - BP { IS_DATA-BP_ID ALPHA = OUT }|.

    ELSEIF IS_DATA-HAS_EXCEED = ABAP_TRUE AND IS_DATA-HAS_OVERDUE = ABAP_TRUE.
      LV_TEXT = |Credit exceeded and overdue - SO { IS_DATA-VBELN ALPHA = OUT }|.

    ELSEIF IS_DATA-HAS_EXCEED = ABAP_TRUE.
      LV_TEXT = |Credit exceeded - SO { IS_DATA-VBELN ALPHA = OUT }|.

    ELSEIF IS_DATA-HAS_OVERDUE = ABAP_TRUE.
      LV_TEXT = |Overdue - SO { IS_DATA-VBELN ALPHA = OUT }|.

    ELSE.
      LV_TEXT = |Approval required|.
    ENDIF.

    IF IS_DATA-RETURNED = ABAP_TRUE.
      LV_TEXT = |Returned: { LV_TEXT }|.
    ENDIF.

    RV_SUBJ = LV_TEXT.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_MAIL_CREDIT->TITLE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_DATA                        TYPE        TY_S_DATA
* | [<-()] RV_TITLE                       TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD TITLE.

    IF IS_DATA-HAS_EXCEED = ABAP_TRUE AND IS_DATA-HAS_OVERDUE = ABAP_TRUE.
      RV_TITLE = `Credit Exceeded and Overdue - Approval Required`.
      RETURN.
    ENDIF.

    RV_TITLE = COND #(
      WHEN IS_DATA-HAS_LIMIT   = ABAP_TRUE
        THEN `Credit Limit Request - Approval Required`
      WHEN IS_DATA-HAS_EXCEED  = ABAP_TRUE
        THEN `Sales Order Credit Exceeded - Approval Required`
      WHEN IS_DATA-HAS_OVERDUE = ABAP_TRUE
        THEN `Sales Order Overdue - Approval Required`
      ELSE `Approval Required` ).

  ENDMETHOD.
ENDCLASS.