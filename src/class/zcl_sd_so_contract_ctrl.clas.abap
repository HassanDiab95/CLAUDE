"! <p>SD: Control of Sales Orders created with reference to a Contract.</p>
"! Filter logic against the range table ZSD_SO_CON_FLT (TSD CH4323, chapter 2/3).
"! Each RULE_ID holds select-option style lines (SIGN/OPTION/LOW/HIGH) per
"! field. Lines of the same field are combined like a select-option (OR),
"! different fields are combined with AND.
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

    "! Filter of one rule: one range table per field
    TYPES:
      BEGIN OF ty_filter,
        rule_id   TYPE ze_sd_rule_id,
        vkorg     TYPE ty_r_vkorg,
        vtweg     TYPE ty_r_vtweg,
        spart     TYPE ty_r_spart,
        auart_so  TYPE ty_r_auart_so,
        auart_con TYPE ty_r_auart_con,
      END OF ty_filter.
    TYPES tt_filter TYPE SORTED TABLE OF ty_filter WITH UNIQUE KEY rule_id.

    CONSTANTS gc_vgtyp_contract TYPE vbak-vgtyp VALUE 'G'.

    CONSTANTS:
      BEGIN OF gc_field,
        vkorg     TYPE ze_sd_flt_field VALUE 'VKORG',
        vtweg     TYPE ze_sd_flt_field VALUE 'VTWEG',
        spart     TYPE ze_sd_flt_field VALUE 'SPART',
        auart_so  TYPE ze_sd_flt_field VALUE 'AUART_SO',
        auart_con TYPE ze_sd_flt_field VALUE 'AUART_CON',
      END OF gc_field.

    "! Returns abap_true when the sales order header matches an active rule:
    "! VGBEL filled + VGTYP = 'G' + Sales Area + SO Type + Contract Type.
    CLASS-METHODS is_relevant
      IMPORTING is_vbak            TYPE vbak
      RETURNING VALUE(rv_relevant) TYPE abap_bool.

    "! Active filter rules from ZSD_SO_CON_FLT as range tables (buffered).
    CLASS-METHODS get_filters
      RETURNING VALUE(rt_filters) TYPE tt_filter.

    "! Returns abap_true when the screen field has to be closed for input.
    CLASS-METHODS is_locked_field
      IMPORTING iv_screen_name   TYPE csequence
      RETURNING VALUE(rv_locked) TYPE abap_bool.

    "! Result of the last IS_RELEVANT evaluation (used outside SAPMV45A,
    "! e.g. pricing screens in SAPLV69A where VBAK is not available).
    CLASS-METHODS is_current_doc_relevant
      RETURNING VALUE(rv_relevant) TYPE abap_bool.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_key,
        vgbel TYPE vbak-vgbel,
        vgtyp TYPE vbak-vgtyp,
        auart TYPE vbak-auart,
        vkorg TYPE vbak-vkorg,
        vtweg TYPE vbak-vtweg,
        spart TYPE vbak-spart,
      END OF ty_key.

    CLASS-DATA gs_last_key      TYPE ty_key.
    CLASS-DATA gv_last_relevant TYPE abap_bool.
    CLASS-DATA gv_evaluated     TYPE abap_bool.
    CLASS-DATA gt_filters       TYPE tt_filter.
    CLASS-DATA gv_filters_read  TYPE abap_bool.

    CLASS-METHODS evaluate
      IMPORTING is_key             TYPE ty_key
      RETURNING VALUE(rv_relevant) TYPE abap_bool.
ENDCLASS.


