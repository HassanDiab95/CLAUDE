*&---------------------------------------------------------------------*
*& Module Pool      YSP_MTOSO_APPROVE
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*

INCLUDE YSP_MTOSO_APP_TOP_CX.
*INCLUDE YSP_MTOSO_APPROVE_TOP                   .    " Global Data

* INCLUDE YSP_MTOSO_APPROVE_O01                   .  " PBO-Modules
* INCLUDE YSP_MTOSO_APPROVE_I01                   .  " PAI-Modules
* INCLUDE YSP_MTOSO_APPROVE_F01                   .  " FORM-Routines


INCLUDE YSP_MTOSO_APP_STATUS_01O01_CX.
*INCLUDE ysp_mtoso_approve_status_01o01.

INCLUDE YSP_MTOSO_APP_USER_COMMI01_CX.
*INCLUDE ysp_mtoso_approve_user_commi01.

INCLUDE YSP_MTOSO_APP_SCREEN_STF01_CX.
*INCLUDE ysp_mtoso_approve_screen_stf01.

INCLUDE YSP_MTOSO_APPROVE_FF01_CX.
*INCLUDE ysp_mtoso_approve_approve_ff01.

INCLUDE YSP_MTOSO_APP_REJECT_FUF01_CX.
*INCLUDE ysp_mtoso_approve_reject_fuf01.

INCLUDE YSP_MTOSO_APP_STATUS_00O01_CX.
*INCLUDE ysp_mtoso_approve_status_00o01.

INCLUDE YSP_MTOSO_APP_USER_COMMI02_CX.
*INCLUDE ysp_mtoso_approve_user_commi02.

INCLUDE YSP_MTOSO_APP_EXECUTEF01_CX.
*INCLUDE ysp_mtoso_approve_executef01.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100_EXIT  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE USER_COMMAND_0100_EXIT INPUT.

  CASE SY-UCOMM.
    WHEN 'EXIT' OR 'BACK' OR 'CANCEL'.
      LEAVE PROGRAM .
  ENDCASE.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0099_EXIT  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE USER_COMMAND_0099_EXIT INPUT.

  CASE SY-UCOMM.
    WHEN 'EXIT' OR 'BACK' OR 'CANCEL'.
      LEAVE PROGRAM .
  ENDCASE.

ENDMODULE.

*&---------------------------------------------------------------------*
*& Include YSP_MTOSO_APPROVE_TOP                    - Module Pool      YSP_MTOSO_APPROVE
*&---------------------------------------------------------------------*
PROGRAM YSP_MTOSO_APPROVE.


TABLES : ZSOAPPROVAL.
DATA: LOG_COUNT TYPE INT8.
DATA : SD_APPROVE            TYPE C, FI_APPROVE TYPE C, FI_APPROVE_IND_PROFIT TYPE C, FI_APPROVE_IND_CREDIT TYPE C.
DATA: IT_PROG_ROW_INDEX TYPE  LVC_T_ROW,
      WA_PROG_ROW_INDEX LIKE LINE OF IT_PROG_ROW_INDEX,
      FLAG              TYPE C,
      GRID              TYPE REF TO CL_GUI_ALV_GRID,
      CONTAINER         TYPE REF TO CL_GUI_CUSTOM_CONTAINER,
      LW_LAYOUT         TYPE LVC_S_LAYO,
      IT_FIELDCAT       TYPE LVC_T_FCAT,
      WA_FIELDCAT       LIKE LINE OF IT_FIELDCAT,
      LS_EXCLUDE        TYPE UI_FUNC,
      PT_EXCLUDE        TYPE UI_FUNCTIONS,
      LT_ROWS           TYPE LVC_T_ROW,
      CA                LIKE LINE OF LT_ROWS,
      LT_EVENTS         TYPE CNTL_SIMPLE_EVENTS,
      L_EVENT           TYPE CNTL_SIMPLE_EVENT,
      OK_CODE           LIKE SY-UCOMM,
      LS_STABLE         TYPE LVC_S_STBL.

TYPES : BEGIN OF YSP_MTOSO_APPROVE_COL.
    INCLUDE TYPE YSP_MTOSO_APPROVE_CX. "#EC CI_USAGE_OK[2383423]
TYPES : COLOR TYPE LVC_T_SCOL.
TYPES : END OF YSP_MTOSO_APPROVE_COL.

*DATA: SO_TAB TYPE STANDARD TABLE OF YSP_MTOSO_APPROVE,
DATA: SO_TAB TYPE STANDARD TABLE OF YSP_MTOSO_APPROVE_COL,
      SO_WA  LIKE LINE OF SO_TAB.

DATA: FROM_DATE  LIKE VBAK-AUDAT,
      TO_DATE    LIKE VBAK-AUDAT,
      DOC_NUMBER LIKE VBAK-VBELN,
      DATEV_F    LIKE VBAK-AUDAT,
      DATEV_T    LIKE VBAK-AUDAT.
TYPES: BEGIN OF SO_STRUCT,
         VBELN TYPE VBELN,
       END OF SO_STRUCT.
DATA: IT_SO_TEMP TYPE TABLE OF SO_STRUCT,
      WA_SO_TEMP TYPE SO_STRUCT.

DATA: coln   TYPE lvc_s_scol,
      coltab TYPE lvc_t_scol,
*      coltab TYPE lvc_s_scol,
      color  TYPE lvc_s_colo.

* Double Click
DATA: G_GRID TYPE REF TO CL_GUI_ALV_GRID.
DATA: L_VALID       TYPE C,
      V_FLAG,
      V_DATA_CHANGE,
      V_ROW         TYPE LVC_S_ROW,
      V_COLUMN      TYPE LVC_S_COL,
      V_ROW_NUM     TYPE LVC_S_ROID.
DATA: SAVE_OK      LIKE SY-UCOMM,
      G_CONTAINER1 TYPE SCRFNAME VALUE 'TEST',
      GS_LAYOUT    TYPE LVC_S_LAYO.

DATA:BEGIN OF  ITAB OCCURS 0,
       VBELN        LIKE LIKP-VBELN,
       POSNR        LIKE LIPS-POSNR,
       COMISN(10),
       BOX(1),
       CELLCOLOR    TYPE LVC_T_SCOL, "required for color
       DROP(20),
       HANDLE_STYLE TYPE LVC_T_STYL,
     END OF ITAB.

DATA : APPRV_TAB TYPE STANDARD TABLE OF ZSOAPPROVAL,
       APPRV_WA  TYPE ZSOAPPROVAL.
DATA : TA_LOG TYPE STANDARD TABLE OF YSP_MTOSO_LOG,
       WA_LOG TYPE YSP_MTOSO_LOG.
DATA : BUKRS  TYPE VBAK-BUKRS_VF,BUKRS1 TYPE VBAK-BUKRS_VF.


*----------------------------------------------------------------------*
***INCLUDE YSP_MTOSO_APPROVE_STATUS_01O01.
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Module STATUS_0100 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE STATUS_0100 OUTPUT.
  SET PF-STATUS 'YSP_MTOSO_STATUS1'.
  SET TITLEBAR 'YSP_MTOSO_TITLE'.

  IF CONTAINER IS INITIAL.

    CREATE OBJECT CONTAINER
      EXPORTING
        CONTAINER_NAME = 'CONTROLLER1'.

    CREATE OBJECT GRID
      EXPORTING
        I_PARENT = CONTAINER.

    CALL METHOD GRID->REGISTER_EDIT_EVENT
      EXPORTING
        I_EVENT_ID = CL_GUI_ALV_GRID=>MC_EVT_MODIFIED
      EXCEPTIONS
        ERROR      = 1
        OTHERS     = 2.

*    CREATE OBJECT EVENT_RECEIVER.
*
*    SET HANDLER EVENT_RECEIVER->HANDLE_DOUBLE_CLICK FOR GRID.

