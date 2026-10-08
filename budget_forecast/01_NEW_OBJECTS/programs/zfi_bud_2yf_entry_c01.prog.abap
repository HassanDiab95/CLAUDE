*&---------------------------------------------------------------------*
*& Include        : ZFI_BUD_2YF_ENTRY_C01
*& Main Program   : ZFI_BUD_2YF_ENTRY
*&---------------------------------------------------------------------*
*& Purpose        : Implementation of the screen controller. UI logic
*&                   only (fields, popups, cursor, messages); every rule
*&                   is checked by ZCL_FI_BUD_2YF.
*&---------------------------------------------------------------------*
CLASS lcl_screen_0100 IMPLEMENTATION.

  METHOD constructor.
    mo_forecast = NEW #( ).

    mv_mode = COND #( WHEN iv_mode IS NOT INITIAL
                      THEN iv_mode
                      WHEN sy-tcode = zif_fi_bud_2yf_types=>c_tcode-modify
                      THEN zif_fi_bud_2yf_types=>c_mode-modify
                      ELSE zif_fi_bud_2yf_types=>c_mode-create ).

    IF mo_forecast->is_entry_allowed( mv_mode ) = abap_false.
      CALL FUNCTION 'POPUP_TO_INFORM'
        EXPORTING
          titel = 'Authorization'
          txt1  = 'You are not authorized to access'
          txt2  = 'the Budget Forecast application.'.
      LEAVE PROGRAM.
    ENDIF.

    set_labels( ).
    reset( ).
  ENDMETHOD.


  METHOD set_labels.
    " Arabic texts of screen 0100 - change the wording only in
    " ZIF_FI_BUD_2YF_TYPES=>C_TEXT_AR
    gs_lbl = VALUE #(
      bukrs           = zif_fi_bud_2yf_types=>c_text_ar-bukrs
      kostl           = zif_fi_bud_2yf_types=>c_text_ar-kostl
      years           = zif_fi_bud_2yf_types=>c_text_ar-years
      ernam           = zif_fi_bud_2yf_types=>c_text_ar-ernam
      erdat           = zif_fi_bud_2yf_types=>c_text_ar-erdat
      aenam           = zif_fi_bud_2yf_types=>c_text_ar-aenam
      aedat           = zif_fi_bud_2yf_types=>c_text_ar-aedat
      changes         = zif_fi_bud_2yf_types=>c_text_ar-change_count
      total           = zif_fi_bud_2yf_types=>c_text_ar-total_amount
      hdr_item_no     = zif_fi_bud_2yf_types=>c_text_ar-item_no
      hdr_budget_year = zif_fi_bud_2yf_types=>c_text_ar-budget_year
      hdr_kostl       = zif_fi_bud_2yf_types=>c_text_ar-dept_code
      hdr_proj_name   = zif_fi_bud_2yf_types=>c_text_ar-proj_name
      hdr_proj_desc   = zif_fi_bud_2yf_types=>c_text_ar-proj_desc
      hdr_priority    = zif_fi_bud_2yf_types=>c_text_ar-priority
      hdr_amount      = zif_fi_bud_2yf_types=>c_text_ar-amount
      hdr_waers       = zif_fi_bud_2yf_types=>c_text_ar-waers
      hdr_bud_type    = zif_fi_bud_2yf_types=>c_text_ar-bud_type
      hdr_proj_type   = zif_fi_bud_2yf_types=>c_text_ar-proj_type ).
  ENDMETHOD.


  METHOD reset.
    CLEAR: gs_head, gs_item, gt_item, gv_ktext, gv_changes_text, gv_fcst_years,
           ms_header_db, mt_items_db, mv_readonly.

    mv_status = c_status-initial.

    " create: preselect the only allowed years
    IF mv_mode = zif_fi_bud_2yf_types=>c_mode-create.
      DATA(ls_window) = mo_forecast->get_forecast_window( ).
      gv_fcst_years = zcl_fi_bud_2yf=>years_text( iv_from = ls_window-fyear_from
                                                   iv_to   = ls_window-fyear_to ).
    ENDIF.

    DATA(lv_text) = condense( COND zif_fi_bud_2yf_types=>ty_text(
                      WHEN mv_mode = zif_fi_bud_2yf_types=>c_mode-create
                      THEN zif_fi_bud_2yf_types=>c_text_ar-btn_create
                      ELSE zif_fi_bud_2yf_types=>c_text_ar-btn_change ) ).
    " icon + Arabic text on the pushbutton (icon code from type group ICON)
    gv_proceed_to_items = |{ icon_bom_sub_item } { lv_text }|.

    ct_fcst-top_line = 1.
  ENDMETHOD.


  METHOD pbo_status.
    DATA lt_excluded TYPE STANDARD TABLE OF sy-ucomm WITH EMPTY KEY.

    IF is_editable( ) = abap_false.
      lt_excluded = VALUE #( ( 'SAVE' ) ).
    ENDIF.
    SET PF-STATUS 'GUI_0100' EXCLUDING lt_excluded.

    " title text in SE41 is just "&1" - the whole title comes from here
    DATA(lv_title) = COND zif_fi_bud_2yf_types=>ty_text(
      WHEN mv_mode = zif_fi_bud_2yf_types=>c_mode-create THEN zif_fi_bud_2yf_types=>c_text_ar-title_create
      WHEN mv_readonly = abap_true                         THEN zif_fi_bud_2yf_types=>c_text_ar-title_display
      ELSE zif_fi_bud_2yf_types=>c_text_ar-title_modify ).
    SET TITLEBAR 'TITLE_0100' WITH lv_title.

    set_listboxes( ).

    ct_fcst-lines = lines( gt_item ).
  ENDMETHOD.


  METHOD pbo_screen_edits.
    LOOP AT SCREEN INTO DATA(ls_screen).
      DATA(lv_open) = SWITCH abap_bool( ls_screen-group1
        WHEN c_group-header THEN xsdbool( mv_status = c_status-initial )
        WHEN c_group-items  THEN is_editable( )
        WHEN c_group-other  THEN xsdbool( mv_status = c_status-entered )
        ELSE xsdbool( ls_screen-input = '1' ) ).
      ls_screen-input = COND #( WHEN lv_open = abap_true THEN '1' ELSE '0' ).
      MODIFY SCREEN FROM ls_screen.
    ENDLOOP.
  ENDMETHOD.


  METHOD pbo_table_line.
    mv_tc_lines = sy-loopc.

    IF is_editable( ) = abap_false.
      LOOP AT SCREEN INTO DATA(ls_screen).
        IF ls_screen-name CP 'GS_ITEM-*'.
          ls_screen-input = '0'.
          MODIFY SCREEN FROM ls_screen.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD pbo_texts.
    gv_ktext = COND #( WHEN gs_head-bukrs IS NOT INITIAL AND gs_head-kostl IS NOT INITIAL
                       THEN mo_forecast->mo_repository->get_cost_center_text( iv_bukrs = gs_head-bukrs
                                                                              iv_kostl = gs_head-kostl ) ).

    gv_changes_text = COND #( WHEN mv_mode = zif_fi_bud_2yf_types=>c_mode-modify
                               AND mv_status = c_status-entered
                              THEN |{ ms_header_db-change_count } { condense( zif_fi_bud_2yf_types=>c_text_ar-of_updates ) } | &&
                                   |{ zif_fi_bud_2yf_types=>c_max_changes } { condense( zif_fi_bud_2yf_types=>c_text_ar-used ) }| ).
  ENDMETHOD.


  METHOD pai_exit.
    CASE iv_ucomm.
      WHEN 'BACK' OR 'CANCEL' OR 'EXIT'.
        " exit commands skip the field transport -> always ask while
        " the items are editable
        IF is_editable( ) = abap_true
           AND confirm( `Unsaved data will be lost. Leave anyway?` ) = abap_false.
          RETURN.
        ENDIF.

        IF iv_ucomm = 'EXIT'.
          LEAVE PROGRAM.
        ENDIF.
        LEAVE TO SCREEN 0.
    ENDCASE.
  ENDMETHOD.


  METHOD pai_check_header.
    IF mv_status <> c_status-initial.
      RETURN.
    ENDIF.

    TRY.
        DATA(ls_years) = zcl_fi_bud_2yf=>split_years( gv_fcst_years ).
        gs_head-fyear_from = ls_years-fyear_from.
        gs_head-fyear_to   = ls_years-fyear_to.

        mo_forecast->validate_header( iv_mode = mv_mode is_key = key( ) ).

      CATCH zcx_fi_bud_2yf INTO DATA(lx_error).
        " E message inside the header CHAIN re-opens the header fields
        MESSAGE lx_error TYPE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD pai_table_modify.
    " only the input columns, so the key fields of the row stay intact
    MODIFY gt_item FROM gs_item INDEX ct_fcst-current_line
           TRANSPORTING budget_year proj_name proj_desc priority amount bud_type proj_type.
  ENDMETHOD.


  METHOD pai_table_mark.
    MODIFY gt_item FROM gs_item INDEX ct_fcst-current_line TRANSPORTING selected.
  ENDMETHOD.


  METHOD pai_user_command.
    " Enter on the header = proceed to the items
    DATA(lv_ucomm) = COND sy-ucomm(
      WHEN mv_status = c_status-initial AND ( iv_ucomm = 'ENTER' OR iv_ucomm IS INITIAL )
      THEN 'PROCESS'
      ELSE iv_ucomm ).

    recalculate( ).

    CASE lv_ucomm.
      WHEN 'PROCESS'.
        IF mv_status = c_status-initial.
          process_header( ).
        ENDIF.

      WHEN 'OTHER'.
        IF is_editable( ) = abap_false
           OR confirm( `Unsaved data will be lost. Continue?` ) = abap_true.
          reset( ).
        ENDIF.

      WHEN 'INSERT_LINE'.
        IF is_editable( ) = abap_true.
          insert_row( ).
        ENDIF.

      WHEN 'DELETE_LINE'.
        IF is_editable( ) = abap_true.
          delete_row( ).
          recalculate( ).
        ENDIF.

      WHEN 'SEL_ALL'.
        select_all( abap_true ).

      WHEN 'DESEL_ALL'.
        select_all( abap_false ).

      WHEN 'SAVE'.
        IF mv_mode = zif_fi_bud_2yf_types=>c_mode-create.
          save_create( ).
        ELSE.
          save_change( ).
        ENDIF.
    ENDCASE.
  ENDMETHOD.


  METHOD process_header.
    gs_head-waers = zif_fi_bud_2yf_types=>c_currency.

    CASE mv_mode.
      WHEN zif_fi_bud_2yf_types=>c_mode-create.
        CLEAR: gt_item, ms_header_db, mt_items_db, mv_readonly.
        mv_status = c_status-entered.
        insert_row( ).

      WHEN zif_fi_bud_2yf_types=>c_mode-modify.
        TRY.
            ms_header_db = mo_forecast->mo_repository->read_header( key( ) ).
          CATCH zcx_fi_bud_2yf INTO DATA(lx_error).
            show_error( lx_error ).
            RETURN.
        ENDTRY.

        mt_items_db = mo_forecast->mo_repository->read_items( key( ) ).
        gs_head     = ms_header_db.
        gt_item     = CORRESPONDING #( mt_items_db ).
        mv_status   = c_status-entered.

        DATA(ls_check) = mo_forecast->check_change_allowed( ms_header_db ).
        mv_readonly = xsdbool( ls_check-allowed = abap_false ).

        IF mv_readonly = abap_false.
          MESSAGE ID zif_fi_bud_2yf_types=>c_msgid TYPE 'S' NUMBER ls_check-msgno
                  WITH ms_header_db-change_count zif_fi_bud_2yf_types=>c_max_changes.
        ELSE.
          MESSAGE ID zif_fi_bud_2yf_types=>c_msgid TYPE 'I' NUMBER ls_check-msgno
                  WITH ls_check-msgv1 DISPLAY LIKE 'W'.
        ENDIF.
    ENDCASE.

    recalculate( ).
    ct_fcst-top_line = 1.
  ENDMETHOD.


  METHOD insert_row.
    APPEND VALUE #( bukrs       = gs_head-bukrs
                    kostl       = gs_head-kostl
                    fyear_from  = gs_head-fyear_from
                    fyear_to    = gs_head-fyear_to
                    item_no     = lines( gt_item ) + 1
                    budget_year = gs_head-fyear_from
                    waers       = zif_fi_bud_2yf_types=>c_currency ) TO gt_item.

    " scroll so that the new line is visible
    DATA(lv_lines) = lines( gt_item ).
    ct_fcst-top_line = COND #( WHEN mv_tc_lines > 0 AND lv_lines > mv_tc_lines
                               THEN lv_lines - mv_tc_lines + 1
                               ELSE 1 ).
  ENDMETHOD.


  METHOD delete_row.
    DELETE gt_item WHERE selected = abap_true.

    LOOP AT gt_item ASSIGNING FIELD-SYMBOL(<ls_item>).
      <ls_item>-item_no = sy-tabix.
    ENDLOOP.

    ct_fcst-top_line = 1.
  ENDMETHOD.


  METHOD select_all.
    LOOP AT gt_item ASSIGNING FIELD-SYMBOL(<ls_item>).
      <ls_item>-selected = iv_selected.
    ENDLOOP.
  ENDMETHOD.


  METHOD recalculate.
    LOOP AT gt_item ASSIGNING FIELD-SYMBOL(<ls_item>).
      <ls_item>-kostl = gs_head-kostl.
      <ls_item>-waers = zif_fi_bud_2yf_types=>c_currency.
    ENDLOOP.

    gs_head-total_amount = zcl_fi_bud_2yf=>total_amount( items( ) ).
    gs_head-waers        = zif_fi_bud_2yf_types=>c_currency.
  ENDMETHOD.


  METHOD save_create.
    TRY.
        mo_forecast->validate_items( is_key = key( ) it_items = items( ) ).
      CATCH zcx_fi_bud_2yf INTO DATA(lx_error).
        show_error( lx_error ).
        RETURN.
    ENDTRY.

    IF confirm( |Submit the forecast budget { gv_fcst_years } for cost center | &&
                |{ gs_head-kostl ALPHA = OUT }? It can be updated at most | &&
                |{ zif_fi_bud_2yf_types=>c_max_changes } times afterwards.| ) = abap_false.
      MESSAGE s019(zbud_fcst).
      RETURN.
    ENDIF.

    TRY.
        DATA(ls_result) = mo_forecast->create( is_key = key( ) it_items = items( ) ).
      CATCH zcx_fi_bud_2yf INTO lx_error.
        show_error( lx_error ).
        RETURN.
    ENDTRY.

    MESSAGE i012(zbud_fcst) WITH gs_head-bukrs gs_head-kostl gv_fcst_years.
    IF ls_result-mail_error IS NOT INITIAL.
      MESSAGE s018(zbud_fcst) WITH ls_result-mail_error DISPLAY LIKE 'W'.
    ENDIF.
    LEAVE TO SCREEN 0.
  ENDMETHOD.


  METHOD save_change.
    IF mv_readonly = abap_true.
      MESSAGE s026(zbud_fcst) DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    DATA(lt_items) = items( ).

    TRY.
        mo_forecast->validate_items( is_key = key( ) it_items = lt_items ).
      CATCH zcx_fi_bud_2yf INTO DATA(lx_error).
        show_error( lx_error ).
        RETURN.
    ENDTRY.

    IF mo_forecast->has_changes( is_key       = key( )
                                 it_items_old = mt_items_db
                                 it_items_new = lt_items ) = abap_false.
      MESSAGE s014(zbud_fcst).
      RETURN.
    ENDIF.

    DATA(lv_next) = ms_header_db-change_count + 1.
    DATA(lv_left) = zif_fi_bud_2yf_types=>c_max_changes - lv_next.

    IF confirm( |This is update { lv_next } of { zif_fi_bud_2yf_types=>c_max_changes } for this forecast. | &&
                COND string( WHEN lv_left = 0 THEN `No further updates will be possible. Save?`
                             ELSE |{ lv_left } update(s) will remain. Save?| ) ) = abap_false.
      MESSAGE s019(zbud_fcst).
      RETURN.
    ENDIF.

    TRY.
        DATA(ls_result) = mo_forecast->change( is_header_db = ms_header_db
                                               it_items_db  = mt_items_db
                                               it_items     = lt_items ).
      CATCH zcx_fi_bud_2yf INTO lx_error.
        show_error( lx_error ).
        RETURN.
    ENDTRY.

    MESSAGE i013(zbud_fcst) WITH ls_result-header-change_count zif_fi_bud_2yf_types=>c_max_changes.
    IF ls_result-mail_error IS NOT INITIAL.
      MESSAGE s018(zbud_fcst) WITH ls_result-mail_error DISPLAY LIKE 'W'.
    ENDIF.
    LEAVE TO SCREEN 0.
  ENDMETHOD.


  METHOD set_listboxes.
    " header: forecast budget years
    DATA(lt_years) = mo_forecast->get_selectable_years( mv_mode ).
    DATA(lt_values) = VALUE vrm_values(
      FOR ls_years IN lt_years
      LET lv_years = zcl_fi_bud_2yf=>years_text( iv_from = ls_years-fyear_from
                                                  iv_to   = ls_years-fyear_to ) IN
      ( key = lv_years text = lv_years ) ).

    CALL FUNCTION 'VRM_SET_VALUES'
      EXPORTING
        id              = 'GV_FCST_YEARS'
        values          = lt_values
      EXCEPTIONS
        id_illegal_name = 1
        OTHERS          = 2.

    " items: budget year = one of the two forecast years
    lt_values = COND #( WHEN mv_status = c_status-entered
                        THEN VALUE #( ( key = |{ gs_head-fyear_from }| text = |{ gs_head-fyear_from }| )
                                      ( key = |{ gs_head-fyear_to }|   text = |{ gs_head-fyear_to }| ) ) ).

    CALL FUNCTION 'VRM_SET_VALUES'
      EXPORTING
        id              = 'GS_ITEM-BUDGET_YEAR'
        values          = lt_values
      EXCEPTIONS
        id_illegal_name = 1
        OTHERS          = 2.
  ENDMETHOD.


  METHOD key.
    rs_key = CORRESPONDING #( gs_head ).
  ENDMETHOD.


  METHOD items.
    rt_items = CORRESPONDING #( gt_item ).
  ENDMETHOD.


  METHOD is_editable.
    rv_result = xsdbool( mv_status = c_status-entered AND mv_readonly = abap_false ).
  ENDMETHOD.


  METHOD show_error.
    " SET CURSOR FIELD needs a character-like field (not a string)
    DATA lv_field TYPE c LENGTH 61.

    IF ix_error->mv_item_index > 0.
      ct_fcst-top_line = ix_error->mv_item_index.
      lv_field = |GS_ITEM-{ ix_error->mv_fieldname }|.
      SET CURSOR FIELD lv_field LINE 1.
    ENDIF.

    " the forecast became display only (limit / year / other user)
    IF ix_error->if_t100_message~t100key-msgno = '008'
    OR ix_error->if_t100_message~t100key-msgno = '021'
    OR ix_error->if_t100_message~t100key-msgno = '022'.
      mv_readonly = abap_true.
    ENDIF.

    MESSAGE ix_error TYPE 'S' DISPLAY LIKE 'E'.
  ENDMETHOD.


  METHOD confirm.
    DATA lv_answer   TYPE c LENGTH 1.
    DATA lv_question TYPE c LENGTH 400.

    lv_question = iv_question.

    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar              = 'Confirm'
        text_question         = lv_question
        text_button_1         = 'Yes'
        icon_button_1         = 'ICON_CHECKED'
        text_button_2         = 'No'
        icon_button_2         = 'ICON_CANCEL'
        default_button        = '1'
        display_cancel_button = abap_false
      IMPORTING
        answer                = lv_answer.

    rv_yes = xsdbool( lv_answer = '1' ).
  ENDMETHOD.

