*&---------------------------------------------------------------------*
*& Object Name    : ZCL_WF_LOG_RPT_DATA
*& Object Type    : Class
*& Package        : ZSD
*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : Nourhan Leila
*&---------------------------------------------------------------------*
*& Purpose        : Selects and enriches the workflow log data for the
*&                   display reports.
*& Note           : A dynamic FROM (name) cannot use INTO TABLE
*&                   @DATA(...). All targets are declared beforehand.
*&---------------------------------------------------------------------*
*& Created By     : Hassan Diab
*& Created On     : 07.09.2026
*& Request No.    : DE3K932563
*& Version        : 1.0
*&---------------------------------------------------------------------*
*& Change History
*&---------------------------------------------------------------------*
*& Ver | Date       | Author      | Request No.  | Description
*&-----|------------|-------------|--------------|---------------------
*& 1.0 | 07.09.2026 | Hassan Diab | DE3K932563   | Initial Version
*&---------------------------------------------------------------------*
CLASS ZCL_WF_LOG_RPT_DATA DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS CONSTRUCTOR
      IMPORTING IV_AREA TYPE CHAR2.

    METHODS SELECT_LIST
      IMPORTING IT_LOG         TYPE ZIF_WF_LOG_RPT=>TR_LOG   OPTIONAL
                IT_VBELN       TYPE ZIF_WF_LOG_RPT=>TR_VBELN OPTIONAL
                IT_BP          TYPE ZIF_WF_LOG_RPT=>TR_BP    OPTIONAL
                IT_BUKRS       TYPE ZIF_WF_LOG_RPT=>TR_BUKRS OPTIONAL
                IT_WERKS       TYPE ZIF_WF_LOG_RPT=>TR_WERKS OPTIONAL
                IT_STAT        TYPE ZIF_WF_LOG_RPT=>TR_STAT  OPTIONAL
                IT_AGENT       TYPE ZIF_WF_LOG_RPT=>TR_AGENT OPTIONAL
                IT_DATE        TYPE ZIF_WF_LOG_RPT=>TR_DATE  OPTIONAL
      RETURNING VALUE(RT_LIST) TYPE ZIF_WF_LOG_RPT=>TT_LIST.

    METHODS SELECT_ITEMS
      IMPORTING IV_LOG_ID      TYPE ZWF_LOG_ID
                IV_AREA        TYPE CHAR2 OPTIONAL
      RETURNING VALUE(RT_ITEM) TYPE ZIF_WF_LOG_RPT=>TT_ITEM.

    METHODS COUNT
      IMPORTING IT_LIST         TYPE ZIF_WF_LOG_RPT=>TT_LIST
      RETURNING VALUE(RS_COUNT) TYPE ZIF_WF_LOG_RPT=>TY_S_COUNT.

    METHODS AREA
      RETURNING VALUE(RV_AREA) TYPE CHAR2.

    METHODS AREA_TEXT
      RETURNING VALUE(RV_TEXT) TYPE STRING.

  PRIVATE SECTION.

    TYPES: BEGIN OF TY_S_LEVEL,
             LEVEL      TYPE INT2,
             AGENT      TYPE XUBNAME,
             AGENT_DESC TYPE ZUSER_DESC,
           END OF TY_S_LEVEL.

    TYPES TY_T_LEVEL TYPE SORTED TABLE OF TY_S_LEVEL
                          WITH UNIQUE KEY LEVEL.

    TYPES: BEGIN OF TY_S_CNT,
             LOG_ID TYPE ZWF_LOG_ID,
             CNT    TYPE I,
           END OF TY_S_CNT.

    TYPES TY_T_CNT TYPE STANDARD TABLE OF TY_S_CNT WITH EMPTY KEY.

    DATA MV_AREA TYPE CHAR2.
    DATA MV_HDR  TYPE TABNAME.
    DATA MV_ITM  TYPE TABNAME.

    DATA MT_STATUS_TXT TYPE STANDARD TABLE OF DD07V WITH EMPTY KEY.
    DATA MT_ACTION_TXT TYPE STANDARD TABLE OF DD07V WITH EMPTY KEY.

    METHODS LOAD_DOMAIN_TEXTS.

    METHODS STATUS_TEXT
      IMPORTING IV_STATUS      TYPE ZWF_STATUS1
      RETURNING VALUE(RV_TEXT) TYPE VAL_TEXT.

    METHODS ACTION_TEXT
      IMPORTING IV_ACTION      TYPE ZWF_ACTION
      RETURNING VALUE(RV_TEXT) TYPE VAL_TEXT.

    METHODS STATUS_ICON
      IMPORTING IV_STATUS      TYPE ZWF_STATUS1
      RETURNING VALUE(RV_ICON) TYPE ICON_D.

    METHODS ACTION_ICON
      IMPORTING IV_ACTION      TYPE ZWF_ACTION
      RETURNING VALUE(RV_ICON) TYPE ICON_D.

    METHODS COLOUR_STATUS
      IMPORTING IV_STATUS       TYPE ZWF_STATUS1
      RETURNING VALUE(RT_COLOR) TYPE LVC_T_SCOL.

    METHODS COLOUR_ACTION
      IMPORTING IV_ACTION       TYPE ZWF_ACTION
      RETURNING VALUE(RT_COLOR) TYPE LVC_T_SCOL.

    METHODS USER_NAME
      IMPORTING IV_BNAME       TYPE XUBNAME
      RETURNING VALUE(RV_NAME) TYPE AD_NAMTEXT.

    METHODS SELECT_COMBINED
      IMPORTING IT_VBELN       TYPE ZIF_WF_LOG_RPT=>TR_VBELN OPTIONAL
                IT_BP          TYPE ZIF_WF_LOG_RPT=>TR_BP    OPTIONAL
                IT_BUKRS       TYPE ZIF_WF_LOG_RPT=>TR_BUKRS OPTIONAL
                IT_WERKS       TYPE ZIF_WF_LOG_RPT=>TR_WERKS OPTIONAL
                IT_STAT        TYPE ZIF_WF_LOG_RPT=>TR_STAT  OPTIONAL
                IT_AGENT       TYPE ZIF_WF_LOG_RPT=>TR_AGENT OPTIONAL
                IT_DATE        TYPE ZIF_WF_LOG_RPT=>TR_DATE  OPTIONAL
      RETURNING VALUE(RT_LIST) TYPE ZIF_WF_LOG_RPT=>TT_LIST.

    METHODS BUILD_LEVEL_MAP
      IMPORTING IV_LOG_ID       TYPE ZWF_LOG_ID
                IV_TABNAME      TYPE TABNAME
      RETURNING VALUE(RT_LEVEL) TYPE TY_T_LEVEL.

    METHODS LEVEL_DESC
      IMPORTING IT_LEVEL       TYPE TY_T_LEVEL
                IV_LEVEL       TYPE INT2
      RETURNING VALUE(RV_DESC) TYPE ZUSER_DESC.

    METHODS LEVEL_USER
      IMPORTING IT_LEVEL       TYPE TY_T_LEVEL
                IV_LEVEL       TYPE INT2
      RETURNING VALUE(RV_USER) TYPE XUBNAME.

