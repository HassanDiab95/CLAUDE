*&---------------------------------------------------------------------*
*& Object Name    : ZCL_WF_LOG_RPT_UI
*& Object Type    : Class
*& Package        : ZSD
*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : Nourhan Leila
*&---------------------------------------------------------------------*
*& Purpose        : Builds the ALV display for the workflow log
*&                   reports.
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
CLASS ZCL_WF_LOG_RPT_UI DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    EVENTS DETAIL_REQUESTED
      EXPORTING VALUE(EV_LOG_ID) TYPE ZWF_LOG_ID.

    METHODS CONSTRUCTOR
      IMPORTING IO_DATA TYPE REF TO ZCL_WF_LOG_RPT_DATA.

    METHODS DISPLAY_LIST
      IMPORTING IT_LIST TYPE ZIF_WF_LOG_RPT=>TT_LIST.

    METHODS BUILD_DETAIL
      IMPORTING IV_LOG_ID TYPE ZWF_LOG_ID.

    METHODS FREE_DETAIL.

  PRIVATE SECTION.

    DATA MO_DATA TYPE REF TO ZCL_WF_LOG_RPT_DATA.
    DATA MT_LIST TYPE ZIF_WF_LOG_RPT=>TT_LIST.
    DATA MT_ONE  TYPE ZIF_WF_LOG_RPT=>TT_LIST.
    DATA MT_ITEM TYPE ZIF_WF_LOG_RPT=>TT_ITEM.

    DATA MO_CONT  TYPE REF TO CL_GUI_CUSTOM_CONTAINER.
    DATA MO_SPLIT TYPE REF TO CL_GUI_SPLITTER_CONTAINER.

    METHODS SET_COL
      IMPORTING IO_COLS  TYPE REF TO CL_SALV_COLUMNS_TABLE
                IV_NAME  TYPE LVC_FNAME
                IV_SHORT TYPE SCRTEXT_S
                IV_MED   TYPE SCRTEXT_M
                IV_LONG  TYPE SCRTEXT_L
                IV_LEN   TYPE LVC_OUTLEN OPTIONAL.

    METHODS HIDE_COL
      IMPORTING IO_COLS TYPE REF TO CL_SALV_COLUMNS_TABLE
                IV_NAME TYPE LVC_FNAME.

    METHODS ICON_COL
      IMPORTING IO_COLS TYPE REF TO CL_SALV_COLUMNS_TABLE
                IV_NAME TYPE LVC_FNAME
                IV_TIP  TYPE SCRTEXT_L OPTIONAL.

    METHODS HOTSPOT_COL
      IMPORTING IO_COLS TYPE REF TO CL_SALV_COLUMNS_TABLE
                IV_NAME TYPE LVC_FNAME.

    METHODS COLOUR_COLUMN
      IMPORTING IO_COLS TYPE REF TO CL_SALV_COLUMNS_TABLE.

    METHODS BUILD_LIST_COLUMNS
      IMPORTING IO_COLS TYPE REF TO CL_SALV_COLUMNS_TABLE.

    METHODS BUILD_ITEM_COLUMNS
      IMPORTING IO_COLS TYPE REF TO CL_SALV_COLUMNS_TABLE.

    METHODS ON_LINK_CLICK
      FOR EVENT LINK_CLICK OF CL_SALV_EVENTS_TABLE
      IMPORTING ROW COLUMN.

    METHODS POPUP_ITEMS
      IMPORTING IV_LOG_ID TYPE ZWF_LOG_ID.

    METHODS GRID_HEADER
      IMPORTING IO_PARENT TYPE REF TO CL_GUI_CONTAINER.

    METHODS GRID_ITEMS
      IMPORTING IO_PARENT TYPE REF TO CL_GUI_CONTAINER.

ENDCLASS.