*    SET HANDLER  EVENT_RECEIVER->

    REFRESH IT_FIELDCAT.

  WA_FIELDCAT-FIELDNAME = 'SO_NUM'.
    WA_FIELDCAT-COLTEXT = 'Sales order'.
    WA_FIELDCAT-OUTPUTLEN = 10.
    WA_FIELDCAT-HOTSPOT = 'X'.

    APPEND WA_FIELDCAT TO IT_FIELDCAT.
    CLEAR WA_FIELDCAT.

    WA_FIELDCAT-FIELDNAME = 'CUSTOMER_NO'.
    WA_FIELDCAT-COLTEXT = 'Customer No'.
    WA_FIELDCAT-OUTPUTLEN = 10.
    APPEND WA_FIELDCAT TO IT_FIELDCAT.
    CLEAR WA_FIELDCAT.

    WA_FIELDCAT-FIELDNAME = 'CUSTOMER_NAME'.
    WA_FIELDCAT-COLTEXT = 'Customer Name'.
    WA_FIELDCAT-OUTPUTLEN = 10.
    APPEND WA_FIELDCAT TO IT_FIELDCAT.
    CLEAR WA_FIELDCAT.

    WA_FIELDCAT-FIELDNAME = 'MATNR'.
    WA_FIELDCAT-COLTEXT = 'Material'.
    WA_FIELDCAT-OUTPUTLEN = 8.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND WA_FIELDCAT TO IT_FIELDCAT.
    CLEAR WA_FIELDCAT.

    WA_FIELDCAT-FIELDNAME = 'DESIGN_CODE'.
    WA_FIELDCAT-COLTEXT = 'Design Code'.
    WA_FIELDCAT-OUTPUTLEN = 8.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND WA_FIELDCAT TO IT_FIELDCAT.
    CLEAR WA_FIELDCAT.

    WA_FIELDCAT-FIELDNAME = 'DC_DESC'.
    WA_FIELDCAT-COLTEXT = 'Design Desc.'.
    WA_FIELDCAT-OUTPUTLEN = 8.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND WA_FIELDCAT TO IT_FIELDCAT.
    CLEAR WA_FIELDCAT.

        WA_FIELDCAT-FIELDNAME = 'Posnr'.
    WA_FIELDCAT-COLTEXT = 'ITEM'.
    WA_FIELDCAT-OUTPUTLEN = 8.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND WA_FIELDCAT TO IT_FIELDCAT.
    CLEAR WA_FIELDCAT.

    WA_FIELDCAT-FIELDNAME = 'DOC_DATE'.
    WA_FIELDCAT-COLTEXT = 'Date'.
    WA_FIELDCAT-OUTPUTLEN = 8.
    APPEND WA_FIELDCAT TO IT_FIELDCAT.
    CLEAR WA_FIELDCAT.

    WA_FIELDCAT-FIELDNAME = 'SALES_OFF'.
    WA_FIELDCAT-COLTEXT = 'Sales Office'.
    WA_FIELDCAT-OUTPUTLEN = 4.
    APPEND WA_FIELDCAT TO IT_FIELDCAT.
    CLEAR WA_FIELDCAT.

    WA_FIELDCAT-FIELDNAME = 'DELV_DATE'.
    WA_FIELDCAT-COLTEXT = 'Delivery Date'.
    WA_FIELDCAT-OUTPUTLEN = 8.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND WA_FIELDCAT TO IT_FIELDCAT.
    CLEAR WA_FIELDCAT.

   WA_FIELDCAT-FIELDNAME = 'NET_VALUE'.
    WA_FIELDCAT-COLTEXT = 'Net Value'.
    WA_FIELDCAT-OUTPUTLEN = 10.
    APPEND WA_FIELDCAT TO IT_FIELDCAT.
    CLEAR WA_FIELDCAT.

    WA_FIELDCAT-FIELDNAME = 'TOTAL_COST'.
    WA_FIELDCAT-COLTEXT = 'TOTAL COST'.
    WA_FIELDCAT-OUTPUTLEN = 10.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND WA_FIELDCAT TO IT_FIELDCAT.
    CLEAR WA_FIELDCAT.

    WA_FIELDCAT-FIELDNAME = 'CONTR_PROFIT'.
    WA_FIELDCAT-COLTEXT = 'CONTR PROFIT'.
    WA_FIELDCAT-OUTPUTLEN = 10.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND WA_FIELDCAT TO IT_FIELDCAT.
    CLEAR WA_FIELDCAT.

    WA_FIELDCAT-FIELDNAME = 'PROFIT'.
    WA_FIELDCAT-COLTEXT = 'Profit'.
    WA_FIELDCAT-OUTPUTLEN = 10.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND WA_FIELDCAT TO IT_FIELDCAT.
    CLEAR WA_FIELDCAT.

    WA_FIELDCAT-FIELDNAME = 'PROFIT_STATUS'.
    WA_FIELDCAT-COLTEXT = 'Profit Status'.
    WA_FIELDCAT-OUTPUTLEN = 15.
    WA_FIELDCAT-EMPHASIZE = 'C511'.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND WA_FIELDCAT TO IT_FIELDCAT.
    CLEAR WA_FIELDCAT.

    WA_FIELDCAT-FIELDNAME = 'CREDIT_LIMIT'.
    WA_FIELDCAT-COLTEXT = 'Credit Limit'.
    WA_FIELDCAT-OUTPUTLEN = 13.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND WA_FIELDCAT TO IT_FIELDCAT.
    CLEAR WA_FIELDCAT.

    WA_FIELDCAT-FIELDNAME = 'CREDIT_EXP'.
    WA_FIELDCAT-COLTEXT = 'Credit Exposure'.
    WA_FIELDCAT-OUTPUTLEN = 13.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND WA_FIELDCAT TO IT_FIELDCAT.
    CLEAR WA_FIELDCAT.

    WA_FIELDCAT-FIELDNAME = 'CREDIT_STATUS'.
    WA_FIELDCAT-COLTEXT = 'Credit Status'.
    WA_FIELDCAT-OUTPUTLEN = 20.
        WA_FIELDCAT-EMPHASIZE = 'C511'.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND WA_FIELDCAT TO IT_FIELDCAT.
    CLEAR WA_FIELDCAT.

        WA_FIELDCAT-FIELDNAME = 'SM_APPROVAL'.
    WA_FIELDCAT-COLTEXT = 'Sales Approval'.
    WA_FIELDCAT-OUTPUTLEN = 12.
     WA_FIELDCAT-EMPHASIZE = 'C511'.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND WA_FIELDCAT TO IT_FIELDCAT.
    CLEAR WA_FIELDCAT.

        WA_FIELDCAT-FIELDNAME = 'AR_APPROVAL'.
    WA_FIELDCAT-COLTEXT = 'FI Approval'.
    WA_FIELDCAT-OUTPUTLEN = 12.
     WA_FIELDCAT-EMPHASIZE = 'C511'.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND WA_FIELDCAT TO IT_FIELDCAT.
    CLEAR WA_FIELDCAT.

    CLEAR PT_EXCLUDE.
    LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_GRAPH .
    APPEND LS_EXCLUDE TO PT_EXCLUDE.
    LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_INFO .
    APPEND LS_EXCLUDE TO PT_EXCLUDE.
    LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_PRINT .
    APPEND LS_EXCLUDE TO PT_EXCLUDE.
    LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_VIEWS .
    APPEND LS_EXCLUDE TO PT_EXCLUDE.
    LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_DETAIL.
    APPEND LS_EXCLUDE TO PT_EXCLUDE.
    LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_REFRESH.
    APPEND LS_EXCLUDE TO PT_EXCLUDE.
*    LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_MB_EXPORT .
*    APPEND LS_EXCLUDE TO PT_EXCLUDE.
    LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_CHECK .
    APPEND LS_EXCLUDE TO PT_EXCLUDE.
*    LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_MB_SUM.
*    APPEND LS_EXCLUDE TO PT_EXCLUDE.
    LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_SUBTOT.
    APPEND LS_EXCLUDE TO PT_EXCLUDE.
    LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_LOC_APPEND_ROW.
    APPEND LS_EXCLUDE TO PT_EXCLUDE.
    LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_LOC_COPY.
    APPEND LS_EXCLUDE TO PT_EXCLUDE.
    LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_LOC_COPY_ROW.
    APPEND LS_EXCLUDE TO PT_EXCLUDE.
    LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_LOC_CUT.
    APPEND LS_EXCLUDE TO PT_EXCLUDE.
    LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_LOC_DELETE_ROW.
    APPEND LS_EXCLUDE TO PT_EXCLUDE.
    LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_LOC_INSERT_ROW.
    APPEND LS_EXCLUDE TO PT_EXCLUDE.
    LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_LOC_MOVE_ROW.
    APPEND LS_EXCLUDE TO PT_EXCLUDE.
    LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_LOC_PASTE.
    APPEND LS_EXCLUDE TO PT_EXCLUDE.
    LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_LOC_PASTE_NEW_ROW.
    APPEND LS_EXCLUDE TO PT_EXCLUDE.
    LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_FC_LOC_UNDO.
    APPEND LS_EXCLUDE TO PT_EXCLUDE.
    LW_LAYOUT-GRID_TITLE = 'Sales order Not Approved'.
    LW_LAYOUT-STYLEFNAME = 'CELLTAB'.