ENDCLASS.



CLASS ZCL_WF_LOG_RPT_DATA IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_DATA->ACTION_ICON
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ACTION                      TYPE        ZWF_ACTION
* | [<-()] RV_ICON                        TYPE        ICON_D
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD ACTION_ICON.

    RV_ICON = SWITCH #( IV_ACTION
                WHEN 'STRT' THEN ICON_WORKFLOW_ACTIVITY
                WHEN 'APPR' THEN ICON_OKAY
                WHEN 'REJC' THEN ICON_INCOMPLETE
                WHEN 'RETN' THEN ICON_PREVIOUS_OBJECT
                WHEN 'FINL' THEN ICON_COMPLETE
                WHEN 'RELS' THEN ICON_RELEASE
                WHEN 'CANC' THEN ICON_CANCEL
                WHEN 'MAIL' THEN ICON_MAIL
                WHEN 'MERR' THEN ICON_FAILURE
                WHEN 'KILL' THEN ICON_DELETE
                ELSE             ICON_SPACE ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_DATA->ACTION_TEXT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ACTION                      TYPE        ZWF_ACTION
* | [<-()] RV_TEXT                        TYPE        VAL_TEXT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD ACTION_TEXT.

    READ TABLE MT_ACTION_TXT INTO DATA(LS_DD)
         WITH KEY DOMVALUE_L = IV_ACTION.

    RV_TEXT = COND #( WHEN SY-SUBRC = 0 THEN LS_DD-DDTEXT
                                        ELSE IV_ACTION ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_LOG_RPT_DATA->CONSTRUCTOR
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_AREA                        TYPE        CHAR2
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD CONSTRUCTOR.

    MV_AREA = IV_AREA.

    CASE IV_AREA.

      WHEN ZIF_WF_LOG_RPT=>GC_AREA-CREDIT_LIMIT.
        MV_HDR = ZIF_WF_LOG_RPT=>GC_TABLE_HDR-CREDIT_LIMIT.
        MV_ITM = ZIF_WF_LOG_RPT=>GC_TABLE_ITM-CREDIT_LIMIT.

      WHEN ZIF_WF_LOG_RPT=>GC_AREA-EXCEED.
        MV_HDR = ZIF_WF_LOG_RPT=>GC_TABLE_HDR-EXCEED.
        MV_ITM = ZIF_WF_LOG_RPT=>GC_TABLE_ITM-EXCEED.

      WHEN ZIF_WF_LOG_RPT=>GC_AREA-OVERDUE.
        MV_HDR = ZIF_WF_LOG_RPT=>GC_TABLE_HDR-OVERDUE.
        MV_ITM = ZIF_WF_LOG_RPT=>GC_TABLE_ITM-OVERDUE.

      WHEN ZIF_WF_LOG_RPT=>GC_AREA-COMBINED.
        MV_HDR = ZIF_WF_LOG_RPT=>GC_TABLE_HDR-EXCEED.
        MV_ITM = ZIF_WF_LOG_RPT=>GC_TABLE_ITM-EXCEED.

    ENDCASE.

    LOAD_DOMAIN_TEXTS( ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_LOG_RPT_DATA->COUNT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IT_LIST                        TYPE        ZIF_WF_LOG_RPT=>TT_LIST
* | [<-()] RS_COUNT                       TYPE        ZIF_WF_LOG_RPT=>TY_S_COUNT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD COUNT.

    RS_COUNT-TOTAL = LINES( IT_LIST ).

    LOOP AT IT_LIST INTO DATA(LS_LIST).
      CASE LS_LIST-STATUS.
        WHEN 'I'. RS_COUNT-IN_PROCESS = RS_COUNT-IN_PROCESS + 1.
        WHEN 'A'. RS_COUNT-APPROVED   = RS_COUNT-APPROVED   + 1.
        WHEN 'R'. RS_COUNT-REJECTED   = RS_COUNT-REJECTED   + 1.
        WHEN 'C'. RS_COUNT-CANCELLED  = RS_COUNT-CANCELLED  + 1.
        WHEN 'K'. RS_COUNT-KILLED     = RS_COUNT-KILLED     + 1.
      ENDCASE.
    ENDLOOP.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_LOG_RPT_DATA->SELECT_ITEMS
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_LOG_ID                      TYPE        ZWF_LOG_ID
* | [--->] IV_AREA                        TYPE        CHAR2(optional)
* | [<-()] RT_ITEM                        TYPE        ZIF_WF_LOG_RPT=>TT_ITEM
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD SELECT_ITEMS.

    DATA LV_ITM TYPE TABNAME.

    LV_ITM = COND #(
      WHEN IV_AREA = ZIF_WF_LOG_RPT=>GC_AREA-EXCEED
        THEN ZIF_WF_LOG_RPT=>GC_TABLE_ITM-EXCEED
      WHEN IV_AREA = ZIF_WF_LOG_RPT=>GC_AREA-OVERDUE
        THEN ZIF_WF_LOG_RPT=>GC_TABLE_ITM-OVERDUE
      WHEN IV_AREA = ZIF_WF_LOG_RPT=>GC_AREA-CREDIT_LIMIT
        THEN ZIF_WF_LOG_RPT=>GC_TABLE_ITM-CREDIT_LIMIT
      ELSE MV_ITM ).

    CHECK LV_ITM IS NOT INITIAL AND IV_LOG_ID IS NOT INITIAL.

    DATA LR_DATA TYPE REF TO DATA.
    DATA LS_ITEM TYPE ZIF_WF_LOG_RPT=>TY_S_ITEM.

    FIELD-SYMBOLS <LT_RAW> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <LS_RAW> TYPE ANY.

    DATA(LT_LEVEL) = BUILD_LEVEL_MAP( IV_LOG_ID  = IV_LOG_ID
                                      IV_TABNAME = LV_ITM ).

    CREATE DATA LR_DATA TYPE STANDARD TABLE OF (LV_ITM).
    ASSIGN LR_DATA->* TO <LT_RAW>.

    SELECT * FROM (LV_ITM)
      WHERE LOG_ID = @IV_LOG_ID
      ORDER BY SEQNR
      INTO TABLE @<LT_RAW>.

    LOOP AT <LT_RAW> ASSIGNING <LS_RAW>.

      CLEAR LS_ITEM.
      MOVE-CORRESPONDING <LS_RAW> TO LS_ITEM.

      LS_ITEM-ACTION_ICON = ACTION_ICON( LS_ITEM-ACTION ).
      LS_ITEM-ACTION_TEXT = ACTION_TEXT( LS_ITEM-ACTION ).
      LS_ITEM-ROW_COLOR   = COLOUR_ACTION( LS_ITEM-ACTION ).
      LS_ITEM-ACTUAL_NAME = USER_NAME( LS_ITEM-ACTUAL_AGENT ).

      IF LS_ITEM-LEVEL_FROM IS NOT INITIAL
      OR LS_ITEM-LEVEL_TO   IS NOT INITIAL.
        LS_ITEM-MOVEMENT = |{ LS_ITEM-LEVEL_FROM } -> { LS_ITEM-LEVEL_TO }|.
        CONDENSE LS_ITEM-MOVEMENT.
      ENDIF.

      DATA(LV_FROM_DESC) = LEVEL_DESC( IT_LEVEL = LT_LEVEL
                                       IV_LEVEL = LS_ITEM-LEVEL_FROM ).

      DATA(LV_TO_DESC) = LEVEL_DESC( IT_LEVEL = LT_LEVEL
                                     IV_LEVEL = LS_ITEM-LEVEL_TO ).

      CASE LS_ITEM-ACTION.

        WHEN 'STRT'.
          LS_ITEM-MOVE_TEXT  = LV_TO_DESC.
          LS_ITEM-PENDING_AT = LV_TO_DESC.

        WHEN 'REJC' OR 'CANC' OR 'KILL'.
          LS_ITEM-MOVE_TEXT = COND #( WHEN LV_FROM_DESC IS NOT INITIAL
                                      THEN LV_FROM_DESC
                                      ELSE LS_ITEM-AGENT_DESC ).
          CLEAR LS_ITEM-PENDING_AT.

        WHEN 'RELS' OR 'MAIL' OR 'MERR'.
          CLEAR: LS_ITEM-MOVE_TEXT, LS_ITEM-PENDING_AT.

        WHEN OTHERS.
          IF LV_FROM_DESC IS NOT INITIAL OR LV_TO_DESC IS NOT INITIAL.
            LS_ITEM-MOVE_TEXT = |{ LV_FROM_DESC } -> { LV_TO_DESC }|.
            CONDENSE LS_ITEM-MOVE_TEXT.
          ENDIF.
          LS_ITEM-PENDING_AT = LV_TO_DESC.

      ENDCASE.

      IF LS_ITEM-ACTION = 'FINL'.
        CLEAR LS_ITEM-PENDING_AT.
      ENDIF.

      LS_ITEM-PENDING_USER = LEVEL_USER( IT_LEVEL = LT_LEVEL
                                         IV_LEVEL = LS_ITEM-LEVEL_TO ).

      APPEND LS_ITEM TO RT_ITEM.

    ENDLOOP.

    DATA(LV_LAST) = LINES( RT_ITEM ).

    LOOP AT RT_ITEM ASSIGNING FIELD-SYMBOL(<LS_OUT>).
      IF SY-TABIX <> LV_LAST.
        CLEAR: <LS_OUT>-PENDING_AT, <LS_OUT>-PENDING_USER.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_DATA->STATUS_ICON
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_STATUS                      TYPE        ZWF_STATUS1
* | [<-()] RV_ICON                        TYPE        ICON_D
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD STATUS_ICON.

    RV_ICON = SWITCH #( IV_STATUS
                WHEN 'I' THEN ICON_LED_YELLOW
                WHEN 'A' THEN ICON_LED_GREEN
                WHEN 'R' THEN ICON_LED_RED
                WHEN 'C' THEN ICON_LED_INACTIVE
                WHEN 'K' THEN ICON_DELETE
                ELSE          ICON_SPACE ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_DATA->STATUS_TEXT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_STATUS                      TYPE        ZWF_STATUS1
