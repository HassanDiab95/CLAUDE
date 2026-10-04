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
- Lines are grouped by **RULE_ID**. One rule is usually enough. A second rule is only needed for a combination that must not mix with
  the first one (for example, ZOP only for sales org 2000 but ZICE only for sales org 3000). The order is locked if **any** active rule matches.
- All 5 fields are mandatory per rule. A rule without at least one active line for each field is rejected on save, and it is ignored at runtime.
  This matters because an empty range would match every order.

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
| ZD_SD_RULE_ID    | CHAR | 10  | –  (upper case)            | Filter rule ID |
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
| ZE_SD_RULE_ID    | ZD_SD_RULE_ID   | Rule / Filter Rule |
| ZE_SD_FLT_SEQNO  | ZD_SD_FLT_SEQNO | No. / Line Number |

SIGN and OPTION use the standard data elements **DDSIGN** (I/E) and **DDOPTION** (EQ, NE, BT, NB, CP, NP, GT, GE, LT, LE).
Their fixed values give F4 help in SM30.
ACTIVE uses the standard data element **XFELD** and is shown as a checkbox in SM30.

### 2.3 Filter table `ZSD_SO_CON_FLT` (`src/ddic/zsd_so_con_flt.tabl.ddl`)

| Field     | Key | Data element    | Meaning |
|-----------|-----|-----------------|---------|
| MANDT     | X   | MANDT           | Client |
| RULE_ID   | X   | ZE_SD_RULE_ID   | Rule (group of lines) |
| FIELDNAME | X   | ZE_SD_FLT_FIELD | VKORG / VTWEG / SPART / AUART_SO / AUART_CON |
| SEQNO     | X   | ZE_SD_FLT_SEQNO | Line number within the field |
| SIGN      |     | DDSIGN          | I = include, E = exclude |
| OPTI      |     | DDOPTION        | EQ, BT, CP, … |
| LOW       |     | ZE_SD_FLT_LOW   | Single value / From |
| HIGH      |     | ZE_SD_FLT_HIGH  | To (only with BT/NB) |
| ACTIVE    |     | XFELD           | Checkbox: X = line is active |

Delivery class **C**, data maintenance allowed. It is transported through a customizing request.

TSD example as table entries:

| RULE_ID | FIELDNAME | SEQNO | SIGN | OPTI | LOW  | HIGH | ACTIVE |
|---------|-----------|-------|------|------|------|------|--------|
| 01      | VKORG     | 0001  | I    | EQ   | 2000 |      | X |
| 01      | VTWEG     | 0001  | I    | EQ   | 20   |      | X |
| 01      | VTWEG     | 0002  | I    | EQ   | 60   |      | X |
| 01      | SPART     | 0001  | I    | EQ   | 00   |      | X |
| 01      | AUART_SO  | 0001  | I    | EQ   | ZOP  |      | X |
| 01      | AUART_SO  | 0002  | I    | EQ   | ZICE |      | X |
| 01      | AUART_SO  | 0003  | I    | EQ   | ZICO |      | X |
| 01      | AUART_CON | 0001  | I    | EQ   | ZCPC |      | X |

### 2.4 Range table types and the filter table type (optional)

The class does not need these DDIC types. It types the filter itself as 
( / ). Create them only if the filter is needed as a DDIC type elsewhere.


| Object               | Kind                     | Definition |
|----------------------|--------------------------|------------|
| ZTT_SD_R_VKORG       | Table type – Ranges      | Data element ZE_SD_VKORG |
| ZTT_SD_R_VTWEG       | Table type – Ranges      | Data element ZE_SD_VTWEG |
| ZTT_SD_R_SPART       | Table type – Ranges      | Data element ZE_SD_SPART |
| ZTT_SD_R_AUART_SO    | Table type – Ranges      | Data element ZE_SD_AUART_SO |
| ZTT_SD_R_AUART_CON   | Table type – Ranges      | Data element ZE_SD_AUART_CON |
| ZSSD_SO_CON_FILTER   | Structure                | RULE_ID + one range table per field (`src/ddic/zssd_so_con_filter.stru.ddl`) |
| ZTT_SD_SO_CON_FILTER | Table type               | Line type ZSSD_SO_CON_FILTER, sorted, unique key RULE_ID |

To create a range table type: SE11 → Data type → Table type → "Edit" → "Define as ranges table type".
Enter the data element, and SE11 generates the row structure with SIGN/OPTION/LOW/HIGH (structure name e.g. `ZSD_S_R_VKORG`).

