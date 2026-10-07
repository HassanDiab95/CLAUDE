*================================================================*
*& Technical Consultant  : Hassan Diab (SNAGFREE)----------------*
*================================================================*
*&---------------------------------------------------------------------*
*& Include        : ZFI_BUDGET_FCST_F01
*& Main Program   : ZFI_BUDGET_FORECAST
*& Package        : <ZFI>
*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : Ahmed Tawfik
*&---------------------------------------------------------------------*
*& Purpose        : Subroutines for the Budget Forecast application:
*&                   entry authorization, header validation, duplicate
*&                   prevention, item handling, save for create and
*&                   change (max. two updates, creator only, within the
*&                   creation year) and the e-mail notification to the
*&                   Final Reviewers and their assistants.
*&---------------------------------------------------------------------*
*& Created By     : Hassan Diab
*& Created On     : 07.10.2026
*& Request No.    : <TBD>
*& Version        : 1.0
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& Form INIT_PROGRAM
*&  Runs once: decides the mode from the transaction code and checks
*&  that the user may use the application at all.
*&---------------------------------------------------------------------*
FORM INIT_PROGRAM.

  CHECK GV_INITIALIZED IS INITIAL.
  GV_INITIALIZED = 'X'.

  GR_CREATE_ROLE = VALUE #( SIGN = 'I' OPTION = 'EQ'
                            ( LOW = 'CRE' ) ( LOW = 'C&M' )
                            ( LOW = 'CMD' ) ( LOW = 'ALL' ) ).

  IF SY-TCODE = GC_TCODE_MODIFY.
    GV_MODE = 'M'.
  ELSE.
    GV_MODE = 'C'.
  ENDIF.

  PERFORM CHECK_USER_ENTRY.

  PERFORM RESET_SCREEN.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form CHECK_USER_ENTRY
*&  Create : user must hold a creator role (with create) in
*&           ZBUD_CREATORS for at least one cost center.
*&  Modify : user must be a creator or have created a forecast.
*&---------------------------------------------------------------------*
FORM CHECK_USER_ENTRY.

  DATA: LV_CRE TYPE I,
        LV_OWN TYPE I.

  SELECT COUNT(*) FROM ZBUD_CREATORS
    INTO LV_CRE
    WHERE USER_ID      = SY-UNAME
      AND CREATOR_ROLE IN GR_CREATE_ROLE
      AND VALID_FROM  <= SY-DATUM
      AND VALID_TO    >= SY-DATUM
      AND ACTIVE       = 'X'.

  IF GV_MODE = 'M'.
    SELECT COUNT(*) FROM ZFI_BUD_FCST_H
      INTO LV_OWN
      WHERE ERNAM = SY-UNAME.
  ENDIF.

  IF LV_CRE = 0 AND LV_OWN = 0.
    CALL FUNCTION 'POPUP_TO_INFORM'
      EXPORTING
        TITEL = 'Authorization'
        TXT1  = 'You are not authorized to access'
        TXT2  = 'the Budget Forecast application.'.
    LEAVE PROGRAM.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form RESET_SCREEN
*&  Back to the initial (header entry) state.
*&---------------------------------------------------------------------*
FORM RESET_SCREEN.

  DATA: LV_FROM TYPE GJAHR,
        LV_TO   TYPE GJAHR.

  CLEAR: GS_HEAD, GS_HEAD_DB, GT_ITEM[], GS_ITEM, GT_ITEM_DB[],
         GV_KTEXT, GV_CHANGES_TEXT, GV_READONLY, GV_FCST_YEARS.

  GV_STATUS = 'I'.

  " Create: the only allowed years are the current forecast window
  IF GV_MODE = 'C'.
    PERFORM GET_FORECAST_WINDOW CHANGING LV_FROM LV_TO.
    GV_FCST_YEARS = |{ LV_FROM }-{ LV_TO }|.
  ENDIF.

  CASE GV_MODE.
    WHEN 'C'.
      CALL FUNCTION 'ICON_CREATE'
        EXPORTING
          NAME   = 'ICON_BOM_SUB_ITEM'
          TEXT   = 'Create Items'
          INFO   = 'Create Items'
        IMPORTING
          RESULT = GV_PROCEED_TO_ITEMS.
    WHEN 'M'.
      CALL FUNCTION 'ICON_CREATE'
        EXPORTING
          NAME   = 'ICON_BOM_SUB_ITEM'
          TEXT   = 'Change Items'
          INFO   = 'Change Items'
        IMPORTING
          RESULT = GV_PROCEED_TO_ITEMS.
  ENDCASE.

  CT_FCST-TOP_LINE = 1.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form GET_FORECAST_WINDOW
*&  The two forecast years offered for a new submission.
*&---------------------------------------------------------------------*
FORM GET_FORECAST_WINDOW CHANGING C_FROM TYPE GJAHR
                                  C_TO   TYPE GJAHR.

  C_FROM = SY-DATUM(4) + GC_YEAR_OFFSET.
  C_TO   = C_FROM + 1.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form SPLIT_YEARS
