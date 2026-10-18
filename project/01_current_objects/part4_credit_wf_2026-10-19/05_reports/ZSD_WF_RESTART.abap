*&---------------------------------------------------------------------*
*& Object Name    : ZSD_WF_RESTART
*& Object Type    : Report
*& Transaction    : ZRESTART_WF
*& Package        : ZSD
*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : Nourhan Leila
*&---------------------------------------------------------------------*
*& Purpose        : Support tool for the SD credit approval workflow.
*&                  Four mutually exclusive modes:
*&                   1. Restart  - write a header text so the credit
*&                                 check runs again from level 1
*&                   2. Unlock   - delete the ZSD_WF_SO row only
*&                   3. Kill     - kill the running work items only,
*&                                 no order change, no resubmit
*&                   4. Set date - maintain the system variable
*&                                 ZWF_SO_WF_START_DATE in TVARVC
*&---------------------------------------------------------------------*
*& Created By     : Hassan Diab
*& Created On     : 22.09.2026
*& Request No.    : DE3K932647
*& Version        : 2.0
*&---------------------------------------------------------------------*
*& Change History
*&---------------------------------------------------------------------*
*& Ver | Date       | Author      | Request No.  | Description
*&-----|------------|-------------|--------------|---------------------
*& 1.0 | 22.09.2026 | Hassan Diab | DE3K932647   | Initial Version
*& 2.0 | 27.09.2026 | Hassan Diab | DE3K932647   | Kill only mode and
*&     |            |             |              | TVARVC start date
*&---------------------------------------------------------------------*
REPORT ZSD_WF_RESTART.

TABLES ZSD_WF_SO.

CONSTANTS GC_TVARVC_START TYPE RVARI_VNAM VALUE 'ZWF_SO_WF_START_DATE'.

*&---------------------------------------------------------------------*
*& Selection screen
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK B1 WITH FRAME TITLE TEXT-B01.
  SELECT-OPTIONS S_VBELN FOR ZSD_WF_SO-SALES_DOCUMENT.
SELECTION-SCREEN END OF BLOCK B1.

SELECTION-SCREEN BEGIN OF BLOCK B2 WITH FRAME TITLE TEXT-B02.
  PARAMETERS P_TEXT TYPE TDLINE DEFAULT 'Credit approval restarted'.
SELECTION-SCREEN END OF BLOCK B2.

SELECTION-SCREEN BEGIN OF BLOCK B3 WITH FRAME TITLE TEXT-B03.
  PARAMETERS P_TEST  AS CHECKBOX DEFAULT 'X'.
  SELECTION-SCREEN SKIP 1.
  PARAMETERS P_ULOCK AS CHECKBOX USER-COMMAND UC.
  PARAMETERS P_KILL  AS CHECKBOX USER-COMMAND UC.
SELECTION-SCREEN END OF BLOCK B3.

SELECTION-SCREEN BEGIN OF BLOCK B4 WITH FRAME TITLE TEXT-B04.
  PARAMETERS P_SDATE AS CHECKBOX USER-COMMAND UC.
  PARAMETERS P_WDATE TYPE DATS.
SELECTION-SCREEN END OF BLOCK B4.