At runtime, `ZCL_SD_SO_CONTRACT_CTRL=>GET_FILTERS` reads the active table lines and fills `ZTT_SD_SO_CON_FILTER`, one entry per rule.
The values are then checked with `IN`.

### 2.5 Table maintenance

1. SE11 → Utilities → Table Maintenance Generator: authorization group (e.g. `ZSD`), function group `ZSD_SO_CON_FLT`, one-step, standard recording routine.
2. Event **01** (before save) → `FORM zsd_so_con_flt_before_save` (`src/ddic/zsd_so_con_flt_tmg_events.abap`). It checks:
   - Sign, Option and Low are mandatory.
   - Low/High are not longer than the field (4 for VKORG/AUART, 2 for VTWEG/SPART).
   - BT/NB need High ≥ Low. Other options must not have a High value.
   - EQ/NE values must exist in TVKO/TVTW/TSPA/TVAK. AUART_SO must be a sales order type (VBTYP `C`) and AUART_CON a contract type (VBTYP `G`).
   - Each rule with active lines has at least one active line for all 5 fields.
3. Create a parameter transaction (e.g. `ZSD_SOCON`) on SM30 for business users.

## 3. Filter logic – `ZCL_SD_SO_CONTRACT_CTRL=>IS_RELEVANT`

Source: `src/class/zcl_sd_so_contract_ctrl.clas.abap`

```
VBAK-VGBEL is initial OR VBAK-VGTYP <> 'G'                -> not relevant
Candidate rules = active rules where
   VBAK-VKORG IN vkorg AND VBAK-VTWEG IN vtweg AND
   VBAK-SPART IN spart AND VBAK-AUART IN auart_so          (none -> not relevant)
Contract type = VBAK-AUART of VBELN = VBAK-VGBEL
Contract type IN auart_con of any candidate rule         -> RELEVANT
otherwise                                                -> not relevant
```

- The filter table is read once per internal session.
- The result is buffered per VGBEL/VGTYP/AUART/sales area, because `USEREXIT_FIELD_MODIFICATION` runs for every screen field.

## 4. Field lock in VA01 – MV45AFZZ `USEREXIT_FIELD_MODIFICATION`

Source: `src/enhancement/mv45afzz_userexit_field_modification.abap`

- The lock only applies in create mode (`T180-TRTYP = 'H'`), only when `VBAK-VGBEL` is filled and `VBAK-VGTYP = 'G'`, and only when `IS_RELEVANT` returns true.
- Fields closed (`SCREEN-INPUT = 0`): `RV45A-MABNR`, `VBAP-MATNR`, `RV45A-KWMENG`, `VBAP-KWMENG`, `VBAP-VRKME`, `VBAP-NETWR`, `VBAP-NETPR`.
  The list is in `IS_LOCKED_FIELD`. Confirm each name with F1 → Technical Information.
- Optional: `src/enhancement/lv69afzz_userexit_field_modification.abap` locks the copied price (`KOMV-KBETR`) on the item condition screen.
- Copy control is not changed.

## 5. Unit test scenarios

| # | Scenario | Expected |
|---|----------|----------|
| 1 | VA01 ZOP / 2000-20-00 with reference to contract ZCPC, rule 01 as above | Fields are locked |
| 2 | Same as 1 with ZICE, and with channel 60 | Fields are locked (more than one value per field) |
| 3 | VKORG entered as BT 2000–2999, order in 2500 | Fields are locked (range) |
| 4 | Extra line `AUART_SO E EQ ZICO` | ZICO is no longer locked |
| 5 | All lines of rule 01 ACTIVE = blank | Fields are editable |
| 6 | VA01 without reference / with reference to a quotation (VGTYP B) | Fields are editable |
| 7 | Reference to a contract type not in AUART_CON | Fields are editable |
| 8 | SM30: rule without an AUART_CON line, BT without High, unknown VKORG, contract type in AUART_SO | Save is rejected |
| 9 | VA02 on the order from scenario 1 | Fields are editable (handled by the TSD ch. 4 workflow) |

## 6. Open points / decisions

- **Object names**: all names (table, domains, data elements, types) are proposals (TSD open item).
- **F4 on Low/High in SM30**: LOW/HIGH are generic CHAR 10, so they have no value help per field. Values are validated on save.
  If F4 is required, add a `PROCESS ON VALUE-REQUEST` module in the generated maintenance screen that calls the search help for the current FIELDNAME.
- **New items in VA01**: the lock applies to all item rows of a matching order. To allow free new items, add a check on `VBAP-VGBEL IS NOT INITIAL`.
- **Variant configuration characteristics**: these cannot be closed via `SCREEN-INPUT`. This stays open until the characteristics in scope are confirmed.
