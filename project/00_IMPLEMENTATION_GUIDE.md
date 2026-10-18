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
| `02_new_objects/ddic/DDIC_OBJECTS.md` | every new domain, data element, table, table type, lock object, message, TVARVC |
| `02_new_objects/ZCL_SD_SO_RELEASE.abap` | central class – the only owner of the release tables and of CN → CP |
| `02_new_objects/Z_SD_SO_REL_UPDATE.abap` | update function module (function group `ZSD_SO_REL`) |
| `02_new_objects/ZCL_WF_SD_SO_REL_STEP.abap` | workflow step class for WS99000010 |
| `02_new_objects/ZSD_SO_REL_RECONCILE.abap` | background job (safety net) |
| `02_new_objects/ZSD_SO_REL_MONITOR.abap` | monitor report |
| `03_changed_objects/CHANGES_TO_EXISTING_OBJECTS.md` | **only the changed lines** of the existing objects (find → insert / replace / delete): `ZCL_WF_SD_CREDIT`, MV45AFZZ, YSDA, YSDAX |
| `03_changed_objects/WS99000010_workflow_changes.md` | tasks and steps to add in SWDD |
| `04_optional/ZCL_SD_COST_DELIV_BLOCK.abap` | earlier, separate proposal for delivery block 80 – not part of this change |

---

## 1. Business rules implemented

1. **Scope.** An order follows the cycle when its company code + order type is active in `ZSD_SO_REL_CFG`,
   it was created on/after the go-live date (TVARVC `ZSD_SO_REL_START_DATE`) and at least one item has a
   **CN** schedule line (production blocked by configuration). Every other order works exactly as today.
2. **YSDA / YSDAX first, per line item.** Every item with CN is approved (SD + FI) or rejected (reason 63)
   in YSDA / YSDAX, item by item, as today.
3. **No credit block** (CMGST ≠ B): each item goes **CN → CP as soon as it is approved**, independent of the
   other items.
4. **Credit block** (credit limit exceeded and/or overdue, CMGST = B): approved items **stay CN**. The credit
   workflow starts **only when every production item of the order is approved or rejected** (and at least
   one is approved). If all items are rejected, no workflow starts.
5. **Release plan per line.** When the credit workflow starts, every production line is marked: approved in
   YSDA/YSDAX → **goes CN → CP at the final approval**; rejected in YSDA/YSDAX → **stays CN**. The approver
   sees this list in the workflow mail / work item.
   **Final approval** → exactly the planned lines **CN → CP**, the others stay CN.
   **Credit rejected** → the **order is cancelled**: every open line gets the rejection reason from
   `ZSD_SO_REL_CFG-REJ_ABGRU` (e.g. `ZC` "Credit rejected"); lines rejected in YSDA/YSDAX keep reason 63.
6. **Approved items are not shown again in YSDA / YSDAX** even though they stay CN while credit runs
   (the list now filters on the SD + FI approval, not only on CN).
7. **Snapshot.** When the workflow starts, the order net value, every item quantity / value / rejection,
   the credit account, credit control area, currency and payment terms are stored.
8. **Order changes during or after the credit approval** are compared with the snapshot:

   | Change | Result |
   |---|---|
   | credit account, credit control area, currency, payment terms | workflow restarted (new credit decision) |
   | net value above approved value + tolerance (`TOL_PCT`) | restarted |
   | item quantity higher than approved, new item, rejection removed | restarted (new item goes to YSDA first) |
   | lower value / quantity, items rejected (Z8, 63, 00 of ZSD_MASS_CLOSING) | **no restart** (unless `ANY_CHANGE = X`) |
   | texts, dates, partners, delivery block, schedule line category | **no restart** |

   Every decision is written to `ZSD_SO_REL_LOG` with the reason.
