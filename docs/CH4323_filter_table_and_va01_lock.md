# CH4323 – Filter Table & VA01 Field Lock (Technical Design)

Scope: TSD chapter 2 (Dynamic Z Configuration Table) and chapter 3 (VA01 applicability check + field locking).
VA02 change detection, delivery block and workflow (chapters 4–6) are not part of this delivery.

## 1. Filter concept

The filter table works like a select-option (similar to TVARVC). Each line holds **one single value or one from–to range**
for one field. One field can have as many lines as needed. Example:

| Line | Field     | Sign | Option | Low  | High |
|------|-----------|------|--------|------|------|
| 1    | AUART_SO  | I    | EQ     | ZOP  |      |
| 2    | AUART_SO  | I    | EQ     | ZICE |      |
| 3    | AUART_SO  | I    | EQ     | ZICO |      |
| 4    | VTWEG     | I    | EQ     | 20   |      |
| 5    | VTWEG     | I    | EQ     | 60   |      |
| 6    | VKORG     | I    | BT     | 2000 | 2999 |

How the lines are evaluated:
- Lines of the **same field** are combined like a select-option. Order type ZOP **or** ZICE **or** ZICO.
- **Different fields** are combined with AND. Order type in the list **and** channel in the list **and** sales org in the range, and so on.
- **Fields are optional.** A field without active lines is not restricted. You can, for example, maintain only VKORG, only the
  distribution channel, or only the order type. The check for a reference to a contract (`VGBEL` filled, `VGTYP = 'G'`) always applies.
- Lines are grouped by **PROCESS**, which links them to the transaction:

  | PROCESS | Used by | Effect |
  |---------|---------|--------|
  | VA01 | Create sales order | Field lock (this delivery) |
  | VA02 | Change sales order | Change detection, delivery block and approval workflow (TSD ch. 4–6) |
  | BOTH | VA01 **and** VA02 | The line is added to the VA01 filter and to the VA02 filter |

  A process with no active lines (including BOTH lines) is switched off. For example, with no VA01 or BOTH lines there is no field lock.
  BOTH lines are combined with the process's own lines in the same way as other lines (same field = OR, different fields = AND).

## 2. DDIC objects

### 2.1 Domains (SE11)

| Domain           | Type | Len | Value table / fixed values | Description |
|------------------|------|-----|----------------------------|-------------|
| ZD_SD_VKORG      | CHAR | 4   | Value table TVKO           | Sales Organization |
| ZD_SD_VTWEG      | CHAR | 2   | Value table TVTW           | Distribution Channel |
| ZD_SD_SPART      | CHAR | 2   | Value table TSPA           | Division |
| ZD_SD_AUART_SO   | CHAR | 4   | Value table TVAK           | Sales Order Type |
| ZD_SD_AUART_CON  | CHAR | 4   | Value table TVAK           | Contract Type |
| ZD_SD_FLT_FIELD  | CHAR | 10  | Fixed values: `VKORG` Sales Organization, `VTWEG` Distribution Channel, `SPART` Division, `AUART_SO` Sales Order Type, `AUART_CON` Contract Type | Filter field name |
| ZD_SD_FLT_VALUE  | CHAR | 10  | –  (upper case)            | Filter value (Low/High) |
| ZD_SD_PROCESS    | CHAR | 4   | Fixed values: `VA01` Create sales order, `VA02` Change sales order, `BOTH` VA01 and VA02 | Process |
| ZD_SD_FLT_SEQNO  | NUMC | 4   | –                          | Line number |

Notes:
- Do **not** set conversion routine AUART on ZD_SD_AUART_SO / ZD_SD_AUART_CON. The table stores internal order type keys (for example `TA`, not `OR`).
  This keeps the values comparable with VBAK-AUART. Z order types such as ZOP are the same internally and externally.
- Leave "Lower case" unchecked on all domains.

### 2.2 Data elements

