
*&---------------------------------------------------------------------*
*& Module Pool      YSP_MTOSO_APPROVE
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*

INCLUDE YSP_MTOSO_APPROVE_TOP                   .    " Global Data

* INCLUDE YSP_MTOSO_APPROVE_O01                   .  " PBO-Modules
* INCLUDE YSP_MTOSO_APPROVE_I01                   .  " PAI-Modules
* INCLUDE YSP_MTOSO_APPROVE_F01                   .  " FORM-Routines


INCLUDE ysp_mtoso_approve_status_01o01.

INCLUDE ysp_mtoso_approve_user_commi01.

INCLUDE ysp_mtoso_approve_screen_stf01.

INCLUDE ysp_mtoso_approve_approve_ff01.

INCLUDE ysp_mtoso_approve_reject_fuf01.

INCLUDE ysp_mtoso_approve_status_00o01.

INCLUDE ysp_mtoso_approve_user_commi02.

INCLUDE ysp_mtoso_approve_executef01.
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
*& Include YSP_MTOSO_APPROVE_TOP                    - Module Pool      YSP_MTOSO_APPROVE
*&---------------------------------------------------------------------*
PROGRAM YSP_MTOSO_APPROVE.


TABLES : ZSOAPPROVAL.
DATA: LOG_COUNT TYPE INT8.
DATA : SD_APPROVE TYPE C , FI_APPROVE TYPE C, FI_APPROVE_IND_PROFIT TYPE C , FI_APPROVE_IND_CREDIT TYPE C.
DATA: IT_PROG_ROW_INDEX TYPE  LVC_T_ROW,
      WA_PROG_ROW_INDEX LIKE LINE OF IT_PROG_ROW_INDEX,
      FLAG           TYPE C,
      GRID           TYPE REF TO CL_GUI_ALV_GRID,
      CONTAINER      TYPE REF TO CL_GUI_CUSTOM_CONTAINER,
      LW_LAYOUT      TYPE LVC_S_LAYO,
      IT_FIELDCAT    TYPE LVC_T_FCAT,
      WA_FIELDCAT    LIKE LINE OF IT_FIELDCAT,
      LS_EXCLUDE     TYPE UI_FUNC,
      PT_EXCLUDE     TYPE UI_FUNCTIONS,
      LT_ROWS        TYPE LVC_T_ROW,
      CA             LIKE LINE OF LT_ROWS,
      LT_EVENTS      TYPE CNTL_SIMPLE_EVENTS,
      L_EVENT        TYPE CNTL_SIMPLE_EVENT,
      OK_CODE        LIKE SY-UCOMM,
      LS_STABLE      TYPE LVC_S_STBL.

TYPES : BEGIN OF YSP_MTOSO_APPROVE_COL.
        INCLUDE TYPE YSP_MTOSO_APPROVE."#EC CI_USAGE_OK[2383423]
TYPES : COLOR TYPE LVC_T_SCOL.
TYPES : END OF YSP_MTOSO_APPROVE_COL.

*DATA: SO_TAB TYPE STANDARD TABLE OF YSP_MTOSO_APPROVE,
DATA: SO_TAB TYPE STANDARD TABLE OF YSP_MTOSO_APPROVE_COL,
      SO_WA  LIKE LINE OF SO_TAB.

DATA: FROM_DATE LIKE VBAK-AUDAT,
      TO_DATE LIKE VBAK-AUDAT,
      DOC_NUMBER LIKE VBAK-VBELN,
      DATEV_F LIKE VBAK-AUDAT,
      DATEV_T LIKE VBAK-AUDAT.
 TYPES: BEGIN OF SO_STRUCT,
           VBELN TYPE VBELN,
         END OF SO_STRUCT.
  DATA: IT_SO_TEMP TYPE TABLE OF SO_STRUCT,
        WA_SO_TEMP TYPE SO_STRUCT.

DATA: coln TYPE lvc_s_scol,
      coltab TYPE lvc_t_scol,
*      coltab TYPE lvc_s_scol,
      color TYPE lvc_s_colo.

* Double Click
  DATA: G_GRID TYPE REF TO CL_GUI_ALV_GRID.
DATA: L_VALID TYPE C,
      V_FLAG,
      V_DATA_CHANGE,
      V_ROW TYPE LVC_S_ROW,
      V_COLUMN TYPE LVC_S_COL,
      V_ROW_NUM TYPE LVC_S_ROID.
DATA: SAVE_OK LIKE SY-UCOMM,
      G_CONTAINER1 TYPE SCRFNAME VALUE 'TEST',
      GS_LAYOUT TYPE LVC_S_LAYO.

DATA:BEGIN OF  ITAB OCCURS 0,
     VBELN LIKE LIKP-VBELN,
     POSNR LIKE LIPS-POSNR,
     COMISN(10),
     BOX(1),
     CELLCOLOR TYPE LVC_T_SCOL, "required for color
     DROP(20),
     HANDLE_STYLE TYPE LVC_T_STYL,
     END OF ITAB.

DATA : APPRV_TAB TYPE STANDARD TABLE OF ZSOAPPROVAL,
      APPRV_WA TYPE ZSOAPPROVAL.
DATA :   TA_LOG  TYPE STANDARD TABLE OF YSP_MTOSO_LOG,
      WA_LOG TYPE YSP_MTOSO_LOG.
