"! <p>SD: Control of Sales Orders created with reference to a Contract.</p>
"! Filter logic against the range table ZSD_SO_CON_FLT (TSD CH4323, chapter 2/3).
"! Each PROCESS (VA01 = create / field lock, VA02 = change / approval,
"! BOTH = VA01 and VA02) holds select-option style lines
"! (SIGN/OPTION/LOW/HIGH) per field. BOTH lines are added to VA01 and VA02.
"! - Lines of the same field are combined like a select-option (OR).
"! - Different fields are combined with AND.
"! - A field without lines is not restricted (all values).
"! The result is buffered per document because USEREXIT_FIELD_MODIFICATION
"! is called once per screen field on every PBO.
CLASS zcl_sd_so_contract_ctrl DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
*   Range tables are typed here (RANGE OF), so the class does not depend
*   on DDIC ranges table types.
    TYPES ty_r_vkorg     TYPE RANGE OF vbak-vkorg.
    TYPES ty_r_vtweg     TYPE RANGE OF vbak-vtweg.
    TYPES ty_r_spart     TYPE RANGE OF vbak-spart.
    TYPES ty_r_auart_so  TYPE RANGE OF vbak-auart.
    TYPES ty_r_auart_con TYPE RANGE OF vbak-auart.

    "! Filter of one process: one range table per field
    TYPES:
      BEGIN OF ty_filter,
        process   TYPE ze_sd_process,
        vkorg     TYPE ty_r_vkorg,
        vtweg     TYPE ty_r_vtweg,
        spart     TYPE ty_r_spart,
        auart_so  TYPE ty_r_auart_so,
        auart_con TYPE ty_r_auart_con,
      END OF ty_filter.
    TYPES tt_filter TYPE SORTED TABLE OF ty_filter WITH UNIQUE KEY process.

    CONSTANTS gc_vgtyp_contract TYPE vbak-vgtyp VALUE 'G'.

    CONSTANTS:
      BEGIN OF gc_process,
        create TYPE ze_sd_process VALUE 'VA01',   " field lock
        change TYPE ze_sd_process VALUE 'VA02',   " change detection / approval
        both   TYPE ze_sd_process VALUE 'BOTH',   " line valid for VA01 and VA02
      END OF gc_process.

    "! Item functions blocked in VA01 for relevant orders (as in VA03).
    "! Confirm the codes in SE41 (program SAPMV45A) or with /h + SY-UCOMM.
    CONSTANTS:
      BEGIN OF gc_fcode,
        insert_item TYPE sy-ucomm VALUE 'POAN',   " Insert row / new item
        delete_item TYPE sy-ucomm VALUE 'POLO',   " Delete item
      END OF gc_fcode.

    TYPES tt_fcode TYPE STANDARD TABLE OF sy-ucomm WITH EMPTY KEY.

    CONSTANTS:
      BEGIN OF gc_field,
        vkorg     TYPE ze_sd_flt_field VALUE 'VKORG',
        vtweg     TYPE ze_sd_flt_field VALUE 'VTWEG',
        spart     TYPE ze_sd_flt_field VALUE 'SPART',
        auart_so  TYPE ze_sd_flt_field VALUE 'AUART_SO',
        auart_con TYPE ze_sd_flt_field VALUE 'AUART_CON',
      END OF gc_field.

    "! Returns abap_true when the sales order header matches the active
    "! filter of the process: VGBEL filled + VGTYP = 'G' + Sales Area +
    "! SO Type + Contract Type.
    CLASS-METHODS is_relevant
      IMPORTING is_vbak            TYPE vbak
                iv_process         TYPE ze_sd_process
      RETURNING VALUE(rv_relevant) TYPE abap_bool.

    "! Active filters from ZSD_SO_CON_FLT as range tables (buffered).
    CLASS-METHODS get_filters
      RETURNING VALUE(rt_filters) TYPE tt_filter.

    "! Returns abap_true when the screen field has to be closed for input.
    CLASS-METHODS is_locked_field
      IMPORTING iv_screen_name   TYPE csequence
      RETURNING VALUE(rv_locked) TYPE abap_bool.

    "! Function codes to exclude from the GUI status (insert / delete item).
    CLASS-METHODS get_locked_fcodes
      RETURNING VALUE(rt_fcodes) TYPE tt_fcode.

    "! Characteristic value assignment in display mode (like VA03):
    "! switches the transaction type to display ('A') for a relevant VA01
    "! order and remembers the original value.
    CLASS-METHODS config_display_on
      IMPORTING is_vbak  TYPE vbak
      CHANGING  cv_trtyp TYPE t180-trtyp.

    "! Restores the transaction type changed by CONFIG_DISPLAY_ON.
    "! Safe to call any time (does nothing if nothing was switched).
    CLASS-METHODS config_display_off
      CHANGING cv_trtyp TYPE t180-trtyp.

    "! Result of the last IS_RELEVANT evaluation (used outside SAPMV45A,
    "! e.g. pricing screens in SAPLV69A where VBAK is not available).
    CLASS-METHODS is_current_doc_relevant
      RETURNING VALUE(rv_relevant) TYPE abap_bool.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_key,
        process TYPE ze_sd_process,
        vgbel   TYPE vbak-vgbel,
        vgtyp   TYPE vbak-vgtyp,
        auart   TYPE vbak-auart,
        vkorg   TYPE vbak-vkorg,
        vtweg   TYPE vbak-vtweg,
        spart   TYPE vbak-spart,
      END OF ty_key.

    CLASS-DATA gs_last_key      TYPE ty_key.
    CLASS-DATA gv_last_relevant TYPE abap_bool.
    CLASS-DATA gv_evaluated     TYPE abap_bool.
    CLASS-DATA gt_filters       TYPE tt_filter.
    CLASS-DATA gv_filters_read  TYPE abap_bool.
    CLASS-DATA gv_saved_trtyp   TYPE t180-trtyp.

    CLASS-METHODS evaluate
      IMPORTING is_key             TYPE ty_key
      RETURNING VALUE(rv_relevant) TYPE abap_bool.
