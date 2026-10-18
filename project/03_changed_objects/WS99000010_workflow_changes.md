# WS99000010 – all changes related to the credit workflow

Everything that touches the credit workflow, in one place: the start check, the workflow steps and the order
lock / kill rules. **Unchanged**: approval levels, decisions, the approver mail (HTML), your logs
(`ZCL_WF_LOG_OD` / `ZCL_WF_LOG_EX`), the existing `REJECT_STEP`, the order lock table `ZSD_WF_SO`, the
event linkages and the check function module `Z_FM_SD_WF_CHECK_CREDIT`.

## 1. What stays exactly as today (your existing rules – now also for production orders)

| Existing rule | Where | Release-cycle orders |
|---|---|---|
| Only one workflow per order while it is in approval (order lock `ZSD_WF_SO`) | WS99000010 / `ZCL_WF_SD_CREDIT` | same |
| VA02 is redirected to VA03 while the order is in approval | `ZEN_DISAB_VA02_CM_WF_RUNNINNG` | same (only CHECK → IF) |
| A change in VA02 while the workflow runs cancels it; the new save starts a new check | `ZEN_CMEXOD_KILL_WORKFLOW` | same (+ the release cycle is told, see 3.3) |
| Delete cancels the running workflow | `ZEN_CMEXOD_KILL_WORKFLOW_WDEL` | same (+ order marked deleted in the release cycle) |
| Rejection cancels the order | `REJECT_STEP` (TS99000044) | same – not changed |

## 2. Why the workflow still needs changes

The workflow decides credit for the **whole order**; YSDA / YSDAX decide **each line**.

| Problem without a change | Change |
|---|---|
| The workflow would start at order save, **before** YSDA / YSDAX decided the lines | start check A1: a release-cycle order may start only after all production lines are decided |
| Two start events at the same time (YSDA approves the last line + an order save) could start two workflows – your current check FM only checks the credit block | start check A1: no start if a WS99000010 already runs for the order (checked **before** the start, so no work item and no log is created) |
| Final approval releases the credit block, but the approved lines stay on **CN** – nothing converts them to CP | new step `SO_REL_APPROVED` |
| The release cycle does not know that credit is in approval / approved / rejected | new steps `SO_REL_START`, `SO_REL_APPROVED`, `SO_REL_REJECTED` |

**`REL_DUPLICATE` is removed.** A check inside the workflow comes too late: the workflow has already started
and written its log. The duplicate check is now in the start check (A1), using your existing method
`FIND_RUNNING`. No new container element is needed.

## 3. Changes – step by step

### 3.1 Start check – `ZCL_WF_SD_CREDIT->IS_START_ALLOWED` (SE24) – change A1
After the go-live date check, insert:
```abap
    IF FIND_RUNNING( IV_VBELN ) IS NOT INITIAL.
      RETURN.
    ENDIF.

    IF NEW ZCL_SD_SO_RELEASE( )->CAN_START_CREDIT_WF( IV_VBELN )
       = ZCL_SD_SO_RELEASE=>GC_START-NO.
      RETURN.
    ENDIF.
```
- **`FIND_RUNNING`** (your existing private method): a WS99000010 is already running for this order →
  `RETURN` (start not allowed) → the check FM raises `NOT_RELEVANT` → no second workflow. Valid for every
  order. After a change in VA02 your kill cancels the old workflow first, so the new start is still allowed.
- **`CAN_START_CREDIT_WF`**: for a release-cycle order → no start while any production line is still open in
  YSDA / YSDAX, no start after the order was cancelled or deleted. For normal orders it answers "not managed"
  and nothing changes.

### 3.2 Class `ZCL_WF_SD_SO_REL_STEP` (SE24)
File `02_new_objects/ZCL_WF_SD_SO_REL_STEP.abap` → create, paste, activate (`ZCL_SD_SO_RELEASE` must be active).
**Why:** a workflow task can only call a class that implements `IF_WORKFLOW`.

### 3.3 MV45AFZZ – what changes for the workflow
(complete code in `MV45AFZZ_ENHANCEMENTS_COMPLETE.abap`)
- `ZEN_CMEXOD_KILL_WORKFLOW`: CHECK → IF; after `KILL_RUNNING_WORKFLOW` one new line
  `NEW ZCL_SD_SO_RELEASE( )->ON_WORKFLOW_KILLED( VBAK-VBELN ).` – sets the credit status of the release cycle
  back to "open", so the new start is allowed. For normal orders it does nothing.
- `ZEN_CMEXOD_KILL_WORKFLOW_WDEL`: CHECK → IF; after the kill `ON_ORDER_DELETED` marks the order deleted.
- `ZEN_DISAB_VA02_CM_WF_RUNNINNG`: CHECK → IF only (the redirect to VA03 stays for every order).
- `ZEN_SO_RELEASE_NO_VKM` (new): no manual credit release in VKM1 / VKM3 / VKM4 while the workflow runs for a
  release-cycle order (error 017) – otherwise the approved lines would never go to CP.

**Why CHECK → IF:** a failing CHECK in an enhancement leaves the whole user exit, so every enhancement after
it (e.g. `ZO2C_CREDITLMIT_CHECK`, `ZSAVE_DIFF_COST_PROFIT`) was skipped.