*&  '2028-2029' -> 2028 / 2029. C_OK = 'X' when the value is valid.
*&---------------------------------------------------------------------*
FORM SPLIT_YEARS USING    U_YEARS
                 CHANGING C_FROM TYPE GJAHR
                          C_TO   TYPE GJAHR
                          C_OK.

  DATA: LV_FROM TYPE STRING,
        LV_TO   TYPE STRING.

  CLEAR: C_FROM, C_TO, C_OK.

  SPLIT U_YEARS AT '-' INTO LV_FROM LV_TO.

  IF LV_FROM CO '0123456789' AND STRLEN( LV_FROM ) = 4 AND
     LV_TO   CO '0123456789' AND STRLEN( LV_TO ) = 4.
    C_FROM = LV_FROM.
    C_TO   = LV_TO.
    IF C_TO = C_FROM + 1.
      C_OK = 'X'.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form SET_LISTBOXES
*&  Header years listbox and the item "Budget Year" listbox.
*&---------------------------------------------------------------------*
FORM SET_LISTBOXES.

  DATA: LT_VALUES TYPE VRM_VALUES,
        LV_FROM   TYPE GJAHR,
        LV_TO     TYPE GJAHR.

  " ---- Header: Forecast Budget Years ----
  CASE GV_MODE.
    WHEN 'C'.
      PERFORM GET_FORECAST_WINDOW CHANGING LV_FROM LV_TO.
      APPEND VALUE #( KEY  = |{ LV_FROM }-{ LV_TO }|
                      TEXT = |{ LV_FROM }-{ LV_TO }| ) TO LT_VALUES.
    WHEN 'M'.
      " the years of the forecasts this user created
      SELECT DISTINCT FYEAR_FROM, FYEAR_TO
        FROM ZFI_BUD_FCST_H
        INTO TABLE @DATA(LT_YEARS)
        WHERE ERNAM = @SY-UNAME
        ORDER BY FYEAR_FROM DESCENDING.
      LOOP AT LT_YEARS INTO DATA(LS_YEARS).
        APPEND VALUE #( KEY  = |{ LS_YEARS-FYEAR_FROM }-{ LS_YEARS-FYEAR_TO }|
                        TEXT = |{ LS_YEARS-FYEAR_FROM }-{ LS_YEARS-FYEAR_TO }| )
          TO LT_VALUES.
      ENDLOOP.
  ENDCASE.

  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      ID              = 'GV_FCST_YEARS'
      VALUES          = LT_VALUES
    EXCEPTIONS
      ID_ILLEGAL_NAME = 1
      OTHERS          = 2.

  " ---- Items: Budget Year (one of the two forecast years) ----
  CLEAR LT_VALUES.
  IF GV_STATUS = 'E'.
    APPEND VALUE #( KEY = |{ GS_HEAD-FYEAR_FROM }| TEXT = |{ GS_HEAD-FYEAR_FROM }| ) TO LT_VALUES.
    APPEND VALUE #( KEY = |{ GS_HEAD-FYEAR_TO }|   TEXT = |{ GS_HEAD-FYEAR_TO }| )   TO LT_VALUES.
  ENDIF.

  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      ID              = 'GS_ITEM-BUDGET_YEAR'
      VALUES          = LT_VALUES
    EXCEPTIONS
      ID_ILLEGAL_NAME = 1
      OTHERS          = 2.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form GET_KOKRS
*&---------------------------------------------------------------------*
FORM GET_KOKRS USING    U_BUKRS TYPE BUKRS
               CHANGING C_KOKRS TYPE KOKRS.

  CLEAR C_KOKRS.
  SELECT SINGLE KOKRS FROM TKA02 INTO C_KOKRS
    WHERE BUKRS = U_BUKRS.
  IF SY-SUBRC <> 0.
    C_KOKRS = U_BUKRS.   "same convention as ZFI_BUDGET_PREPERATION
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form VALIDATE_HEADER
*&  Called from the header CHAIN, so E messages re-open the fields.
*&---------------------------------------------------------------------*
FORM VALIDATE_HEADER.

  DATA: LV_KOKRS  TYPE KOKRS,
        LV_OK     TYPE C,
        LV_W_FROM TYPE GJAHR,
        LV_W_TO   TYPE GJAHR,
        LV_WINDOW TYPE SY-MSGV1.

  " ---- Company code ----
  SELECT SINGLE BUKRS FROM T001 INTO @DATA(LV_BUKRS)
    WHERE BUKRS = @GS_HEAD-BUKRS.
  IF SY-SUBRC <> 0.
    MESSAGE E001 WITH GS_HEAD-BUKRS.
  ENDIF.

  " ---- Cost center (department) ----
  PERFORM GET_KOKRS USING GS_HEAD-BUKRS CHANGING LV_KOKRS.
  SELECT SINGLE KOSTL FROM CSKS INTO @DATA(LV_KOSTL)
    WHERE KOKRS  = @LV_KOKRS
      AND KOSTL  = @GS_HEAD-KOSTL
      AND DATBI >= @SY-DATUM.
  IF SY-SUBRC <> 0.
    MESSAGE E002 WITH GS_HEAD-KOSTL LV_KOKRS.
  ENDIF.

  " ---- Forecast years ----
  PERFORM SPLIT_YEARS USING GV_FCST_YEARS
                      CHANGING GS_HEAD-FYEAR_FROM GS_HEAD-FYEAR_TO LV_OK.
  IF LV_OK IS INITIAL.
    MESSAGE E003.
  ENDIF.

  CASE GV_MODE.

    WHEN 'C'. "create
      " only the current forecast window can be created
      PERFORM GET_FORECAST_WINDOW CHANGING LV_W_FROM LV_W_TO.
      IF GS_HEAD-FYEAR_FROM <> LV_W_FROM.
        LV_WINDOW = |{ LV_W_FROM }-{ LV_W_TO }|.
        MESSAGE E004 WITH LV_WINDOW.
      ENDIF.

      " creator role with create for this cost center
      SELECT SINGLE USER_ID FROM ZBUD_CREATORS INTO @DATA(LV_USER)
        WHERE USER_ID      = @SY-UNAME
          AND KOSTL        = @GS_HEAD-KOSTL
          AND CREATOR_ROLE IN @GR_CREATE_ROLE
          AND VALID_FROM  <= @SY-DATUM
          AND VALID_TO    >= @SY-DATUM
          AND ACTIVE       = 'X'.
      IF SY-SUBRC <> 0.
        MESSAGE E005 WITH GS_HEAD-KOSTL.
      ENDIF.

      " duplicate prevention: Company + Department + Years
      SELECT SINGLE ERNAM FROM ZFI_BUD_FCST_H INTO @DATA(LV_ERNAM)
        WHERE BUKRS      = @GS_HEAD-BUKRS
          AND KOSTL      = @GS_HEAD-KOSTL
          AND FYEAR_FROM = @GS_HEAD-FYEAR_FROM
          AND FYEAR_TO   = @GS_HEAD-FYEAR_TO.
      IF SY-SUBRC = 0.
        MESSAGE E006 WITH GS_HEAD-BUKRS GS_HEAD-KOSTL GV_FCST_YEARS LV_ERNAM.
      ENDIF.

    WHEN 'M'. "modify
      SELECT SINGLE * FROM ZFI_BUD_FCST_H INTO @DATA(LS_HEAD)
        WHERE BUKRS      = @GS_HEAD-BUKRS
          AND KOSTL      = @GS_HEAD-KOSTL
          AND FYEAR_FROM = @GS_HEAD-FYEAR_FROM
          AND FYEAR_TO   = @GS_HEAD-FYEAR_TO.
      IF SY-SUBRC <> 0.
        MESSAGE E007 WITH GS_HEAD-BUKRS GS_HEAD-KOSTL GV_FCST_YEARS.
      ENDIF.

      " only the creator of the forecast request may open it here
      IF LS_HEAD-ERNAM <> SY-UNAME.
        MESSAGE E008 WITH LS_HEAD-ERNAM.
      ENDIF.

  ENDCASE.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form PROCESS_HEADER
