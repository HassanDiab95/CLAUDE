*&---------------------------------------------------------------------*
*& Program        : ZSD_SO_CHG_COCKPIT
*& Transaction    : ZSD_SOCHG_COCKPIT
*& Package        : ZSD
*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : <Functional consultant>
*&---------------------------------------------------------------------*
*& Purpose        : Single entry point of CH4323 (sales order with
*&                  reference to contract - change approval):
*&                  1. Filter maintenance       ZSD_SO_CON_FLT
*&                  2. Approver maintenance     ZSD_SO_APPR_CFG
*&                  3. Workflow log report      ZSD_SO_CHG_WF_LOG
*&                  Maintenance via FM VIEW_MAINTENANCE_CALL, log report
*&                  via SUBMIT ... VIA SELECTION-SCREEN AND RETURN.
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
REPORT ZSD_SO_CHG_COCKPIT.

TABLES SSCRFIELDS.

CONSTANTS: GC_VIEW_FILTER   TYPE TABNAME  VALUE 'ZSD_SO_CON_FLT',  "#EC NOTEXT
           GC_VIEW_APPROVER TYPE TABNAME  VALUE 'ZSD_SO_APPR_CFG', "#EC NOTEXT
           GC_REPORT_LOG    TYPE PROGNAME VALUE 'ZSD_SO_CHG_WF_LOG', "#EC NOTEXT
           GC_UCOMM_FILTER   TYPE SYUCOMM VALUE 'ZFLT',              "#EC NOTEXT
           GC_UCOMM_APPROVER TYPE SYUCOMM VALUE 'ZAPP',              "#EC NOTEXT
           GC_UCOMM_LOG      TYPE SYUCOMM VALUE 'ZLOG'.              "#EC NOTEXT

*--- selection screen: three pushbuttons with icon ------------------------
SELECTION-SCREEN BEGIN OF BLOCK B1 WITH FRAME TITLE TEXT-B01.
  SELECTION-SCREEN SKIP 1.
  SELECTION-SCREEN PUSHBUTTON /2(45) P_BFLT USER-COMMAND ZFLT.
  SELECTION-SCREEN COMMENT 50(60) P_CFLT.
  SELECTION-SCREEN SKIP 1.
  SELECTION-SCREEN PUSHBUTTON /2(45) P_BAPP USER-COMMAND ZAPP.
  SELECTION-SCREEN COMMENT 50(60) P_CAPP.
  SELECTION-SCREEN SKIP 1.
  SELECTION-SCREEN PUSHBUTTON /2(45) P_BLOG USER-COMMAND ZLOG.
  SELECTION-SCREEN COMMENT 50(60) P_CLOG.
  SELECTION-SCREEN SKIP 1.
SELECTION-SCREEN END OF BLOCK B1.


CLASS LCL_COCKPIT DEFINITION FINAL.

  PUBLIC SECTION.

    CLASS-METHODS INIT_BUTTONS .
    CLASS-METHODS HIDE_EXECUTE .
    CLASS-METHODS HANDLE_COMMAND
      IMPORTING
        !IV_UCOMM TYPE SYUCOMM .

  PRIVATE SECTION.

    CLASS-METHODS SET_BUTTON
      IMPORTING
        !IV_ICON   TYPE ICONNAME
        !IV_TEXT   TYPE CSEQUENCE
        !IV_INFO   TYPE CSEQUENCE
      CHANGING
        !CV_BUTTON TYPE CSEQUENCE .

    CLASS-METHODS MAINTAIN_VIEW
      IMPORTING
        !IV_VIEW TYPE TABNAME .

    CLASS-METHODS CALL_LOG_REPORT .

ENDCLASS.


