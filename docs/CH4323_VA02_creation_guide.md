# CH4323 – Part 2: VA02 Change Approval – Step-by-Step Creation Guide

All objects of the VA02 change detection, delivery block, approval workflow, log and log report, with every setting and the complete code.
Create the objects **in the order of this guide**: each step uses objects from the steps before it.

Prerequisite: Part 1 is active, in particular:
- the filter table ZSD_SO_CON_FLT, with process `VA02` or `BOTH` lines for the orders in scope
- the class ZCL_SD_SO_CONTRACT_CTRL
- the enhancements ZSD_SO_CON_FIELD_LOCK, ZSD_SO_CON_ITEM_FCODES and ZSD_SO_CON_CONFIG_DISPLAY

Package: `ZSD` (or the project package). Workbench request for all objects; customizing request for SM30 entries and the delivery block.

## 0. Overview – creation order

| Step | Object | Type | Tool |
|------|--------|------|------|
| 1 | ZSD_SO_LEVEL, ZSD_SO_WF_STATUS, ZSD_SO_WF_EVENT, ZSD_SO_SEQNR, ZSD_SO_CHG_TEXT | Domains (5) | SE11 |
| 2 | ZSD_SO_LEVEL, ZSD_SO_WF_STATUS, ZSD_SO_WF_EVENT, ZSD_SO_SEQNR, ZSD_SO_CHG_TEXT | Data elements (5) | SE11 |
| 3 | ZSD_SO_APPR_CFG | Approver table (customizing) | SE11 |
| 4 | ZSD_SO_APPR_CFG | Table maintenance + transaction ZSD_SO_APPR | SE11 / SE93 |
| 5 | ZSD_SO_CHG_LH | Log header table + index | SE11 |
| 6 | ZSD_SO_CHG_LL | Log level table | SE11 |
| 7 | ZSD_SO_CHG_LE | Log event table | SE11 |
| 8 | ZCL_SD_SO_CHG_MONITOR, ZCL_SD_SO_CHG_LOG, ZCL_SD_SO_CHG_NOTIFY, ZCL_SD_SO_CHG_WF | Classes – create all four empty first, then paste the code | SE24 / ADT |
| 9 | ZCL_SD_SO_CHG_LOG | Log class (+ text symbols) | SE24 / ADT |
| 10 | ZCL_SD_SO_CHG_NOTIFY | E-mail class (+ text symbols) | SE24 / ADT |
| 11 | ZCL_SD_SO_CHG_MONITOR | Change detection class | SE24 / ADT |
| 12 | ZCL_SD_SO_CHG_WF | Workflow class (IF_WORKFLOW) | SE24 / ADT |
| 13 | ZSD_SO_CHG_SNAPSHOT | Enhancement USEREXIT_READ_DOCUMENT | SE38 |
| 14 | ZSD_SO_CHG_DETECT | Enhancement USEREXIT_SAVE_DOCUMENT_PREPARE | SE38 |
| 15 | ZSD_SO_CHG_START_WF | Enhancement USEREXIT_SAVE_DOCUMENT | SE38 |
| 16 | ZSD_SO_CON_FIELD_LOCK / _ITEM_FCODES / _CONFIG_DISPLAY | Update of the Part 1 enhancements (VA02 lock) | SE38 / SE37 |
| 17 | TS9xxxxxx1 … TS9xxxxxx6 | Workflow tasks | PFTC |
| 18 | ZSD_SO_CHG_APPR (WS9xxxxxxx) | Workflow template + start event | SWDD |
| 19 | ZSD_SO_CHG_WF_LOG / ZSD_SOCHG_LOG | Log report + transaction (+ texts) | SE38 / SE93 |
| 20 | XX, SCOT, My Inbox, SWU3 | Customizing / configuration | SPRO / SCOT / … |
| 21 | – | Maintain approvers, test | ZSD_SO_APPR / VA02 |

The classes reference each other (LOG ↔ MONITOR ↔ NOTIFY ↔ WF). Create all four classes empty first (step 8), then paste the code and activate them together (SE80 → *Activate* with all four selected, or ADT mass activation).

---

## 1. Domains (SE11 → Domain)

For every domain: Definition tab → data type and length. Leave **Conversion routine** empty. Tick **Lower case** only where stated.

| Domain | Short description | Data type | Length | Lower case | Value range |
|--------|-------------------|-----------|--------|------------|-------------|
| ZSD_SO_LEVEL | SO change approval: level | NUMC | 2 | – | – |
| ZSD_SO_WF_STATUS | SO change approval: status | CHAR | 1 | – | Fixed values, see 1.1 |
| ZSD_SO_WF_EVENT | SO change approval: log event | CHAR | 10 | – | Fixed values, see 1.2 |
| ZSD_SO_SEQNR | SO change approval: event number | NUMC | 4 | – | – |
| ZSD_SO_CHG_TEXT | SO change approval: text | CHAR | 255 | X | – |

### 1.1 Fixed values of ZSD_SO_WF_STATUS

Each value has one meaning. Run = log header ZSD_SO_CHG_LH-STATUS, Level = ZSD_SO_CHG_LL-STATUS.

| Fixed value | Short description | Used for | Constant |
|-------------|-------------------|----------|----------|
| P | In process | Run | GC_STATUS-IN_PROCESS |
| A | Approved | Run and level | GC_STATUS-APPROVED / GC_LEVEL-APPROVED |
| R | Rejected | Run and level | GC_STATUS-REJECTED / GC_LEVEL-REJECTED |
| X | Cancelled | Run | GC_STATUS-CANCELLED |
| E | Error | Run | GC_STATUS-ERROR |
| F | Replaced by new change | Run | GC_STATUS-REPLACED |
| W | Waiting | Level | GC_LEVEL-WAITING |
| D | Pending decision | Level | GC_LEVEL-PENDING |
| N | Not reached | Level | GC_LEVEL-NOT_REACHED |

### 1.2 Fixed values of ZSD_SO_WF_EVENT

| Fixed value | Short description |
|-------------|-------------------|
| CHANGE | Order changed |
| START | Workflow started |
| LEVEL | Level in process |
| MAIL | E-mail sent |
| MAIL_ERR | E-mail not sent |
| INBOX | Sent to My Inbox |
| APPROVE | Approved |
| REJECT | Rejected |
| RELEASE | Delivery block released |
| REL_ERR | Release failed |
| CLOSE | Closed - stays blocked |
| INFO | Information |
| ERROR | Error |
| REPLACED | Replaced by order change |

Activate all domains.

## 2. Data elements (SE11 → Data type → Data element)

Each data element has the same name as its domain.

| Data element | Domain | Short (10) | Medium (20) | Long (40) | Heading |
|--------------|--------|------------|-------------|-----------|---------|
| ZSD_SO_LEVEL | ZSD_SO_LEVEL | Level | Approval Level | Approval Level | Lvl |
| ZSD_SO_WF_STATUS | ZSD_SO_WF_STATUS | Status | Approval Status | Approval Status | Status |
| ZSD_SO_WF_EVENT | ZSD_SO_WF_EVENT | Event | Log Event | Approval Log Event | Event |
| ZSD_SO_SEQNR | ZSD_SO_SEQNR | No. | Event Number | Event Number | No. |
| ZSD_SO_CHG_TEXT | ZSD_SO_CHG_TEXT | Text | Text | Text | Text |

Standard data elements reused in the tables (do not create them):

| Data element | Used for |
|--------------|----------|
| MANDT | Client |
| VKORG, VTWEG, SPART, AUART | Sales area, order type |
| VBELN_VA | Sales order, contract |
| KUNAG, NAME1_GP | Customer, name |
| NETWR_AK, WAERK | Net value, currency |
| XUBNAME, SYUNAME | Users |
| AD_SMTPADR, AD_NAMTEXT | E-mail, full name |
| XFELD | Active checkbox |
| CHAR1 | E-mail source |
| SYSUUID_C32 | Log ID (UUID) |
| SWW_WIID | Workflow ID |
| SIBFEVENT | Trigger event |
| DATUM, UZEIT | Date, time |

Activate all data elements.

## 3. Approver table ZSD_SO_APPR_CFG (SE11 → Database table)

- Short description: `SD: SO Change Approval - Approver per Level`
- Delivery and Maintenance: Delivery class **C**, Data Browser/Table View Maint. **Display/Maintenance Allowed**
- One approver per level. Levels run in sequence: 01, then 02, then 03 …

| Field | Key | Initial values | Data element | Check table | Description |
|-------|-----|----------------|--------------|-------------|-------------|
| MANDT | X | X | MANDT | T000 | Client |
| VKORG | X | X | VKORG | TVKO | Sales organization of the order |
| AUART | X | X | AUART | TVAK | Sales order type |
| APPR_LEVEL | X | X | ZSD_SO_LEVEL | – | Level / sequence: 01, 02, 03 … |
| UNAME | | | XUBNAME | – | Approver (SAP user, gets the My Inbox work item) |
| EMAIL | | | AD_SMTPADR | – | Optional e-mail. Empty = e-mail from SU01 |
| ACTIVE | | | XFELD | – | Checkbox: X = level active |

- Foreign keys: VKORG → TVKO, AUART → TVAK (*Check table* button on the field).
- Technical settings: Data class **APPL2**, Size category **0**, Buffering **not allowed**.
- Enhancement category: *Can't be enhanced*.

ADT source:

```
@EndUserText.label : 'SD: SO Change Approval - Approver per Level'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zsd_so_appr_cfg {

  key mandt      : mandt not null;

  @AbapCatalog.foreignKey.screenCheck : true
  key vkorg      : vkorg not null
    with foreign key [0..*,1] tvko
      where mandt = zsd_so_appr_cfg.mandt
        and vkorg = zsd_so_appr_cfg.vkorg;

  @AbapCatalog.foreignKey.screenCheck : true
  key auart      : auart not null
    with foreign key [0..*,1] tvak
      where mandt = zsd_so_appr_cfg.mandt
        and auart = zsd_so_appr_cfg.auart;

  key appr_level : zsd_so_level not null;
  uname          : xubname;
  email          : ad_smtpadr;
  active         : xfeld;

}
```

Example entries:

| VKORG | AUART | APPR_LEVEL | UNAME | EMAIL | ACTIVE |
|-------|-------|------------|-------|-------|--------|
| 2000 | ZOP | 01 | SALESMGR | | X |
| 2000 | ZOP | 02 | FINMGR | finance.manager@company.com | X |

## 4. Table maintenance and transaction for ZSD_SO_APPR_CFG

1. SE11 → ZSD_SO_APPR_CFG → *Utilities → Table Maintenance Generator*:
   - Authorization group `ZSD` (or &NC&)
   - Function group `ZSD_SO_APPR_CFG`
   - Maintenance type **one step**, overview screen **0001**
   - Standard recording routine
   - *Find Scr. Number(s)* → *Create*
2. **ACTIVE as checkbox:** if the field is shown as an input field, open function group ZSD_SO_APPR_CFG screen 0001 in SE51 → Layout. Select ACTIVE, then *Edit → Convert → Checkbox*. Save and activate.
3. **Transaction:** SE93 → `ZSD_SO_APPR` → *Transaction with parameters*:
   - Text: `Maintain SO Change Approvers`
   - Default transaction `SM30`, *Skip initial screen*
   - Parameters: `VIEWNAME = ZSD_SO_APPR_CFG`, `UPDATE = X`

## 5. Log header table ZSD_SO_CHG_LH

- Short description: `SD: SO Change Approval WF Log - Header`
- Delivery class **A** (application data). Data Browser: **Display/Maintenance allowed with restrictions** (display only).
- One row per approval run (one per VA02 save with monitored changes).

| Field | Key | Initial values | Data element | Description |
|-------|-----|----------------|--------------|-------------|
| MANDT | X | X | MANDT | Client |
| LOG_ID | X | X | SYSUUID_C32 | Run ID (UUID) |
| VBELN | | | VBELN_VA | Sales order |
| CONTRACT | | | VBELN_VA | Referenced contract (VBAK-VGBEL) |
| AUART | | | AUART | Order type |
| VKORG | | | VKORG | Sales organization |
| VTWEG | | | VTWEG | Distribution channel |
| SPART | | | SPART | Division |
| KUNNR | | | KUNAG | Sold-to party |
| CUST_NAME | | | NAME1_GP | Customer name |
| NETWR | | | NETWR_AK | Net value. Currency field: reference table ZSD_SO_CHG_LH, field WAERK |
| WAERK | | | WAERK | Currency |
| CHANGE_TEXT | | | ZSD_SO_CHG_TEXT | Summary of the changes |
| STATUS | | | ZSD_SO_WF_STATUS | P / A / R / X / E / F |
| CURR_LEVEL | | | ZSD_SO_LEVEL | Level currently in process |
| LEVELS | | | ZSD_SO_LEVEL | Number of levels |
| WF_ID | | | SWW_WIID | Workflow ID |
| REPLACED_BY | | | SYSUUID_C32 | Newer run that replaced this run |
| TRIGGER_EVT | | | SIBFEVENT | Event (CHANGE_APPROVAL_REQUIRED) |
| TRIGGER_BY | | | XUBNAME | User who changed the order (requester) |
| TRIGGER_ON | | | DATUM | Change date |
| TRIGGER_AT | | | UZEIT | Change time |
| CREATED_ON | | | DATUM | Run created on |
| CREATED_AT | | | UZEIT | Run created at |
| CREATED_BY | | | SYUNAME | Run created by |
| CHANGED_ON | | | DATUM | Last change on |
| CHANGED_AT | | | UZEIT | Last change at |
| FINISHED_ON | | | DATUM | Run finished on |
| FINISHED_AT | | | UZEIT | Run finished at |

- Technical settings: Data class **APPL1**, Size category **1**, Buffering **not allowed**.
- **Secondary index** (SE11 → *Indexes* → Create): `Z01` = `MANDT, VBELN, STATUS`, Non-unique. It is used on every VA02 screen by the "in approval" check.

ADT source:

```
@EndUserText.label : 'SD: SO Change Approval WF Log - Header'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zsd_so_chg_lh {

  key mandt   : mandt not null;
  key log_id  : sysuuid_c32 not null;
  vbeln       : vbeln_va;
  contract    : vbeln_va;
  auart       : auart;
  vkorg       : vkorg;
  vtweg       : vtweg;
  spart       : spart;
  kunnr       : kunag;
  cust_name   : name1_gp;
  netwr       : netwr_ak;
  waerk       : waerk;
  change_text : zsd_so_chg_text;
  status      : zsd_so_wf_status;
  curr_level  : zsd_so_level;
  levels      : zsd_so_level;
  wf_id       : sww_wiid;
  replaced_by : sysuuid_c32;
  trigger_evt : sibfevent;
  trigger_by  : xubname;
  trigger_on  : datum;
  trigger_at  : uzeit;
  created_on  : datum;
  created_at  : uzeit;
  created_by  : syuname;
  changed_on  : datum;
  changed_at  : uzeit;
  finished_on : datum;
  finished_at : uzeit;

}
```

## 6. Log level table ZSD_SO_CHG_LL

- Short description: `SD: SO Change Approval WF Log - Levels`
- Delivery class **A**, display only. One row per run and level. The approvers are copied from ZSD_SO_APPR_CFG when the run starts.

| Field | Key | Initial values | Data element | Description |
|-------|-----|----------------|--------------|-------------|
| MANDT | X | X | MANDT | Client |
| LOG_ID | X | X | SYSUUID_C32 | Run ID |
| APPR_LEVEL | X | X | ZSD_SO_LEVEL | Level |
| UNAME | | | XUBNAME | Approver |
| FULL_NAME | | | AD_NAMTEXT | Approver name |
| EMAIL | | | AD_SMTPADR | Approver e-mail |
| EMAIL_SRC | | | CHAR1 | T = approver table, U = user master, blank = none |
| STATUS | | | ZSD_SO_WF_STATUS | W / D / A / R / N |
| STARTED_ON | | | DATUM | Level started on |
| STARTED_AT | | | UZEIT | Level started at |
| DECIDED_ON | | | DATUM | Decision date |
| DECIDED_AT | | | UZEIT | Decision time |
| DECIDED_BY | | | XUBNAME | User who decided |

Technical settings: Data class **APPL1**, Size category **1**, Buffering **not allowed**.

```
@EndUserText.label : 'SD: SO Change Approval WF Log - Levels'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zsd_so_chg_ll {

  key mandt      : mandt not null;
  key log_id     : sysuuid_c32 not null;
  key appr_level : zsd_so_level not null;
  uname          : xubname;
  full_name      : ad_namtext;
  email          : ad_smtpadr;
  email_src      : char1;
  status         : zsd_so_wf_status;
  started_on     : datum;
  started_at     : uzeit;
  decided_on     : datum;
  decided_at     : uzeit;
  decided_by     : xubname;

}
```

## 7. Log event table ZSD_SO_CHG_LE

- Short description: `SD: SO Change Approval WF Log - Events`
- Delivery class **A**, display only. This is the timeline of a run, shown in the report popup.

| Field | Key | Initial values | Data element | Description |
|-------|-----|----------------|--------------|-------------|
| MANDT | X | X | MANDT | Client |
| LOG_ID | X | X | SYSUUID_C32 | Run ID |
| SEQNR | X | X | ZSD_SO_SEQNR | Event number |
| EVENT | | | ZSD_SO_WF_EVENT | Event (see 1.2) |
| APPR_LEVEL | | | ZSD_SO_LEVEL | Level |
| UNAME | | | XUBNAME | User concerned |
| TEXT | | | ZSD_SO_CHG_TEXT | Details |
| CREATED_ON | | | DATUM | Date |
| CREATED_AT | | | UZEIT | Time |
| CREATED_BY | | | SYUNAME | Logged by |

Technical settings: Data class **APPL1**, Size category **2**, Buffering **not allowed**.

```
@EndUserText.label : 'SD: SO Change Approval WF Log - Events'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zsd_so_chg_le {

  key mandt  : mandt not null;
  key log_id : sysuuid_c32 not null;
  key seqnr  : zsd_so_seqnr not null;
  event      : zsd_so_wf_event;
  appr_level : zsd_so_level;
  uname      : xubname;
  text       : zsd_so_chg_text;
  created_on : datum;
  created_at : uzeit;
  created_by : syuname;

}
```

## 8. Create the four classes (empty)

SE24 → Create, *Usual ABAP class*, *Final*, instantiation *Public*. Save each one without methods:

| Class | Description |
|-------|-------------|
| ZCL_SD_SO_CHG_LOG | SD: SO change approval - workflow log |
| ZCL_SD_SO_CHG_NOTIFY | SD: SO change approval - e-mails |
| ZCL_SD_SO_CHG_MONITOR | SD: SO change approval - change detection |
| ZCL_SD_SO_CHG_WF | SD: SO change approval - workflow object |

Then for each class: *Goto → Source code based* (or ADT), replace the whole source with the code of steps 9–12, save. Activate all four together at the end of step 12.

## 9. Class ZCL_SD_SO_CHG_LOG

Purpose: log of every run (header, levels, events), approver determination, closing an older run and cancelling its workflow, and the icons and texts for the report.

| Method | Purpose |
|--------|---------|
| GET_APPROVERS | Approvers of sales org + order type from ZSD_SO_APPR_CFG, with name and e-mail |
| GET_USER_DATA | Full name and e-mail from SU01 (BAPI_USER_GET_DETAIL) |
| CREATE_LOG | New run: header (status P) + one level row per approver (status W) |
| CLOSE_PREVIOUS | Older run in process → status F, levels N, workflow cancelled (SWW_WI_ADMIN_CANCEL) |
| ADD_EVENT | Writes one timeline event |
| SET_WF_ID / SET_CURRENT_LEVEL / SET_LEVEL_STATUS / FINISH | Status updates |
| IS_RUNNING | Order has a run in process (= order locked in VA02) |
| GET_HEADER / GET_LEVELS / GET_LEVEL / GET_EVENTS | Read the log |
| GET_STATUS_ICON / _TEXT, GET_LEVEL_ICON / _TEXT, GET_EVENT_ICON / _TEXT | Icons and texts for report and e-mail |

