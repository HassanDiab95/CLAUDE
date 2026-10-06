# CH4323 – Part 2: VA02 Change Detection, Delivery Block & Approval Workflow (Technical Design)

TSD reference: chapters 4 (VA02), 5 (Delivery Block), 6 (Approval Workflow), 8 (technical note).
Part 1 (filter table, VA01 locks) is described in `CH4323_filter_table_and_va01_lock.md`.
The log, e-mail and report follow the delivery credit approval workflow pattern (WS99000003: ZCL_SD_DLV_CR_LOG / _NOTIFY, ZSD_DLV_CR_WF_LOG).

## 1. Process

1. An order created with reference to a contract (`VBAK-VGBEL` filled, `VGTYP = 'G'`) that matches the VA02 filter (process `VA02` or `BOTH`) is changed in **VA02**.
2. On save, the order is compared with the order as it was when VA02 opened. Monitored:
   - material, quantity, net value, net price
   - characteristic values
   - items added or deleted
3. If at least one changed:
   - The header **delivery block XX** is set.
   - A **workflow log run** is created (status *In process*).
   - **One** workflow starts after the save.
4. The workflow loops over the approval levels of the approver table (level 1, 2, 3 …, one approver per level). For each level:
   - The approver gets an **Outlook e-mail** that a work item waits in **Fiori My Inbox**.
   - The approver **approves or rejects** in My Inbox.
   - **Reject** → the run ends, the order **stays blocked**, and the requester is informed.
   - **Approve** → the next level. After the last level, the **delivery block is removed** and the requester is informed.
5. **While the order is in the approval cycle, it is closed for change.** VA02 opens it display-only:
   - all fields, including the delivery block
   - Insert/Delete item
   - the configuration
   - A message tells the user the order is in the approval workflow.
6. After approval or rejection the order can be changed again. A new monitored change starts a new run and a new workflow.
7. **Safety net:** a change that does not come through the VA02 screens (BAPI, IDoc, mass change) while a run is in process still creates a new run.
   The old run is closed as *Replaced*, and **its workflow is cancelled (killed)** with `SWW_WI_ADMIN_CANCEL`.
   An old approval can never release a newer change.

## 2. Flow

```
VA02 open ── USEREXIT_READ_DOCUMENT ── snapshot; run in process? -> message "display only"
   │                                     USEREXIT_FIELD_MODIFICATION closes all fields,
   │                                     CUA_SETZEN removes Insert/Delete, CE_C_PROCESSING display
   ▼
Save ── USEREXIT_SAVE_DOCUMENT_PREPARE
          changes vs snapshot? ── yes ─► VBAK-LIFSK = XX, approval required
                                 └ no ──► run in process? -> keep LIFSK = XX
   ▼
        USEREXIT_SAVE_DOCUMENT (same LUW)
          ZCL_SD_SO_CHG_LOG=>CREATE_LOG  (LH status P, one LL row per level)
          ADD_EVENT CHANGE  (one per changed field)
          CLOSE_PREVIOUS    (older run -> F Replaced, old workflow cancelled)
          raise ZCL_SD_SO_CHG_WF.CHANGE_APPROVAL_REQUIRED (LOG_ID) in update task
   ▼
COMMIT ─► workflow ZSD_SO_CHG_APPR
   START (WF id, START event; no level -> status E, mail requester, end)
   LOOP index 1..levels UNTIL rejected
      PREPARE_LEVEL (level D, LEVEL event, e-mail, INBOX event, agent)
      User decision Approve / Reject (My Inbox)
      DECIDE (level A/R, APPROVE/REJECT event)
   rejected ─► FINISH_REJECTED (CLOSE event, status R, mail requester)
   approved ─► FINISH_APPROVED (status A, BAPI removes LIFSK, RELEASE event, mail requester)
```

## 3. Object list

