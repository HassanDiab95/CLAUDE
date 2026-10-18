# Sales Order Credit Approval Workflow — WS99000010

Technical package and handover guide.

| | |
|---|---|
| Workflow | **WS99000010** — Sales Order Credit Exceed and Overdue |
| Related workflow | WS99000007 — BP Credit Limit Request (shares the log and mail layer) |
| System / client | QE3 / 400 (QAS), DE3 / 100 (DEV) |
| Package | ZSD |
| Transports | DE3K932563 (new objects), DE3K932476 (existing objects), DE3K932647 (ZSD_WF_RESTART) |
| Technical Consultant | Hassan Diab |
| Functional Consultant | Nourhan Leila |
| Package built | 19.10.2026 |

---

## 1. What the workflow does

A sales order saved with a credit block raises the start event for
WS99000010. The workflow determines who must approve, writes a log, notifies
the approvers by e-mail and in SBWP, and on final approval releases the
credit block (or cancels the order on rejection).

Two independent reasons can block an order, and both are evaluated in the
same run:

- **Exceed** — credit exposure plus this order's net value is above the
  customer's credit limit. Approvers come from `ZWF_USERS` with
  `TYPE = 5`, selected by the exceeded amount or percentage range.
- **Overdue** — the customer has open items past their payment term.
  Approvers come from `ZWF_USERS` with `TYPE = 6`, selected by the overdue
  percentage range.

### The combined branch

When an order is both exceeded **and** overdue, the design is deliberately
asymmetric and this is the part most likely to be misread:

- **One** approval loop runs, using the **exceed** approver chain.
- **Two** logs are created — one in `ZWF_LOG_EX_*`, one in `ZWF_LOG_OD_*` —
  and both carry the same approver chain in their `STRT` rows.
- Every subsequent action (`APPR`, `FINL`, `REJC`, `CANC`, `RELS`) is written
  to **both** logs.
- **One** e-mail per approval step, not one per log.

This is done in `ZSD_WF_CREDIT_EXCEED_SO->GET_APPROVERS`:

```abap
    IF EXCEED_FLAG = ABAP_TRUE AND OVERDUE_FLAG = ABAP_TRUE.
      CLEAR: OVERDUE_FLAG, USERS_OD, USERS_OD_WI,
             LEVELS_OD, CURRENT_LEVEL_OD.
    ENDIF.
```

and the overdue log is started with the exceed users:

```abap
    IT_USERS = COND #( WHEN EXCEED_FLAG = ABAP_TRUE THEN USERS ELSE USERS_OD )
```

**The EX and OD number ranges are separate.** Log 1612 and log 1815 can be the
same order and the same run. Never pair logs by ID proximity — always pair on
`VBELN`.

---

## 2. Runtime flow

```
Sales order saved with credit block
        │
        ▼
Start event  ──►  WS99000010
        │
        ▼
ZSD_WF_CREDIT_EXCEED_SO->GET_APPROVERS
        │  ZCL_WF_SD_CREDIT   order / partner / credit / overdue data
        │  ZCL_WF_SD_FINDER   approver determination (ZWF_CONTROL driven)
        │  ZCL_WF_LOG_EX / _OD->START      writes header + STRT rows
        │  ZCL_WF_SD_CREDIT->SET_ORDER_LOCK   inserts ZSD_WF_SO
        ▼
BUILD_ALERT  ──►  ZCL_WF_SD_ALERT->BUILD_W3HTML   (SBWP description)
NOTIFY_START ──►  ZCL_WF_MAIL_CREDIT->NOTIFY_FROM_LOG   (level 1 mail)
        ▼
UNTIL loop, one user decision per level
        │
        ├─ Approve ──► APPROVE_IN_LOOP   both logs + mail to next level
        ├─ Reject  ──► REJECT_IN_LOOP    both logs, status R
        └─ Return  ──► ZCL_SWF_IFS_DECISION_EX_EXIT   RETN row + mail
        ▼
Final level approved  ──►  RELEASE_SO    SD_ORDER_CREDIT_RELEASE
Rejected              ──►  CANCEL_SO     SD_ORDER_CREDIT_CANCEL
        ▼
ZSD_WF_SO lock row deleted
```