*&  Header accepted -> open the items.
*&---------------------------------------------------------------------*
FORM PROCESS_HEADER.

  DATA: LV_ALLOWED TYPE C,
        LV_MSGNO   TYPE SY-MSGNO,
        LV_MSGV1   TYPE SY-MSGV1.

  GS_HEAD-WAERS = GC_CURRENCY.

  CASE GV_MODE.

    WHEN 'C'. "create
      CLEAR: GT_ITEM[], GT_ITEM_DB[], GS_HEAD_DB.
      GV_STATUS = 'E'.
      PERFORM INSERT_ROW.

    WHEN 'M'. "modify
      SELECT SINGLE * FROM ZFI_BUD_FCST_H INTO GS_HEAD_DB
        WHERE BUKRS      = GS_HEAD-BUKRS
          AND KOSTL      = GS_HEAD-KOSTL
          AND FYEAR_FROM = GS_HEAD-FYEAR_FROM
          AND FYEAR_TO   = GS_HEAD-FYEAR_TO.

      GS_HEAD = GS_HEAD_DB.

      SELECT * FROM ZFI_BUD_FCST_I INTO TABLE GT_ITEM_DB
        WHERE BUKRS      = GS_HEAD-BUKRS
          AND KOSTL      = GS_HEAD-KOSTL
          AND FYEAR_FROM = GS_HEAD-FYEAR_FROM
          AND FYEAR_TO   = GS_HEAD-FYEAR_TO
        ORDER BY ITEM_NO.

      MOVE-CORRESPONDING GT_ITEM_DB[] TO GT_ITEM[].

      GV_STATUS = 'E'.

      PERFORM CHECK_CHANGE_ALLOWED CHANGING LV_ALLOWED LV_MSGNO LV_MSGV1.
      IF LV_ALLOWED = 'X'.
        CLEAR GV_READONLY.
        MESSAGE ID 'ZBUD_FCST' TYPE 'S' NUMBER LV_MSGNO
                WITH GS_HEAD_DB-CHANGE_COUNT GC_MAX_CHANGES.
      ELSE.
        GV_READONLY = 'X'.
        MESSAGE ID 'ZBUD_FCST' TYPE 'I' NUMBER LV_MSGNO
                WITH LV_MSGV1 DISPLAY LIKE 'W'.
      ENDIF.

  ENDCASE.

  PERFORM SET_CHANGES_TEXT.
  PERFORM DO_CALCULATION.

  CT_FCST-TOP_LINE = 1.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form CHECK_CHANGE_ALLOWED