| # | Object | Type | Purpose | Source |
|---|--------|------|---------|--------|
| 1 | ZSD_SO_LEVEL | Domain + data element | Approval level, NUMC 2 | – |
| 2 | ZSD_SO_WF_STATUS | Domain + data element | Run / level status, CHAR 1 | – |
| 3 | ZSD_SO_WF_EVENT | Domain + data element | Log event, CHAR 10 | – |
| 4 | ZSD_SO_SEQNR | Domain + data element | Event number, NUMC 4 | – |
| 5 | ZSD_SO_CHG_TEXT | Domain + data element | Text, CHAR 255, lower case | – |
| 6 | ZSD_SO_APPR_CFG | Table (C) | Approver per sales org / order type / level | `src/ddic/zsd_so_appr_cfg.tabl.ddl` |
| 7 | ZSD_SO_CHG_LH | Table (A) | Log header (one row per run) | `src/ddic/zsd_so_chg_lh.tabl.ddl` |
| 8 | ZSD_SO_CHG_LL | Table (A) | Log levels | `src/ddic/zsd_so_chg_ll.tabl.ddl` |
| 9 | ZSD_SO_CHG_LE | Table (A) | Log events (timeline) | `src/ddic/zsd_so_chg_le.tabl.ddl` |
| 10 | ZCL_SD_SO_CHG_LOG | Class | Log, approver determination, close previous run and kill its workflow, icons and texts | `src/class/zcl_sd_so_chg_log.clas.abap` |
| 11 | ZCL_SD_SO_CHG_NOTIFY | Class | HTML e-mails to the approver and the requester | `src/class/zcl_sd_so_chg_notify.clas.abap` |
| 12 | ZCL_SD_SO_CHG_MONITOR | Class | Snapshot, change detection, start run + event, "in approval" check | `src/class/zcl_sd_so_chg_monitor.clas.abap` |
| 13 | ZCL_SD_SO_CHG_WF | Class (IF_WORKFLOW) | Workflow object, event, step methods | `src/class/zcl_sd_so_chg_wf.clas.abap` |
| 14 | ZSD_SO_CHG_WF_LOG / ZSD_SOCHG_LOG | Report / transaction | Log monitor | `src/report/zsd_so_chg_wf_log.prog.abap` |
| 15 | MV45AFZZ `USEREXIT_READ_DOCUMENT` (end) | Enhancement ZSD_SO_CHG_SNAPSHOT | Snapshot, "display only" message | `src/enhancement/mv45afzz_userexit_read_document.abap` |
| 16 | MV45AFZZ `USEREXIT_SAVE_DOCUMENT_PREPARE` (start) | Enhancement ZSD_SO_CHG_DETECT | Detect changes, set / keep block | `src/enhancement/mv45afzz_userexit_save_document_prepare.abap` |
| 17 | MV45AFZZ `USEREXIT_SAVE_DOCUMENT` (start) | Enhancement ZSD_SO_CHG_START_WF | Log run + workflow event | `src/enhancement/mv45afzz_userexit_save_document.abap` |
| 18 | MV45AFZZ `USEREXIT_FIELD_MODIFICATION` | Existing ZSD_SO_CON_FIELD_LOCK | + VA02 in approval: all fields closed | `src/enhancement/mv45afzz_userexit_field_modification.abap` |
| 19 | FORM `CUA_SETZEN` | Existing ZSD_SO_CON_ITEM_FCODES | + VA02 in approval: Insert/Delete item off | `src/enhancement/mv45af0c_cua_setzen.abap` |
| 20 | FM `CE_C_PROCESSING` | Existing ZSD_SO_CON_CONFIG_DISPLAY | + VA02 in approval: configuration display | `src/enhancement/ce_c_processing_display.abap` |
| 21 | ZSD_SO_CHG_APPR (WS9xxxxxxx) | Workflow template | Approval loop | SWDD |
| 22 | ZSD_SO_FLP_BASE | TVARVC parameter | Fiori launchpad base URL for the My Inbox link | STVARV |
| 23 | XX | Delivery block | Approval block (TSD: value to be confirmed) | Customizing |
| 24 | ZSD_SO_APPR | SM30 parameter transaction | Maintain approver table | SE93 |

## 4. DDIC

### 4.1 Domains / data elements

| Domain = data element | Type | Len | Fixed values | Label |
|-----------------------|------|-----|--------------|-------|
| ZSD_SO_LEVEL | NUMC | 2 | – | Level / Approval Level |
| ZSD_SO_WF_STATUS | CHAR | 1 | P In process (run), D Pending decision (level), W Waiting (level), N Not reached (level), A Approved, R Rejected, X Cancelled (run), E Error (run), F Replaced (run). Each value has one meaning. | Status |
| ZSD_SO_WF_EVENT | CHAR | 10 | CHANGE, START, LEVEL, MAIL, MAIL_ERR, INBOX, APPROVE, REJECT, RELEASE, REL_ERR, CLOSE, INFO, ERROR, REPLACED | Event |
| ZSD_SO_SEQNR | NUMC | 4 | – | No. |
| ZSD_SO_CHG_TEXT | CHAR | 255 | – (lower case) | Text |

### 4.2 Approver table ZSD_SO_APPR_CFG (changed: one approver per level)