### Order change while in approval

`MV45AFZZ / USEREXIT_SAVE_DOCUMENT`, enhancement `ZEN_CMEXOD_KILL_WORKFLOW`,
sees the `ZSD_WF_SO` lock row and calls
`ZCL_WF_SD_CREDIT->KILL_RUNNING_WORKFLOW`, which cancels the running work
items, closes the open logs with `KILL` and deletes the lock. The save then
re-triggers the credit check and a fresh run starts.

---

## 3. Object inventory

### 3.1 In this package

| Folder | Object | Type | Notes |
|---|---|---|---|
| 01_workflow | `WS99000010.XML` | Workflow | Full export |
| 01_workflow | `WS99000007.XML` | Workflow | BP limit, shares log/mail layer |
| 02_core_classes | `ZSD_WF_CREDIT_EXCEED_SO` | Class (BO) | **patched**, see §5 |
| 02_core_classes | `ZCL_WF_SD_CREDIT` | Class | **patched**, see §5 |
| 02_core_classes | `ZCL_WF_SD_FINDER` | Class | Approver determination |
| 03_alert_mail | `ZCL_WF_SD_ALERT` | Class | HTML for SBWP and mail |
| 03_alert_mail | `ZCL_WF_MAIL_CREDIT` | Class | Project mail builder |
| 03_alert_mail | `ZCL_WF_NOTE_READER` | Class | Reads the decision note (SOFM) |
| 04_decision_exits | `ZCL_SWF_IFS_DECISION_EX_EXIT` | Class | Return agent, exceed branch |
| 04_decision_exits | `ZCL_SWF_IFS_DECISION_OD_EXIT` | Class | Return agent, overdue branch |
| 04_decision_exits | `ZCL_SWF_IFS_DECISION_EXIT` | Class | Return agent, WS99000007 |
| 05_reports | `ZSD_WF_RESTART` | Report | v2.0, tcode ZRESTART_WF |
| 05_reports | `ZWF_MAIL_PREVIEW` | Report | Renders a mail without sending |
| 06_log_report | `ZCL_WF_LOG_RPT_DATA` | Class | Log report data layer |
| 06_log_report | `ZCL_WF_LOG_RPT_UI` | Class | Log report ALV layer |
| 07_enhancements | `MV45AFZZ` | Enhancement | **rewritten**, see §5 |
| 08_fixes | Fix notes | Markdown | One file per fix |

### 3.2 NOT in this package — export these yourself

These were never shared in the session, so they could not be included. Put
them in the same folder structure before you hand the package on.

**Classes and interfaces**

- `ZCL_WF_LOG_EX`, `ZCL_WF_LOG_OD`, `ZCL_WF_LOG_CL` — log writers
  (`START`, `ADD_ITEM`, `SET_LEVEL`, `FINISH`, `FIND_OPEN`)
- `ZIF_WF_LOG_RPT` — report types and constants
- `ZCL_MAIL_SENDER`, `ZCL_MAIL_HTML` — the reusable mail layer
- `ZCX_WF_SD` — exception class
- `ZCL_FI_CUSTOMER_OPEN_ITEMS` — used by `GET_OVERDUE_DATA`

**Reports**

- `ZWF_LOG_SO` — SO log display (EX / OD / Both radio buttons)
- `ZWF_LOG_CL` — BP credit limit log display

**DDIC**

- Tables: `ZWF_LOG_EX_H`, `ZWF_LOG_EX_I`, `ZWF_LOG_OD_H`, `ZWF_LOG_OD_I`,
  `ZWF_LOG_CL_H`, `ZWF_LOG_CL_I`, `ZSD_WF_SO`, `ZWF_USERS`, `ZWF_USERS_PL`,
  `ZWF_USERS_DV`, `ZCR_WF_USERS`, `ZWF_RANGES`, `ZWF_TYPES`, `ZWF_CONTROL`