| Data element     | Domain          | Field label (short / medium) |
|------------------|-----------------|------------------------------|
| ZE_SD_VKORG      | ZD_SD_VKORG     | SOrg / Sales Organization |
| ZE_SD_VTWEG      | ZD_SD_VTWEG     | DChl / Distribution Channel |
| ZE_SD_SPART      | ZD_SD_SPART     | Dv / Division |
| ZE_SD_AUART_SO   | ZD_SD_AUART_SO  | SO Type / Sales Order Type |
| ZE_SD_AUART_CON  | ZD_SD_AUART_CON | Con.Type / Contract Type |
| ZE_SD_FLT_FIELD  | ZD_SD_FLT_FIELD | Field / Filter Field |
| ZE_SD_FLT_LOW    | ZD_SD_FLT_VALUE | From / Value From |
| ZE_SD_FLT_HIGH   | ZD_SD_FLT_VALUE | To / Value To |
| ZE_SD_PROCESS    | ZD_SD_PROCESS   | Process / Process |
| ZE_SD_FLT_SEQNO  | ZD_SD_FLT_SEQNO | No. / Line Number |

SIGN and OPTION use the standard data elements **DDSIGN** (I/E) and **DDOPTION** (EQ, NE, BT, NB, CP, NP, GT, GE, LT, LE).
Their fixed values give F4 help in SM30.
ACTIVE uses the standard data element **XFELD** and is shown as a checkbox in SM30.

### 2.3 Filter table `ZSD_SO_CON_FLT` (`src/ddic/zsd_so_con_flt.tabl.ddl`)

| Field     | Key | Data element    | Meaning |
|-----------|-----|-----------------|---------|
| MANDT     | X   | MANDT           | Client |
| PROCESS   | X   | ZE_SD_PROCESS   | VA01 / VA02 / BOTH |
| FIELDNAME | X   | ZE_SD_FLT_FIELD | VKORG / VTWEG / SPART / AUART_SO / AUART_CON |
| SEQNO     | X   | ZE_SD_FLT_SEQNO | Line number within the field |
| SIGN      |     | DDSIGN          | I = include, E = exclude |
| OPTI      |     | DDOPTION        | EQ, BT, CP, … |
| LOW       |     | ZE_SD_FLT_LOW   | Single value / From |
| HIGH      |     | ZE_SD_FLT_HIGH  | To (only with BT/NB) |
| ACTIVE    |     | XFELD           | Checkbox: X = line is active |

Delivery class **C**, data maintenance allowed. It is transported through a customizing request.

TSD example as table entries:

| PROCESS | FIELDNAME | SEQNO | SIGN | OPTI | LOW  | HIGH | ACTIVE |
|---------|-----------|-------|------|------|------|------|--------|
| BOTH    | VKORG     | 0001  | I    | EQ   | 2000 |      | X |
| BOTH    | VTWEG     | 0001  | I    | EQ   | 20   |      | X |
| BOTH    | VTWEG     | 0002  | I    | EQ   | 60   |      | X |
| BOTH    | SPART     | 0001  | I    | EQ   | 00   |      | X |
| BOTH    | AUART_SO  | 0001  | I    | EQ   | ZOP  |      | X |
| BOTH    | AUART_SO  | 0002  | I    | EQ   | ZICE |      | X |
| BOTH    | AUART_SO  | 0003  | I    | EQ   | ZICO |      | X |
| BOTH    | AUART_CON | 0001  | I    | EQ   | ZCPC |      | X |

Minimal example: only one line, `VA01 VKORG I EQ 2000`. This locks every VA01 order with reference to a contract in sales org 2000.

### 2.4 Range table types and the filter table type (optional)

The class does not need these DDIC types. It types the filter itself as `TYPE RANGE OF vbak-...`
(`ZCL_SD_SO_CONTRACT_CTRL=>TY_FILTER` / `TT_FILTER`). Create them only if the filter is needed as a DDIC type elsewhere.