| Field | Key | Data element | Meaning |
|-------|-----|--------------|---------|
| MANDT | X | MANDT | |
| VKORG | X | VKORG | Sales organization |
| AUART | X | AUART | Sales order type |
| APPR_LEVEL | X | ZSD_SO_LEVEL | Sequence: 01 first approver, 02 second … |
| UNAME | | XUBNAME | Approver (SAP user, receives the My Inbox work item) |
| EMAIL | | AD_SMTPADR | Optional. If empty, the e-mail from SU01 is used |
| ACTIVE | | XFELD | Checkbox |

Example: `2000 / ZOP / 01 / SALESMGR`, `2000 / ZOP / 02 / FINMGR`. These are two levels, run in sequence.

### 4.3 Log tables (application data, like ZSD_DLV_CR_LH/LL/LE)

| Table | Key | Main fields |
|-------|-----|-------------|
| ZSD_SO_CHG_LH (header, one per run) | LOG_ID (UUID) | VBELN, CONTRACT, AUART, VKORG, VTWEG, SPART, KUNNR, CUST_NAME, NETWR/WAERK, CHANGE_TEXT, STATUS, CURR_LEVEL, LEVELS, WF_ID, REPLACED_BY, TRIGGER_EVT/BY/ON/AT, CREATED_*, CHANGED_*, FINISHED_* |
| ZSD_SO_CHG_LL (levels) | LOG_ID, APPR_LEVEL | UNAME, FULL_NAME, EMAIL, EMAIL_SRC (T table / U user master), STATUS, STARTED_*, DECIDED_*, DECIDED_BY |
| ZSD_SO_CHG_LE (events) | LOG_ID, SEQNR | EVENT, APPR_LEVEL, UNAME, TEXT, CREATED_ON/AT/BY |

Recommended secondary index on ZSD_SO_CHG_LH: `VBELN, STATUS`. It is used on every VA02 screen, by the "in approval" check.

The approvers are copied into ZSD_SO_CHG_LL when the run starts. A later change in ZSD_SO_APPR_CFG does not affect a running workflow.

## 5. Change detection and delivery block (VA02)

| Exit | Logic |
|------|-------|
| `USEREXIT_READ_DOCUMENT` | `TAKE_SNAPSHOT`: per item MATNR, KWMENG, NETWR, NETPR and the characteristic values. If a run is in process, show the message "Order … is in the approval workflow - display only". |
| `USEREXIT_SAVE_DOCUMENT_PREPARE` | `DETECT_CHANGES`: added (`UPDKZ = I`), deleted (`D`), or values different from the snapshot. Changes → `VBAK-LIFSK = XX`. No changes but a run in process → `LIFSK = XX` again. No error message. |
| `USEREXIT_SAVE_DOCUMENT` | `START_APPROVAL`: CREATE_LOG, CHANGE events, CLOSE_PREVIOUS (kill old workflow), event with LOG_ID in the update task. |

**Release** (all levels approved): `FINISH_APPROVED` → `BAPI_SALESORDER_CHANGE` with `DLV_BLOCK = space`.
The run is closed (status A) first, so the BAPI's own save neither sees a running approval nor a monitored change.
If the order is locked, the BAPI is rolled back, a `REL_ERR` event is logged, and `CX_BO_TEMPORARY` is raised. The workflow retries the step.

## 6. Order closed for change while in approval

"In approval" = a run of the order in ZSD_SO_CHG_LH with status **P** (`ZCL_SD_SO_CHG_MONITOR=>IS_APPROVAL_PENDING`, buffered per order).

| Where | Effect in VA02 |
|-------|----------------|
| `USEREXIT_FIELD_MODIFICATION` | Every input field → `SCREEN-INPUT = 0`: header, items, schedule lines, partners, texts screens of SAPMV45A, and the delivery block |
| `CUA_SETZEN` | Insert Row (POAN) / Delete Item (POLO) removed |
| FM `CE_C_PROCESSING` | Characteristic values display-only |
| `USEREXIT_READ_DOCUMENT` | Status message "display only" |
| `USEREXIT_SAVE_DOCUMENT_PREPARE` | Delivery block kept, even for a save without changes |

Changes that do not come through the VA02 screens (BAPI, IDoc, mass change) are not locked.
For those, the safety net in section 1 point 7 applies: new run, old run replaced, old workflow killed.

## 7. Workflow template ZSD_SO_CHG_APPR

### 7.1 Start event
Category CL, object `ZCL_SD_SO_CHG_WF`, event `CHANGE_APPROVAL_REQUIRED`. Bindings: `_EVT_OBJECT → ORDER`, `LOG_ID → LOG_ID`.

