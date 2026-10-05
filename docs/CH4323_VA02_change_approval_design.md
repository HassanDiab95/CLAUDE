# CH4323 – Part 2: VA02 Change Detection, Delivery Block & Approval Workflow (Technical Design)

TSD reference: chapters 4 (VA02), 5 (Delivery Block), 6 (Approval Workflow), 8 (technical note).
Part 1 (filter table, VA01 locks) is described in `CH4323_filter_table_and_va01_lock.md`.

## 1. Understanding (please confirm, see also chapter 11)

1. An order created with reference to a contract (`VBAK-VGBEL` filled, `VBAK-VGTYP = 'G'`) is opened in **VA02**.
   The VA02 filter in `ZSD_SO_CON_FLT` (process `VA02` or `BOTH`) must match.
2. On save, the system checks whether any of the fields locked in VA01 changed, compared with the order as it was **before this VA02 session**:
   - Material
   - Quantity
   - Net value / net price
   - Characteristic values (VC)
   - Items added or deleted
3. If at least one changed:
   - The header **delivery block XX** is set.
   - **One** approval workflow starts after the save, however many fields changed.
4. The workflow reads the approvers from a new **approver table** (one or more levels, ordered by level) and loops over the levels:
   - It **e-mails** (Outlook) the approvers of the level that a work item is waiting in their **Fiori My Inbox**.
   - The approver **approves or rejects** the work item in My Inbox.
   - **Reject** at any level: the workflow ends and the delivery block **stays**.
   - **Approve**: the workflow moves to the next level. After the last level, the **delivery block is removed** and the order is released.
5. If the order is changed again (while pending or after approval or rejection):
   - The order is blocked again.
   - The older running workflow is cancelled.
   - A **new** workflow starts.
6. While an approval is pending, the user cannot remove the delivery block manually.

## 2. Process flow

```
 VA02 open order ──► USEREXIT_READ_DOCUMENT: snapshot (material, qty, net value/price, characteristics)
        │
 user changes, presses Save
        │
        ▼
 USEREXIT_SAVE_DOCUMENT_PREPARE
   relevant (ref. to contract + VA02 filter)? ── no ──► standard save
        │ yes
   changes vs snapshot? ── no ──► approval pending? ── yes ──► keep LIFSK = XX
        │ yes                                └─ no ──► standard save
   VBAK-LIFSK = XX, "approval required"
        │
        ▼
 USEREXIT_SAVE_DOCUMENT (same LUW)
   ZSD_SO_APPR_LOG: old pending -> C, new entry -> P
   raise event ZCL_SD_SO_CHG_WF.CHANGE_APPROVAL_REQUIRED (update task)
        │
 COMMIT WORK (order saved) ──► event ──► workflow ZSD_SO_CHG_APPR
        │
        ▼
 Workflow:
   1 cancel older running approval workflows of the order
   2 read approval levels  ── none ──► set_no_approver (block stays) ─► end
   3 LOOP level 1..n UNTIL rejected OR all levels done
       3a agents of the level
       3b e-mail to agents (Outlook: "work item in My Inbox")
       3c user decision Approve / Reject  (My Inbox)
       3d Reject  ─► set_rejected (block stays, mail requester) ─► end loop
          Approve ─► next level
   4 all approved ─► set_approved: BAPI_SALESORDER_CHANGE removes LIFSK, mail requester
```

## 3. Object list