```abap
*&---------------------------------------------------------------------*
*& Class          : ZCL_SD_SO_CHG_LOG
*& Workflow       : ZSD_SO_CHG_APPR (WS9xxxxxxx)
*& Package        : ZSD
*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : <Functional consultant>
*&---------------------------------------------------------------------*
*& Purpose        : Log of every run of the sales order change approval
*&                  workflow (CH4323): header ZSD_SO_CHG_LH, levels
*&                  ZSD_SO_CHG_LL, events ZSD_SO_CHG_LE. Approver
*&                  determination from ZSD_SO_APPR_CFG.
*& Note           : No COMMIT WORK here; the caller (sales order save or
*&                  workflow step) commits.
*&---------------------------------------------------------------------*
*& Created By     : Hassan Diab
*& Created On     : 06.10.2026
*& Request No.    : <Request>
*& Version        : 1.0
*&---------------------------------------------------------------------*
*& Change History
*&---------------------------------------------------------------------*
*& Ver | Date       | Author        | Request No.  | Description
*&-----|------------|---------------|--------------|--------------------
*& 1.0 | 06.10.2026 | Hassan Diab   | <Request>    | Initial Creation
*&---------------------------------------------------------------------*
CLASS ZCL_SD_SO_CHG_LOG DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES:
      TT_LEVELS TYPE STANDARD TABLE OF ZSD_SO_CHG_LL WITH DEFAULT KEY .
    TYPES:
      TT_EVENTS TYPE STANDARD TABLE OF ZSD_SO_CHG_LE WITH DEFAULT KEY .
    TYPES:
      BEGIN OF TY_APPROVER,
        APPR_LEVEL TYPE ZSD_SO_LEVEL,
        UNAME      TYPE XUBNAME,
        FULL_NAME  TYPE AD_NAMTEXT,
        EMAIL      TYPE AD_SMTPADR,
        EMAIL_SRC  TYPE CHAR1,
      END OF TY_APPROVER .
    TYPES:
      TT_APPROVER TYPE STANDARD TABLE OF TY_APPROVER WITH DEFAULT KEY .

    "--- header status ---------------------------------------------------
    CONSTANTS:
      BEGIN OF GC_STATUS,
        IN_PROCESS TYPE ZSD_SO_WF_STATUS VALUE 'P',         "#EC NOTEXT
        APPROVED   TYPE ZSD_SO_WF_STATUS VALUE 'A',         "#EC NOTEXT
        REJECTED   TYPE ZSD_SO_WF_STATUS VALUE 'R',         "#EC NOTEXT
        CANCELLED  TYPE ZSD_SO_WF_STATUS VALUE 'X',         "#EC NOTEXT
        ERROR      TYPE ZSD_SO_WF_STATUS VALUE 'E',         "#EC NOTEXT
        REPLACED   TYPE ZSD_SO_WF_STATUS VALUE 'F',         "#EC NOTEXT
      END OF GC_STATUS .

    "--- level status ----------------------------------------------------
    CONSTANTS:
      BEGIN OF GC_LEVEL,
        WAITING     TYPE ZSD_SO_WF_STATUS VALUE 'W',        "#EC NOTEXT
        PENDING     TYPE ZSD_SO_WF_STATUS VALUE 'D',        "#EC NOTEXT
        APPROVED    TYPE ZSD_SO_WF_STATUS VALUE 'A',        "#EC NOTEXT
        REJECTED    TYPE ZSD_SO_WF_STATUS VALUE 'R',        "#EC NOTEXT
        NOT_REACHED TYPE ZSD_SO_WF_STATUS VALUE 'N',        "#EC NOTEXT
      END OF GC_LEVEL .

    "--- events ----------------------------------------------------------
    CONSTANTS:
      BEGIN OF GC_EVENT,
        CHANGE   TYPE ZSD_SO_WF_EVENT VALUE 'CHANGE',       "#EC NOTEXT
        START    TYPE ZSD_SO_WF_EVENT VALUE 'START',        "#EC NOTEXT
        LEVEL    TYPE ZSD_SO_WF_EVENT VALUE 'LEVEL',        "#EC NOTEXT
        MAIL     TYPE ZSD_SO_WF_EVENT VALUE 'MAIL',         "#EC NOTEXT
        MAIL_ERR TYPE ZSD_SO_WF_EVENT VALUE 'MAIL_ERR',     "#EC NOTEXT
        INBOX    TYPE ZSD_SO_WF_EVENT VALUE 'INBOX',        "#EC NOTEXT
        APPROVE  TYPE ZSD_SO_WF_EVENT VALUE 'APPROVE',      "#EC NOTEXT
        REJECT   TYPE ZSD_SO_WF_EVENT VALUE 'REJECT',       "#EC NOTEXT
        RELEASE  TYPE ZSD_SO_WF_EVENT VALUE 'RELEASE',      "#EC NOTEXT
        REL_ERR  TYPE ZSD_SO_WF_EVENT VALUE 'REL_ERR',      "#EC NOTEXT
        CLOSE    TYPE ZSD_SO_WF_EVENT VALUE 'CLOSE',        "#EC NOTEXT
        INFO     TYPE ZSD_SO_WF_EVENT VALUE 'INFO',         "#EC NOTEXT
        ERROR    TYPE ZSD_SO_WF_EVENT VALUE 'ERROR',        "#EC NOTEXT
        REPLACED TYPE ZSD_SO_WF_EVENT VALUE 'REPLACED',     "#EC NOTEXT
      END OF GC_EVENT .

    "--- e-mail source ---------------------------------------------------
    CONSTANTS:
      BEGIN OF GC_EMAIL_SRC,
        TABLE TYPE CHAR1 VALUE 'T',                         "#EC NOTEXT
        USER  TYPE CHAR1 VALUE 'U',                         "#EC NOTEXT
        NONE  TYPE CHAR1 VALUE ' ',                         "#EC NOTEXT
      END OF GC_EMAIL_SRC .

    CLASS-METHODS GET_APPROVERS
      IMPORTING
        !IV_VKORG          TYPE VKORG
        !IV_AUART          TYPE AUART
      RETURNING
        VALUE(RT_APPROVER) TYPE TT_APPROVER .

    CLASS-METHODS GET_USER_DATA
      IMPORTING
        !IV_UNAME     TYPE XUBNAME
      EXPORTING
        !EV_FULL_NAME TYPE AD_NAMTEXT
        !EV_EMAIL     TYPE AD_SMTPADR .

    CLASS-METHODS CLOSE_PREVIOUS
      IMPORTING
        !IV_VBELN      TYPE VBELN_VA
        !IV_NEW_LOG_ID TYPE SYSUUID_C32
        !IV_USER       TYPE XUBNAME OPTIONAL .

    CLASS-METHODS CREATE_LOG
      IMPORTING
        !IS_HEADER       TYPE ZSD_SO_CHG_LH
        !IT_APPROVER     TYPE TT_APPROVER
      RETURNING
        VALUE(RV_LOG_ID) TYPE SYSUUID_C32 .

    CLASS-METHODS SET_WF_ID
      IMPORTING
        !IV_LOG_ID TYPE SYSUUID_C32
        !IV_WF_ID  TYPE SWW_WIID .

    CLASS-METHODS ADD_EVENT
      IMPORTING
        !IV_LOG_ID TYPE SYSUUID_C32
        !IV_EVENT  TYPE ZSD_SO_WF_EVENT
        !IV_LEVEL  TYPE ZSD_SO_LEVEL OPTIONAL
        !IV_UNAME  TYPE XUBNAME OPTIONAL
        !IV_TEXT   TYPE CSEQUENCE OPTIONAL .

    CLASS-METHODS SET_LEVEL_STATUS
      IMPORTING
        !IV_LOG_ID TYPE SYSUUID_C32
        !IV_LEVEL  TYPE ZSD_SO_LEVEL
        !IV_STATUS TYPE ZSD_SO_WF_STATUS
        !IV_UNAME  TYPE XUBNAME OPTIONAL .

    CLASS-METHODS SET_CURRENT_LEVEL
      IMPORTING
        !IV_LOG_ID TYPE SYSUUID_C32
        !IV_LEVEL  TYPE ZSD_SO_LEVEL .

    CLASS-METHODS FINISH
      IMPORTING
        !IV_LOG_ID TYPE SYSUUID_C32
        !IV_STATUS TYPE ZSD_SO_WF_STATUS .

    CLASS-METHODS IS_RUNNING
      IMPORTING
        !IV_VBELN         TYPE VBELN_VA
      RETURNING
        VALUE(RV_RUNNING) TYPE ABAP_BOOL .

    CLASS-METHODS GET_HEADER
      IMPORTING
        !IV_LOG_ID       TYPE SYSUUID_C32
      RETURNING
        VALUE(RS_HEADER) TYPE ZSD_SO_CHG_LH .

    CLASS-METHODS GET_LEVELS
      IMPORTING
        !IV_LOG_ID       TYPE SYSUUID_C32
      RETURNING
        VALUE(RT_LEVELS) TYPE TT_LEVELS .

    CLASS-METHODS GET_LEVEL
      IMPORTING
        !IV_LOG_ID      TYPE SYSUUID_C32
        !IV_LEVEL       TYPE ZSD_SO_LEVEL
      RETURNING
        VALUE(RS_LEVEL) TYPE ZSD_SO_CHG_LL .

    CLASS-METHODS GET_EVENTS
      IMPORTING
        !IV_LOG_ID       TYPE SYSUUID_C32
      RETURNING
        VALUE(RT_EVENTS) TYPE TT_EVENTS .

    "--- icons: resolved by name from table ICON (one place to change) ---
    CLASS-METHODS GET_STATUS_ICON
      IMPORTING
        !IV_STATUS     TYPE ZSD_SO_WF_STATUS
      RETURNING
        VALUE(RV_ICON) TYPE ICON_D .

    CLASS-METHODS GET_LEVEL_ICON
      IMPORTING
        !IV_STATUS     TYPE ZSD_SO_WF_STATUS
      RETURNING
        VALUE(RV_ICON) TYPE ICON_D .

    CLASS-METHODS GET_EVENT_ICON
      IMPORTING
        !IV_EVENT      TYPE ZSD_SO_WF_EVENT
      RETURNING
        VALUE(RV_ICON) TYPE ICON_D .

    CLASS-METHODS GET_STATUS_TEXT
      IMPORTING
        !IV_STATUS     TYPE ZSD_SO_WF_STATUS
      RETURNING
        VALUE(RV_TEXT) TYPE CHAR30 .

    CLASS-METHODS GET_LEVEL_TEXT
      IMPORTING
        !IV_STATUS     TYPE ZSD_SO_WF_STATUS
      RETURNING
        VALUE(RV_TEXT) TYPE CHAR30 .

    CLASS-METHODS GET_EVENT_TEXT
      IMPORTING
        !IV_EVENT      TYPE ZSD_SO_WF_EVENT
      RETURNING
        VALUE(RV_TEXT) TYPE CHAR30 .

  PRIVATE SECTION.

    TYPES:
      BEGIN OF TY_ICON,
        NAME TYPE ICONNAME,
        ID   TYPE ICON_D,
      END OF TY_ICON .

    CLASS-DATA GT_ICON TYPE SORTED TABLE OF TY_ICON WITH UNIQUE KEY NAME .

    CLASS-METHODS ICON_BY_NAME
      IMPORTING
        !IV_NAME       TYPE ICONNAME
      RETURNING
        VALUE(RV_ICON) TYPE ICON_D .

    CLASS-METHODS TOUCH_HEADER
      IMPORTING
        !IV_LOG_ID TYPE SYSUUID_C32 .

ENDCLASS.



CLASS ZCL_SD_SO_CHG_LOG IMPLEMENTATION.


  METHOD GET_APPROVERS.

    DATA: LT_CFG      TYPE STANDARD TABLE OF ZSD_SO_APPR_CFG,
          LS_CFG      TYPE ZSD_SO_APPR_CFG,
          LS_APPROVER TYPE TY_APPROVER,
          LV_EMAIL    TYPE AD_SMTPADR.

    CLEAR RT_APPROVER.

    SELECT * FROM ZSD_SO_APPR_CFG INTO TABLE LT_CFG
      WHERE VKORG  = IV_VKORG
        AND AUART  = IV_AUART
        AND ACTIVE = ABAP_TRUE.

    SORT LT_CFG BY APPR_LEVEL.

    LOOP AT LT_CFG INTO LS_CFG.

      CLEAR LS_APPROVER.
      LS_APPROVER-APPR_LEVEL = LS_CFG-APPR_LEVEL.
      LS_APPROVER-UNAME      = LS_CFG-UNAME.

      GET_USER_DATA( EXPORTING IV_UNAME     = LS_CFG-UNAME
                     IMPORTING EV_FULL_NAME = LS_APPROVER-FULL_NAME
                               EV_EMAIL     = LV_EMAIL ).

      " e-mail from the approver table first, then from the user master
      IF LS_CFG-EMAIL IS NOT INITIAL.
        LS_APPROVER-EMAIL     = LS_CFG-EMAIL.
        LS_APPROVER-EMAIL_SRC = GC_EMAIL_SRC-TABLE.
      ELSEIF LV_EMAIL IS NOT INITIAL.
        LS_APPROVER-EMAIL     = LV_EMAIL.
        LS_APPROVER-EMAIL_SRC = GC_EMAIL_SRC-USER.
      ELSE.
        LS_APPROVER-EMAIL_SRC = GC_EMAIL_SRC-NONE.
      ENDIF.

      IF LS_APPROVER-FULL_NAME IS INITIAL.
        LS_APPROVER-FULL_NAME = LS_CFG-UNAME.
      ENDIF.

      APPEND LS_APPROVER TO RT_APPROVER.

    ENDLOOP.

  ENDMETHOD.


  METHOD GET_USER_DATA.

    DATA: LS_ADDRESS TYPE BAPIADDR3,
          LT_RETURN  TYPE STANDARD TABLE OF BAPIRET2.

    CLEAR: EV_FULL_NAME, EV_EMAIL.

    IF IV_UNAME IS INITIAL.
      RETURN.
    ENDIF.

    CALL FUNCTION 'BAPI_USER_GET_DETAIL'
      EXPORTING
        USERNAME = IV_UNAME
      IMPORTING
        ADDRESS  = LS_ADDRESS
      TABLES
        RETURN   = LT_RETURN.

    EV_FULL_NAME = LS_ADDRESS-FULLNAME.
    EV_EMAIL     = LS_ADDRESS-E_MAIL.

  ENDMETHOD.


  METHOD ADD_EVENT.

    DATA: LS_EVENT TYPE ZSD_SO_CHG_LE,
          LV_SEQNR TYPE ZSD_SO_CHG_LE-SEQNR.

    IF IV_LOG_ID IS INITIAL.
      RETURN.
    ENDIF.

    SELECT MAX( SEQNR ) FROM ZSD_SO_CHG_LE INTO LV_SEQNR
      WHERE LOG_ID = IV_LOG_ID.

    LS_EVENT-MANDT      = SY-MANDT.
    LS_EVENT-LOG_ID     = IV_LOG_ID.
    LS_EVENT-SEQNR      = LV_SEQNR + 1.
    LS_EVENT-EVENT      = IV_EVENT.
    LS_EVENT-APPR_LEVEL = IV_LEVEL.
    LS_EVENT-UNAME      = IV_UNAME.
    LS_EVENT-TEXT       = IV_TEXT.
    LS_EVENT-CREATED_ON = SY-DATUM.
    LS_EVENT-CREATED_AT = SY-UZEIT.
    LS_EVENT-CREATED_BY = SY-UNAME.

    INSERT ZSD_SO_CHG_LE FROM LS_EVENT.

    TOUCH_HEADER( IV_LOG_ID ).

  ENDMETHOD.


  METHOD CLOSE_PREVIOUS.

    DATA: LT_OLD    TYPE STANDARD TABLE OF ZSD_SO_CHG_LH,
          LS_OLD    TYPE ZSD_SO_CHG_LH,
          LV_TEXT   TYPE STRING,
          LV_STATUS TYPE SWW_WISTAT,
          LS_MSG    TYPE SWF_T100MS.

    SELECT * FROM ZSD_SO_CHG_LH INTO TABLE LT_OLD
      WHERE VBELN  = IV_VBELN
        AND STATUS = GC_STATUS-IN_PROCESS
        AND LOG_ID <> IV_NEW_LOG_ID.

    LOOP AT LT_OLD INTO LS_OLD.

      CONCATENATE 'Replaced by a new run after order change by'(040)
                  IV_USER INTO LV_TEXT SEPARATED BY SPACE.
      ADD_EVENT( IV_LOG_ID = LS_OLD-LOG_ID
                 IV_EVENT  = GC_EVENT-REPLACED
                 IV_UNAME  = IV_USER
                 IV_TEXT   = LV_TEXT ).

      UPDATE ZSD_SO_CHG_LH
        SET STATUS      = GC_STATUS-REPLACED
            REPLACED_BY = IV_NEW_LOG_ID
            FINISHED_ON = SY-DATUM
            FINISHED_AT = SY-UZEIT
            CHANGED_ON  = SY-DATUM
            CHANGED_AT  = SY-UZEIT
        WHERE LOG_ID = LS_OLD-LOG_ID.

      UPDATE ZSD_SO_CHG_LL
        SET STATUS = GC_LEVEL-NOT_REACHED
        WHERE LOG_ID = LS_OLD-LOG_ID
          AND ( STATUS = GC_LEVEL-WAITING OR STATUS = GC_LEVEL-PENDING ).

      " kill the old workflow (open work items disappear from My Inbox)
      IF LS_OLD-WF_ID IS NOT INITIAL.
        CALL FUNCTION 'SWW_WI_ADMIN_CANCEL'
          EXPORTING
            WI_ID                       = LS_OLD-WF_ID
            DO_COMMIT                   = SPACE
            LOG_MESSAGE                 = LS_MSG
          IMPORTING
            NEW_STATUS                  = LV_STATUS
          EXCEPTIONS
            UPDATE_FAILED               = 1
            NO_AUTHORIZATION            = 2
            INFEASIBLE_STATE_TRANSITION = 3
            OTHERS                      = 4.
        IF SY-SUBRC <> 0.
          ADD_EVENT( IV_LOG_ID = LS_OLD-LOG_ID
                     IV_EVENT  = GC_EVENT-ERROR
                     IV_TEXT   = 'Old workflow could not be cancelled - cancel it in SWIA'(041) ).
        ENDIF.
      ENDIF.

      CONCATENATE 'Previous run closed:'(042) LS_OLD-LOG_ID
                  INTO LV_TEXT SEPARATED BY SPACE.
      ADD_EVENT( IV_LOG_ID = IV_NEW_LOG_ID
                 IV_EVENT  = GC_EVENT-INFO
                 IV_TEXT   = LV_TEXT ).

    ENDLOOP.

  ENDMETHOD.


  METHOD CREATE_LOG.

    DATA: LS_HEADER   TYPE ZSD_SO_CHG_LH,
          LS_LEVEL    TYPE ZSD_SO_CHG_LL,
          LS_APPROVER TYPE TY_APPROVER,
          LV_UUID     TYPE SYSUUID_C32.

    CLEAR RV_LOG_ID.

    TRY.
        LV_UUID = CL_SYSTEM_UUID=>CREATE_UUID_C32_STATIC( ).
      CATCH CX_UUID_ERROR.
        RETURN.
    ENDTRY.

    LS_HEADER            = IS_HEADER.
    LS_HEADER-MANDT      = SY-MANDT.
    LS_HEADER-LOG_ID     = LV_UUID.
    LS_HEADER-STATUS     = GC_STATUS-IN_PROCESS.
    LS_HEADER-LEVELS     = LINES( IT_APPROVER ).
    LS_HEADER-CREATED_ON = SY-DATUM.
    LS_HEADER-CREATED_AT = SY-UZEIT.
    LS_HEADER-CREATED_BY = SY-UNAME.
    LS_HEADER-CHANGED_ON = SY-DATUM.
    LS_HEADER-CHANGED_AT = SY-UZEIT.

    INSERT ZSD_SO_CHG_LH FROM LS_HEADER.
    IF SY-SUBRC <> 0.
      RETURN.
    ENDIF.

    LOOP AT IT_APPROVER INTO LS_APPROVER.
      CLEAR LS_LEVEL.
      LS_LEVEL-MANDT      = SY-MANDT.
      LS_LEVEL-LOG_ID     = LV_UUID.
      LS_LEVEL-APPR_LEVEL = LS_APPROVER-APPR_LEVEL.
      LS_LEVEL-UNAME      = LS_APPROVER-UNAME.
      LS_LEVEL-FULL_NAME  = LS_APPROVER-FULL_NAME.
      LS_LEVEL-EMAIL      = LS_APPROVER-EMAIL.
      LS_LEVEL-EMAIL_SRC  = LS_APPROVER-EMAIL_SRC.
      LS_LEVEL-STATUS     = GC_LEVEL-WAITING.
      INSERT ZSD_SO_CHG_LL FROM LS_LEVEL.
    ENDLOOP.

    RV_LOG_ID = LV_UUID.

  ENDMETHOD.


  METHOD SET_WF_ID.

    UPDATE ZSD_SO_CHG_LH
      SET WF_ID      = IV_WF_ID
          CHANGED_ON = SY-DATUM
          CHANGED_AT = SY-UZEIT
      WHERE LOG_ID = IV_LOG_ID.

  ENDMETHOD.


  METHOD FINISH.

    UPDATE ZSD_SO_CHG_LH
      SET STATUS      = IV_STATUS
          FINISHED_ON = SY-DATUM
          FINISHED_AT = SY-UZEIT
          CHANGED_ON  = SY-DATUM
          CHANGED_AT  = SY-UZEIT
      WHERE LOG_ID = IV_LOG_ID.

    UPDATE ZSD_SO_CHG_LL
      SET STATUS = GC_LEVEL-NOT_REACHED
      WHERE LOG_ID = IV_LOG_ID
        AND STATUS = GC_LEVEL-WAITING.

  ENDMETHOD.


  METHOD GET_EVENTS.

    CLEAR RT_EVENTS.

    SELECT * FROM ZSD_SO_CHG_LE INTO TABLE RT_EVENTS
      WHERE LOG_ID = IV_LOG_ID
      ORDER BY SEQNR.

  ENDMETHOD.


  METHOD GET_EVENT_ICON.

    DATA LV_NAME TYPE ICONNAME.

    CASE IV_EVENT.
      WHEN GC_EVENT-CHANGE.   LV_NAME = 'ICON_DOCUMENT'.
      WHEN GC_EVENT-START.    LV_NAME = 'ICON_EXECUTE_OBJECT'.
      WHEN GC_EVENT-LEVEL.    LV_NAME = 'ICON_YELLOW_LIGHT'.
      WHEN GC_EVENT-MAIL.     LV_NAME = 'ICON_MAIL'.
      WHEN GC_EVENT-MAIL_ERR. LV_NAME = 'ICON_MESSAGE_ERROR'.
      WHEN GC_EVENT-INBOX.    LV_NAME = 'ICON_INBOX'.
      WHEN GC_EVENT-APPROVE.  LV_NAME = 'ICON_GREEN_LIGHT'.
      WHEN GC_EVENT-REJECT.   LV_NAME = 'ICON_RED_LIGHT'.
      WHEN GC_EVENT-RELEASE.  LV_NAME = 'ICON_UNLOCKED'.
      WHEN GC_EVENT-REL_ERR.  LV_NAME = 'ICON_MESSAGE_ERROR'.
      WHEN GC_EVENT-CLOSE.    LV_NAME = 'ICON_LOCKED'.
      WHEN GC_EVENT-INFO.     LV_NAME = 'ICON_INFORMATION'.
      WHEN GC_EVENT-ERROR.    LV_NAME = 'ICON_MESSAGE_ERROR'.
      WHEN GC_EVENT-REPLACED. LV_NAME = 'ICON_CHANGE'.
    ENDCASE.

    RV_ICON = ICON_BY_NAME( LV_NAME ).

  ENDMETHOD.


  METHOD GET_EVENT_TEXT.

    CASE IV_EVENT.
      WHEN GC_EVENT-CHANGE.   RV_TEXT = 'Order changed'(019).
      WHEN GC_EVENT-START.    RV_TEXT = 'Workflow started'(020).
      WHEN GC_EVENT-LEVEL.    RV_TEXT = 'Level in process'(021).
      WHEN GC_EVENT-MAIL.     RV_TEXT = 'E-mail sent'(022).
      WHEN GC_EVENT-MAIL_ERR. RV_TEXT = 'E-mail not sent'(023).
      WHEN GC_EVENT-INBOX.    RV_TEXT = 'Sent to My Inbox'(024).
      WHEN GC_EVENT-APPROVE.  RV_TEXT = 'Approved'(025).
      WHEN GC_EVENT-REJECT.   RV_TEXT = 'Rejected'(026).
      WHEN GC_EVENT-RELEASE.  RV_TEXT = 'Delivery block released'(027).
      WHEN GC_EVENT-REL_ERR.  RV_TEXT = 'Release failed'(028).
      WHEN GC_EVENT-CLOSE.    RV_TEXT = 'Closed - stays blocked'(029).
      WHEN GC_EVENT-INFO.     RV_TEXT = 'Information'(030).
      WHEN GC_EVENT-ERROR.    RV_TEXT = 'Error'(031).
      WHEN GC_EVENT-REPLACED. RV_TEXT = 'Replaced by order change'(032).
    ENDCASE.

  ENDMETHOD.


  METHOD GET_HEADER.

    CLEAR RS_HEADER.

    SELECT SINGLE * FROM ZSD_SO_CHG_LH INTO RS_HEADER
      WHERE LOG_ID = IV_LOG_ID.

  ENDMETHOD.


  METHOD GET_LEVEL.

    CLEAR RS_LEVEL.

    SELECT SINGLE * FROM ZSD_SO_CHG_LL INTO RS_LEVEL
      WHERE LOG_ID     = IV_LOG_ID
        AND APPR_LEVEL = IV_LEVEL.

  ENDMETHOD.


  METHOD GET_LEVELS.

    CLEAR RT_LEVELS.

    SELECT * FROM ZSD_SO_CHG_LL INTO TABLE RT_LEVELS
      WHERE LOG_ID = IV_LOG_ID
      ORDER BY APPR_LEVEL.

  ENDMETHOD.


  METHOD GET_LEVEL_ICON.

    DATA LV_NAME TYPE ICONNAME.

    CASE IV_STATUS.
      WHEN GC_LEVEL-WAITING.     LV_NAME = 'ICON_LIGHT_OUT'.
      WHEN GC_LEVEL-PENDING.     LV_NAME = 'ICON_YELLOW_LIGHT'.
      WHEN GC_LEVEL-APPROVED.    LV_NAME = 'ICON_GREEN_LIGHT'.
      WHEN GC_LEVEL-REJECTED.    LV_NAME = 'ICON_RED_LIGHT'.
      WHEN GC_LEVEL-NOT_REACHED. LV_NAME = 'ICON_LIGHT_OUT'.
    ENDCASE.

    RV_ICON = ICON_BY_NAME( LV_NAME ).

  ENDMETHOD.


  METHOD GET_LEVEL_TEXT.

    CASE IV_STATUS.
      WHEN GC_LEVEL-WAITING.     RV_TEXT = 'Waiting'(010).
      WHEN GC_LEVEL-PENDING.     RV_TEXT = 'Pending decision'(011).
      WHEN GC_LEVEL-APPROVED.    RV_TEXT = 'Approved'(012).
      WHEN GC_LEVEL-REJECTED.    RV_TEXT = 'Rejected'(013).
      WHEN GC_LEVEL-NOT_REACHED. RV_TEXT = 'Not reached'(014).
    ENDCASE.

  ENDMETHOD.


  METHOD GET_STATUS_ICON.

    DATA LV_NAME TYPE ICONNAME.

    CASE IV_STATUS.
      WHEN GC_STATUS-IN_PROCESS. LV_NAME = 'ICON_YELLOW_LIGHT'.
      WHEN GC_STATUS-APPROVED.   LV_NAME = 'ICON_GREEN_LIGHT'.
      WHEN GC_STATUS-REJECTED.   LV_NAME = 'ICON_RED_LIGHT'.
      WHEN GC_STATUS-CANCELLED.  LV_NAME = 'ICON_LIGHT_OUT'.
      WHEN GC_STATUS-ERROR.      LV_NAME = 'ICON_MESSAGE_ERROR'.
      WHEN GC_STATUS-REPLACED.   LV_NAME = 'ICON_DELETE'.
    ENDCASE.

    RV_ICON = ICON_BY_NAME( LV_NAME ).

  ENDMETHOD.


  METHOD GET_STATUS_TEXT.

    CASE IV_STATUS.
      WHEN GC_STATUS-IN_PROCESS. RV_TEXT = 'In approval - order locked'(001).
      WHEN GC_STATUS-APPROVED.   RV_TEXT = 'Approved - block released'(002).
      WHEN GC_STATUS-REJECTED.   RV_TEXT = 'Rejected - still blocked'(003).
      WHEN GC_STATUS-CANCELLED.  RV_TEXT = 'Cancelled'(004).
      WHEN GC_STATUS-ERROR.      RV_TEXT = 'Error - still blocked'(005).
      WHEN GC_STATUS-REPLACED.   RV_TEXT = 'Finished - replaced by change'(006).
    ENDCASE.

  ENDMETHOD.


  METHOD ICON_BY_NAME.

    DATA LS_ICON TYPE TY_ICON.

    CLEAR RV_ICON.

    IF IV_NAME IS INITIAL.
      RETURN.
    ENDIF.

    READ TABLE GT_ICON INTO LS_ICON WITH TABLE KEY NAME = IV_NAME.
    IF SY-SUBRC = 0.
      RV_ICON = LS_ICON-ID.
      RETURN.
    ENDIF.

    SELECT SINGLE ID FROM ICON INTO RV_ICON
      WHERE NAME = IV_NAME.

    LS_ICON-NAME = IV_NAME.
    LS_ICON-ID   = RV_ICON.
    INSERT LS_ICON INTO TABLE GT_ICON.

  ENDMETHOD.


  METHOD IS_RUNNING.

    DATA LV_LOG_ID TYPE SYSUUID_C32.

    RV_RUNNING = ABAP_FALSE.

    SELECT SINGLE LOG_ID FROM ZSD_SO_CHG_LH INTO LV_LOG_ID
      WHERE VBELN  = IV_VBELN
        AND STATUS = GC_STATUS-IN_PROCESS.

    IF SY-SUBRC = 0.
      RV_RUNNING = ABAP_TRUE.
    ENDIF.

  ENDMETHOD.


  METHOD SET_CURRENT_LEVEL.

    UPDATE ZSD_SO_CHG_LH
      SET CURR_LEVEL = IV_LEVEL
          CHANGED_ON = SY-DATUM
          CHANGED_AT = SY-UZEIT
      WHERE LOG_ID = IV_LOG_ID.

  ENDMETHOD.


  METHOD SET_LEVEL_STATUS.

    DATA LS_LEVEL TYPE ZSD_SO_CHG_LL.

    SELECT SINGLE * FROM ZSD_SO_CHG_LL INTO LS_LEVEL
      WHERE LOG_ID     = IV_LOG_ID
        AND APPR_LEVEL = IV_LEVEL.

    IF SY-SUBRC <> 0.
      RETURN.
    ENDIF.

    LS_LEVEL-STATUS = IV_STATUS.

    CASE IV_STATUS.
      WHEN GC_LEVEL-PENDING.
        LS_LEVEL-STARTED_ON = SY-DATUM.
        LS_LEVEL-STARTED_AT = SY-UZEIT.
      WHEN GC_LEVEL-APPROVED OR GC_LEVEL-REJECTED.
        LS_LEVEL-DECIDED_ON = SY-DATUM.
        LS_LEVEL-DECIDED_AT = SY-UZEIT.
        IF IV_UNAME IS NOT INITIAL.
          LS_LEVEL-DECIDED_BY = IV_UNAME.
        ELSE.
          LS_LEVEL-DECIDED_BY = LS_LEVEL-UNAME.
        ENDIF.
    ENDCASE.

    UPDATE ZSD_SO_CHG_LL FROM LS_LEVEL.

    TOUCH_HEADER( IV_LOG_ID ).

  ENDMETHOD.


  METHOD TOUCH_HEADER.

    UPDATE ZSD_SO_CHG_LH
      SET CHANGED_ON = SY-DATUM
          CHANGED_AT = SY-UZEIT
      WHERE LOG_ID = IV_LOG_ID.

  ENDMETHOD.
ENDCLASS.
```