*    LW_LAYOUT-CWIDTH_OPT  = 'X'.
    " BUILD ALV
    DATA:  LS_VARIANT TYPE DISVARIANT.
    LS_VARIANT = SY-REPID.
    LW_LAYOUT-ctab_fname = 'COLOR'.
    CALL METHOD GRID->SET_TABLE_FOR_FIRST_DISPLAY
      EXPORTING
        I_STRUCTURE_NAME     = 'YSP_MTOSO_APPROVE_CX'
        IS_LAYOUT            = LW_LAYOUT
        IT_TOOLBAR_EXCLUDING = PT_EXCLUDE
        I_SAVE               = 'A'
        IS_VARIANT           = LS_VARIANT
      CHANGING
        IT_OUTTAB            = SO_TAB
        IT_FIELDCATALOG      = IT_FIELDCAT.

  ELSE.
    LS_STABLE-ROW = 'X'.
    LS_STABLE-COL = 'X'.
    CALL METHOD GRID->REFRESH_TABLE_DISPLAY
      EXPORTING
        IS_STABLE = LS_STABLE
      EXCEPTIONS
        FINISHED  = 1
        OTHERS    = 2.
    IF SY-SUBRC <> 0.
    ENDIF.
  ENDIF.
  PERFORM SCREEN_START.
ENDMODULE.
*----------------------------------------------------------------------*
***INCLUDE YSP_MTOSO_APPROVE_USER_COMMI01.
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE USER_COMMAND_0100 INPUT.


  SET CURSOR FIELD 'BAR_TXT' OFFSET 0.
  CASE SY-UCOMM.
    WHEN 'SEARCH'.
      PERFORM SEARCH.
    WHEN 'APPROVE'.
      PERFORM APPROVE_FUN.
    WHEN 'REJECT'.
      PERFORM REJECT_FUN.
    WHEN 'DISPLAY'.
      REFRESH : IT_PROG_ROW_INDEX.
      CALL METHOD GRID->get_selected_rows
        IMPORTING
          ET_INDEX_ROWS = IT_PROG_ROW_INDEX.
      LOOP AT IT_PROG_ROW_INDEX INTO WA_PROG_ROW_INDEX.
        READ TABLE SO_TAB INTO SO_WA INDEX WA_PROG_ROW_INDEX-INDEX.
        SET PARAMETER ID 'AUN' FIELD SO_WA-SO_NUM.
        CALL TRANSACTION 'VA03' AND SKIP FIRST SCREEN.
      ENDLOOP.
  ENDCASE.
ENDMODULE.
*&---------------------------------------------------------------------*
*&       Class lcl_event_receiver
*&---------------------------------------------------------------------*
*        Text
*----------------------------------------------------------------------*

CLASS LCL_EVENT_RECEIVER DEFINITION.

  PUBLIC SECTION.

    METHODS:
      HANDLE_TOOLBAR
                    FOR EVENT TOOLBAR OF CL_GUI_ALV_GRID
        IMPORTING E_OBJECT E_INTERACTIVE,
      HANDLE_USER_COMMAND
                    FOR EVENT USER_COMMAND OF CL_GUI_ALV_GRID
        IMPORTING E_UCOMM,
      HANDLE_DATA_CHANGED
                    FOR EVENT DATA_CHANGED OF CL_GUI_ALV_GRID
        IMPORTING ER_DATA_CHANGED E_ONF4 E_ONF4_BEFORE E_ONF4_AFTER,
      "       TO BE TRIGGERED AFTER DATA CHANGING IS FINISHED
      HANDLE_DATA_CHANGED_FINISHED
                    FOR EVENT DATA_CHANGED_FINISHED OF CL_GUI_ALV_GRID
        IMPORTING E_MODIFIED .

    METHODS:
**Hot spot Handler
      HANDLE_HOTSPOT_CLICK FOR EVENT HOTSPOT_CLICK OF CL_GUI_ALV_GRID
        IMPORTING E_ROW_ID E_COLUMN_ID ES_ROW_NO,

**Double Click Handler
      HANDLE_DOUBLE_CLICK FOR EVENT DOUBLE_CLICK OF CL_GUI_ALV_GRID
        IMPORTING E_ROW E_COLUMN ES_ROW_NO.


  PRIVATE SECTION.


ENDCLASS.
*&---------------------------------------------------------------------*
*&       Class (Implementation)  lcl_event_receiver
*&---------------------------------------------------------------------*
*        Text
*----------------------------------------------------------------------*
CLASS LCL_EVENT_RECEIVER IMPLEMENTATION.

  METHOD HANDLE_DATA_CHANGED_FINISHED .

    LS_STABLE-ROW = 'X'.
    LS_STABLE-COL = 'X'.
    CALL METHOD GRID->REFRESH_TABLE_DISPLAY
      EXPORTING
        IS_STABLE = LS_STABLE
      EXCEPTIONS
        FINISHED  = 1
        OTHERS    = 2.
    IF SY-SUBRC <> 0.
    ENDIF.

  ENDMETHOD .                    "HANDLE_DATA_CHANGED_FINISHED

  METHOD HANDLE_DATA_CHANGED.

    LS_STABLE-ROW = 'X'.
    LS_STABLE-COL = 'X'.
    CALL METHOD GRID->REFRESH_TABLE_DISPLAY
      EXPORTING
        IS_STABLE = LS_STABLE
      EXCEPTIONS
        FINISHED  = 1
        OTHERS    = 2.
    IF SY-SUBRC <> 0.
    ENDIF.

  ENDMETHOD.
  METHOD HANDLE_TOOLBAR.
  ENDMETHOD.                    "HANDLE_TOOLBAR

  METHOD HANDLE_USER_COMMAND.
  ENDMETHOD.                           "HANDLE_USER_COMMAND
*-----------------------------------------------------------------
*Handle Hotspot Click

  METHOD HANDLE_HOTSPOT_CLICK .
    BREAK-POINT.
    CLEAR: V_ROW,V_COLUMN,V_ROW_NUM.

    V_ROW = E_ROW_ID.

    V_COLUMN = E_COLUMN_ID.

    V_ROW_NUM = ES_ROW_NO.

*    MESSAGE I000 WITH V_ROW 'clicked'.

  ENDMETHOD. "lcl_event_handler

*Handle Double Click
  METHOD  HANDLE_DOUBLE_CLICK.
    BREAK-POINT.
  ENDMETHOD.                    "handle_double_click

