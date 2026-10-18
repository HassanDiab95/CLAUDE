# REQ1 – Sales order release cycle: YSDA/YSDAX first, then credit workflow, production block until both approve

Status: **design + draft code, not compiled or tested in SAP.** Replaces the earlier REQ1 draft.

Files in this folder:

| File | Content |
|---|---|
| `README.md` | this design: tables, status model, flows, all business scenarios, open questions |
| `ZCL_SD_SO_RELEASE.abap` | the central class (the only code that writes the release tables) |
| `Z_SD_SO_REL_UPDATE.abap` | update-task function module that writes the tables |
| `integration.abap` | the small calls to add in MV45AFZZ, YSDA, YSDAX, ZCL_WF_SD_CREDIT, the workflow and the job |

---

## 1. Best-practice principles used

1. **One release table, one owner.** YSDA/YSDAX and the credit workflow never change each other's data.
   They report their decision to one class (`ZCL_SD_SO_RELEASE`), which owns the release table and is the
   only code that changes the production block (CN → CP).
2. **Explicit status, not derived from SAP fields.** "Is costing approved?", "Is credit approved?",
   "Is production released?" are stored as status fields, not guessed from `ETTYP` or `CMGST`.
   `CN` keeps one meaning only: *production blocked*.
3. **Snapshot what was approved.** When the credit workflow starts, the order value, quantities and
   credit-relevant header data are stored. On every later save the new order is compared with the snapshot,
   and only a credit-relevant change restarts the workflow.
4. **Full audit log.** Every status change writes a log row (who, when, transaction, old → new, reason).
5. **No `COMMIT WORK` in user exits.** Table changes from the sales order go through an update-task function
   module, so they are saved with the order or not at all.
6. **Idempotent and self-healing.** Every step can run twice without harm, and a background job repairs
   anything that got stuck (order locked during release, event lost, workflow cancelled by admin).
7. **Configuration instead of hard-coded lists.** Which company code / order types follow this cycle and the
   tolerance for value changes are in a small customizing table.

---

## 2. New DDIC objects

### 2.1 `ZSD_SO_REL_H` – release header (one row per sales order)

| Field | Type | Meaning |
|---|---|---|
| MANDT | MANDT | key |
| VBELN | VBELN_VA | key – sales order |
| BUKRS | BUKRS | company code (VBAK-BUKRS_VF) |
| VKORG | VKORG | sales org |
| AUART | AUART | order type |
| COST_STATUS | ZSD_REL_COST CHAR1 | `P` waiting for YSDA/YSDAX · `A` approved · `R` rejected |
| CREDIT_STATUS | ZSD_REL_CREDIT CHAR1 | ` ` not decided yet · `N` not needed (no credit block) · `W` waiting for workflow start · `I` in approval · `A` approved · `R` rejected |
| PROD_STATUS | ZSD_REL_PROD CHAR1 | `B` blocked (CN) · `R` released (CP) · `E` release failed (job retries) |
| OVERALL_STATUS | ZSD_REL_OVERALL CHAR1 | `1` waiting costing · `2` waiting credit · `3` released · `9` rejected · `D` order deleted |
| CREDIT_CYCLE | INT2 | how many times the credit workflow ran |
| WI_ID | SWW_WIID | current WS99000010 work item |
| SNAP_NETWR | NETWR_AK | order net value approved by credit (snapshot) |
| SNAP_WAERK | WAERK | currency of the snapshot |
| SNAP_KNKLI | KNKLI | credit account |
| SNAP_KKBER | KKBER | credit control area |
| SNAP_ZTERM | DZTERM | payment terms |
| SNAP_ON / SNAP_AT | DATS / TIMS | when the snapshot was taken (= workflow start) |
| COST_DONE_ON, CREDIT_DONE_ON, PROD_REL_ON | DATS | milestones |
| PROD_REL_BY | SYUNAME | who/what released production |
| CREATED_BY/ON/AT, CHANGED_BY/ON/AT | | admin |

### 2.2 `ZSD_SO_REL_I` – item snapshot (rows written when the credit workflow starts)

| Field | Type | Meaning |
|---|---|---|
| MANDT, VBELN, POSNR | | key |
| KWMENG | KWMENG | quantity approved by credit |
| VRKME | VRKME | sales unit |
| NETWR | NETWR_AP | item net value approved by credit |
| ABGRU | ABGRU_VA | rejection reason at that time |

Table type `ZSD_SO_REL_I_TT` (standard table of `ZSD_SO_REL_I`) for the update function module.

### 2.3 `ZSD_SO_REL_LOG` – history

| Field | Type |
|---|---|
| MANDT, VBELN, LOG_TS (TIMESTAMPL) | key |
| EVENT | CHAR10 – `CREATE`, `COST`, `CREDIT_WT`, `CREDIT_ST`, `CREDIT_OK`, `CREDIT_NOK`, `RESTART`, `NO_RESTART`, `PROD_REL`, `PROD_ERR`, `DELETE`, `RECONCILE` |
| COST_STATUS, CREDIT_STATUS, PROD_STATUS, OVERALL_STATUS | status after the event |
| NOTE | CHAR255 – reason, e.g. "Net value 120,000 > approved 100,000" |
| UNAME, TCODE | who, from where |