Text symbols (*Goto → Text Symbols*):

| Sym | Text | Length |
|-----|------|--------|
| 001 | In approval - order locked | 26 |
| 002 | Approved - block released | 25 |
| 003 | Rejected - still blocked | 24 |
| 004 | Cancelled | 10 |
| 005 | Error - still blocked | 21 |
| 006 | Finished - replaced by change | 29 |
| 010 | Waiting | 10 |
| 011 | Pending decision | 16 |
| 012 | Approved | 10 |
| 013 | Rejected | 10 |
| 014 | Not reached | 11 |
| 019 | Order changed | 13 |
| 020 | Workflow started | 16 |
| 021 | Level in process | 16 |
| 022 | E-mail sent | 11 |
| 023 | E-mail not sent | 15 |
| 024 | Sent to My Inbox | 16 |
| 025 | Approved | 10 |
| 026 | Rejected | 10 |
| 027 | Delivery block released | 23 |
| 028 | Release failed | 14 |
| 029 | Closed - stays blocked | 22 |
| 030 | Information | 11 |
| 031 | Error | 10 |
| 032 | Replaced by order change | 24 |
| 040 | Replaced by a new run after order change by | 43 |
| 041 | Old workflow could not be cancelled - cancel it in SWIA | 55 |
| 042 | Previous run closed: | 20 |

## 10. Class ZCL_SD_SO_CHG_NOTIFY

Purpose: HTML e-mails (Outlook). To the approver of each level: "work item in My Inbox". To the requester: approved, rejected, or no approver.
The My Inbox link is built from constants in the class. **Before activating, replace the placeholders:**

| Constant | Value |
|----------|-------|
| GC_SYSID_PRD | System ID of the production system (e.g. `PS4`) |
| GC_FLP_BASE_PRD | Launchpad URL of production, e.g. `https://<prd-host>:<port>/sap/bc/ui2/flp` |
| GC_FLP_BASE | Launchpad URL of development / quality |
| GC_INBOX_INTENT | `#WorkflowTask-displayInbox` (standard My Inbox, no change needed) |

The URLs must not contain `?` or `#`; the method adds `?sap-client=<client>` and the intent.

```abap
*&---------------------------------------------------------------------*
*& Class          : ZCL_SD_SO_CHG_NOTIFY
*& Workflow       : ZSD_SO_CHG_APPR (WS9xxxxxxx)
*& Package        : ZSD
*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : <Functional consultant>
*&---------------------------------------------------------------------*
*& Purpose        : HTML body and e-mails of the sales order change
*&                  approval workflow (CH4323).
*& Note           : No COMMIT WORK here; the workflow step commits.
*&                  Fiori launchpad base URL: constants GC_FLP_BASE_PRD
*&                  (production, system GC_SYSID_PRD) and GC_FLP_BASE
*&                  (development / quality).
*&---------------------------------------------------------------------*
*& Created By     : Hassan Diab
*& Created On     : 06.10.2026
*& Request No.    : <Request>
*& Version        : 1.0
*&---------------------------------------------------------------------*
*& Change History
*&---------------------------------------------------------------------*
*& Ver | Date       | Author        | Request No.  | Description
*&-----|------------|---------------|--------------|--------------------
*& 1.0 | 06.10.2026 | Hassan Diab   | <Request>    | Initial Creation
*&---------------------------------------------------------------------*
CLASS ZCL_SD_SO_CHG_NOTIFY DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES:
      TT_LINES TYPE STANDARD TABLE OF STRING WITH DEFAULT KEY .

    METHODS BUILD_LINES
      IMPORTING
        !IV_LOG_ID      TYPE SYSUUID_C32
        !IV_INTRO       TYPE CSEQUENCE OPTIONAL
        !IV_INBOX_LINK  TYPE ABAP_BOOL DEFAULT ABAP_FALSE
        !IV_INBOX       TYPE ABAP_BOOL DEFAULT ABAP_FALSE
      RETURNING
        VALUE(RT_LINES) TYPE TT_LINES .

    "! HTML description of the decision work item (Fiori My Inbox):
    "! same content as the approver e-mail, without the inbox link and
    "! without '&' (My Inbox reads &...& in the text as a variable)
    METHODS BUILD_INBOX_HTML
      IMPORTING
        !IV_LOG_ID     TYPE SYSUUID_C32
        !IV_LEVEL      TYPE ZSD_SO_LEVEL
      RETURNING
        VALUE(RT_HTML) TYPE W3HTMLTAB .

    METHODS TO_W3HTML
      IMPORTING
        !IT_LINES      TYPE TT_LINES
      RETURNING
        VALUE(RT_HTML) TYPE W3HTMLTAB .

    METHODS SEND_MAIL
      IMPORTING
        !IV_EMAIL    TYPE AD_SMTPADR
        !IV_SUBJECT  TYPE CSEQUENCE
        !IT_LINES    TYPE TT_LINES
      EXPORTING
        !EV_ERROR    TYPE STRING
      RETURNING
        VALUE(RV_OK) TYPE ABAP_BOOL .

    METHODS NOTIFY_APPROVER
      IMPORTING
        !IV_LOG_ID TYPE SYSUUID_C32
        !IV_LEVEL  TYPE ZSD_SO_LEVEL .

    METHODS NOTIFY_REQUESTER
      IMPORTING
        !IV_LOG_ID TYPE SYSUUID_C32
        !IV_RESULT TYPE ZSD_SO_WF_STATUS .

  PRIVATE SECTION.

    DATA MV_INBOX TYPE ABAP_BOOL .

    CONSTANTS GC_MAX_LINE TYPE I VALUE 255.
    CONSTANTS GC_TD_LABEL TYPE STRING
      VALUE `border:1px solid #d9d9d9;padding:5px 10px;background:#f5f6f7;font-weight:bold;width:220px`. "#EC NOTEXT
    CONSTANTS GC_TD_VALUE TYPE STRING
      VALUE `border:1px solid #d9d9d9;padding:5px 10px`.    "#EC NOTEXT

    CONSTANTS GC_SYSID_PRD TYPE SYSYSID VALUE '<PRD>'.      "#EC NOTEXT
    CONSTANTS GC_FLP_BASE_PRD TYPE STRING
      VALUE `https://<prd-host>:<port>/sap/bc/ui2/flp`.     "#EC NOTEXT
    CONSTANTS GC_FLP_BASE TYPE STRING
      VALUE `https://<dev-qas-host>:<port>/sap/bc/ui2/flp`. "#EC NOTEXT
    CONSTANTS GC_INBOX_INTENT TYPE STRING
      VALUE `#WorkflowTask-displayInbox`.                   "#EC NOTEXT

    METHODS ADD_LINE
      IMPORTING
        !IV_TEXT  TYPE CSEQUENCE
      CHANGING
        !CT_LINES TYPE TT_LINES .

    METHODS ADD_SECTION
      IMPORTING
        !IV_TITLE TYPE CSEQUENCE
        !IV_COLOR TYPE CSEQUENCE
      CHANGING
        !CT_LINES TYPE TT_LINES .

    METHODS ADD_ROW
      IMPORTING
        !IV_LABEL       TYPE CSEQUENCE
        !IV_VALUE       TYPE CSEQUENCE
        !IV_VALUE_STYLE TYPE CSEQUENCE OPTIONAL
      CHANGING
        !CT_LINES       TYPE TT_LINES .

    METHODS GET_INBOX_URL
      RETURNING
        VALUE(RV_URL) TYPE STRING .

    METHODS FMT_AMOUNT
      IMPORTING
        !IV_AMOUNT     TYPE ANY
        !IV_CURRENCY   TYPE WAERS
      RETURNING
        VALUE(RV_TEXT) TYPE STRING .

    METHODS FMT_DATE
      IMPORTING
        !IV_DATE       TYPE DATS
      RETURNING
        VALUE(RV_TEXT) TYPE STRING .

    METHODS FMT_NUMBER
      IMPORTING
        !IV_VALUE      TYPE ANY
      RETURNING
        VALUE(RV_TEXT) TYPE STRING .

    METHODS ALPHA_OUT
      IMPORTING
        !IV_VALUE      TYPE ANY
      RETURNING
        VALUE(RV_TEXT) TYPE STRING .

    METHODS ESCAPE
      IMPORTING
        !IV_TEXT       TYPE CSEQUENCE
      RETURNING
        VALUE(RV_TEXT) TYPE STRING .

