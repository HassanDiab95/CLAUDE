# CH4323 – Step-by-Step Creation Guide (all objects + code)

Sales Order with reference to Contract: dynamic filter table + VA01 field lock.

Create the objects **in this order**, because each step uses objects from the steps before it.
Use one package (e.g. `ZSD_CH4323`) and a workbench transport. SM30 entries go on a customizing transport.

| Step | Object | Type | Tool |
|------|--------|------|------|
| 1 | ZD_SD_* | Domains (9) | SE11 |
| 2 | ZE_SD_* | Data elements (10) | SE11 |
| 3 | ZSD_SO_CON_FLT | Filter table | SE11 / ADT |
| 4 | ZSD_SO_CON_FLT | Table maintenance + save checks | SE11 / SE80 |
| 5 | ZTT_SD_R_* | Range table types (5) – optional | SE11 |
| 6 | ZSSD_SO_CON_FILTER | Structure – optional | SE11 / ADT |
| 7 | ZTT_SD_SO_CON_FILTER | Table type – optional | SE11 |
| 8 | ZCL_SD_SO_CONTRACT_CTRL | Class | SE24 / ADT |
| 9 | ZSD_SO_CON_FIELD_LOCK | Enhancement in MV45AFZZ | SE38 / SE80 |
| 10 | ZSD_SO_CON_PRICE_LOCK | Enhancement in LV69AFZZ (optional) | SE38 / SE80 |
| 11 | ZSD_SOCON | Parameter transaction for SM30 | SE93 |
| 12 | – | Maintain filter data + test | SM30 / VA01 |

---

## Step 1 – Domains (SE11 → Domain)

For every domain: Definition tab → data type and length. Leave **Lower case** unchecked and leave **Conversion routine** empty.

| Domain | Short description | Data type | Length | Value range tab |
|--------|-------------------|-----------|--------|-----------------|
| ZD_SD_VKORG | Sales Organization | CHAR | 4 | Value table: TVKO |
| ZD_SD_VTWEG | Distribution Channel | CHAR | 2 | Value table: TVTW |
| ZD_SD_SPART | Division | CHAR | 2 | Value table: TSPA |
| ZD_SD_AUART_SO | Sales Order Type | CHAR | 4 | Value table: TVAK |
| ZD_SD_AUART_CON | Contract Type | CHAR | 4 | Value table: TVAK |
| ZD_SD_FLT_FIELD | Filter Field Name | CHAR | 10 | Fixed values (see below) |
| ZD_SD_FLT_VALUE | Filter Value (Low/High) | CHAR | 10 | – |
| ZD_SD_RULE_ID | Filter Rule ID | CHAR | 10 | – |
| ZD_SD_FLT_SEQNO | Filter Line Number | NUMC | 4 | – |

Fixed values for **ZD_SD_FLT_FIELD**:

| Fixed value | Short description |
|-------------|-------------------|
| VKORG | Sales Organization |
| VTWEG | Distribution Channel |
| SPART | Division |
| AUART_SO | Sales Order Type |
| AUART_CON | Contract Type |

Do not set conversion routine AUART on the order type domains. The table stores the internal key (e.g. `TA`, not `OR`), so it can be compared directly with VBAK-AUART.

The **Active** field needs no own domain. It uses the standard data element **XFELD** (checkbox).

Activate all domains.

## Step 2 – Data elements (SE11 → Data type → Data element)

| Data element | Domain | Short / Medium / Long label |
|--------------|--------|-----------------------------|
| ZE_SD_VKORG | ZD_SD_VKORG | SOrg / Sales Org. / Sales Organization |
| ZE_SD_VTWEG | ZD_SD_VTWEG | DChl / Distr. Channel / Distribution Channel |
| ZE_SD_SPART | ZD_SD_SPART | Dv / Division / Division |
| ZE_SD_AUART_SO | ZD_SD_AUART_SO | SO Type / Sales Ord. Type / Sales Order Type |
| ZE_SD_AUART_CON | ZD_SD_AUART_CON | Con.Type / Contract Type / Contract Type |
| ZE_SD_FLT_FIELD | ZD_SD_FLT_FIELD | Field / Filter Field / Filter Field |
| ZE_SD_FLT_LOW | ZD_SD_FLT_VALUE | From / Value From / Value From |
| ZE_SD_FLT_HIGH | ZD_SD_FLT_VALUE | To / Value To / Value To |
| ZE_SD_RULE_ID | ZD_SD_RULE_ID | Rule / Filter Rule / Filter Rule |
| ZE_SD_FLT_SEQNO | ZD_SD_FLT_SEQNO | No. / Line Number / Line Number |

