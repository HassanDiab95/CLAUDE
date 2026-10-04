# CH4323 – Filter Table & VA01 Field Lock (Technical Design)

Scope: TSD chapter 2 (Dynamic Z Configuration Table) and chapter 3 (VA01 applicability check + field locking).
VA02 change detection, delivery block and workflow (chapters 4–6) are not part of this delivery.

## 1. Z table `ZSD_SO_CON_CTRL`

Source: `src/ddic/zsd_so_con_ctrl.tabl.ddl`

| Field     | Key | Data element | Check table | Meaning              | Example |
|-----------|-----|--------------|-------------|----------------------|---------|
| MANDT     | X   | MANDT        |             | Client               |         |
| VKORG     | X   | VKORG        | TVKO        | Sales Organization   | 2000    |
| VTWEG     | X   | VTWEG        | TVTW        | Distribution Channel | 20      |
| SPART     | X   | SPART        | TSPA        | Division             | 00      |
| AUART_SO  | X   | AUART        | TVAK        | Sales Order Type     | ZOP     |
| AUART_CON | X   | AUART        | TVAK        | Contract Type        | ZCPC    |
| ACTIVE    |     | XFELD        |             | Active Rule          | X       |

- Delivery class **C** (customizing, transported via customizing request).
- One row per combination. "20/60" and "ZOP/ZICE/ZICO" in the TSD are separate rows, e.g.:

  | VKORG | VTWEG | SPART | AUART_SO | AUART_CON | ACTIVE |
  |-------|-------|-------|----------|-----------|--------|
  | 2000  | 20    | 00    | ZOP      | ZCPC      | X      |
  | 2000  | 20    | 00    | ZICE     | ZCPC      | X      |
  | 2000  | 20    | 00    | ZICO     | ZCPC      | X      |
  | 2000  | 60    | 00    | ZOP      | ZCPC      | X      |
  | 2000  | 60    | 00    | ZICE     | ZCPC      | X      |
  | 2000  | 60    | 00    | ZICO     | ZCPC      | X      |

- A rule is switched off by clearing ACTIVE; no ABAP change is needed to add or remove a combination.

### Table maintenance
1. SE11 → Utilities → Table Maintenance Generator: authorization group (e.g. `ZSD`), function group `ZSD_SO_CON_CTRL`, one-step, standard recording routine.
2. Event **01** (before save) → `FORM zsd_so_con_ctrl_before_save` (`src/ddic/zsd_so_con_ctrl_tmg_events.abap`), which:
   - checks that all key fields are filled
   - checks that AUART_SO is a sales order type (TVAK-VBTYP = `C`)
   - checks that AUART_CON is a contract type (TVAK-VBTYP = `G`)
3. Create a parameter transaction (e.g. `ZSD_SOCON`) on SM30 for business users.

## 2. Filter logic – `ZCL_SD_SO_CONTRACT_CTRL=>IS_RELEVANT`

Source: `src/class/zcl_sd_so_contract_ctrl.clas.abap`

```
VBAK-VGBEL is initial OR VBAK-VGTYP <> 'G'            -> not relevant
No ACTIVE row in ZSD_SO_CON_CTRL for
   VKORG + VTWEG + SPART + AUART_SO = VBAK-AUART       -> not relevant
Contract type = VBAK-AUART of VBELN = VBAK-VGBEL
AUART_CON of an active row = contract type            -> RELEVANT
otherwise                                             -> not relevant
```

The steps run in the TSD order (3.1): sales order type and sales area first, then the contract type.
`USEREXIT_FIELD_MODIFICATION` runs once per screen field on every PBO, so the result is buffered per
VGBEL/VGTYP/AUART/sales area. The database is only read again when one of those values changes.

## 3. Field lock in VA01 – MV45AFZZ `USEREXIT_FIELD_MODIFICATION`

Source: `src/enhancement/mv45afzz_userexit_field_modification.abap`

- Implicit enhancement in FORM `USEREXIT_FIELD_MODIFICATION`. It replaces the test coding with the hard-coded `COBL-PRCTR` check.
- It runs in create mode only (`T180-TRTYP = 'H'`, which is VA01 and every other create path) and only when `VBAK-VGBEL` is filled, `VBAK-VGTYP = 'G'` and `IS_RELEVANT` returns true.
- Fields closed (`SCREEN-INPUT = 0`):

  | Screen field   | Meaning               |
  |----------------|-----------------------|
  | RV45A-MABNR    | Material (overview)   |
  | VBAP-MATNR     | Material (item)       |
  | RV45A-KWMENG   | Order quantity (overview) |
  | VBAP-KWMENG    | Order quantity (item) |
  | VBAP-VRKME     | Sales unit            |
  | VBAP-NETWR     | Net value             |
  | VBAP-NETPR     | Net price             |

  The list is held in one place, `IS_LOCKED_FIELD`. Confirm each name on the real screens with F1 → Technical Information (TSD open item).

- Optional: `src/enhancement/lv69afzz_userexit_field_modification.abap` also closes `KOMV-KBETR/KPEIN/KMEIN` on the item
  condition screen (SAPLV69A). This protects the copied contract price. It reuses the buffered result because VBAK is not visible there.
- Copy control (VTAA/VTLA) is not changed.

## 4. Unit test scenarios

| # | Scenario | Expected |
|---|----------|----------|
| 1 | VA01 ZOP / 2000-20-00 with reference to contract ZCPC, rule active | Material, quantity and net value are display-only |
| 2 | Same as 1, rule ACTIVE = blank | Fields are editable |
| 3 | VA01 ZOP / 2000-20-00 without reference | Fields are editable |
| 4 | VA01 ZOP with reference to a quotation (VGTYP = B) | Fields are editable |
| 5 | VA01 ZOP / 2000-20-00 with reference to a contract type not in the table | Fields are editable |
| 6 | VA01 ZOP / 1000-10-00 (sales area not in the table) with reference to ZCPC | Fields are editable |
| 7 | New row added in SM30 for another order type | Lock applies without any code change |
| 8 | SM30 save with a contract type in AUART_SO or an empty key | Save is rejected |
| 9 | VA02 on an order from scenario 1 | Fields are editable (VA02 is handled by change detection and workflow, TSD ch. 4) |

## 5. Open points / decisions

- **Final table name**: `ZSD_SO_CON_CTRL` is proposed (TSD open item).
- **New items in VA01**: the lock applies to all item rows of a matching order, so new rows cannot get a material either.
  If new free items must be allowed, add a check on `VBAP-VGBEL IS NOT INITIAL` in the enhancement.
- **Variant configuration characteristics**: these cannot be closed via `SCREEN-INPUT` because the configuration dialog is a separate
  application (CU). This is still open and depends on the final list of characteristics in scope.
  Candidates: set the configuration to display-only via the VC user exits, or block the configuration function code for relevant orders.
- **VA02**: the screenshot test coding also ran for VA02. Following the TSD, fields stay open in VA02 and changes are controlled through
  change detection, delivery block XX and workflow (next delivery).
