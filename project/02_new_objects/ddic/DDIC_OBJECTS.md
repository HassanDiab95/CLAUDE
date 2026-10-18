# DDIC objects – create in this order (SE11, package ZSD)

All objects are new. Activate each group before the next one.

## 1. Domains (with fixed values)

| Domain | Type | Fixed values |
|---|---|---|
| `ZSD_REL_COST` | CHAR 1 | `P` Waiting for YSDA/YSDAX · `A` Approved · `R` Rejected |
| `ZSD_REL_CREDIT` | CHAR 1 | ` ` Not decided · `N` Not needed (no credit block) · `W` Waiting for workflow start · `I` In approval · `A` Approved · `R` Rejected |
| `ZSD_REL_PROD` | CHAR 1 | `B` Blocked (CN) · `R` Released (CP) · `E` Release failed · `K` Kept on CN (rejected in YSDA/YSDAX) · `X` Cancelled (credit rejected) |
| `ZSD_REL_OVERALL` | CHAR 1 | `1` Waiting costing · `2` Waiting credit · `3` Released · `9` Rejected · `D` Order deleted |
| `ZSD_REL_EVENT` | CHAR 10 | (no fixed values) |

## 2. Data elements

| Data element | Domain | Short / field label |
|---|---|---|
| `ZSD_REL_COST` | `ZSD_REL_COST` | Costing approval status |
| `ZSD_REL_CREDIT` | `ZSD_REL_CREDIT` | Credit approval status |
| `ZSD_REL_PROD` | `ZSD_REL_PROD` | Production release status |
| `ZSD_REL_OVERALL` | `ZSD_REL_OVERALL` | Overall release status |
| `ZSD_REL_EVENT` | `ZSD_REL_EVENT` | Release cycle event |

## 3. Table `ZSD_SO_REL_H` – release header (one row per sales order)

Delivery class **A**, Data browser/table view maint. **Display/Maintenance allowed with restrictions**.
Technical settings: data class APPL1, size category 2, no buffering.

| Field | Key | Data element | Comment |
|---|---|---|---|
| MANDT | X | MANDT | |
| VBELN | X | VBELN_VA | sales order |
| BUKRS | | BUKRS | VBAK-BUKRS_VF |
| VKORG | | VKORG | |
| AUART | | AUART | |
| ERDAT | | ERDAT | order creation date |
| COST_STATUS | | ZSD_REL_COST | summary of the items |
| CREDIT_STATUS | | ZSD_REL_CREDIT | order level |
| PROD_STATUS | | ZSD_REL_PROD | summary of the approved items |
| OVERALL_STATUS | | ZSD_REL_OVERALL | |
| CREDIT_CYCLE | | INT2 | number of workflow runs |
| WI_ID | | SWW_WIID | current WS99000010 work item |
| SNAP_NETWR | | NETWR_AK | net value approved by credit – currency key SNAP_WAERK |
| SNAP_WAERK | | WAERK | |
| SNAP_KNKLI | | KNKLI | credit account |
| SNAP_KKBER | | KKBER | credit control area |
| SNAP_ZTERM | | DZTERM | payment terms |
| SNAP_ON | | DATS | snapshot date (= workflow start) |
| SNAP_AT | | TIMS | |
| COST_DONE_ON | | DATS | all items decided in YSDA/YSDAX |
| CREDIT_DONE_ON | | DATS | credit decision |
| CREATED_BY | | SYUNAME | |
| CREATED_ON | | DATS | |
| CREATED_AT | | TIMS | |
| CHANGED_BY | | SYUNAME | |
| CHANGED_ON | | DATS | |
| CHANGED_AT | | TIMS | |

Currency/quantity tab: SNAP_NETWR → reference table ZSD_SO_REL_H, field SNAP_WAERK.

## 4. Table `ZSD_SO_REL_I` – release item (one row per order item)

Same technical settings as the header.