Standard data elements reused in the table (do not create them):
- **DDSIGN**: Sign, I = include / E = exclude
- **DDOPTION**: Option, EQ / NE / BT / NB / CP / NP / GT / GE / LT / LE
- **XFELD**: Active checkbox

Activate all data elements.

## Step 3 – Filter table ZSD_SO_CON_FLT

**SE11 → Database table → ZSD_SO_CON_FLT**
- Short description: `SD: SO with Ref. to Contract - Filter Ranges`
- Delivery and Maintenance tab: Delivery class **C**, Data Browser/Table View Maint. **Display/Maintenance Allowed**

| Field | Key | Initial values | Data element | Description |
|-------|-----|----------------|--------------|-------------|
| MANDT | X | X | MANDT | Client |
| RULE_ID | X | X | ZE_SD_RULE_ID | Filter rule |
| FIELDNAME | X | X | ZE_SD_FLT_FIELD | VKORG / VTWEG / SPART / AUART_SO / AUART_CON |
| SEQNO | X | X | ZE_SD_FLT_SEQNO | Line number |
| SIGN | | | DDSIGN | I / E |
| OPTI | | | DDOPTION | EQ, BT, … |
| LOW | | | ZE_SD_FLT_LOW | Single value / From |
| HIGH | | | ZE_SD_FLT_HIGH | To (only BT / NB) |
| ACTIVE | | | XFELD | **Checkbox**: X = line active |

Technical settings: Data class **APPL2**, Size category **0**, Buffering **not allowed** (the class buffers per session).
Enhancement category: *Can't be enhanced*.

The same table in ADT source form (`src/ddic/zsd_so_con_flt.tabl.ddl`):

```
@EndUserText.label : 'SD: SO with Ref. to Contract - Filter Ranges'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zsd_so_con_flt {

  key mandt     : mandt not null;
  key rule_id   : ze_sd_rule_id not null;
  key fieldname : ze_sd_flt_field not null;
  key seqno     : ze_sd_flt_seqno not null;
  sign          : ddsign;
  opti          : ddoption;
  low           : ze_sd_flt_low;
  high          : ze_sd_flt_high;
  active        : xfeld;

}
```

## Step 4 – Table maintenance generator + save checks

1. SE11 → ZSD_SO_CON_FLT → *Utilities → Table Maintenance Generator*
   - Authorization group: `ZSD` (or &NC&)
   - Function group: `ZSD_SO_CON_FLT`
   - Maintenance type: **one step**, overview screen **0001**
   - Recording routine: standard
   - Press *Find Scr. Number(s)* → *Create*.
2. **Active as checkbox**: XFELD is normally generated as a checkbox. If it is shown as an input field, open screen 0001 of function group
   ZSD_SO_CON_FLT in SE51 → Layout. Select the ACTIVE column field, convert it to a checkbox (*Edit → Convert → Checkbox*), then save and activate.
3. *Environment → Modification → Events* → New entry:
   - Event **01** (Before saving the data in the database) → Form routine `ZSD_SO_CON_FLT_BEFORE_SAVE`
   - Press the editor button. Create the forms in a new include of the function group (e.g. `LZSD_SO_CON_FLTF01`).
4. Paste the code below and activate the function group (SE80 → function group ZSD_SO_CON_FLT → Activate).

`src/ddic/zsd_so_con_flt_tmg_events.abap`:

```abap
*&---------------------------------------------------------------------*
*& Table Maintenance Generator - events for ZSD_SO_CON_FLT
*& SE11 > Utilities > Table Maintenance Generator > Environment >
*& Modification > Events
*&   Event 01 (Before saving the data in the database)
*&     -> FORM ZSD_SO_CON_FLT_BEFORE_SAVE
*&---------------------------------------------------------------------*
FORM zsd_so_con_flt_before_save.

  TYPES:
    BEGIN OF ty_rule_field,
      rule_id   TYPE ze_sd_rule_id,
      fieldname TYPE ze_sd_flt_field,
    END OF ty_rule_field.

  DATA lt_active TYPE SORTED TABLE OF ty_rule_field WITH UNIQUE KEY rule_id fieldname.
  DATA lt_rules  TYPE SORTED TABLE OF ze_sd_rule_id WITH UNIQUE KEY table_line.
  DATA ls_line   TYPE zsd_so_con_flt.
  DATA lv_error  TYPE abap_bool.

  LOOP AT total.
    ls_line = <vim_total_struc>.

*   Deleted lines: only the completeness of their rule is re-checked
    IF <action> = geloescht OR <action> = neuer_geloescht OR <action> = update_geloescht.
      INSERT ls_line-rule_id INTO TABLE lt_rules.
      CONTINUE.
    ENDIF.

    IF <action> = neuer_eintrag OR <action> = aendern.
      PERFORM zsd_so_con_flt_check_line USING ls_line CHANGING lv_error.
      IF lv_error = abap_true.
        vim_abort_saving = abap_true.
        sy-subrc = 4.
        RETURN.
      ENDIF.
      INSERT ls_line-rule_id INTO TABLE lt_rules.
    ENDIF.

    IF ls_line-active = abap_true.
      INSERT VALUE #( rule_id = ls_line-rule_id fieldname = ls_line-fieldname ) INTO TABLE lt_active.
    ENDIF.
  ENDLOOP.

* Every rule with active lines must restrict all 5 fields (all mandatory)
  LOOP AT lt_rules INTO DATA(lv_rule_id).
    CHECK line_exists( lt_active[ rule_id = lv_rule_id ] ).
    LOOP AT VALUE string_table( ( `VKORG` ) ( `VTWEG` ) ( `SPART` ) ( `AUART_SO` ) ( `AUART_CON` ) )
         INTO DATA(lv_field).
      IF NOT line_exists( lt_active[ rule_id = lv_rule_id fieldname = CONV ze_sd_flt_field( lv_field ) ] ).
        MESSAGE |Rule { lv_rule_id }: at least one active line for { lv_field } is required|
          TYPE 'S' DISPLAY LIKE 'E'.
        vim_abort_saving = abap_true.
        sy-subrc = 4.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDLOOP.

ENDFORM.


*&---------------------------------------------------------------------*
*& Checks one filter line: SIGN/OPTION/LOW/HIGH and value existence
*&---------------------------------------------------------------------*
FORM zsd_so_con_flt_check_line USING    is_line  TYPE zsd_so_con_flt
                               CHANGING cv_error TYPE abap_bool.

  DATA lv_maxlen TYPE i.

  cv_error = abap_true.

  CASE is_line-fieldname.
    WHEN 'VKORG' OR 'AUART_SO' OR 'AUART_CON'.
      lv_maxlen = 4.
    WHEN 'VTWEG' OR 'SPART'.
      lv_maxlen = 2.
    WHEN OTHERS.
      MESSAGE |Field { is_line-fieldname } is not allowed| TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
  ENDCASE.

  IF is_line-sign IS INITIAL OR is_line-opti IS INITIAL OR is_line-low IS INITIAL.
    MESSAGE |Rule { is_line-rule_id } / { is_line-fieldname }: Sign, Option and Low are mandatory|
      TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  IF strlen( is_line-low ) > lv_maxlen OR strlen( is_line-high ) > lv_maxlen.
    MESSAGE |{ is_line-fieldname }: value longer than { lv_maxlen } characters|
      TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

* From-to options need HIGH >= LOW, single-value options no HIGH
  IF is_line-opti = 'BT' OR is_line-opti = 'NB'.
    IF is_line-high IS INITIAL OR is_line-high < is_line-low.
      MESSAGE |{ is_line-fieldname }: enter a valid To value (To >= From)|
        TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
  ELSEIF is_line-high IS NOT INITIAL.
    MESSAGE |{ is_line-fieldname }: To value only allowed with option BT/NB|
      TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

* Single values (EQ/NE) must exist in the check table
  IF is_line-opti = 'EQ' OR is_line-opti = 'NE'.
    CASE is_line-fieldname.
      WHEN 'VKORG'.
        SELECT SINGLE @abap_true FROM tvko WHERE vkorg = @is_line-low INTO @DATA(lv_found).
      WHEN 'VTWEG'.
        SELECT SINGLE @abap_true FROM tvtw WHERE vtweg = @is_line-low INTO @lv_found.
      WHEN 'SPART'.
        SELECT SINGLE @abap_true FROM tspa WHERE spart = @is_line-low INTO @lv_found.
      WHEN 'AUART_SO'.
        SELECT SINGLE @abap_true FROM tvak
          WHERE auart = @is_line-low AND vbtyp = 'C' INTO @lv_found.
      WHEN 'AUART_CON'.
        SELECT SINGLE @abap_true FROM tvak
          WHERE auart = @is_line-low AND vbtyp = 'G' INTO @lv_found.
    ENDCASE.
    IF lv_found = abap_false.
      MESSAGE |{ is_line-fieldname }: value { is_line-low } does not exist or has wrong document category|
        TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
  ENDIF.

  cv_error = abap_false.

ENDFORM.
```