*&  Rules for updating a saved forecast:
*&   1. only the creator of the request
*&   2. at most GC_MAX_CHANGES updates
*&   3. only within the calendar year the forecast was created in;
*&      once the next year starts the forecast is frozen
*&  C_MSGNO is the message to show (020 when allowed).
*&---------------------------------------------------------------------*
FORM CHECK_CHANGE_ALLOWED CHANGING C_ALLOWED
                                   C_MSGNO TYPE SY-MSGNO
                                   C_MSGV1 TYPE SY-MSGV1.

  CLEAR: C_ALLOWED, C_MSGNO, C_MSGV1.

  IF GS_HEAD_DB-ERNAM <> SY-UNAME.
    C_MSGNO = '008'.
    C_MSGV1 = GS_HEAD_DB-ERNAM.
    RETURN.
  ENDIF.

  IF GS_HEAD_DB-CHANGE_COUNT >= GC_MAX_CHANGES.
    C_MSGNO = '021'.
    C_MSGV1 = GC_MAX_CHANGES.
    RETURN.
  ENDIF.

  IF SY-DATUM(4) > GS_HEAD_DB-ERDAT(4).
    C_MSGNO = '022'.
    C_MSGV1 = GS_HEAD_DB-ERDAT(4).
    RETURN.
  ENDIF.

  C_ALLOWED = 'X'.
  C_MSGNO   = '020'.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form SET_CHANGES_TEXT
*&---------------------------------------------------------------------*
FORM SET_CHANGES_TEXT.

  CLEAR GV_CHANGES_TEXT.
  IF GV_MODE = 'M' AND GV_STATUS = 'E'.
    GV_CHANGES_TEXT = |{ GS_HEAD_DB-CHANGE_COUNT } of { GC_MAX_CHANGES } used|.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form DO_CALCULATION
*&---------------------------------------------------------------------*
FORM DO_CALCULATION.

  DATA LR_ITEM LIKE REF TO GS_ITEM.

  CLEAR GS_HEAD-TOTAL_AMOUNT.

  LOOP AT GT_ITEM REFERENCE INTO LR_ITEM.
    LR_ITEM->KOSTL = GS_HEAD-KOSTL.
    LR_ITEM->WAERS = GC_CURRENCY.
    ADD LR_ITEM->AMOUNT TO GS_HEAD-TOTAL_AMOUNT.
  ENDLOOP.

  GS_HEAD-WAERS = GC_CURRENCY.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form INSERT_ROW
*&---------------------------------------------------------------------*
FORM INSERT_ROW.

  DATA LV_LINES TYPE I.

  DESCRIBE TABLE GT_ITEM LINES LV_LINES.
  ADD 1 TO LV_LINES.

  CLEAR GS_ITEM.
  GS_ITEM-BUKRS       = GS_HEAD-BUKRS.
  GS_ITEM-KOSTL       = GS_HEAD-KOSTL.
  GS_ITEM-FYEAR_FROM  = GS_HEAD-FYEAR_FROM.
  GS_ITEM-FYEAR_TO    = GS_HEAD-FYEAR_TO.
  GS_ITEM-ITEM_NO     = LV_LINES.
  GS_ITEM-BUDGET_YEAR = GS_HEAD-FYEAR_FROM.
  GS_ITEM-WAERS       = GC_CURRENCY.

  APPEND GS_ITEM TO GT_ITEM.

  " scroll so that the new line is visible
  IF G_CT_FCST_LINES > 0 AND LV_LINES > G_CT_FCST_LINES.
    CT_FCST-TOP_LINE = LV_LINES - G_CT_FCST_LINES + 1.
  ELSE.
    CT_FCST-TOP_LINE = 1.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form DELETE_ROW
*&---------------------------------------------------------------------*
FORM DELETE_ROW.

  DATA LR_ITEM LIKE REF TO GS_ITEM.

  DELETE GT_ITEM WHERE SELECTED = 'X'.

  LOOP AT GT_ITEM REFERENCE INTO LR_ITEM.
    LR_ITEM->ITEM_NO = SY-TABIX.
  ENDLOOP.

  CT_FCST-TOP_LINE = 1.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form SELECT_ALL / DESELECT_ALL
*&---------------------------------------------------------------------*
FORM SELECT_ALL USING U_VALUE.

  DATA LR_ITEM LIKE REF TO GS_ITEM.

  LOOP AT GT_ITEM REFERENCE INTO LR_ITEM.
    LR_ITEM->SELECTED = U_VALUE.
  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form VALIDATE_ITEMS
*&  Mandatory columns of the template: year, name, description,
*&  priority, amount, Opex/Capex, project type.
*&---------------------------------------------------------------------*
FORM VALIDATE_ITEMS CHANGING C_OK.

  DATA: LV_FIELD TYPE FELD-NAME,
        LV_LABEL TYPE SY-MSGV2.

  CLEAR C_OK.

  IF GT_ITEM[] IS INITIAL.
    MESSAGE S009 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  LOOP AT GT_ITEM INTO DATA(LS_ITEM).

    CLEAR: LV_FIELD, LV_LABEL.

    IF LS_ITEM-BUDGET_YEAR <> GS_HEAD-FYEAR_FROM AND
       LS_ITEM-BUDGET_YEAR <> GS_HEAD-FYEAR_TO.
      LV_FIELD = 'GS_ITEM-BUDGET_YEAR'.
      CT_FCST-TOP_LINE = SY-TABIX.
      SET CURSOR FIELD LV_FIELD LINE 1.
      MESSAGE S025 WITH LS_ITEM-ITEM_NO GS_HEAD-FYEAR_FROM GS_HEAD-FYEAR_TO
              DISPLAY LIKE 'E'.
      RETURN.
    ELSEIF LS_ITEM-PROJ_NAME IS INITIAL.
      LV_FIELD = 'GS_ITEM-PROJ_NAME'.      LV_LABEL = 'Project Name'.
    ELSEIF LS_ITEM-PROJ_DESC IS INITIAL.
      LV_FIELD = 'GS_ITEM-PROJ_DESC'.      LV_LABEL = 'Project Description'.
    ELSEIF LS_ITEM-PRIORITY IS INITIAL.
      LV_FIELD = 'GS_ITEM-PRIORITY'.       LV_LABEL = 'Project Priority'.
    ELSEIF LS_ITEM-BUD_TYPE IS INITIAL.
      LV_FIELD = 'GS_ITEM-BUD_TYPE'.       LV_LABEL = 'Opex / Capex'.
    ELSEIF LS_ITEM-PROJ_TYPE IS INITIAL.
      LV_FIELD = 'GS_ITEM-PROJ_TYPE'.      LV_LABEL = 'Project Type'.
    ELSEIF LS_ITEM-AMOUNT <= 0.
      CT_FCST-TOP_LINE = SY-TABIX.
      SET CURSOR FIELD 'GS_ITEM-AMOUNT' LINE 1.
      MESSAGE S011 WITH LS_ITEM-ITEM_NO DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    IF LV_FIELD IS NOT INITIAL.
      CT_FCST-TOP_LINE = SY-TABIX.
      SET CURSOR FIELD LV_FIELD LINE 1.
      MESSAGE S010 WITH LS_ITEM-ITEM_NO LV_LABEL DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

  ENDLOOP.

  C_OK = 'X'.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form BUILD_DB_ITEMS
