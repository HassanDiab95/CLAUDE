*&---------------------------------------------------------------------*
*& Include        : ZFI_BUD_2YF_ENTRY_TOP
*& Main Program   : ZFI_BUD_2YF_ENTRY
*&---------------------------------------------------------------------*
*& Purpose        : Screen 0100 fields (must be global for the dynpro)
*&                   and the definition of the screen controller.
*&---------------------------------------------------------------------*

" ---------------- screen 0100 fields ----------------
DATA gs_head            TYPE zfi_bud_2yf_h.  "header block
DATA gv_fcst_years      TYPE c LENGTH 9.      "listbox, e.g. '2028-2029'
DATA gv_ktext           TYPE kltxt.           "cost center text
DATA gv_changes_text    TYPE char20.          "e.g. '1 of 2 used'
DATA gv_proceed_to_items TYPE c LENGTH 50.    "icon pushbutton

DATA: BEGIN OF gs_item,
        selected TYPE c LENGTH 1.
        INCLUDE STRUCTURE zfi_bud_2yf_i.
DATA  END OF gs_item.

DATA gt_item LIKE STANDARD TABLE OF gs_item WITH EMPTY KEY.

CONTROLS ct_fcst TYPE TABLEVIEW USING SCREEN 0100.

DATA gv_ucomm TYPE sy-ucomm.


*----------------------------------------------------------------------*
* Screen controller: owns the screen state and translates user actions
* into calls of the business object ZCL_FI_BUD_2YF.
*----------------------------------------------------------------------*
CLASS lcl_screen_0100 DEFINITION FINAL.

  PUBLIC SECTION.
    METHODS constructor.

    " PBO
    METHODS pbo_status.
    METHODS pbo_screen_edits.
    METHODS pbo_table_line.
    METHODS pbo_texts.

    " PAI
    METHODS pai_exit
      IMPORTING iv_ucomm TYPE sy-ucomm.
    METHODS pai_check_header.
    METHODS pai_table_modify.
    METHODS pai_table_mark.
    METHODS pai_user_command
      IMPORTING iv_ucomm TYPE sy-ucomm.

  PRIVATE SECTION.
    CONSTANTS: BEGIN OF c_status,
                 initial TYPE c LENGTH 1 VALUE 'I',  "header entry
                 entered TYPE c LENGTH 1 VALUE 'E',  "items open
               END OF c_status.

    " screen groups (Group1) on screen 0100
    CONSTANTS: BEGIN OF c_group,
                 header TYPE c LENGTH 3 VALUE '1',
                 items  TYPE c LENGTH 3 VALUE '2',
                 other  TYPE c LENGTH 3 VALUE '3',
               END OF c_group.

    DATA mo_forecast   TYPE REF TO zcl_fi_bud_2yf.
    DATA mv_mode       TYPE zif_fi_bud_2yf_types=>ty_mode.
    DATA mv_status     TYPE c LENGTH 1.
    DATA mv_readonly   TYPE abap_bool.
    DATA mv_tc_lines   TYPE i.
    DATA ms_header_db  TYPE zif_fi_bud_2yf_types=>ty_header.
    DATA mt_items_db   TYPE zif_fi_bud_2yf_types=>tt_items.

    METHODS reset.
    METHODS process_header.
    METHODS insert_row.
    METHODS delete_row.
    METHODS select_all
      IMPORTING iv_selected TYPE abap_bool.
    METHODS recalculate.
    METHODS save_create.
    METHODS save_change.
    METHODS set_listboxes.

    METHODS key
      RETURNING VALUE(rs_key) TYPE zif_fi_bud_2yf_types=>ty_key.
    METHODS items
      RETURNING VALUE(rt_items) TYPE zif_fi_bud_2yf_types=>tt_items.
    METHODS is_editable
      RETURNING VALUE(rv_result) TYPE abap_bool.

    "! Show the error and put the cursor on the item cell, if any
    METHODS show_error
      IMPORTING ix_error TYPE REF TO zcx_fi_bud_2yf.

    METHODS confirm
      IMPORTING iv_question   TYPE string
      RETURNING VALUE(rv_yes) TYPE abap_bool.

ENDCLASS.

DATA go_screen TYPE REF TO lcl_screen_0100.