* | [<-()] RV_TEXT                        TYPE        VAL_TEXT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD STATUS_TEXT.

    READ TABLE MT_STATUS_TXT INTO DATA(LS_DD)
         WITH KEY DOMVALUE_L = IV_STATUS.

    RV_TEXT = COND #( WHEN SY-SUBRC = 0 THEN LS_DD-DDTEXT
                                        ELSE IV_STATUS ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_LOG_RPT_DATA->AREA
* +-------------------------------------------------------------------------------------------------+
* | [<-()] RV_AREA                        TYPE        CHAR2
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD AREA.

    RV_AREA = MV_AREA.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_LOG_RPT_DATA->AREA_TEXT
* +-------------------------------------------------------------------------------------------------+
* | [<-()] RV_TEXT                        TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD AREA_TEXT.

    RV_TEXT = SWITCH #( MV_AREA
                WHEN ZIF_WF_LOG_RPT=>GC_AREA-CREDIT_LIMIT
                  THEN 'Credit Limit Request'
                WHEN ZIF_WF_LOG_RPT=>GC_AREA-EXCEED
                  THEN 'Sales Order Credit Exceed'
                WHEN ZIF_WF_LOG_RPT=>GC_AREA-OVERDUE
                  THEN 'Sales Order Overdue'
                WHEN ZIF_WF_LOG_RPT=>GC_AREA-COMBINED
                  THEN 'Credit Exceed and Overdue'
                ELSE 'Workflow Log' ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_DATA->BUILD_LEVEL_MAP
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_LOG_ID                      TYPE        ZWF_LOG_ID
* | [--->] IV_TABNAME                     TYPE        TABNAME
* | [<-()] RT_LEVEL                       TYPE        TY_T_LEVEL
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD BUILD_LEVEL_MAP.

    CHECK IV_TABNAME IS NOT INITIAL AND IV_LOG_ID IS NOT INITIAL.

    DATA LR_DATA  TYPE REF TO DATA.
    DATA LS_LEVEL TYPE TY_S_LEVEL.

    FIELD-SYMBOLS <LT_RAW> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <LS_RAW> TYPE ANY.
    FIELD-SYMBOLS <LV_ANY> TYPE ANY.

    CREATE DATA LR_DATA TYPE STANDARD TABLE OF (IV_TABNAME).
    ASSIGN LR_DATA->* TO <LT_RAW>.

    SELECT * FROM (IV_TABNAME)
      WHERE LOG_ID = @IV_LOG_ID
        AND ACTION = 'STRT'
      ORDER BY SEQNR
      INTO TABLE @<LT_RAW>.

    LOOP AT <LT_RAW> ASSIGNING <LS_RAW>.

      CLEAR LS_LEVEL.

      ASSIGN COMPONENT 'LEVEL_TO' OF STRUCTURE <LS_RAW> TO <LV_ANY>.
      IF SY-SUBRC = 0. LS_LEVEL-LEVEL = <LV_ANY>. ENDIF.

      ASSIGN COMPONENT 'AGENT' OF STRUCTURE <LS_RAW> TO <LV_ANY>.
      IF SY-SUBRC = 0. LS_LEVEL-AGENT = <LV_ANY>. ENDIF.

      ASSIGN COMPONENT 'AGENT_DESC' OF STRUCTURE <LS_RAW> TO <LV_ANY>.
      IF SY-SUBRC = 0. LS_LEVEL-AGENT_DESC = <LV_ANY>. ENDIF.

      CHECK LS_LEVEL-LEVEL IS NOT INITIAL.

      INSERT LS_LEVEL INTO TABLE RT_LEVEL.

    ENDLOOP.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_DATA->COLOUR_ACTION
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_ACTION                      TYPE        ZWF_ACTION
* | [<-()] RT_COLOR                       TYPE        LVC_T_SCOL
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD COLOUR_ACTION.

    DATA LV_COL TYPE LVC_COL.

    LV_COL = SWITCH #( IV_ACTION
               WHEN 'STRT' THEN ZIF_WF_LOG_RPT=>GC_COL-BLUE
               WHEN 'APPR' THEN ZIF_WF_LOG_RPT=>GC_COL-GREEN
               WHEN 'FINL' THEN ZIF_WF_LOG_RPT=>GC_COL-GREEN
               WHEN 'RELS' THEN ZIF_WF_LOG_RPT=>GC_COL-GREEN
               WHEN 'REJC' THEN ZIF_WF_LOG_RPT=>GC_COL-RED
               WHEN 'RETN' THEN ZIF_WF_LOG_RPT=>GC_COL-ORANGE
               WHEN 'CANC' THEN ZIF_WF_LOG_RPT=>GC_COL-GREY
               WHEN 'MAIL' THEN ZIF_WF_LOG_RPT=>GC_COL-BLUE
               WHEN 'MERR' THEN ZIF_WF_LOG_RPT=>GC_COL-RED
               WHEN 'KILL' THEN ZIF_WF_LOG_RPT=>GC_COL-GREY
               ELSE             0 ).

    CHECK LV_COL <> 0.

    APPEND VALUE #( FNAME = SPACE
                    COLOR = VALUE #( COL = LV_COL INT = 0 INV = 0 ) )
           TO RT_COLOR.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_DATA->COLOUR_STATUS
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_STATUS                      TYPE        ZWF_STATUS1
* | [<-()] RT_COLOR                       TYPE        LVC_T_SCOL
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD COLOUR_STATUS.

    DATA LV_COL TYPE LVC_COL.

    LV_COL = SWITCH #( IV_STATUS
               WHEN 'I' THEN ZIF_WF_LOG_RPT=>GC_COL-YELLOW
               WHEN 'A' THEN ZIF_WF_LOG_RPT=>GC_COL-GREEN
               WHEN 'R' THEN ZIF_WF_LOG_RPT=>GC_COL-RED
               WHEN 'C' THEN ZIF_WF_LOG_RPT=>GC_COL-GREY
               WHEN 'K' THEN ZIF_WF_LOG_RPT=>GC_COL-GREY
               ELSE          0 ).

    CHECK LV_COL <> 0.

    APPEND VALUE #( FNAME = SPACE
                    COLOR = VALUE #( COL = LV_COL INT = 0 INV = 0 ) )
           TO RT_COLOR.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_DATA->LEVEL_DESC