### 7.2 Container

| Element | Type | Import |
|---------|------|--------|
| ORDER | ZCL_SD_SO_CHG_WF | X |
| LOG_ID | SYSUUID_C32 | X |
| LEVELS | INT4 | |
| LEVEL_INDEX | INT4, initial value 1 | |
| LEVEL | ZSD_SO_LEVEL | |
| AGENTS | TSWHACTOR | |
| REJECTED | XFELD | |
| DECIDED_BY | XUBNAME | |

### 7.3 Steps

```
1  Activity  START          LOG_ID, WF_ID = &_WORKITEM.WORKITEMID&  -> LEVELS
2  Condition LEVELS = 0  -> end (run already closed with status E)
3  Loop UNTIL  REJECTED = 'X'  OR  LEVEL_INDEX > LEVELS
   3.1 Activity      PREPARE_LEVEL  LOG_ID, LEVEL_INDEX -> LEVEL, AGENTS
   3.2 User decision "Change of sales order &ORDER.VBELN& – approve?"   agents: &AGENTS&
                     outcomes Approve / Reject;  _WI_ACTUAL_AGENT -> DECIDED_BY
       Approve: Activity DECIDE (approved = X);  LEVEL_INDEX = LEVEL_INDEX + 1
       Reject : Activity DECIDE (approved = ' '); REJECTED = 'X'
4  Condition REJECTED = 'X'
     true : Activity FINISH_REJECTED
     false: Activity FINISH_APPROVED   (CX_BO_TEMPORARY = temporary error, retry)
```

- If `&_WORKITEM.WORKITEMID&` is not available in your release, leave `IV_WF_ID` empty. `START` then finds the running workflow of the order itself.
- My Inbox: the user decision task shows Approve / Reject. OData service `/IWPGW/TASKPROCESSING` must be active, and approvers need the My Inbox tile.

## 8. Log report ZSD_SO_CHG_WF_LOG (transaction ZSD_SOCHG_LOG)

- **Selection:** sales org (mandatory), order, customer, order type, distribution channel, division, start date, status, changed by.
- **One line per run**, newest first:
  - status icon and text
  - order (hotspot → VA03) and contract (hotspot → VA43)
  - customer and sales area
  - changes
  - Level 1–4 icons, current level, number of levels, "waiting for" (name of the current approver)
  - net value
  - started / finished
  - changed by / on / at
  - workflow (hotspot → workflow log)
- **Double-click** a line → popup with the **timeline** of the run (`ZSD_SO_CHG_LE`): change events, start, e-mails, decisions, release, replaced …
- **Text symbols:** maintain them in the report and the classes (B01, M01–M02, T01–T02, H01–H26, E01–E09; classes 001–066). The texts are in the code as `'…'(nnn)`; use *Goto → Text elements → Compare* to create them.

## 9. Test scenarios

| # | Scenario | Expected |
|---|----------|----------|
| 1 | VA02, change a text only | No block, no run |
| 2 | VA02, change quantity | Block XX, run P, one CHANGE event, e-mail to level 1, work item in My Inbox |
| 3 | Change quantity and material in one save | One run, two CHANGE events, one workflow |
| 4 | Change a characteristic value / add or delete an item | Block, run, workflow |
| 5 | Open the order in VA02 while run P | Message "display only"; all fields, Insert/Delete and configuration closed |
| 6 | Level 1 approves (two levels) | Level 1 A, level 2 D, e-mail to level 2 |
| 7 | All levels approve | Block removed, run A, RELEASE event, requester mail; VA02 open again |
| 8 | Level 2 rejects | Run R, level 3 N, block stays, requester mail; VA02 open again |
| 9 | After approval or rejection, change again | New run, new workflow |
| 10 | While run P: change via BAPI_SALESORDER_CHANGE (quantity) | New run, old run F (Replaced), old workflow cancelled, old work item gone from My Inbox |
| 11 | Order open in VA02 when the last approver approves | REL_ERR event, step retried until the release succeeds |
| 12 | No approver maintained | Run E, ERROR event, block stays, requester mail |
| 13 | Report: selection, icons, hotspots, double-click timeline | As described in chapter 8 |

## 10. Open points

1. Which exact changes are wanted in the approver table (this design assumes **one approver per level**).
2. Approver key: sales org + order type, or also channel, division or contract type?
3. Delivery block code `XX`.
4. Whether to add a reminder or escalation deadline on the decision step.
5. Whether a net value change caused by automatic repricing counts as a change.
