CLASS lcl_view IMPLEMENTATION.

  METHOD show.

    IF mo_container IS NOT BOUND.

      mo_container = NEW #( container_name = gc_container ).
      mo_grid      = NEW #( i_parent = mo_container ).

      mo_grid->register_edit_event(
        EXPORTING  i_event_id = cl_gui_alv_grid=>mc_evt_modified
        EXCEPTIONS error      = 1
                   OTHERS     = 2 ).

      DATA(lt_fcat) = build_fieldcat( ).

      mo_grid->set_table_for_first_display(
        EXPORTING i_structure_name     = gc_structure
                  is_layout            = VALUE #( grid_title = 'Sales order Not Approved'
                                                  stylefname = 'CELLTAB'
                                                  ctab_fname = 'COLOR' )
                  it_toolbar_excluding = build_toolbar_exclude( )
                  i_save               = 'A'
                  is_variant           = VALUE #( report = sy-repid )
        CHANGING  it_outtab            = ct_out
                  it_fieldcatalog      = lt_fcat ).

    ELSE.

      mo_grid->refresh_table_display(
        EXPORTING  is_stable = VALUE #( row = abap_true col = abap_true )
        EXCEPTIONS finished  = 1
                   OTHERS    = 2 ).

    ENDIF.

  ENDMETHOD.

  METHOD refresh_soft.

    mo_grid->refresh_table_display( i_soft_refresh = abap_true ).

  ENDMETHOD.

  METHOD get_selected_rows.

    mo_grid->get_selected_rows( IMPORTING et_index_rows = rt_rows ).

  ENDMETHOD.

  METHOD build_fieldcat.

    rt_fcat = VALUE #(
      ( fieldname = 'SO_NUM'        coltext = 'Sales order'     outputlen = 10 hotspot = abap_true )
      ( fieldname = 'CUSTOMER_NO'   coltext = 'Customer No'     outputlen = 10 )
      ( fieldname = 'CUSTOMER_NAME' coltext = 'Customer Name'   outputlen = 10 )
      ( fieldname = 'MATNR'         coltext = 'Material'        outputlen = 8 )
      ( fieldname = 'DESIGN_CODE'   coltext = 'Design Code'     outputlen = 8 )
      ( fieldname = 'DC_DESC'       coltext = 'Design Desc.'    outputlen = 8 )
      ( fieldname = 'Posnr'         coltext = 'ITEM'            outputlen = 8 )
      ( fieldname = 'DOC_DATE'      coltext = 'Date'            outputlen = 8 )
      ( fieldname = 'SALES_OFF'     coltext = 'Sales Office'    outputlen = 4 )
      ( fieldname = 'DELV_DATE'     coltext = 'Delivery Date'   outputlen = 8 )
      ( fieldname = 'NET_VALUE'     coltext = 'Net Value'       outputlen = 10 )
      ( fieldname = 'TOTAL_COST'    coltext = 'TOTAL COST'      outputlen = 10 )
      ( fieldname = 'CONTR_PROFIT'  coltext = 'CONTR PROFIT'    outputlen = 10 )
      ( fieldname = 'PROFIT'        coltext = 'Profit'          outputlen = 10 )
      ( fieldname = 'PROFIT_STATUS' coltext = 'Profit Status'   outputlen = 15 emphasize = 'C511' )
      ( fieldname = 'CREDIT_LIMIT'  coltext = 'Credit Limit'    outputlen = 13 )
      ( fieldname = 'CREDIT_EXP'    coltext = 'Credit Exposure' outputlen = 13 )
      ( fieldname = 'CREDIT_STATUS' coltext = 'Credit Status'   outputlen = 20 emphasize = 'C511' )
      ( fieldname = 'SM_APPROVAL'   coltext = 'Sales Approval'  outputlen = 12 emphasize = 'C511' )
      ( fieldname = 'AR_APPROVAL'   coltext = 'FI Approval'     outputlen = 12 emphasize = 'C511' ) ).

  ENDMETHOD.

  METHOD build_toolbar_exclude.

    rt_exclude = VALUE #(
      ( cl_gui_alv_grid=>mc_fc_graph )
      ( cl_gui_alv_grid=>mc_fc_info )
      ( cl_gui_alv_grid=>mc_fc_print )
      ( cl_gui_alv_grid=>mc_fc_views )
      ( cl_gui_alv_grid=>mc_fc_detail )
      ( cl_gui_alv_grid=>mc_fc_refresh )
      ( cl_gui_alv_grid=>mc_fc_check )
      ( cl_gui_alv_grid=>mc_fc_subtot )
      ( cl_gui_alv_grid=>mc_fc_loc_append_row )
      ( cl_gui_alv_grid=>mc_fc_loc_copy )
      ( cl_gui_alv_grid=>mc_fc_loc_copy_row )
      ( cl_gui_alv_grid=>mc_fc_loc_cut )
      ( cl_gui_alv_grid=>mc_fc_loc_delete_row )
      ( cl_gui_alv_grid=>mc_fc_loc_insert_row )
      ( cl_gui_alv_grid=>mc_fc_loc_move_row )
      ( cl_gui_alv_grid=>mc_fc_loc_paste )
      ( cl_gui_alv_grid=>mc_fc_loc_paste_new_row )
      ( cl_gui_alv_grid=>mc_fc_loc_undo ) ).

  ENDMETHOD.

