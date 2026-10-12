# PO / PR enhancement (BAdI ME_PROCESS_PO_CUST, impl. ZCL_IM_PR_AUTO_CLOSE)

| Class | Purpose |
|---|---|
| `ZCL_IM_PR_AUTO_CLOSE` | BAdI implementation – dispatches to the classes below |
| `ZCL_PO_PR_PREIS_CHECK` | **New.** PR Z306/Z307 → PO Z406/Z407 in ME21N/ME22N: copies `EBAN-PREIS` to `EKPO-EXPECTED_VALUE`, errors if the item's conditions (`EKKO-KNUMV` → `PRCD_ELEMENTS`, `SUM( KBETR )`) are more than `PREIS` |
| `ZCL_PO_PR_LIMIT_CHECK` | Existing limit check (unchanged) |
| `ZCL_PR_AUTO_CLOSE` | Closes the PR item on PO save – now also for PR Z306/Z307 → PO Z406/Z407 |

## Message to create (SE91, class `ZMM_PO`)

| No. | Text |
|---|---|
| 003 | `Item &1: Conditions total &2 more than PR &3 valuation price &4` |

Long text: *Sum of the PO item conditions (KBETR) is more than the purchase requisition valuation price.*

## Behaviour
- **Copy:** done once per PO item when the item is new (not yet on EKPO) or its
  PR reference changes. A value the user types afterwards is kept and checked.
  Items already saved (ME22N) are only checked, never overwritten.
- **Check:** sum of `KBETR` of the item's active conditions (`KPOSN = EBELP`, `KINAK` empty). Taken from the PO in memory (`GET_CONDITIONS`) so unsaved changes count; falls back to `PRCD_ELEMENTS` by `EKKO-KNUMV`. Runs in `PROCESS_ITEM` (item turns red immediately) and in `CHECK`
  (blocks save via `CH_FAILED`).
- **Skipped** when the PR currency differs from the PO currency.
- **Close:** on save, `ZCL_PR_AUTO_CLOSE` closes the PR item with `BAPI_PR_CHANGE`,
  same as for limit items. If `EBAN-EXPECTED_VALUE` is empty, `EBAN-PREIS` is used.