*&---------------------------------------------------------------------*
*& Local class
*&---------------------------------------------------------------------*
CLASS LCL_APP DEFINITION FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS: BEGIN OF GC_TEXT,
                 OBJECT TYPE TDOBJECT VALUE 'VBBK',
                 ID     TYPE TDID     VALUE 'TX01',
               END OF GC_TEXT.

    TYPES: BEGIN OF TY_S_RESULT,
             LIGHT   TYPE ICON_D,
             VBELN   TYPE VBELN_VA,
             OLD_LOG TYPE ZWF_LOG_ID,
             TEXT_OK TYPE ABAP_BOOL,
             NEW_LOG TYPE ZWF_LOG_ID,
             MESSAGE TYPE BAPI_MSG,
           END OF TY_S_RESULT.

    TYPES TT_RESULT TYPE STANDARD TABLE OF TY_S_RESULT WITH EMPTY KEY.
    TYPES TT_VBELN  TYPE STANDARD TABLE OF VBELN_VA    WITH EMPTY KEY.

    CLASS-METHODS READ_START_DATE
      RETURNING VALUE(RV_DATE) TYPE DATS.

    METHODS RUN.


  PRIVATE SECTION.

    DATA MT_RESULT TYPE TT_RESULT.

    METHODS SELECT_ORDERS
      RETURNING VALUE(RT_VBELN) TYPE TT_VBELN.

    METHODS PROCESS_ONE
      IMPORTING IV_VBELN      TYPE VBELN_VA
      RETURNING VALUE(RS_RES) TYPE TY_S_RESULT.

    METHODS WRITE_TEXT
      IMPORTING IV_VBELN   TYPE VBELN_VA
      EXPORTING EV_OK      TYPE ABAP_BOOL
                EV_MESSAGE TYPE BAPI_MSG.

    METHODS OPEN_LOG
      IMPORTING IV_VBELN      TYPE VBELN_VA
      RETURNING VALUE(RV_LOG) TYPE ZWF_LOG_ID.

    METHODS WAIT_NEW_LOG
      IMPORTING IV_VBELN      TYPE VBELN_VA
                IV_OLD_LOG    TYPE ZWF_LOG_ID
      RETURNING VALUE(RV_LOG) TYPE ZWF_LOG_ID.

    METHODS UNLOCK_ONLY.

    METHODS KILL_ONLY.

    METHODS SET_START_DATE.

    METHODS DISPLAY.

ENDCLASS.


CLASS LCL_APP IMPLEMENTATION.

*&---------------------------------------------------------------------*
*& RUN - four way branch
*&---------------------------------------------------------------------*
  METHOD RUN.

    IF P_SDATE = ABAP_TRUE.
      SET_START_DATE( ).
      RETURN.
    ENDIF.

    IF P_ULOCK = ABAP_TRUE.
      UNLOCK_ONLY( ).
      RETURN.
    ENDIF.

    IF P_KILL = ABAP_TRUE.
      KILL_ONLY( ).
      RETURN.
    ENDIF.

    DATA(LT_VBELN) = SELECT_ORDERS( ).

    IF LT_VBELN IS INITIAL.
      MESSAGE 'None of the selected orders is locked by the credit workflow'
              TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    LOOP AT LT_VBELN INTO DATA(LV_VBELN).
      APPEND PROCESS_ONE( LV_VBELN ) TO MT_RESULT.
    ENDLOOP.

    DISPLAY( ).

  ENDMETHOD.


*&---------------------------------------------------------------------*
*& SELECT_ORDERS
*&---------------------------------------------------------------------*
  METHOD SELECT_ORDERS.

    "--- only orders locked by the credit workflow -------------------
    SELECT SALES_DOCUMENT
      FROM ZSD_WF_SO
      WHERE SALES_DOCUMENT IN @S_VBELN
      ORDER BY SALES_DOCUMENT
      INTO TABLE @RT_VBELN.

  ENDMETHOD.


*&---------------------------------------------------------------------*
*& OPEN_LOG
*&---------------------------------------------------------------------*
  METHOD OPEN_LOG.

    SELECT SINGLE MAX( LOG_ID )
      FROM ZWF_LOG_EX_H
      WHERE VBELN  = @IV_VBELN
        AND STATUS = 'I'
      INTO @RV_LOG.

    IF RV_LOG IS NOT INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE MAX( LOG_ID )
      FROM ZWF_LOG_OD_H
      WHERE VBELN  = @IV_VBELN
        AND STATUS = 'I'
      INTO @RV_LOG.

  ENDMETHOD.


*&---------------------------------------------------------------------*
*& PROCESS_ONE - restart mode
*&---------------------------------------------------------------------*
  METHOD PROCESS_ONE.

    RS_RES-VBELN   = IV_VBELN.
    RS_RES-OLD_LOG = OPEN_LOG( IV_VBELN ).

    IF P_TEST = ABAP_TRUE.
      RS_RES-LIGHT   = ICON_LED_YELLOW.
      RS_RES-MESSAGE = 'Test run - no change made'.
      RETURN.
    ENDIF.

    WRITE_TEXT( EXPORTING IV_VBELN   = IV_VBELN
                IMPORTING EV_OK      = RS_RES-TEXT_OK
                          EV_MESSAGE = RS_RES-MESSAGE ).

    IF RS_RES-TEXT_OK = ABAP_FALSE.
      RS_RES-LIGHT = ICON_LED_RED.
      RETURN.
    ENDIF.

    RS_RES-NEW_LOG = WAIT_NEW_LOG( IV_VBELN   = IV_VBELN
                                   IV_OLD_LOG = RS_RES-OLD_LOG ).

    IF RS_RES-NEW_LOG IS NOT INITIAL.
      RS_RES-LIGHT   = ICON_LED_GREEN.
      RS_RES-MESSAGE = |Restarted - new log { RS_RES-NEW_LOG ALPHA = OUT }|.
    ELSE.
      RS_RES-LIGHT   = ICON_LED_YELLOW.
      RS_RES-MESSAGE = 'Text written, no new workflow log yet'.
    ENDIF.

  ENDMETHOD.