- Data elements: `ZWF_LOG_ID`, `ZWF_STATUS1`, `ZWF_ACTION`, `ZWF_NOTE`,
  `ZWF_TYPE`, `ZWF_DESC`, `ZRANGE_CODE`, `ZRANGE_FROM`, `ZRANGE_TO`,
  `ZRANGE_TYPE`, `ZSEQUENCE`, `ZUSER_DESC`
- Table types: `ZWF_USERS_TY`, `ZWF_USERS_WI_TY`
- Message class `ZSD_WF` (000–016 in use, **017 to be created**, see §5)

**Workflow repository**

- Standard tasks `TS99000039`, `TS99000040`, `TS99000042`, `TS99000046`,
  `TS99000048`, `TS99000052`, `TS99000054`
- Rules `99000004`, `99000005`
- Event linkage in SWE2 for WS99000010

**Transactions**

- `ZWF_TYPES`, `ZWF_RANGES`, `ZWF_USERS` — SM30 parameter transactions
- `ZRESTART_WF` — ZSD_WF_RESTART

---

## 4. Configuration

### 4.1 Approver determination

`ZWF_CONTROL` decides the granularity per workflow type and company code:

| Flag | Meaning | Table read |
|---|---|---|
| `X_COMP` | Company code only | `ZWF_USERS` |
| `X_PLANT` | Company code + plant | `ZWF_USERS_PL` |
| `X_DIV` | Company code + plant + division | `ZWF_USERS_DV` |

Exactly one flag per row (`ZSD_WF 001`). `ZCL_WF_SD_FINDER` reads
`ZWF_CONTROL` first and then the matching user table.

### 4.2 Ranges

`ZWF_RANGES` is keyed by `RANGE_CODE` and holds `RANGE_FROM` / `RANGE_TO`
plus `TYPE`:

- `TYPE = '%'` — percentage range
- `TYPE = <currency>` — absolute amount range

`GET_EXCEED_RANGES` tries the currency range first and falls back to
percentage. `GET_OVERDUE_RANGES` uses percentage only.

### 4.3 Workflow start date — `ZWF_SO_WF_START_DATE`

TVARVC parameter (`TYPE = 'P'`, `NUMB = '0000'`) holding a date in `YYYYMMDD`.
Orders created before that date do not start the workflow.

Maintained either in **STVARV** or with **ZSD_WF_RESTART**, checkbox
*Set start date* (`P_SDATE` + `P_WDATE`). Read by
`ZCL_WF_SD_CREDIT->GET_WF_START_DATE` and evaluated in `IS_START_ALLOWED`.

Create the record in QAS and PRD before go-live. Without it the check is
skipped and every historical order becomes eligible.

---

## 5. Changes in this package (19.10.2026)

All nine were applied to the source files here. Folder `08_fixes_2026-10-19`
holds the detail.

### The incident they fix

On 04.10.2026 at 19:55:16, logs **1612** (EX) and **1815** (OD) were created
by a new workflow run, and in the same second were closed with `KILL` by the
save that had just started them. The work items were never cancelled, so the
workflow kept running and wrote `MAIL` (19:55:17) and two `APPR` rows (05.10)
into logs that already read *Killed*. The lock row was deleted too, leaving
the order changeable during approval.

Cause: YSDA saves the order twice in the same transaction. On save 2 the
`ZSD_WF_SO` row inserted by save 1's workflow made `IS_ORDER_LOCKED` true,
`FIND_RUNNING` found nothing because the new work items did not exist yet,
and `CLOSE_OPEN_LOGS` plus the lock delete ran unconditionally.

### Applied