ENDCLASS.
*&---------------------------------------------------------------------*
*& Form SEARCH
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM SEARCH .
*  CLEAR : SO_WA , SO_TAB, IT_SO_TEMP , WA_SO_TEMP.
*  IF DOC_NUMBER IS NOT INITIAL.
*    SELECT VBELN FROM VBEP INTO CORRESPONDING FIELDS OF TABLE IT_SO_TEMP
*  WHERE ETTYP = 'CN' AND VBELN = DOC_NUMBER  .
*  ELSE.
*    SELECT VBELN FROM VBEP INTO CORRESPONDING FIELDS OF TABLE IT_SO_TEMP
*WHERE ETTYP = 'CN' .
*  ENDIF.
*
*  DATA : SORG TYPE VBAK-VKORG , AUART LIKE VBAK-AUART.
*  LOOP AT IT_SO_TEMP INTO WA_SO_TEMP.
*    CLEAR : SORG.
*    IF FROM_DATE = '00000000' AND TO_DATE = '00000000'.
*      SELECT SINGLE VKORG FROM VBAK INTO SORG
*        WHERE VBELN = WA_SO_TEMP-VBELN .
*
*    ELSEIF FROM_DATE <> '00000000' AND TO_DATE = '00000000'.
*      SELECT SINGLE VKORG FROM VBAK INTO SORG
*        WHERE VBELN = WA_SO_TEMP-VBELN AND AUDAT = FROM_DATE  .
*
*    ELSEIF FROM_DATE = '00000000' AND TO_DATE <> '00000000'.
*      SELECT SINGLE VKORG FROM VBAK INTO SORG
*        WHERE VBELN = WA_SO_TEMP-VBELN AND  AUDAT <= TO_DATE   .
*
*    ELSEIF FROM_DATE <> '00000000' AND TO_DATE <> '00000000'.
*      SELECT SINGLE VKORG FROM VBAK INTO SORG
*        WHERE VBELN = WA_SO_TEMP-VBELN AND AUDAT >= FROM_DATE AND AUDAT <= TO_DATE   .
*
*    ENDIF.
*        SELECT SINGLE AUART FROM VBAK INTO AUART WHERE VBELN = WA_SO_TEMP-VBELN .
*     IF AUART <> 'YPCO' .
*       IF AUART <> 'YCCO'.
*    IF SORG = '1500'.
*      SELECT SINGLE VBELN FROM VBAP INTO SO_WA-SO_NUM
*        WHERE PSTYV = 'ZTAC' AND VBELN = WA_SO_TEMP-VBELN
*           AND ABGRU = '' .
*    ELSEIF SORG = '1200'.
*       SELECT SINGLE VBELN FROM VBAP INTO SO_WA-SO_NUM
*        WHERE PSTYV = 'ZTAW' AND VBELN = WA_SO_TEMP-VBELN
*           AND ABGRU = '' .
*    ENDIF.
*      IF SY-SUBRC = 0.
*        SELECT SINGLE KUNNR NETWR AUDAT VKBUR VDATU FROM VBAK
*          INTO ( SO_WA-CUSTOMER_NO , SO_WA-NET_VALUE , SO_WA-DOC_DATE ,
*                  SO_WA-SALES_OFF , SO_WA-DELV_DATE )
*          WHERE VBELN = WA_SO_TEMP-VBELN .
*         CLEAR:  SO_WA-TOTAL_COST.
*          DATA : WAVWR TYPE VBAP-WAVWR.
*          SELECT WAVWR FROM VBAP INTO WAVWR
*            WHERE VBELN = WA_SO_TEMP-VBELN.
*            SO_WA-TOTAL_COST = SO_WA-TOTAL_COST + WAVWR .
*          ENDSELECT.
*          SO_WA-PROFIT = SO_WA-NET_VALUE - SO_WA-TOTAL_COST.
*           CLEAR : color , coln , coltab.
*           IF SO_WA-TOTAL_COST = 0 .
*              SO_WA-PROFIT_STATUS = 'COST ERROR'.
*            "coloring
*
*            color-col = '6'. "red color
*            color-int = '0'.
*            color-inv = '0'.
*            coln-fname = 'PROFIT_STATUS'.
*            coln-color = color.
*            APPEND coln to coltab.
*            so_wa-color = coltab.
*            "end coloring
*            SO_WA-AR_APPROVAL ='Not Approved'.
*            "coloring
*                    CLEAR : color , coln .
*                    color-col = '6'. "red color
*                    color-int = '0'.
*                    color-inv = '0'.
*                    coln-fname = 'AR_APPROVAL'.
*                    coln-color = color.
*                    APPEND coln to coltab.
*                    so_wa-color = coltab.
*           "end coloring
*          ELSEIF SO_WA-PROFIT < 0.
*            SO_WA-PROFIT_STATUS = 'Loss'.
*            "coloring
*
*            color-col = '6'. "red color
*            color-int = '0'.
*            color-inv = '0'.
*            coln-fname = 'PROFIT_STATUS'.
*            coln-color = color.
*            APPEND coln to coltab.
*            so_wa-color = coltab.
*            "end coloring
*            SO_WA-AR_APPROVAL ='Not Approved'.
*            "coloring
*                    CLEAR : color , coln .
*                    color-col = '6'. "red color
*                    color-int = '0'.
*                    color-inv = '0'.
*                    coln-fname = 'AR_APPROVAL'.
*                    coln-color = color.
*                    APPEND coln to coltab.
*                    so_wa-color = coltab.
*           "end coloring
*            ELSE.
*             SO_WA-PROFIT_STATUS = 'Profit'.
*         SO_WA-AR_APPROVAL ='Approved'.
*          ENDIF.
*          SELECT SINGLE CREDIT_LIMIT FROM UKMBP_CMS_SGM
*            INTO SO_WA-CREDIT_LIMIT WHERE PARTNER = SO_WA-CUSTOMER_NO.
*IF SY-SUBRC <> 0.
*  SO_WA-CREDIT_STATUS = 'Not related to Credit Managment'.
*     "coloring
*                    CLEAR : color , coln .
*                    color-col = '3'. "Yellow color
*                    color-int = '0'.
*                    color-inv = '0'.
*                    coln-fname = 'CREDIT_STATUS'.
*                    coln-color = color.
*                    APPEND coln to coltab.
*                    so_wa-color = coltab.
*                   "end coloring
*ELSE.
*
*          CALL FUNCTION 'UKM_COMMTS_BUPA_DISPLAY'
*            EXPORTING
*              I_PARTNER            = SO_WA-CUSTOMER_NO
*              I_SEGMENT            = 'WFICS'
**             I_DATE               =
**             I_REFRESH            = 'X'
*            IMPORTING
*              E_COMMITMENTS_AMOUNT = SO_WA-CREDIT_EXP
**             E_AMOUNT_L           =
*            .
*
*              IF SO_WA-CREDIT_LIMIT < SO_WA-CREDIT_EXP.
*                  SO_WA-CREDIT_STATUS = 'Exceed the limit'.
*                   "coloring
*                    CLEAR : color , coln .
*                    color-col = '6'. "red color
*                    color-int = '0'.
*                    color-inv = '0'.
*                    coln-fname = 'CREDIT_STATUS'.
*                    coln-color = color.
*                    APPEND coln to coltab.
*                    so_wa-color = coltab.
*                   "end coloring
*          if SO_WA-AR_APPROVAL ='Approved'.
*                        SO_WA-AR_APPROVAL ='Not Approved'.
*            "coloring
*                    CLEAR : color , coln .
*                    color-col = '6'. "red color
*                    color-int = '0'.
*                    color-inv = '0'.
*                    coln-fname = 'AR_APPROVAL'.
*                    coln-color = color.
*                    APPEND coln to coltab.
*                    so_wa-color = coltab.
*           "end coloring
*                     endif.
*                  else.
*                    SO_WA-CREDIT_STATUS = 'Did not Exceed '.
*                    FI_APPROVE_IND_CREDIT = 'X'.
*              ENDIF.
*ENDIF.
** Approval Status
*
*CLEAR : SD_APPROVE , FI_APPROVE.
*SELECT SINGLE SD_APPROVE FI_APPROVE FROM ZSOAPPROVAL
*  INTO ( SD_APPROVE , FI_APPROVE ) WHERE VBELN = SO_WA-SO_NUM.
*  IF SD_APPROVE = 'X'.
*    SO_WA-SM_APPROVAL ='Approved'.
*  ELSE.
*  SO_WA-SM_APPROVAL ='Not Approved'.
*   "coloring
*                    CLEAR : color , coln .
*                    color-col = '6'. "red color
*                    color-int = '0'.
*                    color-inv = '0'.
*                    coln-fname = 'SM_APPROVAL'.
*                    coln-color = color.
*                    APPEND coln to coltab.
*                    so_wa-color = coltab.
*                   "end coloring
*  ENDIF.
**  IF FI_APPROVE = 'X' OR ( FI_APPROVE_IND_PROFIT = 'X' AND FI_APPROVE_IND_CREDIT = 'X' ).
**   SO_WA-AR_APPROVAL ='Approved'.
**  ELSE.
** SO_WA-AR_APPROVAL ='Not Approved'.
**  "coloring
**                    CLEAR : color , coln .
**                    color-col = '6'. "red color
**                    color-int = '0'.
**                    color-inv = '0'.
**                    coln-fname = 'AR_APPROVAL'.
**                    coln-color = color.
**                    APPEND coln to coltab.
**                    so_wa-color = coltab.
**                   "end coloring
**  ENDIF.
**End Approval Status
*  BREAK msalah.
*SELECT SINGLE SD_APPROVE FI_APPROVE FROM ZSOAPPROVAL
*  INTO ( SD_APPROVE , FI_APPROVE ) WHERE VBELN = SO_WA-SO_NUM.
*
*  IF SY-SUBRC <> 0.
*
*  APPRV_WA-VBELN = SO_WA-SO_NUM.
*  APPRV_WA-BUKRS = BUKRS.
*   IF SO_WA-AR_APPROVAL ='Approved'  .
*      APPRV_WA-FI_APPROVE = 'X'.
*    ENDIF.
*
*  APPEND APPRV_WA TO APPRV_TAB.
*  INSERT ZSOAPPROVAL FROM APPRV_WA.
*  CLEAR APPRV_WA.
*ENDIF.
*
*
*      APPEND SO_WA TO SO_TAB.
*      CLEAR SO_WA.
*    ENDIF.
*ENDIF.
*ENDIF.
*ENDLOOP.
*      DELETE ADJACENT DUPLICATES FROM SO_TAB
*      COMPARING SO_NUM.
*CALL METHOD GRID->REFRESH_TABLE_DISPLAY
*  EXPORTING
*    I_SOFT_REFRESH = 'X'.

