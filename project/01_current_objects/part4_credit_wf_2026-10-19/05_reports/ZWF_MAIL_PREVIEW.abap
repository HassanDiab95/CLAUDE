*&---------------------------------------------------------------------*
*& Object Name    : ZWF_MAIL_PREVIEW
*& Object Type    : Report
*& Transaction    : ZWF_MAIL_PREV
*& Package        : ZSD
*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : Nourhan Leila
*&---------------------------------------------------------------------*
*& Purpose        : Test harness for the workflow approver notification.
*&                   Builds the mail from an existing log without
*&                   running a workflow, so the layout can be checked
*&                   in seconds rather than by creating a document and
*&                   waiting for the approval to reach a level.
*&
*& Description    : Three modes.
*&                   Preview  - prints the raw HTML to the screen.
*&                              Paste it into a browser to see the
*&                              rendered mail.
*&                   Test     - sends to the address in Send To,
*&                              bypassing the approver lookup. Nothing
*&                              is written to the log.
*&                   Live     - sends to the real approver at the
*&                              chosen level and writes the MAIL or
*&                              MERR row, exactly as the workflow does.
*&---------------------------------------------------------------------*
*& Created By     : Hassan Diab
*& Created On     : 13.09.2026
*& Request No.    :
*& Version        : 1.0
*&---------------------------------------------------------------------*
REPORT ZWF_MAIL_PREVIEW.

TABLES ZWF_LOG_EX_H.

*&---------------------------------------------------------------------*
*& Selection screen
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK B1 WITH FRAME TITLE TEXT-B01.
  PARAMETERS P_CL RADIOBUTTON GROUP AR DEFAULT 'X' USER-COMMAND AR.
  PARAMETERS P_EX RADIOBUTTON GROUP AR.
  PARAMETERS P_OD RADIOBUTTON GROUP AR.
SELECTION-SCREEN END OF BLOCK B1.

SELECTION-SCREEN BEGIN OF BLOCK B2 WITH FRAME TITLE TEXT-B02.
  PARAMETERS P_LOG   TYPE ZWF_LOG_ID OBLIGATORY.
  PARAMETERS P_LEVEL TYPE INT2 DEFAULT 1.
  PARAMETERS P_RET   AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK B2.

SELECTION-SCREEN BEGIN OF BLOCK B3 WITH FRAME TITLE TEXT-B03.
  PARAMETERS P_PREV RADIOBUTTON GROUP MD DEFAULT 'X'.
  PARAMETERS P_TEST RADIOBUTTON GROUP MD.
  PARAMETERS P_LIVE RADIOBUTTON GROUP MD.
  SELECTION-SCREEN SKIP 1.
  PARAMETERS P_TO   TYPE AD_SMTPADR.
SELECTION-SCREEN END OF BLOCK B3.


*&---------------------------------------------------------------------*
*& Local application class
*&---------------------------------------------------------------------*
CLASS LCL_APP DEFINITION FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS RUN.

  PRIVATE SECTION.

    DATA MO_MAIL TYPE REF TO ZCL_WF_MAIL_CREDIT.

    METHODS AREA
      RETURNING VALUE(RV_AREA) TYPE CHAR2.

    METHODS LOAD
      RETURNING VALUE(RS_DATA) TYPE ZCL_WF_MAIL_CREDIT=>TY_S_DATA.

    METHODS SHOW_HTML
      IMPORTING IT_BODY TYPE BCSY_TEXT.

    METHODS SEND_TEST
      IMPORTING IS_DATA TYPE ZCL_WF_MAIL_CREDIT=>TY_S_DATA.

    METHODS SEND_LIVE.

ENDCLASS.