## Step 5 – Range table types (SE11 → Data type → Table type) – OPTIONAL

> **Steps 5–7 are optional.** The class ZCL_SD_SO_CONTRACT_CTRL defines its own range types
> (TY_R_VKORG … TY_R_AUART_CON, TY_FILTER, TT_FILTER with ). It does not use these DDIC types.
> Create them only if other programs need the filter as a DDIC type.
> A table type created **without** *Define as Ranges Table Type* has no SIGN/OPTION/LOW/HIGH columns,
> so it cannot be used with . This causes errors such as *"does not have the structure of a selection table"*.


For each entry: create a table type, then choose *Edit → Define as Ranges Table Type*.
Enter the data element as *Data element* and a structure name as *Structured row type*. Then press *Create* for the row type, activate it, and activate the table type.

| Table type | Data element | Row type (generated) |
|------------|--------------|----------------------|
| ZTT_SD_R_VKORG | ZE_SD_VKORG | ZSSD_R_VKORG |
| ZTT_SD_R_VTWEG | ZE_SD_VTWEG | ZSSD_R_VTWEG |
| ZTT_SD_R_SPART | ZE_SD_SPART | ZSSD_R_SPART |
| ZTT_SD_R_AUART_SO | ZE_SD_AUART_SO | ZSSD_R_AUART_SO |
| ZTT_SD_R_AUART_CON | ZE_SD_AUART_CON | ZSSD_R_AUART_CON |

Each generated row type has the components SIGN / OPTION / LOW / HIGH.

## Step 6 – Filter structure ZSSD_SO_CON_FILTER

SE11 → Data type → Structure → `ZSSD_SO_CON_FILTER` (`SD: SO with Ref. to Contract - Filter per Rule`)

| Component | Typing method | Component type |
|-----------|---------------|----------------|
| RULE_ID | Types | ZE_SD_RULE_ID |
| VKORG | Types | ZTT_SD_R_VKORG |
| VTWEG | Types | ZTT_SD_R_VTWEG |
| SPART | Types | ZTT_SD_R_SPART |
| AUART_SO | Types | ZTT_SD_R_AUART_SO |
| AUART_CON | Types | ZTT_SD_R_AUART_CON |

Enhancement category: *Can't be enhanced*. ADT source form:

```
@EndUserText.label : 'SD: SO with Ref. to Contract - Filter per Rule'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
define structure zssd_so_con_filter {

  rule_id   : ze_sd_rule_id;
  vkorg     : ztt_sd_r_vkorg;
  vtweg     : ztt_sd_r_vtweg;
  spart     : ztt_sd_r_spart;
  auart_so  : ztt_sd_r_auart_so;
  auart_con : ztt_sd_r_auart_con;

}
```