ENDCLASS.



CLASS ZCL_SD_SO_CHG_NOTIFY IMPLEMENTATION.


  METHOD ADD_LINE.

    DATA: LV_REST TYPE STRING,
          LV_PART TYPE STRING,
          LV_CUT  TYPE I,
          LV_CHAR TYPE C LENGTH 1.

    LV_REST = IV_TEXT.

    WHILE STRLEN( LV_REST ) > GC_MAX_LINE.

      LV_CUT = GC_MAX_LINE - 1.
      DO.
        IF LV_CUT <= 0.
          EXIT.
        ENDIF.
        LV_CHAR = LV_REST+LV_CUT(1).
        IF LV_CHAR IS INITIAL.
          EXIT.
        ENDIF.
        LV_CUT = LV_CUT - 1.
      ENDDO.

      IF LV_CUT <= 0.
        LV_CUT = GC_MAX_LINE.
      ENDIF.

      LV_PART = LV_REST(LV_CUT).
      APPEND LV_PART TO CT_LINES.
      LV_REST = LV_REST+LV_CUT.

    ENDWHILE.

    APPEND LV_REST TO CT_LINES.

  ENDMETHOD.


  METHOD ADD_ROW.

    DATA LV_LINE TYPE STRING.

    ADD_LINE( EXPORTING IV_TEXT = `<tr>` CHANGING CT_LINES = CT_LINES ).

    LV_LINE = `<td style="` && GC_TD_LABEL && `">`.
    ADD_LINE( EXPORTING IV_TEXT = LV_LINE   CHANGING CT_LINES = CT_LINES ).
    ADD_LINE( EXPORTING IV_TEXT = IV_LABEL  CHANGING CT_LINES = CT_LINES ).
    ADD_LINE( EXPORTING IV_TEXT = `</td>`   CHANGING CT_LINES = CT_LINES ).

    LV_LINE = `<td style="` && GC_TD_VALUE && IV_VALUE_STYLE && `">`.
    ADD_LINE( EXPORTING IV_TEXT = LV_LINE   CHANGING CT_LINES = CT_LINES ).
    ADD_LINE( EXPORTING IV_TEXT = IV_VALUE  CHANGING CT_LINES = CT_LINES ).
    ADD_LINE( EXPORTING IV_TEXT = `</td>`   CHANGING CT_LINES = CT_LINES ).

    ADD_LINE( EXPORTING IV_TEXT = `</tr>` CHANGING CT_LINES = CT_LINES ).

  ENDMETHOD.


  METHOD ADD_SECTION.

    DATA LV_LINE TYPE STRING.

    LV_LINE = `<h3 style="margin:16px 0 6px 0;font-size:14px;color:` && IV_COLOR && `">`.
    ADD_LINE( EXPORTING IV_TEXT = LV_LINE  CHANGING CT_LINES = CT_LINES ).
    ADD_LINE( EXPORTING IV_TEXT = IV_TITLE CHANGING CT_LINES = CT_LINES ).
    ADD_LINE( EXPORTING IV_TEXT = `</h3>`  CHANGING CT_LINES = CT_LINES ).
    ADD_LINE( EXPORTING IV_TEXT = `<table style="border-collapse:collapse;min-width:460px">`
              CHANGING  CT_LINES = CT_LINES ).

  ENDMETHOD.


  METHOD ALPHA_OUT.

    DATA LV_CHAR TYPE C LENGTH 20.

    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
      EXPORTING
        INPUT  = IV_VALUE
      IMPORTING
        OUTPUT = LV_CHAR.

    RV_TEXT = LV_CHAR.

  ENDMETHOD.


  METHOD BUILD_LINES.

    DATA: LS_HEAD   TYPE ZSD_SO_CHG_LH,
          LT_LEVELS TYPE ZCL_SD_SO_CHG_LOG=>TT_LEVELS,
          LS_LEVEL  TYPE ZSD_SO_CHG_LL,
          LT_EVENTS TYPE ZCL_SD_SO_CHG_LOG=>TT_EVENTS,
          LS_EVENT  TYPE ZSD_SO_CHG_LE,
          LV_TEXT   TYPE STRING,
          LV_LABEL  TYPE STRING,
          LV_STYLE  TYPE STRING,
          LV_COLOR  TYPE STRING,
          LV_URL    TYPE STRING,
          LV_STATUS TYPE CHAR30,
          LV_COUNT  TYPE I.

    CLEAR RT_LINES.
    MV_INBOX = IV_INBOX.

    LS_HEAD   = ZCL_SD_SO_CHG_LOG=>GET_HEADER( IV_LOG_ID ).
    LT_LEVELS = ZCL_SD_SO_CHG_LOG=>GET_LEVELS( IV_LOG_ID ).
    LT_EVENTS = ZCL_SD_SO_CHG_LOG=>GET_EVENTS( IV_LOG_ID ).

    ADD_LINE( EXPORTING IV_TEXT = `<div style="font-family:Arial,Helvetica,sans-serif;font-size:13px;color:#32363a">`
              CHANGING  CT_LINES = RT_LINES ).

    " intro
    IF IV_INTRO IS NOT INITIAL.
      ADD_LINE( EXPORTING IV_TEXT = `<p style="font-size:14px"><b>` CHANGING CT_LINES = RT_LINES ).
      ADD_LINE( EXPORTING IV_TEXT = ESCAPE( IV_INTRO )             CHANGING CT_LINES = RT_LINES ).
      ADD_LINE( EXPORTING IV_TEXT = `</b></p>`                      CHANGING CT_LINES = RT_LINES ).
    ENDIF.

    " sales order
    ADD_SECTION( EXPORTING IV_TITLE = 'Sales order'(001) IV_COLOR = '#0a6ed1'
                 CHANGING  CT_LINES = RT_LINES ).

    ADD_ROW( EXPORTING IV_LABEL = 'Sales order'(001)  IV_VALUE = ALPHA_OUT( LS_HEAD-VBELN )
             CHANGING  CT_LINES = RT_LINES ).
    ADD_ROW( EXPORTING IV_LABEL = 'Contract'(002)     IV_VALUE = ALPHA_OUT( LS_HEAD-CONTRACT )
             CHANGING  CT_LINES = RT_LINES ).

    LV_TEXT = ALPHA_OUT( LS_HEAD-KUNNR ) && ` - ` && ESCAPE( LS_HEAD-CUST_NAME ).
    ADD_ROW( EXPORTING IV_LABEL = 'Customer'(003) IV_VALUE = LV_TEXT
             CHANGING  CT_LINES = RT_LINES ).

    CONCATENATE LS_HEAD-VKORG LS_HEAD-VTWEG LS_HEAD-SPART LS_HEAD-AUART
           INTO LV_TEXT SEPARATED BY ` / `.
    ADD_ROW( EXPORTING IV_LABEL = 'Sales area / Order type'(004) IV_VALUE = LV_TEXT
             CHANGING  CT_LINES = RT_LINES ).

    ADD_ROW( EXPORTING IV_LABEL = 'Net value'(005)
                       IV_VALUE = FMT_AMOUNT( IV_AMOUNT = LS_HEAD-NETWR IV_CURRENCY = LS_HEAD-WAERK )
             CHANGING  CT_LINES = RT_LINES ).

    LV_TEXT = ESCAPE( LS_HEAD-TRIGGER_BY ) && ` - ` && FMT_DATE( LS_HEAD-TRIGGER_ON ).
    ADD_ROW( EXPORTING IV_LABEL = 'Changed by / on'(006) IV_VALUE = LV_TEXT
             CHANGING  CT_LINES = RT_LINES ).

    ADD_ROW( EXPORTING IV_LABEL       = 'Delivery block'(007)
                       IV_VALUE       = ZCL_SD_SO_CHG_MONITOR=>GC_BLOCK
                       IV_VALUE_STYLE = ';color:#bb0000;font-weight:bold'
             CHANGING  CT_LINES = RT_LINES ).

    ADD_LINE( EXPORTING IV_TEXT = `</table>` CHANGING CT_LINES = RT_LINES ).

    " changes (one CHANGE event per changed field)
    ADD_SECTION( EXPORTING IV_TITLE = 'Changes requiring approval'(010) IV_COLOR = '#e9730c'
                 CHANGING  CT_LINES = RT_LINES ).

    LOOP AT LT_EVENTS INTO LS_EVENT WHERE EVENT = ZCL_SD_SO_CHG_LOG=>GC_EVENT-CHANGE.
      LV_COUNT = LV_COUNT + 1.
      ADD_ROW( EXPORTING IV_LABEL = FMT_NUMBER( LV_COUNT )
                         IV_VALUE = ESCAPE( LS_EVENT-TEXT )
               CHANGING  CT_LINES = RT_LINES ).
    ENDLOOP.

    ADD_LINE( EXPORTING IV_TEXT = `</table>` CHANGING CT_LINES = RT_LINES ).

    " approval status
    ADD_SECTION( EXPORTING IV_TITLE = 'Approval status'(030) IV_COLOR = '#32363a'
                 CHANGING  CT_LINES = RT_LINES ).

    LOOP AT LT_LEVELS INTO LS_LEVEL.

      LV_STATUS = ZCL_SD_SO_CHG_LOG=>GET_LEVEL_TEXT( LS_LEVEL-STATUS ).

      CASE LS_LEVEL-STATUS.
        WHEN ZCL_SD_SO_CHG_LOG=>GC_LEVEL-APPROVED. LV_COLOR = '#107e3e'.
        WHEN ZCL_SD_SO_CHG_LOG=>GC_LEVEL-REJECTED. LV_COLOR = '#bb0000'.
        WHEN ZCL_SD_SO_CHG_LOG=>GC_LEVEL-PENDING.  LV_COLOR = '#e9730c'.
        WHEN OTHERS.                               LV_COLOR = '#6a6d70'.
      ENDCASE.

      LV_TEXT = LV_STATUS.
      IF LS_LEVEL-DECIDED_ON IS NOT INITIAL.
        LV_TEXT = LV_TEXT && ` - ` && FMT_DATE( LS_LEVEL-DECIDED_ON ).
      ENDIF.

      LV_STYLE = `;color:` && LV_COLOR && `;font-weight:bold`.
      LV_LABEL = FMT_NUMBER( LS_LEVEL-APPR_LEVEL ) && `. ` && ESCAPE( LS_LEVEL-FULL_NAME ).

      ADD_ROW( EXPORTING IV_LABEL       = LV_LABEL
                         IV_VALUE       = LV_TEXT
                         IV_VALUE_STYLE = LV_STYLE
               CHANGING  CT_LINES = RT_LINES ).

    ENDLOOP.

    ADD_LINE( EXPORTING IV_TEXT = `</table>` CHANGING CT_LINES = RT_LINES ).

    " link to My Inbox (approver e-mail only)
    IF IV_INBOX_LINK = ABAP_TRUE AND IV_INBOX = ABAP_FALSE.
      LV_URL = GET_INBOX_URL( ).
      IF LV_URL IS NOT INITIAL.
        REPLACE ALL OCCURRENCES OF `&` IN LV_URL WITH `&amp;`.
        ADD_LINE( EXPORTING IV_TEXT = `<p style="margin-top:16px">` CHANGING CT_LINES = RT_LINES ).
        CONCATENATE `<a target="_blank" href="` LV_URL `">` INTO LV_TEXT.
        ADD_LINE( EXPORTING IV_TEXT = LV_TEXT CHANGING CT_LINES = RT_LINES ).
        ADD_LINE( EXPORTING IV_TEXT = `<b>` CHANGING CT_LINES = RT_LINES ).
        ADD_LINE( EXPORTING IV_TEXT = 'Open My Inbox to approve or reject'(031)
                  CHANGING  CT_LINES = RT_LINES ).
        ADD_LINE( EXPORTING IV_TEXT = `</b></a></p>` CHANGING CT_LINES = RT_LINES ).
      ENDIF.
    ENDIF.

    ADD_LINE( EXPORTING IV_TEXT = `</div>` CHANGING CT_LINES = RT_LINES ).

    CLEAR MV_INBOX.

  ENDMETHOD.


  METHOD BUILD_INBOX_HTML.

    DATA: LS_HEAD  TYPE ZSD_SO_CHG_LH,
          LV_INTRO TYPE STRING.

    LS_HEAD = ZCL_SD_SO_CHG_LOG=>GET_HEADER( IV_LOG_ID ).

    LV_INTRO = 'Please approve or reject the change of sales order'(056) && ` `
               && ALPHA_OUT( LS_HEAD-VBELN ) && ` (` && 'level'(051) && ` `
               && FMT_NUMBER( IV_LEVEL ) && ` / ` && FMT_NUMBER( LS_HEAD-LEVELS ) && `).`.

    RT_HTML = TO_W3HTML( BUILD_LINES( IV_LOG_ID = IV_LOG_ID
                                      IV_INTRO  = LV_INTRO
                                      IV_INBOX  = ABAP_TRUE ) ).

  ENDMETHOD.


  METHOD ESCAPE.

    DATA LV_IN TYPE STRING.

    LV_IN = IV_TEXT.

    " My Inbox: no '&' at all (&...& would be read as a container variable),
    " so no HTML entities either - replace the special characters directly
    IF MV_INBOX = ABAP_TRUE.
      REPLACE ALL OCCURRENCES OF `->` IN LV_IN WITH `→`.
      REPLACE ALL OCCURRENCES OF `&`  IN LV_IN WITH `+`.
      REPLACE ALL OCCURRENCES OF `<`  IN LV_IN WITH `(`.
      REPLACE ALL OCCURRENCES OF `>`  IN LV_IN WITH `)`.
      REPLACE ALL OCCURRENCES OF `"`  IN LV_IN WITH `'`.
      RV_TEXT = LV_IN.
      RETURN.
    ENDIF.

    RV_TEXT = CL_HTTP_UTILITY=>ESCAPE_HTML( UNESCAPED = LV_IN ).

  ENDMETHOD.


  METHOD FMT_AMOUNT.

    DATA LV_CHAR TYPE C LENGTH 40.

    WRITE IV_AMOUNT TO LV_CHAR CURRENCY IV_CURRENCY.
    CONDENSE LV_CHAR.
    RV_TEXT = LV_CHAR && ` ` && IV_CURRENCY.

  ENDMETHOD.


  METHOD FMT_DATE.

    DATA LV_CHAR TYPE C LENGTH 10.

    CLEAR RV_TEXT.
    IF IV_DATE IS INITIAL.
      RETURN.
    ENDIF.

    WRITE IV_DATE TO LV_CHAR.
    RV_TEXT = LV_CHAR.

  ENDMETHOD.


  METHOD FMT_NUMBER.

    DATA LV_CHAR TYPE C LENGTH 30.

    WRITE IV_VALUE TO LV_CHAR.
    CONDENSE LV_CHAR.
    SHIFT LV_CHAR LEFT DELETING LEADING '0'.
    IF LV_CHAR IS INITIAL.
      LV_CHAR = '0'.
    ENDIF.
    RV_TEXT = LV_CHAR.

  ENDMETHOD.


  METHOD GET_INBOX_URL.

    DATA LV_BASE TYPE STRING.

    IF SY-SYSID = GC_SYSID_PRD.
      LV_BASE = GC_FLP_BASE_PRD.
    ELSE.
      LV_BASE = GC_FLP_BASE.
    ENDIF.

    CONCATENATE LV_BASE `?sap-client=` SY-MANDT GC_INBOX_INTENT
           INTO RV_URL.

  ENDMETHOD.


  METHOD NOTIFY_APPROVER.

    DATA: LS_HEAD    TYPE ZSD_SO_CHG_LH,
          LS_LEVEL   TYPE ZSD_SO_CHG_LL,
          LT_LINES   TYPE TT_LINES,
          LV_INTRO   TYPE STRING,
          LV_SUBJECT TYPE STRING,
          LV_ERROR   TYPE STRING,
          LV_TEXT    TYPE STRING.

    LS_HEAD  = ZCL_SD_SO_CHG_LOG=>GET_HEADER( IV_LOG_ID ).
    LS_LEVEL = ZCL_SD_SO_CHG_LOG=>GET_LEVEL( IV_LOG_ID = IV_LOG_ID IV_LEVEL = IV_LEVEL ).

    LV_INTRO = 'Your approval is needed for the change of sales order'(050) && ` `
               && ALPHA_OUT( LS_HEAD-VBELN ) && ` (` && 'level'(051) && ` `
               && FMT_NUMBER( IV_LEVEL ) && ` / ` && FMT_NUMBER( LS_HEAD-LEVELS ) && `). `
               && 'Please decide in Fiori My Inbox.'(052).

    LV_SUBJECT = 'Change approval'(053) && ` ` && ALPHA_OUT( LS_HEAD-VBELN ) && ` - `
                 && LS_HEAD-CUST_NAME && ` (` && 'level'(051) && ` `
                 && FMT_NUMBER( IV_LEVEL ) && `/` && FMT_NUMBER( LS_HEAD-LEVELS ) && `)`.

    LT_LINES = BUILD_LINES( IV_LOG_ID     = IV_LOG_ID
                            IV_INTRO      = LV_INTRO
                            IV_INBOX_LINK = ABAP_TRUE ).

    IF SEND_MAIL( EXPORTING IV_EMAIL   = LS_LEVEL-EMAIL
                            IV_SUBJECT = LV_SUBJECT
                            IT_LINES   = LT_LINES
                  IMPORTING EV_ERROR   = LV_ERROR ) = ABAP_TRUE.

      LV_TEXT = 'E-mail sent to'(054) && ` ` && LS_LEVEL-EMAIL.
      ZCL_SD_SO_CHG_LOG=>ADD_EVENT( IV_LOG_ID = IV_LOG_ID
                                    IV_EVENT  = ZCL_SD_SO_CHG_LOG=>GC_EVENT-MAIL
                                    IV_LEVEL  = IV_LEVEL
                                    IV_UNAME  = LS_LEVEL-UNAME
                                    IV_TEXT   = LV_TEXT ).
    ELSE.

      LV_TEXT = 'E-mail not sent:'(055) && ` ` && LV_ERROR.
      ZCL_SD_SO_CHG_LOG=>ADD_EVENT( IV_LOG_ID = IV_LOG_ID
                                    IV_EVENT  = ZCL_SD_SO_CHG_LOG=>GC_EVENT-MAIL_ERR
                                    IV_LEVEL  = IV_LEVEL
                                    IV_UNAME  = LS_LEVEL-UNAME
                                    IV_TEXT   = LV_TEXT ).
    ENDIF.

  ENDMETHOD.


  METHOD NOTIFY_REQUESTER.

    DATA: LS_HEAD    TYPE ZSD_SO_CHG_LH,
          LT_LINES   TYPE TT_LINES,
          LV_NAME    TYPE AD_NAMTEXT,
          LV_EMAIL   TYPE AD_SMTPADR,
          LV_RESULT  TYPE STRING,
          LV_INTRO   TYPE STRING,
          LV_SUBJECT TYPE STRING,
          LV_ERROR   TYPE STRING,
          LV_TEXT    TYPE STRING,
          LV_USER    TYPE XUBNAME.

    LS_HEAD = ZCL_SD_SO_CHG_LOG=>GET_HEADER( IV_LOG_ID ).
    LV_USER = LS_HEAD-TRIGGER_BY.

    IF LV_USER IS INITIAL.
      RETURN.
    ENDIF.

    ZCL_SD_SO_CHG_LOG=>GET_USER_DATA( EXPORTING IV_UNAME     = LV_USER
                                      IMPORTING EV_FULL_NAME = LV_NAME
                                                EV_EMAIL     = LV_EMAIL ).

    CASE IV_RESULT.
      WHEN ZCL_SD_SO_CHG_LOG=>GC_STATUS-APPROVED.
        LV_RESULT = 'approved - the delivery block is released'(060).
      WHEN ZCL_SD_SO_CHG_LOG=>GC_STATUS-ERROR.
        LV_RESULT = 'not started - no approver maintained, the order stays blocked'(066).
      WHEN OTHERS.
        LV_RESULT = 'rejected - the order stays blocked'(061).
    ENDCASE.

    LV_INTRO   = 'Your change of sales order'(062) && ` ` && ALPHA_OUT( LS_HEAD-VBELN )
                 && ` ` && 'was'(063) && ` ` && LV_RESULT && `.`.
    LV_SUBJECT = 'Change approval'(053) && ` ` && ALPHA_OUT( LS_HEAD-VBELN ) && `: ` && LV_RESULT.
    LT_LINES   = BUILD_LINES( IV_LOG_ID = IV_LOG_ID IV_INTRO = LV_INTRO ).

    IF SEND_MAIL( EXPORTING IV_EMAIL   = LV_EMAIL
                            IV_SUBJECT = LV_SUBJECT
                            IT_LINES   = LT_LINES
                  IMPORTING EV_ERROR   = LV_ERROR ) = ABAP_TRUE.
      LV_TEXT = 'Result e-mail sent to requester'(064) && ` ` && LV_EMAIL.
      ZCL_SD_SO_CHG_LOG=>ADD_EVENT( IV_LOG_ID = IV_LOG_ID
                                    IV_EVENT  = ZCL_SD_SO_CHG_LOG=>GC_EVENT-MAIL
                                    IV_UNAME  = LV_USER
                                    IV_TEXT   = LV_TEXT ).
    ELSE.
      LV_TEXT = 'Result e-mail not sent:'(065) && ` ` && LV_ERROR.
      ZCL_SD_SO_CHG_LOG=>ADD_EVENT( IV_LOG_ID = IV_LOG_ID
                                    IV_EVENT  = ZCL_SD_SO_CHG_LOG=>GC_EVENT-MAIL_ERR
                                    IV_UNAME  = LV_USER
                                    IV_TEXT   = LV_TEXT ).
    ENDIF.

  ENDMETHOD.


  METHOD SEND_MAIL.

    DATA: LO_SEND     TYPE REF TO CL_BCS,
          LO_DOCUMENT TYPE REF TO CL_DOCUMENT_BCS,
          LO_RECEIVER TYPE REF TO IF_RECIPIENT_BCS,
          LX_BCS      TYPE REF TO CX_BCS,
          LT_BODY     TYPE SOLI_TAB,
          LS_BODY     TYPE SOLI,
          LV_LINE     TYPE STRING,
          LV_SUBJECT  TYPE SO_OBJ_DES,
          LV_LONG     TYPE STRING.

    CLEAR EV_ERROR.
    RV_OK = ABAP_FALSE.

    IF IV_EMAIL IS INITIAL.
      EV_ERROR = 'No e-mail address'(040).
      RETURN.
    ENDIF.

    LS_BODY-LINE = `<html><body>`.
    APPEND LS_BODY TO LT_BODY.
    LOOP AT IT_LINES INTO LV_LINE.
      LS_BODY-LINE = LV_LINE.
      APPEND LS_BODY TO LT_BODY.
    ENDLOOP.
    LS_BODY-LINE = `</body></html>`.
    APPEND LS_BODY TO LT_BODY.

    LV_LONG    = IV_SUBJECT.
    LV_SUBJECT = IV_SUBJECT.

    TRY.
        LO_DOCUMENT = CL_DOCUMENT_BCS=>CREATE_DOCUMENT(
                        I_TYPE    = 'HTM'
                        I_TEXT    = LT_BODY
                        I_SUBJECT = LV_SUBJECT ).

        LO_SEND = CL_BCS=>CREATE_PERSISTENT( ).
        LO_SEND->SET_DOCUMENT( LO_DOCUMENT ).
        LO_SEND->SET_MESSAGE_SUBJECT( LV_LONG ).

        LO_RECEIVER = CL_CAM_ADDRESS_BCS=>CREATE_INTERNET_ADDRESS( IV_EMAIL ).
        LO_SEND->ADD_RECIPIENT( I_RECIPIENT = LO_RECEIVER ).

        LO_SEND->SET_SEND_IMMEDIATELY( ABAP_TRUE ).
        LO_SEND->SEND( ).

        RV_OK = ABAP_TRUE.

      CATCH CX_BCS INTO LX_BCS.
        EV_ERROR = LX_BCS->GET_TEXT( ).
    ENDTRY.

  ENDMETHOD.


  METHOD TO_W3HTML.

    DATA: LV_LINE TYPE STRING,
          LS_HTML TYPE W3HTML.

    CLEAR RT_HTML.

    LOOP AT IT_LINES INTO LV_LINE.
      LS_HTML-LINE = LV_LINE.
      APPEND LS_HTML TO RT_HTML.
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
```

Text symbols:

| Sym | Text | Length |
|-----|------|--------|
| 001 | Sales order | 11 |
| 002 | Contract | 10 |
| 003 | Customer | 10 |
| 004 | Sales area / Order type | 23 |
| 005 | Net value | 10 |
| 006 | Changed by / on | 15 |
| 007 | Delivery block | 14 |
| 010 | Changes requiring approval | 26 |
| 030 | Approval status | 15 |
| 031 | Open My Inbox to approve or reject | 34 |
| 040 | No e-mail address | 17 |
| 050 | Your approval is needed for the change of sales order | 53 |
| 051 | level | 10 |
| 052 | Please decide in Fiori My Inbox. | 32 |
| 053 | Change approval | 15 |
| 054 | E-mail sent to | 14 |
| 055 | E-mail not sent: | 16 |
| 056 | Please approve or reject the change of sales order | 50 |
| 060 | approved - the delivery block is released | 41 |
| 061 | rejected - the order stays blocked | 34 |
| 062 | Your change of sales order | 26 |
| 063 | was | 10 |
| 064 | Result e-mail sent to requester | 31 |
| 065 | Result e-mail not sent: | 23 |
| 066 | not started - no approver maintained, the order stays blocked | 61 |

## 11. Class ZCL_SD_SO_CHG_MONITOR

Purpose: snapshot when VA02 opens, comparison on save, start of the run and the workflow event, and the "in approval" check.

| Method | Called from | Purpose |
|--------|-------------|---------|
| TAKE_SNAPSHOT | USEREXIT_READ_DOCUMENT | Material, quantity, net value, net price and characteristic values per item |
| DETECT_CHANGES | USEREXIT_SAVE_DOCUMENT_PREPARE | Added or deleted items and changed values → change texts |
| SET_APPROVAL_REQUIRED / IS_APPROVAL_REQUIRED | Save prepare / save | Flag between the two exits |
| START_APPROVAL | USEREXIT_SAVE_DOCUMENT | Run + CHANGE events + CLOSE_PREVIOUS + event (update task) |
| IS_APPROVAL_PENDING | Field modification, CUA, CE_C_PROCESSING, read, save prepare | Order in approval (buffered per order) |
| GET_CONFIG_VALUES | Snapshot / detect | Characteristic values as one string (VC_I_GET_CONFIGURATION) |

Constants: `GC_BLOCK = 'XX'` (delivery block), `GC_WF_OBJTYPE = 'ZCL_SD_SO_CHG_WF'`, `GC_WF_EVENT = 'CHANGE_APPROVAL_REQUIRED'`.

```abap
"! <p>SD: VA02 change detection for sales orders with reference to a
"! contract (TSD CH4323, chapter 4-6).</p>
"! <ul>
"! <li>TAKE_SNAPSHOT (USEREXIT_READ_DOCUMENT): values when the order is opened</li>
"! <li>DETECT_CHANGES (USEREXIT_SAVE_DOCUMENT_PREPARE): compare with the snapshot</li>
"! <li>START_APPROVAL (USEREXIT_SAVE_DOCUMENT): workflow log (ZCL_SD_SO_CHG_LOG),
"!     old run closed + old workflow cancelled, workflow event raised in the
"!     update task, so the workflow only starts after a successful save</li>
"! <li>IS_APPROVAL_PENDING: order is in the approval cycle -> VA02 locked</li>
"! </ul>
"! Monitored: Material, Quantity, Net value, Net price, VC characteristic
"! values, items added, items deleted.
CLASS zcl_sd_so_chg_monitor DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Header delivery block for pending approval (TSD: final value to be confirmed)
    CONSTANTS gc_block TYPE vbak-lifsk VALUE 'XX'.

    CONSTANTS gc_wf_objtype TYPE sibftypeid VALUE 'ZCL_SD_SO_CHG_WF'.
    CONSTANTS gc_wf_event   TYPE sibfevent  VALUE 'CHANGE_APPROVAL_REQUIRED'.

    TYPES tt_change TYPE STANDARD TABLE OF string WITH EMPTY KEY.

    CLASS-METHODS take_snapshot
      IMPORTING iv_vbeln TYPE vbak-vbeln
                it_xvbap TYPE va_vbapvb_t.

    CLASS-METHODS detect_changes
      IMPORTING iv_vbeln          TYPE vbak-vbeln
                it_xvbap          TYPE va_vbapvb_t
      RETURNING VALUE(rt_changes) TYPE tt_change.

    CLASS-METHODS set_approval_required
      IMPORTING it_changes TYPE tt_change.

    CLASS-METHODS is_approval_required
      RETURNING VALUE(rv_required) TYPE abap_bool.

    CLASS-METHODS start_approval
      IMPORTING is_vbak TYPE vbak.

    CLASS-METHODS is_approval_pending
      IMPORTING iv_vbeln          TYPE vbak-vbeln
      RETURNING VALUE(rv_pending) TYPE abap_bool.

    "! Characteristic values of a configuration as one comparable string
    CLASS-METHODS get_config_values
      IMPORTING iv_cuobj         TYPE vbap-cuobj
      RETURNING VALUE(rv_values) TYPE string.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_snapshot,
        posnr  TYPE vbap-posnr,
        matnr  TYPE vbap-matnr,
        kwmeng TYPE vbap-kwmeng,
        netwr  TYPE vbap-netwr,
        netpr  TYPE vbap-netpr,
        config TYPE string,
      END OF ty_snapshot.

    CLASS-DATA gt_snapshot       TYPE SORTED TABLE OF ty_snapshot WITH UNIQUE KEY posnr.
    CLASS-DATA gv_snapshot_vbeln TYPE vbak-vbeln.
    CLASS-DATA gt_changes        TYPE tt_change.
    CLASS-DATA gv_required       TYPE abap_bool.
    CLASS-DATA gv_pending_vbeln  TYPE vbak-vbeln.
    CLASS-DATA gv_pending        TYPE abap_bool.