*&  Screen items -> database rows with the header key.
*&---------------------------------------------------------------------*
FORM BUILD_DB_ITEMS CHANGING CT_DB TYPE STANDARD TABLE.

  DATA LS_DB TYPE ZFI_BUD_FCST_I.

  CLEAR CT_DB[].

  LOOP AT GT_ITEM INTO DATA(LS_ITEM).
    CLEAR LS_DB.
    MOVE-CORRESPONDING LS_ITEM TO LS_DB.
    LS_DB-MANDT      = SY-MANDT.
    LS_DB-BUKRS      = GS_HEAD-BUKRS.
    LS_DB-KOSTL      = GS_HEAD-KOSTL.
    LS_DB-FYEAR_FROM = GS_HEAD-FYEAR_FROM.
    LS_DB-FYEAR_TO   = GS_HEAD-FYEAR_TO.
    LS_DB-ITEM_NO    = SY-TABIX.
    LS_DB-WAERS      = GC_CURRENCY.
    APPEND LS_DB TO CT_DB.
  ENDLOOP.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form CONFIRM
*&---------------------------------------------------------------------*
FORM CONFIRM USING    U_QUESTION
             CHANGING C_YES.

  DATA: LV_ANSWER,
        LV_QUESTION(400) TYPE C.

  CLEAR C_YES.
  LV_QUESTION = U_QUESTION.

  CALL FUNCTION 'POPUP_TO_CONFIRM'
    EXPORTING
      TITLEBAR              = 'Confirm'
      TEXT_QUESTION         = LV_QUESTION
      TEXT_BUTTON_1         = 'Yes'
      ICON_BUTTON_1         = 'ICON_CHECKED'
      TEXT_BUTTON_2         = 'No'
      ICON_BUTTON_2         = 'ICON_CANCEL'
      DEFAULT_BUTTON        = '1'
      DISPLAY_CANCEL_BUTTON = ' '
    IMPORTING
      ANSWER                = LV_ANSWER.

  IF LV_ANSWER = '1'.
    C_YES = 'X'.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form SAVE_FOR_CREATE
*&---------------------------------------------------------------------*
FORM SAVE_FOR_CREATE.

  DATA: LV_OK       TYPE C,
        LV_YES      TYPE C,
        LV_W_FROM   TYPE GJAHR,
        LV_W_TO     TYPE GJAHR,
        LV_WINDOW   TYPE SY-MSGV1,
        LV_QUEST    TYPE STRING,
        LV_MAIL_ERR TYPE STRING,
        LT_DB       TYPE TABLE OF ZFI_BUD_FCST_I.

  " the window moves on 1 January - re-check if the screen stayed open
  PERFORM GET_FORECAST_WINDOW CHANGING LV_W_FROM LV_W_TO.
  IF GS_HEAD-FYEAR_FROM <> LV_W_FROM.
    LV_WINDOW = |{ LV_W_FROM }-{ LV_W_TO }|.
    MESSAGE S004 WITH LV_WINDOW DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  PERFORM VALIDATE_ITEMS CHANGING LV_OK.
  CHECK LV_OK = 'X'.

  LV_QUEST = |Submit the forecast budget { GV_FCST_YEARS } for cost center | &&
             |{ GS_HEAD-KOSTL ALPHA = OUT }? It can be updated at most | &&
             |{ GC_MAX_CHANGES } times afterwards.|.
  PERFORM CONFIRM USING LV_QUEST CHANGING LV_YES.
  IF LV_YES IS INITIAL.
    MESSAGE S019.
    RETURN.
  ENDIF.

  PERFORM DO_CALCULATION.
  PERFORM BUILD_DB_ITEMS CHANGING LT_DB.

  GET TIME.
  GS_HEAD-MANDT        = SY-MANDT.
  GS_HEAD-WAERS        = GC_CURRENCY.
  GS_HEAD-CHANGE_COUNT = 0.
  GS_HEAD-ERNAM        = SY-UNAME.
  GS_HEAD-ERDAT        = SY-DATUM.
  GS_HEAD-ERZET        = SY-UZEIT.
  CLEAR: GS_HEAD-AENAM, GS_HEAD-AEDAT, GS_HEAD-AEZET.

  " the primary key (BUKRS, KOSTL, FYEAR_FROM, FYEAR_TO) is the final
  " duplicate guard if two creators save the same combination at once
  INSERT ZFI_BUD_FCST_H FROM GS_HEAD.
  IF SY-SUBRC <> 0.
    ROLLBACK WORK.
    SELECT SINGLE ERNAM FROM ZFI_BUD_FCST_H INTO @DATA(LV_ERNAM)
      WHERE BUKRS      = @GS_HEAD-BUKRS
        AND KOSTL      = @GS_HEAD-KOSTL
        AND FYEAR_FROM = @GS_HEAD-FYEAR_FROM
        AND FYEAR_TO   = @GS_HEAD-FYEAR_TO.
    MESSAGE S006 WITH GS_HEAD-BUKRS GS_HEAD-KOSTL GV_FCST_YEARS LV_ERNAM
            DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  INSERT ZFI_BUD_FCST_I FROM TABLE LT_DB ACCEPTING DUPLICATE KEYS.
  IF SY-SUBRC <> 0.
    ROLLBACK WORK.
    MESSAGE S016 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  COMMIT WORK AND WAIT.

  PERFORM SEND_NOTIFICATION USING 'C' CHANGING LV_MAIL_ERR.

  MESSAGE I012 WITH GS_HEAD-BUKRS GS_HEAD-KOSTL GV_FCST_YEARS.
  IF LV_MAIL_ERR IS NOT INITIAL.
    MESSAGE S018 WITH LV_MAIL_ERR DISPLAY LIKE 'W'.
  ENDIF.
  LEAVE TO SCREEN 0.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form SAVE_FOR_CHANGE