*&---------------------------------------------------------------------*
*& WRITE_TEXT
*&---------------------------------------------------------------------*
  METHOD WRITE_TEXT.

    CLEAR: EV_OK, EV_MESSAGE.

    DATA LS_HEADER_INX TYPE BAPISDH1X.
    DATA LT_TEXT       TYPE STANDARD TABLE OF BAPISDTEXT.
    DATA LT_RETURN     TYPE STANDARD TABLE OF BAPIRET2.

    LS_HEADER_INX-UPDATEFLAG = 'U'.

    APPEND VALUE #(             DOC_NUMBER = IV_VBELN
                                ITM_NUMBER = '000000'
                                TEXT_ID    = GC_TEXT-ID
                                LANGU      = SY-LANGU
                                FORMAT_COL = '*'
                                TEXT_LINE  = |{ P_TEXT } - { SY-UNAME } | &&
                    |{ SY-DATUM DATE       = USER } | &&
                    |{ SY-UZEIT TIME       = USER }| )
           TO LT_TEXT.

    CALL FUNCTION 'BAPI_SALESORDER_CHANGE'
      EXPORTING
        SALESDOCUMENT    = IV_VBELN
        ORDER_HEADER_INX = LS_HEADER_INX
      TABLES
        RETURN           = LT_RETURN
        ORDER_TEXT       = LT_TEXT.

    LOOP AT LT_RETURN INTO DATA(LS_RET) WHERE TYPE CA 'EA'.
      EV_MESSAGE = LS_RET-MESSAGE.
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      RETURN.
    ENDLOOP.

    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        WAIT = ABAP_TRUE.

    EV_OK      = ABAP_TRUE.
    EV_MESSAGE = 'Text TX01 written, save committed'.

  ENDMETHOD.


*&---------------------------------------------------------------------*
*& WAIT_NEW_LOG
*&---------------------------------------------------------------------*
  METHOD WAIT_NEW_LOG.

    DO 5 TIMES.

      RV_LOG = OPEN_LOG( IV_VBELN ).

      IF RV_LOG IS NOT INITIAL AND RV_LOG <> IV_OLD_LOG.
        RETURN.
      ENDIF.

      CLEAR RV_LOG.
      WAIT UP TO 1 SECONDS.

    ENDDO.

  ENDMETHOD.


*&---------------------------------------------------------------------*
*& UNLOCK_ONLY - delete the lock row, nothing else
*&---------------------------------------------------------------------*
  METHOD UNLOCK_ONLY.

    DATA(LT_VBELN) = SELECT_ORDERS( ).

    IF LT_VBELN IS INITIAL.
      MESSAGE 'None of the selected orders is in the lock table'
              TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    DATA LS_RES TYPE TY_S_RESULT.

    LOOP AT LT_VBELN INTO DATA(LV_VBELN).

      CLEAR LS_RES.
      LS_RES-VBELN   = LV_VBELN.
      LS_RES-OLD_LOG = OPEN_LOG( LV_VBELN ).

      IF P_TEST = ABAP_TRUE.
        LS_RES-LIGHT   = ICON_LED_YELLOW.
        LS_RES-MESSAGE = 'Test run - the lock row would be deleted'.
      ELSE.
        DELETE FROM ZSD_WF_SO WHERE SALES_DOCUMENT = LV_VBELN.
        LS_RES-LIGHT   = ICON_LED_GREEN.
        LS_RES-MESSAGE = 'Lock row deleted. Workflow and logs untouched'.
      ENDIF.

      APPEND LS_RES TO MT_RESULT.

    ENDLOOP.

    IF P_TEST = ABAP_FALSE.
      COMMIT WORK.
    ENDIF.

    DISPLAY( ).

  ENDMETHOD.