### 2.4 `ZSD_SO_REL_CFG` – which orders follow this cycle

| Field | Type | Meaning |
|---|---|---|
| MANDT, BUKRS, AUART | | key |
| ACTIVE | XFELD | cycle active for this company code / order type |
| TOL_PCT | DEC 5,2 | net value may grow this % without restarting the credit workflow (default 0) |
| ANY_CHANGE | XFELD | `X` = also restart when value/quantity goes **down** (default space) |

Initial entries (from the existing check `ZSD_CHECK_APPROVAL`): 1400 ZEM, 1400 ZMT, 1200 YPMT, 1500 YCMT, 1600 YXMT – **please confirm** (question 1).

### 2.5 Lock object `EZSD_SO_REL` on `ZSD_SO_REL_H` (VBELN)

Used so that two CHANGED events for the same order cannot start two workflows at the same time.

---

## 3. Status model

```
              order saved with CN (relevant order type)
                              │
                              ▼
   OVERALL 1  COST=P  CREDIT=' '  PROD=B      ◄──── new item added later
                              │
              YSDA/YSDAX: every open CN item SD+FI approved
                              │
            ┌─────────────────┴──────────────────┐
     CMGST <> 'B'                          CMGST = 'B' (credit limit / overdue)
            │                                    │
   CREDIT=N, release CN→CP              CREDIT=W, raise BUS2032.CHANGED
            │                                    │
            │                         workflow starts → CREDIT=I, snapshot
            │                                    │
            │               ┌────────────────────┼─────────────────────┐
            │         final approval        rejection        credit-relevant change
            │               │                    │             (kill, CREDIT=' ',
            │        CREDIT=A, CN→CP        CREDIT=R            new workflow starts)
            ▼               ▼                    ▼
   OVERALL 3  PROD=R   OVERALL 3 PROD=R     OVERALL 9  PROD=B (CN stays)
```

OVERALL is always derived the same way:

| Condition | OVERALL |
|---|---|
| COST = R or CREDIT = R | `9` rejected |
| PROD = R | `3` released |
| COST = P | `1` waiting costing (YSDA/YSDAX) |
| otherwise | `2` waiting credit |

---

## 4. Who calls the class, and when

| Moment | Where | Method | What it does |
|---|---|---|---|
| Order saved (VA01, VA02, BAPI, any program) | `USEREXIT_SAVE_DOCUMENT` | `ON_ORDER_SAVED` | creates the row for relevant orders; detects new items; compares with snapshot; kills the workflow only on a credit-relevant change |
| Order deleted | `USEREXIT_DELETE_DOCUMENT` | `ON_ORDER_DELETED` | kills workflow, OVERALL `D` |
| Manual credit release while workflow runs | `USEREXIT_SAVE_DOCUMENT_PREPARE` | `IS_IN_CREDIT_APPROVAL` | error in VKM1/VKM3/VKM4: release only through the workflow (same idea as the old 1400 enhancement) |
| Manual CN → CP in VA02 | `USEREXIT_MOVE_FIELD_TO_VBEP` (`ZSD_CHECK_APPROVAL`) | `IS_PRODUCTION_RELEASE_ALLOWED` | error unless costing and credit are both done |
| YSDA/YSDAX approve or reject | `APPROVE_FUN`, `REJECT_FUN` | `ON_COSTING_DECISION` | recalculates costing status; when complete: no block → release production; block → CREDIT=W and start the workflow |
| Event BUS2032 CREATED/CHANGED | check FM → `IS_START_ALLOWED` | `CAN_START_CREDIT_WF` | `N` while costing is open or a workflow already runs |
| Workflow first step | WS99000010 | `ON_CREDIT_STARTED` | CREDIT=I, snapshot of value/quantities; returns *duplicate* if another workflow already runs |
| Workflow final approval | WS99000010 | `ON_CREDIT_APPROVED` | CREDIT=A, CN → CP |
| Workflow rejection | WS99000010 | `ON_CREDIT_REJECTED` | CREDIT=R, CN stays |
| Every 30 min | job `ZSD_SO_REL_RECONCILE` | `RECONCILE` | retries failed releases, restarts lost workflow starts, reports inconsistencies |

YSDA/YSDAX list: an item already SD+FI approved is **not shown** any more, even though it stays on CN while
the credit workflow runs. That is the answer to "the order will appear again in YSDA": the list filters on the
approval, not only on CN.

---

## 5. Credit-relevant change (restart rule)

Checked in `ON_ORDER_SAVED` only while CREDIT = `I`. Compared against the snapshot taken at workflow start.

