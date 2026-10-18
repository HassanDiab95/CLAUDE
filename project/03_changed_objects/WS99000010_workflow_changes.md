# WS99000010 – workflow changes (SWDD), step by step

Three new background steps are added. They call the class `ZCL_WF_SD_SO_REL_STEP`, which calls
`ZCL_SD_SO_RELEASE`. **Nothing else in the workflow changes**: approval levels, decisions, mails (the HTML
sent to the approver stays as it is), logs and the existing `REJECT_STEP` stay as they are.

## Why the workflow needs these changes at all

The workflow decides the credit for the **whole order**, but YSDA / YSDAX decided **each line**. Without these
steps the workflow does not know which lines were approved in YSDA / YSDAX, so:

| Without the new steps | With the new steps |
|---|---|
| Final approval releases the credit block, but the approved lines stay **CN** forever – nothing converts them to CP | `SO_REL_APPROVED` converts exactly the lines approved in YSDA / YSDAX to **CP**; rejected lines stay CN |
| Two workflows can run for the same order (e.g. YSDA raises the event and a VA02 save raises one at the same moment) – two approvals, two mails | `SO_REL_START` + the `REL_DUPLICATE` check end the second workflow at once |
| The release tables do not know that credit is running / approved / rejected – VA02 changes cannot be compared with what credit approved, VKM1 cannot be blocked, the job cannot retry | `SO_REL_START` stores "credit in approval" + the snapshot; `SO_REL_APPROVED` / `SO_REL_REJECTED` store the result |
| After a rejection nobody knows which lines were approved in YSDA and are now cancelled | `SO_REL_REJECTED` records every line before your `REJECT_STEP` cancels the order |

## Step 1 – Create the class `ZCL_WF_SD_SO_REL_STEP` (SE24)
File `02_new_objects/ZCL_WF_SD_SO_REL_STEP.abap` → create, paste, activate (`ZCL_SD_SO_RELEASE` must be active).
**Why:** a workflow task can only call a class that implements `IF_WORKFLOW`; this class is that link.

## Step 2 – Create three standard tasks (PFTC)
PFTC → Task type *Standard task* → Create. For each task:
- *Object category* **ABAP Class**, *Object type* `ZCL_WF_SD_SO_REL_STEP`, *Method* as below
- tick **Synchronous object method** and **Background processing**
- Additional data → Agent assignment → **General task**
- tab *Container*: the elements are created from the method parameters (accept the proposal)

| Task (new number) | Abbreviation / text | Method | Container |
|---|---|---|---|
| TS9xxxxxx1 | `SO_REL_START` – Release cycle: credit started | `CREDIT_STARTED` | IV_VBELN, IV_WI_ID (import), EV_DUPLICATE (export) |
| TS9xxxxxx2 | `SO_REL_APPROVED` – Release cycle: credit approved | `CREDIT_APPROVED` | IV_VBELN (import) |
| TS9xxxxxx3 | `SO_REL_REJECTED` – Release cycle: credit rejected | `CREDIT_REJECTED` | IV_VBELN, IV_NOTE, IV_ABGRU (import) |

For `SO_REL_APPROVED` only: tab *Temporary error* → retry **10 times every 15 minutes**.
**Why:** if the order is open in VA02 when credit is approved, CN → CP cannot be saved (order locked); the
step then waits and tries again. If it still fails, the job `ZSD_SO_REL_RECONCILE` does it later.

## Step 3 – New container element `REL_DUPLICATE` (SWDD → Container → Create)

| Element | Data type | Properties |
|---|---|---|
| `REL_DUPLICATE` | `XFELD` | none (not import / export) |

**Usage of `REL_DUPLICATE`:** it receives the answer of the first new step: "is another workflow already
running for this sales order?".
- `X` → yes: a workflow for this order is already in approval (its work item ID is saved in the release
  table and that work item is still active). This new workflow is a duplicate and must stop immediately.
- empty → no: this is the only workflow; it registers itself (its ID, "credit in approval", snapshot,
  release plan) and continues normally.

**Why it is needed:** for orders of the release cycle the workflow can be started from two places – YSDA /
YSDAX (event raised when the last line is decided) and VA02 (event raised by the order save). If both events
arrive at nearly the same moment, the check function module can let both through, because neither workflow
has registered yet. The first step registers the workflow under a lock; the second one finds the first
already registered and gets `REL_DUPLICATE = X`. Without this flag the approver would get two work items and
two mails for the same order, and both workflows would later try to release / cancel the order.