ENDCLASS.


CLASS zcl_sd_so_chg_monitor IMPLEMENTATION.

  METHOD take_snapshot.
    CLEAR: gt_snapshot, gt_changes, gv_required, gv_pending_vbeln, gv_pending.
    gv_snapshot_vbeln = iv_vbeln.

    LOOP AT it_xvbap INTO DATA(ls_item).
      INSERT VALUE #( posnr  = ls_item-posnr
                      matnr  = ls_item-matnr
                      kwmeng = ls_item-kwmeng
                      netwr  = ls_item-netwr
                      netpr  = ls_item-netpr
                      config = get_config_values( ls_item-cuobj ) ) INTO TABLE gt_snapshot.
    ENDLOOP.
  ENDMETHOD.


  METHOD detect_changes.
*   Only compare against a snapshot of the same order
    IF iv_vbeln IS INITIAL OR iv_vbeln <> gv_snapshot_vbeln.
      RETURN.
    ENDIF.

    LOOP AT it_xvbap INTO DATA(ls_item).
      DATA(lv_posnr) = |{ ls_item-posnr ALPHA = OUT }|.

      CASE ls_item-updkz.
        WHEN 'D'.
          APPEND |Item { lv_posnr }: deleted| TO rt_changes.
          CONTINUE.
        WHEN 'I'.
          APPEND |Item { lv_posnr }: added (material { ls_item-matnr ALPHA = OUT })| TO rt_changes.
          CONTINUE.
      ENDCASE.

      READ TABLE gt_snapshot INTO DATA(ls_old) WITH TABLE KEY posnr = ls_item-posnr.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      IF ls_item-matnr <> ls_old-matnr.
        APPEND |Item { lv_posnr }: material { ls_old-matnr ALPHA = OUT } -> { ls_item-matnr ALPHA = OUT }| TO rt_changes.
      ENDIF.
      IF ls_item-kwmeng <> ls_old-kwmeng.
        APPEND |Item { lv_posnr }: quantity { ls_old-kwmeng NUMBER = USER } -> { ls_item-kwmeng NUMBER = USER }| TO rt_changes.
      ENDIF.
      IF ls_item-netwr <> ls_old-netwr.
        APPEND |Item { lv_posnr }: net value { ls_old-netwr NUMBER = USER } -> { ls_item-netwr NUMBER = USER }| TO rt_changes.
      ENDIF.
      IF ls_item-netpr <> ls_old-netpr.
        APPEND |Item { lv_posnr }: net price { ls_old-netpr NUMBER = USER } -> { ls_item-netpr NUMBER = USER }| TO rt_changes.
      ENDIF.
      IF ls_item-cuobj IS NOT INITIAL
     AND get_config_values( ls_item-cuobj ) <> ls_old-config.
        APPEND |Item { lv_posnr }: characteristic values changed| TO rt_changes.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD set_approval_required.
    gt_changes  = it_changes.
    gv_required = abap_true.
  ENDMETHOD.


  METHOD is_approval_required.
    rv_required = gv_required.
  ENDMETHOD.


  METHOD start_approval.
    DATA ls_header TYPE zsd_so_chg_lh.
    DATA lo_container TYPE REF TO if_swf_ifs_parameter_container.

    IF gv_required = abap_false OR is_vbak-vbeln IS INITIAL.
      RETURN.
    ENDIF.

    ls_header-vbeln       = is_vbak-vbeln.
    ls_header-contract    = is_vbak-vgbel.
    ls_header-auart       = is_vbak-auart.
    ls_header-vkorg       = is_vbak-vkorg.
    ls_header-vtweg       = is_vbak-vtweg.
    ls_header-spart       = is_vbak-spart.
    ls_header-kunnr       = is_vbak-kunnr.
    ls_header-netwr       = is_vbak-netwr.
    ls_header-waerk       = is_vbak-waerk.
    ls_header-change_text = concat_lines_of( table = gt_changes sep = `; ` ).
    ls_header-trigger_evt = gc_wf_event.
    ls_header-trigger_by  = sy-uname.
    ls_header-trigger_on  = sy-datum.
    ls_header-trigger_at  = sy-uzeit.
    SELECT SINGLE name1 FROM kna1 WHERE kunnr = @is_vbak-kunnr INTO @ls_header-cust_name.

*   New run: header + one level row per approver of ZSD_SO_APPR_CFG
    DATA(lv_log_id) = zcl_sd_so_chg_log=>create_log(
                        is_header   = ls_header
                        it_approver = zcl_sd_so_chg_log=>get_approvers( iv_vkorg = is_vbak-vkorg
                                                                        iv_auart = is_vbak-auart ) ).
    IF lv_log_id IS INITIAL.
      RETURN.
    ENDIF.

*   One CHANGE event per changed field (shown in the e-mail and the log report)
    LOOP AT gt_changes INTO DATA(lv_change).
      zcl_sd_so_chg_log=>add_event( iv_log_id = lv_log_id
                                    iv_event  = zcl_sd_so_chg_log=>gc_event-change
                                    iv_uname  = sy-uname
                                    iv_text   = lv_change ).
    ENDLOOP.

*   Older run still in process (change by BAPI / IDoc while VA02 is locked):
*   close it and cancel (kill) its workflow
    zcl_sd_so_chg_log=>close_previous( iv_vbeln      = is_vbak-vbeln
                                       iv_new_log_id = lv_log_id
                                       iv_user       = sy-uname ).

*   Workflow event with LOG_ID, raised in the update task = only after a
*   successful save. One event per save, however many fields changed.
    TRY.
        lo_container = cl_swf_evt_event=>get_event_container(
                         im_objcateg = cl_swf_evt_event=>mc_objcateg_cl
                         im_objtype  = gc_wf_objtype
                         im_event    = gc_wf_event ).
        lo_container->set( name = 'LOG_ID' value = lv_log_id ).

        cl_swf_evt_event=>raise_in_update_task(
          im_objcateg        = cl_swf_evt_event=>mc_objcateg_cl
          im_objtype         = gc_wf_objtype
          im_event           = gc_wf_event
          im_objkey          = CONV #( is_vbak-vbeln )
          im_event_container = lo_container ).
      CATCH cx_root INTO DATA(lx_event).
        zcl_sd_so_chg_log=>add_event( iv_log_id = lv_log_id
                                      iv_event  = zcl_sd_so_chg_log=>gc_event-error
                                      iv_text   = lx_event->get_text( ) ).
    ENDTRY.

    CLEAR: gt_changes, gv_required.
    gv_pending_vbeln = is_vbak-vbeln.
    gv_pending       = abap_true.
  ENDMETHOD.


  METHOD is_approval_pending.
    IF iv_vbeln IS INITIAL.
      RETURN.
    ENDIF.

    IF iv_vbeln <> gv_pending_vbeln.
      gv_pending_vbeln = iv_vbeln.
      gv_pending       = zcl_sd_so_chg_log=>is_running( iv_vbeln ).
    ENDIF.

    rv_pending = gv_pending.
  ENDMETHOD.


  METHOD get_config_values.
    DATA lt_conf TYPE STANDARD TABLE OF conf_out.

    IF iv_cuobj IS INITIAL.
      RETURN.
    ENDIF.

    CALL FUNCTION 'VC_I_GET_CONFIGURATION'
      EXPORTING
        instance           = iv_cuobj
        language           = sy-langu
      TABLES
        configuration      = lt_conf
      EXCEPTIONS
        instance_not_found = 1
        internal_error     = 2
        OTHERS             = 3.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SORT lt_conf BY atnam atwrt.
    LOOP AT lt_conf INTO DATA(ls_conf).
      rv_values = |{ rv_values }{ ls_conf-atnam }={ ls_conf-atwrt };|.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