*&---------------------------------------------------------------------*
FORM SAVE_FOR_CHANGE.

  DATA: LV_OK      TYPE C,
        LV_YES     TYPE C,
        LV_ALLOWED TYPE C,
        LV_MSGNO   TYPE SY-MSGNO,
        LV_MSGV1   TYPE SY-MSGV1,
        LV_NEXT    TYPE I,
        LV_LEFT    TYPE I,
        LV_QUEST   TYPE STRING,
        LV_MAIL_ERR TYPE STRING,
        LT_DB      TYPE TABLE OF ZFI_BUD_FCST_I.

  IF GV_READONLY = 'X'.
    MESSAGE S026 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " re-check the rules (the year may have changed while on the screen)
  PERFORM CHECK_CHANGE_ALLOWED CHANGING LV_ALLOWED LV_MSGNO LV_MSGV1.
  IF LV_ALLOWED IS INITIAL.
    GV_READONLY = 'X'.
    MESSAGE ID 'ZBUD_FCST' TYPE 'S' NUMBER LV_MSGNO WITH LV_MSGV1
            DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  PERFORM VALIDATE_ITEMS CHANGING LV_OK.
  CHECK LV_OK = 'X'.

  PERFORM DO_CALCULATION.
  PERFORM BUILD_DB_ITEMS CHANGING LT_DB.

  SORT GT_ITEM_DB BY ITEM_NO.
  IF LT_DB[] = GT_ITEM_DB[].
    MESSAGE S014.
    RETURN.
  ENDIF.

  LV_NEXT = GS_HEAD_DB-CHANGE_COUNT + 1.
  LV_LEFT = GC_MAX_CHANGES - LV_NEXT.

  LV_QUEST = |This is update { LV_NEXT } of { GC_MAX_CHANGES } for this forecast. |.
  IF LV_LEFT = 0.
    LV_QUEST = LV_QUEST && |No further updates will be possible. Save?|.
  ELSE.
    LV_QUEST = LV_QUEST && |{ LV_LEFT } update(s) will remain. Save?|.
  ENDIF.

  PERFORM CONFIRM USING LV_QUEST CHANGING LV_YES.
  IF LV_YES IS INITIAL.
    MESSAGE S019.
    RETURN.
  ENDIF.

  GET TIME.

  " optimistic lock: only update if nobody saved in between
  UPDATE ZFI_BUD_FCST_H
     SET CHANGE_COUNT = LV_NEXT
         TOTAL_AMOUNT = GS_HEAD-TOTAL_AMOUNT
         AENAM        = SY-UNAME
         AEDAT        = SY-DATUM
         AEZET        = SY-UZEIT
   WHERE BUKRS        = GS_HEAD-BUKRS
     AND KOSTL        = GS_HEAD-KOSTL
     AND FYEAR_FROM   = GS_HEAD-FYEAR_FROM
     AND FYEAR_TO     = GS_HEAD-FYEAR_TO
     AND CHANGE_COUNT = GS_HEAD_DB-CHANGE_COUNT.
  IF SY-DBCNT = 0.
    ROLLBACK WORK.
    MESSAGE S015 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  DELETE FROM ZFI_BUD_FCST_I
   WHERE BUKRS      = GS_HEAD-BUKRS
     AND KOSTL      = GS_HEAD-KOSTL
     AND FYEAR_FROM = GS_HEAD-FYEAR_FROM
     AND FYEAR_TO   = GS_HEAD-FYEAR_TO.

  INSERT ZFI_BUD_FCST_I FROM TABLE LT_DB ACCEPTING DUPLICATE KEYS.
  IF SY-SUBRC <> 0.
    ROLLBACK WORK.
    MESSAGE S016 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  COMMIT WORK AND WAIT.

  GS_HEAD-CHANGE_COUNT = LV_NEXT.
  GS_HEAD-AENAM        = SY-UNAME.
  GS_HEAD-AEDAT        = SY-DATUM.
  GS_HEAD-AEZET        = SY-UZEIT.

  PERFORM SEND_NOTIFICATION USING 'M' CHANGING LV_MAIL_ERR.

  MESSAGE I013 WITH LV_NEXT GC_MAX_CHANGES.
  IF LV_MAIL_ERR IS NOT INITIAL.
    MESSAGE S018 WITH LV_MAIL_ERR DISPLAY LIKE 'W'.
  ENDIF.
  LEAVE TO SCREEN 0.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form HAS_UNSAVED_CHANGES