| # | Object | Type | Purpose | Source |
|---|--------|------|---------|--------|
| 1 | ZE_SD_APPR_LEVEL / ZD_SD_APPR_LEVEL | Data element / domain | Approval level (NUMC 2) | – |
| 2 | ZE_SD_APPR_STATUS / ZD_SD_APPR_STATUS | Data element / domain | Status P/A/R/C/E (CHAR 1, fixed values) | – |
| 3 | ZE_SD_APPR_COUNTER / ZD_SD_APPR_COUNTER | Data element / domain | Request counter per order (NUMC 4) | – |
| 4 | ZE_SD_APPR_CHG_TEXT / ZD_SD_APPR_CHG_TEXT | Data element / domain | Change summary (CHAR 255) | – |
| 5 | ZSD_SO_APPR_CFG | Table (C) | Approvers per sales org / order type / level | `src/ddic/zsd_so_appr_cfg.tabl.ddl` |
| 6 | ZSD_SO_APPR_LOG | Table (A) | Approval requests, status, decision | `src/ddic/zsd_so_appr_log.tabl.ddl` |
| 7 | ZCL_SD_SO_CHG_MONITOR | Class | Snapshot, change detection, start approval | `src/class/zcl_sd_so_chg_monitor.clas.abap` |
| 8 | ZCL_SD_SO_CHG_WF | Class (IF_WORKFLOW) | Workflow object, event, background methods | `src/class/zcl_sd_so_chg_wf.clas.abap` |
| 9 | ZSD_SO_CHG_SNAPSHOT | Enhancement MV45AFZZ `USEREXIT_READ_DOCUMENT` (end) | Snapshot | `src/enhancement/mv45afzz_userexit_read_document.abap` |
| 10 | ZSD_SO_CHG_DETECT | Enhancement MV45AFZZ `USEREXIT_SAVE_DOCUMENT_PREPARE` (start) | Detect, set / keep block | `src/enhancement/mv45afzz_userexit_save_document_prepare.abap` |
| 11 | ZSD_SO_CHG_START_WF | Enhancement MV45AFZZ `USEREXIT_SAVE_DOCUMENT` (start) | Log + event | `src/enhancement/mv45afzz_userexit_save_document.abap` |
| 12 | ZSD_SO_CON_FIELD_LOCK | Existing enhancement `USEREXIT_FIELD_MODIFICATION` | + lock `VBAK-LIFSK` in VA02 while pending | `src/enhancement/mv45afzz_userexit_field_modification.abap` |
| 13 | TS9xxxxxx1..5 | Workflow tasks (background) | Call class methods | SWDD / PFTC |
| 14 | ZSD_SO_CHG_APPR (WS9xxxxxxx) | Workflow template | Approval loop | SWDD |
| 15 | ZSD_SO_APPR_INBOX_URL | TVARVC parameter | Fiori launchpad / My Inbox link in the e-mail | STVARV |
| 16 | XX | Delivery block (OVLS / TVLS) | Approval block (TSD: value to be confirmed) | Customizing |
| 17 | ZSD_SO_APPR | SM30 parameter transaction | Maintain approver table | SE93 |

## 4. DDIC

### 4.1 Domains / data elements

| Domain | Type | Len | Fixed values | Data element (labels) |
|--------|------|-----|--------------|-----------------------|
| ZD_SD_APPR_LEVEL | NUMC | 2 | – | ZE_SD_APPR_LEVEL (Level / Approval Level) |
| ZD_SD_APPR_STATUS | CHAR | 1 | P Pending, A Approved, R Rejected, C Cancelled (replaced by new change), E No approver | ZE_SD_APPR_STATUS (Status / Approval Status) |
| ZD_SD_APPR_COUNTER | NUMC | 4 | – | ZE_SD_APPR_COUNTER (Req. / Approval Request) |
| ZD_SD_APPR_CHG_TEXT | CHAR | 255 | – (lower case allowed) | ZE_SD_APPR_CHG_TEXT (Changes / Changed Fields) |

### 4.2 Approver table ZSD_SO_APPR_CFG (customizing, SM30)

| Field | Key | Data element | Meaning |
|-------|-----|--------------|---------|
| MANDT | X | MANDT | Client |
| VKORG | X | VKORG | Sales organization of the order |
| AUART | X | AUART | Sales order type |
| APPR_LVL | X | ZE_SD_APPR_LEVEL | Level / sequence: 01 first, 02 second, … |
| APPROVER | X | XUBNAME | SAP user of the approver |
| EMAIL | | AD_SMTPADR | Optional. If empty, the e-mail from the user master (SU01) is used |
| ACTIVE | | XFELD | Checkbox |

