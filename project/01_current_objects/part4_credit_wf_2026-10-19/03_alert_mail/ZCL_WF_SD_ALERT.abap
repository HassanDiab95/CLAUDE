CLASS ZCL_WF_SD_ALERT DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS: BEGIN OF GC_KIND,
                 EXCEED   TYPE CHAR2 VALUE 'EX',
                 OVERDUE  TYPE CHAR2 VALUE 'OD',
                 COMBINED TYPE CHAR2 VALUE 'EO',
               END OF GC_KIND.

    "! Alert as BCSY_TEXT - for the mail
    "! @parameter iv_full_doc | true wraps it in html/body, for a mail
    METHODS BUILD_HTML
      IMPORTING IV_LOG_EX      TYPE ZWF_LOG_ID OPTIONAL
                IV_LOG_OD      TYPE ZWF_LOG_ID OPTIONAL
                IV_LEVEL       TYPE INT2       OPTIONAL
                IV_FULL_DOC    TYPE ABAP_BOOL  DEFAULT ABAP_TRUE
      RETURNING VALUE(RT_HTML) TYPE BCSY_TEXT.

    "! Alert as RSWEBPUB_T_W3HTML - for the work item description
    METHODS BUILD_W3HTML
      IMPORTING IV_LOG_EX      TYPE ZWF_LOG_ID OPTIONAL
                IV_LOG_OD      TYPE ZWF_LOG_ID OPTIONAL
                IV_LEVEL       TYPE INT2       OPTIONAL
      RETURNING VALUE(RT_HTML) TYPE RSWEBPUB_T_W3HTML.

    "! The previous approver, for the "moved to you" line
    METHODS LAST_APPROVER
      IMPORTING IV_LOG_EX TYPE ZWF_LOG_ID OPTIONAL
                IV_LOG_OD TYPE ZWF_LOG_ID OPTIONAL
      EXPORTING EV_BNAME  TYPE XUBNAME
                EV_DESC   TYPE ZUSER_DESC
                EV_NOTE   TYPE ZWF_NOTE
                EV_FOUND  TYPE ABAP_BOOL.

  PRIVATE SECTION.

    TYPES: BEGIN OF TY_S_DATA,
             KIND             TYPE CHAR2,
             LOG_EX           TYPE ZWF_LOG_ID,
             LOG_OD           TYPE ZWF_LOG_ID,
             VBELN            TYPE VBELN_VA,
             BP_ID            TYPE BU_PARTNER,
             BP_NAME          TYPE CHAR100,
             BUKRS            TYPE BUKRS,
             BUTXT            TYPE BUTXT,
             CURRENCY         TYPE UKM_SGM_CURRENCY,
             CUR_LIMIT        TYPE UKM_CREDIT_LIMIT,
             EXCEED_CURR      TYPE UKM_COMM_ACTUAL,
             EXCEED_PER       TYPE UKM_COMM_ACTUAL,
             OVER_AMOUNT      TYPE DMBTR,
             OVER_DAYS        TYPE INT2,
             OVER_PERCENT     TYPE NETWR,
             PAYMENT_TERM_TXT TYPE TEXT1_052,
             LAST_EXC_DATE    TYPE CMFRE,
             LAST_EXC_VALUE   TYPE AMTBL_CM,
             LEVELS           TYPE INT2,
             CURRENT_LEVEL    TYPE INT2,
             PREV_BNAME       TYPE XUBNAME,
             PREV_DESC        TYPE ZUSER_DESC,
             PREV_NOTE        TYPE ZWF_NOTE,
             PREV_FOUND       TYPE ABAP_BOOL,
             NEXT_DESC        TYPE ZUSER_DESC,
           END OF TY_S_DATA.

    METHODS COLLECT
      IMPORTING IV_LOG_EX      TYPE ZWF_LOG_ID
                IV_LOG_OD      TYPE ZWF_LOG_ID
                IV_LEVEL       TYPE INT2
      RETURNING VALUE(RS_DATA) TYPE TY_S_DATA.

    METHODS AMOUNT
      IMPORTING IV_VALUE       TYPE P
                IV_CURRENCY    TYPE WAERS_CURC OPTIONAL
      RETURNING VALUE(RV_TEXT) TYPE STRING.

    METHODS APPROVER_AT_LEVEL
      IMPORTING IV_LOG_EX      TYPE ZWF_LOG_ID
                IV_LOG_OD      TYPE ZWF_LOG_ID
                IV_LEVEL       TYPE INT2
      RETURNING VALUE(RV_DESC) TYPE ZUSER_DESC.

    METHODS ITEM_TABLE
      IMPORTING IV_LOG_EX  TYPE ZWF_LOG_ID
                IV_LOG_OD  TYPE ZWF_LOG_ID
      EXPORTING EV_TABNAME TYPE TABNAME
                EV_LOG_ID  TYPE ZWF_LOG_ID.