*&---------------------------------------------------------------------*
FORM HAS_UNSAVED_CHANGES CHANGING C_CHANGED.

  DATA LT_DB TYPE TABLE OF ZFI_BUD_FCST_I.

  CLEAR C_CHANGED.

  CHECK GV_STATUS = 'E' AND GV_READONLY IS INITIAL.

  PERFORM BUILD_DB_ITEMS CHANGING LT_DB.
  SORT GT_ITEM_DB BY ITEM_NO.

  IF GV_MODE = 'C'.
    " a new forecast with only the empty starter line is not a change
    LOOP AT LT_DB INTO DATA(LS_DB)
         WHERE PROJ_NAME IS NOT INITIAL OR PROJ_DESC IS NOT INITIAL
            OR AMOUNT IS NOT INITIAL.
      C_CHANGED = 'X'.
      EXIT.
    ENDLOOP.
  ELSEIF LT_DB[] <> GT_ITEM_DB[].
    C_CHANGED = 'X'.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form OTHER_FORECAST
*&  Back to the header to pick another forecast.
*&---------------------------------------------------------------------*
FORM OTHER_FORECAST.

  DATA: LV_CHANGED TYPE C,
        LV_YES     TYPE C.

  PERFORM HAS_UNSAVED_CHANGES CHANGING LV_CHANGED.
  IF LV_CHANGED = 'X'.
    PERFORM CONFIRM USING 'Unsaved data will be lost. Continue?'
                    CHANGING LV_YES.
    CHECK LV_YES = 'X'.
  ENDIF.

  PERFORM RESET_SCREEN.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form GET_NOTIFICATION_RECIPIENTS
*&  All active Final Reviewers (ZFI_BUD_WF_AGENT, level FR) and all
*&  active Final Reviewer assistants (ZFIBUD_ASSISTANT).
*&---------------------------------------------------------------------*
FORM GET_NOTIFICATION_RECIPIENTS CHANGING CT_USERS TYPE STANDARD TABLE.

  DATA: LT_USERS TYPE SORTED TABLE OF SY-UNAME WITH UNIQUE KEY TABLE_LINE,
        LV_USER  TYPE SY-UNAME.

  SELECT AGENT_USER FROM ZFI_BUD_WF_AGENT
    INTO TABLE @DATA(LT_FR)
    WHERE ZLEVEL = 'FR'
      AND ACTIVE = 'X'.
  LOOP AT LT_FR INTO DATA(LS_FR).
    LV_USER = LS_FR-AGENT_USER.
    INSERT LV_USER INTO TABLE LT_USERS.
  ENDLOOP.

  SELECT USER_ID FROM ZFIBUD_ASSISTANT
    INTO TABLE @DATA(LT_ASSIST)
    WHERE ACTIVE = 'X'.
  LOOP AT LT_ASSIST INTO DATA(LS_ASSIST).
    LV_USER = LS_ASSIST-USER_ID.
    INSERT LV_USER INTO TABLE LT_USERS.
  ENDLOOP.

  CT_USERS[] = LT_USERS[].

ENDFORM.
*&---------------------------------------------------------------------*
*& Form GET_USER_EMAIL
*&---------------------------------------------------------------------*
FORM GET_USER_EMAIL USING    U_USER TYPE SY-UNAME
                    CHANGING C_SMTP TYPE AD_SMTPADR.

  CLEAR C_SMTP.

  SELECT SINGLE A~SMTP_ADDR
    FROM USR21 AS U
    INNER JOIN ADR6 AS A
      ON  A~ADDRNUMBER = U~ADDRNUMBER
      AND A~PERSNUMBER = U~PERSNUMBER
    INTO @C_SMTP
    WHERE U~BNAME = @U_USER
      AND A~FLGDEFAULT = 'X'.

  IF C_SMTP IS INITIAL.
    SELECT SINGLE A~SMTP_ADDR
      FROM USR21 AS U
      INNER JOIN ADR6 AS A
        ON  A~ADDRNUMBER = U~ADDRNUMBER
        AND A~PERSNUMBER = U~PERSNUMBER
      INTO @C_SMTP
      WHERE U~BNAME = @U_USER.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form SEND_NOTIFICATION
