*================================================================*
*& Technical Consultant  : Hassan Diab (SNAGFREE)----------------*
*================================================================*
*&---------------------------------------------------------------------*
*& Program        : ZFI_BUDGET_FORECAST_REP
*& Transaction    : ZFI_BUD_FCST_R
*& Type           : Executable Program (Report)
*& Package        : <ZFI>
*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : Ahmed Tawfik
*&---------------------------------------------------------------------*
*& Purpose        : Consolidated Budget Forecast report. Lists every
*&                   submitted forecast (header + items) in one ALV with
*&                   totals per company / cost center / forecast years,
*&                   and exports it to Excel (standard ALV export or a
*&                   direct .xlsx download). Restricted to the Final
*&                   Reviewers (ZFI_BUD_WF_AGENT, level FR) and the
*&                   Final Reviewer assistants (ZFIBUD_ASSISTANT).
*&---------------------------------------------------------------------*
*& Created By     : Hassan Diab
*& Created On     : 07.10.2026
*& Request No.    : <TBD>
*& Version        : 1.0
*&---------------------------------------------------------------------*
*& Change History
*&---------------------------------------------------------------------*
*& Ver | Date       | Author        | Request No.  | Description
*&-----|------------|---------------|--------------|--------------------
*& 1.0 | 07.10.2026 | Hassan Diab   | <TBD>        | Initial creation.
*&---------------------------------------------------------------------*
REPORT ZFI_BUDGET_FORECAST_REP MESSAGE-ID ZBUD_FCST.

TABLES ZFI_BUD_FCST_H.

TYPES: BEGIN OF TY_OUT,
         BUKRS        TYPE ZFI_BUD_FCST_H-BUKRS,
         KOSTL        TYPE ZFI_BUD_FCST_H-KOSTL,
         KTEXT        TYPE CSKT-LTEXT,
         FCST_YEARS   TYPE CHAR9,
         ITEM_NO      TYPE ZFI_BUD_FCST_I-ITEM_NO,
         BUDGET_YEAR  TYPE ZFI_BUD_FCST_I-BUDGET_YEAR,
         PROJ_NAME    TYPE ZFI_BUD_FCST_I-PROJ_NAME,
         PROJ_DESC    TYPE ZFI_BUD_FCST_I-PROJ_DESC,
         PRIORITY     TYPE ZFI_BUD_FCST_I-PRIORITY,
         AMOUNT       TYPE ZFI_BUD_FCST_I-AMOUNT,
         WAERS        TYPE ZFI_BUD_FCST_I-WAERS,
         BUD_TYPE     TYPE ZFI_BUD_FCST_I-BUD_TYPE,
         PROJ_TYPE    TYPE ZFI_BUD_FCST_I-PROJ_TYPE,
         CHANGE_COUNT TYPE ZFI_BUD_FCST_H-CHANGE_COUNT,
         ERNAM        TYPE ZFI_BUD_FCST_H-ERNAM,
         ERDAT        TYPE ZFI_BUD_FCST_H-ERDAT,
         AENAM        TYPE ZFI_BUD_FCST_H-AENAM,
         AEDAT        TYPE ZFI_BUD_FCST_H-AEDAT,
       END OF TY_OUT.

DATA: GT_OUT  TYPE STANDARD TABLE OF TY_OUT,
      GO_SALV TYPE REF TO CL_SALV_TABLE.

SELECTION-SCREEN BEGIN OF BLOCK B01 WITH FRAME TITLE TEXT-B01.
  SELECT-OPTIONS: S_BUKRS FOR ZFI_BUD_FCST_H-BUKRS,
                  S_KOSTL FOR ZFI_BUD_FCST_H-KOSTL,
                  S_FYEAR FOR ZFI_BUD_FCST_H-FYEAR_FROM,
                  S_ERNAM FOR ZFI_BUD_FCST_H-ERNAM.
SELECTION-SCREEN END OF BLOCK B01.