* +-------------------------------------------------------------------------------------------------+
* | [--->] IT_LEVEL                       TYPE        TY_T_LEVEL
* | [--->] IV_LEVEL                       TYPE        INT2
* | [<-()] RV_DESC                        TYPE        ZUSER_DESC
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD LEVEL_DESC.

    READ TABLE IT_LEVEL INTO DATA(LS_LEVEL)
         WITH TABLE KEY LEVEL = IV_LEVEL.

    IF SY-SUBRC = 0.
      RV_DESC = LS_LEVEL-AGENT_DESC.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_DATA->LEVEL_USER
* +-------------------------------------------------------------------------------------------------+
* | [--->] IT_LEVEL                       TYPE        TY_T_LEVEL
* | [--->] IV_LEVEL                       TYPE        INT2
* | [<-()] RV_USER                        TYPE        XUBNAME
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD LEVEL_USER.

    READ TABLE IT_LEVEL INTO DATA(LS_LEVEL)
         WITH TABLE KEY LEVEL = IV_LEVEL.

    IF SY-SUBRC = 0.
      RV_USER = LS_LEVEL-AGENT.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_DATA->LOAD_DOMAIN_TEXTS
* +-------------------------------------------------------------------------------------------------+
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD LOAD_DOMAIN_TEXTS.

    CALL FUNCTION 'DD_DOMVALUES_GET'
      EXPORTING
        DOMNAME   = ZIF_WF_LOG_RPT=>GC_DOMAIN-STATUS
        TEXT      = ABAP_TRUE
        LANGU     = SY-LANGU
      TABLES
        DD07V_TAB = MT_STATUS_TXT
      EXCEPTIONS
        OTHERS    = 1.

    CALL FUNCTION 'DD_DOMVALUES_GET'
      EXPORTING
        DOMNAME   = ZIF_WF_LOG_RPT=>GC_DOMAIN-ACTION
        TEXT      = ABAP_TRUE
        LANGU     = SY-LANGU
      TABLES
        DD07V_TAB = MT_ACTION_TXT
      EXCEPTIONS
        OTHERS    = 1.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_DATA->SELECT_COMBINED