| # | Object | Change |
|---|---|---|
| A1 | `ZCL_WF_SD_CREDIT` | `KILL_RUNNING_WORKFLOW` gains `IV_FORCE TYPE ABAP_BOOL DEFAULT ABAP_FALSE` |
| A2 | `ZCL_WF_SD_CREDIT` | `LS_LOG_MSG` replaces `MESSAGE`, declared outside the loop and filled with `ZSD_WF 017` |
| A3 | `ZCL_WF_SD_CREDIT` | `IF LT_WI IS INITIAL AND IV_FORCE = ABAP_FALSE. RETURN. ENDIF.` before `CLOSE_OPEN_LOGS` |
| A4/A5 | `ZCL_WF_SD_CREDIT` | `CLOSE_OPEN_LOGS` excludes logs created at or after method entry |
| B1/B2 | `ZSD_WF_CREDIT_EXCEED_SO` | both `TESTMETHOD` calls commented out |
| B3 | `ZSD_WF_CREDIT_EXCEED_SO` | dead `COND` for `LV_MAIL_LOG` removed |
| C1 | `ZSD_WF_RESTART` | kill-only mode passes `IV_FORCE = ABAP_TRUE` |
| — | `MV45AFZZ` | `STATICS LT_DONE` re-entrancy guard, `BREAK SNAG_HASSAN` removed |

### Still to do by hand

- **Fix 03** — `ADD_ITEM` status guard in `ZCL_WF_LOG_EX` / `_OD` / `_CL`.
  See `08_fixes_2026-10-19/FIX_03_ADD_ITEM_STATUS_GUARD.md`.
- **Message `ZSD_WF 017`** — create it, text suggestion:
  `Sales order &1 changed by &2, approval cancelled`.
  Referenced by patch A2; the kill will short dump on a missing message only
  if the workflow log tries to render it, but create it regardless.
- **`TESTMETHOD`** — still present in `ZCL_WF_SD_CREDIT`. The calls are
  commented out; delete the method itself before PRD.

---

## 6. Deployment order

1. DDIC — domains, data elements, table types, tables, message class `ZSD_WF`
2. Exception class `ZCX_WF_SD`
3. Mail layer — `ZCL_MAIL_SENDER`, `ZCL_MAIL_HTML`
4. Log writers — `ZCL_WF_LOG_EX`, `ZCL_WF_LOG_OD`, `ZCL_WF_LOG_CL`
5. `ZCL_WF_SD_FINDER`, `ZCL_WF_SD_CREDIT`
6. `ZCL_WF_NOTE_READER`, `ZCL_WF_SD_ALERT`, `ZCL_WF_MAIL_CREDIT`
7. `ZSD_WF_CREDIT_EXCEED_SO`
8. Decision exit classes
9. `ZIF_WF_LOG_RPT`, `ZCL_WF_LOG_RPT_DATA`, `ZCL_WF_LOG_RPT_UI`, `ZWF_LOG_SO`
10. `ZSD_WF_RESTART`, `ZWF_MAIL_PREVIEW`
11. `MV45AFZZ` enhancement
12. Tasks, rules, workflow WS99000010, SWE2 linkage
13. Transactions, number ranges for the three log areas
14. TVARVC `ZWF_SO_WF_START_DATE`
15. Config data — `ZWF_TYPES`, `ZWF_RANGES`, `ZWF_CONTROL`, `ZWF_USERS*`

---

## 7. Operating notes

### After any method signature change

**Refresh the task container in PFTC.** Additional data → Object method →
Change → Yes. Without it the new parameter arrives **initial with no error**,
which is the single most common failure in this project. It has already cost
time on TS99000024, TS99000026 and the release and cancel tasks.

### Never call COMMIT WORK in a synchronous background workflow method

It closes the update task and the workflow loses its export parameters. This
was the cause of `LOG_ID` never reaching the container from `GET_APPROVERS`.

### HTML in SBWP