| Field | Key | Data element | Comment |
|---|---|---|---|
| MANDT | X | MANDT | |
| VBELN | X | VBELN_VA | |
| POSNR | X | POSNR_VA | |
| PROD_RELEVANT | | XFELD | item had a CN schedule line = goes through YSDA/YSDAX |
| COST_STATUS | | ZSD_REL_COST | from ZSOAPPROVAL / rejection reason |
| PROD_STATUS | | ZSD_REL_PROD | B / R / E / K / X (see domain) |
| DECIDED_BY | | SYUNAME | user who completed the YSDA/YSDAX decision of this line |
| DECIDED_ON | | DATS | date of the decision |
| DECIDED_AT | | TIMS | time of the decision |
| REJ_ABGRU | | ABGRU_VA | rejection reason given in YSDA/YSDAX (e.g. 63) |
| REL_PLAN | | XFELD | `X` = line goes CN → CP at the credit final approval (fixed at workflow start) |
| CANCEL_ABGRU | | ABGRU_VA | rejection reason set when credit was rejected (order cancelled) |
| CANCEL_ON | | DATS | cancellation date |
| SNAP_TAKEN | | XFELD | snapshot exists for this item |
| SNAP_KWMENG | | KWMENG | quantity approved by credit – unit SNAP_VRKME |
| SNAP_VRKME | | VRKME | |
| SNAP_NETWR | | NETWR_AP | value approved by credit – currency ZSD_SO_REL_H-SNAP_WAERK |
| SNAP_ABGRU | | ABGRU_VA | rejection reason at snapshot time |
| COST_DONE_ON | | DATS | |
| PROD_REL_ON | | DATS | CN → CP date |
| PROD_REL_BY | | SYUNAME | user or WF-BATCH |
| CREATED_ON | | DATS | |

Currency/quantity tab: SNAP_KWMENG → ZSD_SO_REL_I-SNAP_VRKME; SNAP_NETWR → ZSD_SO_REL_H-SNAP_WAERK
(add foreign key ZSD_SO_REL_I-VBELN → ZSD_SO_REL_H so the reference to the header is allowed).

## 5. Table `ZSD_SO_REL_LOG` – history

| Field | Key | Data element |
|---|---|---|
| MANDT | X | MANDT |
| VBELN | X | VBELN_VA |
| LOG_TS | X | TIMESTAMPL |
| POSNR | X | POSNR_VA – `000000` = order row, otherwise the line the row is about |
| EVENT | | ZSD_REL_EVENT (`ITEM` for line rows) |
| COST_STATUS | | ZSD_REL_COST |
| CREDIT_STATUS | | ZSD_REL_CREDIT |
| PROD_STATUS | | ZSD_REL_PROD |
| OVERALL_STATUS | | ZSD_REL_OVERALL |
| NOTE | | ZWF_NOTE (existing, CHAR 255) |
| UNAME | | SYUNAME |
| TCODE | | SYTCODE |

## 6. Table `ZSD_SO_REL_CFG` – which orders follow the cycle (customizing)

Delivery class **C**. Generate table maintenance (SE11 → Utilities → Table Maintenance Generator,
function group `ZSD_SO_REL_CFG`, one step) and transaction `ZSD_SO_REL_CFG` → SM30.

| Field | Key | Data element | Comment |
|---|---|---|---|
| MANDT | X | MANDT | |
| BUKRS | X | BUKRS | VBAK-BUKRS_VF |
| AUART | X | AUART | order type |
| ACTIVE | | XFELD | cycle active |
| TOL_PCT | | DEC 5 / 2 (create `ZSD_REL_TOL_PCT`) | allowed growth of net value without restart, % |
| ANY_CHANGE | | XFELD | `X` = restart also when value / quantity goes down |
| REJ_ABGRU | | ABGRU_VA | rejection reason set on every open line when credit is rejected (order cancelled) |

Initial entries (confirm with the business; create the rejection reason, e.g. `ZC` "Credit rejected", in
SPRO → Sales and Distribution → Sales → Sales Documents → Sales Document Item → Define Reasons for Rejection, OVAG):

| BUKRS | AUART | ACTIVE | TOL_PCT | ANY_CHANGE | REJ_ABGRU |
|---|---|---|---|---|---|
| 1200 | YPMT | X | 0 | | ZC |
| 1400 | ZEM | X | 0 | | ZC |
| 1400 | ZMT | X | 0 | | ZC |
| 1500 | YCMT | X | 0 | | ZC |
| 1600 | YXMT | X | 0 | | ZC |

## 7. Table types `ZSD_SO_REL_I_TT` and `ZSD_SO_REL_LOG_TT`

Line type `ZSD_SO_REL_I`, standard table, standard key.

Also table type **`ZSD_SO_REL_LOG_TT`**: line type `ZSD_SO_REL_LOG`, standard table, standard key.

## 8. Lock object `EZSD_SO_REL`

Primary table `ZSD_SO_REL_H`, lock mode E, lock parameters MANDT, VBELN.
Generates `ENQUEUE_EZSD_SO_REL` / `DEQUEUE_EZSD_SO_REL`.

## 9. Messages – class `ZSD_WF` (SE91)

Check that the numbers are free; if not, take the next free ones and change the code.

| No. | Text |
|---|---|
| 015 | `Order &1 is in credit approval - release only through the approval workflow` |
| 016 | `Item &1: credit approval not completed - schedule line category cannot be changed` |


## 10. TVARVC variable

| Name | Type | Value |
|---|---|---|
| `ZSD_SO_REL_START_DATE` | Parameter | go-live date `YYYYMMDD` – only orders created on/after it follow the cycle |