* +-------------------------------------------------------------------------------------------------+
* | [--->] IT_VBELN                       TYPE        ZIF_WF_LOG_RPT=>TR_VBELN(optional)
* | [--->] IT_BP                          TYPE        ZIF_WF_LOG_RPT=>TR_BP(optional)
* | [--->] IT_BUKRS                       TYPE        ZIF_WF_LOG_RPT=>TR_BUKRS(optional)
* | [--->] IT_WERKS                       TYPE        ZIF_WF_LOG_RPT=>TR_WERKS(optional)
* | [--->] IT_STAT                        TYPE        ZIF_WF_LOG_RPT=>TR_STAT(optional)
* | [--->] IT_AGENT                       TYPE        ZIF_WF_LOG_RPT=>TR_AGENT(optional)
* | [--->] IT_DATE                        TYPE        ZIF_WF_LOG_RPT=>TR_DATE(optional)
* | [<-()] RT_LIST                        TYPE        ZIF_WF_LOG_RPT=>TT_LIST
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD SELECT_COMBINED.

    TYPES: BEGIN OF TY_S_EX,
             LOG_ID        TYPE ZWF_LOG_ID,
             STATUS        TYPE ZWF_STATUS1,
             VBELN         TYPE VBELN_VA,
             BP_ID         TYPE BU_PARTNER,
             BP_NAME       TYPE CHAR100,
             BUKRS         TYPE BUKRS,
             WERKS         TYPE WERKS_D,
             CURRENCY      TYPE UKM_SGM_CURRENCY,
             CUR_LIMIT     TYPE UKM_CREDIT_LIMIT,
             EXCEED_CURR   TYPE UKM_COMM_ACTUAL,
             EXCEED_PER    TYPE UKM_COMM_ACTUAL,
             LEVELS        TYPE INT2,
             CURRENT_LEVEL TYPE INT2,
             STARTED_BY    TYPE XUBNAME,
             STARTED_ON    TYPE DATS,
             FINISHED_ON   TYPE DATS,
             WI_ID         TYPE SWW_WIID,
           END OF TY_S_EX.

    TYPES: BEGIN OF TY_S_OD,
             LOG_ID       TYPE ZWF_LOG_ID,
             STATUS       TYPE ZWF_STATUS1,
             VBELN        TYPE VBELN_VA,
             OVER_AMOUNT  TYPE DMBTR,
             OVER_DAYS    TYPE INT2,
             OVER_PERCENT TYPE NETWR,
           END OF TY_S_OD.

    DATA LT_EX   TYPE STANDARD TABLE OF TY_S_EX WITH EMPTY KEY.
    DATA LT_OD   TYPE STANDARD TABLE OF TY_S_OD WITH EMPTY KEY.
    DATA LS_EX   TYPE TY_S_EX.
    DATA LS_OD   TYPE TY_S_OD.
    DATA LS_LIST TYPE ZIF_WF_LOG_RPT=>TY_S_LIST.

    SELECT LOG_ID,
           STATUS,
           VBELN,
           BP_ID,
           BP_NAME,
           BUKRS,
           WERKS,
           CURRENCY,
           CUR_LIMIT,
           EXCEED_CURR,
           EXCEED_PER,
           LEVELS,
           CURRENT_LEVEL,
           STARTED_BY,
           STARTED_ON,
           FINISHED_ON,
           WI_ID
      FROM ZWF_LOG_EX_H
      WHERE VBELN      IN @IT_VBELN
        AND BP_ID      IN @IT_BP
        AND BUKRS      IN @IT_BUKRS
        AND WERKS      IN @IT_WERKS
        AND STATUS     IN @IT_STAT
        AND STARTED_BY IN @IT_AGENT
        AND STARTED_ON IN @IT_DATE
      ORDER BY VBELN, LOG_ID DESCENDING
      INTO TABLE @LT_EX.

    CHECK LT_EX IS NOT INITIAL.

    SELECT LOG_ID,
           STATUS,
           VBELN,
           OVER_AMOUNT,
           OVER_DAYS,
           OVER_PERCENT
      FROM ZWF_LOG_OD_H
      FOR ALL ENTRIES IN @LT_EX
      WHERE VBELN = @LT_EX-VBELN
      INTO TABLE @LT_OD.

    CHECK LT_OD IS NOT INITIAL.

    DELETE ADJACENT DUPLICATES FROM LT_EX COMPARING VBELN.

    SORT LT_OD BY VBELN ASCENDING LOG_ID DESCENDING.
    DELETE ADJACENT DUPLICATES FROM LT_OD COMPARING VBELN.

    SELECT BUKRS, BUTXT FROM T001 INTO TABLE @DATA(LT_T001).
    SORT LT_T001 BY BUKRS.

    SELECT WERKS, NAME1 FROM T001W INTO TABLE @DATA(LT_T001W).
    SORT LT_T001W BY WERKS.

    LOOP AT LT_EX INTO LS_EX.

      CLEAR LS_OD.
      READ TABLE LT_OD INTO LS_OD
           WITH KEY VBELN = LS_EX-VBELN BINARY SEARCH.

      CHECK SY-SUBRC = 0.

      CLEAR LS_LIST.
      MOVE-CORRESPONDING LS_EX TO LS_LIST.

      LS_LIST-LOG_ID = LS_EX-LOG_ID.
      LS_LIST-STATUS = LS_EX-STATUS.

      LS_LIST-LOG_EX      = LS_EX-LOG_ID.
      LS_LIST-STATUS_EX   = LS_EX-STATUS.
      LS_LIST-ST_ICON_EX  = STATUS_ICON( LS_EX-STATUS ).
      LS_LIST-ST_TEXT_EX  = STATUS_TEXT( LS_EX-STATUS ).
      LS_LIST-C_DETAIL_EX = ICON_DETAIL.

      LS_LIST-LOG_OD       = LS_OD-LOG_ID.
      LS_LIST-STATUS_OD    = LS_OD-STATUS.
      LS_LIST-ST_ICON_OD   = STATUS_ICON( LS_OD-STATUS ).
      LS_LIST-ST_TEXT_OD   = STATUS_TEXT( LS_OD-STATUS ).
      LS_LIST-C_DETAIL_OD  = ICON_DETAIL.

      LS_LIST-OVER_AMOUNT  = LS_OD-OVER_AMOUNT.
      LS_LIST-OVER_DAYS    = LS_OD-OVER_DAYS.
      LS_LIST-OVER_PERCENT = LS_OD-OVER_PERCENT.

      CLEAR LS_LIST-ROW_COLOR.

      LS_LIST-PROGRESS = |{ LS_EX-CURRENT_LEVEL } / { LS_EX-LEVELS }|.
      CONDENSE LS_LIST-PROGRESS.

      READ TABLE LT_T001 INTO DATA(LS_T001)
           WITH KEY BUKRS = LS_EX-BUKRS BINARY SEARCH.
      IF SY-SUBRC = 0.
        LS_LIST-BUTXT = LS_T001-BUTXT.
      ENDIF.

      READ TABLE LT_T001W INTO DATA(LS_T001W)
           WITH KEY WERKS = LS_EX-WERKS BINARY SEARCH.
      IF SY-SUBRC = 0.
        LS_LIST-NAME1 = LS_T001W-NAME1.
      ENDIF.

      LS_LIST-STARTED_NAME = USER_NAME( LS_EX-STARTED_BY ).

      IF LS_EX-FINISHED_ON IS NOT INITIAL.
        LS_LIST-DURATION_DAYS = LS_EX-FINISHED_ON - LS_EX-STARTED_ON.
      ELSE.
        LS_LIST-DURATION_DAYS = SY-DATUM - LS_EX-STARTED_ON.
      ENDIF.

      APPEND LS_LIST TO RT_LIST.

    ENDLOOP.

    SORT RT_LIST BY LOG_EX DESCENDING.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_LOG_RPT_DATA->SELECT_LIST