*&---------------------------------------------------------------------*
*& KILL_ONLY - kill the running work items, no order change
*&---------------------------------------------------------------------*
  METHOD KILL_ONLY.

    "--- the order does not have to be in the lock table --------------
    SELECT VBELN
      FROM VBAK
      WHERE VBELN IN @S_VBELN
      ORDER BY VBELN
      INTO TABLE @DATA(LT_VBELN).

    IF LT_VBELN IS INITIAL.
      MESSAGE 'No sales order found for the selection'
              TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    DATA LS_RES TYPE TY_S_RESULT.

    DATA(LO_CREDIT) = NEW ZCL_WF_SD_CREDIT( ).

    DATA(LV_REASON) = |Work items killed manually by { SY-UNAME } | &&
                      |on { SY-DATUM DATE = USER } | &&
                      |{ SY-UZEIT TIME = USER }|.

    IF P_TEXT IS NOT INITIAL.
      LV_REASON = |{ LV_REASON }. { P_TEXT }|.
    ENDIF.

    LOOP AT LT_VBELN INTO DATA(LS_VBAK).

      CLEAR LS_RES.
      LS_RES-VBELN   = LS_VBAK-VBELN.
      LS_RES-OLD_LOG = OPEN_LOG( LS_VBAK-VBELN ).

      IF P_TEST = ABAP_TRUE.
        LS_RES-LIGHT   = ICON_LED_YELLOW.
        LS_RES-MESSAGE = 'Test run - running work items would be killed'.
        APPEND LS_RES TO MT_RESULT.
        CONTINUE.
      ENDIF.

      "--- kills the work items, closes the open logs with KILL
      "--- and removes the ZSD_WF_SO lock row -----------------------
      DATA(LV_KILLED) = LO_CREDIT->KILL_RUNNING_WORKFLOW(
                          IV_VBELN  = LS_VBAK-VBELN
                          IV_REASON = LV_REASON
                          IV_FORCE  = ABAP_TRUE ).

      IF LV_KILLED = ABAP_TRUE.
        LS_RES-LIGHT   = ICON_LED_GREEN.
        LS_RES-MESSAGE = 'Work items killed, open logs closed as Killed'.
      ELSE.
        LS_RES-LIGHT   = ICON_LED_YELLOW.
        LS_RES-MESSAGE = 'No running work item found. ' &&
                         'Open logs closed, lock removed'.
      ENDIF.

      APPEND LS_RES TO MT_RESULT.

    ENDLOOP.

    IF P_TEST = ABAP_FALSE.
      COMMIT WORK AND WAIT.
    ENDIF.

    DISPLAY( ).

  ENDMETHOD.


*&---------------------------------------------------------------------*
*& READ_START_DATE - current value of the system variable
*&---------------------------------------------------------------------*
  METHOD READ_START_DATE.

    SELECT SINGLE LOW
      FROM TVARVC
      WHERE NAME = @GC_TVARVC_START
        AND TYPE = 'P'
        AND NUMB = '0000'
      INTO @DATA(LV_LOW).

    IF SY-SUBRC = 0 AND LV_LOW CO '0123456789' AND LV_LOW IS NOT INITIAL.
      RV_DATE = LV_LOW.
    ENDIF.

  ENDMETHOD.


*&---------------------------------------------------------------------*
*& SET_START_DATE - maintain ZWF_SO_WF_START_DATE in TVARVC
*&---------------------------------------------------------------------*
  METHOD SET_START_DATE.

    DATA LS_TVARVC TYPE TVARVC.
    DATA LS_RES    TYPE TY_S_RESULT.

    DATA(LV_OLD) = READ_START_DATE( ).

    IF P_WDATE IS INITIAL.
      MESSAGE 'Enter the workflow start date' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    IF P_TEST = ABAP_TRUE.

      MESSAGE |Test run - { GC_TVARVC_START } would be set from | &&
              |{ COND #( WHEN LV_OLD IS INITIAL
                         THEN 'not maintained'
                         ELSE |{ LV_OLD DATE = USER }| ) } | &&
              |to { P_WDATE DATE = USER }|
              TYPE 'S'.
      RETURN.

    ENDIF.

    "--- only this one record is touched ----------------------------
    LS_TVARVC-NAME = GC_TVARVC_START.
    LS_TVARVC-TYPE = 'P'.
    LS_TVARVC-NUMB = '0000'.
    LS_TVARVC-SIGN = 'I'.
    LS_TVARVC-OPTI = 'EQ'.
    LS_TVARVC-LOW  = P_WDATE.
    CLEAR LS_TVARVC-HIGH.

    MODIFY TVARVC FROM LS_TVARVC.

    IF SY-SUBRC = 0.

      COMMIT WORK AND WAIT.

      MESSAGE |{ GC_TVARVC_START } set to { P_WDATE DATE = USER }| &&
              COND #( WHEN LV_OLD IS NOT INITIAL
                      THEN | (was { LV_OLD DATE = USER })| )
              TYPE 'S'.

    ELSE.

      ROLLBACK WORK.
      MESSAGE |{ GC_TVARVC_START } could not be updated|
              TYPE 'S' DISPLAY LIKE 'E'.

    ENDIF.

  ENDMETHOD.