### 3.4 Three standard tasks (PFTC)
For each task: *Object category* **ABAP Class**, *Object type* `ZCL_WF_SD_SO_REL_STEP`, method as below,
tick **Synchronous object method** and **Background processing**, Additional data → Agent assignment →
**General task**; accept the container proposal.

| Task (new number) | Abbreviation / text | Method | Container |
|---|---|---|---|
| TS9xxxxxx1 | `SO_REL_START` – Release cycle: credit started | `CREDIT_STARTED` | IV_VBELN, IV_WI_ID |
| TS9xxxxxx2 | `SO_REL_APPROVED` – Release cycle: credit approved | `CREDIT_APPROVED` | IV_VBELN |
| TS9xxxxxx3 | `SO_REL_REJECTED` – Release cycle: credit rejected | `CREDIT_REJECTED` | IV_VBELN, IV_NOTE, IV_ABGRU |

`SO_REL_APPROVED` only: tab *Temporary error* → retry **10 times every 15 minutes** (if the order is locked,
CN → CP cannot be saved yet; after the retries the job `ZSD_SO_REL_RECONCILE` does it).

### 3.5 Step `SO_REL_START` – first step of the workflow (SWDD, new version)
Insert **before** the current first step ("Check Blocked Flag"):
- Step type **Activity**, task `SO_REL_START`, *Background step*
- Binding workflow → task: `&SALES_ORDER&` → `IV_VBELN`, `&_WORKITEM.ID&` → `IV_WI_ID`
  (system element `_WORKITEM`, attribute ID – choose it with F4)
- no binding back, no condition after it

**Why:** records in the release tables that credit is "in approval", stores the snapshot (net value,
quantities, credit account, currency, payment terms) used for changes **after** the approval, and fixes the
release plan (which lines go CN → CP at the final approval, which stay CN). For normal orders it does nothing.

### 3.6 Step `SO_REL_APPROVED` – after the final approval
In the final-approval path (*CHECK_FINAL_APPROVAL* = true, after "Approve Release Sales Order") insert
**after** the step that releases the SAP credit block (in every place where the final approval exists):
- Step type **Activity**, task `SO_REL_APPROVED`, *Background step*
- Binding: `&SALES_ORDER&` → `IV_VBELN`

**Why:** sends the lines approved in YSDA / YSDAX to production (CN → CP); lines rejected in YSDA / YSDAX
stay CN. After the credit block release, otherwise lines would go to production while the order is blocked.

### 3.7 Step `SO_REL_REJECTED` – on rejection
Insert **directly before** the existing `REJECT_STEP` (task TS99000044 "Cancel Sales Order Credit") in both
places where it is used (nodes 233 and 243):
- Step type **Activity**, task `SO_REL_REJECTED`, *Background step*
- Binding: `&SALES_ORDER&` → `IV_VBELN`, decision note → `IV_NOTE`, `&REASON&` → `IV_ABGRU`

**Why:** records every line as YSDA / YSDAX decided it and sets credit status "rejected". It does not change
the order – your `REJECT_STEP` cancels it right after, as today.

### 3.8 Activate
Check and activate the new version. Running workflows stay on the old version; new starts use the new one.

### 3.9 Event linkages (SWE2) – no change
`BUS2032 CREATED` / `CHANGED` → WS99000010, check FM `Z_FM_SD_WF_CHECK_CREDIT` (unchanged; the new logic is in
`IS_START_ALLOWED`, 3.1).
**Start without VA02:** when the last production line of a credit-blocked order is decided in YSDA / YSDAX,
`ZCL_SD_SO_RELEASE` raises BUS2032 `CHANGED` (with `SOLDTOPARTY`) → linkage → check FM → WS99000010. The
initiator is the YSDA / YSDAX user.

## 4. The whole flow

```
VA01 save (production order, credit block)
   └─ BUS2032 CREATED → check FM → A1: YSDA not finished → NOT_RELEVANT (no workflow yet)
YSDA / YSDAX: last production line approved or rejected
   └─ no credit block → approved lines CN → CP at once, no workflow
   └─ credit block    → BUS2032 CHANGED → check FM → A1: none running, YSDA finished → WS99000010
        ├─ SO_REL_START            → release tables: "in approval", snapshot, release plan
        ├─ your approval levels, mails, logs (unchanged); order locked, VA02 → VA03
        ├─ final approval → credit block released → SO_REL_APPROVED → approved lines CN → CP
        └─ rejection → SO_REL_REJECTED (lines recorded) → REJECT_STEP (order cancelled, unchanged)
VA02 change during approval (if the order was opened before the lock)
   └─ your kill cancels the workflow → ON_WORKFLOW_KILLED → the save raises CHANGED → new workflow
```

## 5. Test
1. SWELS → event trace on. Credit-blocked production order: save in VA01 → SWEL shows BUS2032 CREATED,
   receiver not started (check FM `NOT_RELEVANT`).
2. Approve / reject the lines in YSDA → after the last line SWEL shows BUS2032 CHANGED, receiver WS99000010
   started; SWI1 → `SO_REL_START` is the first step.
3. Raise BUS2032 CHANGED again (SWUE) while the workflow runs → check FM `NOT_RELEVANT`, no second workflow,
   no second log.
4. Final approval → `SO_REL_APPROVED` → VA03: lines approved in YSDA are CP, rejected lines CN.
5. Rejection → `SO_REL_REJECTED`, then `REJECT_STEP` → order cancelled as today.
6. Normal order (no production lines) → workflow starts at VA01 save as today.