SELECTION-SCREEN BEGIN OF BLOCK B02 WITH FRAME TITLE TEXT-B02.
  PARAMETERS P_XLSX AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK B02.

INITIALIZATION.
  PERFORM CHECK_AUTHORIZATION.

START-OF-SELECTION.
  PERFORM GET_DATA.

  IF GT_OUT IS INITIAL.
    MESSAGE S024 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  PERFORM BUILD_ALV.

  IF P_XLSX = 'X'.
    PERFORM DOWNLOAD_EXCEL.
  ENDIF.

  GO_SALV->DISPLAY( ).

*&---------------------------------------------------------------------*
*& Form CHECK_AUTHORIZATION
*&  Final Reviewer (any cost center) or Final Reviewer assistant.
*&---------------------------------------------------------------------*
FORM CHECK_AUTHORIZATION.

  DATA: LV_FR TYPE I,
        LV_AS TYPE I.

  SELECT COUNT(*) FROM ZFI_BUD_WF_AGENT
    INTO LV_FR
    WHERE AGENT_USER = SY-UNAME
      AND ZLEVEL     = 'FR'
      AND ACTIVE     = 'X'.

  SELECT COUNT(*) FROM ZFIBUD_ASSISTANT
    INTO LV_AS
    WHERE USER_ID = SY-UNAME
      AND ACTIVE  = 'X'.

  IF LV_FR = 0 AND LV_AS = 0.
    MESSAGE S023 DISPLAY LIKE 'E'.
    LEAVE PROGRAM.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form GET_DATA
*&---------------------------------------------------------------------*
FORM GET_DATA.

  TYPES: BEGIN OF TY_TEXT,
           BUKRS TYPE BUKRS,
           KOSTL TYPE KOSTL,
           LTEXT TYPE CSKT-LTEXT,
         END OF TY_TEXT.

  DATA: LT_TEXT  TYPE HASHED TABLE OF TY_TEXT WITH UNIQUE KEY BUKRS KOSTL,
        LS_TEXT  TYPE TY_TEXT,
        LV_KOKRS TYPE KOKRS,
        LS_OUT   TYPE TY_OUT.

  CLEAR GT_OUT.

  SELECT H~BUKRS, H~KOSTL, H~FYEAR_FROM, H~FYEAR_TO, H~CHANGE_COUNT,
         H~ERNAM, H~ERDAT, H~AENAM, H~AEDAT,
         I~ITEM_NO, I~BUDGET_YEAR, I~PROJ_NAME, I~PROJ_DESC, I~PRIORITY,
         I~AMOUNT, I~WAERS, I~BUD_TYPE, I~PROJ_TYPE
    FROM ZFI_BUD_FCST_H AS H
    INNER JOIN ZFI_BUD_FCST_I AS I
      ON  I~BUKRS      = H~BUKRS
      AND I~KOSTL      = H~KOSTL
      AND I~FYEAR_FROM = H~FYEAR_FROM
      AND I~FYEAR_TO   = H~FYEAR_TO
    INTO TABLE @DATA(LT_RAW)
    WHERE H~BUKRS      IN @S_BUKRS
      AND H~KOSTL      IN @S_KOSTL
      AND H~FYEAR_FROM IN @S_FYEAR
      AND H~ERNAM      IN @S_ERNAM
    ORDER BY H~BUKRS, H~KOSTL, H~FYEAR_FROM, I~ITEM_NO.

  LOOP AT LT_RAW INTO DATA(LS_RAW).

    CLEAR LS_OUT.
    MOVE-CORRESPONDING LS_RAW TO LS_OUT.
    LS_OUT-FCST_YEARS = |{ LS_RAW-FYEAR_FROM }-{ LS_RAW-FYEAR_TO }|.

    " cost center text, buffered per company / cost center
    READ TABLE LT_TEXT INTO LS_TEXT
         WITH TABLE KEY BUKRS = LS_RAW-BUKRS KOSTL = LS_RAW-KOSTL.
    IF SY-SUBRC <> 0.
      CLEAR LS_TEXT.
      LS_TEXT-BUKRS = LS_RAW-BUKRS.
      LS_TEXT-KOSTL = LS_RAW-KOSTL.
      CLEAR LV_KOKRS.
      SELECT SINGLE KOKRS FROM TKA02 INTO LV_KOKRS
        WHERE BUKRS = LS_RAW-BUKRS.
      IF SY-SUBRC <> 0.
        LV_KOKRS = LS_RAW-BUKRS.
      ENDIF.
      SELECT SINGLE LTEXT FROM CSKT INTO LS_TEXT-LTEXT
        WHERE SPRAS  = SY-LANGU
          AND KOKRS  = LV_KOKRS
          AND KOSTL  = LS_RAW-KOSTL
          AND DATBI >= SY-DATUM.
      INSERT LS_TEXT INTO TABLE LT_TEXT.
    ENDIF.
    LS_OUT-KTEXT = LS_TEXT-LTEXT.

    APPEND LS_OUT TO GT_OUT.

  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form BUILD_ALV
