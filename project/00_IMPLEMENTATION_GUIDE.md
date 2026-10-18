# Sales order release cycle – implementation guide

**YSDA / YSDAX (per line item) → credit management workflow WS99000010 → production release (CN → CP)**

Status of all code: **draft, written from the sources you sent, not compiled or tested in SAP.**
Work through the steps in order; each step lists the object, the exact place and the file that holds the
complete code.

---

## Contents of this package

| Folder | Content |
|---|---|
| `00_IMPLEMENTATION_GUIDE.md` | this document |
| `01_current_objects/` | your objects as you sent them (reference only, do not import) |
| `02_new_objects/ddic/DDIC_OBJECTS.md` | every new domain, data element, table, table type, lock object, message |
| `02_new_objects/ZCL_SD_SO_RELEASE.abap` | central class – the only owner of the release tables and of CN → CP |
| `02_new_objects/ZCL_WF_SD_SO_REL_STEP.abap` | workflow step class for WS99000010 |
| `02_new_objects/ZSD_SO_REL_RECONCILE.abap` | background job (safety net) |
| `02_new_objects/ZSD_SO_REL_MONITOR.abap` | monitor report |
| `03_changed_objects/CHANGES_TO_EXISTING_OBJECTS.md` | **only the changed lines** of the existing objects (find → insert / replace / delete): `ZCL_WF_SD_CREDIT`, MV45AFZZ, YSDA, YSDAX |
| `03_changed_objects/WS99000010_workflow_changes.md` | tasks and steps to add in SWDD |
| `06_ysda_ysdax_oop/` | YSDA / YSDAX converted to OOP (3 includes each, same logic) + `REQ1_CHANGES_ON_NEW_CODE.md` (the REQ1 changes for the new code) |
| `04_optional/ZCL_SD_COST_DELIV_BLOCK.abap` | earlier, separate proposal for delivery block 80 – not part of this change |

---

## Purpose of `ZCL_SD_SO_RELEASE` – who uses it

One class that keeps the release status of a production order (tables `ZSD_SO_REL_H` / `_I` / `_LOG`) and is the
**only code that changes CN → CP** for orders of the cycle. It is **not** only for the workflow and **not** only
for YSDA / YSDAX – every participant calls it, so the rules sit in one place:

| Caller | Methods | Why |
|---|---|---|
| VA01 / VA02 save (MV45AFZZ, B1–B8) | `ON_ORDER_SAVED`, `ON_WORKFLOW_KILLED`, `ON_ORDER_DELETED`, `IS_IN_CREDIT_APPROVAL`, `IS_ITEM_RELEASE_ALLOWED` | create the release rows, follow the existing kill / delete, block VKM1 / manual CN → CP |
| YSDA / YSDAX (C5, C7 / D3, D6 or N4, N7 / X3, X6) | `ON_ITEM_DECISION`, `GET_ITEM_STATUS_TEXT` | after each approve / reject: CN → CP now (no credit block), or start the credit workflow when the last line is decided |
| Check FM of the workflow start (`ZCL_WF_SD_CREDIT->IS_START_ALLOWED`, A1) | `CAN_START_CREDIT_WF` | WS99000010 may start only after YSDA / YSDAX are complete |
| Workflow WS99000010 (via `ZCL_WF_SD_SO_REL_STEP`, also writes `YSDA` / `PROD` rows into the EX / OD log) | `ON_CREDIT_STARTED`, `ON_CREDIT_APPROVED`, `ON_CREDIT_REJECTED`, `GET_RELEASE_PLAN` | record the start + release plan, CN → CP after final approval, record every line when credit is rejected (the existing REJECT_STEP cancels the order after rejection |
| Job `ZSD_SO_REL_RECONCILE` | `PROCESS` | safety net: retry a lost workflow start or a CN → CP that failed (order was locked) |

The class writes its tables **directly** (no update function module). It never commits inside the sales order
save – the `COMMIT WORK` of VA01 / VA02 saves the rows together with the order. Outside the order save
(YSDA / YSDAX, workflow, job) the class or the workflow runtime commits.

## 1. Business rules implemented

1. **Scope = exactly the lines YSDA / YSDAX show.** A line is a production line when it has a **CN**
   schedule line and its plant + order type + item category match the selection hard coded in YSDA / YSDAX
   (copied 1:1 into `ZSD_SO_REL_CFG`, e.g. plant 1200 item category ZTAW/ZFRE, plant 1400 order types
   ZEM/ZMT/ZOR/ZFC). The order must be a sales order or free of charge order (VBTYP C / I, as in the
   programs) and be created on/after the go-live date (TVARVC `ZSD_SO_REL_START_DATE`). An order with no such
   line works exactly as today. The programs themselves are not changed for this – the table is only needed
   because VA01/VA02 (MV45AFZZ) must know which lines will wait for YSDA/YSDAX.
2. **YSDA / YSDAX first, per line item.** Every item with CN is approved (SD + FI) or rejected (reason 63)
   in YSDA / YSDAX, item by item, as today.
3. **No credit block** (CMGST ≠ B): each item goes **CN → CP as soon as it is approved**, independent of the
   other items.
4. **Credit block** (credit limit exceeded and/or overdue, CMGST = B): approved items **stay CN**. The credit
   workflow starts **only when every production item of the order is approved or rejected** (and at least
   one is approved). If all items are rejected, no workflow starts.
4a. **Automatic start from YSDA / YSDAX – no VA02 needed.** When the approver in YSDA/YSDAX approves or
   rejects the **last open production line** of a credit-blocked order, the program itself raises
   **BUS2032 `CHANGED`** (`SAP_WAPI_CREATE_EVENT`, with `SOLDTOPARTY` in the event container). The existing
   linkage starts **WS99000010**, the check function module lets it through (costing done, credit waiting),
   and `_WF_INITIATOR` is the YSDA/YSDAX user. Nobody has to open or change the sales order. The start
   request is logged (`EVENT` / `EVENT_ERR`); if the start gets lost, the job raises the event again after
   30 minutes.
5. **Release plan per line.** When the credit workflow starts, every production line is marked: approved in
   YSDA/YSDAX → **goes CN → CP at the final approval**; rejected in YSDA/YSDAX → **stays CN**. The plan is
   stored in the release tables (monitor `ZSD_SO_REL_MON`); the approver mail stays as it is.
   **Final approval** → exactly the planned lines **CN → CP**, the others stay CN.
   **Credit rejected** → first the new step records every line as YSDA/YSDAX decided it (approved lines:
   "not released – cancelled", rejected lines keep reason 63), then the **existing** `REJECT_STEP`
   (TS99000044 "Cancel Sales Order Credit") cancels the order exactly as today. No line goes to CP.
6. **Approved items are not shown again in YSDA / YSDAX** even though they stay CN while credit runs
   (the list now filters on the SD + FI approval, not only on CN).
7. **Snapshot.** When the workflow starts, the order net value, every item quantity / value / rejection,
   the credit account, credit control area, currency and payment terms are stored.
8. **Order changes during the credit approval** follow your existing rules for every order: the order is
   locked (VA02 → VA03); if it is changed anyway, the existing kill cancels the workflow and the release cycle
   is told (`ON_WORKFLOW_KILLED`), so the new save starts a new check.
   **Changes after the credit approval** are compared with the snapshot:

   | Change after approval | Result |
   |---|---|
   | credit account, credit control area, currency, payment terms | new credit decision needed |
   | net value above approved value + tolerance (constant `GC_TOL_PCT`, 0 %) | new credit decision needed |
   | item quantity higher than approved, new item, rejection removed | new credit decision needed (new item goes to YSDA first) |
   | lower value / quantity, items rejected, texts, dates, partners | no new decision |

   Every decision is written to `ZSD_SO_REL_LOG` with the reason.
9. **One workflow per order.** The start check (`IS_START_ALLOWED`, change A1) refuses the start while the
   order has the lock row `ZSD_WF_SO` or a running WS99000010 (existing methods `IS_ORDER_LOCKED` /
   `FIND_RUNNING`) – before the workflow starts, so no second work item, log or mail.
10. **Manual shortcuts are closed.** VKM1 / VKM3 / VKM4 release is refused while the credit workflow runs;
    CN → CP by hand in VA02 is refused until the item is approved in YSDA/YSDAX **and** credit is approved
    or not needed.
11. **Line log.** For every line the decision is stored on the line (approved / rejected, by whom, when,
    reason) and every change is written to `ZSD_SO_REL_LOG` as its own row (POSNR = line): approved, rejected,
    release plan, CN → CP, stays CN, cancelled. Monitor `ZSD_SO_REL_MON` shows it per line.
12. **Safety net.** Job `ZSD_SO_REL_RECONCILE` releases items whose release failed (order locked), raises
    a lost workflow start again and reports workflows that are no longer active.

---

## 2. Status model

Header (`ZSD_SO_REL_H`) – one row per order. Item (`ZSD_SO_REL_I`) – one row per order item.

| Field | Values |
|---|---|
| Item `COST_STATUS` | `P` waiting YSDA/YSDAX · `A` approved (SD + FI) · `R` rejected |
| Item `PROD_STATUS` | `B` blocked (CN) · `R` released (CP) · `E` release failed (job retries) |
| Header `COST_STATUS` | `P` while any production item is `P` · `R` if all rejected · else `A` |
| Header `CREDIT_STATUS` | ` ` not decided · `N` not needed · `W` waiting for workflow start · `I` in approval · `A` approved · `R` rejected |
| Header `OVERALL_STATUS` | `1` waiting YSDA/YSDAX · `2` waiting credit · `3` released · `9` rejected · `D` deleted |

```
 order saved (CN items)          YSDA/YSDAX per item               credit block?
 ─────────────────────►  items P ──────────────────► item A / R ──────┬───────────────────────────────┐
                                                                     no                              yes
                                                                      │                               │
                                                        item CN→CP at once            all items A/R? ─┤ no: wait
                                                        (credit N)                           │ yes
                                                                                    credit W → event → WS99000010
                                                                                             │ first step: credit I + snapshot
                                                                            ┌────────────────┼─────────────────┐
                                                                       final approval    rejection     credit relevant change
                                                                       credit A           credit R      kill, credit ' ', new start
                                                                       approved items     items stay CN
                                                                       CN → CP
```

---

## 3. Implementation steps

### Step 1 – Transport and package
Create a workbench request (e.g. "REQ1 SO release cycle YSDA + credit WF"). Package `ZSD` for everything.

### Step 2 – DDIC objects (SE11 / SE91 / STVARV)
File: `02_new_objects/ddic/DDIC_OBJECTS.md`. In this order:
1. Domains `ZSD_REL_COST`, `ZSD_REL_CREDIT`, `ZSD_REL_PROD`, `ZSD_REL_OVERALL`, `ZSD_REL_EVENT` .
2. Data elements with the same names.
3. Tables `ZSD_SO_REL_H`, `ZSD_SO_REL_I`, `ZSD_SO_REL_LOG`, `ZSD_SO_REL_CFG` (no table maintenance generator – no function group).
4. Messages 018 and 019 in class `ZSD_WF` (000–017 are already used; 017 = kill message of the credit workflow).
5. TVARVC (STVARV): create **only** `ZSD_SO_REL_START_DATE` (go-live date) – **leave it empty until
   go-live** (empty = cycle switched off). Nothing else goes into TVARVC.

### Step 3 – Classes (SE24)
1. `02_new_objects/ZCL_SD_SO_RELEASE.abap` – create the class in source-code based mode and paste.
   The settings are written in the class code itself (constants at the top of the class, nothing to create
   anywhere): tolerance `GC_TOL_PCT` = 0 %, restart on any change `GC_ANY_CHANGE` = off. To change one, change the
   constant in the class.
2. `ZCL_WF_SD_CREDIT->IS_START_ALLOWED`: apply change **A1** of `03_changed_objects/CHANGES_TO_EXISTING_OBJECTS.md`.
3. Activate both classes **together** (they call each other).
4. `02_new_objects/ZCL_WF_SD_SO_REL_STEP.abap` – create and activate.

### Step 4 – Sales order user exits (SE80 → include MV45AFZZ)
Apply changes **B1–B8** of `03_changed_objects/CHANGES_TO_EXISTING_OBJECTS.md`, or simply replace the whole code of
each enhancement with `03_changed_objects/MV45AFZZ_ENHANCEMENTS_COMPLETE.abap` (all six, ready to paste):

| # | User exit (FORM) | Enhancement | Change |
|---|---|---|---|
| B1–B2 | `USEREXIT_SAVE_DOCUMENT` | `ZEN_CMEXOD_KILL_WORKFLOW` | CHECK → IF, skip release-cycle orders |
| B3 | `USEREXIT_SAVE_DOCUMENT` | **new** `ZEN_SO_RELEASE_SAVE` | create |
| B4 | `USEREXIT_DELETE_DOCUMENT` | `ZEN_CMEXOD_KILL_WORKFLOW_WDEL` | CHECK → IF, release-cycle orders closed |
| B5 | `USEREXIT_SAVE_DOCUMENT_PREPARE` | **new** `ZEN_SO_RELEASE_NO_VKM` | create |
| B6–B7 | `USEREXIT_MOVE_FIELD_TO_VBEP` | `ZSD_CHECK_APPROVAL` | approval read fix + credit check |
| B8 | `USEREXIT_READ_DOCUMENT` | `ZEN_DISAB_VA02_CM_WF_RUNNINNG` | CHECK → IF, redirect only other orders |

> **Existing bug fixed by B1–B2:** a failing `CHECK` in an enhancement leaves the whole user exit, so today
> every enhancement after `ZEN_CMEXOD_KILL_WORKFLOW` in USEREXIT_SAVE_DOCUMENT (`ZO2C_CREDITLMIT_CHECK`,
> `ZSAVE_DIFF_COST_PROFIT`, `ZSD_DISCOUNT_BLOCK`, ...) is skipped on almost every save. After the fix they run
> again on every save – **test them**.
>
> **Existing bug fixed by B6:** YSDA/YSDAX store the **plant** in `ZSOAPPROVAL-BUKRS`, so the old
> `BUKRS = VBAK-BUKRS_VF` never found the approval for plants 1202 / 1501.

### Step 5 – YSDA (module pool `YSP_MTOSO_APPROVE`)
Choose **one** of the two ways, depending on which YSDA code you have:

| YSDA code in the system | Apply |
|---|---|
| old code (9 includes) | changes **C1–C7** below |
| OOP version from `06_ysda_ysdax_oop` (3 includes) | changes **N1–N7** in `06_ysda_ysdax_oop/REQ1_CHANGES_ON_NEW_CODE.md` – only in include `YSP_MTOSO_APPROVE_C01` |

Both ways do the same: list filter (lines approved by SD + FI are hidden), per-row reset of the BAPI tables,
FI approval no longer sets CP alone, release-cycle decision when SD + FI are done, release-cycle call after
each rejection.

### Step 6 – YSDAX (module pool `YSP_MTOSO_APPROVE_CX`)
Old code: changes **D1–D6** below. OOP version: changes **X1–X6** in
`06_ysda_ysdax_oop/REQ1_CHANGES_ON_NEW_CODE.md` – only in include `YSP_MTOSO_APPROVE_CX_C01`.
(Same logic; YSDAX FI approval never set CP, so there is no FI change.)

### Step 7 – Workflow WS99000010 and log (PFTC + SWDD)
File: `03_changed_objects/WS99000010_workflow_changes.md` (also as Word file) – based on your package of
19.10.2026, step by step with the reason for each:
start check A1 (lock row / running run / YSDA first), kill enhancement (your v2.0 + `ON_WORKFLOW_KILLED`),
class `ZCL_WF_SD_SO_REL_STEP`, three background tasks, `SO_REL_START` after `GET_APPROVERS`,
`SO_REL_APPROVED` after `APPROVE_STEP` (`RELEASE_SO`), `SO_REL_REJECTED` before `REJECT_STEP` (`CANCEL_SO`),
log actions `YSDA` / `PROD` in your EX / OD logs (domain values + Fix 03 exemption).
**No change** to the approver mail (HTML), the approval loop, the order lock or the event linkage.

### Step 8 – Reports and transactions
1. `02_new_objects/ZSD_SO_REL_RECONCILE.abap` → SE38, variant `DEFAULT` (P_WAIT = 30),
   SM36 job **every 30 minutes**, user with SD change authorization (e.g. the workflow batch user).
2. `02_new_objects/ZSD_SO_REL_MONITOR.abap` → SE38, transaction `ZSD_SO_REL_MON` (SE93).

### Step 9 – Customizing
SE16N `ZSD_SO_REL_CFG` (in the development system, then transport `R3TR TABU ZSD_SO_REL_CFG`): the 14 entries from `DDIC_OBJECTS.md` §6 – they are the selection of YSDA / YSDAX
(plants 1200, 1202, 1500, 1501, 1600, 1400). Add a row `<plant> | * | * | YSDAX` for any other plant that is
approved in YSDAX in real life. If YSDA / YSDAX selection is changed later, change this table the same way.

### Step 10 – Test in QA (all must pass before transport to production)

| # | Scenario | Expected |
|---|---|---|
| 1 | Production order, no credit issue, 2 items | each item CP as soon as it is approved; no workflow; overall 3 |
| 2 | Credit limit exceeded, 1 item | no workflow at save; YSDA approve → item hidden, still CN → workflow starts → final approval → CP |
| 3 | Overdue only | as 2 |
| 4 | Credit limit + overdue | as 2, one workflow |
| 5 | Blocked order, 3 items: approve 1, approve 2 | no workflow yet, items CN |
| 6 | … then reject item 3 | workflow starts now; after approval items 1 + 2 CP, item 3 stays rejected |
| 7 | Blocked order, all items rejected | no workflow, overall 9 |
| 8 | Workflow rejects | new step logs `CREDIT_NOK` with one `ITEM` row per line (approved lines "cancelled", rejected lines unchanged), then the existing REJECT_STEP cancels the order as today; no line CP; overall 9 |
| 8a | Blocked order, YSDA approves line 10, rejects line 20 → credit approved | line 10 CP, line 20 stays CN (reason 63); log per line |
| 9 | During workflow: open the order in VA02 | redirected to VA03 (existing lock) |
| 10 | Order changed in VA02 although in approval (opened before the lock) | existing kill cancels the workflow, log `RESTART`, the save starts a new workflow |
| 11 | Second start event while the workflow runs (SWUE BUS2032 CHANGED) | check FM NOT_RELEVANT, no second workflow, no second log |
| 12 | After credit approval: increase quantity in VA02 | log `RESTART`; if SAP blocks the order again, a new workflow starts |
| 13 | Order open in VA02 when credit is rejected | the new step only writes the release tables (no lock problem); the existing REJECT_STEP behaves as today |
| 14 | Final approval while the order is open in VA02 | step retries; else job releases; log `PROD_ERR` then `PROD_REL` |
| 15 | VKM1 release while workflow runs | error 018 |
| 16 | VA02: change CN → CP by hand before credit approval | error 019 |
| 17 | Delete order during workflow | workflow cancelled, overall D |
| 18 | Plant / item category / order type not in ZSD_SO_REL_CFG (= not shown in YSDA/YSDAX) or created before go-live | exactly as today |
| 18a | Plant 1400, order type ZOR, CN line | managed (same as YSDAX shows it) |
| 18b | Plant 1200, item category other than ZTAW / ZFRE with CN | not managed – YSDA does not show it, so it does not block the credit start |
| 19 | VA01 / VA02 save of any order | `ZO2C_CREDITLMIT_CHECK`, `ZSAVE_DIFF_COST_PROFIT`, sales office check etc. run (bug fix of step 4) |
| 20 | YSDA plants 1202 / 1501: VA02 schedule line change after approval | no false "not yet approved" error |
| 21 | Approve 2 rows of different orders in one YSDA click | each order handled separately (BAPI table fix) |

Use transaction `ZSD_SO_REL_MON` (double click = history) and SWI1 / SWIA to follow every test.

### Step 11 – Go-live
1. Transport in this order: DDIC → classes → workflow tasks → workflow → user exits →
   YSDA / YSDAX → reports → customizing. If you use the OOP version of YSDA / YSDAX, transport and test the
   pure conversion first (it changes nothing in the logic), then the REQ1 changes N1–N7 / X1–X6.
2. Schedule the reconcile job.
3. Set TVARVC `ZSD_SO_REL_START_DATE` to the go-live date. Orders created before it keep the old logic
   until they are closed.

---

## 4. Decisions taken (change if the business decides differently)

| # | Question | Decision in the code |
|---|---|---|
| 1 | Lines in scope | the lines YSDA / YSDAX show (plant / item category / order type in `ZSD_SO_REL_CFG`) |
| 2 | Restart after a change | new workflow from level 1 (existing kill) |
| 3 | VA02 while the workflow runs | as today for every order: VA03 redirect, kill on change |
| 4 | Quantity / price change after YSDA approval | YSDA not asked again (only new items go back to YSDA) |
| 5 | Credit rejected | every line recorded as YSDA/YSDAX decided it; the existing REJECT_STEP cancels the order (no change to it) |
| 6 | Credit block after items were released | released items stay CP; standard credit block stops the delivery; unreleased items wait for the new approval |
| 7 | Workflow cancelled by an admin | job reports it, does not restart it |
| 8 | Credit start rule | after **all** production items are approved or rejected |
| 9 | Tolerance | 0 % |

## 5. Open points for you

1. **Workflow step placement** – confirm in SWDD which step releases the SAP credit block at final approval;
   `SO_REL_APPROVED` must come after it.
2. **Company code 1400** – `ZO2C_CREDITLMIT_CHECK` (old credit / overdue workflow, BUS2031 events) will run
   again on every save after the CHECK fix. If WS99000010 replaces it, deactivate it, otherwise 1400 orders
   get two credit approvals.
3. **YSDA FI auto-decision** – YSDA still sets FI "Not Approved" (+ Z8) when the customer exceeds the credit
   limit. With the credit workflow in place, decide whether YSDA should judge only cost / profit.
4. **Mixed orders (on hold – waiting for the business answer)** – an order with production lines (CN) and
   normal lines, with a credit block, where **all** production lines are rejected in YSDA / YSDAX: today the
   credit workflow does not start, so the normal lines keep the credit block. If such orders exist, the fix is
   small (`SET_SUMMARY` / `PROCESS`: start the workflow when normal lines are open). No code change until
   decided.
