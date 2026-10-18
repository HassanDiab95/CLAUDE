# WS99000010 – workflow and log changes (last part of REQ1)

Based on your package `ZSD_SO_CREDIT_WF` of 19.10.2026 (version 2.0 of `ZEN_CMEXOD_KILL_WORKFLOW`, Fix 01 – 04,
log classes `ZCL_WF_LOG_EX` / `_OD`, `ZSD_WF_CREDIT_EXCEED_SO`).

**Unchanged:** approval levels and loop, `GET_APPROVERS`, `APPROVE_IN_LOOP`, `REJECT_IN_LOOP`, `RELEASE_SO`,
`CANCEL_SO`, the order lock `ZSD_WF_SO`, the approver mail and SBWP HTML, the decision exits, the log report,
the event linkage and the check FM `Z_FM_SD_WF_CHECK_CREDIT`.

## 1. Why the workflow needs changes

The workflow decides credit for the **whole order**; YSDA / YSDAX decide **each line**.

| Without a change | Change |
|---|---|
| The workflow would start at order save, **before** YSDA / YSDAX decided the lines | start check A1 – a release-cycle order may start only after all its production lines are decided |
| Two start events close together (YSDA last line + order save) could start a second run; your check FM only checks the credit block | start check A1 – no start while the order has the lock row or a running WS99000010 (checked **before** the start: no work item, no log, no mail) |
| `RELEASE_SO` releases the credit block, but the lines approved in YSDA stay **CN** | step `SO_REL_APPROVED` – CN → CP for exactly those lines |
| Your log does not show which lines YSDA approved / rejected and which lines went to production | the new steps write rows into your EX / OD log (actions `YSDA`, `PROD`) |

## 2. Start check – `ZCL_WF_SD_CREDIT->IS_START_ALLOWED` (change A1)

After the start date check insert:
```abap
    IF IS_ORDER_LOCKED( IV_VBELN ) = ABAP_TRUE
    OR FIND_RUNNING( IV_VBELN ) IS NOT INITIAL.
      RETURN.
    ENDIF.

    IF NEW ZCL_SD_SO_RELEASE( )->CAN_START_CREDIT_WF( IV_VBELN )
       = ZCL_SD_SO_RELEASE=>GC_START-NO.
      RETURN.
    ENDIF.
```
- Lock row or running work item → `RV_START` stays false → the check FM raises `NOT_RELEVANT` → no second run.
  Both are checked because a run that has just started has its lock row (`GET_APPROVERS`) before its work
  items are visible (your incident of 04.10.2026). After a kill, `RELEASE_SO` or `CANCEL_SO` both are gone.
- `CAN_START_CREDIT_WF`: release-cycle order → no start while a production line is open in YSDA / YSDAX, or
  after the order was cancelled / deleted. Normal orders → no effect.
- **Prerequisite:** `Z_FM_SD_WF_CHECK_CREDIT` must be set as check function module in SWE2 (open item §9 of
  your guide). Without it `IS_START_ALLOWED` is never called.

## 3. Kill on change – `ZEN_CMEXOD_KILL_WORKFLOW` (your version 2.0 + B1 / B2)

Complete code in `MV45AFZZ_ENHANCEMENTS_COMPLETE.abap`. Your re-entrancy guard (`STATICS LT_DONE`) stays.
New: CHECK → IF, and when `KILL_RUNNING_WORKFLOW` returns true (a running run was really cancelled – your
Fix 01) one call `ZCL_SD_SO_RELEASE->ON_WORKFLOW_KILLED`, which sets the release cycle back to "credit open"
so the new start is allowed. For normal orders it does nothing.

## 4. Class `ZCL_WF_SD_SO_REL_STEP` (SE24)

File `02_new_objects/ZCL_WF_SD_SO_REL_STEP.abap`. Three static methods, each called by one background task.
Each writes into your logs with the same rule as `APPROVE_IN_LOOP`: EX log = `LOG_ID` (unless `LOG_AREA = 'OD'`),
OD log = `LOG_ID` when `LOG_AREA = 'OD'`, otherwise `LOG_ID_OD`.
No `COMMIT WORK` in any of them (your rule in §7 of the package guide) – the workflow runtime commits.

