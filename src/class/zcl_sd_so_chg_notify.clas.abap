*&---------------------------------------------------------------------*
*& Class          : ZCL_SD_SO_CHG_NOTIFY
*& Workflow       : ZSD_SO_CHG_APPR (WS9xxxxxxx)
*& Package        : ZSD
*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : <Functional consultant>
*&---------------------------------------------------------------------*
*& Purpose        : HTML body and e-mails of the sales order change
*&                  approval workflow (CH4323).
*& Note           : No COMMIT WORK here; the workflow step commits.
*&                  Fiori launchpad base URL: constants GC_FLP_BASE_PRD
*&                  (production, system GC_SYSID_PRD) and GC_FLP_BASE
*&                  (development / quality).
*&---------------------------------------------------------------------*
*& Created By     : Hassan Diab
*& Created On     : 06.10.2026
*& Request No.    : <Request>
*& Version        : 1.0
*&---------------------------------------------------------------------*
*& Change History
*&---------------------------------------------------------------------*
*& Ver | Date       | Author        | Request No.  | Description
*&-----|------------|---------------|--------------|--------------------
*& 1.0 | 06.10.2026 | Hassan Diab   | <Request>    | Initial Creation
*&---------------------------------------------------------------------*
CLASS ZCL_SD_SO_CHG_NOTIFY DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES:
      TT_LINES TYPE STANDARD TABLE OF STRING WITH DEFAULT KEY .

    METHODS BUILD_LINES
      IMPORTING
        !IV_LOG_ID      TYPE SYSUUID_C32
        !IV_INTRO       TYPE CSEQUENCE OPTIONAL
        !IV_INBOX_LINK  TYPE ABAP_BOOL DEFAULT ABAP_FALSE
        !IV_INBOX       TYPE ABAP_BOOL DEFAULT ABAP_FALSE
      RETURNING
        VALUE(RT_LINES) TYPE TT_LINES .

    "! HTML description of the decision work item (Fiori My Inbox):
    "! same content as the approver e-mail, without the inbox link and
    "! without '&' (My Inbox reads &...& in the text as a variable)
    METHODS BUILD_INBOX_HTML
      IMPORTING
        !IV_LOG_ID     TYPE SYSUUID_C32
        !IV_LEVEL      TYPE ZSD_SO_LEVEL
      RETURNING
        VALUE(RT_HTML) TYPE W3HTMLTAB .

    METHODS TO_W3HTML
      IMPORTING
        !IT_LINES      TYPE TT_LINES
      RETURNING
        VALUE(RT_HTML) TYPE W3HTMLTAB .

    METHODS SEND_MAIL
      IMPORTING
        !IV_EMAIL    TYPE AD_SMTPADR
        !IV_SUBJECT  TYPE CSEQUENCE
        !IT_LINES    TYPE TT_LINES
      EXPORTING
        !EV_ERROR    TYPE STRING
      RETURNING
        VALUE(RV_OK) TYPE ABAP_BOOL .

    METHODS NOTIFY_APPROVER
      IMPORTING
        !IV_LOG_ID TYPE SYSUUID_C32
        !IV_LEVEL  TYPE ZSD_SO_LEVEL .

    METHODS NOTIFY_REQUESTER
      IMPORTING
        !IV_LOG_ID TYPE SYSUUID_C32
        !IV_RESULT TYPE ZSD_SO_WF_STATUS .

  PRIVATE SECTION.

    DATA MV_INBOX TYPE ABAP_BOOL .

    CONSTANTS GC_MAX_LINE TYPE I VALUE 255.
    CONSTANTS GC_TD_LABEL TYPE STRING
      VALUE `border:1px solid #d9d9d9;padding:5px 10px;background:#f5f6f7;font-weight:bold;width:220px`. "#EC NOTEXT
    CONSTANTS GC_TD_VALUE TYPE STRING
      VALUE `border:1px solid #d9d9d9;padding:5px 10px`.    "#EC NOTEXT

    CONSTANTS GC_SYSID_PRD TYPE SYSYSID VALUE '<PRD>'.      "#EC NOTEXT
    CONSTANTS GC_FLP_BASE_PRD TYPE STRING
      VALUE `https://<prd-host>:<port>/sap/bc/ui2/flp`.     "#EC NOTEXT
    CONSTANTS GC_FLP_BASE TYPE STRING
      VALUE `https://<dev-qas-host>:<port>/sap/bc/ui2/flp`. "#EC NOTEXT
    CONSTANTS GC_INBOX_INTENT TYPE STRING
      VALUE `#WorkflowTask-displayInbox`.                   "#EC NOTEXT

    METHODS ADD_LINE
      IMPORTING
        !IV_TEXT  TYPE CSEQUENCE
      CHANGING
        !CT_LINES TYPE TT_LINES .

    METHODS ADD_SECTION
      IMPORTING
        !IV_TITLE TYPE CSEQUENCE
        !IV_COLOR TYPE CSEQUENCE
      CHANGING
        !CT_LINES TYPE TT_LINES .

    METHODS ADD_ROW
      IMPORTING
        !IV_LABEL       TYPE CSEQUENCE
        !IV_VALUE       TYPE CSEQUENCE
        !IV_VALUE_STYLE TYPE CSEQUENCE OPTIONAL
      CHANGING
        !CT_LINES       TYPE TT_LINES .

    METHODS GET_INBOX_URL
      RETURNING
        VALUE(RV_URL) TYPE STRING .

    METHODS FMT_AMOUNT
      IMPORTING
        !IV_AMOUNT     TYPE ANY
        !IV_CURRENCY   TYPE WAERS
      RETURNING
        VALUE(RV_TEXT) TYPE STRING .

    METHODS FMT_DATE
      IMPORTING
        !IV_DATE       TYPE DATS
      RETURNING
        VALUE(RV_TEXT) TYPE STRING .

    METHODS FMT_NUMBER
      IMPORTING
        !IV_VALUE      TYPE ANY
      RETURNING
        VALUE(RV_TEXT) TYPE STRING .

    METHODS ALPHA_OUT
      IMPORTING
        !IV_VALUE      TYPE ANY
      RETURNING
        VALUE(RV_TEXT) TYPE STRING .

    METHODS ESCAPE
      IMPORTING
        !IV_TEXT       TYPE CSEQUENCE
      RETURNING
        VALUE(RV_TEXT) TYPE STRING .