DATA : BUKRS TYPE VBAK-BUKRS_VF,BUKRS1 TYPE VBAK-BUKRS_VF.
DATA : ORDER_HEADER_INX TYPE BAPISDH1X,
             RETURN           TYPE BAPIRET2,
             LT_SCHDL         TYPE TABLE OF BAPISCHDL WITH HEADER LINE,
             LT_RETURN        TYPE TABLE OF BAPIRET2 WITH HEADER LINE,
             LT_SCHDLX        TYPE TABLE OF BAPISCHDLX WITH HEADER LINE.

*----------------------------------------------------------------------*
***INCLUDE YSP_MTOSO_APPROVE_STATUS_01O01.
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Module STATUS_0100 OUTPUT
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
MODULE status_0100 OUTPUT.
  SET PF-STATUS 'YSP_MTOSO_STATUS1'.
  SET TITLEBAR 'YSP_MTOSO_TITLE'.

  IF container IS INITIAL.

    CREATE OBJECT container
      EXPORTING
        container_name = 'CONTROLLER1'.

    CREATE OBJECT grid
      EXPORTING
        i_parent = container.

    CALL METHOD grid->register_edit_event
      EXPORTING
        i_event_id = cl_gui_alv_grid=>mc_evt_modified
      EXCEPTIONS
        error      = 1
        OTHERS     = 2.

*    CREATE OBJECT EVENT_RECEIVER.
*
*    SET HANDLER EVENT_RECEIVER->HANDLE_DOUBLE_CLICK FOR GRID.

*    SET HANDLER  EVENT_RECEIVER->

    REFRESH it_fieldcat.

    wa_fieldcat-fieldname = 'DOC_TYPE'.
    wa_fieldcat-coltext = 'Document Type'.
    wa_fieldcat-outputlen = 12.
    wa_fieldcat-emphasize = 'C511'.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'SO_NUM'.
    wa_fieldcat-coltext = 'Sales order'.
    wa_fieldcat-outputlen = 10.
    wa_fieldcat-hotspot = 'X'.

    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'CUSTOMER_NO'.
    wa_fieldcat-coltext = 'Customer No'.
    wa_fieldcat-outputlen = 10.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'CUSTOMER_NAME'.
    wa_fieldcat-coltext = 'Customer Name'.
    wa_fieldcat-outputlen = 10.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'MATNR'.
    wa_fieldcat-coltext = 'Material'.
    wa_fieldcat-outputlen = 8.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'DESIGN_CODE'.
    wa_fieldcat-coltext = 'Design Code'.
    wa_fieldcat-outputlen = 8.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'DC_DESC'.
    wa_fieldcat-coltext = 'Design Desc.'.
    wa_fieldcat-outputlen = 8.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'Posnr'.
    wa_fieldcat-coltext = 'ITEM'.
    wa_fieldcat-outputlen = 8.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'DOC_DATE'.
    wa_fieldcat-coltext = 'Date'.
    wa_fieldcat-outputlen = 8.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'SALES_OFF'.
    wa_fieldcat-coltext = 'Sales Office'.
    wa_fieldcat-outputlen = 4.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'DELV_DATE'.
    wa_fieldcat-coltext = 'Delivery Date'.
    wa_fieldcat-outputlen = 8.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'NET_VALUE'.
    wa_fieldcat-coltext = 'Net Value'.
    wa_fieldcat-outputlen = 10.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'TOTAL_COST'.
    wa_fieldcat-coltext = 'TOTAL COST'.
    wa_fieldcat-outputlen = 10.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PROFIT'.
    wa_fieldcat-coltext = 'Profit'.
    wa_fieldcat-outputlen = 10.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PROFIT_STATUS'.
    wa_fieldcat-coltext = 'Profit Status'.
    wa_fieldcat-outputlen = 15.
    wa_fieldcat-emphasize = 'C511'.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'CREDIT_LIMIT'.
    wa_fieldcat-coltext = 'Credit Limit'.
    wa_fieldcat-outputlen = 13.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'CREDIT_EXP'.
    wa_fieldcat-coltext = 'Credit Exposure'.
    wa_fieldcat-outputlen = 13.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'CREDIT_STATUS'.
    wa_fieldcat-coltext = 'Credit Status'.
    wa_fieldcat-outputlen = 20.
    wa_fieldcat-emphasize = 'C511'.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    "added by hager mohsen T00004846 29.09.2024

    wa_fieldcat-fieldname = 'PAYTERM_CODE'.
    wa_fieldcat-coltext = 'Payement Term Code'.
    wa_fieldcat-outputlen = 4.
