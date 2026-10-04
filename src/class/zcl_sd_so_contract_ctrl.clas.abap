"! <p>SD: Control of Sales Orders created with reference to a Contract.</p>
"! Filter logic against Z table ZSD_SO_CON_CTRL (TSD CH4323, chapter 2/3).
"! The result is buffered per document because USEREXIT_FIELD_MODIFICATION
"! is called once per screen field on every PBO.
CLASS zcl_sd_so_contract_ctrl DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS gc_vgtyp_contract TYPE vbak-vgtyp VALUE 'G'.

    "! Returns abap_true when the sales order header matches an ACTIVE rule:
    "! VGBEL filled + VGTYP = 'G' + Sales Area + SO Type + Contract Type.
    CLASS-METHODS is_relevant
      IMPORTING is_vbak            TYPE vbak
      RETURNING VALUE(rv_relevant) TYPE abap_bool.

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


  METHOD evaluate.
    rv_relevant = abap_false.

*   1. Sales order must be created with reference to a contract
    IF is_key-vgbel IS INITIAL OR is_key-vgtyp <> gc_vgtyp_contract.
      RETURN.
    ENDIF.

*   2. Active rule for Sales Order Type + Sales Area must exist
    SELECT auart_con FROM zsd_so_con_ctrl
      WHERE vkorg    = @is_key-vkorg
        AND vtweg    = @is_key-vtweg
        AND spart    = @is_key-spart
        AND auart_so = @is_key-auart
        AND active   = @abap_true
      INTO TABLE @DATA(lt_auart_con).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

*   3. Contract type of the referenced contract must match the rule
    SELECT SINGLE auart FROM vbak
      WHERE vbeln = @is_key-vgbel
      INTO @DATA(lv_auart_con).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF line_exists( lt_auart_con[ auart_con = lv_auart_con ] ).
      rv_relevant = abap_true.
    ENDIF.
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