CLASS zcl_sd_so_contract_ctrl IMPLEMENTATION.

  METHOD is_relevant.
    DATA(ls_key) = VALUE ty_key( vgbel = is_vbak-vgbel
                                 vgtyp = is_vbak-vgtyp
                                 auart = is_vbak-auart
                                 vkorg = is_vbak-vkorg
                                 vtweg = is_vbak-vtweg
                                 spart = is_vbak-spart ).

    IF gv_evaluated = abap_false OR ls_key <> gs_last_key.
      gs_last_key      = ls_key.
      gv_last_relevant = evaluate( ls_key ).
      gv_evaluated     = abap_true.
    ENDIF.

    rv_relevant = gv_last_relevant.
  ENDMETHOD.


  METHOD get_filters.
    DATA ls_filter TYPE ty_filter.

    IF gv_filters_read = abap_false.
      SELECT rule_id, fieldname, sign, opti, low, high
        FROM zsd_so_con_flt
        WHERE active = @abap_true
        ORDER BY rule_id, fieldname, seqno
        INTO TABLE @DATA(lt_lines).

      LOOP AT lt_lines INTO DATA(ls_line) GROUP BY ls_line-rule_id INTO DATA(lv_rule_id).
        CLEAR ls_filter.
        ls_filter-rule_id = lv_rule_id.

        LOOP AT GROUP lv_rule_id INTO DATA(ls_member).
          CASE ls_member-fieldname.
            WHEN gc_field-vkorg.
              APPEND VALUE #( sign = ls_member-sign option = ls_member-opti
                              low  = ls_member-low  high   = ls_member-high ) TO ls_filter-vkorg.
            WHEN gc_field-vtweg.
              APPEND VALUE #( sign = ls_member-sign option = ls_member-opti
                              low  = ls_member-low  high   = ls_member-high ) TO ls_filter-vtweg.
            WHEN gc_field-spart.
              APPEND VALUE #( sign = ls_member-sign option = ls_member-opti
                              low  = ls_member-low  high   = ls_member-high ) TO ls_filter-spart.
            WHEN gc_field-auart_so.
              APPEND VALUE #( sign = ls_member-sign option = ls_member-opti
                              low  = ls_member-low  high   = ls_member-high ) TO ls_filter-auart_so.
            WHEN gc_field-auart_con.
              APPEND VALUE #( sign = ls_member-sign option = ls_member-opti
                              low  = ls_member-low  high   = ls_member-high ) TO ls_filter-auart_con.
          ENDCASE.
        ENDLOOP.

*       All fields are mandatory: an empty range would match everything,
*       so incomplete rules are ignored.
        IF ls_filter-vkorg     IS NOT INITIAL
       AND ls_filter-vtweg     IS NOT INITIAL
       AND ls_filter-spart     IS NOT INITIAL
       AND ls_filter-auart_so  IS NOT INITIAL
       AND ls_filter-auart_con IS NOT INITIAL.
          INSERT ls_filter INTO TABLE gt_filters.
        ENDIF.
      ENDLOOP.

      gv_filters_read = abap_true.
    ENDIF.

    rt_filters = gt_filters.
  ENDMETHOD.


  METHOD evaluate.
    DATA lt_candidates TYPE tt_filter.

    rv_relevant = abap_false.

*   1. Sales order must be created with reference to a contract
    IF is_key-vgbel IS INITIAL OR is_key-vgtyp <> gc_vgtyp_contract.
      RETURN.
    ENDIF.

*   2. Rules whose Sales Area + Sales Order Type ranges match the order
    DATA(lt_filters) = get_filters( ).
    LOOP AT lt_filters INTO DATA(ls_filter).
      IF  is_key-vkorg IN ls_filter-vkorg
      AND is_key-vtweg IN ls_filter-vtweg
      AND is_key-spart IN ls_filter-spart
      AND is_key-auart IN ls_filter-auart_so.
        INSERT ls_filter INTO TABLE lt_candidates.
      ENDIF.
    ENDLOOP.
    IF lt_candidates IS INITIAL.
      RETURN.
    ENDIF.

*   3. Contract type of the referenced contract must be in the rule's range
    SELECT SINGLE auart FROM vbak
      WHERE vbeln = @is_key-vgbel
      INTO @DATA(lv_auart_con).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    LOOP AT lt_candidates INTO ls_filter.
      IF lv_auart_con IN ls_filter-auart_con.
        rv_relevant = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
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


  METHOD is_current_doc_relevant.
    rv_relevant = xsdbool( gv_evaluated = abap_true AND gv_last_relevant = abap_true ).
  ENDMETHOD.

ENDCLASS.