| Method | Calls | Log row(s) |
|---|---|---|
| `CREDIT_STARTED` | `ZCL_SD_SO_RELEASE->ON_CREDIT_STARTED` – credit "in approval", snapshot, release plan | one `YSDA` row per production line: `Item 10 <material>: Approved 20.10.2026 USER1 -> CN -> CP after approval` / `Item 20 …: Rejected (63) … -> Stays CN` |
| `CREDIT_APPROVED` | `ON_CREDIT_APPROVED` – CN → CP for the planned lines | one `PROD` row: `Released to production (CN -> CP): 10, 30. Stays CN: 20` |
| `CREDIT_REJECTED` | `ON_CREDIT_REJECTED` – records the lines, no change to the order | one `PROD` row: `Credit rejected - no item released to production. Items stay CN: 10, 20, 30` |

## 5. Three standard tasks (PFTC)

For each: *Object category* **ABAP Class**, *Object type* `ZCL_WF_SD_SO_REL_STEP`, method as below,
**Synchronous object method**, **Background processing**, *General task*. Accept the container proposal.

| Task (new number) | Abbreviation / text | Method | Container (import) |
|---|---|---|---|
| TS9xxxxxx1 | `SO_REL_START` – Release cycle: credit started | `CREDIT_STARTED` | IV_VBELN, IV_WI_ID, IV_LOG_ID, IV_LOG_ID_OD, IV_LOG_AREA |
| TS9xxxxxx2 | `SO_REL_APPROVED` – Release cycle: credit approved | `CREDIT_APPROVED` | IV_VBELN, IV_LOG_ID, IV_LOG_ID_OD, IV_LOG_AREA |
| TS9xxxxxx3 | `SO_REL_REJECTED` – Release cycle: credit rejected | `CREDIT_REJECTED` | IV_VBELN, IV_NOTE, IV_ABGRU, IV_LOG_ID, IV_LOG_ID_OD, IV_LOG_AREA |

`SO_REL_APPROVED` only: tab *Temporary error* → retry **10 times every 15 minutes** (order locked in VA02 →
CN → CP cannot be saved yet; after the retries job `ZSD_SO_REL_RECONCILE` does it).
After any later signature change: PFTC → Additional data → Object method → Change → Yes (your note §7).

## 6. Steps in WS99000010 (SWDD – new version)

### 6.1 `SO_REL_START` – directly after `GET_APPROVERS`
- Step type **Activity**, task `SO_REL_START`, *Background step*
- Binding: `&SALES_ORDER&` → `IV_VBELN`, `&_WORKITEM.ID&` → `IV_WI_ID` (F4 on `_WORKITEM`), `&LOG_ID&` →
  `IV_LOG_ID`, `&LOG_ID_OD&` → `IV_LOG_ID_OD`, `&LOG_AREA&` → `IV_LOG_AREA`
- **Why after `GET_APPROVERS`:** the logs (`LOG_ID` / `LOG_ID_OD`) and the lock row exist only after it, and
  the `YSDA` rows must go into those logs. It runs before `BUILD_ALERT` / `NOTIFY_START`, so the status is
  set before the first mail. Normal orders: nothing is written.

### 6.2 `SO_REL_APPROVED` – after `APPROVE_STEP` (`RELEASE_SO`)
In both places where `APPROVE_STEP` is used (nodes 227 and 238), insert directly **after** it:
- Step type **Activity**, task `SO_REL_APPROVED`, *Background step*
- Binding: `&SALES_ORDER&` → `IV_VBELN`, `&LOG_ID&`, `&LOG_ID_OD&`, `&LOG_AREA&` → `IV_LOG_ID`,
  `IV_LOG_ID_OD`, `IV_LOG_AREA`
- **Why after `RELEASE_SO`:** CN → CP must happen only after the credit block is released, and only after
  `RELEASE_SO` deleted the lock row `ZSD_WF_SO` – otherwise the BAPI that changes the schedule lines would run
  through `ZEN_CMEXOD_KILL_WORKFLOW` with the lock row present and kill this workflow.

### 6.3 `SO_REL_REJECTED` – before `REJECT_STEP` (`CANCEL_SO`)
In both places where `REJECT_STEP` is used (nodes 233 and 243), insert directly **before** it:
- Step type **Activity**, task `SO_REL_REJECTED`, *Background step*
- Binding: `&SALES_ORDER&` → `IV_VBELN`, decision note → `IV_NOTE`, `&REASON&` → `IV_ABGRU`, `&LOG_ID&`,
  `&LOG_ID_OD&`, `&LOG_AREA&` → `IV_LOG_ID`, `IV_LOG_ID_OD`, `IV_LOG_AREA`