ENDFORM.

*----------------------------------------------------------------------*
***INCLUDE YSP_MTOSO_APPROVE_SCREEN_STF01.
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form SCREEN_START
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*

*-----------------------------------------------------------------------------*
* Modification history                                                        *
*-----------------------------------------------------------------------------*
* Date        |Request No  |Author             |Description                   *
*-----------------------------------------------------------------------------*
* 03/11/2020  |DE3K919163 |IABAPT [Heba] |SD Support "T00002023/ CH1369"      *
* 01/02/2021  |DE3K919612 |IABAPT [Heba] |SD Support "T00002246/CH1555"       *
* 17/02/2021  |DE3K919734 |IABAPT [Heba] |SD Support "T00002246/CH1555"       *
* 13/07/2021  |DE3K920394 |IABAPT [Heba] |SD Support "T00002246/CH1555"       *
* 06/09/2021  |DE3K920715 |IABAPT [Heba] |SD Support "T00002741/IN5636"
*-----------------------------------------------------------------------------*

FORM SCREEN_START .
  IF FLAG <> 'X' .
    CLEAR : SO_WA , SO_TAB .
    BREAK MSALAH.
    DATA : WAVWR TYPE VBAP-WAVWR, CUOBJ TYPE VBAP-CUOBJ,
           PSTYV TYPE VBAP-PSTYV,  KALAB TYPE MSKA-KALAB, COUNT TYPE INT8.

    RANGES : ITAB FOR PSTYV,
             SCH_SEL FOR VBEP-ETTYP,  "--Added by Heba for Support Task "T00002023/CH1369"
             S_TYP   FOR VBAK-AUART.  "--Added by Heba for Support Task "T0000281/IN57218"


    IF BUKRS = 1600 .
      ITAB-LOW = 'YZTC'   .
      ITAB-OPTION = 'EQ'.
      ITAB-SIGN = 'I'.
      APPEND ITAB.
      ITAB-LOW = 'YFRE'   .
      ITAB-OPTION = 'EQ'.
      ITAB-SIGN = 'I'.
      APPEND ITAB.
    ENDIF.


*Begin of Code Commented by Heba for Support Task "T0000281/IN57218" ....
"Restrict the doc. types in case of 1400
    REFRESH S_TYP.
    IF BUKRS = 1400 .
      S_TYP-LOW = 'ZEM'.
      S_TYP-OPTION = 'EQ'.
      S_TYP-SIGN = 'I'.
      APPEND S_TYP.
      S_TYP-LOW = 'ZMT'.
      S_TYP-OPTION = 'EQ'.
      S_TYP-SIGN = 'I'.
      APPEND S_TYP.

      "added by hager mohsen SD Support Task T00005692 10.11.2025
      S_TYP-LOW = 'ZOR'.
      S_TYP-OPTION = 'EQ'.
      S_TYP-SIGN = 'I'.
      APPEND S_TYP.

       S_TYP-LOW = 'ZFC'.
      S_TYP-OPTION = 'EQ'.
      S_TYP-SIGN = 'I'.
      APPEND S_TYP.
      "endadded
    ENDIF.
*End Add...


*Begin of Code Commented by Heba for Support Task "T00002023/CH1369" ....
**Begin of Code added by Heba for Support Task "T00002023/CH1369" ....
*    "Add 'Schedule line category' Selection Values
*    SCH_SEL-OPTION = 'EQ'.
*    SCH_SEL-SIGN = 'I'.
*    SCH_SEL-LOW = 'CN'.
*    APPEND SCH_SEL.
*    IF BUKRS = 1300
*      OR BUKRS = 1400. "--Added by Heba for Support "T00002246/CH1555"...
*      SCH_SEL-LOW = 'CP'.
*      APPEND SCH_SEL.
*    ENDIF.
**End of Code added by Heba for Support Task "T00002023/CH1369" ....
*End of Code Commented by Heba for Support Task "T00002023/CH1369" ....

    COUNT = 0.
    SELECT VBAK~VBELN VBAP~MATNR VBAP~POSNR VBAP~NETWR VBAP~WAVWR VBAK~KUNNR VBAK~AUDAT VBAK~VDATU
     VBAP~CUOBJ VBAK~VKBUR VBAK~KNUMV FROM VBAP
      INNER JOIN VBAK ON VBAK~VBELN = VBAP~VBELN
      INNER JOIN VBEP ON VBEP~VBELN = VBAP~VBELN AND VBEP~POSNR = VBAP~POSNR
      INTO (SO_WA-SO_NUM , SO_WA-MATNR , SO_WA-POSNR , SO_WA-NET_VALUE , SO_WA-TOTAL_COST
      , SO_WA-CUSTOMER_NO , SO_WA-DOC_DATE , SO_WA-DELV_DATE , CUOBJ , SO_WA-SALES_OFF , SO_WA-KNUMV)
         WHERE VBAP~PSTYV IN ITAB
      "--UnCommented by Heba for Support Task "T00002023/CH1369" on 11/7/2021
       AND VBEP~ETTYP = 'CN'      "--Commented by Heba for Support Task "T00002023/CH1369"
       "--End...

      "--Commented by Heba for Support Task "T00002023/CH1369" on 11/07/2021
       "AND VBEP~ETTYP IN SCH_SEL  "--Added by Heba for Support Task "T00002023/CH1369"
       "--End...

      AND VBAP~WERKS = BUKRS
      AND VBAP~ABSTA <> 'C' AND  ( VBAK~VBTYP = 'C' OR VBAK~VBTYP = 'I' )
*      AND VBAK~AUART IN ('ZEM' , 'ZMT') "--Added by Heba for Support Task "T00002023/CH1369" on 11/07/2021
      AND VBAK~AUART IN S_TYP "--Added by Heba for Support Task "T0000281/IN57218" on 29/09/2021
      AND VBAK~AUDAT >= DATEV_F AND VBAK~AUDAT <= DATEV_T.


*1)	Select Cost estimate number (KALNR) from TABLE KEKO where VBELN and POSNR equal to SD Document number and SD Document item and TOPKA = “X”
*2)	Using KALNR, use table “KEPH” to get how much is variable production costs. Where KEPH -KKZST = “”
*3)	variable production cost is the summation of fields “KST001+ KST002+ KST003+ KST004”
*4)	Variable contribution margin is the margin that results when variable production costs are subtracted from revenue
      DATA : KALNR  TYPE KEKO-KALNR,
             KST001 TYPE KEPH-KST001,KST002 TYPE KEPH-KST002,
             KST003 TYPE KEPH-KST003, KST004 TYPE KEPH-KST004 .
      SELECT SINGLE KALNR FROM KEKO INTO KALNR WHERE  VBELN = SO_WA-SO_NUM AND POSNR = SO_WA-POSNR.
      SELECT SINGLE KST001 KST002 KST003 KST004 FROM KEPH INTO ( KST001, KST002, KST003, KST004 )
        WHERE KALNR = KALNR AND KKZST = ''.

      SO_WA-CONTR_PROFIT = SO_WA-NET_VALUE -  ( KST001 + KST002 + KST003 + KST004 )  .

      SELECT SINGLE KALAB FROM MSKA INTO KALAB WHERE
        VBELN = SO_WA-SO_NUM AND POSNR = SO_WA-POSNR  AND MATNR = SO_WA-MATNR.
      IF SY-SUBRC <> 0 .
        SELECT SINGLE NAME1 FROM KNA1 INTO SO_WA-CUSTOMER_NAME
                    WHERE KUNNR = SO_WA-CUSTOMER_NO.