CLASS LCL_APP IMPLEMENTATION.

  METHOD AREA.

    RV_AREA = COND #(
      WHEN P_OD = ABAP_TRUE THEN ZCL_WF_MAIL_CREDIT=>GC_KIND-OVERDUE
      WHEN P_EX = ABAP_TRUE THEN ZCL_WF_MAIL_CREDIT=>GC_KIND-EXCEED
      ELSE                       ZCL_WF_MAIL_CREDIT=>GC_KIND-CREDIT_LIMIT ).

  ENDMETHOD.


  METHOD LOAD.

    RS_DATA = MO_MAIL->LOAD_FROM_LOG( IV_AREA   = AREA( )
                                      IV_LOG_ID = P_LOG ).

    IF RS_DATA-LOG_ID IS INITIAL.
      MESSAGE |Log { P_LOG } not found in area { AREA( ) }| TYPE 'E'.
    ENDIF.

    RS_DATA-CURRENT_LEVEL = P_LEVEL.
    RS_DATA-RETURNED      = P_RET.

    "--- the approver at that level, for the greeting ----------------
    DATA(LS_PROBE) = RS_DATA.

    " NOTIFY_FROM_LOG does this internally; here we only need the
    " description so the preview reads like the real mail
    IF RS_DATA-APPROVER_DESC IS INITIAL.
      RS_DATA-APPROVER_DESC = |Approver level { P_LEVEL }|.
    ENDIF.

  ENDMETHOD.


  METHOD SHOW_HTML.

    IF IT_BODY IS INITIAL.
      MESSAGE 'Nothing to show' TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    CL_DEMO_OUTPUT=>DISPLAY_TEXT(
      CONCAT_LINES_OF( TABLE = IT_BODY
                       SEP   = CL_ABAP_CHAR_UTILITIES=>NEWLINE ) ).

  ENDMETHOD.


  METHOD SEND_TEST.

    IF P_TO IS INITIAL.
      MESSAGE 'Enter an address in Send To for a test send' TYPE 'E'.
    ENDIF.

    DATA(LS_DATA) = IS_DATA.
    LS_DATA-RECIPIENT_EMAIL = P_TO.

    DATA(LO_SENDER) = NEW ZCL_MAIL_SENDER( ).

    DATA(LV_OK) = LO_SENDER->SEND(
      IT_BODY     = MO_MAIL->BUILD_BODY( LS_DATA )
      IV_SUBJECT  = |PREVIEW - log { P_LOG }|
      IT_TO       = VALUE #( ( P_TO ) )
      IV_PRIORITY = ZCL_MAIL_SENDER=>GC_PRIO-NORMAL
      IV_COMMIT   = ABAP_TRUE ).

    IF LV_OK = ABAP_TRUE.
      MESSAGE |Preview sent to { P_TO }. Nothing written to the log.|
              TYPE 'S'.
    ELSE.
      MESSAGE LO_SENDER->GET_MESSAGE( ) TYPE 'E'.
    ENDIF.

  ENDMETHOD.


  METHOD SEND_LIVE.

    DATA(LV_OK) = MO_MAIL->NOTIFY_FROM_LOG( IV_AREA     = AREA( )
                                            IV_LOG_ID   = P_LOG
                                            IV_LEVEL    = P_LEVEL
                                            IV_RETURNED = P_RET ).

    COMMIT WORK.

    IF LV_OK = ABAP_TRUE.
      MESSAGE |Sent to the approver at level { P_LEVEL }. | &&
              |A MAIL row was written to the log.| TYPE 'S'.
    ELSE.
      MESSAGE |{ MO_MAIL->GET_MESSAGE( ) } | &&
              |A MERR row was written to the log.|
              TYPE 'S' DISPLAY LIKE 'W'.
    ENDIF.

  ENDMETHOD.


  METHOD RUN.

    MO_MAIL = NEW ZCL_WF_MAIL_CREDIT( ).
    IF P_LIVE = ABAP_TRUE.
      SEND_LIVE( ).
      RETURN.
    ENDIF.

    DATA(LS_DATA) = LOAD( ).

    IF P_TEST = ABAP_TRUE.
      SEND_TEST( LS_DATA ).
      RETURN.
    ENDIF.

    SHOW_HTML( MO_MAIL->BUILD_BODY( LS_DATA ) ).

  ENDMETHOD.

ENDCLASS.

INITIALIZATION.
  DATA LV_AREA TYPE CHAR2.

  GET PARAMETER ID 'ZWFAREA' FIELD LV_AREA.

  CASE LV_AREA.
    WHEN 'EX'. CLEAR: P_CL, P_OD. P_EX = ABAP_TRUE.
    WHEN 'OD'. CLEAR: P_CL, P_EX. P_OD = ABAP_TRUE.
    WHEN OTHERS.
  ENDCASE.

  SET PARAMETER ID 'ZWFAREA' FIELD SPACE.


AT SELECTION-SCREEN OUTPUT.
  LOOP AT SCREEN.
    IF SCREEN-NAME CS 'P_TO'.
      SCREEN-INPUT = COND #( WHEN P_TEST = ABAP_TRUE THEN 1 ELSE 0 ).
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.


AT SELECTION-SCREEN.

  IF P_TEST = ABAP_TRUE AND P_TO IS INITIAL.
    MESSAGE 'Enter an address in Send To for a test send' TYPE 'E'.
  ENDIF.

  IF P_LIVE = ABAP_TRUE AND SY-UCOMM = 'ONLI'.
    DATA LV_ANSWER TYPE C LENGTH 1.

    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        TITLEBAR              = 'Live send'
        TEXT_QUESTION         = 'This sends to the real approver and ' &&
                                'writes a log row. Continue?'
        TEXT_BUTTON_1         = 'Send'
        TEXT_BUTTON_2         = 'Cancel'
        DEFAULT_BUTTON        = '2'
        DISPLAY_CANCEL_BUTTON = ABAP_FALSE
      IMPORTING
        ANSWER                = LV_ANSWER
      EXCEPTIONS
        OTHERS                = 0.

    IF LV_ANSWER <> '1'.
      MESSAGE 'Cancelled' TYPE 'S' DISPLAY LIKE 'W'.
      LEAVE LIST-PROCESSING.
    ENDIF.
  ENDIF.


START-OF-SELECTION.

  NEW LCL_APP( )->RUN( ).