*        WA_FIELDCAT-EMPHASIZE = 'C511'.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PAYTERM_DESC'.
    wa_fieldcat-coltext = 'Payement Term Description'.
    wa_fieldcat-outputlen = 30.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'HEADER_NETWR'.
    wa_fieldcat-coltext = 'Net Value For Order'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'NET_WEIGHT'.
    wa_fieldcat-coltext = 'Net Weight'.
    wa_fieldcat-outputlen = 15.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'GROSS_WEIGHT'.
    wa_fieldcat-coltext = 'Total Item Weight MT'.
    wa_fieldcat-outputlen = 15.
    wa_fieldcat-decimals = 2.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'ORDER_QUAN'.
    wa_fieldcat-coltext = 'Order Quantity'.
    wa_fieldcat-outputlen = 15.
     wa_fieldcat-decimals = 2.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'SALES_UNIT'.
    wa_fieldcat-coltext = 'Sales Unit'.
    wa_fieldcat-outputlen = 3.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'WEIGHT_UNIT'.
    wa_fieldcat-coltext = 'Weight Unit'.
    wa_fieldcat-outputlen = 3.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'SUBTOTAL1'.
    wa_fieldcat-coltext = 'Subtotal1'.
    wa_fieldcat-outputlen = 15.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'SUBTOTAL2'.
    wa_fieldcat-coltext = 'Subtotal2'.
    wa_fieldcat-outputlen = 15.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'SUBTOTAL3'.
    wa_fieldcat-coltext = 'Subtotal3'.
    wa_fieldcat-outputlen = 15.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'SUBTOTAL4'.
    wa_fieldcat-coltext = 'Subtotal4'.
    wa_fieldcat-outputlen = 15.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PIPE_DIAMETER'.
    wa_fieldcat-coltext = 'Pipe Diameter'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PIPE_THICKNESS'.
    wa_fieldcat-coltext = 'Pipe Thickness'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PIPE_LENGTH'.
    wa_fieldcat-coltext = 'Pipe Length "Meter"'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PIPE_COMPOUND'.
    wa_fieldcat-coltext = 'Pipe Compound'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'ONE_METER_WEIGHT'.
    wa_fieldcat-coltext = 'One Meter Weight "KG"'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PIPE_SOCKET'.
    wa_fieldcat-coltext = 'Pipe Socket Type'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PC_WEIGHT'.
    wa_fieldcat-coltext = 'Pc Weight "KG"'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PIPE_STANDARD'.
    wa_fieldcat-coltext = 'Pipe Standard Type'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    "added  by hager mohsen 27.11.2024 Suppor Task T00004846
    wa_fieldcat-fieldname = 'PAPER_TYPE1'.
    wa_fieldcat-coltext = 'Paper Type 1'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PAPER_GRADE1'.
    wa_fieldcat-coltext = 'Paper Grade GSM1'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PAPER_TYPE2'.
    wa_fieldcat-coltext = 'Paper Type 2'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PAPER_GRADE2'.
    wa_fieldcat-coltext = 'Paper Grade GSM2'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PAPER_TYPE3'.
    wa_fieldcat-coltext = 'Paper Type 3'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PAPER_GRADE3'.
    wa_fieldcat-coltext = 'Paper Grade GSM3'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PAPER_TYPE4'.
    wa_fieldcat-coltext = 'Paper Type 4'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PAPER_GRADE4'.
    wa_fieldcat-coltext = 'Paper Grade GSM4'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PAPER_TYPE5'.
    wa_fieldcat-coltext = 'Paper Type 5'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PAPER_GRADE5'.
    wa_fieldcat-coltext = 'Paper Grade GSM5'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PAPER_TYPE6'.
    wa_fieldcat-coltext = 'Paper Type 6'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PAPER_GRADE6'.
    wa_fieldcat-coltext = 'Paper Grade GSM6'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PAPER_TYPE7'.
    wa_fieldcat-coltext = 'Paper Type 7'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'PAPER_GRADE7'.
    wa_fieldcat-coltext = 'Paper Grade GSM7'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

     wa_fieldcat-fieldname = 'GSM_TOTAL'.
    wa_fieldcat-coltext = 'BOARD TOTAL GSM SALES'.
    wa_fieldcat-outputlen = 25.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.
    "end added

    wa_fieldcat-fieldname = 'PRICE_PER_WEIGHT'.
    wa_fieldcat-coltext = 'Price per MT'.
    wa_fieldcat-outputlen = 20.
    wa_fieldcat-decimals = 2.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

     wa_fieldcat-fieldname = 'PROFIT_ITEM'.
    wa_fieldcat-coltext = 'Gross Margine %'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

     wa_fieldcat-fieldname = 'OVER_DUE'.
    wa_fieldcat-coltext = 'Over Due'.
    wa_fieldcat-outputlen = 20.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.
    "end added.

    wa_fieldcat-fieldname = 'SM_APPROVAL'.
    wa_fieldcat-coltext = 'Sales Approval'.
    wa_fieldcat-outputlen = 12.
    wa_fieldcat-emphasize = 'C511'.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.

    wa_fieldcat-fieldname = 'AR_APPROVAL'.
    wa_fieldcat-coltext = 'FI Approval'.
    wa_fieldcat-outputlen = 12.
    wa_fieldcat-emphasize = 'C511'.
*    WA_FIELDCAT-EDIT = 'X'.
**    WA_FIELDCAT-NO_ZERO = 'X'.
    APPEND wa_fieldcat TO it_fieldcat.
    CLEAR wa_fieldcat.




    CLEAR pt_exclude.
    ls_exclude = cl_gui_alv_grid=>mc_fc_graph .
    APPEND ls_exclude TO pt_exclude.
    ls_exclude = cl_gui_alv_grid=>mc_fc_info .
    APPEND ls_exclude TO pt_exclude.
    ls_exclude = cl_gui_alv_grid=>mc_fc_print .
    APPEND ls_exclude TO pt_exclude.
    ls_exclude = cl_gui_alv_grid=>mc_fc_views .
    APPEND ls_exclude TO pt_exclude.
    ls_exclude = cl_gui_alv_grid=>mc_fc_detail.
    APPEND ls_exclude TO pt_exclude.
    ls_exclude = cl_gui_alv_grid=>mc_fc_refresh.
    APPEND ls_exclude TO pt_exclude.
*    LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_MB_EXPORT .
*    APPEND LS_EXCLUDE TO PT_EXCLUDE.
    ls_exclude = cl_gui_alv_grid=>mc_fc_check .
    APPEND ls_exclude TO pt_exclude.
