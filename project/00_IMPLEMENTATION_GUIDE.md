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
| `03_changed_objects/MV45AFZZ_changes.abap` | 6 changes in the sales order user exits |
| `03_changed_objects/ZCL_WF_SD_CREDIT_IS_START_ALLOWED.abap` | 1 method of the existing credit class |
| `03_changed_objects/YSDA_YSP_MTOSO_APPROVE_changes.abap` | YSDA: list filter, APPROVE_FUN, REJECT_FUN |
| `03_changed_objects/YSDAX_YSP_MTOSO_APPROVE_CX_changes.abap` | YSDAX: list filter, APPROVE_FUN, REJECT_FUN |
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
5. **Credit workflow final approval** → all approved items **CN → CP**. **Rejection** → items stay CN.
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
   | any value / quantity change **after a credit rejection** | credit approval asked again |

   Every decision is written to `ZSD_SO_REL_LOG` with the reason.
9. **One workflow per order.** A second start is refused by the check function module, and if two events
   arrive at the same moment the second workflow ends itself in its first step.
10. **Manual shortcuts are closed.** VKM1 / VKM3 / VKM4 release is refused while the credit workflow runs;
    CN → CP by hand in VA02 is refused until the item is approved in YSDA/YSDAX **and** credit is approved
    or not needed.
11. **Safety net.** Job `ZSD_SO_REL_RECONCILE` releases items whose release failed (order locked), raises
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
4. Table type `ZSD_SO_REL_I_TT`.
5. Lock object `EZSD_SO_REL`.
6. Messages 015 and 016 in class `ZSD_WF`.
7. TVARVC variable `ZSD_SO_REL_START_DATE` – **leave it empty until go-live** (empty = cycle switched off).

### Step 3 – Update function module (SE37)
File: `02_new_objects/Z_SD_SO_REL_UPDATE.abap`.
Create function group `ZSD_SO_REL`, then function module `Z_SD_SO_REL_UPDATE`:
Attributes → **Update module, Start immediately**; import parameters **pass by value** as in the file.

### Step 4 – Classes (SE24)
1. `02_new_objects/ZCL_SD_SO_RELEASE.abap` – create the class in source-code based mode and paste.
2. `03_changed_objects/ZCL_WF_SD_CREDIT_IS_START_ALLOWED.abap` – in the existing class `ZCL_WF_SD_CREDIT`
   replace the method `IS_START_ALLOWED` (new block marked `REQ1`).
3. Activate both classes **together** (they call each other).
4. `02_new_objects/ZCL_WF_SD_SO_REL_STEP.abap` – create and activate.

### Step 5 – Sales order user exits (SE80 → include MV45AFZZ)
File: `03_changed_objects/MV45AFZZ_changes.abap` – six changes, each block is complete:

| # | User exit (FORM) | Enhancement | Action |
|---|---|---|---|
| 1 | `USEREXIT_SAVE_DOCUMENT` | `ZEN_CMEXOD_KILL_WORKFLOW` | replace code (IF instead of CHECK, skip release-cycle orders) |
| 2 | `USEREXIT_SAVE_DOCUMENT` | **new** `ZEN_SO_RELEASE_SAVE` | create at the same enhancement point |
| 3 | `USEREXIT_DELETE_DOCUMENT` | `ZEN_CMEXOD_KILL_WORKFLOW_WDEL` | replace code |
| 4 | `USEREXIT_SAVE_DOCUMENT_PREPARE` | **new** `ZEN_SO_RELEASE_NO_VKM` | create |
| 5 | `USEREXIT_MOVE_FIELD_TO_VBEP` | `ZSD_CHECK_APPROVAL` | replace code |
| 6 | `USEREXIT_READ_DOCUMENT` | `ZEN_DISAB_VA02_CM_WF_RUNNINNG` | replace code |

> **Existing bug fixed by change 1:** `ZEN_CMEXOD_KILL_WORKFLOW` begins with `CHECK`. A failing CHECK in an
> enhancement leaves the whole user exit, so today **every enhancement after it in USEREXIT_SAVE_DOCUMENT**
> (`ZO2C_CREDITLMIT_CHECK`, `ZSAVE_DIFF_COST_PROFIT`, `ZSD_DISCOUNT_BLOCK`, ...) is skipped unless the order is
> changed in VA02 *and* locked by the workflow. After change 1 they run again on every save – **test them**.
>
> **Existing bug fixed by change 5:** the approval was read with `BUKRS = VBAK-BUKRS_VF`, but YSDA/YSDAX
> store the **plant** in `ZSOAPPROVAL-BUKRS`, so orders of plants 1202 / 1501 were always "not approved".

### Step 6 – YSDA (SE80 → module pool `YSP_MTOSO_APPROVE`)
File: `03_changed_objects/YSDA_YSP_MTOSO_APPROVE_changes.abap`.
1. Include `YSP_MTOSO_APPROVE_SCREEN_STF01`, FORM `SCREEN_START`: insert the block after the big SELECT
   (`... vbak~audat <= datev_t.`) – hides items already approved by SD + FI.
2. Include `YSP_MTOSO_APPROVE_APPROVE_FF01`: replace the whole FORM `APPROVE_FUN`.
   - FI approval now only removes the Z8 rejection; it no longer sets CP by itself.
   - When SD + FI are both done: `ZCL_SD_SO_RELEASE->ON_ITEM_DECISION`; orders outside the cycle keep the
     old CN → CP code.
   - BAPI tables are cleared for every selected row (before, the 2nd row re-sent the 1st row's lines).
3. Include `YSP_MTOSO_APPROVE_REJECT_FUF01`: replace the whole FORM `REJECT_FUN` (calls
   `ON_ITEM_DECISION` after each rejection, so the workflow starts when the last open item is rejected).

### Step 7 – YSDAX (SE80 → module pool `YSP_MTOSO_APPROVE_CX`)
File: `03_changed_objects/YSDAX_YSP_MTOSO_APPROVE_CX_changes.abap` – same three changes in
`YSP_MTOSO_APP_SCREEN_STF01_CX`, `YSP_MTOSO_APPROVE_FF01_CX`, `YSP_MTOSO_APP_REJECT_FUF01_CX`.

### Step 8 – Workflow WS99000010 (PFTC + SWDD)
File: `03_changed_objects/WS99000010_workflow_changes.md`.
Create three background tasks on `ZCL_WF_SD_SO_REL_STEP` and insert them as: first step (+ duplicate
condition), after the final approval (after the credit block release), after the rejection.
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
| 8 | Workflow rejects | items stay CN, overall 9, log `CREDIT_NOK` |
| 9 | During workflow: change text / delivery date in VA02 | VA02 allowed, log `NO_RESTART`, workflow continues |
| 10 | During workflow: increase quantity | workflow cancelled, new workflow, log `RESTART` with reason |
| 11 | During workflow: add an item | workflow cancelled; new item in YSDA; after its decision workflow starts again |
| 12 | During workflow: reject an item (YSDA Z8 or ZSD_MASS_CLOSING) | `NO_RESTART` |
| 13 | After rejection: reduce quantity | credit asked again (new workflow) |
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
| 5 | Credit rejected | items stay CN; a later value / quantity change asks credit again |
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
4. **Message numbers** 015 / 016 in `ZSD_WF` – take free numbers if these are used.