The work item description renders HTML through a multiline container
reference `&ELEMENT[]&`, element type `RSWEBPUB_T_W3HTML` (line type `W3HTML`,
255 characters). `ZCL_WF_SD_ALERT->BUILD_W3HTML` produces a **fragment** —
no `<html>` or `<body>` wrapper. `BUILD_HTML( IV_FULL_DOC = ABAP_TRUE )`
produces the full document for the e-mail.

### Repairing a log by hand

Logs 1612 / 1815 are still status `K` with a live workflow at level 3. To
repair: set `STATUS = 'I'` and `CURRENT_LEVEL = 3` on both headers, remove or
annotate the `KILL` row, and re-insert the `ZSD_WF_SO` row so the order is
locked again. Before doing so, check SWI1 for `TOP_TASK = 'WS99000010'` on
that order — the work item IDs in the log (`MAIL` 11241282 vs `APPR`
11238204) suggest two instances may be alive, and the older one must be
killed with ZSD_WF_RESTART in kill-only mode first.

---

## 8. ZSD_WF_RESTART — four modes

Transaction `ZRESTART_WF`. Exactly one mode per run; `P_TEST` defaults on.

| Selection field | Mode | What it does |
|---|---|---|
| none ticked | Restart | Writes header text TX01 via `BAPI_SALESORDER_CHANGE`, which re-triggers the credit check and starts a fresh approval from level 1 |
| `P_ULOCK` | Remove lock | Deletes the `ZSD_WF_SO` row only. Workflow and logs untouched, order becomes changeable |
| `P_KILL` | Kill work items | `KILL_RUNNING_WORKFLOW( IV_FORCE = ABAP_TRUE )`. No order change, no resubmit |
| `P_SDATE` | Set start date | Writes `P_WDATE` into TVARVC `ZWF_SO_WF_START_DATE`. No sales order needed |

Selection screen fields: `S_VBELN`, `P_TEXT`, `P_TEST`, `P_ULOCK`, `P_KILL`,
`P_SDATE`, `P_WDATE`. Block titles `TEXT-B01` … `TEXT-B04`.

---

## 9. Open items

- [ ] `Z_FM_SD_WF_CHECK_CREDIT` — event check function module for WS99000010,
      mirroring the `Z_FM_BCS_WF_CHECK_DOCTYPE` pattern. `IS_START_ALLOWED`
      is implemented in `ZCL_WF_SD_CREDIT` but nothing calls it yet. Wire it
      into SWE2. Exceptions: `NOT_RELEVANT` (consumed cleanly) and
      `DOCUMENT_NOT_READ` (error queue, restartable).
- [ ] `ZCX_WF_SD` — add constant `ORDER_NOT_FOUND`, message `ZSD_WF 016`.
      `IS_START_ALLOWED` already raises it.
- [ ] Message `ZSD_WF 017` for the kill log message.
- [ ] Fix 03 — `ADD_ITEM` status guard in the three log classes.
- [ ] Workflow bindings — `LOG_ID` / `LOG_ID_OD` missing on nodes 000227,
      000233, 000238, 000243. Node 000125 / 000187 missing `USERS`,
      `CURRENT_LEVEL`, `LOG_ID`, `LOG_AREA`, `WORK_ITEM_ID`. Stray `USERS`
      out-binding on node 000040 to be removed.
- [ ] The missing `RELS` row — the release step writes `ADD_ITEM` with
      action `RELS` but the row does not reach `ZWF_LOG_*_I`. Debugger showed
      the INSERT with valid data (log 53, seq 7). Fix 03 will make this
      visible rather than silent; re-test after applying it.
- [ ] Remove `TESTMETHOD` from `ZCL_WF_SD_CREDIT` before PRD.
- [ ] `GET_CREDIT_DATA` adds `NETWR` to the exposure returned by
      `UKM_COMMTS_READ`. Confirm with Nourhan that the open order is not
      already in the commitment, otherwise the exceed amount is double
      counted.
- [ ] `GET_ORDER_DATA` reads `WERKS` from `VBAP` with no `ORDER BY POSNR` —
      the plant returned is arbitrary when items differ.
