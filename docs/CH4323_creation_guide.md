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
| 9a | ZSD_SO_CON_ITEM_FCODES | Enhancement in FORM CUA_SETZEN – disable Insert/Delete item | SE38 / SE80 |
| 9b | ZSD_SO_CON_NO_NEW_ITEM | Enhancement in MV45AFZB – reject new items (safety net) | SE38 / SE80 |
| 9c | ZSD_SO_CON_NO_DELETE_ITEM | Enhancement in MV45AFZB – reject item deletion (safety net) | SE38 / SE80 |
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
| ZD_SD_PROCESS | Process (VA01 / VA02 / BOTH) | CHAR | 4 | Fixed values (see below) |
| ZD_SD_FLT_SEQNO | Filter Line Number | NUMC | 4 | – |

Fixed values for **ZD_SD_FLT_FIELD**:

| Fixed value | Short description |
|-------------|-------------------|
| VKORG | Sales Organization |
| VTWEG | Distribution Channel |
| SPART | Division |
| AUART_SO | Sales Order Type |
| AUART_CON | Contract Type |

Fixed values for **ZD_SD_PROCESS**:

| Fixed value | Short description |
|-------------|-------------------|
| VA01 | Create sales order (field lock) |
| VA02 | Change sales order (approval) |
| BOTH | VA01 and VA02 |

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
| ZE_SD_PROCESS | ZD_SD_PROCESS | Process / Process / Process |
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
| PROCESS | X | X | ZE_SD_PROCESS | VA01 / VA02 / BOTH |
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
  key process   : ze_sd_process not null;
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

  DATA ls_line  TYPE zsd_so_con_flt.
  DATA lv_error TYPE abap_bool.

  LOOP AT total.
    CHECK <action> = neuer_eintrag OR <action> = aendern.

    ls_line = <vim_total_struc>.
    PERFORM zsd_so_con_flt_check_line USING ls_line CHANGING lv_error.
    IF lv_error = abap_true.
      vim_abort_saving = abap_true.
      sy-subrc = 4.
      RETURN.
    ENDIF.
  ENDLOOP.

ENDFORM.


*&---------------------------------------------------------------------*
*& Checks one filter line: SIGN/OPTION/LOW/HIGH and value existence
*&---------------------------------------------------------------------*
FORM zsd_so_con_flt_check_line USING    is_line  TYPE zsd_so_con_flt
                               CHANGING cv_error TYPE abap_bool.

  DATA lv_maxlen TYPE i.

  cv_error = abap_true.

  IF is_line-process <> 'VA01' AND is_line-process <> 'VA02' AND is_line-process <> 'BOTH'.
    MESSAGE |Process { is_line-process } is not allowed (VA01, VA02 or BOTH)| TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

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
    MESSAGE |{ is_line-process } / { is_line-fieldname }: Sign, Option and Low are mandatory|
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
> (TY_R_VKORG … TY_R_AUART_CON, TY_FILTER, TT_FILTER with `TYPE RANGE OF`). It does not use these DDIC types.
> Create them only if other programs need the filter as a DDIC type.
> A table type created **without** *Define as Ranges Table Type* has no SIGN/OPTION/LOW/HIGH columns,
> so it cannot be used with `IN`. This causes errors such as *"does not have the structure of a selection table"*.


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

SE11 → Data type → Structure → `ZSSD_SO_CON_FILTER` (`SD: SO with Ref. to Contract - Filter per Process`)

| Component | Typing method | Component type |
|-----------|---------------|----------------|
| PROCESS | Types | ZE_SD_PROCESS |
| VKORG | Types | ZTT_SD_R_VKORG |
| VTWEG | Types | ZTT_SD_R_VTWEG |
| SPART | Types | ZTT_SD_R_SPART |
| AUART_SO | Types | ZTT_SD_R_AUART_SO |
| AUART_CON | Types | ZTT_SD_R_AUART_CON |

Enhancement category: *Can't be enhanced*. ADT source form:

```
@EndUserText.label : 'SD: SO with Ref. to Contract - Filter per Process'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
define structure zssd_so_con_filter {

  process   : ze_sd_process;
  vkorg     : ztt_sd_r_vkorg;
  vtweg     : ztt_sd_r_vtweg;
  spart     : ztt_sd_r_spart;
  auart_so  : ztt_sd_r_auart_so;
  auart_con : ztt_sd_r_auart_con;

}
```