ENDCLASS.


CLASS zcl_sd_so_contract_ctrl IMPLEMENTATION.

  METHOD is_relevant.
    DATA(ls_key) = VALUE ty_key( process = iv_process
                                 vgbel   = is_vbak-vgbel
                                 vgtyp   = is_vbak-vgtyp
                                 auart   = is_vbak-auart
                                 vkorg   = is_vbak-vkorg
                                 vtweg   = is_vbak-vtweg
                                 spart   = is_vbak-spart ).

    IF gv_evaluated = abap_false OR ls_key <> gs_last_key.
      gs_last_key      = ls_key.
      gv_last_relevant = evaluate( ls_key ).
      gv_evaluated     = abap_true.
    ENDIF.

    rv_relevant = gv_last_relevant.
  ENDMETHOD.


  METHOD get_filters.
    DATA lt_targets TYPE STANDARD TABLE OF ze_sd_process WITH EMPTY KEY.

    IF gv_filters_read = abap_false.
      SELECT process, fieldname, sign, opti, low, high
        FROM zsd_so_con_flt
        WHERE active = @abap_true
        ORDER BY process, fieldname, seqno
        INTO TABLE @DATA(lt_lines).

      LOOP AT lt_lines INTO DATA(ls_line).
*       BOTH = line applies to VA01 and VA02
        lt_targets = COND #( WHEN ls_line-process = gc_process-both
                             THEN VALUE #( ( gc_process-create ) ( gc_process-change ) )
                             ELSE VALUE #( ( ls_line-process ) ) ).

        LOOP AT lt_targets INTO DATA(lv_process).
          IF NOT line_exists( gt_filters[ process = lv_process ] ).
            INSERT VALUE #( process = lv_process ) INTO TABLE gt_filters.
          ENDIF.
          ASSIGN gt_filters[ process = lv_process ] TO FIELD-SYMBOL(<ls_filter>).

          CASE ls_line-fieldname.
            WHEN gc_field-vkorg.
              APPEND VALUE #( sign = ls_line-sign option = ls_line-opti
                              low  = ls_line-low  high   = ls_line-high ) TO <ls_filter>-vkorg.
            WHEN gc_field-vtweg.
              APPEND VALUE #( sign = ls_line-sign option = ls_line-opti
                              low  = ls_line-low  high   = ls_line-high ) TO <ls_filter>-vtweg.
            WHEN gc_field-spart.
              APPEND VALUE #( sign = ls_line-sign option = ls_line-opti
                              low  = ls_line-low  high   = ls_line-high ) TO <ls_filter>-spart.
            WHEN gc_field-auart_so.
              APPEND VALUE #( sign = ls_line-sign option = ls_line-opti
                              low  = ls_line-low  high   = ls_line-high ) TO <ls_filter>-auart_so.
            WHEN gc_field-auart_con.
              APPEND VALUE #( sign = ls_line-sign option = ls_line-opti
                              low  = ls_line-low  high   = ls_line-high ) TO <ls_filter>-auart_con.
          ENDCASE.
        ENDLOOP.
      ENDLOOP.

      gv_filters_read = abap_true.
    ENDIF.

    rt_filters = gt_filters.
  ENDMETHOD.


  METHOD evaluate.
    rv_relevant = abap_false.