*    LS_EXCLUDE = CL_GUI_ALV_GRID=>MC_MB_SUM.
*    APPEND LS_EXCLUDE TO PT_EXCLUDE.
    ls_exclude = cl_gui_alv_grid=>mc_fc_subtot.
    APPEND ls_exclude TO pt_exclude.
    ls_exclude = cl_gui_alv_grid=>mc_fc_loc_append_row.
    APPEND ls_exclude TO pt_exclude.
    ls_exclude = cl_gui_alv_grid=>mc_fc_loc_copy.
    APPEND ls_exclude TO pt_exclude.
    ls_exclude = cl_gui_alv_grid=>mc_fc_loc_copy_row.
    APPEND ls_exclude TO pt_exclude.
    ls_exclude = cl_gui_alv_grid=>mc_fc_loc_cut.
    APPEND ls_exclude TO pt_exclude.
    ls_exclude = cl_gui_alv_grid=>mc_fc_loc_delete_row.
    APPEND ls_exclude TO pt_exclude.
    ls_exclude = cl_gui_alv_grid=>mc_fc_loc_insert_row.
    APPEND ls_exclude TO pt_exclude.
    ls_exclude = cl_gui_alv_grid=>mc_fc_loc_move_row.
    APPEND ls_exclude TO pt_exclude.
    ls_exclude = cl_gui_alv_grid=>mc_fc_loc_paste.
    APPEND ls_exclude TO pt_exclude.
    ls_exclude = cl_gui_alv_grid=>mc_fc_loc_paste_new_row.
    APPEND ls_exclude TO pt_exclude.
    ls_exclude = cl_gui_alv_grid=>mc_fc_loc_undo.
    APPEND ls_exclude TO pt_exclude.
    lw_layout-grid_title = 'Sales order Not Approved'.
    lw_layout-stylefname = 'CELLTAB'.
*    LW_LAYOUT-CWIDTH_OPT  = 'X'.
    " BUILD ALV
    DATA:  ls_variant TYPE disvariant.
    ls_variant = sy-repid.
    lw_layout-ctab_fname = 'COLOR'.
    CALL METHOD grid->set_table_for_first_display
      EXPORTING
        i_structure_name     = 'YSP_MTOSO_APPROVE'
        is_layout            = lw_layout
        it_toolbar_excluding = pt_exclude
        i_save               = 'A'
        is_variant           = ls_variant
      CHANGING
        it_outtab            = so_tab
        it_fieldcatalog      = it_fieldcat.

  ELSE.
    ls_stable-row = 'X'.
    ls_stable-col = 'X'.
    CALL METHOD grid->refresh_table_display
      EXPORTING
        is_stable = ls_stable
      EXCEPTIONS
        finished  = 1
        OTHERS    = 2.
    IF sy-subrc <> 0.
    ENDIF.
  ENDIF.
  PERFORM screen_start.
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
FORM screen_start .
  IF flag <> 'X' .
    CLEAR : so_wa , so_tab .
    BREAK msalah.
    DATA : wavwr TYPE vbap-wavwr, cuobj TYPE vbap-cuobj,
           pstyv TYPE vbap-pstyv,  kalab TYPE mska-kalab, count TYPE int8.

    IF bukrs = 1200 OR bukrs = 1202.
      pstyv = 'ZTAW'.
    ELSEIF bukrs = 1500 OR bukrs = 1501.
      pstyv = 'ZTAC'.
    ENDIF.
    count = 0.

    SELECT vbak~vbeln vbap~matnr vbap~posnr vbap~netwr vbap~wavwr vbak~kunnr vbak~audat vbak~vdatu
    vbap~cuobj vbak~vkbur vbak~auart vbak~knumv
      "added by hager mohsen 29.09.2024 Support Task T00004846
      vbak~netwr  brgew kwmeng ntgew kwmeng vbap~vrkme gewei kzwi1 kzwi2 kzwi3 kzwi4 netpr
      FROM vbap
     INNER JOIN vbak ON vbak~vbeln = vbap~vbeln
     INNER JOIN vbep ON vbep~vbeln = vbap~vbeln AND vbep~posnr = vbap~posnr
     INTO (so_wa-so_num , so_wa-matnr , so_wa-posnr , so_wa-net_value , so_wa-total_cost
     , so_wa-customer_no , so_wa-doc_date , so_wa-delv_date , cuobj , so_wa-sales_off , so_wa-doc_type ,so_wa-knumv
       "added by hager mohsen 29.09.2024 Support Task T00004846
      , so_wa-header_netwr , so_wa-gross_weight , so_wa-order_quan, so_wa-net_weight,
      so_wa-order_quan, so_wa-sales_unit, so_wa-weight_unit, so_wa-subtotal1, so_wa-subtotal2, so_wa-subtotal3, so_wa-subtotal4, so_wa-netpr)
        WHERE ( vbap~pstyv = pstyv OR vbap~pstyv = 'ZFRE' ) AND vbep~ettyp = 'CN' AND vbap~werks = bukrs
     AND ( ABGRU = '' or ABGRU = 'Z8' ) AND  ( vbak~vbtyp = 'C' OR vbak~vbtyp = 'I' )
     AND vbak~audat >= datev_f AND vbak~audat <= datev_t.
"vbap~absta <> 'C'