ENDCLASS.


*----------------------------------------------------------------------*
* Menu screen 0001
*----------------------------------------------------------------------*
CLASS lcl_menu_0001 IMPLEMENTATION.

  METHOD constructor.
    DATA(lo_forecast) = NEW zcl_fi_bud_2yf( ).

    mv_can_create = lo_forecast->mo_auth->is_creator( ).
    mv_can_change = xsdbool( mv_can_create = abap_true
                          OR lo_forecast->mo_repository->user_has_forecast( sy-uname ) = abap_true ).
    mv_can_report = lo_forecast->mo_auth->is_final_reviewer( ).

    IF mv_can_create = abap_false AND mv_can_change = abap_false AND mv_can_report = abap_false.
      CALL FUNCTION 'POPUP_TO_INFORM'
        EXPORTING
          titel = 'Authorization'
          txt1  = 'You are not authorized to access'
          txt2  = 'the Budget Forecast application.'.
      LEAVE PROGRAM.
    ENDIF.
  ENDMETHOD.


  METHOD pbo.
    SET PF-STATUS 'GUI_0001'.
    SET TITLEBAR 'TITLE_0001'.

    " show only the buttons of the user's role
    LOOP AT SCREEN INTO DATA(ls_screen).
      DATA(lv_visible) = SWITCH abap_bool( ls_screen-name
                           WHEN 'FCST_CREATE' THEN mv_can_create
                           WHEN 'FCST_CHANGE' THEN mv_can_change
                           WHEN 'FCST_REPORT' THEN mv_can_report
                           ELSE abap_true ).
      IF lv_visible = abap_false.
        ls_screen-active = '0'.
        MODIFY SCREEN FROM ls_screen.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD pai.
    CASE iv_ucomm.
      WHEN 'FCST_CREATE'.
        IF mv_can_create = abap_true.
          start_entry( zif_fi_bud_2yf_types=>c_mode-create ).
        ENDIF.

      WHEN 'FCST_CHANGE'.
        IF mv_can_change = abap_true.
          start_entry( zif_fi_bud_2yf_types=>c_mode-modify ).
        ENDIF.

      WHEN 'FCST_REPORT'.
        IF mv_can_report = abap_true.
          SUBMIT zfi_bud_2yf_report VIA SELECTION-SCREEN AND RETURN.
        ENDIF.
    ENDCASE.
  ENDMETHOD.


  METHOD start_entry.
    " fresh controller for every call; Back / Save return to this menu
    go_screen = NEW #( iv_mode ).
    CALL SCREEN 0100.
    CLEAR go_screen.
  ENDMETHOD.

ENDCLASS.
