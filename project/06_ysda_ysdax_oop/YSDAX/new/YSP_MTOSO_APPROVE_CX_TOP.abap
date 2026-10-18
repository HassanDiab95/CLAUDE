*&---------------------------------------------------------------------*
*& Include          YSP_MTOSO_APPROVE_CX_TOP   (YSDAX)
*&---------------------------------------------------------------------*
*& Global data and class definitions.
*& Only the fields of screen 0099 stay global (the dynpro needs them);
*& everything else lives in the classes.
*&---------------------------------------------------------------------*
PROGRAM ysp_mtoso_approve_cx.

*--- Screen 0099 fields (names / types must not change) ----------------
DATA bukrs   TYPE vbak-bukrs_vf.        " Plant (VBAP-WERKS)
DATA datev_f TYPE vbak-audat.           " From date
DATA datev_t TYPE vbak-audat.           " To date

*--- ALV output line: DDIC structure + cell colours ---------------------
TYPES BEGIN OF ty_s_out.
INCLUDE TYPE ysp_mtoso_approve_cx. "#EC CI_USAGE_OK[2383423]
TYPES color TYPE lvc_t_scol.
TYPES END OF ty_s_out.
TYPES ty_t_out TYPE STANDARD TABLE OF ty_s_out WITH EMPTY KEY.

*--- BAPI tables ---------------------------------------------------------
TYPES ty_t_item_in  TYPE STANDARD TABLE OF bapisditm  WITH EMPTY KEY.
TYPES ty_t_item_inx TYPE STANDARD TABLE OF bapisditmx WITH EMPTY KEY.
TYPES ty_t_schdl    TYPE STANDARD TABLE OF bapischdl  WITH EMPTY KEY.
TYPES ty_t_schdlx   TYPE STANDARD TABLE OF bapischdlx WITH EMPTY KEY.
TYPES ty_t_return   TYPE STANDARD TABLE OF bapiret2   WITH EMPTY KEY.

*--- variable production cost of the cost estimate (KEPH) ---------------
TYPES: BEGIN OF ty_s_var_cost,
         kst001 TYPE keph-kst001,
         kst002 TYPE keph-kst002,
         kst003 TYPE keph-kst003,
         kst004 TYPE keph-kst004,
       END OF ty_s_var_cost.


*&---------------------------------------------------------------------*
*& LCL_VIEW - ALV grid on screen 0100 (container CONTROLLER1)
*&---------------------------------------------------------------------*
CLASS lcl_view DEFINITION FINAL.

  PUBLIC SECTION.
    "! First call: create the grid and show CT_OUT.
    "! Next calls: refresh the grid (row / column stable).
    METHODS show
      CHANGING ct_out TYPE ty_t_out.

    METHODS refresh_soft.

    METHODS get_selected_rows
      RETURNING VALUE(rt_rows) TYPE lvc_t_row.

  PRIVATE SECTION.
    CONSTANTS gc_container TYPE c LENGTH 30 VALUE 'CONTROLLER1'.
    CONSTANTS gc_structure TYPE dd02l-tabname VALUE 'YSP_MTOSO_APPROVE_CX'.

    DATA mo_container TYPE REF TO cl_gui_custom_container.
    DATA mo_grid      TYPE REF TO cl_gui_alv_grid.

    METHODS build_fieldcat
      RETURNING VALUE(rt_fcat) TYPE lvc_t_fcat.

    METHODS build_toolbar_exclude
      RETURNING VALUE(rt_exclude) TYPE ui_functions.

ENDCLASS.