"commented by support task T00004982 24.11.2024
*      SELECT SINGLE kalab FROM mska INTO kalab WHERE
*        vbeln = so_wa-so_num AND posnr = so_wa-posnr.
*      IF sy-subrc <> 0 .
        SELECT SINGLE name1 FROM kna1 INTO so_wa-customer_name
                    WHERE kunnr = so_wa-customer_no.
*//////////////// Start Cost Error ////////////////
        "Begin of Code added by Menna for Support Task "<Task No/T00002507>" ....
        DATA : it_prcd_elements TYPE TABLE OF prcd_elements WITH HEADER LINE.
        DATA : o_cost TYPE prcd_elements-kwert.
        FREE: it_prcd_elements.
        CLEAR: it_prcd_elements.
        SELECT * FROM prcd_elements
          WHERE knumv = @so_wa-knumv
          AND   kposn = @so_wa-posnr
          AND   KSCHL IN ( 'ZBPC' , 'ZOVC' )
*          AND   kschl = 'ZOVC'
          INTO TABLE @it_prcd_elements.

           DATA(LV_COLLECT_OVC_BPC) = REDUCE KWERT( INIT SUM TYPE KWERT FOR <FS> IN IT_PRCD_ELEMENTS NEXT SUM += <FS>-KWERT ).

          " this lines hashed by hassan diab 24-05-2026 .
*        READ TABLE it_prcd_elements INDEX 1.
*        o_cost = it_prcd_elements-kwert.

        CLEAR: it_prcd_elements.
        O_COST = LV_COLLECT_OVC_BPC.
        so_wa-total_cost = so_wa-total_cost + o_cost.
        CLEAR : o_cost.
        "End of Code added by Menna for Support Task "<Task No/T00002507>" ....
        so_wa-profit = so_wa-net_value - so_wa-total_cost.
        CLEAR : color , coln , coltab.
        IF so_wa-total_cost = 0 .
          so_wa-profit_status = 'COST ERROR'.
          "coloring
          color-col = '6'. "red color
          color-int = '0'.
          color-inv = '0'.
          coln-fname = 'PROFIT_STATUS'.
          coln-color = color.
          APPEND coln TO coltab.
          so_wa-color = coltab.
          "end coloring
          so_wa-ar_approval ='Not Approved'.
          "coloring
          CLEAR : color , coln .
          color-col = '6'. "red color
          color-int = '0'.
          color-inv = '0'.
          coln-fname = 'AR_APPROVAL'.
          coln-color = color.
          APPEND coln TO coltab.
          so_wa-color = coltab.
          "end coloring
*///////////////END Cost error////////////////
*///////////////Start Profit Status////////////////
        ELSEIF so_wa-profit < 0.
          so_wa-profit_status = 'Loss'.
          "coloring
          color-col = '6'. "red color
          color-int = '0'.
          color-inv = '0'.
          coln-fname = 'PROFIT_STATUS'.
          coln-color = color.
          APPEND coln TO coltab.
          so_wa-color = coltab.
          "end coloring


          so_wa-ar_approval = 'Not Approved'.
          "coloring
          CLEAR : color , coln .
          color-col = '6'. "red color
          color-int = '0'.
          color-inv = '0'.
          coln-fname = 'AR_APPROVAL'.
          coln-color = color.
          APPEND coln TO coltab.
          so_wa-color = coltab.
          "end coloring

        ELSE.
          so_wa-profit_status = 'Profit'.
          so_wa-ar_approval ='Approved'.
        ENDIF.
*///////////////End Profit Status////////////////
*///////////////Start Credit Status////////////////
        SELECT SINGLE credit_limit FROM ukmbp_cms_sgm
                    INTO so_wa-credit_limit WHERE partner = so_wa-customer_no.
        IF sy-subrc <> 0.

          so_wa-credit_status = 'Not related to Credit Managment'.
          "coloring
          CLEAR : color , coln .
          color-col = '3'. "Yellow color
          color-int = '0'.
          color-inv = '0'.
          coln-fname = 'CREDIT_STATUS'.
          coln-color = color.
          APPEND coln TO coltab.
          so_wa-color = coltab.
          "end coloring
        ELSE.

          CALL FUNCTION 'UKM_COMMTS_BUPA_DISPLAY'
            EXPORTING
              i_partner            = so_wa-customer_no
              i_segment            = 'WFICS'
*             I_DATE               =
*             I_REFRESH            = 'X'
            IMPORTING
              e_commitments_amount = so_wa-credit_exp