```

## 12. Class ZCL_SD_SO_CHG_WF (workflow object)

- Interface **IF_WORKFLOW**, with BI_OBJECT and BI_PERSISTENT. Key = sales order (VBELN).
- Event **CHANGE_APPROVAL_REQUIRED** with parameter **LOG_ID** (SYSUUID_C32).
- In SE24: tab *Events* → `CHANGE_APPROVAL_REQUIRED`, type *Instance*, parameter `LOG_ID` type SYSUUID_C32, pass by value.

| Method | Workflow step | Import | Export | Exception |
|--------|---------------|--------|--------|-----------|
| START | 1 | IV_LOG_ID, IV_WF_ID (optional) | EV_LEVELS | – |
| PREPARE_LEVEL | 3.1 | IV_LOG_ID, IV_INDEX | EV_LEVEL, ET_AGENTS | – |
| DECIDE | 3.3 / 3.4 | IV_LOG_ID, IV_LEVEL, IV_APPROVED, IV_DECIDED_BY | – | – |
| FINISH_APPROVED | 4 (false) | IV_LOG_ID | – | CX_BO_TEMPORARY (retry) |
| FINISH_REJECTED | 4 (true) | IV_LOG_ID | – | – |

```abap
*&---------------------------------------------------------------------*
*& Class          : ZCL_SD_SO_CHG_WF
*& Workflow       : ZSD_SO_CHG_APPR (WS9xxxxxxx)
*& Package        : ZSD
*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : <Functional consultant>
*&---------------------------------------------------------------------*
*& Purpose        : Workflow object (IF_WORKFLOW) of the sales order
*&                  change approval (CH4323). Key = sales order.
*&                  Event CHANGE_APPROVAL_REQUIRED (parameter LOG_ID)
*&                  starts the workflow; every background step calls one
*&                  method of this class.
*& Note           : No COMMIT WORK here; the workflow step commits.
*&---------------------------------------------------------------------*
*& Created By     : Hassan Diab
*& Created On     : 06.10.2026
*& Request No.    : <Request>
*& Version        : 1.0
*&---------------------------------------------------------------------*
*& Change History
*&---------------------------------------------------------------------*
*& Ver | Date       | Author        | Request No.  | Description
*&-----|------------|---------------|--------------|--------------------
*& 1.0 | 06.10.2026 | Hassan Diab   | <Request>    | Initial Creation
*&---------------------------------------------------------------------*
CLASS zcl_sd_so_chg_wf DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_workflow.

    EVENTS change_approval_required
      EXPORTING VALUE(log_id) TYPE sysuuid_c32.

    DATA vbeln TYPE vbak-vbeln READ-ONLY.

    METHODS constructor
      IMPORTING iv_vbeln TYPE vbak-vbeln.

    "! Step 1: store the workflow ID, log START, return the number of levels.
    "! No level maintained -> run ends with status E, order stays blocked.
    METHODS start
      IMPORTING iv_log_id TYPE sysuuid_c32
                iv_wf_id  TYPE sww_wiid OPTIONAL
      EXPORTING ev_levels TYPE i.

    "! Loop step: level at position IV_INDEX -> pending, e-mail to the
    "! approver, agent and HTML description for the decision step
    METHODS prepare_level
      IMPORTING iv_log_id TYPE sysuuid_c32
                iv_index  TYPE i
      EXPORTING ev_level  TYPE zsd_so_level
                et_agents TYPE tswhactor
                et_html   TYPE w3htmltab.

    "! After the user decision: level approved / rejected
    METHODS decide
      IMPORTING iv_log_id     TYPE sysuuid_c32
                iv_level      TYPE zsd_so_level
                iv_approved   TYPE abap_bool
                iv_decided_by TYPE xubname OPTIONAL.

    "! All levels approved: remove delivery block, close run, mail requester
    METHODS finish_approved
      IMPORTING iv_log_id TYPE sysuuid_c32
      RAISING   cx_bo_temporary.

    "! Rejected: order stays blocked, close run, mail requester
    METHODS finish_rejected
      IMPORTING iv_log_id TYPE sysuuid_c32.

  PRIVATE SECTION.
    DATA ms_lpor TYPE sibflpor.

    METHODS find_running_workflow
      RETURNING VALUE(rv_wf_id) TYPE sww_wiid.
ENDCLASS.