*&---------------------------------------------------------------------*
*& LCL_APP - YSDAX controller: selection, approval, rejection, log
*&---------------------------------------------------------------------*
CLASS lcl_app DEFINITION FINAL.

  PUBLIC SECTION.
    "! Screen 0099 - EXECUTE
    METHODS execute
      IMPORTING iv_plant     TYPE vbak-bukrs_vf
                iv_date_from TYPE vbak-audat
                iv_date_to   TYPE vbak-audat.

    "! Screen 0100 - PBO
    METHODS pbo_0100.

    "! Screen 0100 - PAI
    METHODS pai_0100
      IMPORTING iv_ucomm TYPE syucomm.

  PRIVATE SECTION.
    CONSTANTS: BEGIN OF gc_text,
                 approved     TYPE string VALUE 'Approved',
                 not_approved TYPE string VALUE 'Not Approved',
                 cost_error   TYPE string VALUE 'COST ERROR',
                 loss         TYPE string VALUE 'Loss',
                 profit       TYPE string VALUE 'Profit',
                 no_credit    TYPE string VALUE 'Not related to Credit Managment',
                 exceeded     TYPE string VALUE 'Exceed the limit',
                 not_exceeded TYPE string VALUE 'Did not Exceed ',
               END OF gc_text.

    CONSTANTS: BEGIN OF gc_color,
                 red    TYPE lvc_col VALUE '6',
                 yellow TYPE lvc_col VALUE '3',
               END OF gc_color.

    CONSTANTS gc_credit_segment TYPE ukm_credit_sgmnt VALUE 'CPXCS'.
    CONSTANTS gc_rej_manual     TYPE abgru_va VALUE '63'.   " rejection by the approver
    CONSTANTS gc_sched_released TYPE ettyp    VALUE 'CP'.

    DATA mo_view      TYPE REF TO lcl_view.
    DATA mt_out       TYPE ty_t_out.          " ALV table (old SO_TAB)
    DATA mv_loaded    TYPE abap_bool.         " old FLAG
    DATA mv_plant     TYPE vbak-bukrs_vf.     " old BUKRS
    DATA mv_date_from TYPE vbak-audat.        " old DATEV_F
    DATA mv_date_to   TYPE vbak-audat.        " old DATEV_T

    " Kept as attributes because the old program kept them global and
    " their values carry over between the routines (see README, part 4)
    DATA mv_sd_approve TYPE c LENGTH 1.       " old SD_APPROVE
    DATA mv_fi_approve TYPE c LENGTH 1.       " old FI_APPROVE
    DATA ms_apprv      TYPE zsoapproval.      " old APPRV_WA
    DATA ms_log        TYPE ysp_mtoso_log.    " old WA_LOG

    "--- selection (old FORM SCREEN_START) ------------------------------
    METHODS screen_start.
    METHODS load_rows.
    METHODS set_contribution
      CHANGING cs_row   TYPE ty_s_out
               cv_kalnr TYPE keko-kalnr
               cs_cost  TYPE ty_s_var_cost.
    METHODS has_stock
      IMPORTING is_row          TYPE ty_s_out
      RETURNING VALUE(rv_stock) TYPE abap_bool.
    METHODS set_profit
      CHANGING cs_row TYPE ty_s_out.
    METHODS set_credit
      CHANGING cs_row TYPE ty_s_out.
    METHODS set_approval
      CHANGING cs_row   TYPE ty_s_out
               cv_count TYPE int8.
    METHODS set_configuration
      IMPORTING iv_cuobj TYPE vbap-cuobj
      CHANGING  cs_row   TYPE ty_s_out.

    "--- user actions ---------------------------------------------------
    METHODS approve.                          " old FORM APPROVE_FUN
    METHODS reject.                           " old FORM REJECT_FUN
    METHODS display_orders.                   " old function DISPLAY

    "--- helpers -----------------------------------------------------------
    METHODS get_user_position
      EXPORTING ev_posnum       TYPE char2
      RETURNING VALUE(rv_found) TYPE abap_bool.
    METHODS add_cp_schedule_lines
      IMPORTING is_row    TYPE ty_s_out
      CHANGING  ct_schdl  TYPE ty_t_schdl
                ct_schdlx TYPE ty_t_schdlx.
    METHODS write_log
      IMPORTING iv_event TYPE ysp_mtoso_log-event
                iv_vbeln TYPE ysp_mtoso_log-so_number.
    METHODS add_color
      IMPORTING iv_field TYPE lvc_fname
                iv_color TYPE lvc_col
      CHANGING  cs_row   TYPE ty_s_out.

ENDCLASS.

DATA go_app TYPE REF TO lcl_app.