9. **One workflow per order.** A second start is refused by the check function module, and if two events
   arrive at the same moment the second workflow ends itself in its first step.
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
1. Domains `ZSD_REL_COST`, `ZSD_REL_CREDIT`, `ZSD_REL_PROD`, `ZSD_REL_OVERALL`, `ZSD_REL_EVENT` (+ `ZSD_REL_TOL_PCT`).
2. Data elements with the same names.
3. Tables `ZSD_SO_REL_H`, `ZSD_SO_REL_I`, `ZSD_SO_REL_LOG`, `ZSD_SO_REL_CFG` (+ table maintenance for CFG).
4. Table types `ZSD_SO_REL_I_TT` and `ZSD_SO_REL_LOG_TT`.
5. Lock object `EZSD_SO_REL`.
6. Messages 015 and 016 in class `ZSD_WF`.
7. Rejection reason for "credit rejected" (e.g. `ZC`) in OVAG, entered in `ZSD_SO_REL_CFG-REJ_ABGRU`.
8. TVARVC variable `ZSD_SO_REL_START_DATE` – **leave it empty until go-live** (empty = cycle switched off).

### Step 3 – Update function module (SE37)
File: `02_new_objects/Z_SD_SO_REL_UPDATE.abap`.
Create function group `ZSD_SO_REL`, then function module `Z_SD_SO_REL_UPDATE`:
Attributes → **Update module, Start immediately**; import parameters **pass by value** as in the file.

### Step 4 – Classes (SE24)
1. `02_new_objects/ZCL_SD_SO_RELEASE.abap` – create the class in source-code based mode and paste.
2. `ZCL_WF_SD_CREDIT->IS_START_ALLOWED`: apply change **A1** of `03_changed_objects/CHANGES_TO_EXISTING_OBJECTS.md`.
3. Activate both classes **together** (they call each other).
4. `02_new_objects/ZCL_WF_SD_SO_REL_STEP.abap` – create and activate.

### Step 5 – Sales order user exits (SE80 → include MV45AFZZ)
Apply changes **B1–B8** of `03_changed_objects/CHANGES_TO_EXISTING_OBJECTS.md`:

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

### Step 6 – YSDA (module pool `YSP_MTOSO_APPROVE`)
Apply changes **C1–C7**: list filter in `SCREEN_START`, per-row BAPI table reset, FI approval no longer sets
CP alone, release-cycle decision when SD + FI are done, release-cycle call after each rejection.

### Step 7 – YSDAX (module pool `YSP_MTOSO_APPROVE_CX`)
Apply changes **D1–D6** (same logic; YSDAX FI approval never set CP, so there is no FI change).

### Step 8 – Workflow WS99000010 (PFTC + SWDD)
File: `03_changed_objects/WS99000010_workflow_changes.md`.
Create three background tasks on `ZCL_WF_SD_SO_REL_STEP` and insert them as: first step (+ duplicate
condition), after the final approval (after the credit block release), after the rejection.
Then apply change **F1** of `CHANGES_TO_EXISTING_OBJECTS.md` in `ZCL_WF_SD_ALERT->BUILD_HTML`: the approver mail
and the work item show every order line with its YSDA/YSDAX decision and "CN → CP" or "stays CN".
Event linkages in SWE2 stay as they are.

### Step 9 – Reports and transactions
1. `02_new_objects/ZSD_SO_REL_RECONCILE.abap` → SE38, variant `DEFAULT` (P_WAIT = 30),
   SM36 job **every 30 minutes**, user with SD change authorization (e.g. the workflow batch user).
2. `02_new_objects/ZSD_SO_REL_MONITOR.abap` → SE38, transaction `ZSD_SO_REL_MON` (SE93).

### Step 10 – Customizing
SM30 `ZSD_SO_REL_CFG`: entries from `DDIC_OBJECTS.md` §6 (confirm the order types with the business).

### Step 11 – Test in QA (all must pass before transport to production)