CLASS zcl_sd_so_chg_wf IMPLEMENTATION.

  METHOD constructor.
    vbeln   = iv_vbeln.
    ms_lpor = VALUE #( instid = iv_vbeln
                       typeid = zcl_sd_so_chg_monitor=>gc_wf_objtype
                       catid  = 'CL' ).
  ENDMETHOD.


  METHOD bi_persistent~find_by_lpor.
    result = NEW zcl_sd_so_chg_wf( CONV #( lpor-instid ) ).
  ENDMETHOD.


  METHOD bi_persistent~lpor.
    result = ms_lpor.
  ENDMETHOD.


  METHOD bi_persistent~refresh.
  ENDMETHOD.


  METHOD bi_object~default_attribute_value.
    result = REF #( vbeln ).
  ENDMETHOD.


  METHOD bi_object~execute_default_method.
*   Work item "display object": open the order in VA03
    SET PARAMETER ID 'AUN' FIELD vbeln.
    CALL TRANSACTION 'VA03' WITH AUTHORITY-CHECK AND SKIP FIRST SCREEN.
  ENDMETHOD.


  METHOD bi_object~release.
  ENDMETHOD.


  METHOD start.
    CLEAR ev_levels.

    DATA(lv_wf_id) = iv_wf_id.
    IF lv_wf_id IS INITIAL.
      lv_wf_id = find_running_workflow( ).
    ENDIF.
    zcl_sd_so_chg_log=>set_wf_id( iv_log_id = iv_log_id iv_wf_id = lv_wf_id ).

    zcl_sd_so_chg_log=>add_event( iv_log_id = iv_log_id
                                  iv_event  = zcl_sd_so_chg_log=>gc_event-start
                                  iv_text   = |Workflow { lv_wf_id ALPHA = OUT } started| ).

    ev_levels = lines( zcl_sd_so_chg_log=>get_levels( iv_log_id ) ).

    IF ev_levels = 0.
      zcl_sd_so_chg_log=>add_event( iv_log_id = iv_log_id
                                    iv_event  = zcl_sd_so_chg_log=>gc_event-error
                                    iv_text   = 'No approver maintained in ZSD_SO_APPR_CFG - order stays blocked' ).
      zcl_sd_so_chg_log=>finish( iv_log_id = iv_log_id
                                 iv_status = zcl_sd_so_chg_log=>gc_status-error ).
      NEW zcl_sd_so_chg_notify( )->notify_requester( iv_log_id = iv_log_id
                                                      iv_result = zcl_sd_so_chg_log=>gc_status-error ).
    ENDIF.
  ENDMETHOD.


  METHOD prepare_level.
    CLEAR: ev_level, et_agents, et_html.

    DATA(lt_levels) = zcl_sd_so_chg_log=>get_levels( iv_log_id ).
    READ TABLE lt_levels INTO DATA(ls_level) INDEX iv_index.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    ev_level  = ls_level-appr_level.
    et_agents = VALUE #( ( otype = 'US' objid = ls_level-uname ) ).

    zcl_sd_so_chg_log=>set_current_level( iv_log_id = iv_log_id iv_level = ev_level ).
    zcl_sd_so_chg_log=>set_level_status( iv_log_id = iv_log_id
                                         iv_level  = ev_level
                                         iv_status = zcl_sd_so_chg_log=>gc_level-pending ).
    zcl_sd_so_chg_log=>add_event( iv_log_id = iv_log_id
                                  iv_event  = zcl_sd_so_chg_log=>gc_event-level
                                  iv_level  = ev_level
                                  iv_uname  = ls_level-uname
                                  iv_text   = ls_level-full_name ).

*   E-mail (Outlook): work item waiting in Fiori My Inbox
    DATA(lo_notify) = NEW zcl_sd_so_chg_notify( ).
    lo_notify->notify_approver( iv_log_id = iv_log_id
                                iv_level  = ev_level ).

*   Same content as HTML description of the decision work item (My Inbox)
    et_html = lo_notify->build_inbox_html( iv_log_id = iv_log_id
                                           iv_level  = ev_level ).

    zcl_sd_so_chg_log=>add_event( iv_log_id = iv_log_id
                                  iv_event  = zcl_sd_so_chg_log=>gc_event-inbox
                                  iv_level  = ev_level
                                  iv_uname  = ls_level-uname ).
  ENDMETHOD.


  METHOD decide.
    DATA(lv_status) = COND zsd_so_wf_status( WHEN iv_approved = abap_true
                                             THEN zcl_sd_so_chg_log=>gc_level-approved
                                             ELSE zcl_sd_so_chg_log=>gc_level-rejected ).
    DATA(lv_event)  = COND zsd_so_wf_event( WHEN iv_approved = abap_true
                                            THEN zcl_sd_so_chg_log=>gc_event-approve
                                            ELSE zcl_sd_so_chg_log=>gc_event-reject ).

    zcl_sd_so_chg_log=>set_level_status( iv_log_id = iv_log_id
                                         iv_level  = iv_level
                                         iv_status = lv_status
                                         iv_uname  = iv_decided_by ).
    zcl_sd_so_chg_log=>add_event( iv_log_id = iv_log_id
                                  iv_event  = lv_event
                                  iv_level  = iv_level
                                  iv_uname  = iv_decided_by ).
  ENDMETHOD.


  METHOD finish_approved.
    DATA ls_header_in  TYPE bapisdh1.
    DATA ls_header_inx TYPE bapisdh1x.
    DATA lt_return     TYPE STANDARD TABLE OF bapiret2.

*   Sales order of this run: from the log header (independent of the
*   object binding of the workflow step); instance key only as fallback
    DATA(ls_head)  = zcl_sd_so_chg_log=>get_header( iv_log_id ).
    DATA(lv_vbeln) = COND vbak-vbeln( WHEN ls_head-vbeln IS NOT INITIAL
                                      THEN ls_head-vbeln
                                      ELSE vbeln ).
    IF lv_vbeln IS INITIAL.
      zcl_sd_so_chg_log=>add_event( iv_log_id = iv_log_id
                                    iv_event  = zcl_sd_so_chg_log=>gc_event-rel_err
                                    iv_text   = 'Sales order number not found in log header - release not possible' ).
      RETURN.
    ENDIF.

*   Release only after the LAST level: every level of the run must be approved
    DATA(lt_levels) = zcl_sd_so_chg_log=>get_levels( iv_log_id ).
    IF lt_levels IS INITIAL
    OR line_exists( lt_levels[ status = zcl_sd_so_chg_log=>gc_level-waiting ] )
    OR line_exists( lt_levels[ status = zcl_sd_so_chg_log=>gc_level-pending ] )
    OR line_exists( lt_levels[ status = zcl_sd_so_chg_log=>gc_level-rejected ] )
    OR line_exists( lt_levels[ status = zcl_sd_so_chg_log=>gc_level-not_reached ] ).
      zcl_sd_so_chg_log=>add_event( iv_log_id = iv_log_id
                                    iv_event  = zcl_sd_so_chg_log=>gc_event-error
                                    iv_text   = 'Release refused: not all levels approved - order stays blocked' ).
      RETURN.
    ENDIF.

*   Close the run first: the order save of the BAPI below must not see a
*   running approval (otherwise the block would be set again)
    zcl_sd_so_chg_log=>finish( iv_log_id = iv_log_id
                               iv_status = zcl_sd_so_chg_log=>gc_status-approved ).

    ls_header_in-dlv_block   = space.
    ls_header_inx-updateflag = 'U'.
    ls_header_inx-dlv_block  = abap_true.

    CALL FUNCTION 'BAPI_SALESORDER_CHANGE'
      EXPORTING
        salesdocument    = lv_vbeln
        order_header_in  = ls_header_in
        order_header_inx = ls_header_inx
      TABLES
        return           = lt_return.

    LOOP AT lt_return INTO DATA(ls_return) WHERE type CA 'EA'.
      EXIT.
    ENDLOOP.
    IF sy-subrc = 0.
*     e.g. order locked: undo, log, temporary error -> workflow retries
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      zcl_sd_so_chg_log=>add_event( iv_log_id = iv_log_id
                                    iv_event  = zcl_sd_so_chg_log=>gc_event-rel_err
                                    iv_text   = ls_return-message ).
      RAISE EXCEPTION TYPE cx_bo_temporary.
    ENDIF.
*   COMMIT WORK is done by the workflow runtime after the background step

    zcl_sd_so_chg_log=>add_event( iv_log_id = iv_log_id
                                  iv_event  = zcl_sd_so_chg_log=>gc_event-release
                                  iv_text   = |Delivery block { zcl_sd_so_chg_monitor=>gc_block } removed| ).

    NEW zcl_sd_so_chg_notify( )->notify_requester( iv_log_id = iv_log_id
                                                    iv_result = zcl_sd_so_chg_log=>gc_status-approved ).
  ENDMETHOD.


  METHOD finish_rejected.
    zcl_sd_so_chg_log=>add_event( iv_log_id = iv_log_id
                                  iv_event  = zcl_sd_so_chg_log=>gc_event-close
                                  iv_text   = |Delivery block { zcl_sd_so_chg_monitor=>gc_block } remains| ).
    zcl_sd_so_chg_log=>finish( iv_log_id = iv_log_id
                               iv_status = zcl_sd_so_chg_log=>gc_status-rejected ).

    NEW zcl_sd_so_chg_notify( )->notify_requester( iv_log_id = iv_log_id
                                                    iv_result = zcl_sd_so_chg_log=>gc_status-rejected ).
  ENDMETHOD.


  METHOD find_running_workflow.
    DATA lt_worklist TYPE STANDARD TABLE OF swr_wihdr.

*   Newest running top-level workflow of this order = the current one
    CALL FUNCTION 'SAP_WAPI_WORKITEMS_TO_OBJECT'
      EXPORTING
        object_por      = ms_lpor
        top_level_items = abap_true
      TABLES
        worklist        = lt_worklist.

    DELETE lt_worklist WHERE wi_type <> 'F'
                          OR wi_stat = 'COMPLETED'
                          OR wi_stat = 'CANCELLED'.
    SORT lt_worklist BY wi_id DESCENDING.
    READ TABLE lt_worklist INTO DATA(ls_wi) INDEX 1.
    IF sy-subrc = 0.
      rv_wf_id = ls_wi-wi_id.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
```

Activate the four classes together now (steps 9–12).

## 13. Enhancement ZSD_SO_CHG_SNAPSHOT – USEREXIT_READ_DOCUMENT

1. SE38 → `MV45AFZZ` → FORM `USEREXIT_READ_DOCUMENT`.
2. *Edit → Enhancement Operations → Show Implicit Enhancement Options*.
3. Right-click the option at the **end** of the FORM (before `ENDFORM`) → *Enhancement Implementation → Create* → Code → `ZSD_SO_CHG_SNAPSHOT`.
4. Paste the code, activate.

```abap
*&---------------------------------------------------------------------*
*& Include MV45AFZZ - FORM USEREXIT_READ_DOCUMENT          (VA02)
*& Implicit enhancement at the END of the FORM.
*&
*& Takes a snapshot of the monitored values when the order is opened in
*& change mode: Material, Quantity, Net value, Net price and the
*& characteristic values of each item. USEREXIT_SAVE_DOCUMENT_PREPARE
*& compares against this snapshot.
*& Only for orders with reference to a contract that match the VA02
*& filter (ZSD_SO_CON_FLT, process VA02 or BOTH).
*& If the order is in the approval cycle, the user is told that the order
*& is locked (all fields are closed by USEREXIT_FIELD_MODIFICATION).
*&---------------------------------------------------------------------*
ENHANCEMENT 1 zsd_so_chg_snapshot.

  IF t180-trtyp = 'V'                                         " change (VA02)
     AND vbak-vgbel IS NOT INITIAL
     AND vbak-vgtyp = zcl_sd_so_contract_ctrl=>gc_vgtyp_contract
     AND zcl_sd_so_contract_ctrl=>is_relevant(
           is_vbak    = vbak
           iv_process = zcl_sd_so_contract_ctrl=>gc_process-change ) = abap_true.
    zcl_sd_so_chg_monitor=>take_snapshot( iv_vbeln = vbak-vbeln
                                          it_xvbap = xvbap[] ).

    IF zcl_sd_so_chg_monitor=>is_approval_pending( vbak-vbeln ) = abap_true.
      MESSAGE s398(00) WITH 'Order' vbak-vbeln
                            'is in the approval workflow - display only' ''.
    ENDIF.
  ENDIF.

ENDENHANCEMENT.
```

## 14. Enhancement ZSD_SO_CHG_DETECT – USEREXIT_SAVE_DOCUMENT_PREPARE

MV45AFZZ → FORM `USEREXIT_SAVE_DOCUMENT_PREPARE` → implicit enhancement at the **start** → `ZSD_SO_CHG_DETECT`.

```abap
*&---------------------------------------------------------------------*
*& Include MV45AFZZ - FORM USEREXIT_SAVE_DOCUMENT_PREPARE  (VA02)
*& Implicit enhancement at the START of the FORM.
*&
*& TSD 4.4 / 5:
*&   - Compare the order with the snapshot taken when it was opened.
*&   - At least one monitored change -> header delivery block XX and
*&     "approval required" (one approval per save, however many fields).
*&   - No monitored change but an approval is still pending -> keep the
*&     delivery block (it cannot be removed manually while pending).
*& No error message: the save always goes through.
*&---------------------------------------------------------------------*
ENHANCEMENT 1 zsd_so_chg_detect.

  IF t180-trtyp = 'V'                                         " change (VA02)
     AND vbak-vgbel IS NOT INITIAL
     AND vbak-vgtyp = zcl_sd_so_contract_ctrl=>gc_vgtyp_contract
     AND zcl_sd_so_contract_ctrl=>is_relevant(
           is_vbak    = vbak
           iv_process = zcl_sd_so_contract_ctrl=>gc_process-change ) = abap_true.

    DATA(lt_zz_changes) = zcl_sd_so_chg_monitor=>detect_changes( iv_vbeln = vbak-vbeln
                                                                 it_xvbap = xvbap[] ).
    IF lt_zz_changes IS NOT INITIAL.
      vbak-lifsk = zcl_sd_so_chg_monitor=>gc_block.
      zcl_sd_so_chg_monitor=>set_approval_required( lt_zz_changes ).
    ELSEIF zcl_sd_so_chg_monitor=>is_approval_pending( vbak-vbeln ) = abap_true.
      vbak-lifsk = zcl_sd_so_chg_monitor=>gc_block.
    ENDIF.
  ENDIF.

ENDENHANCEMENT.
```

## 15. Enhancement ZSD_SO_CHG_START_WF – USEREXIT_SAVE_DOCUMENT

MV45AFZZ → FORM `USEREXIT_SAVE_DOCUMENT` → implicit enhancement at the **start** → `ZSD_SO_CHG_START_WF`.

```abap
*&---------------------------------------------------------------------*
*& Include MV45AFZZ - FORM USEREXIT_SAVE_DOCUMENT          (VA02)
*& Implicit enhancement at the START of the FORM.
*&
*& Called during the save, before COMMIT WORK (same LUW as the order):
*&   - creates the workflow log run (ZSD_SO_CHG_LH/LL/LE, status P) with
*&     one CHANGE event per changed field
*&   - closes an older run of the same order (status F) and cancels its
*&     workflow
*&   - raises event CHANGE_APPROVAL_REQUIRED (LOG_ID) of ZCL_SD_SO_CHG_WF
*&     in the update task -> workflow ZSD_SO_CHG_APPR starts only after
*&     the order was saved successfully. One event per save.
*&---------------------------------------------------------------------*
ENHANCEMENT 1 zsd_so_chg_start_wf.

  IF t180-trtyp = 'V'                                         " change (VA02)
     AND zcl_sd_so_chg_monitor=>is_approval_required( ) = abap_true.
    zcl_sd_so_chg_monitor=>start_approval( vbak ).
  ENDIF.

ENDENHANCEMENT.
```

## 16. Update of the Part 1 enhancements (order locked while in approval)

Replace the code of the three existing enhancement implementations with the versions below. The VA01 logic is unchanged; the VA02 part is new.

### 16.1 ZSD_SO_CON_FIELD_LOCK – MV45AFZZ USEREXIT_FIELD_MODIFICATION

All input fields are closed in VA02 while the order is in approval.

```abap
*&---------------------------------------------------------------------*
*& Include MV45AFZZ - FORM USEREXIT_FIELD_MODIFICATION
*& Implicit enhancement at the start of the FORM (replaces the test
*& coding with the hard-coded COBL-PRCTR / sy-tcode check).
*&
*& Logic (TSD CH4323, 3.1 / 3.2):
*&   - Sales order in create mode (VA01)
*&   - VBAK-VGBEL is not initial and VBAK-VGTYP = 'G' (ref. to contract)
*&   - Active filter lines of process VA01 in ZSD_SO_CON_FLT whose ranges
*&       contain VKORG / VTWEG / SPART / AUART_SO (= VBAK-AUART)
*&       / AUART_CON (= VBAK-AUART of the referenced contract)
*&       (a field without lines is not restricted)
*&   => close Material / Quantity / Net value fields for input
*& VA02: while the order is in the approval cycle (workflow log status P)
*&   the whole order is closed for change (all fields display-only,
*&   delivery block included).
*&---------------------------------------------------------------------*
ENHANCEMENT 1 ZSD_SO_CON_FIELD_LOCK.    "active version
*
  CONSTANTS LC_ZZ_OFF TYPE C LENGTH 1 VALUE '0'.

  CASE T180-TRTYP.
    WHEN 'H'.                                                 " create (VA01)
      IF  ZCL_SD_SO_CONTRACT_CTRL=>IS_LOCKED_FIELD( SCREEN-NAME ) = ABAP_TRUE
      AND VBAK-VGBEL IS NOT INITIAL
      AND VBAK-VGTYP = ZCL_SD_SO_CONTRACT_CTRL=>GC_VGTYP_CONTRACT
      AND ZCL_SD_SO_CONTRACT_CTRL=>IS_RELEVANT(
            IS_VBAK    = VBAK
            IV_PROCESS = ZCL_SD_SO_CONTRACT_CTRL=>GC_PROCESS-CREATE ) = ABAP_TRUE.
        SCREEN-INPUT = LC_ZZ_OFF.
        MODIFY SCREEN.
      ENDIF.
    WHEN 'V'.                                                 " change (VA02)
      IF  SCREEN-INPUT = '1'
      AND ZCL_SD_SO_CHG_MONITOR=>IS_APPROVAL_PENDING( VBAK-VBELN ) = ABAP_TRUE.
        SCREEN-INPUT = LC_ZZ_OFF.
        MODIFY SCREEN.
      ENDIF.
  ENDCASE.

ENDENHANCEMENT.
```

### 16.2 ZSD_SO_CON_ITEM_FCODES – FORM CUA_SETZEN

Insert Row / Delete Item are removed in VA02 while the order is in approval.

```abap
*&---------------------------------------------------------------------*
*& SAPMV45A - FORM CUA_SETZEN   (include MV45AF0C_CUA_SETZEN)
*& Implicit enhancement at the END of the FORM.
*&
*& Removes the item functions "Insert Row" (POAN) and "Delete Item"
*& (POLO) from the GUI status in VA01 for relevant orders, like VA03
*& (codes in ZCL_SD_SO_CONTRACT_CTRL=>GC_FCODE), and in VA02 while the
*& order is in the approval cycle.
*& Excluded function codes also make the matching pushbuttons above the
*& item table inactive (greyed out) and remove the menu entries.
*&
*& CUA_EXCLUDE is the exclusion table that SAPMV45A passes to
*& SET PF-STATUS ... EXCLUDING. Check the name in your release:
*& in the debugger, set a breakpoint on statement SET PF-STATUS.
*&---------------------------------------------------------------------*
ENHANCEMENT 1 ZSD_SO_CON_ITEM_FCODES.    "active version
*
  DATA LV_ZZ_LOCK TYPE ABAP_BOOL.

  CLEAR LV_ZZ_LOCK.

  CASE T180-TRTYP.
    WHEN 'H'.                                                 " create (VA01)
      IF  VBAK-VGBEL IS NOT INITIAL
      AND VBAK-VGTYP = ZCL_SD_SO_CONTRACT_CTRL=>GC_VGTYP_CONTRACT
      AND ZCL_SD_SO_CONTRACT_CTRL=>IS_RELEVANT(
            IS_VBAK    = VBAK
            IV_PROCESS = ZCL_SD_SO_CONTRACT_CTRL=>GC_PROCESS-CREATE ) = ABAP_TRUE.
        LV_ZZ_LOCK = ABAP_TRUE.
      ENDIF.
    WHEN 'V'.                                                 " change (VA02)
      IF ZCL_SD_SO_CHG_MONITOR=>IS_APPROVAL_PENDING( VBAK-VBELN ) = ABAP_TRUE.
        LV_ZZ_LOCK = ABAP_TRUE.
      ENDIF.
  ENDCASE.

  IF LV_ZZ_LOCK = ABAP_TRUE.
    DATA(LT_ZZ_FCODES) = ZCL_SD_SO_CONTRACT_CTRL=>GET_LOCKED_FCODES( ).
    LOOP AT LT_ZZ_FCODES INTO DATA(LV_ZZ_FCODE).
      CUA_EXCLUDE = LV_ZZ_FCODE.
      COLLECT CUA_EXCLUDE.
    ENDLOOP.
  ENDIF.

ENDENHANCEMENT.
```

### 16.3 ZSD_SO_CON_CONFIG_DISPLAY – FM CE_C_PROCESSING

The configuration is display-only in VA02 while the order is in approval.

```abap
*&---------------------------------------------------------------------*
*& Function module CE_C_PROCESSING (function group CUKO, SAPLCUKO)
*& Implicit enhancement at the START of the function module.
*&
*& Call path in VA01 (item configuration):
*&   SAPMV45A FCODE_POCO -> SAPFV45S CONFIGURATION_FCODE/_PROCESSING
*&   -> FM V45CU_CONFIGURATION -> FM CE_C_PROCESSING (parameter DISPLAY)
*&
*& Sets DISPLAY = 'X' when the configuration is called from a sales order
*& in VA01 (create) with reference to a contract that matches the VA01
*& filter. The characteristic value assignment then opens display-only,
*& as in VA03. Same in VA02 while the order is in the approval cycle.
*& Any other caller (other transactions, other orders) is not affected.
*&
*& The order data is read from SAPMV45A with a dynamic ASSIGN, because
*& the function module has no access to the sales order globals.
*& Requirement: DISPLAY is passed by value (SE37 > CE_C_PROCESSING >
*& Import tab > "Pass Value" ticked). Otherwise the assignment is
*& rejected by the syntax check (see creation guide step 9d).
*&---------------------------------------------------------------------*
ENHANCEMENT 1 ZSD_SO_CON_CONFIG_DISPLAY.    "active version
*
  FIELD-SYMBOLS: <LS_ZZ_VBAK>  TYPE VBAK,
                 <LV_ZZ_TRTYP> TYPE T180-TRTYP.

  DATA LV_ZZ_DISPLAY TYPE ABAP_BOOL.

  CLEAR LV_ZZ_DISPLAY.

  " sales order data (only assigned when called from SAPMV45A)
  ASSIGN ('(SAPMV45A)VBAK')       TO <LS_ZZ_VBAK>.
  ASSIGN ('(SAPMV45A)T180-TRTYP') TO <LV_ZZ_TRTYP>.

  IF <LS_ZZ_VBAK> IS ASSIGNED AND <LV_ZZ_TRTYP> IS ASSIGNED.

    CASE <LV_ZZ_TRTYP>.
      WHEN 'H'.                                               " create (VA01)
        IF  <LS_ZZ_VBAK>-VGBEL IS NOT INITIAL
        AND <LS_ZZ_VBAK>-VGTYP = ZCL_SD_SO_CONTRACT_CTRL=>GC_VGTYP_CONTRACT
        AND ZCL_SD_SO_CONTRACT_CTRL=>IS_RELEVANT(
              IS_VBAK    = <LS_ZZ_VBAK>
              IV_PROCESS = ZCL_SD_SO_CONTRACT_CTRL=>GC_PROCESS-CREATE ) = ABAP_TRUE.
          LV_ZZ_DISPLAY = ABAP_TRUE.
        ENDIF.
      WHEN 'V'.                                               " change (VA02)
        IF ZCL_SD_SO_CHG_MONITOR=>IS_APPROVAL_PENDING( <LS_ZZ_VBAK>-VBELN ) = ABAP_TRUE.
          LV_ZZ_DISPLAY = ABAP_TRUE.
        ENDIF.
    ENDCASE.

  ENDIF.

  IF LV_ZZ_DISPLAY = ABAP_TRUE.
    DISPLAY = ABAP_TRUE.                                      " as VA03
  ENDIF.

ENDENHANCEMENT.
```

## 17. Workflow tasks (PFTC)

The approval process has six steps that do work. **Five of them are background tasks**: they call class methods and no person is involved.
**The only dialog step is the user decision (Approve / Reject).** It does not need an own task: it is the *User Decision* step type in the template, which uses the standard decision task TS00008267.

| Step | Task (abbreviation) | Name | Method | Background | Dialog / agent | Bindings task ↔ method |
|------|---------------------|------|--------|------------|----------------|------------------------|
| 1 | ZSO_CHG_START | Start approval run | START | **Yes** | No agent (WF-BATCH) | IV_LOG_ID, IV_WF_ID → EV_LEVELS |
| 3.1 | ZSO_CHG_LEVEL | Prepare approval level | PREPARE_LEVEL | **Yes** | No agent (WF-BATCH) | IV_LOG_ID, IV_INDEX → EV_LEVEL, ET_AGENTS |
| 3.2 | *User Decision step* (standard TS00008267) | Approve / Reject | – | **No** | **Dialog**: approver of the level (expression &AGENTS&), in Fiori My Inbox | Result → outcome Approve / Reject; _WI_ACTUAL_AGENT → DECIDED_BY |
| 3.3 / 3.4 | ZSO_CHG_DECIDE | Log decision | DECIDE | **Yes** | No agent (WF-BATCH) | IV_LOG_ID, IV_LEVEL, IV_APPROVED, IV_DECIDED_BY |
| 4 (approved) | ZSO_CHG_APPROVED | Release delivery block | FINISH_APPROVED | **Yes** | No agent (WF-BATCH) | IV_LOG_ID. Exception CX_BO_TEMPORARY = *Temporary error* (retry) |
| 4 (rejected) | ZSO_CHG_REJECTED | Close rejected run | FINISH_REJECTED | **Yes** | No agent (WF-BATCH) | IV_LOG_ID |

**Settings for the five background tasks** (PFTC → Standard task → Create):
- Object category **ABAP Class**, object type `ZCL_SD_SO_CHG_WF`, the method above.
- Tick **Background processing** and **Synchronous object method**.
- Container elements are proposed from the method parameters: answer *Yes*.
- *Additional data → Agent assignment → Attributes → General task*.
- No agent is entered in the template step. Background steps run under the workflow system user WF-BATCH (SWU3).

**Settings for the dialog step (3.2, User Decision):**
- Step type *User Decision* in SWDD, not a PFTC task.
- Agents: *Expression* `&AGENTS&`, which is the approver of the current level from ZSD_SO_APPR_CFG / ZSD_SO_CHG_LL.
- Decision texts: 1 = `Approve`, 2 = `Reject`.
- The work item appears in **Fiori My Inbox** with Approve / Reject buttons.

**Who removes the delivery block?** Only step 4 (approved), FINISH_APPROVED. It runs **once, after the last level has approved**:
- The loop ends only when `LEVEL_INDEX > LEVELS` (all levels approved) or `REJECTED = 'X'`.
- Approval at level 1 … n-1 only logs the decision (DECIDE) and moves to the next level. The order stays blocked.
- FINISH_APPROVED also checks the log itself: if any level is not *Approved*, it refuses the release, logs an ERROR event and the order stays blocked.

## 18. Workflow template ZSD_SO_CHG_APPR (SWDD)

### 18.1 Basic data
- SWDD → Create → abbreviation `ZSD_SO_CHG_APPR`, name `SO change approval (CH4323)`. Save → number WS9xxxxxxx.
- **Agent assignment** of the template: *General task*.

### 18.2 Container

| Element | Type | Import | Initial value | Purpose |
|---------|------|--------|---------------|---------|
| ORDER | ABAP class ZCL_SD_SO_CHG_WF | X | | Sales order |
| LOG_ID | ABAP Dict. SYSUUID_C32 | X | | Run ID from the event |
| LEVELS | ABAP Dict. INT4 | | | Number of levels |
| LEVEL_INDEX | ABAP Dict. INT4 | | 1 | Loop counter |
| LEVEL | ABAP Dict. ZSD_SO_LEVEL | | | Current level |
| AGENTS | ABAP Dict. TSWHACTOR (multiline) | | | Approver of the current level |
| REJECTED | ABAP Dict. XFELD | | | X = rejected |
| DECIDED_BY | ABAP Dict. XUBNAME | | | User who decided |

### 18.3 Start event (Basic data → Start events)

| Category | Object type | Event | Binding | Active |
|----------|-------------|-------|---------|--------|
| CL | ZCL_SD_SO_CHG_WF | CHANGE_APPROVAL_REQUIRED | `&_EVT_OBJECT&` → `&ORDER&`, `&LOG_ID&` → `&LOG_ID&` | Activate (check SWE2) |

### 18.4 Steps

```
1   Activity      ZSO_CHG_START      binding: LOG_ID -> IV_LOG_ID, &_WORKITEM.WORKITEMID& -> IV_WF_ID
                                     back:    EV_LEVELS -> LEVELS
2   Condition     LEVELS = 0
       true  -> Process control: Complete workflow   (run already closed with status E)
3   Loop (UNTIL)  REJECTED = 'X'  OR  LEVEL_INDEX > LEVELS
    3.1 Activity  ZSO_CHG_LEVEL      binding: LOG_ID, LEVEL_INDEX -> IV_INDEX
                                     back:    EV_LEVEL -> LEVEL, ET_AGENTS -> AGENTS
    3.2 User Decision
          Title     : Change of sales order &ORDER.VBELN& - approve?
          Decisions : 1 Approve   2 Reject   (Reject: comment mandatory - optional)
          Agents    : Expression &AGENTS&
          Back      : &_WI_ACTUAL_AGENT& -> DECIDED_BY   (remove "US" prefix if needed)
          Object    : &ORDER&  (display object -> VA03)
        Outcome Approve:
          3.3 Activity  ZSO_CHG_DECIDE   LOG_ID, LEVEL, IV_APPROVED = 'X', DECIDED_BY
          3.5 Container operation  LEVEL_INDEX = LEVEL_INDEX + 1
        Outcome Reject:
          3.4 Activity  ZSO_CHG_DECIDE   LOG_ID, LEVEL, IV_APPROVED = ' ', DECIDED_BY
          3.6 Container operation  REJECTED = 'X'
4   Condition     REJECTED = 'X'
       true  -> Activity ZSO_CHG_REJECTED   (LOG_ID)
       false -> Activity ZSO_CHG_APPROVED   (LOG_ID)  - temporary error: retry
```

Notes:
- **Object binding of every activity (important):** in each activity step, *Binding (workflow → task)* must contain `&ORDER&` → `&_WI_OBJECT_ID&`.
  This is the object instance on which the method runs; it carries the order number as attribute VBELN.
  FINISH_APPROVED reads the order number from the log header (ZSD_SO_CHG_LH-VBELN via LOG_ID) and uses the instance only as fallback.
- **Workflow ID binding:** if `&_WORKITEM.WORKITEMID&` is not offered in your release, leave IV_WF_ID unbound. START then finds the workflow itself.
- **DECIDED_BY:** `_WI_ACTUAL_AGENT` is `US<user>`. If needed, bind it to a CHAR 14 element and pass `+2` to DECIDED_BY, or use a container operation.
- **Retry:** for step ZSO_CHG_APPROVED, set the error handling for *temporary errors* to retry (e.g. 10 × every 10 minutes, *Details → Error handling*). This covers an order still open in VA02 when the last approver approves.
- **Test:** SWUS / SWU_OBUF; event trace SWELS / SWEL.

## 19. Log report ZSD_SO_CHG_WF_LOG and transaction ZSD_SOCHG_LOG

1. SE38 → `ZSD_SO_CHG_WF_LOG`:
   - Type *Executable program*, title `SO Change Approval - Workflow Log`
   - Package ZSD
   - Paste the code, activate
2. Text elements → **Text symbols** (or *Goto → Text elements → Compare*):

| Sym | Text | Length |
|-----|------|--------|
| E01 | Step | 10 |
| E02 | Event | 10 |
| E03 | No. | 10 |
| E04 | Level | 10 |
| E05 | User | 10 |
| E06 | Details | 10 |
| E07 | Date | 10 |
| E08 | Time | 10 |
| E09 | Logged by | 10 |
| H01 | Status | 10 |
| H02 | Status text | 11 |
| H03 | Contract | 10 |
| H04 | Level 1 | 10 |
| H05 | Level 2 | 10 |
| H06 | Level 3 | 10 |
| H07 | Level 4 | 10 |
| H08 | Current level | 13 |
| H09 | Levels | 10 |
| H10 | Waiting for | 11 |
| H11 | Net value | 10 |
| H16 | Started on | 10 |
| H17 | Started at | 10 |
| H18 | Finished on | 11 |
| H19 | Finished at | 11 |
| H21 | Workflow | 10 |
| H22 | Trigger event | 13 |
| H23 | Changed by | 10 |
| H24 | Changed on | 10 |
| H25 | Changed at | 10 |
| H26 | Changes | 10 |
| M01 | No workflow log found for the selection | 39 |
| M02 | Workflow log cannot be displayed | 32 |
| T01 | Sales order change approval - workflow log | 42 |
| T02 | Workflow timeline | 17 |

| Sym | Text |
|-----|------|
| B01 | Selection |

3. Text elements → **Selection texts**:

| Name | Text | Dictionary ref. |
|------|------|-----------------|
| P_VKORG | Sales Organization | X |
| S_VBELN | Sales Order | X |
| S_KUNNR | Customer | X |
| S_AUART | Order Type | X |
| S_VTWEG | Distribution Channel | X |
| S_SPART | Division | X |
| S_CREDAT | Started On | |
| S_STATUS | Status | X |
| S_TRGBY | Changed By | |

4. SE93 → `ZSD_SOCHG_LOG`:
   - *Program and selection screen (report transaction)*, program ZSD_SO_CHG_WF_LOG, screen 1000
   - Text: `SO Change Approval - WF Log`
   - GUI support: SAP GUI for HTML / Windows

```abap
*&---------------------------------------------------------------------*
*& Program        : ZSD_SO_CHG_WF_LOG
*& Transaction    : ZSD_SOCHG_LOG
*& Workflow       : ZSD_SO_CHG_APPR (WS9xxxxxxx)
*& Package        : ZSD
*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : <Functional consultant>
*&---------------------------------------------------------------------*
*& Purpose        : Log monitor of the sales order change approval
*&                  workflow (CH4323).
*&---------------------------------------------------------------------*
*& Created By     : Hassan Diab
*& Created On     : 06.10.2026
*& Request No.    : <Request>
*& Version        : 1.0
*&---------------------------------------------------------------------*
*& Change History
*&---------------------------------------------------------------------*
*& Ver | Date       | Author        | Request No.  | Description
*&-----|------------|---------------|--------------|--------------------
*& 1.0 | 06.10.2026 | Hassan Diab   | <Request>    | Initial Creation
*&---------------------------------------------------------------------*
REPORT ZSD_SO_CHG_WF_LOG.

TABLES ZSD_SO_CHG_LH.

SELECTION-SCREEN BEGIN OF BLOCK B1 WITH FRAME TITLE TEXT-B01.
  PARAMETERS     P_VKORG TYPE VKORG OBLIGATORY.
  SELECT-OPTIONS S_VBELN  FOR ZSD_SO_CHG_LH-VBELN.
  SELECT-OPTIONS S_KUNNR  FOR ZSD_SO_CHG_LH-KUNNR.
  SELECT-OPTIONS S_AUART  FOR ZSD_SO_CHG_LH-AUART.
  SELECT-OPTIONS S_VTWEG  FOR ZSD_SO_CHG_LH-VTWEG.
  SELECT-OPTIONS S_SPART  FOR ZSD_SO_CHG_LH-SPART.
  SELECT-OPTIONS S_CREDAT FOR ZSD_SO_CHG_LH-CREATED_ON.
  SELECT-OPTIONS S_STATUS FOR ZSD_SO_CHG_LH-STATUS.
  SELECT-OPTIONS S_TRGBY  FOR ZSD_SO_CHG_LH-TRIGGER_BY.
SELECTION-SCREEN END OF BLOCK B1.

CLASS LCL_REPORT DEFINITION FINAL.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF TY_OUT,
        STATUS_ICON TYPE ICON_D,
        STATUS_TEXT TYPE CHAR30,
        VBELN       TYPE VBELN_VA,
        CONTRACT    TYPE VBELN_VA,
        KUNNR       TYPE KUNAG,
        CUST_NAME   TYPE NAME1_GP,
        VKORG       TYPE VKORG,
        VTWEG       TYPE VTWEG,
        SPART       TYPE SPART,
        AUART       TYPE AUART,
        CHANGE_TEXT TYPE ZSD_SO_CHG_TEXT,
        L1_ICON     TYPE ICON_D,
        L2_ICON     TYPE ICON_D,
        L3_ICON     TYPE ICON_D,
        L4_ICON     TYPE ICON_D,
        CURR_LEVEL  TYPE ZSD_SO_LEVEL,
        LEVELS      TYPE ZSD_SO_LEVEL,
        CURR_APPR   TYPE AD_NAMTEXT,
        NETWR       TYPE NETWR_AK,
        WAERK       TYPE WAERK,
        CREATED_ON  TYPE DATS,
        CREATED_AT  TYPE TIMS,
        FINISHED_ON TYPE DATS,
        FINISHED_AT TYPE TIMS,
        TRIGGER_EVT TYPE SIBFEVENT,
        TRIGGER_BY  TYPE XUBNAME,
        TRIGGER_ON  TYPE DATS,
        TRIGGER_AT  TYPE TIMS,
        REPLACED_BY TYPE SYSUUID_C32,
        WF_ID       TYPE SWW_WIID,
        LOG_ID      TYPE SYSUUID_C32,
      END OF TY_OUT .
    TYPES TT_OUT TYPE STANDARD TABLE OF TY_OUT WITH DEFAULT KEY .

    TYPES:
      BEGIN OF TY_EVT,
        ICON       TYPE ICON_D,
        EVENT_TEXT TYPE CHAR30,
        SEQNR      TYPE ZSD_SO_CHG_LE-SEQNR,
        APPR_LEVEL TYPE ZSD_SO_LEVEL,
        UNAME      TYPE XUBNAME,
        TEXT       TYPE ZSD_SO_CHG_LE-TEXT,
        CREATED_ON TYPE DATS,
        CREATED_AT TYPE TIMS,
        CREATED_BY TYPE SYUNAME,
      END OF TY_EVT .
    TYPES TT_EVT TYPE STANDARD TABLE OF TY_EVT WITH DEFAULT KEY .

    METHODS RUN .

  PRIVATE SECTION.

    DATA MT_OUT TYPE TT_OUT .
    DATA MO_ALV TYPE REF TO CL_SALV_TABLE .

    METHODS SELECT_DATA .
    METHODS DISPLAY .
    METHODS SHOW_EVENTS
      IMPORTING
        !IV_LOG_ID TYPE SYSUUID_C32 .
    METHODS SET_COLUMN
      IMPORTING
        !IO_COLUMNS TYPE REF TO CL_SALV_COLUMNS_TABLE
        !IV_NAME    TYPE LVC_FNAME
        !IV_TEXT    TYPE CSEQUENCE OPTIONAL
        !IV_ICON    TYPE ABAP_BOOL OPTIONAL
        !IV_HOTSPOT TYPE ABAP_BOOL OPTIONAL
        !IV_HIDE    TYPE ABAP_BOOL OPTIONAL
        !IV_CURR    TYPE LVC_FNAME OPTIONAL .

    METHODS ON_DOUBLE_CLICK
      FOR EVENT DOUBLE_CLICK OF CL_SALV_EVENTS_TABLE
      IMPORTING ROW COLUMN .
    METHODS ON_LINK_CLICK
      FOR EVENT LINK_CLICK OF CL_SALV_EVENTS_TABLE
      IMPORTING ROW COLUMN .

ENDCLASS.


CLASS LCL_REPORT IMPLEMENTATION.

  METHOD RUN.

    SELECT_DATA( ).

    IF MT_OUT IS INITIAL.
      MESSAGE 'No workflow log found for the selection'(M01) TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    DISPLAY( ).

  ENDMETHOD.


  METHOD SELECT_DATA.

    DATA: LT_HEAD   TYPE STANDARD TABLE OF ZSD_SO_CHG_LH,
          LS_HEAD   TYPE ZSD_SO_CHG_LH,
          LT_LEVELS TYPE STANDARD TABLE OF ZSD_SO_CHG_LL,
          LS_LEVEL  TYPE ZSD_SO_CHG_LL,
          LS_OUT    TYPE TY_OUT,
          LV_POS    TYPE I.

    CLEAR MT_OUT.

    SELECT * FROM ZSD_SO_CHG_LH INTO TABLE LT_HEAD
      WHERE VKORG      = P_VKORG
        AND VBELN      IN S_VBELN
        AND KUNNR      IN S_KUNNR
        AND AUART      IN S_AUART
        AND VTWEG      IN S_VTWEG
        AND SPART      IN S_SPART
        AND CREATED_ON IN S_CREDAT
        AND STATUS     IN S_STATUS
        AND TRIGGER_BY IN S_TRGBY.

    IF LT_HEAD IS INITIAL.
      RETURN.
    ENDIF.

    SELECT * FROM ZSD_SO_CHG_LL INTO TABLE LT_LEVELS
      FOR ALL ENTRIES IN LT_HEAD
      WHERE LOG_ID = LT_HEAD-LOG_ID.

    SORT LT_LEVELS BY LOG_ID APPR_LEVEL.
    SORT LT_HEAD BY CREATED_ON DESCENDING CREATED_AT DESCENDING.

    LOOP AT LT_HEAD INTO LS_HEAD.

      CLEAR LS_OUT.
      MOVE-CORRESPONDING LS_HEAD TO LS_OUT.

      LS_OUT-STATUS_ICON = ZCL_SD_SO_CHG_LOG=>GET_STATUS_ICON( LS_HEAD-STATUS ).
      LS_OUT-STATUS_TEXT = ZCL_SD_SO_CHG_LOG=>GET_STATUS_TEXT( LS_HEAD-STATUS ).

      " level columns by position (levels may be numbered 01/02/.. or 10/20/..)
      CLEAR LV_POS.
      LOOP AT LT_LEVELS INTO LS_LEVEL WHERE LOG_ID = LS_HEAD-LOG_ID.
        LV_POS = LV_POS + 1.
        CASE LV_POS.
          WHEN 1. LS_OUT-L1_ICON = ZCL_SD_SO_CHG_LOG=>GET_LEVEL_ICON( LS_LEVEL-STATUS ).
          WHEN 2. LS_OUT-L2_ICON = ZCL_SD_SO_CHG_LOG=>GET_LEVEL_ICON( LS_LEVEL-STATUS ).
          WHEN 3. LS_OUT-L3_ICON = ZCL_SD_SO_CHG_LOG=>GET_LEVEL_ICON( LS_LEVEL-STATUS ).
          WHEN 4. LS_OUT-L4_ICON = ZCL_SD_SO_CHG_LOG=>GET_LEVEL_ICON( LS_LEVEL-STATUS ).
        ENDCASE.
        IF LS_LEVEL-APPR_LEVEL = LS_HEAD-CURR_LEVEL
           AND LS_HEAD-STATUS = ZCL_SD_SO_CHG_LOG=>GC_STATUS-IN_PROCESS.
          LS_OUT-CURR_APPR = LS_LEVEL-FULL_NAME.
        ENDIF.
      ENDLOOP.

      APPEND LS_OUT TO MT_OUT.

    ENDLOOP.

  ENDMETHOD.


  METHOD DISPLAY.

    DATA: LO_COLUMNS   TYPE REF TO CL_SALV_COLUMNS_TABLE,
          LO_EVENTS    TYPE REF TO CL_SALV_EVENTS_TABLE,
          LO_FUNCTIONS TYPE REF TO CL_SALV_FUNCTIONS_LIST,
          LO_DISPLAY   TYPE REF TO CL_SALV_DISPLAY_SETTINGS,
          LX_SALV      TYPE REF TO CX_SALV_MSG,
          LV_TITLE     TYPE LVC_TITLE.

    TRY.
        CL_SALV_TABLE=>FACTORY( IMPORTING R_SALV_TABLE = MO_ALV
                                CHANGING  T_TABLE      = MT_OUT ).
      CATCH CX_SALV_MSG INTO LX_SALV.
        MESSAGE LX_SALV TYPE 'E'.
        RETURN.
    ENDTRY.

    LO_FUNCTIONS = MO_ALV->GET_FUNCTIONS( ).
    LO_FUNCTIONS->SET_ALL( ABAP_TRUE ).

    LO_DISPLAY = MO_ALV->GET_DISPLAY_SETTINGS( ).
    LO_DISPLAY->SET_STRIPED_PATTERN( ABAP_TRUE ).
    LV_TITLE = 'Sales order change approval - workflow log'(T01).
    LO_DISPLAY->SET_LIST_HEADER( LV_TITLE ).

    LO_COLUMNS = MO_ALV->GET_COLUMNS( ).
    LO_COLUMNS->SET_OPTIMIZE( ABAP_TRUE ).

    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'STATUS_ICON' IV_TEXT = 'Status'(H01)   IV_ICON = ABAP_TRUE ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'STATUS_TEXT' IV_TEXT = 'Status text'(H02) ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'VBELN'       IV_HOTSPOT = ABAP_TRUE ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'CONTRACT'    IV_TEXT = 'Contract'(H03) IV_HOTSPOT = ABAP_TRUE ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'CHANGE_TEXT' IV_TEXT = 'Changes'(H26) ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'L1_ICON'     IV_TEXT = 'Level 1'(H04)  IV_ICON = ABAP_TRUE ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'L2_ICON'     IV_TEXT = 'Level 2'(H05)  IV_ICON = ABAP_TRUE ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'L3_ICON'     IV_TEXT = 'Level 3'(H06)  IV_ICON = ABAP_TRUE ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'L4_ICON'     IV_TEXT = 'Level 4'(H07)  IV_ICON = ABAP_TRUE ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'CURR_LEVEL'  IV_TEXT = 'Current level'(H08) ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'LEVELS'      IV_TEXT = 'Levels'(H09) ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'CURR_APPR'   IV_TEXT = 'Waiting for'(H10) ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'NETWR'       IV_TEXT = 'Net value'(H11) IV_CURR = 'WAERK' ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'CREATED_ON'  IV_TEXT = 'Started on'(H16) ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'CREATED_AT'  IV_TEXT = 'Started at'(H17) ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'FINISHED_ON' IV_TEXT = 'Finished on'(H18) ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'FINISHED_AT' IV_TEXT = 'Finished at'(H19) ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'TRIGGER_EVT' IV_TEXT = 'Trigger event'(H22) ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'TRIGGER_BY'  IV_TEXT = 'Changed by'(H23) ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'TRIGGER_ON'  IV_TEXT = 'Changed on'(H24) ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'TRIGGER_AT'  IV_TEXT = 'Changed at'(H25) ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'REPLACED_BY' IV_HIDE = ABAP_TRUE ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'WF_ID'       IV_TEXT = 'Workflow'(H21) IV_HOTSPOT = ABAP_TRUE ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'LOG_ID'      IV_HIDE = ABAP_TRUE ).

    LO_EVENTS = MO_ALV->GET_EVENT( ).
    SET HANDLER ON_DOUBLE_CLICK FOR LO_EVENTS.
    SET HANDLER ON_LINK_CLICK   FOR LO_EVENTS.

    MO_ALV->DISPLAY( ).

  ENDMETHOD.


  METHOD SET_COLUMN.

    DATA: LO_COLUMN TYPE REF TO CL_SALV_COLUMN_TABLE,
          LV_SHORT  TYPE SCRTEXT_S,
          LV_MEDIUM TYPE SCRTEXT_M,
          LV_LONG   TYPE SCRTEXT_L.

    TRY.
        LO_COLUMN ?= IO_COLUMNS->GET_COLUMN( IV_NAME ).
      CATCH CX_SALV_NOT_FOUND.
        RETURN.
    ENDTRY.

    IF IV_TEXT IS NOT INITIAL.
      LV_SHORT  = IV_TEXT.
      LV_MEDIUM = IV_TEXT.
      LV_LONG   = IV_TEXT.
      LO_COLUMN->SET_SHORT_TEXT( LV_SHORT ).
      LO_COLUMN->SET_MEDIUM_TEXT( LV_MEDIUM ).
      LO_COLUMN->SET_LONG_TEXT( LV_LONG ).
    ENDIF.

    IF IV_ICON = ABAP_TRUE.
      LO_COLUMN->SET_ICON( IF_SALV_C_BOOL_SAP=>TRUE ).
      LO_COLUMN->SET_ALIGNMENT( IF_SALV_C_ALIGNMENT=>CENTERED ).
    ENDIF.

    IF IV_HOTSPOT = ABAP_TRUE.
      LO_COLUMN->SET_CELL_TYPE( IF_SALV_C_CELL_TYPE=>HOTSPOT ).
    ENDIF.

    IF IV_HIDE = ABAP_TRUE.
      LO_COLUMN->SET_VISIBLE( ABAP_FALSE ).
    ENDIF.

    IF IV_CURR IS NOT INITIAL.
      TRY.
          LO_COLUMN->SET_CURRENCY_COLUMN( IV_CURR ).
        CATCH CX_SALV_NOT_FOUND CX_SALV_DATA_ERROR.
      ENDTRY.
    ENDIF.

  ENDMETHOD.


  METHOD ON_DOUBLE_CLICK.

    DATA LS_OUT TYPE TY_OUT.

    READ TABLE MT_OUT INTO LS_OUT INDEX ROW.
    IF SY-SUBRC = 0.
      SHOW_EVENTS( LS_OUT-LOG_ID ).
    ENDIF.

  ENDMETHOD.


  METHOD ON_LINK_CLICK.

    DATA LS_OUT TYPE TY_OUT.

    READ TABLE MT_OUT INTO LS_OUT INDEX ROW.
    IF SY-SUBRC <> 0.
      RETURN.
    ENDIF.

    CASE COLUMN.
      WHEN 'VBELN'.
        SET PARAMETER ID 'AUN' FIELD LS_OUT-VBELN.
        CALL TRANSACTION 'VA03' AND SKIP FIRST SCREEN.      "#EC CI_CALLTA
      WHEN 'CONTRACT'.
        IF LS_OUT-CONTRACT IS NOT INITIAL.
          SET PARAMETER ID 'KTN' FIELD LS_OUT-CONTRACT.
          CALL TRANSACTION 'VA43' AND SKIP FIRST SCREEN.    "#EC CI_CALLTA
        ENDIF.
      WHEN 'WF_ID'.
        IF LS_OUT-WF_ID IS NOT INITIAL.
          CALL FUNCTION 'SWL_WI_DISPLAY'
            EXPORTING
              WI_ID  = LS_OUT-WF_ID
            EXCEPTIONS
              OTHERS = 1.
          IF SY-SUBRC <> 0.
            MESSAGE 'Workflow log cannot be displayed'(M02) TYPE 'S' DISPLAY LIKE 'E'.
          ENDIF.
        ENDIF.
    ENDCASE.

  ENDMETHOD.


  METHOD SHOW_EVENTS.

    DATA: LT_EVENTS  TYPE ZCL_SD_SO_CHG_LOG=>TT_EVENTS,
          LS_EVENT   TYPE ZSD_SO_CHG_LE,
          LT_EVT     TYPE TT_EVT,
          LS_EVT     TYPE TY_EVT,
          LO_POPUP   TYPE REF TO CL_SALV_TABLE,
          LO_COLUMNS TYPE REF TO CL_SALV_COLUMNS_TABLE,
          LO_DISPLAY TYPE REF TO CL_SALV_DISPLAY_SETTINGS,
          LX_SALV    TYPE REF TO CX_SALV_MSG,
          LV_TITLE   TYPE LVC_TITLE.

    LT_EVENTS = ZCL_SD_SO_CHG_LOG=>GET_EVENTS( IV_LOG_ID ).

    LOOP AT LT_EVENTS INTO LS_EVENT.
      CLEAR LS_EVT.
      MOVE-CORRESPONDING LS_EVENT TO LS_EVT.
      LS_EVT-ICON       = ZCL_SD_SO_CHG_LOG=>GET_EVENT_ICON( LS_EVENT-EVENT ).
      LS_EVT-EVENT_TEXT = ZCL_SD_SO_CHG_LOG=>GET_EVENT_TEXT( LS_EVENT-EVENT ).
      APPEND LS_EVT TO LT_EVT.
    ENDLOOP.

    TRY.
        CL_SALV_TABLE=>FACTORY( IMPORTING R_SALV_TABLE = LO_POPUP
                                CHANGING  T_TABLE      = LT_EVT ).
      CATCH CX_SALV_MSG INTO LX_SALV.
        MESSAGE LX_SALV TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    LO_COLUMNS = LO_POPUP->GET_COLUMNS( ).
    LO_COLUMNS->SET_OPTIMIZE( ABAP_TRUE ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'ICON'       IV_TEXT = 'Step'(E01) IV_ICON = ABAP_TRUE ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'EVENT_TEXT' IV_TEXT = 'Event'(E02) ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'SEQNR'      IV_TEXT = 'No.'(E03) ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'APPR_LEVEL' IV_TEXT = 'Level'(E04) ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'UNAME'      IV_TEXT = 'User'(E05) ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'TEXT'       IV_TEXT = 'Details'(E06) ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'CREATED_ON' IV_TEXT = 'Date'(E07) ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'CREATED_AT' IV_TEXT = 'Time'(E08) ).
    SET_COLUMN( IO_COLUMNS = LO_COLUMNS IV_NAME = 'CREATED_BY' IV_TEXT = 'Logged by'(E09) ).

    LO_DISPLAY = LO_POPUP->GET_DISPLAY_SETTINGS( ).
    LV_TITLE = 'Workflow timeline'(T02).
    LO_DISPLAY->SET_LIST_HEADER( LV_TITLE ).

    LO_POPUP->SET_SCREEN_POPUP( START_COLUMN = 5
                                END_COLUMN   = 170
                                START_LINE   = 3
                                END_LINE     = 25 ).
    LO_POPUP->DISPLAY( ).

  ENDMETHOD.