## Step 4 – First step of the workflow: `SO_REL_START`
SWDD → open WS99000010 → new version → insert **before** the current first step ("Check Blocked Flag"):
- Step type **Activity**, task `SO_REL_START`, *Background step*
- Binding workflow → task:
  - `&SALES_ORDER&` → `IV_VBELN`
  - `&_WORKITEM.ID&` → `IV_WI_ID` (system element `_WORKITEM`, attribute ID – choose it with F4 in the
    binding editor; the attribute name can differ by release)
- Binding task → workflow: `EV_DUPLICATE` → `&REL_DUPLICATE&`

**Why first:** the workflow must register itself before anything else (before mails are sent). It saves:
credit status "in approval", the snapshot (net value, quantities, credit account, currency, payment terms)
used to compare later VA02 changes, and the release plan (which lines go CN → CP at the final approval and
which stay CN). For orders that are not in the release cycle it does nothing and returns `REL_DUPLICATE` empty.

## Step 5 – Condition directly after it: `&REL_DUPLICATE& = X`
- Step type **Condition**, condition `&REL_DUPLICATE&` = `X`
- **True** branch: step type **Process Control** → function **Cancel workflow** (or *Complete workflow*)
- **False** branch: continue with the existing first step ("Check Blocked Flag")

**Why:** ends the duplicate workflow before it creates work items or sends mails (see step 3).

## Step 6 – After the final approval: `SO_REL_APPROVED`
In the final-approval path (*CHECK_FINAL_APPROVAL* = true, after "Approve Release Sales Order"), insert
**after** the step that releases the SAP credit block:
- Step type **Activity**, task `SO_REL_APPROVED`, *Background step*
- Binding: `&SALES_ORDER&` → `IV_VBELN`

**Why:** this is the step that sends the approved lines to production. It changes **only** the lines
approved in YSDA / YSDAX from CN to CP; lines rejected in YSDA / YSDAX stay CN. It must come **after** the
credit block release, otherwise lines would go to production while the order is still blocked.
If the final approval exists in more than one place of the workflow, insert it after each of them.

## Step 7 – On rejection: `SO_REL_REJECTED`
Insert **directly before** the existing `REJECT_STEP` (task TS99000044 "Cancel Sales Order Credit") in both
places where it is used (nodes 233 and 243):
- Step type **Activity**, task `SO_REL_REJECTED`, *Background step*
- Binding: `&SALES_ORDER&` → `IV_VBELN`, decision note → `IV_NOTE` (the same note the workflow already
  writes to the log via `ZCL_WF_NOTE_READER`), `&REASON&` → `IV_ABGRU`

**Why:** it records every line as YSDA / YSDAX decided it (approved lines: "not released – cancelled",
rejected lines unchanged) and sets credit status "rejected", so VA02 / job / monitor know the result. It does
**not** change the sales order – your existing `REJECT_STEP` (unchanged) cancels the order right after.

## Step 8 – Activate
Check (F8 / syntax) and activate the new version. Running workflows stay on the old version; new starts use
the new version.

## Step 9 – Event linkages (SWE2) – no change
`BUS2032 CREATED` and `BUS2032 CHANGED` → `WS99000010`, check function module `Z_FM_SD_WF_CHECK_CREDIT`.
The new logic is inside `ZCL_WF_SD_CREDIT->IS_START_ALLOWED` (change A1 in `CHANGES_TO_EXISTING_OBJECTS.md`):
for an order of the release cycle the workflow may start only after YSDA / YSDAX are complete.

**How the workflow starts without VA02:** YSDA / YSDAX → `ZCL_SD_SO_RELEASE->ON_ITEM_DECISION` → when the last
production line of a credit-blocked order is decided → `SAP_WAPI_CREATE_EVENT` BUS2032 / `CHANGED` with
event container element `SOLDTOPARTY` = VBAK-KUNNR → linkage → check FM → WS99000010. The start bindings
are filled as for a sales order save: `_EVT_OBJECT` → `SALES_ORDER_BOR`, `_EVT_OBJECT.SALESDOCUMENT` →
`SALES_ORDER`, `SOLDTOPARTY` → `BUSINESS_PARTNER`, `_EVT_CREATOR` → `_WF_INITIATOR` (the YSDA/YSDAX user).

## Step 10 – Test
1. SWELS → event trace on. Approve the last line of a credit-blocked order in YSDA → SWEL shows one BUS2032
   CHANGED with receiver WS99000010, status "Receiver started".
2. SWI1 → the workflow log shows `SO_REL_START` first, then your existing steps.
3. Final approval → `SO_REL_APPROVED` → lines approved in YSDA are CP (VA03), rejected lines CN.
4. Rejection → `SO_REL_REJECTED`, then `REJECT_STEP` → order cancelled as today.
5. Duplicate: start a second workflow for the same order (e.g. SWUE, event BUS2032 CHANGED) while the first
   runs → the second ends right after `SO_REL_START` (`REL_DUPLICATE = X`).