*//////////////// Start Cost Error ////////////////
        "Begin of Code added by Menna for Support Task "<Task No/T00002507>" ....
        DATA : IT_PRCD_ELEMENTS TYPE TABLE OF PRCD_ELEMENTS WITH HEADER LINE.
        DATA : O_COST TYPE PRCD_ELEMENTS-KWERT.
        FREE: IT_PRCD_ELEMENTS.
        CLEAR: IT_PRCD_ELEMENTS.
        SELECT * FROM PRCD_ELEMENTS
          WHERE KNUMV = @SO_WA-KNUMV
          AND   KPOSN = @SO_WA-POSNR
          AND   KSCHL IN ( 'ZOVC' , 'ZBPC' )
*          AND   ( KSCHL = 'ZOVC' OR KSCHL = '' )
          INTO TABLE @IT_PRCD_ELEMENTS.
        DATA(LV_COLLECT_OVC_BPC) = REDUCE KWERT( INIT SUM TYPE KWERT FOR <FS> IN IT_PRCD_ELEMENTS NEXT SUM += <FS>-KWERT ).

        " this line hashed by hassan 24-05-2026.
*        READ TABLE IT_PRCD_ELEMENTS INDEX 1.
*        O_COST = IT_PRCD_ELEMENTS-KWERT.
*        CLEAR: IT_PRCD_ELEMENTS.

        O_COST = LV_COLLECT_OVC_BPC.
        SO_WA-TOTAL_COST = SO_WA-TOTAL_COST + O_COST.
        CLEAR : O_COST.
        "End of Code added by Menna for Support Task "<Task No/T00002507>" ....
        SO_WA-PROFIT = SO_WA-NET_VALUE - SO_WA-TOTAL_COST.
        CLEAR : COLOR , COLN , COLTAB.
        IF SO_WA-TOTAL_COST = 0 .
          SO_WA-PROFIT_STATUS = 'COST ERROR'.
          "coloring
          COLOR-COL = '6'. "red color
          COLOR-INT = '0'.
          COLOR-INV = '0'.
          COLN-FNAME = 'PROFIT_STATUS'.
          COLN-COLOR = COLOR.
          APPEND COLN TO COLTAB.
          SO_WA-COLOR = COLTAB.
          "end coloring
          SO_WA-AR_APPROVAL ='Not Approved'.
          "coloring
          CLEAR : COLOR , COLN .
          COLOR-COL = '6'. "red color
          COLOR-INT = '0'.
          COLOR-INV = '0'.
          COLN-FNAME = 'AR_APPROVAL'.
          COLN-COLOR = COLOR.
          APPEND COLN TO COLTAB.
          SO_WA-COLOR = COLTAB.
          "end coloring
*///////////////END Cost error////////////////
*///////////////Start Profit Status////////////////
        ELSEIF SO_WA-PROFIT < 0.
          SO_WA-PROFIT_STATUS = 'Loss'.
          "coloring
          COLOR-COL = '6'. "red color
          COLOR-INT = '0'.
          COLOR-INV = '0'.
          COLN-FNAME = 'PROFIT_STATUS'.
          COLN-COLOR = COLOR.
          APPEND COLN TO COLTAB.
          SO_WA-COLOR = COLTAB.
          "end coloring


          SO_WA-AR_APPROVAL = 'Not Approved'.
          "coloring
          CLEAR : COLOR , COLN .
          COLOR-COL = '6'. "red color
          COLOR-INT = '0'.
          COLOR-INV = '0'.
          COLN-FNAME = 'AR_APPROVAL'.
          COLN-COLOR = COLOR.
          APPEND COLN TO COLTAB.
          SO_WA-COLOR = COLTAB.
          "end coloring

        ELSE.
          SO_WA-PROFIT_STATUS = 'Profit'.
          SO_WA-AR_APPROVAL ='Approved'.
        ENDIF.
*///////////////End Profit Status////////////////
*///////////////Start Credit Status////////////////
        SELECT SINGLE CREDIT_LIMIT FROM UKMBP_CMS_SGM
                    INTO SO_WA-CREDIT_LIMIT WHERE PARTNER = SO_WA-CUSTOMER_NO.
        IF SY-SUBRC <> 0.

          SO_WA-CREDIT_STATUS = 'Not related to Credit Managment'.
          "coloring
          CLEAR : COLOR , COLN .
          COLOR-COL = '3'. "Yellow color
          COLOR-INT = '0'.
          COLOR-INV = '0'.
          COLN-FNAME = 'CREDIT_STATUS'.
          COLN-COLOR = COLOR.
          APPEND COLN TO COLTAB.
          SO_WA-COLOR = COLTAB.
          "end coloring
        ELSE.

          CALL FUNCTION 'UKM_COMMTS_BUPA_DISPLAY'
            EXPORTING
              I_PARTNER            = SO_WA-CUSTOMER_NO
              I_SEGMENT            = 'CPXCS'
*             I_DATE               =
*             I_REFRESH            = 'X'
            IMPORTING
              E_COMMITMENTS_AMOUNT = SO_WA-CREDIT_EXP
*             E_AMOUNT_L           =
            .

          IF SO_WA-CREDIT_LIMIT < SO_WA-CREDIT_EXP.
            SO_WA-CREDIT_STATUS = 'Exceed the limit'.
            "coloring
            CLEAR : COLOR , COLN .
            COLOR-COL = '6'. "red color
            COLOR-INT = '0'.
            COLOR-INV = '0'.
            COLN-FNAME = 'CREDIT_STATUS'.
            COLN-COLOR = COLOR.
            APPEND COLN TO COLTAB.
            SO_WA-COLOR = COLTAB.
            "end coloring
            IF SO_WA-AR_APPROVAL ='Approved'.
              SO_WA-AR_APPROVAL ='Not Approved'.
              "coloring
              CLEAR : COLOR , COLN .
              COLOR-COL = '6'. "red color
              COLOR-INT = '0'.
              COLOR-INV = '0'.
              COLN-FNAME = 'AR_APPROVAL'.
              COLN-COLOR = COLOR.
              APPEND COLN TO COLTAB.
              SO_WA-COLOR = COLTAB.
              "end coloring
            ENDIF.
          ELSE.
            SO_WA-CREDIT_STATUS = 'Did not Exceed '.
            FI_APPROVE_IND_CREDIT = 'X'.
          ENDIF.
        ENDIF.

        CLEAR : SD_APPROVE , FI_APPROVE.
        SELECT SINGLE SD_APPROVE FI_APPROVE FROM ZSOAPPROVAL
          INTO (SD_APPROVE , FI_APPROVE) WHERE VBELN = SO_WA-SO_NUM AND POSNR = SO_WA-POSNR.
        IF SY-SUBRC <> 0.

          APPRV_WA-VBELN = SO_WA-SO_NUM.
          APPRV_WA-BUKRS = BUKRS.
          IF SO_WA-AR_APPROVAL ='Approved'  .
            APPRV_WA-FI_APPROVE = 'X'.
          ENDIF.
          SO_WA-SM_APPROVAL ='Not Approved'.
          "coloring
          CLEAR : COLOR , COLN .
          COLOR-COL = '6'. "red color
          COLOR-INT = '0'.
          COLOR-INV = '0'.
          COLN-FNAME = 'SM_APPROVAL'.
          COLN-COLOR = COLOR.
          APPEND COLN TO COLTAB.
          SO_WA-COLOR = COLTAB.
          "end coloring
          APPRV_WA-POSNR = SO_WA-POSNR.
          COUNT = COUNT + 1.
          DATA COUNT1(8) TYPE C.
          MOVE COUNT TO COUNT1.
          CONCATENATE COUNT1 SO_WA-SO_NUM SO_WA-POSNR INTO APPRV_WA-ID.

          MODIFY ZSOAPPROVAL FROM APPRV_WA.