| # | Scenario | Expected |
|---|---|---|
| 1 | Production order, no credit issue, 2 items | each item CP as soon as it is approved; no workflow; overall 3 |
| 2 | Credit limit exceeded, 1 item | no workflow at save; YSDA approve → item hidden, still CN → workflow starts → final approval → CP |
| 3 | Overdue only | as 2 |
| 4 | Credit limit + overdue | as 2, one workflow |
| 5 | Blocked order, 3 items: approve 1, approve 2 | no workflow yet, items CN |
| 6 | … then reject item 3 | workflow starts now; after approval items 1 + 2 CP, item 3 stays rejected |
| 7 | Blocked order, all items rejected | no workflow, overall 9 |
| 8 | Workflow rejects | all open lines get reason `ZC` (order cancelled), overall 9, log `CREDIT_NOK` + `CANCELLED`, one `ITEM` row per line |
| 8a | Blocked order, YSDA approves line 10, rejects line 20 → credit approved | line 10 CP, line 20 stays CN (reason 63); mail shows the plan; log per line |
| 9 | During workflow: change text / delivery date in VA02 | VA02 allowed, log `NO_RESTART`, workflow continues |
| 10 | During workflow: increase quantity | workflow cancelled, new workflow, log `RESTART` with reason |
| 11 | During workflow: add an item | workflow cancelled; new item in YSDA; after its decision workflow starts again |
| 12 | During workflow: reject an item (YSDA Z8 or ZSD_MASS_CLOSING) | `NO_RESTART` |
| 13 | Order open in VA02 when credit is rejected | rejection step retries; else job cancels; log `CANCEL_ERR` then `CANCELLED` |
| 14 | Final approval while the order is open in VA02 | step retries; else job releases; log `PROD_ERR` then `PROD_REL` |
| 15 | VKM1 release while workflow runs | error 015 |
| 16 | VA02: change CN → CP by hand before credit approval | error 016 |
| 17 | Delete order during workflow | workflow cancelled, overall D |
| 18 | Order type not in ZSD_SO_REL_CFG / created before go-live | exactly as today |
| 19 | VA01 / VA02 save of any order | `ZO2C_CREDITLMIT_CHECK`, `ZSAVE_DIFF_COST_PROFIT`, sales office check etc. run (bug fix of step 5) |
| 20 | YSDA plants 1202 / 1501: VA02 schedule line change after approval | no false "not yet approved" error |
| 21 | Approve 2 rows of different orders in one YSDA click | each order handled separately (BAPI table fix) |

Use transaction `ZSD_SO_REL_MON` (double click = history) and SWI1 / SWIA to follow every test.

### Step 12 – Go-live
1. Transport in this order: DDIC → function group → classes → workflow tasks → workflow → user exits →
   YSDA / YSDAX → reports → customizing.
2. Schedule the reconcile job.
3. Set TVARVC `ZSD_SO_REL_START_DATE` to the go-live date. Orders created before it keep the old logic
   until they are closed.

---

## 4. Decisions taken (change if the business decides differently)

| # | Question | Decision in the code |
|---|---|---|
| 1 | Order types in scope | 1200 YPMT, 1400 ZEM/ZMT, 1500 YCMT, 1600 YXMT (table, easy to change) |
| 2 | Restart after a credit relevant change | new workflow from level 1 |
| 3 | VA02 while the workflow runs | allowed for release-cycle orders (restart rule protects credit); other orders still go to VA03 |
| 4 | Quantity / price change after YSDA approval | YSDA not asked again (only new items go back to YSDA) |
| 5 | Credit rejected | order cancelled: rejection reason `ZC` on every open line (reason code to confirm) |
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
4. **Credit rejection = order cancelled** – confirm the rejection reason code (proposal `ZC` "Credit rejected",
   to create in OVAG) and that **all open lines** are rejected, including lines that were already released
   to production in an earlier credit cycle.
5. **Message numbers** 015 / 016 in `ZSD_WF` – take free numbers if these are used.