CLASS ZCL_WF_LOG_RPT_UI IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_LOG_RPT_UI->BUILD_DETAIL
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_LOG_ID                      TYPE        ZWF_LOG_ID
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD BUILD_DETAIL.

    CHECK MO_CONT IS NOT BOUND.

    MT_ONE  = VALUE #( FOR LS IN MT_LIST
                       WHERE ( LOG_ID = IV_LOG_ID ) ( LS ) ).
    MT_ITEM = MO_DATA->SELECT_ITEMS( IV_LOG_ID ).

    MO_CONT = NEW CL_GUI_CUSTOM_CONTAINER( CONTAINER_NAME = 'CC_DETAIL' ).

    MO_SPLIT = NEW CL_GUI_SPLITTER_CONTAINER( PARENT  = MO_CONT
                                              ROWS    = 2
                                              COLUMNS = 1 ).
    MO_SPLIT->SET_ROW_HEIGHT( ID = 1 HEIGHT = 35 ).
    MO_SPLIT->SET_ROW_HEIGHT( ID = 2 HEIGHT = 65 ).

    GRID_HEADER( MO_SPLIT->GET_CONTAINER( ROW = 1 COLUMN = 1 ) ).
    GRID_ITEMS( MO_SPLIT->GET_CONTAINER( ROW = 2 COLUMN = 1 ) ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_UI->BUILD_ITEM_COLUMNS
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_COLS                        TYPE REF TO CL_SALV_COLUMNS_TABLE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD BUILD_ITEM_COLUMNS.

    IO_COLS->SET_OPTIMIZE( ABAP_TRUE ).
    COLOUR_COLUMN( IO_COLS ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'SEQNR'
             IV_SHORT = 'Seq'
             IV_MED   = 'Sequence'
             IV_LONG  = 'Log Sequence Number'
             IV_LEN   = 5 ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'ACTION_ICON'
             IV_SHORT = 'A'
             IV_MED   = 'Act.'
             IV_LONG  = 'Action Indicator'
             IV_LEN   = 3 ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'ACTION_TEXT'
             IV_SHORT = 'Action'
             IV_MED   = 'Action'
             IV_LONG  = 'Workflow Action'
             IV_LEN   = 16 ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'MOVEMENT'
             IV_SHORT = 'Level'
             IV_MED   = 'Level move'
             IV_LONG  = 'Level From -> To'
             IV_LEN   = 12 ).


    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'MOVE_TEXT'
             IV_SHORT = 'Route'
             IV_MED   = 'Approver route'
             IV_LONG  = 'From Approver -> To Approver'
             IV_LEN   = 45 ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'PENDING_AT'
             IV_SHORT = 'Pending'
             IV_MED   = 'Pending at'
             IV_LONG  = 'Currently Pending With'
             IV_LEN   = 30 ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'PENDING_USER'
             IV_SHORT = 'Pend.user'
             IV_MED   = 'Pending user'
             IV_LONG  = 'Pending Approver User'
             IV_LEN   = 12 ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'AGENT'
             IV_SHORT = 'Agent'
             IV_MED   = 'Planned agent'
             IV_LONG  = 'Planned Approver' ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'AGENT_DESC'
             IV_SHORT = 'Descr.'
             IV_MED   = 'Description'
             IV_LONG  = 'Approver Description' ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'ACTUAL_AGENT'
             IV_SHORT = 'By'
             IV_MED   = 'Executed by'
             IV_LONG  = 'User Who Executed' ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'ACTUAL_NAME'
             IV_SHORT = 'Name'
             IV_MED   = 'Executor name'
             IV_LONG  = 'Name of Executing User' ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'NOTE'
             IV_SHORT = 'Note'
             IV_MED   = 'Decision note'
             IV_LONG  = 'Decision Note'
             IV_LEN   = 60 ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'ACTION_ON'
             IV_SHORT = 'Date'
             IV_MED   = 'Action date'
             IV_LONG  = 'Date of Action' ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'ACTION_AT'
             IV_SHORT = 'Time'
             IV_MED   = 'Action time'
             IV_LONG  = 'Time of Action' ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'WI_ID'
             IV_SHORT = 'Work it.'
             IV_MED   = 'Work item'
             IV_LONG  = 'Work Item ID' ).

    HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'ACTION' ).
    HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'LEVEL_FROM' ).
    HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'LEVEL_TO' ).

    ICON_COL( IO_COLS = IO_COLS IV_NAME = 'ACTION_ICON' ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_UI->BUILD_LIST_COLUMNS
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_COLS                        TYPE REF TO CL_SALV_COLUMNS_TABLE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD BUILD_LIST_COLUMNS.

    IO_COLS->SET_OPTIMIZE( ABAP_TRUE ).
    COLOUR_COLUMN( IO_COLS ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'LOG_ID'
             IV_SHORT = 'Log ID'
             IV_MED   = 'Log ID'
             IV_LONG  = 'Workflow Log ID' ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'STATUS_ICON'
             IV_SHORT = 'St'
             IV_MED   = 'Status'
             IV_LONG  = 'Status Indicator'
             IV_LEN   = 3 ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'STATUS_TEXT'
             IV_SHORT = 'Status'
             IV_MED   = 'Status'
             IV_LONG  = 'Workflow Status'
             IV_LEN   = 14 ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'WF_TYPE_TEXT'
             IV_SHORT = 'WF type'
             IV_MED   = 'Workflow type'
             IV_LONG  = 'Workflow Type Description' ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'BP_ID'
             IV_SHORT = 'BP'
             IV_MED   = 'Partner'
             IV_LONG  = 'Business Partner' ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'BP_NAME'
             IV_SHORT = 'Name'
             IV_MED   = 'Partner name'
             IV_LONG  = 'Business Partner Name' ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'BUKRS'
             IV_SHORT = 'CoCd'
             IV_MED   = 'Comp.code'
             IV_LONG  = 'Company Code'
             IV_LEN   = 5 ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'BUTXT'
             IV_SHORT = 'Company'
             IV_MED   = 'Company name'
             IV_LONG  = 'Company Code Name' ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'CURRENCY'
             IV_SHORT = 'Curr.'
             IV_MED   = 'Currency'
             IV_LONG  = 'Segment Currency'
             IV_LEN   = 5 ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'PROGRESS'
             IV_SHORT = 'Level'
             IV_MED   = 'Level'
             IV_LONG  = 'Current / Total Levels'
             IV_LEN   = 9 ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'ITEM_COUNT'
             IV_SHORT = 'Actions'
             IV_MED   = 'Actions'
             IV_LONG  = 'Number of Logged Actions'
             IV_LEN   = 8 ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'DURATION_DAYS'
             IV_SHORT = 'Days'
             IV_MED   = 'Days open'
             IV_LONG  = 'Days Since Start'
             IV_LEN   = 6 ).
    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'PENDING_AT'
             IV_SHORT = 'Pending'
             IV_MED   = 'Pending at'
             IV_LONG  = 'Currently Pending With'
             IV_LEN   = 30 ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'PENDING_USER'
             IV_SHORT = 'Pend.user'
             IV_MED   = 'Pending user'
             IV_LONG  = 'Pending Approver User'
             IV_LEN   = 12 ).
    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'STARTED_BY'
             IV_SHORT = 'User'
             IV_MED   = 'Started by'
             IV_LONG  = 'Started By User' ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'STARTED_NAME'
             IV_SHORT = 'Name'
             IV_MED   = 'Starter name'
             IV_LONG  = 'Name of Starting User' ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'STARTED_ON'
             IV_SHORT = 'From'
             IV_MED   = 'Start date'
             IV_LONG  = 'Workflow Start Date' ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'FINISHED_ON'
             IV_SHORT = 'To'
             IV_MED   = 'End date'
             IV_LONG  = 'Workflow End Date' ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'WI_ID'
             IV_SHORT = 'Work it.'
             IV_MED   = 'Work item'
             IV_LONG  = 'Work Item ID' ).

    SET_COL( IO_COLS  = IO_COLS
             IV_NAME  = 'C_DETAIL'
             IV_SHORT = 'Detail'
             IV_MED   = 'Details'
             IV_LONG  = 'Header and Items'
             IV_LEN   = 6 ).

    "--- area specific ------------------------------------------------
    CASE MO_DATA->AREA( ).

      WHEN ZIF_WF_LOG_RPT=>GC_AREA-CREDIT_LIMIT.

        SET_COL( IO_COLS  = IO_COLS
                 IV_NAME  = 'REQ_LIMIT'
                 IV_SHORT = 'Requested'
                 IV_MED   = 'Requested limit'
                 IV_LONG  = 'Requested Credit Limit' ).

        SET_COL( IO_COLS  = IO_COLS
                 IV_NAME  = 'CUR_LIMIT'
                 IV_SHORT = 'Current'
                 IV_MED   = 'Current limit'
                 IV_LONG  = 'Current Credit Limit' ).


        SET_COL( IO_COLS  = IO_COLS
                 IV_NAME  = 'CHANGED_BY'
                 IV_SHORT = 'Changed'
                 IV_MED   = 'Changed by'
                 IV_LONG  = 'Business Partner Changed By' ).

        SET_COL( IO_COLS  = IO_COLS
                 IV_NAME  = 'CHANGED_NAME'
                 IV_SHORT = 'Name'
                 IV_MED   = 'Changer name'
                 IV_LONG  = 'Name of BP Changer' ).
        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'ERNAM' ).
        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'ERNAM_NAME' ).
        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'NAME1' ).
        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'VBELN' ).
        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'WERKS' ).
        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'EXCEED_CURR' ).
        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'EXCEED_PER' ).
        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'OVER_AMOUNT' ).
        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'OVER_DAYS' ).
        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'OVER_PERCENT' ).
        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'NETWR' ).
        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'WAERK' ).
      WHEN ZIF_WF_LOG_RPT=>GC_AREA-EXCEED.

        SET_COL( IO_COLS  = IO_COLS
                 IV_NAME  = 'VBELN'
                 IV_SHORT = 'SO'
                 IV_MED   = 'Sales order'
                 IV_LONG  = 'Sales Order Number' ).

        SET_COL( IO_COLS  = IO_COLS
                 IV_NAME  = 'NETWR'
                 IV_SHORT = 'Net value'
                 IV_MED   = 'Net value'
                 IV_LONG  = 'Sales Order Net Value' ).

        SET_COL( IO_COLS  = IO_COLS
                 IV_NAME  = 'WAERK'
                 IV_SHORT = 'SO curr.'
                 IV_MED   = 'SO currency'
                 IV_LONG  = 'Sales Order Currency'
                 IV_LEN   = 5 ).

        SET_COL( IO_COLS  = IO_COLS
                 IV_NAME  = 'WERKS'
                 IV_SHORT = 'Plant'
                 IV_MED   = 'Plant'
                 IV_LONG  = 'Plant'
                 IV_LEN   = 5 ).

        SET_COL( IO_COLS  = IO_COLS
                 IV_NAME  = 'CUR_LIMIT'
                 IV_SHORT = 'Limit'
                 IV_MED   = 'Credit limit'
                 IV_LONG  = 'Current Credit Limit' ).

        SET_COL( IO_COLS  = IO_COLS
                 IV_NAME  = 'EXCEED_CURR'
                 IV_SHORT = 'Exceeded'
                 IV_MED   = 'Exceeded by'
                 IV_LONG  = 'Exceeded Amount' ).

        SET_COL( IO_COLS  = IO_COLS
                 IV_NAME  = 'EXCEED_PER'
                 IV_SHORT = 'Exc. %'
                 IV_MED   = 'Exceeded %'
                 IV_LONG  = 'Exceeded Percentage'
                 IV_LEN   = 9 ).

        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'REQ_LIMIT' ).
        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'OVER_AMOUNT' ).
        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'OVER_DAYS' ).
        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'OVER_PERCENT' ).

        SET_COL( IO_COLS  = IO_COLS
                 IV_NAME  = 'ERNAM'
                 IV_SHORT = 'Created'
                 IV_MED   = 'Created by'
                 IV_LONG  = 'Sales Order Created By' ).

        SET_COL( IO_COLS  = IO_COLS
                 IV_NAME  = 'ERNAM_NAME'
                 IV_SHORT = 'Name'
                 IV_MED   = 'Creator name'
                 IV_LONG  = 'Name of Sales Order Creator' ).

        SET_COL( IO_COLS  = IO_COLS
                 IV_NAME  = 'NAME1'
                 IV_SHORT = 'Plant nm'
                 IV_MED   = 'Plant name'
                 IV_LONG  = 'Plant Name' ).

        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'CHANGED_BY' ).
        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'CHANGED_NAME' ).

      WHEN ZIF_WF_LOG_RPT=>GC_AREA-OVERDUE.

        SET_COL( IO_COLS  = IO_COLS
                 IV_NAME  = 'VBELN'
                 IV_SHORT = 'SO'
                 IV_MED   = 'Sales order'
                 IV_LONG  = 'Sales Order Number' ).

        SET_COL( IO_COLS  = IO_COLS
                 IV_NAME  = 'WERKS'
                 IV_SHORT = 'Plant'
                 IV_MED   = 'Plant'
                 IV_LONG  = 'Plant'
                 IV_LEN   = 5 ).

        SET_COL( IO_COLS  = IO_COLS
                 IV_NAME  = 'OVER_AMOUNT'
                 IV_SHORT = 'Overdue'
                 IV_MED   = 'Overdue amount'
                 IV_LONG  = 'Overdue Amount' ).

        SET_COL( IO_COLS  = IO_COLS
                 IV_NAME  = 'OVER_DAYS'
                 IV_SHORT = 'Days'
                 IV_MED   = 'Overdue days'
                 IV_LONG  = 'Days Overdue'
                 IV_LEN   = 6 ).

        SET_COL( IO_COLS  = IO_COLS
                 IV_NAME  = 'OVER_PERCENT'
                 IV_SHORT = 'Ovd. %'
                 IV_MED   = 'Overdue %'
                 IV_LONG  = 'Overdue Percentage'
                 IV_LEN   = 10 ).

        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'REQ_LIMIT' ).
        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'CUR_LIMIT' ).
        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'EXCEED_CURR' ).
        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'EXCEED_PER' ).

        SET_COL( IO_COLS  = IO_COLS
                 IV_NAME  = 'ERNAM'
                 IV_SHORT = 'Created'
                 IV_MED   = 'Created by'
                 IV_LONG  = 'Sales Order Created By' ).

        SET_COL( IO_COLS  = IO_COLS
                 IV_NAME  = 'ERNAM_NAME'
                 IV_SHORT = 'Name'
                 IV_MED   = 'Creator name'
                 IV_LONG  = 'Name of Sales Order Creator' ).

        SET_COL( IO_COLS  = IO_COLS
                 IV_NAME  = 'NAME1'
                 IV_SHORT = 'Plant nm'
                 IV_MED   = 'Plant name'
                 IV_LONG  = 'Plant Name' ).

        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'CHANGED_BY' ).
        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'CHANGED_NAME' ).
        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'NETWR' ).
        HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'WAERK' ).


    ENDCASE.

    "--- technical ----------------------------------------------------
    HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'STATUS' ).
    HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'WF_TYPE' ).
    HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'LEVELS' ).
    HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'CURRENT_LEVEL' ).
    HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'STARTED_AT' ).
    HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'FINISHED_AT' ).

    ICON_COL( IO_COLS = IO_COLS IV_NAME = 'STATUS_ICON' ).
    ICON_COL( IO_COLS = IO_COLS
              IV_NAME = 'C_DETAIL'
              IV_TIP  = 'Show header and items' ).

    "--- currency reference -------------------------------------------
    DATA(LT_CUR) = VALUE STRING_TABLE(
      ( `REQ_LIMIT` ) ( `CUR_LIMIT` ) ( `EXCEED_CURR` ) ( `OVER_AMOUNT` ) ).

    LOOP AT LT_CUR INTO DATA(LV_C).
      TRY.
          CAST CL_SALV_COLUMN_LIST(
            IO_COLS->GET_COLUMN( CONV #( LV_C ) )
          )->SET_CURRENCY_COLUMN( 'CURRENCY' ).
        CATCH CX_SALV_NOT_FOUND CX_SALV_DATA_ERROR.
      ENDTRY.
    ENDLOOP.

    "--- hotspots -----------------------------------------------------
    HOTSPOT_COL( IO_COLS = IO_COLS IV_NAME = 'LOG_ID' ).
    HOTSPOT_COL( IO_COLS = IO_COLS IV_NAME = 'VBELN' ).
    HOTSPOT_COL( IO_COLS = IO_COLS IV_NAME = 'ITEM_COUNT' ).
    HOTSPOT_COL( IO_COLS = IO_COLS IV_NAME = 'C_DETAIL' ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_UI->COLOUR_COLUMN
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_COLS                        TYPE REF TO CL_SALV_COLUMNS_TABLE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD COLOUR_COLUMN.

    " CL_SALV_TABLE needs this - a layout CTAB_FNAME does nothing here
    TRY.
        IO_COLS->SET_COLOR_COLUMN( 'ROW_COLOR' ).
      CATCH CX_SALV_DATA_ERROR.
    ENDTRY.

    HIDE_COL( IO_COLS = IO_COLS IV_NAME = 'ROW_COLOR' ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_LOG_RPT_UI->CONSTRUCTOR
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_DATA                        TYPE REF TO ZCL_WF_LOG_RPT_DATA
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD CONSTRUCTOR.

    MO_DATA = IO_DATA.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_LOG_RPT_UI->DISPLAY_LIST
* +-------------------------------------------------------------------------------------------------+
* | [--->] IT_LIST                        TYPE        ZIF_WF_LOG_RPT=>TT_LIST
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD DISPLAY_LIST.

    MT_LIST = IT_LIST.

    IF MT_LIST IS INITIAL.
      MESSAGE 'No workflow log matches the selection'
              TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    DATA LO_ALV TYPE REF TO CL_SALV_TABLE.

    TRY.
        CL_SALV_TABLE=>FACTORY(
          IMPORTING
            R_SALV_TABLE = LO_ALV
          CHANGING
            T_TABLE      = MT_LIST ).

        BUILD_LIST_COLUMNS( LO_ALV->GET_COLUMNS( ) ).

        SET HANDLER ON_LINK_CLICK FOR LO_ALV->GET_EVENT( ).

        DATA(LS_CNT) = MO_DATA->COUNT( MT_LIST ).

        LO_ALV->GET_DISPLAY_SETTINGS( )->SET_LIST_HEADER(
          |{ MO_DATA->AREA_TEXT( ) } | &&
          |Total { LS_CNT-TOTAL } | &&
          |In process { LS_CNT-IN_PROCESS } | &&
          |Approved { LS_CNT-APPROVED } | &&
          |Rejected { LS_CNT-REJECTED } | &&
          |Cancelled { LS_CNT-CANCELLED }| ).

        LO_ALV->GET_DISPLAY_SETTINGS( )->SET_STRIPED_PATTERN( ABAP_TRUE ).
        LO_ALV->GET_FUNCTIONS( )->SET_ALL( ABAP_TRUE ).
        LO_ALV->DISPLAY( ).

      CATCH CX_SALV_MSG CX_SALV_NOT_FOUND CX_SALV_DATA_ERROR INTO DATA(LX).
        MESSAGE LX->GET_TEXT( ) TYPE 'E'.
    ENDTRY.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_LOG_RPT_UI->FREE_DETAIL
* +-------------------------------------------------------------------------------------------------+
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD FREE_DETAIL.

    IF MO_CONT IS BOUND.
      MO_CONT->FREE( ).
      CLEAR: MO_CONT, MO_SPLIT.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_UI->GRID_HEADER
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_PARENT                      TYPE REF TO CL_GUI_CONTAINER
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD GRID_HEADER.

    DATA LO_ALV TYPE REF TO CL_SALV_TABLE.

    TRY.
        CL_SALV_TABLE=>FACTORY(
          EXPORTING
            R_CONTAINER  = IO_PARENT
          IMPORTING
            R_SALV_TABLE = LO_ALV
          CHANGING
            T_TABLE      = MT_ONE ).

        BUILD_LIST_COLUMNS( LO_ALV->GET_COLUMNS( ) ).

        LO_ALV->GET_DISPLAY_SETTINGS( )->SET_LIST_HEADER( 'Log header' ).
        LO_ALV->GET_FUNCTIONS( )->SET_ALL( ABAP_FALSE ).
        LO_ALV->DISPLAY( ).

      CATCH CX_SALV_MSG CX_SALV_NOT_FOUND CX_SALV_DATA_ERROR.
    ENDTRY.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_UI->GRID_ITEMS
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_PARENT                      TYPE REF TO CL_GUI_CONTAINER
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD GRID_ITEMS.

    DATA LO_ALV TYPE REF TO CL_SALV_TABLE.

    TRY.
        CL_SALV_TABLE=>FACTORY(
          EXPORTING
            R_CONTAINER  = IO_PARENT
          IMPORTING
            R_SALV_TABLE = LO_ALV
          CHANGING
            T_TABLE      = MT_ITEM ).

        BUILD_ITEM_COLUMNS( LO_ALV->GET_COLUMNS( ) ).

        LO_ALV->GET_DISPLAY_SETTINGS( )->SET_LIST_HEADER(
          |Approval history - { LINES( MT_ITEM ) } action(s)| ).
        LO_ALV->GET_DISPLAY_SETTINGS( )->SET_STRIPED_PATTERN( ABAP_TRUE ).
        LO_ALV->GET_FUNCTIONS( )->SET_ALL( ABAP_TRUE ).
        LO_ALV->DISPLAY( ).

      CATCH CX_SALV_MSG CX_SALV_NOT_FOUND CX_SALV_DATA_ERROR.
    ENDTRY.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_UI->HIDE_COL
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_COLS                        TYPE REF TO CL_SALV_COLUMNS_TABLE
* | [--->] IV_NAME                        TYPE        LVC_FNAME
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD HIDE_COL.

    TRY.
        IO_COLS->GET_COLUMN( IV_NAME )->SET_TECHNICAL( ABAP_TRUE ).
      CATCH CX_SALV_NOT_FOUND.
    ENDTRY.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_UI->HOTSPOT_COL
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_COLS                        TYPE REF TO CL_SALV_COLUMNS_TABLE
* | [--->] IV_NAME                        TYPE        LVC_FNAME
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD HOTSPOT_COL.

    TRY.
        CAST CL_SALV_COLUMN_TABLE(
          IO_COLS->GET_COLUMN( IV_NAME )
        )->SET_CELL_TYPE( IF_SALV_C_CELL_TYPE=>HOTSPOT ).
      CATCH CX_SALV_NOT_FOUND.
    ENDTRY.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_UI->ICON_COL
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_COLS                        TYPE REF TO CL_SALV_COLUMNS_TABLE
* | [--->] IV_NAME                        TYPE        LVC_FNAME
* | [--->] IV_TIP                         TYPE        SCRTEXT_L(optional)
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD ICON_COL.

    TRY.
        DATA(LO_COL) = CAST CL_SALV_COLUMN_TABLE(
                         IO_COLS->GET_COLUMN( IV_NAME ) ).
        LO_COL->SET_ICON( IF_SALV_C_BOOL_SAP=>TRUE ).
        LO_COL->SET_ALIGNMENT( IF_SALV_C_ALIGNMENT=>CENTERED ).
        IF IV_TIP IS SUPPLIED AND IV_TIP IS NOT INITIAL.
          LO_COL->SET_TOOLTIP( CONV #( IV_TIP ) ).
        ENDIF.
      CATCH CX_SALV_NOT_FOUND.
    ENDTRY.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_UI->ON_LINK_CLICK
* +-------------------------------------------------------------------------------------------------+
* | [--->] ROW                            LIKE
* | [--->] COLUMN                         LIKE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD ON_LINK_CLICK.

    DATA(LS_ROW) = VALUE #( MT_LIST[ ROW ] OPTIONAL ).
    CHECK LS_ROW-LOG_ID IS NOT INITIAL.

    CASE COLUMN.

      WHEN 'LOG_ID' OR 'VBELN' OR 'C_DETAIL'.
        " the report owns the screen
        RAISE EVENT DETAIL_REQUESTED
          EXPORTING EV_LOG_ID = LS_ROW-LOG_ID.

      WHEN 'ITEM_COUNT'.
        POPUP_ITEMS( LS_ROW-LOG_ID ).

    ENDCASE.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_UI->POPUP_ITEMS
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_LOG_ID                      TYPE        ZWF_LOG_ID
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD POPUP_ITEMS.

    DATA(LT_ITEM) = MO_DATA->SELECT_ITEMS( IV_LOG_ID ).

    IF LT_ITEM IS INITIAL.
      MESSAGE 'No actions logged yet' TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    DATA LO_ALV TYPE REF TO CL_SALV_TABLE.

    TRY.
        CL_SALV_TABLE=>FACTORY(
          IMPORTING
            R_SALV_TABLE = LO_ALV
          CHANGING
            T_TABLE      = LT_ITEM ).

        BUILD_ITEM_COLUMNS( LO_ALV->GET_COLUMNS( ) ).

        LO_ALV->GET_DISPLAY_SETTINGS( )->SET_LIST_HEADER(
          |Approval history - log { IV_LOG_ID }| ).
        LO_ALV->GET_DISPLAY_SETTINGS( )->SET_STRIPED_PATTERN( ABAP_TRUE ).
        LO_ALV->GET_FUNCTIONS( )->SET_ALL( ABAP_TRUE ).

        LO_ALV->SET_SCREEN_POPUP( START_COLUMN = 5
                                  END_COLUMN   = 175
                                  START_LINE   = 3
                                  END_LINE     = 26 ).
        LO_ALV->DISPLAY( ).

      CATCH CX_SALV_MSG CX_SALV_NOT_FOUND CX_SALV_DATA_ERROR INTO DATA(LX).
        MESSAGE LX->GET_TEXT( ) TYPE 'I' DISPLAY LIKE 'E'.
    ENDTRY.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_LOG_RPT_UI->SET_COL
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_COLS                        TYPE REF TO CL_SALV_COLUMNS_TABLE
* | [--->] IV_NAME                        TYPE        LVC_FNAME
* | [--->] IV_SHORT                       TYPE        SCRTEXT_S
* | [--->] IV_MED                         TYPE        SCRTEXT_M
* | [--->] IV_LONG                        TYPE        SCRTEXT_L
* | [--->] IV_LEN                         TYPE        LVC_OUTLEN(optional)
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD SET_COL.

    TRY.
        DATA(LO_COL) = IO_COLS->GET_COLUMN( IV_NAME ).
        LO_COL->SET_SHORT_TEXT( IV_SHORT ).
        LO_COL->SET_MEDIUM_TEXT( IV_MED ).
        LO_COL->SET_LONG_TEXT( IV_LONG ).
        IF IV_LEN IS SUPPLIED AND IV_LEN > 0.
          LO_COL->SET_OUTPUT_LENGTH( IV_LEN ).
        ENDIF.
      CATCH CX_SALV_NOT_FOUND.
    ENDTRY.

  ENDMETHOD.
ENDCLASS.