Example (two levels; level 1 has two approvers, and either one can decide):

| VKORG | AUART | APPR_LVL | APPROVER | ACTIVE |
|-------|-------|----------|----------|--------|
| 2000 | ZOP | 01 | SALESMGR1 | ☑ |
| 2000 | ZOP | 01 | SALESMGR2 | ☑ |
| 2000 | ZOP | 02 | FINMGR | ☑ |

Table maintenance generator: function group `ZSD_SO_APPR_CFG`, one-step, authorization group `ZSD`, transaction `ZSD_SO_APPR`.

### 4.3 Approval log ZSD_SO_APPR_LOG (application data)

| Field | Key | Data element | Meaning |
|-------|-----|--------------|---------|
| MANDT, VBELN, COUNTER | X | MANDT, VBELN_VA, ZE_SD_APPR_COUNTER | One entry per approval request (per VA02 save with changes) |
| STATUS | | ZE_SD_APPR_STATUS | P / A / R / C / E |
| CHG_USER, CHG_DATE, CHG_TIME | | ERNAM, ERDAT, ERZET | Who changed the order (requester), when |
| CHANGE_TEXT | | ZE_SD_APPR_CHG_TEXT | e.g. `Item 10: quantity 1 -> 2; Item 30: characteristic values changed` |
| APPR_LVL, DECIDED_BY, DECIDED_DATE, DECIDED_TIME | | ZE_SD_APPR_LEVEL, XUBNAME, DATUM, UZEIT | Final decision |

The log is used to:
- check "approval pending" (delivery block protection)
- show the change text in the work item and the e-mail
- give an audit trail (SE16N / a simple ALV report, optional)

## 5. Change detection (VA02)

| Exit | When | Logic |
|------|------|-------|
| `USEREXIT_READ_DOCUMENT` (end) | Order read in VA02 (`T180-TRTYP = 'V'`), relevant for process VA02 | `TAKE_SNAPSHOT`: per item MATNR, KWMENG, NETWR, NETPR and the characteristic values (`VC_I_GET_CONFIGURATION`, sorted `ATNAM=ATWRT;`) |
| `USEREXIT_SAVE_DOCUMENT_PREPARE` (start) | Save | `DETECT_CHANGES`: `XVBAP-UPDKZ = 'I'` → added, `'D'` → deleted, otherwise compare with the snapshot. Result = list of change texts. |

- **Changes found** → `VBAK-LIFSK = 'XX'` and `SET_APPROVAL_REQUIRED`. The user gets no error message and the save always goes through.
- **No changes, but an approval is still pending** → `VBAK-LIFSK = 'XX'` again (protection, TSD 5).
- **Only other fields changed** (texts, partners, dates, …) → no approval.
- **Several monitored fields changed in one save** → one approval request and one workflow (TSD 4.4 / 6).
- The **same logic runs for every channel that uses SAPMV45A in change mode**: VA02, BAPI_SALESORDER_CHANGE, IDoc, mass change.
  The workflow's own BAPI call (release) changes only the header delivery block, so it does not trigger a new approval.

## 6. Delivery block

| Point | Rule | Where |
|-------|------|-------|
| Set | Monitored change on save | `USEREXIT_SAVE_DOCUMENT_PREPARE` |
| Protect (screen) | `VBAK-LIFSK` display-only in VA02 while status P | `USEREXIT_FIELD_MODIFICATION` |
| Protect (save) | Reset to XX if removed while status P (e.g. BAPI / mass change) | `USEREXIT_SAVE_DOCUMENT_PREPARE` |
| Release | All levels approved → `BAPI_SALESORDER_CHANGE` (`ORDER_HEADER_IN-DLV_BLOCK = space`) | `ZCL_SD_SO_CHG_WF->SET_APPROVED` |
| Reject | Block stays | `ZCL_SD_SO_CHG_WF->SET_REJECTED` |