- **Why before `CANCEL_SO`:** it records the lines while the order still exists in its current state; it
  does not change the order. `CANCEL_SO` then cancels it as today and writes `CANC`.

### 6.4 Activate
Check and activate the new version. Running workflows stay on the old version.

## 7. Log changes (your log classes and report)

| # | Object | Change | Why |
|---|---|---|---|
| L1 | Domain of `ZWF_ACTION` (SE11) | add fixed values `YSDA` "YSDA/YSDAX line decision" and `PROD` "Production release (CN/CP)" | the log report reads the action text from the domain (`ACTION_TEXT`) |
| L2 | `ZCL_WF_LOG_EX`, `ZCL_WF_LOG_OD` → `ADD_ITEM` (your Fix 03 guard) | exempt `PROD` like `RELS`: `IF LV_HDR_STATUS <> GC_STATUS-IN_PROCESS AND IV_ACTION <> GC_ACTION-RELEASE AND IV_ACTION <> 'PROD'.` | the `PROD` row is written after `FINISH` (approved / rejected), like `RELS`; without the exemption Fix 03 drops it |
| L3 | `ZCL_WF_LOG_RPT_DATA` → `ACTION_ICON` (optional) | `WHEN 'YSDA' THEN ICON_CHECKED` and `WHEN 'PROD' THEN ICON_SYSTEM_START` | icons in the log report; without it the rows show no icon |

The `YSDA` rows are written while the log is still "In process", so Fix 03 lets them through without change.
Your report `ZWF_LOG_SO` then shows, per order: `STRT` → `YSDA` (one per line) → `MAIL` → `APPR` … `FINL` →
`RELS` → `PROD` (or `REJC` → `PROD` → `CANC`).

## 8. Messages
`ZSD_WF 017` is your kill message. The release cycle uses **018** (VKM1 refused) and **019** (manual CN → CP
refused). If you already created our messages as 017 / 018, renumber them and change `ZEN_SO_RELEASE_NO_VKM`
and `ZSD_CHECK_APPROVAL` to `E018` / `E019` (complete code in `MV45AFZZ_ENHANCEMENTS_COMPLETE.abap`).

## 9. The whole flow

```
VA01 save (production order, credit block)
   └─ BUS2032 CREATED → check FM → A1: YSDA not finished → NOT_RELEVANT
YSDA / YSDAX: last production line approved or rejected
   ├─ no credit block → approved lines CN → CP at once, no workflow
   └─ credit block    → RAISE_START_EVENT → IS_START_ALLOWED → SAP_WAPI_START_WORKFLOW( 'WS99000010' )
        ├─ GET_APPROVERS        logs STRT, lock row            (unchanged)
        ├─ SO_REL_START         log YSDA rows, credit "in approval", release plan
        ├─ BUILD_ALERT / NOTIFY_START / approval loop          (unchanged)
        ├─ final: APPROVE_STEP (RELEASE_SO, lock deleted) → SO_REL_APPROVED → CN → CP, log PROD
        └─ reject: SO_REL_REJECTED (log PROD) → REJECT_STEP (CANCEL_SO, log CANC)
VA02 change while in approval (opened before the lock)
   └─ ZEN_CMEXOD_KILL_WORKFLOW → KILL_RUNNING_WORKFLOW (log KILL) → ON_WORKFLOW_KILLED
      → the save raises CHANGED → A1 → new run
```

## 10. Test
1. SWELS on. Save a credit-blocked production order → BUS2032 CREATED, receiver not started.
2. Decide the last line in YSDA → WS99000010 started directly (SWI1; no other template started); `ZWF_LOG_SO`: `STRT`, then one `YSDA`
   row per line.
3. SWUE BUS2032 CHANGED for the same order while it runs → `NOT_RELEVANT`, no second run, no second log.
4. Final approval → `RELS`, then `PROD` "Released to production: …"; VA03: those lines CP, rejected lines CN;
   the workflow is not killed by the CN → CP change.
5. Rejection → `REJC`, `PROD` "Credit rejected …", `CANC`; order cancelled as today.
6. Normal order → workflow and log exactly as today (no `YSDA` / `PROD` rows).