* +-------------------------------------------------------------------------------------------------+
* | [--->] IT_LOG                         TYPE        ZIF_WF_LOG_RPT=>TR_LOG(optional)
* | [--->] IT_VBELN                       TYPE        ZIF_WF_LOG_RPT=>TR_VBELN(optional)
* | [--->] IT_BP                          TYPE        ZIF_WF_LOG_RPT=>TR_BP(optional)
* | [--->] IT_BUKRS                       TYPE        ZIF_WF_LOG_RPT=>TR_BUKRS(optional)
* | [--->] IT_WERKS                       TYPE        ZIF_WF_LOG_RPT=>TR_WERKS(optional)
* | [--->] IT_STAT                        TYPE        ZIF_WF_LOG_RPT=>TR_STAT(optional)
* | [--->] IT_AGENT                       TYPE        ZIF_WF_LOG_RPT=>TR_AGENT(optional)
* | [--->] IT_DATE                        TYPE        ZIF_WF_LOG_RPT=>TR_DATE(optional)
* | [<-()] RT_LIST                        TYPE        ZIF_WF_LOG_RPT=>TT_LIST
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD SELECT_LIST.

    IF MV_AREA = ZIF_WF_LOG_RPT=>GC_AREA-COMBINED.
      RT_LIST = SELECT_COMBINED( IT_VBELN = IT_VBELN
                                 IT_BP    = IT_BP
                                 IT_BUKRS = IT_BUKRS
                                 IT_WERKS = IT_WERKS
                                 IT_STAT  = IT_STAT
                                 IT_AGENT = IT_AGENT
                                 IT_DATE  = IT_DATE ).
      RETURN.
    ENDIF.

    CHECK MV_HDR IS NOT INITIAL.

    DATA LR_DATA TYPE REF TO DATA.
    DATA LT_CNT  TYPE TY_T_CNT.
    DATA LS_CNT  TYPE TY_S_CNT.
    DATA LS_LIST TYPE ZIF_WF_LOG_RPT=>TY_S_LIST.

    FIELD-SYMBOLS <LT_RAW> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <LS_RAW> TYPE ANY.

    CREATE DATA LR_DATA TYPE STANDARD TABLE OF (MV_HDR).
    ASSIGN LR_DATA->* TO <LT_RAW>.

    IF MV_AREA = ZIF_WF_LOG_RPT=>GC_AREA-CREDIT_LIMIT.

      SELECT * FROM (MV_HDR)
        WHERE LOG_ID     IN @IT_LOG
          AND BP_ID      IN @IT_BP
          AND BUKRS      IN @IT_BUKRS
          AND STATUS     IN @IT_STAT
          AND STARTED_BY IN @IT_AGENT
          AND STARTED_ON IN @IT_DATE
        ORDER BY LOG_ID DESCENDING
        INTO TABLE @<LT_RAW>.

    ELSE.

      SELECT * FROM (MV_HDR)
        WHERE LOG_ID     IN @IT_LOG
          AND VBELN      IN @IT_VBELN
          AND BP_ID      IN @IT_BP
          AND BUKRS      IN @IT_BUKRS
          AND WERKS      IN @IT_WERKS
          AND STATUS     IN @IT_STAT
          AND STARTED_BY IN @IT_AGENT
          AND STARTED_ON IN @IT_DATE
        ORDER BY LOG_ID DESCENDING
        INTO TABLE @<LT_RAW>.

    ENDIF.

    CHECK <LT_RAW> IS NOT INITIAL.

    SELECT LOG_ID, COUNT(*) AS CNT
      FROM (MV_ITM)
      GROUP BY LOG_ID
      INTO TABLE @LT_CNT.

    SORT LT_CNT BY LOG_ID.

    SELECT BUKRS, BUTXT FROM T001 INTO TABLE @DATA(LT_T001).
    SORT LT_T001 BY BUKRS.

    SELECT WERKS, NAME1 FROM T001W INTO TABLE @DATA(LT_T001W).
    SORT LT_T001W BY WERKS.

    SELECT TYPE, DESCRIPTION FROM ZWF_TYPES INTO TABLE @DATA(LT_TYPE).
    SORT LT_TYPE BY TYPE.

    LOOP AT <LT_RAW> ASSIGNING <LS_RAW>.

      CLEAR LS_LIST.
      MOVE-CORRESPONDING <LS_RAW> TO LS_LIST.

      LS_LIST-STATUS_ICON = STATUS_ICON( LS_LIST-STATUS ).
      LS_LIST-STATUS_TEXT = STATUS_TEXT( LS_LIST-STATUS ).
      LS_LIST-ROW_COLOR   = COLOUR_STATUS( LS_LIST-STATUS ).
      LS_LIST-C_DETAIL    = ICON_DETAIL.

      LS_LIST-PROGRESS = |{ LS_LIST-CURRENT_LEVEL } / { LS_LIST-LEVELS }|.
      CONDENSE LS_LIST-PROGRESS.

      READ TABLE LT_T001 INTO DATA(LS_T001)
           WITH KEY BUKRS = LS_LIST-BUKRS BINARY SEARCH.
      IF SY-SUBRC = 0.
        LS_LIST-BUTXT = LS_T001-BUTXT.
      ENDIF.

      READ TABLE LT_T001W INTO DATA(LS_T001W)
           WITH KEY WERKS = LS_LIST-WERKS BINARY SEARCH.
      IF SY-SUBRC = 0.
        LS_LIST-NAME1 = LS_T001W-NAME1.
      ENDIF.

      READ TABLE LT_TYPE INTO DATA(LS_TYPE)
           WITH KEY TYPE = LS_LIST-WF_TYPE BINARY SEARCH.
      IF SY-SUBRC = 0.
        LS_LIST-WF_TYPE_TEXT = LS_TYPE-DESCRIPTION.
      ENDIF.

      LS_LIST-STARTED_NAME = USER_NAME( LS_LIST-STARTED_BY ).
      LS_LIST-ERNAM_NAME   = USER_NAME( CONV #( LS_LIST-ERNAM ) ).
      LS_LIST-CHANGED_NAME = USER_NAME( LS_LIST-CHANGED_BY ).

      IF LS_LIST-STATUS = 'I'.
        DATA(LT_LVL) = BUILD_LEVEL_MAP( IV_LOG_ID  = LS_LIST-LOG_ID
                                        IV_TABNAME = MV_ITM ).
        LS_LIST-PENDING_AT = LEVEL_DESC( IT_LEVEL = LT_LVL
                                         IV_LEVEL = LS_LIST-CURRENT_LEVEL ).
        LS_LIST-PENDING_USER = LEVEL_USER( IT_LEVEL = LT_LVL
                                           IV_LEVEL = LS_LIST-CURRENT_LEVEL ).
      ENDIF.

      CLEAR LS_CNT.
      READ TABLE LT_CNT INTO LS_CNT
           WITH KEY LOG_ID = LS_LIST-LOG_ID BINARY SEARCH.
      IF SY-SUBRC = 0.
        LS_LIST-ITEM_COUNT = LS_CNT-CNT.
      ENDIF.

      LS_LIST-DURATION_DAYS = COND #(
        WHEN LS_LIST-FINISHED_ON IS NOT INITIAL
        THEN LS_LIST-FINISHED_ON - LS_LIST-STARTED_ON
        ELSE SY-DATUM - LS_LIST-STARTED_ON ).

      APPEND LS_LIST TO RT_LIST.

    ENDLOOP.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_DATA->USER_NAME
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_BNAME                       TYPE        XUBNAME
* | [<-()] RV_NAME                        TYPE        AD_NAMTEXT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD USER_NAME.

    CHECK IV_BNAME IS NOT INITIAL.

    SELECT SINGLE NAME_TEXTC FROM USER_ADDR
      WHERE BNAME = @IV_BNAME
      INTO @RV_NAME.

  ENDMETHOD.
ENDCLASS.