## Step 7 – Filter table type ZTT_SD_SO_CON_FILTER

SE11 → Data type → Table type → `ZTT_SD_SO_CON_FILTER` (`SD: SO with Ref. to Contract - Filter Rules`)
- Line type: **ZSSD_SO_CON_FILTER**
- Initialization and access: Access **Sorted table**
- Primary key: Key definition **Key components**, Key category **Unique**, component **RULE_ID**

## Step 8 – Class ZCL_SD_SO_CONTRACT_CTRL

SE24 (source-code based, *Goto → Source code based*) or ADT → new class `ZCL_SD_SO_CONTRACT_CTRL`. Description: `SD: SO with Ref. to Contract - Control`.
Replace the complete source with the code below and activate it.

| Method | Purpose |
|--------|---------|
| IS_RELEVANT | VGBEL/VGTYP check + filter check for an order header (buffered) |
| GET_FILTERS | Reads ZSD_SO_CON_FLT (active lines only) into ZTT_SD_SO_CON_FILTER |
| IS_LOCKED_FIELD | List of screen fields to close |
| IS_CURRENT_DOC_RELEVANT | Last result, used in the pricing screen |

`src/class/zcl_sd_so_contract_ctrl.clas.abap`:

```abap
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
```

## Step 9 – Enhancement in MV45AFZZ (VA01 field lock)

1. SE38 → `MV45AFZZ` → Display → search FORM `USEREXIT_FIELD_MODIFICATION`.
2. *Edit → Enhancement Operations → Show Implicit Enhancement Options*.
3. Right-click the implicit option at the **start** of the form (after `FORM USEREXIT_FIELD_MODIFICATION.`) → *Enhancement Implementation → Create* → Code.
4. Enhancement implementation: `ZSD_SO_CON_FIELD_LOCK`, short text `CH4323 VA01 lock for orders with ref. to contract`.
5. Remove the test code (`COBL-PRCTR` / `sy-tcode`), paste the code below and activate.

`src/enhancement/mv45afzz_userexit_field_modification.abap`:

```abap
*&---------------------------------------------------------------------*
*& Include MV45AFZZ - FORM USEREXIT_FIELD_MODIFICATION
*& Implicit enhancement at the start of the FORM (replaces the test
*& coding with the hard-coded COBL-PRCTR / sy-tcode check).
*&
*& Logic (TSD CH4323, 3.1 / 3.2):
*&   - Sales order in create mode (VA01)
*&   - VBAK-VGBEL is not initial and VBAK-VGTYP = 'G' (ref. to contract)
*&   - Active rule in filter table ZSD_SO_CON_FLT whose ranges contain
*&       VKORG / VTWEG / SPART / AUART_SO (= VBAK-AUART)
*&       / AUART_CON (= VBAK-AUART of the referenced contract)
*&   => close Material / Quantity / Net value fields for input
*&---------------------------------------------------------------------*
ENHANCEMENT 1 zsd_so_con_field_lock.

  IF t180-trtyp = 'H'                                         " create (VA01)
     AND vbak-vgbel IS NOT INITIAL
     AND vbak-vgtyp = zcl_sd_so_contract_ctrl=>gc_vgtyp_contract
     AND zcl_sd_so_contract_ctrl=>is_relevant( vbak ) = abap_true
     AND zcl_sd_so_contract_ctrl=>is_locked_field( screen-name ) = abap_true.
    screen-input = '0'.
    MODIFY SCREEN.
  ENDIF.

ENDENHANCEMENT.
```

## Step 10 – Enhancement in LV69AFZZ (optional – lock copied price)

Same procedure as step 9 in include `LV69AFZZ`, FORM `USEREXIT_FIELD_MODIFICATION`.
Enhancement implementation: `ZSD_SO_CON_PRICE_LOCK`.

`src/enhancement/lv69afzz_userexit_field_modification.abap`:

```abap
*&---------------------------------------------------------------------*
*& Include LV69AFZZ - FORM USEREXIT_FIELD_MODIFICATION   (optional)
*& Locks the agreed copied price on the item condition screen in VA01
*& (TSD 3.2 "Net Value / agreed copied price-related data").
*& VBAK is not available in SAPLV69A, so the result buffered by
*& USEREXIT_FIELD_MODIFICATION in MV45AFZZ is reused. That form runs on
*& the overview PBO of every order before the conditions can be opened,
*& so the buffer always belongs to the current document.
*&---------------------------------------------------------------------*
ENHANCEMENT 1 zsd_so_con_price_lock.

  IF sy-tcode = 'VA01'
     AND zcl_sd_so_contract_ctrl=>is_current_doc_relevant( ) = abap_true.
    CASE screen-name.
      WHEN 'KOMV-KBETR' OR 'KOMV-KPEIN' OR 'KOMV-KMEIN'.
        screen-input = '0'.
        MODIFY SCREEN.
    ENDCASE.
  ENDIF.

ENDENHANCEMENT.
```

## Step 11 – Parameter transaction ZSD_SOCON (SE93)

- Transaction `ZSD_SOCON`, *Transaction with parameters*. Text: `Maintain SO/Contract Control Filter`.
- Default transaction `SM30`, check *Skip initial screen*.
- Default values: `VIEWNAME = ZSD_SO_CON_FLT`, `UPDATE = X`.

## Step 12 – Maintain filter data and test

ZSD_SOCON / SM30 → ZSD_SO_CON_FLT → New entries (TSD example):

| Rule | Field | No. | Sign | Option | From | To | Active |
|------|-------|-----|------|--------|------|----|--------|
| 01 | VKORG | 0001 | I | EQ | 2000 | | ☑ |
| 01 | VTWEG | 0001 | I | EQ | 20 | | ☑ |
| 01 | VTWEG | 0002 | I | EQ | 60 | | ☑ |
| 01 | SPART | 0001 | I | EQ | 00 | | ☑ |
| 01 | AUART_SO | 0001 | I | EQ | ZOP | | ☑ |
| 01 | AUART_SO | 0002 | I | EQ | ZICE | | ☑ |
| 01 | AUART_SO | 0003 | I | EQ | ZICO | | ☑ |
| 01 | AUART_CON | 0001 | I | EQ | ZCPC | | ☑ |

Rules:
- The same field in several lines means OR (ZOP or ZICE or ZICO). Different fields mean AND.
- A from–to range is one line with option **BT**, e.g. `VKORG I BT 2000 2999`.
- An exclusion is one line with sign **E**, e.g. `AUART_SO E EQ ZICO`.
- Untick **Active** to switch a line off. If all lines of a rule are unticked, the rule is off.
- Every active rule needs at least one active line for each of the 5 fields. The save is rejected otherwise.

Test cases:

| # | Scenario | Expected |
|---|----------|----------|
| 1 | VA01 ZOP / 2000-20-00 with reference to contract ZCPC | Material, quantity and net value are display-only |
| 2 | Same with ZICE and channel 60 | Locked |
| 3 | VKORG line changed to BT 2000–2999, order in 2500 | Locked |
| 4 | Extra line AUART_SO E EQ ZICO, order ZICO | Editable |
| 5 | Active unticked on all lines of rule 01 | Editable |
| 6 | VA01 without reference, or with reference to a quotation | Editable |
| 7 | Reference to a contract type not in AUART_CON | Editable |
| 8 | SM30: rule without an AUART_CON line, BT without To, unknown VKORG, contract type in AUART_SO | Save rejected with message |
| 9 | VA02 on the order from test 1 | Editable (TSD ch. 4 handles VA02) |

Note: the filter table is read once per session. After changing SM30 entries, start a new VA01 session (/nVA01) to test.

## Open points

- All object names are proposals (TSD open item).
- Confirm the screen field names in IS_LOCKED_FIELD on your screens with F1 → Technical Information.
- Variant configuration characteristics cannot be locked with SCREEN-INPUT. This is open until the characteristics in scope are known.
- VA02 change detection, delivery block XX and the approval workflow come in the next delivery.