ENDCLASS.

CLASS lcl_app IMPLEMENTATION.

  METHOD execute.

    mv_plant     = iv_plant.
    mv_date_from = iv_date_from.
    mv_date_to   = iv_date_to.

    AUTHORITY-CHECK OBJECT 'M_MSEG_WWA'
      ID 'WERKS' FIELD mv_plant.
    IF sy-subrc <> 0.
      MESSAGE 'You Dont have authorization ' TYPE 'I'.
    ELSE.
      CALL SCREEN '0100'.
    ENDIF.

  ENDMETHOD.

  METHOD pbo_0100.

    IF mo_view IS NOT BOUND.
      mo_view = NEW #( ).
    ENDIF.

    mo_view->show( CHANGING ct_out = mt_out ).

    screen_start( ).

  ENDMETHOD.

  METHOD pai_0100.

    CASE iv_ucomm.
      WHEN 'SEARCH'.
      WHEN 'APPROVE'.
        approve( ).
      WHEN 'REJECT'.
        reject( ).
      WHEN 'DISPLAY'.
        display_orders( ).
    ENDCASE.

  ENDMETHOD.

  METHOD screen_start.

    CHECK mv_loaded = abap_false.

    CLEAR mt_out.
    load_rows( ).

    SORT mt_out DESCENDING BY so_num posnr.
    DELETE ADJACENT DUPLICATES FROM mt_out COMPARING so_num posnr.

    mo_view->refresh_soft( ).
    mv_loaded = abap_true.

  ENDMETHOD.

  METHOD load_rows.

    DATA lr_pstyv TYPE RANGE OF vbap-pstyv.
    DATA lr_auart TYPE RANGE OF vbak-auart.
    DATA lv_count TYPE int8.
    DATA lv_kalnr TYPE keko-kalnr.
    DATA ls_cost  TYPE ty_s_var_cost.

    IF mv_plant = '1600'.
      lr_pstyv = VALUE #( sign = 'I' option = 'EQ' ( low = 'YZTC' ) ( low = 'YFRE' ) ).
    ENDIF.

    IF mv_plant = '1400'.
      lr_auart = VALUE #( sign = 'I' option = 'EQ' ( low = 'ZEM' ) ( low = 'ZMT' )
                                                   ( low = 'ZOR' ) ( low = 'ZFC' ) ).
    ENDIF.

    SELECT vbak~vbeln AS so_num,
           vbap~matnr,
           vbap~posnr,
           vbap~netwr AS net_value,
           vbap~wavwr AS total_cost,
           vbak~kunnr AS customer_no,
           vbak~audat AS doc_date,
           vbak~vdatu AS delv_date,
           vbap~cuobj,
           vbak~vkbur AS sales_off,
           vbak~knumv
      FROM vbap
      INNER JOIN vbak ON vbak~vbeln = vbap~vbeln
      INNER JOIN vbep ON vbep~vbeln = vbap~vbeln
                     AND vbep~posnr = vbap~posnr
      WHERE vbap~pstyv IN @lr_pstyv
        AND vbep~ettyp = 'CN'
        AND vbap~werks = @mv_plant
        AND vbap~absta <> 'C'
        AND ( vbak~vbtyp = 'C' OR vbak~vbtyp = 'I' )
        AND vbak~auart IN @lr_auart
        AND vbak~audat >= @mv_date_from
        AND vbak~audat <= @mv_date_to
      INTO TABLE @DATA(lt_db).

    LOOP AT lt_db INTO DATA(ls_db).

      DATA(ls_row) = CORRESPONDING ty_s_out( ls_db ).

      set_contribution( CHANGING cs_row   = ls_row
                                 cv_kalnr = lv_kalnr
                                 cs_cost  = ls_cost ).

      CHECK has_stock( ls_row ) = abap_false.

      SELECT SINGLE name1 FROM kna1
        WHERE kunnr = @ls_row-customer_no
        INTO @ls_row-customer_name.

      set_profit( CHANGING cs_row = ls_row ).
      set_credit( CHANGING cs_row = ls_row ).
      set_approval( CHANGING cs_row = ls_row cv_count = lv_count ).
      set_configuration( EXPORTING iv_cuobj = ls_db-cuobj
                         CHANGING  cs_row   = ls_row ).

      APPEND ls_row TO mt_out.

    ENDLOOP.

  ENDMETHOD.

  METHOD set_contribution.

    SELECT SINGLE kalnr FROM keko
      WHERE vbeln = @cs_row-so_num
        AND posnr = @cs_row-posnr
      INTO @cv_kalnr.

    SELECT SINGLE kst001, kst002, kst003, kst004 FROM keph
      WHERE kalnr = @cv_kalnr
        AND kkzst = @space
      INTO @cs_cost.

    cs_row-contr_profit = cs_row-net_value
                        - ( cs_cost-kst001 + cs_cost-kst002 + cs_cost-kst003 + cs_cost-kst004 ).

  ENDMETHOD.

  METHOD has_stock.

    SELECT SINGLE kalab FROM mska
      WHERE vbeln = @is_row-so_num
        AND posnr = @is_row-posnr
        AND matnr = @is_row-matnr
      INTO @DATA(lv_kalab).

    rv_stock = xsdbool( sy-subrc = 0 ).

  ENDMETHOD.

  METHOD set_profit.

    SELECT SUM( kwert ) FROM prcd_elements
      WHERE knumv = @cs_row-knumv
        AND kposn = @cs_row-posnr
        AND kschl IN ( 'ZBPC', 'ZOVC' )
      INTO @DATA(lv_cost).

    cs_row-total_cost = cs_row-total_cost + lv_cost.
    cs_row-profit     = cs_row-net_value - cs_row-total_cost.

    IF cs_row-total_cost = 0.
      cs_row-profit_status = gc_text-cost_error.
      add_color( EXPORTING iv_field = 'PROFIT_STATUS' iv_color = gc_color-red CHANGING cs_row = cs_row ).
      cs_row-ar_approval = gc_text-not_approved.
      add_color( EXPORTING iv_field = 'AR_APPROVAL' iv_color = gc_color-red CHANGING cs_row = cs_row ).

    ELSEIF cs_row-profit < 0.
      cs_row-profit_status = gc_text-loss.
      add_color( EXPORTING iv_field = 'PROFIT_STATUS' iv_color = gc_color-red CHANGING cs_row = cs_row ).
      cs_row-ar_approval = gc_text-not_approved.
      add_color( EXPORTING iv_field = 'AR_APPROVAL' iv_color = gc_color-red CHANGING cs_row = cs_row ).

    ELSE.
      cs_row-profit_status = gc_text-profit.
      cs_row-ar_approval   = gc_text-approved.
    ENDIF.

  ENDMETHOD.

  METHOD set_credit.

    SELECT SINGLE credit_limit FROM ukmbp_cms_sgm
      WHERE partner = @cs_row-customer_no
      INTO @cs_row-credit_limit.

    IF sy-subrc <> 0.
      cs_row-credit_status = gc_text-no_credit.
      add_color( EXPORTING iv_field = 'CREDIT_STATUS' iv_color = gc_color-yellow CHANGING cs_row = cs_row ).
      RETURN.
    ENDIF.

    CALL FUNCTION 'UKM_COMMTS_BUPA_DISPLAY'
      EXPORTING
        i_partner            = cs_row-customer_no
        i_segment            = gc_credit_segment
      IMPORTING
        e_commitments_amount = cs_row-credit_exp.

    IF cs_row-credit_limit < cs_row-credit_exp.
      cs_row-credit_status = gc_text-exceeded.
      add_color( EXPORTING iv_field = 'CREDIT_STATUS' iv_color = gc_color-red CHANGING cs_row = cs_row ).
      IF cs_row-ar_approval = gc_text-approved.
        cs_row-ar_approval = gc_text-not_approved.
        add_color( EXPORTING iv_field = 'AR_APPROVAL' iv_color = gc_color-red CHANGING cs_row = cs_row ).
      ENDIF.
    ELSE.
      cs_row-credit_status = gc_text-not_exceeded.
    ENDIF.

  ENDMETHOD.

  METHOD set_approval.

    DATA lv_count_c TYPE c LENGTH 8.

    CLEAR: mv_sd_approve, mv_fi_approve.
    SELECT SINGLE sd_approve, fi_approve FROM zsoapproval
      WHERE vbeln = @cs_row-so_num
        AND posnr = @cs_row-posnr
      INTO (@mv_sd_approve, @mv_fi_approve).

    IF sy-subrc <> 0.
      ms_apprv-vbeln = cs_row-so_num.
      ms_apprv-bukrs = mv_plant.
      IF cs_row-ar_approval = gc_text-approved.
        ms_apprv-fi_approve = abap_true.
      ENDIF.
      cs_row-sm_approval = gc_text-not_approved.
      add_color( EXPORTING iv_field = 'SM_APPROVAL' iv_color = gc_color-red CHANGING cs_row = cs_row ).
      ms_apprv-posnr = cs_row-posnr.
      cv_count  = cv_count + 1.
      lv_count_c = cv_count.
      CONCATENATE lv_count_c cs_row-so_num cs_row-posnr INTO ms_apprv-id.
      MODIFY zsoapproval FROM @ms_apprv.
      CLEAR ms_apprv.
      RETURN.
    ENDIF.

    IF mv_sd_approve = abap_true.
      cs_row-sm_approval = gc_text-approved.
    ELSE.
      cs_row-sm_approval = gc_text-not_approved.
      add_color( EXPORTING iv_field = 'SM_APPROVAL' iv_color = gc_color-red CHANGING cs_row = cs_row ).
    ENDIF.

    IF mv_fi_approve = abap_true.
      cs_row-ar_approval = gc_text-approved.
    ELSE.
      cs_row-ar_approval = gc_text-not_approved.
      add_color( EXPORTING iv_field = 'AR_APPROVAL' iv_color = gc_color-red CHANGING cs_row = cs_row ).
    ENDIF.

  ENDMETHOD.

  METHOD set_configuration.

    DATA lt_conf TYPE STANDARD TABLE OF conf_out.

    CALL FUNCTION 'VC_I_GET_CONFIGURATION'
      EXPORTING
        instance            = iv_cuobj
      TABLES
        configuration       = lt_conf
      EXCEPTIONS
        instance_not_found  = 1
        internal_error      = 2
        no_class_allocation = 3
        instance_not_valid  = 4
        OTHERS              = 5.

    LOOP AT lt_conf INTO DATA(ls_conf) WHERE atnam = 'ZDESC'.
      SELECT SINGLE edescription FROM yvcot
        WHERE code = @ls_conf-atwtb
        INTO @cs_row-dc_desc.
      cs_row-design_code = ls_conf-atwtb.
    ENDLOOP.

  ENDMETHOD.

  METHOD approve.

    DATA lt_schdl    TYPE ty_t_schdl.
    DATA lt_schdlx   TYPE ty_t_schdlx.
    DATA lt_return   TYPE ty_t_return.
    DATA lt_apprv    TYPE STANDARD TABLE OF zsoapproval WITH EMPTY KEY.
    DATA ls_row      TYPE ty_s_out.
    DATA lv_posnum   TYPE char2.

    DATA(ls_header_inx) = VALUE bapisdh1x( updateflag = 'U' ).
    DATA(lt_rows)       = mo_view->get_selected_rows( ).

    LOOP AT lt_rows INTO DATA(ls_index).

      READ TABLE mt_out INTO ls_row INDEX ls_index-index.

      IF get_user_position( IMPORTING ev_posnum = lv_posnum ) = abap_true.

        CASE lv_posnum.

          WHEN 'SD'.
            SELECT * FROM zsoapproval
              WHERE vbeln = @ls_row-so_num
                AND posnr = @ls_row-posnr
              INTO TABLE @lt_apprv.
            IF sy-subrc = 0.
              LOOP AT lt_apprv INTO ms_apprv.
                ms_apprv-sd_approve   = abap_true.
                ms_apprv-sd_aprv_date = sy-datum.
                ms_apprv-sd_aprv_time = sy-uzeit.
                MODIFY zsoapproval FROM @ms_apprv.
                COMMIT WORK AND WAIT.
                CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
                  EXPORTING
                    wait = abap_true.
                mv_sd_approve = abap_true.
              ENDLOOP.
            ENDIF.

          WHEN 'FI'.
            SELECT * FROM zsoapproval
              WHERE vbeln = @ls_row-so_num
                AND posnr = @ls_row-posnr
              INTO TABLE @lt_apprv.
            LOOP AT lt_apprv INTO ms_apprv.
              ms_apprv-fi_approve   = abap_true.
              ms_apprv-fi_aprv_date = sy-datum.
              ms_apprv-fi_aprv_time = sy-uzeit.
              MODIFY zsoapproval FROM @ms_apprv.
              COMMIT WORK AND WAIT.
              CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
                EXPORTING
                  wait = abap_true.
              mv_fi_approve = abap_true.
            ENDLOOP.

        ENDCASE.

      ELSE.

        MESSAGE 'You are not Authorized to Approve' TYPE 'W'.
        write_log( iv_event = 'not Authorized'
                   iv_vbeln = ls_row-so_num ).
        CLEAR: mv_sd_approve, mv_fi_approve.

      ENDIF.

      SELECT SINGLE sd_approve, fi_approve FROM zsoapproval
        WHERE vbeln = @ls_row-so_num
          AND posnr = @ls_row-posnr
        INTO (@mv_sd_approve, @mv_fi_approve).

      IF mv_sd_approve = abap_true AND mv_fi_approve = abap_true.

        add_cp_schedule_lines( EXPORTING is_row    = ls_row
                               CHANGING  ct_schdl  = lt_schdl
                                         ct_schdlx = lt_schdlx ).

        CALL FUNCTION 'BAPI_SALESORDER_CHANGE' "#EC CI_USAGE_OK[2438131]
          EXPORTING
            salesdocument    = ls_row-so_num
            order_header_inx = ls_header_inx
          TABLES
            return           = lt_return
            schedule_lines   = lt_schdl
            schedule_linesx  = lt_schdlx.

        CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
          EXPORTING
            wait = abap_true.

        LOOP AT lt_return INTO DATA(ls_return) WHERE id = 'V1'.
          MESSAGE ls_return-message(100) TYPE 'I'.
          ms_log-note = ls_return-message(100).
        ENDLOOP.

        write_log( iv_event = 'APPROVAL'
                   iv_vbeln = ls_row-so_num ).

      ENDIF.

    ENDLOOP.

    mv_loaded = abap_false.
    screen_start( ).

  ENDMETHOD.

  METHOD reject.

    IF get_user_position( ) = abap_false.
      MESSAGE 'No Authorization For reject this order' TYPE 'I'.
      RETURN.
    ENDIF.

    DATA lt_item_in  TYPE ty_t_item_in.
    DATA lt_item_inx TYPE ty_t_item_inx.
    DATA lt_return   TYPE ty_t_return.
    DATA ls_row      TYPE ty_s_out.

    DATA(ls_header_inx) = VALUE bapisdh1x( updateflag = 'U' ).
    DATA(lt_rows)       = mo_view->get_selected_rows( ).

    LOOP AT lt_rows INTO DATA(ls_index).

      READ TABLE mt_out INTO ls_row INDEX ls_index-index.

      APPEND VALUE #( itm_number = ls_row-posnr
                      reason_rej = gc_rej_manual ) TO lt_item_in.
      APPEND VALUE #( itm_number = ls_row-posnr
                      updateflag = 'U'
                      reason_rej = abap_true ) TO lt_item_inx.

      CALL FUNCTION 'BAPI_SALESORDER_CHANGE' "#EC CI_USAGE_OK[2438131]
        EXPORTING
          salesdocument    = ls_row-so_num
          order_header_inx = ls_header_inx
        TABLES
          return           = lt_return
          order_item_in    = lt_item_in
          order_item_inx   = lt_item_inx.

      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' "#EC CI_USAGE_OK[2438131]
        EXPORTING
          wait = abap_true.

      LOOP AT lt_return INTO DATA(ls_return).
        MESSAGE ls_return-message(100) TYPE 'I'.
        ms_log-note = ls_return-message(100).
      ENDLOOP.

      write_log( iv_event = 'REJECT'
                 iv_vbeln = ls_row-so_num ).

    ENDLOOP.

    mv_loaded = abap_false.
    screen_start( ).

  ENDMETHOD.

  METHOD display_orders.

    DATA ls_row TYPE ty_s_out.

    DATA(lt_rows) = mo_view->get_selected_rows( ).

    LOOP AT lt_rows INTO DATA(ls_index).
      READ TABLE mt_out INTO ls_row INDEX ls_index-index.
      SET PARAMETER ID 'AUN' FIELD ls_row-so_num.
      CALL TRANSACTION 'VA03' WITHOUT AUTHORITY-CHECK AND SKIP FIRST SCREEN.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_user_position.

    SELECT SINGLE zposnum FROM zapproveuser
      WHERE user_name = @sy-uname
        AND bukrs     = @mv_plant
      INTO @ev_posnum.
    rv_found = xsdbool( sy-subrc = 0 ).

  ENDMETHOD.

  METHOD add_cp_schedule_lines.

    SELECT etenr FROM vbep
      WHERE vbeln = @is_row-so_num
        AND posnr = @is_row-posnr
        AND wmeng > 0
      INTO TABLE @DATA(lt_etenr).

    LOOP AT lt_etenr INTO DATA(lv_etenr).
      APPEND VALUE #( itm_number = is_row-posnr
                      sched_line = lv_etenr
                      sched_type = gc_sched_released ) TO ct_schdl.
      APPEND VALUE #( itm_number = is_row-posnr
                      sched_line = lv_etenr
                      updateflag = 'U'
                      sched_type = abap_true ) TO ct_schdlx.
    ENDLOOP.

  ENDMETHOD.

  METHOD write_log.

    DATA lv_count TYPE int8.

    ms_log-logdate   = sy-datum.
    ms_log-time      = sy-uzeit.
    ms_log-user_name = sy-uname.
    ms_log-event     = iv_event.
    ms_log-so_number = iv_vbeln.

    SELECT COUNT(*) FROM ysp_mtoso_log INTO @lv_count.
    ms_log-log_number = lv_count + 1.

    INSERT ysp_mtoso_log FROM @ms_log.

  ENDMETHOD.

  METHOD add_color.

    APPEND VALUE #( fname = iv_field
                    color = VALUE #( col = iv_color int = 0 inv = 0 ) ) TO cs_row-color.

  ENDMETHOD.

ENDCLASS.