ENDCLASS.



CLASS ZCL_WF_SD_ALERT IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_SD_ALERT->AMOUNT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_VALUE                       TYPE        P
* | [--->] IV_CURRENCY                    TYPE        WAERS_CURC(optional)
* | [<-()] RV_TEXT                        TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD AMOUNT.

    DATA LV_OUT TYPE C LENGTH 30.

    WRITE IV_VALUE TO LV_OUT CURRENCY IV_CURRENCY.

    CONDENSE LV_OUT.

    RV_TEXT = COND #( WHEN IV_CURRENCY IS NOT INITIAL
                      THEN |{ LV_OUT } { IV_CURRENCY }|
                      ELSE LV_OUT ).

    CONDENSE RV_TEXT.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_SD_ALERT->APPROVER_AT_LEVEL
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_LOG_EX                      TYPE        ZWF_LOG_ID
* | [--->] IV_LOG_OD                      TYPE        ZWF_LOG_ID
* | [--->] IV_LEVEL                       TYPE        INT2
* | [<-()] RV_DESC                        TYPE        ZUSER_DESC
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD APPROVER_AT_LEVEL.

    DATA LV_TAB TYPE TABNAME.
    DATA LV_LOG TYPE ZWF_LOG_ID.

    ITEM_TABLE( EXPORTING IV_LOG_EX  = IV_LOG_EX
                          IV_LOG_OD  = IV_LOG_OD
                IMPORTING EV_TABNAME = LV_TAB
                          EV_LOG_ID  = LV_LOG ).

    CHECK LV_TAB IS NOT INITIAL.

    DATA LR_ITM TYPE REF TO DATA.

    FIELD-SYMBOLS <LS_ITM> TYPE ANY.
    FIELD-SYMBOLS <LV_ANY> TYPE ANY.

    CREATE DATA LR_ITM TYPE (LV_TAB).
    ASSIGN LR_ITM->* TO <LS_ITM>.

    SELECT SINGLE * FROM (LV_TAB)
      WHERE LOG_ID   = @LV_LOG
        AND ACTION   = 'STRT'
        AND LEVEL_TO = @IV_LEVEL
      INTO @<LS_ITM>.

    CHECK SY-SUBRC = 0.

    ASSIGN COMPONENT 'AGENT_DESC' OF STRUCTURE <LS_ITM> TO <LV_ANY>.
    IF SY-SUBRC = 0. RV_DESC = <LV_ANY>. ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_SD_ALERT->BUILD_HTML
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_LOG_EX                      TYPE        ZWF_LOG_ID(optional)
* | [--->] IV_LOG_OD                      TYPE        ZWF_LOG_ID(optional)
* | [--->] IV_LEVEL                       TYPE        INT2(optional)
* | [--->] IV_FULL_DOC                    TYPE        ABAP_BOOL (default =ABAP_TRUE)
* | [<-()] RT_HTML                        TYPE        BCSY_TEXT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD BUILD_HTML.

    DATA(LS) = COLLECT( IV_LOG_EX = IV_LOG_EX
                        IV_LOG_OD = IV_LOG_OD
                        IV_LEVEL  = IV_LEVEL ).

    DATA(LV_ACCENT) = SWITCH STRING( LS-KIND
      WHEN GC_KIND-OVERDUE THEN ZCL_MAIL_HTML=>GC_COLOUR-RED
      ELSE                      ZCL_MAIL_HTML=>GC_COLOUR-AMBER ).

    DATA(LO_HTML) = NEW ZCL_MAIL_HTML( LV_ACCENT ).

    DATA(LV_TITLE) = SWITCH STRING( LS-KIND
      WHEN GC_KIND-EXCEED
        THEN `Sales Order Credit Limit Exceeded - Approval Required`
      WHEN GC_KIND-OVERDUE
        THEN `Sales Order Overdue - Approval Required`
      ELSE `Credit Exceeded and Overdue - Approval Required` ).

    "--- open ---------------------------------------------------------
    IF IV_FULL_DOC = ABAP_TRUE.
      RT_HTML = LO_HTML->OPEN_DOCUMENT( ).
    ELSE.
      " SBWP renders a fragment - no html or body wrapper
      RT_HTML = VALUE #(
        ( |<table width="700" cellpadding="0" cellspacing="0"| )
        ( | style="background:#fff;border:1px solid #e0e0e0;| )
        ( |font-family:Arial,sans-serif;">| ) ).
    ENDIF.

    APPEND LINES OF LO_HTML->BANNER(
      IV_TITLE    = LV_TITLE
      IV_SUBTITLE = |Sales order { LS-VBELN ALPHA = OUT }| ) TO RT_HTML.

    "--- greeting -----------------------------------------------------
    APPEND LINES OF LO_HTML->PARAGRAPH(
      COND #( WHEN LS-NEXT_DESC IS NOT INITIAL
              THEN |Dear <b>{ LS-NEXT_DESC }</b>,|
              ELSE |Dear Approver,| ) ) TO RT_HTML.

    "--- the approval trail -------------------------------------------
    IF LS-PREV_FOUND = ABAP_TRUE.

      APPEND LINES OF LO_HTML->CALLOUT(
        IV_TEXT   = |This item was approved by { LS-PREV_DESC } | &&
                    |({ LS-PREV_BNAME }) and moved to you for approval|
        IV_COLOUR = ZCL_MAIL_HTML=>GC_COLOUR-GREEN ) TO RT_HTML.

      IF LS-PREV_NOTE IS NOT INITIAL.
        APPEND LINES OF LO_HTML->PARAGRAPH(
          |Their note: <i>{ LS-PREV_NOTE }</i>| ) TO RT_HTML.
      ENDIF.

    ELSE.

      APPEND LINES OF LO_HTML->PARAGRAPH(
        |This item is waiting for your decision.| ) TO RT_HTML.

    ENDIF.

    APPEND LINES OF LO_HTML->PARAGRAPH(
      |Check sales order <b>{ LS-VBELN ALPHA = OUT }</b> for business | &&
      |partner <b>{ LS-BP_NAME }</b> to approve or reject.| ) TO RT_HTML.

    "--- partner ------------------------------------------------------
    APPEND LINES OF LO_HTML->SECTION_TITLE( 'Business Partner' ) TO RT_HTML.

    APPEND LINES OF LO_HTML->PAIR_TABLE( VALUE #(
      ( LABEL = 'Sales Order'
        VALUE = |{ LS-VBELN ALPHA = OUT }| BOLD = ABAP_TRUE )
      ( LABEL = 'Business Partner'
        VALUE = |{ LS-BP_ID ALPHA = OUT }| )
      ( LABEL = 'Business Partner Name'
        VALUE = CONV STRING( LS-BP_NAME ) )
      ( LABEL = 'Company Code'
        VALUE = |{ LS-BUKRS } - { LS-BUTXT }| ) ) ) TO RT_HTML.

    "--- exceed -------------------------------------------------------
    IF LS-KIND = GC_KIND-EXCEED OR LS-KIND = GC_KIND-COMBINED.

      APPEND LINES OF LO_HTML->SECTION_TITLE( 'Credit Exposure' ) TO RT_HTML.

      APPEND LINES OF LO_HTML->PAIR_TABLE( VALUE #(
        ( LABEL = 'Credit Limit'
          VALUE = AMOUNT( IV_VALUE    = LS-CUR_LIMIT
                          IV_CURRENCY = LS-CURRENCY ) )
        ( LABEL = 'Credit Exceed'
          VALUE = AMOUNT( IV_VALUE    = LS-EXCEED_CURR
                          IV_CURRENCY = LS-CURRENCY )
          COLOR = ZCL_MAIL_HTML=>GC_COLOUR-RED BOLD     = ABAP_TRUE )
        ( LABEL = 'Credit Exceed %'
          VALUE = |{ LS-EXCEED_PER             DECIMALS = 2 } %|
          COLOR = ZCL_MAIL_HTML=>GC_COLOUR-RED BOLD     = ABAP_TRUE ) ) )
        TO RT_HTML.

    ENDIF.

    "--- overdue ------------------------------------------------------
    IF LS-KIND = GC_KIND-OVERDUE OR LS-KIND = GC_KIND-COMBINED.

      APPEND LINES OF LO_HTML->SECTION_TITLE( 'Overdue Position' ) TO RT_HTML.

      APPEND LINES OF LO_HTML->PAIR_TABLE( VALUE #(
        ( LABEL = 'Overdue Amount'
          VALUE = AMOUNT( IV_VALUE    = LS-OVER_AMOUNT
                          IV_CURRENCY = LS-CURRENCY )
          COLOR = ZCL_MAIL_HTML=>GC_COLOUR-RED BOLD     = ABAP_TRUE )
        ( LABEL = 'Overdue Days'
          VALUE = |{ LS-OVER_DAYS } Days|
          COLOR = ZCL_MAIL_HTML=>GC_COLOUR-RED BOLD     = ABAP_TRUE )
        ( LABEL = 'Overdue %'
          VALUE = |{ LS-OVER_PERCENT           DECIMALS = 2 } %| )
        ( LABEL = 'Payment Term'
          VALUE = CONV STRING( LS-PAYMENT_TERM_TXT ) ) ) ) TO RT_HTML.

    ENDIF.

    "--- last exception -----------------------------------------------
    IF LS-LAST_EXC_DATE IS NOT INITIAL.

      APPEND LINES OF LO_HTML->SECTION_TITLE( 'Last Exception' ) TO RT_HTML.

      APPEND LINES OF LO_HTML->PAIR_TABLE( VALUE #(
        ( LABEL = 'Last Exception Date'
          VALUE = |{ LS-LAST_EXC_DATE DATE = USER }| )
        ( LABEL = 'Last Exception Value'
          VALUE = AMOUNT( IV_VALUE    = LS-LAST_EXC_VALUE
                          IV_CURRENCY = LS-CURRENCY ) ) ) ) TO RT_HTML.

    ENDIF.

    "--- your step ----------------------------------------------------
    APPEND LINES OF LO_HTML->SECTION_TITLE( 'Your Approval Step' ) TO RT_HTML.

    APPEND LINES OF LO_HTML->PAIR_TABLE( VALUE #(
      ( LABEL = 'Approval Level'
        VALUE = |{ LS-CURRENT_LEVEL } of { LS-LEVELS }| BOLD = ABAP_TRUE )
      ( LABEL = 'Your Role'
        VALUE = CONV STRING( LS-NEXT_DESC ) )
      ( LABEL = 'Exceed Log'
        VALUE = COND #( WHEN LS-LOG_EX IS NOT INITIAL
                        THEN |{ LS-LOG_EX ALPHA = OUT }| ) )
      ( LABEL = 'Overdue Log'
        VALUE = COND #( WHEN LS-LOG_OD IS NOT INITIAL
                        THEN |{ LS-LOG_OD ALPHA = OUT }| ) ) ) ) TO RT_HTML.

    APPEND LINES OF LO_HTML->PARAGRAPH(
      |Complete the work item then take your decision. | &&
      |Please enter a decision note.| ) TO RT_HTML.

    "--- close --------------------------------------------------------
    IF IV_FULL_DOC = ABAP_TRUE.
      APPEND LINES OF LO_HTML->FOOTER( ) TO RT_HTML.
      APPEND LINES OF LO_HTML->CLOSE_DOCUMENT( ) TO RT_HTML.
    ELSE.
      APPEND |</table>| TO RT_HTML.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_SD_ALERT->BUILD_W3HTML
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_LOG_EX                      TYPE        ZWF_LOG_ID(optional)
* | [--->] IV_LOG_OD                      TYPE        ZWF_LOG_ID(optional)
* | [--->] IV_LEVEL                       TYPE        INT2(optional)
* | [<-()] RT_HTML                        TYPE        RSWEBPUB_T_W3HTML
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD BUILD_W3HTML.

    DATA(LT_BODY) = BUILD_HTML( IV_LOG_EX   = IV_LOG_EX
                                IV_LOG_OD   = IV_LOG_OD
                                IV_LEVEL    = IV_LEVEL
                                IV_FULL_DOC = ABAP_FALSE ).

    LOOP AT LT_BODY INTO DATA(LV_LINE).
      APPEND CONV W3HTML( LV_LINE ) TO RT_HTML.
    ENDLOOP.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_SD_ALERT->COLLECT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_LOG_EX                      TYPE        ZWF_LOG_ID