## Step 7 – Filter table type ZTT_SD_SO_CON_FILTER

SE11 → Data type → Table type → `ZTT_SD_SO_CON_FILTER` (`SD: SO with Ref. to Contract - Filter per Process`)
- Line type: **ZSSD_SO_CON_FILTER**
- Initialization and access: Access **Sorted table**
- Primary key: Key definition **Key components**, Key category **Unique**, component **PROCESS**

## Step 8 – Class ZCL_SD_SO_CONTRACT_CTRL

SE24 (source-code based, *Goto → Source code based*) or ADT → new class `ZCL_SD_SO_CONTRACT_CTRL`. Description: `SD: SO with Ref. to Contract - Control`.
Replace the complete source with the code below and activate it.

| Method | Purpose |
|--------|---------|
| IS_RELEVANT | VGBEL/VGTYP check + filter check of a process (VA01/VA02) for an order header (buffered) |
| GET_FILTERS | Reads ZSD_SO_CON_FLT (active lines only) into one filter per process; BOTH lines go to VA01 and VA02 |
| IS_LOCKED_FIELD | List of screen fields to close |
| IS_CURRENT_DOC_RELEVANT | Last result, used in the pricing screen |

`src/class/zcl_sd_so_contract_ctrl.clas.abap`:

```abap
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
*&   - Active filter lines of process VA01 in ZSD_SO_CON_FLT whose ranges
*&       contain VKORG / VTWEG / SPART / AUART_SO (= VBAK-AUART)
*&       / AUART_CON (= VBAK-AUART of the referenced contract)
*&       (a field without lines is not restricted)
*&   => close Material / Quantity / Net value fields for input
*&---------------------------------------------------------------------*
ENHANCEMENT 1 zsd_so_con_field_lock.

  IF t180-trtyp = 'H'                                         " create (VA01)
     AND vbak-vgbel IS NOT INITIAL
     AND vbak-vgtyp = zcl_sd_so_contract_ctrl=>gc_vgtyp_contract
     AND zcl_sd_so_contract_ctrl=>is_relevant(
           is_vbak    = vbak
           iv_process = zcl_sd_so_contract_ctrl=>gc_process-create ) = abap_true
     AND zcl_sd_so_contract_ctrl=>is_locked_field( screen-name ) = abap_true.
    screen-input = '0'.
    MODIFY SCREEN.
  ENDIF.

ENDENHANCEMENT.
```

## Step 9a – Disable "Insert Row" and "Delete Item" (like VA03)

The buttons above the item table (Insert Row = **POAN**, Delete Item = **POLO**) are function codes, not input fields.
`SCREEN-INPUT = 0` cannot close them. Instead they are removed from the GUI status, which is how VA03 does it.
An excluded function code also greys out the matching pushbutton and removes the menu entry (Edit → Insert/Delete item).

1. **Check the function codes.** Start VA01, enter `/h` in the command field, and press the Insert Row button. In the debugger, read `SY-UCOMM` (expected `POAN`).
   Do the same for Delete Item (expected `POLO`). If your codes differ, change `GC_FCODE` in the class.
2. **Check the exclusion table.** SE38 → `SAPMV45A` → search for `SET PF-STATUS`. The table after `EXCLUDING` should be `CUA_EXCLUDE`.
   If your release uses another name, change it in the code below.
3. SE38 → include `MV45AF0C_CUA_SETZEN` → FORM `CUA_SETZEN` → implicit enhancement option at the **end** of the FORM (before `ENDFORM`).
   Create enhancement implementation `ZSD_SO_CON_ITEM_FCODES`, paste the code and activate.

`src/enhancement/mv45af0c_cua_setzen.abap`:

```abap
*&---------------------------------------------------------------------*
*& SAPMV45A - FORM CUA_SETZEN   (include MV45AF0C_CUA_SETZEN)
*& Implicit enhancement at the END of the FORM.
*&
*& Removes the item functions "Insert Row" (POAN) and "Delete Item"
*& (POLO) from the GUI status in VA01 for relevant orders, like VA03.
*& Excluded function codes also make the matching pushbuttons above the
*& item table inactive (greyed out) and remove the menu entries.
*&
*& CUA_EXCLUDE is the exclusion table that SAPMV45A passes to
*& SET PF-STATUS ... EXCLUDING. Check the name in your release:
*& in the debugger, set a breakpoint on statement SET PF-STATUS.
*&---------------------------------------------------------------------*
ENHANCEMENT 1 zsd_so_con_item_fcodes.

  IF t180-trtyp = 'H'                                         " create (VA01)
     AND vbak-vgbel IS NOT INITIAL
     AND vbak-vgtyp = zcl_sd_so_contract_ctrl=>gc_vgtyp_contract
     AND zcl_sd_so_contract_ctrl=>is_relevant(
           is_vbak    = vbak
           iv_process = zcl_sd_so_contract_ctrl=>gc_process-create ) = abap_true.

    DATA(lt_zz_fcodes) = zcl_sd_so_contract_ctrl=>get_locked_fcodes( ).
    LOOP AT lt_zz_fcodes INTO DATA(lv_zz_fcode).
      cua_exclude = lv_zz_fcode.
      COLLECT cua_exclude.
    ENDLOOP.
  ENDIF.

ENDENHANCEMENT.
```

## Step 9b – Reject new items (safety net) – MV45AFZB USEREXIT_CHECK_VBAP

This catches items added any other way, for example by typing into an empty row. Items copied from the contract have `VBAP-VGBEL`; a manually added item does not.
Sub-items generated by the system (`VBAP-UEPOS` filled, e.g. free goods or BOM components) are allowed.

SE38 → `MV45AFZB` → FORM `USEREXIT_CHECK_VBAP` → implicit enhancement at the start → `ZSD_SO_CON_NO_NEW_ITEM`.

`src/enhancement/mv45afzb_userexit_check_vbap.abap`:

```abap
*&---------------------------------------------------------------------*
*& Include MV45AFZB - FORM USEREXIT_CHECK_VBAP   (safety net)
*& Implicit enhancement at the start of the FORM.
*&
*& Rejects a NEW item in VA01 for relevant orders. Items copied from the
*& contract carry VBAP-VGBEL; an item entered manually does not.
*& Covers every other way of adding items, e.g. typing into an empty
*& row or another function code than POAN.
*& Sub-items generated by the system (free goods, BOM components:
*& VBAP-UEPOS filled) are allowed.
*&---------------------------------------------------------------------*
ENHANCEMENT 1 zsd_so_con_no_new_item.

  IF t180-trtyp = 'H'                                         " create (VA01)
     AND vbap-vgbel IS INITIAL
     AND vbap-uepos IS INITIAL
     AND vbak-vgbel IS NOT INITIAL
     AND vbak-vgtyp = zcl_sd_so_contract_ctrl=>gc_vgtyp_contract
     AND zcl_sd_so_contract_ctrl=>is_relevant(
           is_vbak    = vbak
           iv_process = zcl_sd_so_contract_ctrl=>gc_process-create ) = abap_true.
    MESSAGE e398(00) WITH 'New items are not allowed for orders'
                          'with reference to contract' vbak-vgbel ''.
  ENDIF.

ENDENHANCEMENT.
```

## Step 9c – Reject item deletion (safety net) – MV45AFZB USEREXIT_CHECK_XVBAP_FOR_DELET

SE38 → `MV45AFZB` → FORM `USEREXIT_CHECK_XVBAP_FOR_DELET` → implicit enhancement at the start → `ZSD_SO_CON_NO_DELETE_ITEM`.
Read the template comment of the FORM in your system first. It explains the meaning of `US_ERROR` / `US_EXIT` in your release.

`src/enhancement/mv45afzb_userexit_check_xvbap_for_delet.abap`:

```abap
*&---------------------------------------------------------------------*
*& Include MV45AFZB - FORM USEREXIT_CHECK_XVBAP_FOR_DELET   (safety net)
*&   FORM userexit_check_xvbap_for_delet USING us_error LIKE ...
*&                                             us_exit  LIKE ...
*& Implicit enhancement at the start of the FORM.
*&
*& Prevents deleting an item in VA01 for relevant orders, in case the
*& deletion is triggered by another function than POLO.
*& US_ERROR = 'X' tells SAPMV45A that the item must not be deleted.
*& Check the template comment of this FORM in your MV45AFZB before use.
*&---------------------------------------------------------------------*
ENHANCEMENT 1 zsd_so_con_no_delete_item.

  IF t180-trtyp = 'H'                                         " create (VA01)
     AND vbak-vgbel IS NOT INITIAL
     AND vbak-vgtyp = zcl_sd_so_contract_ctrl=>gc_vgtyp_contract
     AND zcl_sd_so_contract_ctrl=>is_relevant(
           is_vbak    = vbak
           iv_process = zcl_sd_so_contract_ctrl=>gc_process-create ) = abap_true.
    us_error = 'X'.
    MESSAGE s398(00) WITH 'Items of orders with reference to contract'
                          vbak-vgbel 'cannot be deleted' '' DISPLAY LIKE 'E'.
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

| Process | Field | No. | Sign | Option | From | To | Active |
|---------|-------|-----|------|--------|------|----|--------|
| BOTH | VKORG | 0001 | I | EQ | 2000 | | ☑ |
| BOTH | VTWEG | 0001 | I | EQ | 20 | | ☑ |
| BOTH | VTWEG | 0002 | I | EQ | 60 | | ☑ |
| BOTH | SPART | 0001 | I | EQ | 00 | | ☑ |
| BOTH | AUART_SO | 0001 | I | EQ | ZOP | | ☑ |
| BOTH | AUART_SO | 0002 | I | EQ | ZICE | | ☑ |
| BOTH | AUART_SO | 0003 | I | EQ | ZICO | | ☑ |
| BOTH | AUART_CON | 0001 | I | EQ | ZCPC | | ☑ |

Rules:
- **Process**:
  - `VA01`: the line is used only when creating the order (field lock).
  - `VA02`: the line is used only when changing the order (approval).
  - `BOTH`: the line is used for VA01 and VA02.
- The same field in several lines means OR (ZOP or ZICE or ZICO). Different fields mean AND.
- **Fields are optional.** A field without lines is not restricted. For example, the single line `VA01 VKORG I EQ 2000` locks
  every VA01 order with reference to a contract in sales org 2000, whatever the channel, division or order type.
- A from–to range is one line with option **BT**, e.g. `VKORG I BT 2000 2999`.
- An exclusion is one line with sign **E**, e.g. `AUART_SO E EQ ZICO`.
- Untick **Active** to switch a line off. If a process has no active lines (its own or BOTH), the control is off for that process.

Test cases:

| # | Scenario | Expected |
|---|----------|----------|
| 1 | VA01 ZOP / 2000-20-00 with reference to contract ZCPC | Material, quantity and net value are display-only |
| 2 | Same with ZICE and channel 60 | Locked |
| 3 | VKORG line changed to BT 2000–2999, order in 2500 | Locked |
| 4 | Extra line AUART_SO E EQ ZICO, order ZICO | Editable |
| 5 | Active unticked on all VA01 and BOTH lines | Editable |
| 6 | VA01 without reference, or with reference to a quotation | Editable |
| 7 | Reference to a contract type not in AUART_CON | Editable |
| 8 | SM30: BT without To, unknown VKORG, contract type in AUART_SO, process not VA01/VA02/BOTH | Save rejected with message |
| 9a | VA01 test 1: Insert Row / Delete Item buttons | Greyed out, menu entries hidden |
| 9b | VA01 test 1: type a material into an empty row and press Enter | Error: new items not allowed |
| 9 | VA02 on the order from test 1 | Editable (TSD ch. 4 handles VA02) |
| 10 | Only line `VA01 VKORG I EQ 2000`; VA01 order with ref. to contract in 2000 | Locked |
| 11 | Same line with process VA02 | VA01 fields editable |

Note: the filter table is read once per session. After changing SM30 entries, start a new VA01 session (/nVA01) to test.

## Open points

- All object names are proposals (TSD open item).
- Confirm the screen field names in IS_LOCKED_FIELD on your screens with F1 → Technical Information.
- Variant configuration characteristics cannot be locked with SCREEN-INPUT. This is open until the characteristics in scope are known.
- VA02 change detection, delivery block XX and the approval workflow come in the next delivery.