*             E_AMOUNT_L           =
            .

          IF so_wa-credit_limit < so_wa-credit_exp.
            so_wa-credit_status = 'Exceed the limit'.
            "coloring
            CLEAR : color , coln .
            color-col = '6'. "red color
            color-int = '0'.
            color-inv = '0'.
            coln-fname = 'CREDIT_STATUS'.
            coln-color = color.
            APPEND coln TO coltab.
            so_wa-color = coltab.
            "end coloring
            IF so_wa-ar_approval ='Approved'.
              so_wa-ar_approval ='Not Approved'.
              "coloring
              CLEAR : color , coln .
              color-col = '6'. "red color
              color-int = '0'.
              color-inv = '0'.
              coln-fname = 'AR_APPROVAL'.
              coln-color = color.
              APPEND coln TO coltab.
              so_wa-color = coltab.
              "end coloring
            ENDIF.
          ELSE.
            so_wa-credit_status = 'Did not Exceed '.
            fi_approve_ind_credit = 'X'.
          ENDIF.
        ENDIF.

        CLEAR : sd_approve , fi_approve.
        SELECT SINGLE sd_approve fi_approve FROM zsoapproval
          INTO (sd_approve , fi_approve) WHERE vbeln = so_wa-so_num AND posnr = so_wa-posnr.
        IF sy-subrc <> 0.

          apprv_wa-vbeln = so_wa-so_num.
          apprv_wa-bukrs = bukrs.
          IF so_wa-ar_approval ='Approved'  .
            apprv_wa-fi_approve = 'X'.
          ENDIF.
          so_wa-sm_approval ='Not Approved'.
          "coloring
          CLEAR : color , coln .
          color-col = '6'. "red color
          color-int = '0'.
          color-inv = '0'.
          coln-fname = 'SM_APPROVAL'.
          coln-color = color.
          APPEND coln TO coltab.
          so_wa-color = coltab.
          "end coloring
          apprv_wa-posnr = so_wa-posnr.
          count = count + 1.
          DATA count1(8) TYPE c.
          MOVE count TO count1.
          CONCATENATE count1 so_wa-so_num so_wa-posnr INTO apprv_wa-id.

          MODIFY zsoapproval FROM apprv_wa.
*          APPEND APPRV_WA TO APPRV_TAB.
*          INSERT ZSOAPPROVAL FROM TABLE APPRV_TAB.
*    INSERT LINES OF APPRV_TAB INTO TABLE ZSOAPPROVAL.
*  INSERT ZSOAPPROVAL FROM APPRV_WA.
          CLEAR apprv_wa.
        ELSE.
          IF sd_approve = 'X'.
            so_wa-sm_approval ='Approved'.
          ELSE.
            so_wa-sm_approval ='Not Approved'.
            "coloring
            CLEAR : color , coln .
            color-col = '6'. "red color
            color-int = '0'.
            color-inv = '0'.
            coln-fname = 'SM_APPROVAL'.
            coln-color = color.
            APPEND coln TO coltab.
            so_wa-color = coltab.
            "end coloring
          ENDIF.
          IF fi_approve = 'X'.
            so_wa-ar_approval ='Approved'.
          ELSE.
            so_wa-ar_approval ='Not Approved'.
            "coloring
            CLEAR : color , coln .
            color-col = '6'. "red color
            color-int = '0'.
            color-inv = '0'.
            coln-fname = 'AR_APPROVAL'.
            coln-color = color.
            APPEND coln TO coltab.
            so_wa-color = coltab.
            "end coloring
          ENDIF.

        ENDIF.

        DATA: obj_no               TYPE inob-cuobj,
              configuration_tab    TYPE TABLE OF conf_out,
              wa_configuration_tab LIKE LINE OF configuration_tab,
              zwght1               TYPE p DECIMALS 5.
        CLEAR: obj_no, wa_configuration_tab.
        REFRESH: configuration_tab.