| Object               | Kind                     | Definition |
|----------------------|--------------------------|------------|
| ZTT_SD_R_VKORG       | Table type – Ranges      | Data element ZE_SD_VKORG |
| ZTT_SD_R_VTWEG       | Table type – Ranges      | Data element ZE_SD_VTWEG |
| ZTT_SD_R_SPART       | Table type – Ranges      | Data element ZE_SD_SPART |
| ZTT_SD_R_AUART_SO    | Table type – Ranges      | Data element ZE_SD_AUART_SO |
| ZTT_SD_R_AUART_CON   | Table type – Ranges      | Data element ZE_SD_AUART_CON |
| ZSSD_SO_CON_FILTER   | Structure                | PROCESS + one range table per field (`src/ddic/zssd_so_con_filter.stru.ddl`) |
| ZTT_SD_SO_CON_FILTER | Table type               | Line type ZSSD_SO_CON_FILTER, sorted, unique key PROCESS |

To create a range table type: SE11 → Data type → Table type → "Edit" → "Define as ranges table type".
Enter the data element, and SE11 generates the row structure with SIGN/OPTION/LOW/HIGH (structure name e.g. `ZSD_S_R_VKORG`).

At runtime, `ZCL_SD_SO_CONTRACT_CTRL=>GET_FILTERS` reads the active table lines and fills `ZCL_SD_SO_CONTRACT_CTRL=>TT_FILTER`, one entry per process (VA01, VA02). BOTH lines go into both entries.
The values are then checked with `IN`.

### 2.5 Table maintenance

1. SE11 → Utilities → Table Maintenance Generator: authorization group (e.g. `ZSD`), function group `ZSD_SO_CON_FLT`, one-step, standard recording routine.
2. Event **01** (before save) → `FORM zsd_so_con_flt_before_save` (`src/ddic/zsd_so_con_flt_tmg_events.abap`). It checks:
   - PROCESS is VA01, VA02 or BOTH. Sign, Option and Low are mandatory.
   - Low/High are not longer than the field (4 for VKORG/AUART, 2 for VTWEG/SPART).
   - BT/NB need High ≥ Low. Other options must not have a High value.
   - EQ/NE values must exist in TVKO/TVTW/TSPA/TVAK. AUART_SO must be a sales order type (VBTYP `C`) and AUART_CON a contract type (VBTYP `G`).
3. Create a parameter transaction (e.g. `ZSD_SOCON`) on SM30 for business users.

## 3. Filter logic – `ZCL_SD_SO_CONTRACT_CTRL=>IS_RELEVANT`

Source: `src/class/zcl_sd_so_contract_ctrl.clas.abap`

```
IS_RELEVANT( is_vbak, iv_process )   iv_process = 'VA01' (create) / 'VA02' (change)

VBAK-VGBEL is initial OR VBAK-VGTYP <> 'G'                -> not relevant
No active lines for the process (own + BOTH)             -> not relevant
VBAK-VKORG NOT IN vkorg OR VBAK-VTWEG NOT IN vtweg OR
VBAK-SPART NOT IN spart OR VBAK-AUART NOT IN auart_so      -> not relevant
   (a field without lines = empty range = all values)
AUART_CON lines exist:
   contract type (VBAK-AUART of VGBEL) NOT IN auart_con   -> not relevant
otherwise                                                -> RELEVANT
```

- The filter table is read once per internal session.
- The result is buffered per process/VGBEL/VGTYP/AUART/sales area, because `USEREXIT_FIELD_MODIFICATION` runs for every screen field.

## 4. Field lock in VA01 – MV45AFZZ `USEREXIT_FIELD_MODIFICATION`

Source: `src/enhancement/mv45afzz_userexit_field_modification.abap`

- The lock only applies in create mode (`T180-TRTYP = 'H'`), only when `VBAK-VGBEL` is filled and `VBAK-VGTYP = 'G'`, and only when `IS_RELEVANT` returns true.
- Fields closed (`SCREEN-INPUT = 0`): `RV45A-MABNR`, `VBAP-MATNR`, `RV45A-KWMENG`, `VBAP-KWMENG`, `VBAP-VRKME`, `VBAP-NETWR`, `VBAP-NETPR`.
  The list is in `IS_LOCKED_FIELD`. Confirm each name with F1 → Technical Information.