*          APPEND APPRV_WA TO APPRV_TAB.
*          INSERT ZSOAPPROVAL FROM TABLE APPRV_TAB.
*    INSERT LINES OF APPRV_TAB INTO TABLE ZSOAPPROVAL.
*  INSERT ZSOAPPROVAL FROM APPRV_WA.
          CLEAR APPRV_WA.
        ELSE.
          IF SD_APPROVE = 'X'.
            SO_WA-SM_APPROVAL ='Approved'.
          ELSE.
            SO_WA-SM_APPROVAL ='Not Approved'.
            "coloring
            CLEAR : COLOR , COLN .
            COLOR-COL = '6'. "red color
            COLOR-INT = '0'.
            COLOR-INV = '0'.
            COLN-FNAME = 'SM_APPROVAL'.
            COLN-COLOR = COLOR.
            APPEND COLN TO COLTAB.
            SO_WA-COLOR = COLTAB.
            "end coloring
          ENDIF.
          IF FI_APPROVE = 'X'.
            SO_WA-AR_APPROVAL ='Approved'.
          ELSE.
            SO_WA-AR_APPROVAL ='Not Approved'.
            "coloring
            CLEAR : COLOR , COLN .
            COLOR-COL = '6'. "red color
            COLOR-INT = '0'.
            COLOR-INV = '0'.
            COLN-FNAME = 'AR_APPROVAL'.
            COLN-COLOR = COLOR.
            APPEND COLN TO COLTAB.
            SO_WA-COLOR = COLTAB.
            "end coloring
          ENDIF.

        ENDIF.

        DATA: OBJ_NO               TYPE INOB-CUOBJ,
              CONFIGURATION_TAB    TYPE TABLE OF CONF_OUT,
              WA_CONFIGURATION_TAB LIKE LINE OF CONFIGURATION_TAB,
              ZWGHT1               TYPE P DECIMALS 5.
        CLEAR: OBJ_NO, WA_CONFIGURATION_TAB.
        REFRESH: CONFIGURATION_TAB.
*  SELECT SINGLE AUFNR FROM AUFK INTO AUFNR
*    WHERE KDAUF = VBRP-AUBEL.
*  SELECT SINGLE CUOBJ FROM AFPO INTO OBJ_NO
*    WHERE AUFNR = VBAK-VBELN.

        CALL FUNCTION 'VC_I_GET_CONFIGURATION'
          EXPORTING
            INSTANCE            = CUOBJ
          TABLES
            CONFIGURATION       = CONFIGURATION_TAB
          EXCEPTIONS
            INSTANCE_NOT_FOUND  = 1
            INTERNAL_ERROR      = 2
            NO_CLASS_ALLOCATION = 3
            INSTANCE_NOT_VALID  = 4
            OTHERS              = 5.
        LOOP AT CONFIGURATION_TAB INTO WA_CONFIGURATION_TAB WHERE ATNAM = 'ZDESC' .
          SELECT SINGLE EDESCRIPTION FROM YVCOT INTO SO_WA-DC_DESC WHERE CODE = WA_CONFIGURATION_TAB-ATWTB .
          SO_WA-DESIGN_CODE = WA_CONFIGURATION_TAB-ATWTB.
        ENDLOOP.

        APPEND SO_WA TO SO_TAB.
        CLEAR SO_WA.
      ENDIF.
    ENDSELECT.

    SORT SO_TAB DESCENDING BY SO_NUM POSNR.
    DELETE ADJACENT DUPLICATES FROM SO_TAB
    COMPARING SO_NUM POSNR.
    CALL METHOD GRID->REFRESH_TABLE_DISPLAY
      EXPORTING
        I_SOFT_REFRESH = 'X'.
    FLAG = 'X'.

  ENDIF.
ENDFORM.

*----------------------------------------------------------------------*
***INCLUDE YSP_MTOSO_APPROVE_APPROVE_FF01.
*----------------------------------------------------------------------*
*-----------------------------------------------------------------------------*
* Modification history                                                        *
*-----------------------------------------------------------------------------*
* Date        |Request No  |Author             |Description                   *
*-----------------------------------------------------------------------------*
* 17/02/2021  |DE3K919734 |IABAPT [Heba] |SD Support "T00002246/CH1555"       *
* 23/11/2021  |DE3K921092 |IABAPT [Heba] |SD Support "T00002916 /CH1970"      *
* 03/01/2022  |DE3K921378 |IABAPT [Heba] |SD Support "T00003072/IN6038"       *
*-----------------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& Form APPROVE_FUN
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM APPROVE_FUN .
  REFRESH : IT_PROG_ROW_INDEX.
  CALL METHOD GRID->GET_SELECTED_ROWS
    IMPORTING
      ET_INDEX_ROWS = IT_PROG_ROW_INDEX.
  DATA : ZPOSNUM(2) TYPE C.
  LOOP AT IT_PROG_ROW_INDEX INTO WA_PROG_ROW_INDEX.
    READ TABLE SO_TAB INTO SO_WA INDEX WA_PROG_ROW_INDEX-INDEX.

    SELECT SINGLE ZPOSNUM FROM ZAPPROVEUSER INTO ZPOSNUM
                WHERE USER_NAME = SY-UNAME
                AND BUKRS = BUKRS.  "--Added by Heba for Support Task "T00002246/CH1555"

    IF SY-SUBRC = 0.
      IF ZPOSNUM = 'SD'.
        SELECT * FROM ZSOAPPROVAL INTO CORRESPONDING FIELDS OF TABLE APPRV_TAB
                WHERE VBELN = SO_WA-SO_NUM AND POSNR = SO_WA-POSNR.
        IF SY-SUBRC = 0.
          LOOP AT APPRV_TAB INTO APPRV_WA .
            APPRV_WA-SD_APPROVE = 'X'.

*&--Added by Heba for Task 'T00002916 /CH1970'...
            "Set Approval Date and Time
            APPRV_WA-SD_APRV_DATE = SY-DATUM.
            APPRV_WA-SD_APRV_TIME = SY-UZEIT.
*&--End Add...

            MODIFY APPRV_TAB FROM APPRV_WA.
            MODIFY ZSOAPPROVAL FROM APPRV_WA.

*&--Added by Menna for Task 'T00003072/IN6038'...
          COMMIT WORK AND WAIT.
*&--End of edit by Menna for Task 'T00003072/IN6038'...
*&--Added by Heba for Task 'T00003072/IN6038'...
            "Commit the changes in the DB
            CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
              EXPORTING
                WAIT = 'X'.
*&--End Add...


            SD_APPROVE = 'X'.
          ENDLOOP.
        ELSE.

        ENDIF.

      ELSEIF ZPOSNUM = 'FI'.

        SELECT * FROM ZSOAPPROVAL INTO CORRESPONDING FIELDS OF TABLE APPRV_TAB
                 WHERE VBELN = SO_WA-SO_NUM AND POSNR = SO_WA-POSNR.
        LOOP AT APPRV_TAB INTO APPRV_WA .
          APPRV_WA-FI_APPROVE = 'X'.

*&--Added by Heba for Task 'T00002916 /CH1970'...
          "Set Approval Date and Time
          APPRV_WA-FI_APRV_DATE = SY-DATUM.
          APPRV_WA-FI_APRV_TIME = SY-UZEIT.
*&--End Add...

          MODIFY APPRV_TAB FROM APPRV_WA.
          MODIFY ZSOAPPROVAL FROM APPRV_WA.

*&--Added by Menna for Task 'T00003072/IN6038'...
          COMMIT WORK AND WAIT.
*&--End of edit by Menna for Task 'T00003072/IN6038'...
*&--Added by Heba for Task 'T00003072/IN6038'...
          "Commit the changes in the DB
          CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
            EXPORTING
              WAIT = 'X'.
*&--End Add...


          FI_APPROVE = 'X'.
        ENDLOOP.

      ENDIF.
    ELSE.

      MESSAGE 'You are not Authorized to Approve' TYPE 'W'.