*&---------------------------------------------------------------------*
*& DISPLAY
*&---------------------------------------------------------------------*
  METHOD DISPLAY.

    DATA LO_ALV TYPE REF TO CL_SALV_TABLE.

    TRY.
        CL_SALV_TABLE=>FACTORY(
          IMPORTING
            R_SALV_TABLE = LO_ALV
          CHANGING
            T_TABLE      = MT_RESULT ).

        DATA(LO_COLS) = LO_ALV->GET_COLUMNS( ).
        LO_COLS->SET_OPTIMIZE( ABAP_TRUE ).

        DATA(LO_LIGHT) = CAST CL_SALV_COLUMN_TABLE(
                           LO_COLS->GET_COLUMN( 'LIGHT' ) ).
        LO_LIGHT->SET_ICON( IF_SALV_C_BOOL_SAP=>TRUE ).
        LO_LIGHT->SET_SHORT_TEXT( 'St' ).
        LO_LIGHT->SET_MEDIUM_TEXT( 'Status' ).
        LO_LIGHT->SET_LONG_TEXT( 'Status' ).

        LO_COLS->GET_COLUMN( 'OLD_LOG' )->SET_LONG_TEXT( 'Old log ID' ).
        LO_COLS->GET_COLUMN( 'TEXT_OK' )->SET_LONG_TEXT( 'Text written' ).
        LO_COLS->GET_COLUMN( 'NEW_LOG' )->SET_LONG_TEXT( 'New log ID' ).
        LO_COLS->GET_COLUMN( 'MESSAGE' )->SET_LONG_TEXT( 'Result' ).

        "--- the restart columns mean nothing in the other modes ----
        IF P_ULOCK = ABAP_TRUE OR P_KILL = ABAP_TRUE.
          LO_COLS->GET_COLUMN( 'TEXT_OK' )->SET_TECHNICAL( ABAP_TRUE ).
          LO_COLS->GET_COLUMN( 'NEW_LOG' )->SET_TECHNICAL( ABAP_TRUE ).
        ENDIF.

        LO_ALV->GET_FUNCTIONS( )->SET_ALL( ABAP_TRUE ).

        DATA LV_MODE TYPE STRING.

        LV_MODE = COND #( WHEN P_ULOCK = ABAP_TRUE THEN 'Remove lock only'
                          WHEN P_KILL  = ABAP_TRUE THEN 'Kill work items only'
                          ELSE 'Credit approval restart' ).

        DATA LV_HEAD TYPE LVC_TITLE.

        LV_HEAD = COND #( WHEN P_TEST = ABAP_TRUE
                          THEN |{ LV_MODE } - TEST RUN - | &&
                               |{ LINES( MT_RESULT ) } order(s)|
                          ELSE |{ LV_MODE } - | &&
                               |{ LINES( MT_RESULT ) } order(s)| ).

        LO_ALV->GET_DISPLAY_SETTINGS( )->SET_LIST_HEADER( LV_HEAD ).
        LO_ALV->GET_DISPLAY_SETTINGS( )->SET_STRIPED_PATTERN( ABAP_TRUE ).
        LO_ALV->DISPLAY( ).

      CATCH CX_SALV_MSG CX_SALV_NOT_FOUND INTO DATA(LX).
        MESSAGE LX->GET_TEXT( ) TYPE 'E'.
    ENDTRY.

  ENDMETHOD.


ENDCLASS.


*&---------------------------------------------------------------------*
*& INITIALIZATION
*&---------------------------------------------------------------------*
INITIALIZATION.

  P_WDATE = LCL_APP=>READ_START_DATE( ).

  IF P_WDATE IS INITIAL.
    P_WDATE = SY-DATUM.
  ENDIF.