Customizing: delivery block `XX` (SPRO → Logistics Execution → Shipping → Deliveries → Define Reasons for Blocking in Shipping, plus assignment to the delivery types).

## 7. Workflow trigger

- Object: class **ZCL_SD_SO_CHG_WF** (interface IF_WORKFLOW, key = VBELN), event **CHANGE_APPROVAL_REQUIRED**.
- Raised in `USEREXIT_SAVE_DOCUMENT` with `CL_SWF_EVT_EVENT=>RAISE_IN_UPDATE_TASK`. The event is only created if the order update is successful, as TSD ch. 8 requires.
- Event linkage: workflow template ZSD_SO_CHG_APPR → *Basic data → Start events*: category CL, object `ZCL_SD_SO_CHG_WF`, event `CHANGE_APPROVAL_REQUIRED`, binding `_EVT_OBJECT → ORDER`. Activate the linkage (SWE2 shows it).

## 8. Workflow template ZSD_SO_CHG_APPR

### 8.1 Container

| Element | Type | Import | Purpose |
|---------|------|--------|---------|
| ORDER | Class ZCL_SD_SO_CHG_WF | X (from event) | The sales order |
| LEVELS | ZCL_SD_SO_CHG_WF=>TT_LEVEL (multiline) | | Approval levels |
| LEVEL_COUNT | INT4 | | Number of levels |
| LEVEL_INDEX | INT4 (initial 1) | | Loop counter |
| LEVEL | ZE_SD_APPR_LEVEL | | Current level |
| AGENTS | TSWHACTOR (multiline) | | Approvers of the current level |
| REJECTED | XFELD | | X = rejected |
| DECIDED_BY | XUBNAME | | Actual agent of the decision |

### 8.2 Tasks (PFTC, object category CL, all background except the decision)

| Task | Method | Container binding |
|------|--------|-------------------|
| TS…1 Cancel previous | CANCEL_PREVIOUS_WORKFLOWS | – |
| TS…2 Get levels | GET_LEVELS | → LEVELS, LEVEL_COUNT |
| TS…3 Get level agents | GET_LEVEL_AGENTS | LEVELS, LEVEL_INDEX → LEVEL, AGENTS |
| TS…4 Send e-mail | SEND_APPROVAL_EMAIL | LEVEL, AGENTS |
| TS…5 Approved | SET_APPROVED | DECIDED_BY, LEVEL. Exception CX_BO_TEMPORARY = temporary error with retry (e.g. order locked in VA02) |
| TS…6 Rejected | SET_REJECTED | DECIDED_BY, LEVEL |
| TS…7 No approver | SET_NO_APPROVER | – |

### 8.3 Steps

```
1  Activity      TS…1 Cancel previous workflows
2  Activity      TS…2 Get levels
3  Condition     LEVEL_COUNT = 0
     true  ──► Activity TS…7 No approver ──► Process control: complete workflow
4  Loop (UNTIL)  REJECTED = 'X'  OR  LEVEL_INDEX > LEVEL_COUNT
   4.1 Activity       TS…3 Get level agents
   4.2 Activity       TS…4 Send e-mail
   4.3 User decision  "Sales order &ORDER.VBELN& changed – approve?"
                      Text: &ORDER.CHANGE_TEXT&, requested by &ORDER.REQUESTER&
                      Outcomes: Approve / Reject (reject: comment mandatory, optional)
                      Agents: expression &AGENTS&
                      Binding back: _WI_ACTUAL_AGENT → DECIDED_BY
       Approve ─► Container operation LEVEL_INDEX = LEVEL_INDEX + 1
       Reject  ─► Activity TS…6 Rejected
                  Container operation REJECTED = 'X'
5  Condition     REJECTED = ' '
     true  ──► Activity TS…5 Approved (remove delivery block)
```