*  SELECT SINGLE AUFNR FROM AUFK INTO AUFNR
*    WHERE KDAUF = VBRP-AUBEL.
*  SELECT SINGLE CUOBJ FROM AFPO INTO OBJ_NO
*    WHERE AUFNR = VBAK-VBELN.

        CALL FUNCTION 'VC_I_GET_CONFIGURATION'
          EXPORTING
            instance            = cuobj
          TABLES
            configuration       = configuration_tab
          EXCEPTIONS
            instance_not_found  = 1
            internal_error      = 2
            no_class_allocation = 3
            instance_not_valid  = 4
            OTHERS              = 5.
        "MODIFIED by hager mohsen 29.09.2024 Support Task T00004846
        LOOP AT configuration_tab INTO wa_configuration_tab.

          IF wa_configuration_tab-atnam = 'ZDESC' .
            SELECT SINGLE edescription FROM yvcot INTO so_wa-dc_desc WHERE code = wa_configuration_tab-atwtb .
            so_wa-design_code = wa_configuration_tab-atwtb.
          ENDIF.
          "added by hager mohsen 29.09.2024 Support Task T00004846
          IF wa_configuration_tab-atnam = 'ZP_DIA_RST' .
            so_wa-pipe_diameter = wa_configuration_tab-atwtb.
          ENDIF.

          IF wa_configuration_tab-atnam = 'ZP_THK_RST' .
            so_wa-pipe_thickness = wa_configuration_tab-atwtb.
          ENDIF.

          IF wa_configuration_tab-atnam = 'ZP_LEN' .
            so_wa-pipe_length = wa_configuration_tab-atwtb.
          ENDIF.

          IF wa_configuration_tab-atnam = 'ZP_CMP_RST' .
            so_wa-pipe_compound = wa_configuration_tab-atwtb.
          ENDIF.

          IF wa_configuration_tab-atnam = 'ZP_1MWT' .
            so_wa-one_meter_weight = wa_configuration_tab-atwtb.
          ENDIF.

          IF wa_configuration_tab-atnam = 'ZP_SKT_RST' .
            so_wa-pipe_socket = wa_configuration_tab-atwtb.
          ENDIF.

          IF wa_configuration_tab-atnam = 'ZP_PCWT' .
            so_wa-pc_weight = wa_configuration_tab-atwtb.
          ENDIF.

          IF wa_configuration_tab-atnam = 'ZP_TYP_RST' .
            so_wa-pipe_standard = wa_configuration_tab-atwtb.
          ENDIF.

          " added by hager mohsen 27.11.2024 support Task T00004846
          "added by hager mohsen 29.09.2024 Support Task T00004846
          IF wa_configuration_tab-atnam = 'YPAP_TYPE1' .
            so_wa-paper_type1 = wa_configuration_tab-atwtb.
          ENDIF.

           IF wa_configuration_tab-atnam = 'YPAP_GSM1' .
            so_wa-paper_grade1 = wa_configuration_tab-atwtb.
          ENDIF.

          IF wa_configuration_tab-atnam = 'YPAP_TYPE2' .
            so_wa-paper_type2 = wa_configuration_tab-atwtb.
          ENDIF.

           IF wa_configuration_tab-atnam = 'YPAP_GSM2' .
            so_wa-paper_grade2 = wa_configuration_tab-atwtb.
          ENDIF.

          IF wa_configuration_tab-atnam = 'YPAP_TYPE3' .
            so_wa-paper_type3 = wa_configuration_tab-atwtb.
          ENDIF.

           IF wa_configuration_tab-atnam = 'YPAP_GSM3' .
            so_wa-paper_grade3 = wa_configuration_tab-atwtb.
          ENDIF.

          IF wa_configuration_tab-atnam = 'YPAP_TYPE4' .
            so_wa-paper_type4 = wa_configuration_tab-atwtb.
          ENDIF.

           IF wa_configuration_tab-atnam = 'YPAP_GSM4' .
            so_wa-paper_grade4 = wa_configuration_tab-atwtb.
          ENDIF.

          IF wa_configuration_tab-atnam = 'YPAP_TYPE5' .
            so_wa-paper_type5 = wa_configuration_tab-atwtb.
          ENDIF.

           IF wa_configuration_tab-atnam = 'YPAP_GSM5' .
            so_wa-paper_grade5 = wa_configuration_tab-atwtb.
          ENDIF.

          IF wa_configuration_tab-atnam = 'YPAP_TYPE6' .
            so_wa-paper_type6 = wa_configuration_tab-atwtb.
          ENDIF.

           IF wa_configuration_tab-atnam = 'YPAP_GSM6' .
            so_wa-paper_grade6 = wa_configuration_tab-atwtb.
          ENDIF.

          IF wa_configuration_tab-atnam = 'YPAP_TYPE7' .
            so_wa-paper_type7 = wa_configuration_tab-atwtb.
          ENDIF.

           IF wa_configuration_tab-atnam = 'YPAP_GSM7' .
            so_wa-paper_grade7 = wa_configuration_tab-atwtb.
          ENDIF.

           IF wa_configuration_tab-atnam = 'YBRD_GSM_SLS' .
            so_wa-GSM_TOTAL = wa_configuration_tab-atwtb.
          ENDIF.
        ENDLOOP.
        " added by hager mohsen SD Support Task T00004846 03.10.2024
        if so_wa-net_weight ne 0.
*        so_wa-price_per_weight = ( so_wa-net_value / so_wa-net_weight ) * 1000 .
        so_wa-price_per_weight = ( so_wa-netpr / so_wa-net_weight ).
        endif.
        if so_wa-order_quan ne 0 and so_wa-net_value ne 0.
        so_wa-PROFIT_ITEM =  ( ( ( so_wa-net_value / so_Wa-order_quan ) - ( so_wa-total_cost / so_wa-order_quan ) ) / ( so_wa-net_value / so_Wa-order_quan ) ) * 100.
        endif.
*        DATA: lineitems    LIKE bapi3007_2 OCCURS 0,
*              wa_lineitems LIKE LINE OF lineitems,
*              zbd1t        TYPE bsid-zbd1t,
*              zbd2t        TYPE bsid-zbd2t,
*              zbd3t        TYPE bsid-zbd3t,
*              madat        TYPE bsid-madat,
*              zdue         TYPE bsid-madat,
*              no_days      TYPE p.
*
*        CALL FUNCTION 'BAPI_AR_ACC_GETOPENITEMS'
*          EXPORTING
*            companycode = bukrs
*            customer    = so_wa-customer_no
*            keydate     = to_date
*          TABLES
*            lineitems   = lineitems.
*        LOOP AT lineitems INTO wa_lineitems.
*          CLEAR: zbd1t, zbd2t, zbd3t, madat.
*          CALL FUNCTION 'FI_TERMS_OF_PAYMENT_PROPOSE'
*            EXPORTING
*              i_bldat         = wa_lineitems-doc_date
*              i_budat         = wa_lineitems-pstng_date
*              i_zfbdt         = wa_lineitems-pstng_date
*              i_zterm         = wa_lineitems-pmnttrms
*              i_bukrs         = wa_lineitems-comp_code
*            IMPORTING
*              e_zbd1t         = zbd1t
*              e_zbd2t         = zbd2t
*              e_zbd3t         = zbd3t
*            EXCEPTIONS
*              terms_not_found = 1
*              OTHERS          = 2.
*
*          CALL FUNCTION 'J_1B_FI_NETDUE'
*            EXPORTING
*              zfbdt   = wa_lineitems-bline_date
*              zbd1t   = zbd1t
*              zbd2t   = zbd2t
*              zbd3t   = zbd3t
*            IMPORTING
*              duedate = madat.
           data : over_due_h type bsid-dmbtr,
                  over_due_s type bsid-dmbtr.

           Select sum( dmbtr ) from bsid into over_due_h where shkzg = 'H' and kunnr = so_wa-customer_no and umskz ne 'A'.
           Select sum( dmbtr ) from bsid into over_due_s where shkzg = 'S' and kunnr = so_wa-customer_no and umskz ne 'A'.
           so_wa-over_due = over_due_s - over_due_h.
           clear: over_due_s , over_due_h.

           select single zterm from vbkd into so_Wa-payterm_code where VBELN = so_wa-so_num.
           select single VTEXT from tvzbt into so_Wa-payterm_desc where zterm = so_Wa-payterm_code and spras = 'E'.
