# REQ1 – Sales order release cycle: final status (last version)

Production orders go through YSDA / YSDAX first, line by line. With no credit block an approved line goes
CN → CP at once. With a credit block the credit workflow WS99000010 starts automatically when the last
production line is decided; at final approval exactly the lines approved in YSDA / YSDAX go CN → CP; on
rejection your existing step cancels the order. Normal orders work as today.

You have applied everything **except the workflow and the log**. This file lists every object, the
corrections made after your last apply (part 2), and the remaining workflow / log changes (part 3).

## 1. All objects of the task

| # | Object | Type | Status |
|---|---|---|---|
| 1 | `ZSD_REL_COST`, `ZSD_REL_CREDIT`, `ZSD_REL_PROD`, `ZSD_REL_OVERALL`, `ZSD_REL_EVENT` | domains + data elements | done |
| 2 | `ZSD_SO_REL_H`, `ZSD_SO_REL_I`, `ZSD_SO_REL_LOG` | tables | done |
| 3 | `ZSD_SO_REL_CFG` + 14 entries (SE16N, transported) | table | done |
| 4 | Messages `ZSD_WF` 018, 019 | messages | **check – see 2.3** |
| 5 | TVARVC `ZSD_SO_REL_START_DATE` | parameter | done (set at go-live) |
| 6 | `ZCL_SD_SO_RELEASE` | new class | **re-paste – see 2.1** |
| 7 | `ZCL_WF_SD_CREDIT->IS_START_ALLOWED` (A1) | changed method | **part 3 (workflow)** |
| 8 | MV45AFZZ – 6 enhancements | enhancements | **re-check – see 2.2** |
| 9 | YSDA `YSP_MTOSO_APPROVE` (OOP + N1–N7) | module pool | done |
| 10 | YSDAX `YSP_MTOSO_APPROVE_CX` (OOP + X1–X6) | module pool | done |
| 11 | `ZSD_SO_REL_RECONCILE` + job, `ZSD_SO_REL_MONITOR` + `ZSD_SO_REL_MON` | reports | done |
| 12 | `ZCL_WF_SD_SO_REL_STEP` | new class | **part 3 (workflow)** |
| 13 | Tasks `SO_REL_START`, `SO_REL_APPROVED`, `SO_REL_REJECTED` | PFTC | **part 3 (workflow)** |
| 14 | WS99000010 – 3 new steps | SWDD | **part 3 (workflow)** |
| 15 | Domain `ZWF_ACTION` (+ `YSDA`, `PROD`), `ZCL_WF_LOG_EX` / `_OD` (Fix 03 exemption), `ZCL_WF_LOG_RPT_DATA` (icons) | log | **part 3 (log)** |
| – | Lock object `EZSD_SO_REL` | – | **no longer needed** – delete it if you created it |
| – | Update FM `Z_SD_SO_REL_UPDATE`, function group | – | not used (direct writes) |
| – | Change F1 in `ZCL_WF_SD_ALERT` (lines in the mail) | – | dropped (mail unchanged) |

## 2. Corrections after your last apply – please re-apply

These came from your review of the workflow (duplicate flag, existing lock / kill) and from your package of
19.10.2026. They are needed for the workflow part to work.

### 2.1 `ZCL_SD_SO_RELEASE` – replace the whole source
File `02_new_objects/ZCL_SD_SO_RELEASE.abap`. Changes:

| Method | Change | Why |
|---|---|---|
| `ON_CREDIT_STARTED` | no duplicate check, no return value, no enqueue | duplicate check moved to the start check (A1) – inside the workflow it was too late |
| `ON_WORKFLOW_KILLED` | **new** – credit status back to "open" after your kill | your kill stays the rule for every order; the release cycle must allow the new start |
| `ON_ORDER_SAVED` | no own kill; compares with the snapshot only **after** the credit approval | during approval your lock (VA02 → VA03) and your kill apply |
| `ON_ORDER_DELETED` | no own kill | your `ZEN_CMEXOD_KILL_WORKFLOW_WDEL` kills |
| `CAN_START_CREDIT_WF` | "in approval" no longer blocks | the start check uses your lock row / `FIND_RUNNING` instead |
| `ON_CREDIT_APPROVED`, `PROCESS`, `RELEASE_ITEMS` | no `COMMIT WORK`, no rollback when called from the workflow | your rule: no COMMIT in a synchronous background workflow method |
| `IS_WORKITEM_ACTIVE`, `CANCEL_ORDER`, `GC_REJ_CREDIT` | removed | not needed any more (your `CANCEL_SO` cancels) |

### 2.2 MV45AFZZ – compare with `03_changed_objects/MV45AFZZ_ENHANCEMENTS_COMPLETE.abap`

| Enhancement | Last version |
|---|---|
| `ZEN_CMEXOD_KILL_WORKFLOW` | **your v2.0** (STATICS re-entrancy guard) + CHECK → IF + `ON_WORKFLOW_KILLED` when the kill returned true. No exception for release-cycle orders any more. → applied with the workflow (part 3) |
| `ZEN_SO_RELEASE_SAVE` (new) | unchanged |
| `ZEN_CMEXOD_KILL_WORKFLOW_WDEL` | your kill for every order, then `ON_ORDER_DELETED` (no `IS_MANAGED` split any more) |
| `ZEN_SO_RELEASE_NO_VKM` (new) | message **E018** |
| `ZSD_CHECK_APPROVAL` | plant fix + CN → CP check with message **E019** |
| `ZEN_DISAB_VA02_CM_WF_RUNNINNG` | only CHECK → IF (redirect to VA03 for every order, no `IS_MANAGED` exception) |

### 2.3 Messages
`ZSD_WF 017` is your kill message (package of 19.10.2026). The release cycle uses **018**
`Order &1 in credit approval - release via workflow` and **019** `Item &1: no CN->CP before credit approval`.
If you created them as 017 / 018, renumber them and change `E017` → `E018` in `ZEN_SO_RELEASE_NO_VKM` and
`E018` → `E019` in `ZSD_CHECK_APPROVAL`.

## 3. Remaining: workflow and log

See the next chapter (also file `03_changed_objects/WS99000010_workflow_changes.md`).

Order of work:
1. Re-paste `ZCL_SD_SO_RELEASE` (2.1), activate.
2. Create `ZCL_WF_SD_SO_REL_STEP`, activate.
3. A1 in `ZCL_WF_SD_CREDIT->IS_START_ALLOWED`; check that `Z_FM_SD_WF_CHECK_CREDIT` is set in SWE2.
4. MV45AFZZ: `ZEN_CMEXOD_KILL_WORKFLOW` last version, plus the corrections of 2.2 / 2.3.
5. Log: domain values `YSDA` / `PROD`, Fix 03 exemption for `PROD`, report icons.
6. PFTC: three tasks. SWDD: three steps, activate.
7. Tests (chapter 3, section 10).