*&---------------------------------------------------------------------*
FORM BUILD_ALV.

  DATA: LO_COLUMNS TYPE REF TO CL_SALV_COLUMNS_TABLE,
        LO_SORTS   TYPE REF TO CL_SALV_SORTS,
        LS_KEY     TYPE SALV_S_LAYOUT_KEY.

  TRY.
      CL_SALV_TABLE=>FACTORY(
        IMPORTING R_SALV_TABLE = GO_SALV
        CHANGING  T_TABLE      = GT_OUT ).

      GO_SALV->GET_FUNCTIONS( )->SET_ALL( ABAP_TRUE ).

      GO_SALV->GET_DISPLAY_SETTINGS( )->SET_STRIPED_PATTERN( ABAP_TRUE ).
      GO_SALV->GET_DISPLAY_SETTINGS( )->SET_LIST_HEADER(
        CONV LVC_TITLE( |Consolidated Budget Forecast Report ({ LINES( GT_OUT ) } items)| ) ).

      LS_KEY-REPORT = SY-REPID.
      GO_SALV->GET_LAYOUT( )->SET_KEY( LS_KEY ).
      GO_SALV->GET_LAYOUT( )->SET_SAVE_RESTRICTION( IF_SALV_C_LAYOUT=>RESTRICT_NONE ).
      GO_SALV->GET_LAYOUT( )->SET_DEFAULT( ABAP_TRUE ).

      LO_COLUMNS = GO_SALV->GET_COLUMNS( ).
      LO_COLUMNS->SET_OPTIMIZE( ABAP_TRUE ).

      PERFORM SET_COLUMN_TEXT USING LO_COLUMNS:
        'BUKRS'        'Company Code',
        'KOSTL'        'Cost Center',
        'KTEXT'        'Department',
        'FCST_YEARS'   'Forecast Years',
        'ITEM_NO'      'Sequence',
        'BUDGET_YEAR'  'Budget Year',
        'PROJ_NAME'    'Project Name',
        'PROJ_DESC'    'Project Description',
        'PRIORITY'     'Project Priority',
        'AMOUNT'       'Project Budget',
        'WAERS'        'Currency',
        'BUD_TYPE'     'Opex / Capex',
        'PROJ_TYPE'    'Project Type',
        'CHANGE_COUNT' 'Updates Used',
        'ERNAM'        'Created By',
        'ERDAT'        'Created On',
        'AENAM'        'Last Changed By',
        'AEDAT'        'Last Changed On'.

      " grand total and subtotal per forecast submission
      GO_SALV->GET_AGGREGATIONS( )->ADD_AGGREGATION( COLUMNNAME = 'AMOUNT' ).

      LO_SORTS = GO_SALV->GET_SORTS( ).
      LO_SORTS->ADD_SORT( COLUMNNAME = 'BUKRS' ).
      LO_SORTS->ADD_SORT( COLUMNNAME = 'KOSTL' ).
      LO_SORTS->ADD_SORT( COLUMNNAME = 'FCST_YEARS' SUBTOTAL = ABAP_TRUE ).
      LO_SORTS->ADD_SORT( COLUMNNAME = 'ITEM_NO' ).

    CATCH CX_SALV_MSG CX_SALV_NOT_FOUND CX_SALV_EXISTING CX_SALV_DATA_ERROR
          INTO DATA(LX_SALV).
      MESSAGE LX_SALV TYPE 'E'.
  ENDTRY.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form SET_COLUMN_TEXT