- **Insert / Delete item disabled (like VA03).** The item functions are function codes, so they cannot be closed with `SCREEN-INPUT`:

  | Part | Object | Effect |
  |------|--------|--------|
  | FORM `CUA_SETZEN` (end), `mv45af0c_cua_setzen.abap` | Excludes POAN (Insert Row) and POLO (Delete Item) from the GUI status via `CUA_EXCLUDE` | Buttons greyed out, menu entries hidden |
  | MV45AFZB `USEREXIT_CHECK_VBAP`, `mv45afzb_userexit_check_vbap.abap` | Error for an item without `VBAP-VGBEL` (not from the contract), except system sub-items | No new items by any route |
  | MV45AFZB `USEREXIT_CHECK_XVBAP_FOR_DELET`, `mv45afzb_userexit_check_xvbap_for_delet.abap` | `US_ERROR = 'X'` | No deletion by any route |
  | FORM `CUA_SETZEN` (same enhancement) | Also excludes the item configuration function (`GC_FCODE-CONFIG_ITEM`, placeholder `POKO`, verify) | Configuration screen cannot be opened |
  | MV45AFZZ `USEREXIT_SAVE_DOCUMENT_PREPARE`, `mv45afzz_userexit_save_document_prepare.abap` | `IS_CONFIG_CHANGED` compares the item characteristic values (`VC_I_GET_CONFIGURATION`) with the contract item | Save cancelled if the configuration differs |

  The characteristic value screen belongs to Variant Configuration (function group CEI0), not SAPMV45A, so single characteristics
  cannot be closed with `SCREEN-INPUT` without modifying SAP standard.

  The function codes are held in `ZCL_SD_SO_CONTRACT_CTRL=>GC_FCODE` / `GET_LOCKED_FCODES`.
- Optional: `src/enhancement/lv69afzz_userexit_field_modification.abap` locks the copied price (`KOMV-KBETR`) on the item condition screen.
- Copy control is not changed.

## 5. Unit test scenarios

| # | Scenario | Expected |
|---|----------|----------|
| 1 | VA01 ZOP / 2000-20-00 with reference to contract ZCPC, BOTH lines as above | Fields are locked |
| 2 | Same as 1 with ZICE, and with channel 60 | Fields are locked (more than one value per field) |
| 3 | VKORG entered as BT 2000–2999, order in 2500 | Fields are locked (range) |
| 4 | Extra line `AUART_SO E EQ ZICO` | ZICO is no longer locked |
| 5 | All VA01 and BOTH lines ACTIVE = blank | Fields are editable |
| 6 | VA01 without reference / with reference to a quotation (VGTYP B) | Fields are editable |
| 7 | Reference to a contract type not in AUART_CON | Fields are editable |
| 8 | SM30: BT without High, unknown VKORG, contract type in AUART_SO, process not VA01/VA02/BOTH | Save is rejected |
| 9 | VA02 on the order from scenario 1 | Fields are editable (handled by the TSD ch. 4 workflow) |
| 10 | Only line `VA01 VKORG I EQ 2000`, VA01 order with ref. to contract in 2000, any type/channel | Fields are locked |
| 11 | Same lines but with PROCESS = VA02 only | VA01 fields are editable |

## 6. Open points / decisions

- **Object names**: all names (table, domains, data elements, types) are proposals (TSD open item).
- **F4 on Low/High in SM30**: LOW/HIGH are generic CHAR 10, so they have no value help per field. Values are validated on save.
  If F4 is required, add a `PROCESS ON VALUE-REQUEST` module in the generated maintenance screen that calls the search help for the current FIELDNAME.
- **New items in VA01**: blocked (Insert Row disabled, material locked on empty rows, and `USEREXIT_CHECK_VBAP` as a safety net).
- **Function codes / exclusion table**: confirm POAN/POLO and `CUA_EXCLUDE` in your release (see creation guide, step 9a).
- **Variant configuration characteristics**: the configuration function is disabled in VA01 and checked on save against the contract. Confirm the function code and the characteristics in scope.