**          no_days = to_date - madat.
**          IF no_days >= 1 AND wa_lineitems-sp_gl_ind NE 'A'..
*            so_wa-over_due = so_wa-over_due + wa_lineitems-lc_amount.

*          ENDIF.
*          CLEAR wa_lineitems.
*        ENDLOOP.
        APPEND so_wa TO so_tab.
        CLEAR so_wa.
*        REFRESH lineitems.

*      ENDIF.
    ENDSELECT.

    SORT so_tab DESCENDING BY so_num posnr.
    DELETE ADJACENT DUPLICATES FROM so_tab
    COMPARING so_num posnr.
    CALL METHOD grid->refresh_table_display
      EXPORTING
        i_soft_refresh = 'X'.
    flag = 'X'.

" added by hager mohsen 24.12.2024 SD Support Task T00005055
LOOP AT so_tab into so_wa where ar_approval = 'Not Approved'.
 DATA : ORDER_HEADER_INX TYPE BAPISDH1X,
        RETURN TYPE BAPIRET2,
        lt_schdl TYPE TABLE OF bapischdl WITH HEADER LINE,
        lt_return TYPE TABLE OF bapiret2 WITH HEADER LINE,
        lt_schdlx TYPE TABLE OF bapischdlx WITH HEADER LINE,
        ORDER_ITEM_IN	TYPE TABLE OF	BAPISDITM WITH HEADER LINE,
        ORDER_ITEM_INX  TYPE TABLE OF BAPISDITMX WITH HEADER LINE.

   ORDER_HEADER_INX-UPDATEFLAG = 'U'.
   ORDER_ITEM_IN-ITM_NUMBER =  SO_WA-POSNR .
    ORDER_ITEM_IN-REASON_REJ = 'Z8'.

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

ENDLOOP.

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
* 23/11/2021  |DE3K921092 |IABAPT [Heba] |SD Support "T00002916/CH1970"       *
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
 DATA : ORDER_HEADER_INX TYPE BAPISDH1X,
        RETURN TYPE BAPIRET2,
        lt_schdl TYPE TABLE OF bapischdl WITH HEADER LINE,
        lt_return TYPE TABLE OF bapiret2 WITH HEADER LINE,
        lt_schdlx TYPE TABLE OF bapischdlx WITH HEADER LINE,
        ORDER_ITEM_IN	TYPE TABLE OF	BAPISDITM WITH HEADER LINE,
        ORDER_ITEM_INX  TYPE TABLE OF BAPISDITMX WITH HEADER LINE.
  REFRESH : IT_PROG_ROW_INDEX.
  CALL METHOD GRID->GET_SELECTED_ROWS
    IMPORTING
      ET_INDEX_ROWS = IT_PROG_ROW_INDEX.
  DATA : ZPOSNUM(2) TYPE C.
  LOOP AT IT_PROG_ROW_INDEX INTO WA_PROG_ROW_INDEX.
    READ TABLE SO_TAB INTO SO_WA INDEX WA_PROG_ROW_INDEX-INDEX.


*--Added by Heba for Support Task 'T00002640/IN5492'...
*    IF SY-TCODE = 'YSDAX'.
      SELECT SINGLE ZPOSNUM FROM ZAPPROVEUSER INTO ZPOSNUM
                  WHERE USER_NAME = SY-UNAME
                   AND BUKRS = BUKRS.  "--Added by Heba for Support Task "T00002246/CH1555"
*    ELSE.
*      SELECT SINGLE ZPOSNUM FROM ZAPPROVEUSER INTO ZPOSNUM
*              WHERE USER_NAME = SY-UNAME.
*    ENDIF.
*--End Add...


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
           "Commit the changes in the DB
            CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
              EXPORTING
                WAIT = 'X'.
*&--End of edit by Menna for Task 'T00003072/IN6038'...
 " added by hager mohsen 24.12.2024 Support Task T00005055
   ORDER_HEADER_INX-UPDATEFLAG = 'U'.
   ORDER_ITEM_IN-ITM_NUMBER =  SO_WA-POSNR .
    ORDER_ITEM_IN-REASON_REJ = ''.

  APPEND ORDER_ITEM_IN.
   ORDER_ITEM_INX-ITM_NUMBER =  SO_WA-POSNR .
   ORDER_ITEM_INX-UPDATEFLAG = 'U'.
   ORDER_ITEM_INX-REASON_REJ  = 'X'.
  APPEND  ORDER_ITEM_INX.


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
            salesdocument    = SO_WA-SO_NUM
            order_header_inx = ORDER_HEADER_INX
       TABLES
            return           = lt_return
            ORDER_ITEM_IN    = ORDER_ITEM_IN
            ORDER_ITEM_INX   = ORDER_ITEM_INX
             SCHEDULE_LINES   = LT_SCHDL
          SCHEDULE_LINESX  = LT_SCHDLX.
  .
  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
       EXPORTING
            wait   = 'X'
       IMPORTING
            return = return.

*&--Added by Heba for Task 'T00003072/IN6038'...

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
  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'  "#EC CI_USAGE_OK[2438131]
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