*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN OUTPUT
*&---------------------------------------------------------------------*
AT SELECTION-SCREEN OUTPUT.

  LOOP AT SCREEN.

    "--- the restart text is only used by restart and kill ----------
    IF SCREEN-NAME CS 'P_TEXT'.
      SCREEN-INPUT = COND #( WHEN P_ULOCK = ABAP_TRUE
                               OR P_SDATE = ABAP_TRUE
                             THEN 0 ELSE 1 ).
      MODIFY SCREEN.
    ENDIF.

    "--- the date is only used by the date mode ---------------------
    IF SCREEN-NAME CS 'P_WDATE'.
      SCREEN-INPUT = COND #( WHEN P_SDATE = ABAP_TRUE THEN 1 ELSE 0 ).
      MODIFY SCREEN.
    ENDIF.

    "--- the date mode needs no sales order -------------------------
    IF SCREEN-NAME CS 'S_VBELN'.
      SCREEN-INPUT = COND #( WHEN P_SDATE = ABAP_TRUE THEN 0 ELSE 1 ).
      MODIFY SCREEN.
    ENDIF.

  ENDLOOP.


*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN
*&---------------------------------------------------------------------*
AT SELECTION-SCREEN.

  DATA LV_MODES TYPE I.

  CLEAR LV_MODES.
  IF P_ULOCK = ABAP_TRUE. LV_MODES = LV_MODES + 1. ENDIF.
  IF P_KILL  = ABAP_TRUE. LV_MODES = LV_MODES + 1. ENDIF.
  IF P_SDATE = ABAP_TRUE. LV_MODES = LV_MODES + 1. ENDIF.

  IF LV_MODES > 1.
    MESSAGE 'Tick only one of Remove lock, Kill work items, Set start date'
            TYPE 'E'.
  ENDIF.

  "--- every mode but the date mode needs a sales order -------------
  IF P_SDATE = ABAP_FALSE AND S_VBELN[] IS INITIAL.
    MESSAGE 'Enter at least one sales order' TYPE 'E'.
  ENDIF.

  IF P_SDATE = ABAP_TRUE AND P_WDATE IS INITIAL.
    MESSAGE 'Enter the workflow start date' TYPE 'E'.
  ENDIF.

  IF P_TEST = ABAP_FALSE AND SY-UCOMM = 'ONLI'.

    DATA LV_ANSWER   TYPE C LENGTH 1.
    DATA LV_TITLE    TYPE C LENGTH 30.
    DATA LV_QUESTION TYPE C LENGTH 200.
    DATA LV_BUTTON   TYPE C LENGTH 12.

    IF P_SDATE = ABAP_TRUE.

      LV_TITLE    = 'Set workflow start date'.
      LV_QUESTION = 'The system variable ZWF_SO_WF_START_DATE will be ' &&
                    'updated. Sales orders created before that date ' &&
                    'will not start the credit workflow. Continue?'.
      LV_BUTTON   = 'Update'.

    ELSEIF P_ULOCK = ABAP_TRUE.

      LV_TITLE    = 'Remove lock only'.
      LV_QUESTION = 'The lock row will be deleted. The workflow and ' &&
                    'its work items stay active and the order ' &&
                    'becomes changeable. Continue?'.
      LV_BUTTON   = 'Unlock'.

    ELSEIF P_KILL = ABAP_TRUE.

      LV_TITLE    = 'Kill work items only'.
      LV_QUESTION = 'Running work items will be killed and the open ' &&
                    'logs closed as Killed. The order is not changed ' &&
                    'and no new approval is started. Continue?'.
      LV_BUTTON   = 'Kill'.

    ELSE.

      LV_TITLE    = 'Restart credit approval'.
      LV_QUESTION = 'Running approvals on the selected orders will ' &&
                    'be killed and restarted from level 1. Continue?'.
      LV_BUTTON   = 'Restart'.

    ENDIF.

    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        TITLEBAR              = LV_TITLE
        TEXT_QUESTION         = LV_QUESTION
        TEXT_BUTTON_1         = LV_BUTTON
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


*&---------------------------------------------------------------------*
*& START-OF-SELECTION
*&---------------------------------------------------------------------*
START-OF-SELECTION.

  NEW LCL_APP( )->RUN( ).