* | [--->] IV_LOG_OD                      TYPE        ZWF_LOG_ID
* | [--->] IV_LEVEL                       TYPE        INT2
* | [<-()] RS_DATA                        TYPE        TY_S_DATA
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD COLLECT.

    RS_DATA-LOG_EX = IV_LOG_EX.
    RS_DATA-LOG_OD = IV_LOG_OD.

    "--- which shape -------------------------------------------------
    IF IV_LOG_EX IS NOT INITIAL AND IV_LOG_OD IS NOT INITIAL.
      RS_DATA-KIND = GC_KIND-COMBINED.
    ELSEIF IV_LOG_EX IS NOT INITIAL.
      RS_DATA-KIND = GC_KIND-EXCEED.
    ELSE.
      RS_DATA-KIND = GC_KIND-OVERDUE.
    ENDIF.

    "--- exceed header -----------------------------------------------
    IF IV_LOG_EX IS NOT INITIAL.

      SELECT SINGLE * FROM ZWF_LOG_EX_H
        WHERE LOG_ID = @IV_LOG_EX
        INTO @DATA(LS_EX).

      IF SY-SUBRC = 0.
        MOVE-CORRESPONDING LS_EX TO RS_DATA.
      ENDIF.

    ENDIF.

    "--- overdue header ----------------------------------------------
    IF IV_LOG_OD IS NOT INITIAL.

      SELECT SINGLE * FROM ZWF_LOG_OD_H
        WHERE LOG_ID = @IV_LOG_OD
        INTO @DATA(LS_OD).

      IF SY-SUBRC = 0.

        IF RS_DATA-VBELN IS INITIAL.
          " overdue only - take everything from here
          MOVE-CORRESPONDING LS_OD TO RS_DATA.
        ELSE.
          " combined - only the fields the exceed header lacks
          RS_DATA-OVER_AMOUNT      = LS_OD-OVER_AMOUNT.
          RS_DATA-OVER_DAYS        = LS_OD-OVER_DAYS.
          RS_DATA-OVER_PERCENT     = LS_OD-OVER_PERCENT.
          RS_DATA-PAYMENT_TERM_TXT = LS_OD-PAYMENT_TERM_TXT.
        ENDIF.

      ENDIF.

    ENDIF.

    SELECT SINGLE BUTXT FROM T001
      WHERE BUKRS = @RS_DATA-BUKRS
      INTO @RS_DATA-BUTXT.

    IF IV_LEVEL IS NOT INITIAL.
      RS_DATA-CURRENT_LEVEL = IV_LEVEL.
    ENDIF.

    "--- who is addressed, and who acted before ----------------------
    RS_DATA-NEXT_DESC = APPROVER_AT_LEVEL(
      IV_LOG_EX = IV_LOG_EX
      IV_LOG_OD = IV_LOG_OD
      IV_LEVEL  = RS_DATA-CURRENT_LEVEL ).

    LAST_APPROVER( EXPORTING IV_LOG_EX = IV_LOG_EX
                             IV_LOG_OD = IV_LOG_OD
                   IMPORTING EV_BNAME  = RS_DATA-PREV_BNAME
                             EV_DESC   = RS_DATA-PREV_DESC
                             EV_NOTE   = RS_DATA-PREV_NOTE
                             EV_FOUND  = RS_DATA-PREV_FOUND ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_SD_ALERT->ITEM_TABLE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_LOG_EX                      TYPE        ZWF_LOG_ID
* | [--->] IV_LOG_OD                      TYPE        ZWF_LOG_ID
* | [<---] EV_TABNAME                     TYPE        TABNAME
* | [<---] EV_LOG_ID                      TYPE        ZWF_LOG_ID
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD ITEM_TABLE.

    CLEAR: EV_TABNAME, EV_LOG_ID.

    IF IV_LOG_EX IS NOT INITIAL.
      EV_TABNAME = 'ZWF_LOG_EX_I'.
      EV_LOG_ID  = IV_LOG_EX.
    ELSEIF IV_LOG_OD IS NOT INITIAL.
      EV_TABNAME = 'ZWF_LOG_OD_I'.
      EV_LOG_ID  = IV_LOG_OD.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_SD_ALERT->LAST_APPROVER
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_LOG_EX                      TYPE        ZWF_LOG_ID(optional)
* | [--->] IV_LOG_OD                      TYPE        ZWF_LOG_ID(optional)
* | [<---] EV_BNAME                       TYPE        XUBNAME
* | [<---] EV_DESC                        TYPE        ZUSER_DESC
* | [<---] EV_NOTE                        TYPE        ZWF_NOTE
* | [<---] EV_FOUND                       TYPE        ABAP_BOOL
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD LAST_APPROVER.

    CLEAR: EV_BNAME, EV_DESC, EV_NOTE, EV_FOUND.

    DATA LV_TAB TYPE TABNAME.
    DATA LV_LOG TYPE ZWF_LOG_ID.

    ITEM_TABLE( EXPORTING IV_LOG_EX  = IV_LOG_EX
                          IV_LOG_OD  = IV_LOG_OD
                IMPORTING EV_TABNAME = LV_TAB
                          EV_LOG_ID  = LV_LOG ).

    CHECK LV_TAB IS NOT INITIAL.

    DATA LR_ITM TYPE REF TO DATA.

    FIELD-SYMBOLS <LT_ITM> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <LS_ITM> TYPE ANY.
    FIELD-SYMBOLS <LV_ANY> TYPE ANY.

    CREATE DATA LR_ITM TYPE STANDARD TABLE OF (LV_TAB).
    ASSIGN LR_ITM->* TO <LT_ITM>.

    "--- the newest real decision, ignoring STRT and mail rows -------
    SELECT * FROM (LV_TAB)
      WHERE LOG_ID = @LV_LOG
        AND ACTION IN ( 'APPR', 'FINL', 'RETN' )
      ORDER BY SEQNR DESCENDING
      INTO TABLE @<LT_ITM>
      UP TO 1 ROWS.

    READ TABLE <LT_ITM> INDEX 1 ASSIGNING <LS_ITM>.

    CHECK SY-SUBRC = 0.

    ASSIGN COMPONENT 'AGENT' OF STRUCTURE <LS_ITM> TO <LV_ANY>.
    IF SY-SUBRC = 0. EV_BNAME = <LV_ANY>. ENDIF.

    ASSIGN COMPONENT 'AGENT_DESC' OF STRUCTURE <LS_ITM> TO <LV_ANY>.
    IF SY-SUBRC = 0. EV_DESC = <LV_ANY>. ENDIF.

    ASSIGN COMPONENT 'NOTE' OF STRUCTURE <LS_ITM> TO <LV_ANY>.
    IF SY-SUBRC = 0. EV_NOTE = <LV_ANY>. ENDIF.

    EV_FOUND = ABAP_TRUE.

  ENDMETHOD.
ENDCLASS.