*&---------------------------------------------------------------------*
FORM SET_COLUMN_TEXT USING U_COLUMNS TYPE REF TO CL_SALV_COLUMNS_TABLE
                           U_NAME    TYPE CSEQUENCE
                           U_TEXT    TYPE CSEQUENCE.

  DATA LO_COLUMN TYPE REF TO CL_SALV_COLUMN.

  TRY.
      LO_COLUMN = U_COLUMNS->GET_COLUMN( CONV LVC_FNAME( U_NAME ) ).
      LO_COLUMN->SET_LONG_TEXT(   CONV SCRTEXT_L( U_TEXT ) ).
      LO_COLUMN->SET_MEDIUM_TEXT( CONV SCRTEXT_M( U_TEXT ) ).
      LO_COLUMN->SET_SHORT_TEXT(  CONV SCRTEXT_S( U_TEXT ) ).
    CATCH CX_SALV_NOT_FOUND.
  ENDTRY.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form DOWNLOAD_EXCEL
*&  Direct .xlsx download of the ALV (with its column texts).
*&---------------------------------------------------------------------*
FORM DOWNLOAD_EXCEL.

  DATA: LV_XSTRING  TYPE XSTRING,
        LT_SOLIX    TYPE SOLIX_TAB,
        LV_SIZE     TYPE I,
        LV_FILENAME TYPE STRING,
        LV_PATH     TYPE STRING,
        LV_FULLPATH TYPE STRING.

  LV_XSTRING = GO_SALV->TO_XML( XML_TYPE = IF_SALV_BS_XML=>C_TYPE_XLSX ).

  LT_SOLIX = CL_BCS_CONVERT=>XSTRING_TO_SOLIX( IV_XSTRING = LV_XSTRING ).
  LV_SIZE  = XSTRLEN( LV_XSTRING ).

  CALL METHOD CL_GUI_FRONTEND_SERVICES=>FILE_SAVE_DIALOG
    EXPORTING
      WINDOW_TITLE      = 'Save Budget Forecast Report'
      DEFAULT_EXTENSION = 'xlsx'
      DEFAULT_FILE_NAME = |Budget Forecast-{ SY-DATUM }-{ SY-UZEIT }.xlsx|
      FILE_FILTER       = 'Excel Files (*.xlsx)|*.xlsx|All Files (*.*)|*.*'
    CHANGING
      FILENAME          = LV_FILENAME
      PATH              = LV_PATH
      FULLPATH          = LV_FULLPATH
    EXCEPTIONS
      OTHERS            = 1.
  IF SY-SUBRC <> 0 OR LV_FULLPATH IS INITIAL.
    MESSAGE 'Download cancelled by user.' TYPE 'S'.
    RETURN.
  ENDIF.

  CALL FUNCTION 'GUI_DOWNLOAD'
    EXPORTING
      FILENAME                = LV_FULLPATH
      FILETYPE                = 'BIN'
      BIN_FILESIZE            = LV_SIZE
    TABLES
      DATA_TAB                = LT_SOLIX
    EXCEPTIONS
      FILE_WRITE_ERROR        = 1
      NO_BATCH                = 2
      GUI_REFUSE_FILETRANSFER = 3
      OTHERS                  = 4.

  IF SY-SUBRC = 0.
    MESSAGE |File exported successfully: { LV_FULLPATH }| TYPE 'S'.
  ELSE.
    MESSAGE 'Error occurred during file download!' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.

ENDFORM.