ENDCLASS.



CLASS ZCL_SD_SO_CHG_NOTIFY IMPLEMENTATION.


  METHOD ADD_LINE.

    DATA: LV_REST TYPE STRING,
          LV_PART TYPE STRING,
          LV_CUT  TYPE I,
          LV_CHAR TYPE C LENGTH 1.

    LV_REST = IV_TEXT.

    WHILE STRLEN( LV_REST ) > GC_MAX_LINE.

      LV_CUT = GC_MAX_LINE - 1.
      DO.
        IF LV_CUT <= 0.
          EXIT.
        ENDIF.
        LV_CHAR = LV_REST+LV_CUT(1).
        IF LV_CHAR IS INITIAL.
          EXIT.
        ENDIF.
        LV_CUT = LV_CUT - 1.
      ENDDO.

      IF LV_CUT <= 0.
        LV_CUT = GC_MAX_LINE.
      ENDIF.

      LV_PART = LV_REST(LV_CUT).
      APPEND LV_PART TO CT_LINES.
      LV_REST = LV_REST+LV_CUT.

    ENDWHILE.

    APPEND LV_REST TO CT_LINES.

  ENDMETHOD.


  METHOD ADD_ROW.

    DATA LV_LINE TYPE STRING.

    ADD_LINE( EXPORTING IV_TEXT = `<tr>` CHANGING CT_LINES = CT_LINES ).

    LV_LINE = `<td style="` && GC_TD_LABEL && `">`.
    ADD_LINE( EXPORTING IV_TEXT = LV_LINE   CHANGING CT_LINES = CT_LINES ).
    ADD_LINE( EXPORTING IV_TEXT = IV_LABEL  CHANGING CT_LINES = CT_LINES ).
    ADD_LINE( EXPORTING IV_TEXT = `</td>`   CHANGING CT_LINES = CT_LINES ).

    LV_LINE = `<td style="` && GC_TD_VALUE && IV_VALUE_STYLE && `">`.
    ADD_LINE( EXPORTING IV_TEXT = LV_LINE   CHANGING CT_LINES = CT_LINES ).
    ADD_LINE( EXPORTING IV_TEXT = IV_VALUE  CHANGING CT_LINES = CT_LINES ).
    ADD_LINE( EXPORTING IV_TEXT = `</td>`   CHANGING CT_LINES = CT_LINES ).

    ADD_LINE( EXPORTING IV_TEXT = `</tr>` CHANGING CT_LINES = CT_LINES ).

  ENDMETHOD.


  METHOD ADD_SECTION.

    DATA LV_LINE TYPE STRING.

    LV_LINE = `<h3 style="margin:16px 0 6px 0;font-size:14px;color:` && IV_COLOR && `">`.
    ADD_LINE( EXPORTING IV_TEXT = LV_LINE  CHANGING CT_LINES = CT_LINES ).
    ADD_LINE( EXPORTING IV_TEXT = IV_TITLE CHANGING CT_LINES = CT_LINES ).
    ADD_LINE( EXPORTING IV_TEXT = `</h3>`  CHANGING CT_LINES = CT_LINES ).
    ADD_LINE( EXPORTING IV_TEXT = `<table style="border-collapse:collapse;min-width:460px">`
              CHANGING  CT_LINES = CT_LINES ).

  ENDMETHOD.


  METHOD ALPHA_OUT.

    DATA LV_CHAR TYPE C LENGTH 20.

    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
      EXPORTING
        INPUT  = IV_VALUE
      IMPORTING
        OUTPUT = LV_CHAR.

    RV_TEXT = LV_CHAR.

  ENDMETHOD.


  METHOD BUILD_LINES.

    DATA: LS_HEAD   TYPE ZSD_SO_CHG_LH,
          LT_LEVELS TYPE ZCL_SD_SO_CHG_LOG=>TT_LEVELS,
          LS_LEVEL  TYPE ZSD_SO_CHG_LL,
          LT_EVENTS TYPE ZCL_SD_SO_CHG_LOG=>TT_EVENTS,
          LS_EVENT  TYPE ZSD_SO_CHG_LE,
          LV_TEXT   TYPE STRING,
          LV_LABEL  TYPE STRING,
          LV_STYLE  TYPE STRING,
          LV_COLOR  TYPE STRING,
          LV_URL    TYPE STRING,
          LV_STATUS TYPE CHAR30,
          LV_COUNT  TYPE I.

    CLEAR RT_LINES.
    MV_INBOX = IV_INBOX.

    LS_HEAD   = ZCL_SD_SO_CHG_LOG=>GET_HEADER( IV_LOG_ID ).
    LT_LEVELS = ZCL_SD_SO_CHG_LOG=>GET_LEVELS( IV_LOG_ID ).
    LT_EVENTS = ZCL_SD_SO_CHG_LOG=>GET_EVENTS( IV_LOG_ID ).

    ADD_LINE( EXPORTING IV_TEXT = `<div style="font-family:Arial,Helvetica,sans-serif;font-size:13px;color:#32363a">`
              CHANGING  CT_LINES = RT_LINES ).

    " intro
    IF IV_INTRO IS NOT INITIAL.
      ADD_LINE( EXPORTING IV_TEXT = `<p style="font-size:14px"><b>` CHANGING CT_LINES = RT_LINES ).
      ADD_LINE( EXPORTING IV_TEXT = ESCAPE( IV_INTRO )             CHANGING CT_LINES = RT_LINES ).
      ADD_LINE( EXPORTING IV_TEXT = `</b></p>`                      CHANGING CT_LINES = RT_LINES ).
    ENDIF.

    " sales order
    ADD_SECTION( EXPORTING IV_TITLE = 'Sales order'(001) IV_COLOR = '#0a6ed1'
                 CHANGING  CT_LINES = RT_LINES ).

    ADD_ROW( EXPORTING IV_LABEL = 'Sales order'(001)  IV_VALUE = ALPHA_OUT( LS_HEAD-VBELN )
             CHANGING  CT_LINES = RT_LINES ).
    ADD_ROW( EXPORTING IV_LABEL = 'Contract'(002)     IV_VALUE = ALPHA_OUT( LS_HEAD-CONTRACT )
             CHANGING  CT_LINES = RT_LINES ).

    LV_TEXT = ALPHA_OUT( LS_HEAD-KUNNR ) && ` - ` && ESCAPE( LS_HEAD-CUST_NAME ).
    ADD_ROW( EXPORTING IV_LABEL = 'Customer'(003) IV_VALUE = LV_TEXT
             CHANGING  CT_LINES = RT_LINES ).

    CONCATENATE LS_HEAD-VKORG LS_HEAD-VTWEG LS_HEAD-SPART LS_HEAD-AUART
           INTO LV_TEXT SEPARATED BY ` / `.
    ADD_ROW( EXPORTING IV_LABEL = 'Sales area / Order type'(004) IV_VALUE = LV_TEXT
             CHANGING  CT_LINES = RT_LINES ).

    ADD_ROW( EXPORTING IV_LABEL = 'Net value'(005)
                       IV_VALUE = FMT_AMOUNT( IV_AMOUNT = LS_HEAD-NETWR IV_CURRENCY = LS_HEAD-WAERK )
             CHANGING  CT_LINES = RT_LINES ).

    LV_TEXT = ESCAPE( LS_HEAD-TRIGGER_BY ) && ` - ` && FMT_DATE( LS_HEAD-TRIGGER_ON ).
    ADD_ROW( EXPORTING IV_LABEL = 'Changed by / on'(006) IV_VALUE = LV_TEXT
             CHANGING  CT_LINES = RT_LINES ).

    ADD_ROW( EXPORTING IV_LABEL       = 'Delivery block'(007)
                       IV_VALUE       = ZCL_SD_SO_CHG_MONITOR=>GC_BLOCK
                       IV_VALUE_STYLE = ';color:#bb0000;font-weight:bold'
             CHANGING  CT_LINES = RT_LINES ).

    ADD_LINE( EXPORTING IV_TEXT = `</table>` CHANGING CT_LINES = RT_LINES ).

    " changes (one CHANGE event per changed field)
    ADD_SECTION( EXPORTING IV_TITLE = 'Changes requiring approval'(010) IV_COLOR = '#e9730c'
                 CHANGING  CT_LINES = RT_LINES ).

    LOOP AT LT_EVENTS INTO LS_EVENT WHERE EVENT = ZCL_SD_SO_CHG_LOG=>GC_EVENT-CHANGE.
      LV_COUNT = LV_COUNT + 1.
      ADD_ROW( EXPORTING IV_LABEL = FMT_NUMBER( LV_COUNT )
                         IV_VALUE = ESCAPE( LS_EVENT-TEXT )
               CHANGING  CT_LINES = RT_LINES ).
    ENDLOOP.

    ADD_LINE( EXPORTING IV_TEXT = `</table>` CHANGING CT_LINES = RT_LINES ).

    " approval status
    ADD_SECTION( EXPORTING IV_TITLE = 'Approval status'(030) IV_COLOR = '#32363a'
                 CHANGING  CT_LINES = RT_LINES ).

    LOOP AT LT_LEVELS INTO LS_LEVEL.

      LV_STATUS = ZCL_SD_SO_CHG_LOG=>GET_LEVEL_TEXT( LS_LEVEL-STATUS ).

      CASE LS_LEVEL-STATUS.
        WHEN ZCL_SD_SO_CHG_LOG=>GC_LEVEL-APPROVED. LV_COLOR = '#107e3e'.
        WHEN ZCL_SD_SO_CHG_LOG=>GC_LEVEL-REJECTED. LV_COLOR = '#bb0000'.
        WHEN ZCL_SD_SO_CHG_LOG=>GC_LEVEL-PENDING.  LV_COLOR = '#e9730c'.
        WHEN OTHERS.                               LV_COLOR = '#6a6d70'.
      ENDCASE.

      LV_TEXT = LV_STATUS.
      IF LS_LEVEL-DECIDED_ON IS NOT INITIAL.
        LV_TEXT = LV_TEXT && ` - ` && FMT_DATE( LS_LEVEL-DECIDED_ON ).
      ENDIF.

      LV_STYLE = `;color:` && LV_COLOR && `;font-weight:bold`.
      LV_LABEL = FMT_NUMBER( LS_LEVEL-APPR_LEVEL ) && `. ` && ESCAPE( LS_LEVEL-FULL_NAME ).

      ADD_ROW( EXPORTING IV_LABEL       = LV_LABEL
                         IV_VALUE       = LV_TEXT
                         IV_VALUE_STYLE = LV_STYLE
               CHANGING  CT_LINES = RT_LINES ).

    ENDLOOP.

    ADD_LINE( EXPORTING IV_TEXT = `</table>` CHANGING CT_LINES = RT_LINES ).

    " link to My Inbox (approver e-mail only)
    IF IV_INBOX_LINK = ABAP_TRUE AND IV_INBOX = ABAP_FALSE.
      LV_URL = GET_INBOX_URL( ).
      IF LV_URL IS NOT INITIAL.
        REPLACE ALL OCCURRENCES OF `&` IN LV_URL WITH `&amp;`.
        ADD_LINE( EXPORTING IV_TEXT = `<p style="margin-top:16px">` CHANGING CT_LINES = RT_LINES ).
        CONCATENATE `<a target="_blank" href="` LV_URL `">` INTO LV_TEXT.
        ADD_LINE( EXPORTING IV_TEXT = LV_TEXT CHANGING CT_LINES = RT_LINES ).
        ADD_LINE( EXPORTING IV_TEXT = `<b>` CHANGING CT_LINES = RT_LINES ).
        ADD_LINE( EXPORTING IV_TEXT = 'Open My Inbox to approve or reject'(031)
                  CHANGING  CT_LINES = RT_LINES ).
        ADD_LINE( EXPORTING IV_TEXT = `</b></a></p>` CHANGING CT_LINES = RT_LINES ).
      ENDIF.
    ENDIF.

    ADD_LINE( EXPORTING IV_TEXT = `</div>` CHANGING CT_LINES = RT_LINES ).

    CLEAR MV_INBOX.

  ENDMETHOD.


  METHOD BUILD_INBOX_HTML.

    DATA: LS_HEAD  TYPE ZSD_SO_CHG_LH,
          LV_INTRO TYPE STRING.

    LS_HEAD = ZCL_SD_SO_CHG_LOG=>GET_HEADER( IV_LOG_ID ).

    LV_INTRO = 'Please approve or reject the change of sales order'(056) && ` `
               && ALPHA_OUT( LS_HEAD-VBELN ) && ` (` && 'level'(051) && ` `
               && FMT_NUMBER( IV_LEVEL ) && ` / ` && FMT_NUMBER( LS_HEAD-LEVELS ) && `).`.

    RT_HTML = TO_W3HTML( BUILD_LINES( IV_LOG_ID = IV_LOG_ID
                                      IV_INTRO  = LV_INTRO
                                      IV_INBOX  = ABAP_TRUE ) ).

  ENDMETHOD.


  METHOD ESCAPE.

    DATA LV_IN TYPE STRING.

    LV_IN = IV_TEXT.

    " My Inbox: no '&' at all (&...& would be read as a container variable),
    " so no HTML entities either - replace the special characters directly
    IF MV_INBOX = ABAP_TRUE.
      REPLACE ALL OCCURRENCES OF `->` IN LV_IN WITH `→`.
      REPLACE ALL OCCURRENCES OF `&`  IN LV_IN WITH `+`.
      REPLACE ALL OCCURRENCES OF `<`  IN LV_IN WITH `(`.
      REPLACE ALL OCCURRENCES OF `>`  IN LV_IN WITH `)`.
      REPLACE ALL OCCURRENCES OF `"`  IN LV_IN WITH `'`.
      RV_TEXT = LV_IN.
      RETURN.
    ENDIF.

    RV_TEXT = CL_HTTP_UTILITY=>ESCAPE_HTML( UNESCAPED = LV_IN ).

  ENDMETHOD.


  METHOD FMT_AMOUNT.

    DATA LV_CHAR TYPE C LENGTH 40.

    WRITE IV_AMOUNT TO LV_CHAR CURRENCY IV_CURRENCY.
    CONDENSE LV_CHAR.
    RV_TEXT = LV_CHAR && ` ` && IV_CURRENCY.

  ENDMETHOD.


  METHOD FMT_DATE.

    DATA LV_CHAR TYPE C LENGTH 10.

    CLEAR RV_TEXT.
    IF IV_DATE IS INITIAL.
      RETURN.
    ENDIF.

    WRITE IV_DATE TO LV_CHAR.
    RV_TEXT = LV_CHAR.

  ENDMETHOD.


  METHOD FMT_NUMBER.

    DATA LV_CHAR TYPE C LENGTH 30.

    WRITE IV_VALUE TO LV_CHAR.
    CONDENSE LV_CHAR.
    SHIFT LV_CHAR LEFT DELETING LEADING '0'.
    IF LV_CHAR IS INITIAL.
      LV_CHAR = '0'.
    ENDIF.
    RV_TEXT = LV_CHAR.

  ENDMETHOD.


  METHOD GET_INBOX_URL.

    DATA LV_BASE TYPE STRING.

    IF SY-SYSID = GC_SYSID_PRD.
      LV_BASE = GC_FLP_BASE_PRD.
    ELSE.
      LV_BASE = GC_FLP_BASE.
    ENDIF.

    CONCATENATE LV_BASE `?sap-client=` SY-MANDT GC_INBOX_INTENT
           INTO RV_URL.

  ENDMETHOD.


  METHOD NOTIFY_APPROVER.

    DATA: LS_HEAD    TYPE ZSD_SO_CHG_LH,
          LS_LEVEL   TYPE ZSD_SO_CHG_LL,
          LT_LINES   TYPE TT_LINES,
          LV_INTRO   TYPE STRING,
          LV_SUBJECT TYPE STRING,
          LV_ERROR   TYPE STRING,
          LV_TEXT    TYPE STRING.

    LS_HEAD  = ZCL_SD_SO_CHG_LOG=>GET_HEADER( IV_LOG_ID ).
    LS_LEVEL = ZCL_SD_SO_CHG_LOG=>GET_LEVEL( IV_LOG_ID = IV_LOG_ID IV_LEVEL = IV_LEVEL ).

    LV_INTRO = 'Your approval is needed for the change of sales order'(050) && ` `
               && ALPHA_OUT( LS_HEAD-VBELN ) && ` (` && 'level'(051) && ` `
               && FMT_NUMBER( IV_LEVEL ) && ` / ` && FMT_NUMBER( LS_HEAD-LEVELS ) && `). `
               && 'Please decide in Fiori My Inbox.'(052).

    LV_SUBJECT = 'Change approval'(053) && ` ` && ALPHA_OUT( LS_HEAD-VBELN ) && ` - `
                 && LS_HEAD-CUST_NAME && ` (` && 'level'(051) && ` `
                 && FMT_NUMBER( IV_LEVEL ) && `/` && FMT_NUMBER( LS_HEAD-LEVELS ) && `)`.

    LT_LINES = BUILD_LINES( IV_LOG_ID     = IV_LOG_ID
                            IV_INTRO      = LV_INTRO
                            IV_INBOX_LINK = ABAP_TRUE ).

    IF SEND_MAIL( EXPORTING IV_EMAIL   = LS_LEVEL-EMAIL
                            IV_SUBJECT = LV_SUBJECT
                            IT_LINES   = LT_LINES
                  IMPORTING EV_ERROR   = LV_ERROR ) = ABAP_TRUE.

      LV_TEXT = 'E-mail sent to'(054) && ` ` && LS_LEVEL-EMAIL.
      ZCL_SD_SO_CHG_LOG=>ADD_EVENT( IV_LOG_ID = IV_LOG_ID
                                    IV_EVENT  = ZCL_SD_SO_CHG_LOG=>GC_EVENT-MAIL
                                    IV_LEVEL  = IV_LEVEL
                                    IV_UNAME  = LS_LEVEL-UNAME
                                    IV_TEXT   = LV_TEXT ).
    ELSE.

      LV_TEXT = 'E-mail not sent:'(055) && ` ` && LV_ERROR.
      ZCL_SD_SO_CHG_LOG=>ADD_EVENT( IV_LOG_ID = IV_LOG_ID
                                    IV_EVENT  = ZCL_SD_SO_CHG_LOG=>GC_EVENT-MAIL_ERR
                                    IV_LEVEL  = IV_LEVEL
                                    IV_UNAME  = LS_LEVEL-UNAME
                                    IV_TEXT   = LV_TEXT ).
    ENDIF.

  ENDMETHOD.


  METHOD NOTIFY_REQUESTER.

    DATA: LS_HEAD    TYPE ZSD_SO_CHG_LH,
          LT_LINES   TYPE TT_LINES,
          LV_NAME    TYPE AD_NAMTEXT,
          LV_EMAIL   TYPE AD_SMTPADR,
          LV_RESULT  TYPE STRING,
          LV_INTRO   TYPE STRING,
          LV_SUBJECT TYPE STRING,
          LV_ERROR   TYPE STRING,
          LV_TEXT    TYPE STRING,
          LV_USER    TYPE XUBNAME.

    LS_HEAD = ZCL_SD_SO_CHG_LOG=>GET_HEADER( IV_LOG_ID ).
    LV_USER = LS_HEAD-TRIGGER_BY.

    IF LV_USER IS INITIAL.
      RETURN.
    ENDIF.

    ZCL_SD_SO_CHG_LOG=>GET_USER_DATA( EXPORTING IV_UNAME     = LV_USER
                                      IMPORTING EV_FULL_NAME = LV_NAME
                                                EV_EMAIL     = LV_EMAIL ).

    CASE IV_RESULT.
      WHEN ZCL_SD_SO_CHG_LOG=>GC_STATUS-APPROVED.
        LV_RESULT = 'approved - the delivery block is released'(060).
      WHEN ZCL_SD_SO_CHG_LOG=>GC_STATUS-ERROR.
        LV_RESULT = 'not started - no approver maintained, the order stays blocked'(066).
      WHEN OTHERS.
        LV_RESULT = 'rejected - the order stays blocked'(061).
    ENDCASE.

    LV_INTRO   = 'Your change of sales order'(062) && ` ` && ALPHA_OUT( LS_HEAD-VBELN )
                 && ` ` && 'was'(063) && ` ` && LV_RESULT && `.`.
    LV_SUBJECT = 'Change approval'(053) && ` ` && ALPHA_OUT( LS_HEAD-VBELN ) && `: ` && LV_RESULT.
    LT_LINES   = BUILD_LINES( IV_LOG_ID = IV_LOG_ID IV_INTRO = LV_INTRO ).

    IF SEND_MAIL( EXPORTING IV_EMAIL   = LV_EMAIL
                            IV_SUBJECT = LV_SUBJECT
                            IT_LINES   = LT_LINES
                  IMPORTING EV_ERROR   = LV_ERROR ) = ABAP_TRUE.
      LV_TEXT = 'Result e-mail sent to requester'(064) && ` ` && LV_EMAIL.
      ZCL_SD_SO_CHG_LOG=>ADD_EVENT( IV_LOG_ID = IV_LOG_ID
                                    IV_EVENT  = ZCL_SD_SO_CHG_LOG=>GC_EVENT-MAIL
                                    IV_UNAME  = LV_USER
                                    IV_TEXT   = LV_TEXT ).
    ELSE.
      LV_TEXT = 'Result e-mail not sent:'(065) && ` ` && LV_ERROR.
      ZCL_SD_SO_CHG_LOG=>ADD_EVENT( IV_LOG_ID = IV_LOG_ID
                                    IV_EVENT  = ZCL_SD_SO_CHG_LOG=>GC_EVENT-MAIL_ERR
                                    IV_UNAME  = LV_USER
                                    IV_TEXT   = LV_TEXT ).
    ENDIF.

  ENDMETHOD.


  METHOD SEND_MAIL.

    DATA: LO_SEND     TYPE REF TO CL_BCS,
          LO_DOCUMENT TYPE REF TO CL_DOCUMENT_BCS,
          LO_RECEIVER TYPE REF TO IF_RECIPIENT_BCS,
          LX_BCS      TYPE REF TO CX_BCS,
          LT_BODY     TYPE SOLI_TAB,
          LS_BODY     TYPE SOLI,
          LV_LINE     TYPE STRING,
          LV_SUBJECT  TYPE SO_OBJ_DES,
          LV_LONG     TYPE STRING.

    CLEAR EV_ERROR.
    RV_OK = ABAP_FALSE.

    IF IV_EMAIL IS INITIAL.
      EV_ERROR = 'No e-mail address'(040).
      RETURN.
    ENDIF.

    LS_BODY-LINE = `<html><body>`.
    APPEND LS_BODY TO LT_BODY.
    LOOP AT IT_LINES INTO LV_LINE.
      LS_BODY-LINE = LV_LINE.
      APPEND LS_BODY TO LT_BODY.
    ENDLOOP.
    LS_BODY-LINE = `</body></html>`.
    APPEND LS_BODY TO LT_BODY.

    LV_LONG    = IV_SUBJECT.
    LV_SUBJECT = IV_SUBJECT.

    TRY.
        LO_DOCUMENT = CL_DOCUMENT_BCS=>CREATE_DOCUMENT(
                        I_TYPE    = 'HTM'
                        I_TEXT    = LT_BODY
                        I_SUBJECT = LV_SUBJECT ).

        LO_SEND = CL_BCS=>CREATE_PERSISTENT( ).
        LO_SEND->SET_DOCUMENT( LO_DOCUMENT ).
        LO_SEND->SET_MESSAGE_SUBJECT( LV_LONG ).

        LO_RECEIVER = CL_CAM_ADDRESS_BCS=>CREATE_INTERNET_ADDRESS( IV_EMAIL ).
        LO_SEND->ADD_RECIPIENT( I_RECIPIENT = LO_RECEIVER ).

        LO_SEND->SET_SEND_IMMEDIATELY( ABAP_TRUE ).
        LO_SEND->SEND( ).

        RV_OK = ABAP_TRUE.

      CATCH CX_BCS INTO LX_BCS.
        EV_ERROR = LX_BCS->GET_TEXT( ).
    ENDTRY.

  ENDMETHOD.


  METHOD TO_W3HTML.

    DATA: LV_LINE TYPE STRING,
          LS_HTML TYPE W3HTML.

    CLEAR RT_HTML.

    LOOP AT IT_LINES INTO LV_LINE.
      LS_HTML-LINE = LV_LINE.
      APPEND LS_HTML TO RT_HTML.
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