- **Levels run in sequence.** Level 2 only receives the work item after level 1 approved.
- **Several approvers on one level:** all of them get the work item. The first decision completes it (standard workflow behaviour).
- **Another change while pending:** the new workflow first cancels the old one (step 1), and the old log entry is already set to C at save.
  So an old approval can never release a newer change.
- **Deadline (optional):** step 4.3 → *Latest end* (e.g. 2 days) → reminder e-mail or escalation. This is open: does the business want it?

### 8.4 Fiori My Inbox

- The user decision step creates a standard decision task, so My Inbox shows Approve / Reject buttons without a custom app.
- Prerequisites (Basis / Fiori team):
  - OData service `/IWPGW/TASKPROCESSING` (version 2) is active.
  - Approvers have the My Inbox tile / catalog.
  - The task is not excluded by a My Inbox scenario filter.
- Agent assignment of the decision task: *General task* (agents come from the binding `AGENTS`).

## 9. E-mail (Outlook)

- Sent by `SEND_APPROVAL_EMAIL` for each level, to each approver of that level, through BCS (CL_BCS, HTML).
- Content:
  - Order number and the user who changed it
  - Level
  - Change summary
  - "work item in your Fiori inbox", with a link from TVARVC `ZSD_SO_APPR_INBOX_URL` (e.g. `https://<flp-host>/sap/bc/ui2/flp#WorkflowTask-displayInbox`)
- The requester gets a mail on approval, rejection, or when no approver is maintained (`NOTIFY_REQUESTER`).
- Prerequisites:
  - SAPconnect (SCOT) is configured for SMTP, and job `RSCONN01` is scheduled (or immediate sending is allowed).
  - Approvers have an e-mail address in SU01 or in `ZSD_SO_APPR_CFG-EMAIL`.
  - Monitor in SOST.

## 10. Test scenarios

| # | Scenario | Expected |
|---|----------|----------|
| 1 | VA02, relevant order, change a text only | No block, no workflow |
| 2 | VA02, change quantity of item 10 | Block XX, log P, one workflow, e-mail to level 1, work item in My Inbox |
| 3 | Change quantity and material in one save | One log entry, one workflow, change text lists both |
| 4 | Change a characteristic value | Block, workflow, text "characteristic values changed" |
| 5 | Add or delete an item | Block, workflow |
| 6 | Level 1 approves, two levels maintained | Work item and e-mail to level 2, block stays |
| 7 | All levels approve | Block removed, log A, mail to requester |
| 8 | Level 2 rejects | Block stays, log R, mail to requester, no further level |
| 9 | While pending: try to remove block in VA02 | Field display-only; via BAPI the block is set again |
| 10 | While pending: change quantity again | Old workflow cancelled, old log C, new log P, new workflow |
| 11 | After approval: change again | New block, new workflow |
| 12 | No approver for VKORG/AUART | Block stays, log E, mail to requester |
| 13 | Order open in VA02 when the last approver approves | SET_APPROVED temporary error, retried until the order is released |
| 14 | Order not matching the VA02 filter / without contract reference | No block, no workflow |

## 11. Assumptions – please confirm or correct

1. **Baseline** = the order as saved before this VA02 session, not the contract values.
2. **Items added or deleted in VA02** count as a change that needs approval (VA02 has no Insert/Delete lock).
3. **Approver determination** = sales organization + sales order type. Other keys could be used instead: distribution channel, division, or contract type.
4. **Several approvers on the same level** = any one of them decides. Is it instead "all of them must approve"?
5. **Rejection** = the workflow ends, the block stays, and the requester is informed. The order can then be corrected in VA02, which starts a new workflow.
   No "send back for rework" loop inside the same workflow.
6. **Net value** changes caused by automatic repricing (e.g. a new pricing date) also count as a change.
7. **No approver maintained** = the block stays and the requester is informed. The alternative would be an automatic release.
8. **Delivery block value** `XX`, and whether a reminder or escalation deadline is required.