ENDCLASS.

START-OF-SELECTION.
  DATA GO_REPORT TYPE REF TO LCL_REPORT.
  CREATE OBJECT GO_REPORT.
  GO_REPORT->RUN( ).
```

## 20. Customizing and configuration

| # | Item | Where | Value / action |
|---|------|-------|----------------|
| 1 | Delivery block XX | SPRO → Logistics Execution → Shipping → Deliveries → Define Reasons for Blocking in Shipping (OVLS / TVLS) | Block `XX`, text `Change approval pending`, tick *Delivery block* (and *Billing block* if wanted). Assign it to the delivery types / sales document types as required |
| 2 | E-mail | SCOT / SOST | SMTP node active, job RSCONN01 scheduled (or immediate sending). Sender: user WF-BATCH needs an e-mail address in SU01 |
| 3 | Workflow runtime | SWU3 | All entries green (WF-BATCH, RFC destination, event queue) |
| 4 | My Inbox | /IWFND/MAINT_SERVICE | Service `/IWPGW/TASKPROCESSING` (version 2) active; approvers have the My Inbox catalog / role |
| 5 | Approvers | SU01 | Each approver has an e-mail address (unless filled in ZSD_SO_APPR_CFG) |
| 6 | Filter | ZSD_SOCON (Part 1) | Process `VA02` or `BOTH` lines for the orders in scope |

## 21. Maintain approvers and test

1. **ZSD_SO_APPR:** maintain the levels (step 3 example).
2. **Test cases:**

| # | Scenario | Expected |
|---|----------|----------|
| 1 | VA02 change a text only | No block, no run |
| 2 | VA02 change quantity | Block XX; ZSD_SO_CHG_LH status P; CHANGE event; e-mail to level 1; work item in My Inbox |
| 3 | Change quantity and material in one save | One run, two CHANGE events, one workflow |
| 4 | Change a characteristic value / add or delete an item | Block, run, workflow |
| 5 | Open the order in VA02 while status P | Message "display only"; all fields, Insert/Delete and configuration closed |
| 6 | Level 1 approves (two levels) | Level 1 A, level 2 D, e-mail to level 2 |
| 7 | Last level approves | Block removed, run A, RELEASE event, requester e-mail; VA02 open again |
| 8 | A level rejects | Run R, remaining levels N, block stays, requester e-mail |
| 9 | Change again after approval or rejection | New run, new workflow |
| 10 | While status P: change by BAPI_SALESORDER_CHANGE | New run; old run F; old workflow cancelled; old work item gone from My Inbox |
| 11 | No approver maintained | Run E, ERROR event, block stays, requester e-mail |
| 12 | ZSD_SOCHG_LOG | Runs with level icons; hotspots VA03 / VA43 / workflow log; double-click shows the timeline |

## 22. Open points

1. Approver key: sales org + order type, or also channel, division or contract type?
2. Final delivery block code (XX).
3. Reminder or escalation deadline on the decision step.
4. Whether a net value change caused by automatic repricing counts as a change.