*&  U_ACTION: C = created, M = changed.
*&  Runs after the data is committed; a mail error never undoes the
*&  save, it is only returned in C_ERROR and shown to the user.
*&---------------------------------------------------------------------*
FORM SEND_NOTIFICATION USING    U_ACTION
                       CHANGING C_ERROR TYPE STRING.

  DATA: LT_USERS   TYPE STANDARD TABLE OF SY-UNAME,
        LV_USER    TYPE SY-UNAME,
        LV_SMTP    TYPE AD_SMTPADR,
        LV_ACTION  TYPE STRING,
        LV_SUBJECT TYPE STRING,
        LV_HTML    TYPE STRING,
        LV_FULLNM  TYPE STRING,
        LV_ITEMS   TYPE I,
        LV_AMOUNT  TYPE STRING,
        LO_SEND    TYPE REF TO CL_BCS,
        LO_DOC     TYPE REF TO CL_DOCUMENT_BCS,
        LO_RECIP   TYPE REF TO IF_RECIPIENT_BCS,
        LX_BCS     TYPE REF TO CX_BCS.

  CLEAR C_ERROR.

  PERFORM GET_NOTIFICATION_RECIPIENTS CHANGING LT_USERS.
  IF LT_USERS[] IS INITIAL.
    RETURN.
  ENDIF.

  CASE U_ACTION.
    WHEN 'C'.
      LV_ACTION = 'created'.
    WHEN 'M'.
      LV_ACTION = |changed (update { GS_HEAD-CHANGE_COUNT } of { GC_MAX_CHANGES })|.
  ENDCASE.

  SELECT SINGLE NAME_TEXTC FROM USER_ADDR INTO @DATA(LV_NAME)
    WHERE BNAME = @SY-UNAME.
  IF SY-SUBRC = 0 AND LV_NAME IS NOT INITIAL.
    LV_FULLNM = |{ LV_NAME } ({ SY-UNAME })|.
  ELSE.
    LV_FULLNM = SY-UNAME.
  ENDIF.

  DESCRIBE TABLE GT_ITEM LINES LV_ITEMS.
  LV_AMOUNT = |{ GS_HEAD-TOTAL_AMOUNT NUMBER = USER } { GS_HEAD-WAERS }|.

  LV_SUBJECT = |Budget Forecast { GV_FCST_YEARS } { LV_ACTION } - | &&
               |Company { GS_HEAD-BUKRS } / Cost Center { GS_HEAD-KOSTL ALPHA = OUT }|.

  LV_HTML =
    |<html><body style="font-family:Arial,sans-serif;font-size:10pt">| &&
    |<p>Dear Final Reviewer,</p>| &&
    |<p>A budget forecast has been <b>{ LV_ACTION }</b>.</p>| &&
    |<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse">| &&
    |<tr><td><b>Company</b></td><td>{ GS_HEAD-BUKRS }</td></tr>| &&
    |<tr><td><b>Cost Center Code</b></td><td>{ GS_HEAD-KOSTL ALPHA = OUT } - | &&
    |{ ESCAPE( VAL = CONV STRING( GV_KTEXT ) FORMAT = CL_ABAP_FORMAT=>E_HTML_TEXT ) }</td></tr>| &&
    |<tr><td><b>Forecast Budget Years</b></td><td>{ GV_FCST_YEARS }</td></tr>| &&
    |<tr><td><b>Number of Items</b></td><td>{ LV_ITEMS }</td></tr>| &&
    |<tr><td><b>Total Forecast Amount</b></td><td>{ LV_AMOUNT }</td></tr>| &&
    |<tr><td><b>{ COND STRING( WHEN U_ACTION = 'C' THEN `Created By` ELSE `Changed By` ) }</b></td>| &&
    |<td>{ ESCAPE( VAL = LV_FULLNM FORMAT = CL_ABAP_FORMAT=>E_HTML_TEXT ) }</td></tr>| &&
    |<tr><td><b>Date / Time</b></td><td>{ SY-DATUM DATE = USER } { SY-UZEIT TIME = USER }</td></tr>| &&
    |</table>| &&
    |<p>The submission can be reviewed in the consolidated forecast report | &&
    |(transaction { GC_TCODE_REPORT }).</p>| &&
    |<p>This is an automatic notification from the SAP Budget Forecast application.</p>| &&
    |</body></html>|.

  TRY.
      LO_SEND = CL_BCS=>CREATE_PERSISTENT( ).

      LO_DOC = CL_DOCUMENT_BCS=>CREATE_DOCUMENT(
                 I_TYPE    = 'HTM'
                 I_TEXT    = CL_DOCUMENT_BCS=>STRING_TO_SOLI( LV_HTML )
                 I_SUBJECT = CONV SO_OBJ_DES( LV_SUBJECT ) ).
      LO_SEND->SET_DOCUMENT( LO_DOC ).
      LO_SEND->SET_MESSAGE_SUBJECT( LV_SUBJECT ).

      LO_SEND->SET_SENDER( CL_SAPUSER_BCS=>CREATE( SY-UNAME ) ).

      LOOP AT LT_USERS INTO LV_USER.
        PERFORM GET_USER_EMAIL USING LV_USER CHANGING LV_SMTP.
        IF LV_SMTP IS NOT INITIAL.
          LO_RECIP = CL_CAM_ADDRESS_BCS=>CREATE_INTERNET_ADDRESS( LV_SMTP ).
        ELSE.
          " no e-mail in SU01 -> SAP Business Workplace inbox
          LO_RECIP = CL_SAPUSER_BCS=>CREATE( LV_USER ).
        ENDIF.
        LO_SEND->ADD_RECIPIENT( I_RECIPIENT = LO_RECIP ).
      ENDLOOP.

      LO_SEND->SET_SEND_IMMEDIATELY( ABAP_TRUE ).
      LO_SEND->SEND( ).
      COMMIT WORK.

    CATCH CX_BCS INTO LX_BCS.
      C_ERROR = LX_BCS->GET_TEXT( ).
  ENDTRY.

ENDFORM.