*   1. Sales order must be created with reference to a contract
    IF is_key-vgbel IS INITIAL OR is_key-vgtyp <> gc_vgtyp_contract.
      RETURN.
    ENDIF.

*   2. The process needs at least one active filter line
    DATA(lt_filters) = get_filters( ).
    READ TABLE lt_filters WITH TABLE KEY process = is_key-process INTO DATA(ls_filter).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

*   3. Sales Area + Sales Order Type (a field without lines = all values)
    IF  is_key-vkorg NOT IN ls_filter-vkorg
     OR is_key-vtweg NOT IN ls_filter-vtweg
     OR is_key-spart NOT IN ls_filter-spart
     OR is_key-auart NOT IN ls_filter-auart_so.
      RETURN.
    ENDIF.

*   4. Contract type of the referenced contract (only read if restricted)
    IF ls_filter-auart_con IS NOT INITIAL.
      SELECT SINGLE auart FROM vbak
        WHERE vbeln = @is_key-vgbel
        INTO @DATA(lv_auart_con).
      IF sy-subrc <> 0 OR lv_auart_con NOT IN ls_filter-auart_con.
        RETURN.
      ENDIF.
    ENDIF.

    rv_relevant = abap_true.
  ENDMETHOD.


  METHOD is_locked_field.
*   Screen fields closed in VA01 (TSD 3.2). Names to be confirmed per
*   screen with F1 > Technical Information (TSD open item).
    CASE iv_screen_name.
      WHEN 'RV45A-MABNR'          " Material   - overview / item detail
        OR 'VBAP-MATNR'
        OR 'RV45A-KWMENG'         " Quantity   - overview
        OR 'VBAP-KWMENG'          " Quantity   - item detail
        OR 'VBAP-VRKME'           " Sales unit
        OR 'VBAP-NETWR'           " Net value
        OR 'VBAP-NETPR'.          " Net price
        rv_locked = abap_true.
      WHEN OTHERS.
        rv_locked = abap_false.
    ENDCASE.
  ENDMETHOD.


  METHOD get_locked_fcodes.
    rt_fcodes = VALUE #( ( gc_fcode-insert_item )
                         ( gc_fcode-delete_item ) ).
  ENDMETHOD.


  METHOD config_display_on.
    IF  cv_trtyp = 'H'                                    " create (VA01)
    AND is_vbak-vgbel IS NOT INITIAL
    AND is_vbak-vgtyp = gc_vgtyp_contract
    AND is_relevant( is_vbak = is_vbak iv_process = gc_process-create ) = abap_true.
      gv_saved_trtyp = cv_trtyp.
      cv_trtyp       = 'A'.                               " display (as VA03)
    ENDIF.
  ENDMETHOD.


  METHOD config_display_off.
    IF gv_saved_trtyp IS NOT INITIAL.
      cv_trtyp = gv_saved_trtyp.
      CLEAR gv_saved_trtyp.
    ENDIF.
  ENDMETHOD.


  METHOD is_current_doc_relevant.
    rv_relevant = xsdbool( gv_evaluated = abap_true AND gv_last_relevant = abap_true ).
  ENDMETHOD.

ENDCLASS.