CLASS LCL_COCKPIT IMPLEMENTATION.

  METHOD INIT_BUTTONS.

    SET_BUTTON( EXPORTING IV_ICON   = 'ICON_FILTER'
                          IV_TEXT   = 'Filter maintenance'(T01)
                          IV_INFO   = 'Maintain filter ZSD_SO_CON_FLT'(Q01)
                CHANGING  CV_BUTTON = P_BFLT ).
    SET_BUTTON( EXPORTING IV_ICON   = 'ICON_EMPLOYEE'
                          IV_TEXT   = 'Approver maintenance'(T02)
                          IV_INFO   = 'Maintain approvers ZSD_SO_APPR_CFG'(Q02)
                CHANGING  CV_BUTTON = P_BAPP ).
    SET_BUTTON( EXPORTING IV_ICON   = 'ICON_PROTOCOL'
                          IV_TEXT   = 'Workflow log report'(T03)
                          IV_INFO   = 'Display the approval workflow log'(Q03)
                CHANGING  CV_BUTTON = P_BLOG ).

    P_CFLT = 'Orders in scope (VA01 / VA02 / BOTH, ranges per field)'(C01).
    P_CAPP = 'Approver per sales org / order type / level'(C02).
    P_CLOG = 'Approval runs, levels and timeline'(C03).

  ENDMETHOD.


  METHOD SET_BUTTON.

    DATA LV_RESULT TYPE C LENGTH 45.          " = length of the pushbuttons

    CALL FUNCTION 'ICON_CREATE'
      EXPORTING
        NAME                  = IV_ICON
        TEXT                  = IV_TEXT
        INFO                  = IV_INFO
        ADD_STDINF            = SPACE
      IMPORTING
        RESULT                = LV_RESULT
      EXCEPTIONS
        ICON_NOT_FOUND        = 1
        OUTPUTFIELD_TOO_SHORT = 2
        OTHERS                = 3.

    IF SY-SUBRC = 0.
      CV_BUTTON = LV_RESULT.
    ELSE.
      CV_BUTTON = IV_TEXT.
    ENDIF.

  ENDMETHOD.


  METHOD HIDE_EXECUTE.

    " no list output: hide the Execute (F8) button
    DATA LT_EXCLUDE TYPE STANDARD TABLE OF SYUCOMM.

    APPEND 'ONLI' TO LT_EXCLUDE.

    CALL FUNCTION 'RS_SET_SELSCREEN_STATUS'
      EXPORTING
        P_STATUS  = SY-PFKEY
      TABLES
        P_EXCLUDE = LT_EXCLUDE.

  ENDMETHOD.


  METHOD HANDLE_COMMAND.

    CASE IV_UCOMM.
      WHEN GC_UCOMM_FILTER.
        MAINTAIN_VIEW( GC_VIEW_FILTER ).
      WHEN GC_UCOMM_APPROVER.
        MAINTAIN_VIEW( GC_VIEW_APPROVER ).
      WHEN GC_UCOMM_LOG.
        CALL_LOG_REPORT( ).
    ENDCASE.

  ENDMETHOD.


  METHOD MAINTAIN_VIEW.

    " SM30 maintenance in change mode; authorization (S_TABU_DIS / S_TABU_NAM)
    " is checked by the function module itself
    CALL FUNCTION 'VIEW_MAINTENANCE_CALL'
      EXPORTING
        ACTION                       = 'U'
        VIEW_NAME                    = IV_VIEW
      EXCEPTIONS
        CLIENT_REFERENCE             = 1
        FOREIGN_LOCK                 = 2
        INVALID_ACTION               = 3
        NO_CLIENTINDEPENDENT_AUTH    = 4
        NO_DATABASE_FUNCTION         = 5
        NO_EDITOR_FUNCTION           = 6
        NO_SHOW_AUTH                 = 7
        NO_TVDIR_ENTRY               = 8
        NO_UPD_AUTH                  = 9
        ONLY_SHOW_ALLOWED            = 10
        SYSTEM_FAILURE               = 11
        UNKNOWN_FIELD_IN_DBA_SELLIST = 12
        VIEW_NOT_FOUND               = 13
        MAINTENANCE_PROHIBITED       = 14
        OTHERS                       = 15.

    CASE SY-SUBRC.
      WHEN 0.
      WHEN 2.
        MESSAGE 'Table is locked by another user'(M02) TYPE 'S' DISPLAY LIKE 'E'.
      WHEN 7 OR 9.
        MESSAGE 'No authorization to maintain this table'(M03) TYPE 'S' DISPLAY LIKE 'E'.
      WHEN 8.
        MESSAGE 'Table maintenance generator not created for this table'(M04) TYPE 'S' DISPLAY LIKE 'E'.
      WHEN OTHERS.
        MESSAGE 'Table maintenance could not be called'(M05) TYPE 'S' DISPLAY LIKE 'E'.
    ENDCASE.

  ENDMETHOD.


  METHOD CALL_LOG_REPORT.

    SUBMIT (GC_REPORT_LOG) VIA SELECTION-SCREEN AND RETURN.

  ENDMETHOD.

ENDCLASS.


INITIALIZATION.
  LCL_COCKPIT=>INIT_BUTTONS( ).

AT SELECTION-SCREEN OUTPUT.
  LCL_COCKPIT=>HIDE_EXECUTE( ).

AT SELECTION-SCREEN.
  LCL_COCKPIT=>HANDLE_COMMAND( SSCRFIELDS-UCOMM ).