| Change | Restart workflow? |
|---|---|
| Credit account (KNKLI), credit control area, currency, payment terms changed | **yes** |
| Order net value > approved value + tolerance % | **yes** |
| Item quantity higher than approved | **yes** |
| New item (not rejected), or rejected item opened again | **yes** (and YSDA must approve the new item first) |
| Value or quantity lower, items rejected (Z8, 63, 00 by ZSD_MASS_CLOSING) | no (yes only if `ANY_CHANGE = X`) |
| Texts, dates, delivery block, partners other than credit account, schedule line category CN→CP | no |

Every decision is logged (`RESTART` / `NO_RESTART` with the reason), so you can prove why a workflow ran again.

---

## 6. Business scenarios

| # | Scenario | Result |
|---|---|---|
| 1 | Production order, no credit issue | YSDA SD+FI → CN→CP at once, CREDIT=N, OVERALL 3. No workflow. |
| 2 | Credit limit exceeded | No workflow at save (costing open). YSDA approves → item disappears from YSDA, stays CN → workflow starts → final approval → CN→CP. |
| 3 | Overdue only | Same as 2 (the standard credit check sets CMGST=B for overdue too). |
| 4 | Credit limit + overdue | Same as 2, one workflow (exceed + overdue branches as today). |
| 5 | Order with 3 items, YSDA approves 2 | Still COST=P, no workflow. Third approved → workflow starts once. |
| 6 | YSDA rejects all items | COST=R, OVERALL 9, no workflow. |
| 7 | YSDA rejects some, approves the rest | Rejected items ignored; decision on the approved ones. |
| 8 | Credit workflow rejected | CREDIT=R, CN stays, OVERALL 9 (see question 5). |
| 9 | User changes texts/dates during the workflow | Logged `NO_RESTART`, workflow continues. |
| 10 | User increases quantity or price during the workflow | Workflow killed, new snapshot, new workflow from level 1 (see question 2). |
| 11 | User adds an item during the workflow | Workflow killed, COST=P, item shows in YSDA; after YSDA approval the workflow starts again. |
| 12 | Items rejected during the workflow (ZSD_MASS_CLOSING, Z8 by YSDA) | Value goes down → `NO_RESTART`. This also stops the repeated workflows from the original incident. |
| 13 | Order changed after production was released, credit blocks again | New workflow for the delivery; production stays CP (see question 6). |
| 14 | Final approval while the order is open in VA02 | BAPI cannot lock → PROD=E, job releases it later. |
| 15 | Two CHANGED events at the same time | Lock + status check: the second workflow ends at its first step (`ON_CREDIT_STARTED` returns duplicate). |
| 16 | Admin cancels the workflow in SWIA | Job sees CREDIT=I without a running work item → resets and starts it again (or reports, see question 7). |
| 17 | Credit released manually in VKM1/VKM3/VKM4 while the workflow runs | Error – release only through the workflow. |
| 18 | User sets CP by hand in VA02 before both approvals | Error in `ZSD_CHECK_APPROVAL`. |
| 19 | Order deleted | Workflow killed, logs closed, OVERALL D. |
| 20 | Order type / company code not in `ZSD_SO_REL_CFG`, or no CN line | Not managed: workflow works exactly as today. |
| 21 | Orders created before go-live (TVARVC `ZWF_SO_WF_START_DATE`) | Not managed: as today. |

---

## 7. Open questions (my default in brackets – reply only where you disagree)

1. **Scope** – are the order types 1400 ZEM/ZMT, 1200 YPMT, 1500 YCMT, 1600 YXMT the complete list of production orders? *(yes)*
2. **Restart** – after a credit-relevant change, does approval start again from level 1? *(yes, from level 1)*
3. **VA02 while the workflow runs** – today `ZEN_DISAB_VA02_CM_WF_RUNNINNG` sends the user to VA03, so
   nobody can change the order in VA02. To allow "non-credit changes without restart" this redirect must be
   removed for managed orders. *(remove the redirect for managed orders; the restart rule protects credit)*
4. **YSDA after a quantity/price change** – must YSDA approve the item again? *(no – the existing delivery
   block 80 cost check covers cost changes; only new items go back to YSDA)*
5. **Credit rejected** – only keep CN and notify, or also set a rejection reason on the items? *(keep CN, notify the creator)*
6. **Credit block after production release** – keep CP and let the standard credit block stop the delivery,
   or switch back to CN? *(keep CP)*
7. **Workflow cancelled by admin** – job restarts it automatically or only reports it? *(report only)*
8. **Workflow classes** – please send the class/method behind the first background step (where the logs
   are started), the final approval step and the rejection step of WS99000010, so the three calls go in the right place.
9. **Company 1400** – is the old credit/overdue workflow in `ZO2C_CREDITLMIT_CHECK` still active? If yes,
   1400 orders get two credit approvals. *(switch it off for managed orders)*
10. **Tolerance** – allowed growth of net value without restart? *(0 %)*