*INSERT LOG

      WA_LOG-LOGDATE = SY-DATUM.
      WA_LOG-TIME = SY-UZEIT.
      WA_LOG-USER_NAME = SY-UNAME.
      WA_LOG-EVENT = 'not Authorized'.
      WA_LOG-SO_NUMBER = SO_WA-SO_NUM.
      SELECT COUNT(*) FROM YSP_MTOSO_LOG INTO LOG_COUNT .
      IF LOG_COUNT = 0.
        WA_LOG-LOG_NUMBER = 1.
      ELSE.
        WA_LOG-LOG_NUMBER = LOG_COUNT + 1.
      ENDIF.
      INSERT YSP_MTOSO_LOG FROM  WA_LOG.
      SD_APPROVE = ''.FI_APPROVE = ''.
    ENDIF.
    BREAK MSALAH.
    SELECT SINGLE SD_APPROVE FI_APPROVE FROM ZSOAPPROVAL
      INTO (SD_APPROVE , FI_APPROVE)
    WHERE VBELN = SO_WA-SO_NUM AND POSNR = SO_WA-POSNR.

    IF SD_APPROVE = 'X' AND FI_APPROVE = 'X'.

      DATA : ORDER_HEADER_INX TYPE BAPISDH1X,
             RETURN           TYPE BAPIRET2,
             LT_SCHDL         TYPE TABLE OF BAPISCHDL WITH HEADER LINE,
             LT_RETURN        TYPE TABLE OF BAPIRET2 WITH HEADER LINE,
             LT_SCHDLX        TYPE TABLE OF BAPISCHDLX WITH HEADER LINE.
      ORDER_HEADER_INX-UPDATEFLAG = 'U'.

      SELECT ETENR FROM VBEP INTO ( LT_SCHDL-SCHED_LINE )
        WHERE VBELN = SO_WA-SO_NUM AND POSNR = SO_WA-POSNR AND WMENG > 0.
        LT_SCHDL-ITM_NUMBER = SO_WA-POSNR.
        LT_SCHDL-SCHED_TYPE = 'CP'.
        APPEND LT_SCHDL.
        LT_SCHDLX-ITM_NUMBER =  SO_WA-POSNR .
        LT_SCHDLX-SCHED_LINE = LT_SCHDL-SCHED_LINE.
        LT_SCHDLX-UPDATEFLAG = 'U'.
        LT_SCHDLX-SCHED_TYPE  = 'X'.
        APPEND  LT_SCHDLX.
      ENDSELECT.

      CALL FUNCTION 'BAPI_SALESORDER_CHANGE'  "#EC CI_USAGE_OK[2438131]
        EXPORTING
          SALESDOCUMENT    = SO_WA-SO_NUM
          ORDER_HEADER_INX = ORDER_HEADER_INX
        TABLES
          RETURN           = LT_RETURN
          SCHEDULE_LINES   = LT_SCHDL
          SCHEDULE_LINESX  = LT_SCHDLX.

      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          WAIT   = 'X'
        IMPORTING
          RETURN = RETURN.

      LOOP AT LT_RETURN WHERE ID = 'V1'.
        MESSAGE LT_RETURN-MESSAGE(100) TYPE 'I'.
        WA_LOG-NOTE = LT_RETURN-MESSAGE(100).
      ENDLOOP.
*INSERT LOG

      WA_LOG-LOGDATE = SY-DATUM.
      WA_LOG-TIME = SY-UZEIT.
      WA_LOG-USER_NAME = SY-UNAME.
      WA_LOG-EVENT = 'APPROVAL'.
      WA_LOG-SO_NUMBER = SO_WA-SO_NUM.
      SELECT COUNT(*) FROM YSP_MTOSO_LOG INTO LOG_COUNT .
      IF LOG_COUNT = 0.
        WA_LOG-LOG_NUMBER = 1.
      ELSE.
        WA_LOG-LOG_NUMBER = LOG_COUNT + 1.
      ENDIF.
      INSERT YSP_MTOSO_LOG FROM  WA_LOG.

    ELSE.

    ENDIF.




  ENDLOOP.
  FLAG = ''.
  PERFORM SCREEN_START.
ENDFORM.

*----------------------------------------------------------------------*
***INCLUDE YSP_MTOSO_APPROVE_REJECT_FUF01.
*----------------------------------------------------------------------*
*-----------------------------------------------------------------------------*
* Modification history                                                        *
*-----------------------------------------------------------------------------*
* Date        |Request No  |Author             |Description                   *
*-----------------------------------------------------------------------------*
* 17/02/2021  |DE3K919734 |IABAPT [Heba] |SD Support "T00002246/CH1555"       *
* 11/07/2021  |DE3K920384 |IABAPT [Heba] |SD Support "T00002246/CH1555"       *
*-----------------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form REJECT_FUN
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM REJECT_FUN .
   DATA : SD_APPROVE TYPE C , FI_APPROVE TYPE C , ZPOSNUM(2) TYPE C.
   SELECT SINGLE ZPOSNUM FROM ZAPPROVEUSER INTO ZPOSNUM
            WHERE USER_NAME = SY-UNAME
            AND BUKRS = BUKRS.  "--Added by Heba for Support Task "T00002246/CH1555"

          IF SY-SUBRC = 0.
REFRESH : IT_PROG_ROW_INDEX.
CALL METHOD
      GRID->get_selected_rows
   IMPORTING
      ET_INDEX_ROWS  =  IT_PROG_ROW_INDEX.
 LOOP AT IT_PROG_ROW_INDEX INTO WA_PROG_ROW_INDEX.
   READ TABLE SO_TAB INTO SO_WA INDEX WA_PROG_ROW_INDEX-INDEX.

 DATA : ORDER_HEADER_INX TYPE BAPISDH1X,
        RETURN TYPE BAPIRET2,
        lt_schdl TYPE TABLE OF bapischdl WITH HEADER LINE,
        lt_return TYPE TABLE OF bapiret2 WITH HEADER LINE,
        lt_schdlx TYPE TABLE OF bapischdlx WITH HEADER LINE,
        ORDER_ITEM_IN	TYPE TABLE OF	BAPISDITM WITH HEADER LINE,
        ORDER_ITEM_INX  TYPE TABLE OF BAPISDITMX WITH HEADER LINE.

   ORDER_HEADER_INX-UPDATEFLAG = 'U'.
   ORDER_ITEM_IN-ITM_NUMBER =  SO_WA-POSNR .
    ORDER_ITEM_IN-REASON_REJ = '63'.

  APPEND ORDER_ITEM_IN.
   ORDER_ITEM_INX-ITM_NUMBER =  SO_WA-POSNR .
   ORDER_ITEM_INX-UPDATEFLAG = 'U'.
   ORDER_ITEM_INX-REASON_REJ  = 'X'.
  APPEND  ORDER_ITEM_INX.



  CALL FUNCTION 'BAPI_SALESORDER_CHANGE'  "#EC CI_USAGE_OK[2438131]
       EXPORTING
            salesdocument    = SO_WA-SO_NUM
            order_header_inx = ORDER_HEADER_INX
       TABLES
            return           = lt_return
            ORDER_ITEM_IN    = ORDER_ITEM_IN
            ORDER_ITEM_INX   = ORDER_ITEM_INX.
  .
  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
       EXPORTING
            wait   = 'X'
       IMPORTING
            return = return.

  LOOP AT lt_return.
  MESSAGE lt_return-message(100) TYPE 'I'.
  WA_LOG-NOTE = lt_return-message(100).
  ENDLOOP.

*INSERT LOG

WA_LOG-LOGDATE = SY-DATUM.
WA_LOG-TIME = SY-UZEIT.
WA_LOG-USER_NAME = SY-UNAME.
WA_LOG-EVENT = 'REJECT'.
WA_LOG-SO_NUMBER = SO_WA-SO_NUM.
SELECT COUNT(*) FROM YSP_MTOSO_LOG INTO lOG_COUNT .
  IF LOG_COUNT = 0.
WA_LOG-LOG_NUMBER = 1.
  ELSE.
WA_LOG-LOG_NUMBER = LOG_COUNT + 1.
ENDIF.
INSERT YSP_MTOSO_LOG FROM  WA_LOG.

ENDLOOP.
FLAG = ''.
PERFORM SCREEN_START.
ELSE.
   MESSAGE 'No Authorization For reject this order' TYPE 'I'.
ENDIF.
ENDFORM.

*----------------------------------------------------------------------*
***INCLUDE YSP_MTOSO_APPROVE_STATUS_00O01.
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Module STATUS_0099 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE STATUS_0099 OUTPUT.
  SET PF-STATUS 'YSP_MTOSO_STATUS90'.
  SET TITLEBAR 'YSP_MTOSO_TITLE90'.
ENDMODULE.


*----------------------------------------------------------------------*
***INCLUDE YSP_MTOSO_APPROVE_USER_COMMI02.
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0099  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE USER_COMMAND_0099 INPUT.
  CASE SY-UCOMM.
    WHEN 'EXECUTE'.
      PERFORM EXECUTE.
  ENDCASE.
ENDMODULE.

*----------------------------------------------------------------------*
***INCLUDE YSP_MTOSO_APPROVE_EXECUTEF01.
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form EXECUTE
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*& -->  p1        text
*& <--  p2        text
*&---------------------------------------------------------------------*
FORM EXECUTE .

AUTHORITY-CHECK OBJECT 'M_MSEG_WWA'
   ID 'WERKS' FIELD BUKRS.
    IF SY-SUBRC <> 0.
      MESSAGE 'You Dont have authorization ' type 'I'.
      ELSE.
  call SCREEN '0100'.
     ENDIF.






ENDFORM.