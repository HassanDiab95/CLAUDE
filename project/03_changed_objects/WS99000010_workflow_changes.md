# WS99000010 – workflow changes (SWDD)

Three new background steps call `ZCL_WF_SD_SO_REL_STEP`. The approval levels, mails, logs and the
existing classes stay as they are.

## A. Create the three standard tasks (PFTC)

For each task: *Object category* **ABAP Class**, *Object type* `ZCL_WF_SD_SO_REL_STEP`,
*Synchronous object method*, *Background processing* ticked, *General task* (Additional data →
Agent assignment → General task).

| Task (new number) | Short text | Method | Task container (from the method) |
|---|---|---|---|
| TS9xxxxxx1 | `SO_REL_START` – Release cycle: credit started | `CREDIT_STARTED` | IV_VBELN, IV_WI_ID (import), EV_DUPLICATE (export) |
| TS9xxxxxx2 | `SO_REL_APPROVED` – Release cycle: credit approved | `CREDIT_APPROVED` | IV_VBELN (import) |
| TS9xxxxxx3 | `SO_REL_REJECTED` – Release cycle: credit rejected → cancel order | `CREDIT_REJECTED` | IV_VBELN, IV_NOTE (import) |

For `SO_REL_APPROVED` **and** `SO_REL_REJECTED`: tab *Temporary error* → retry 10 times every 15 minutes
(the order may be open in VA02 when production is released / the order is cancelled; after the retries the
job `ZSD_SO_REL_RECONCILE` still does it).

## B. Workflow container (SWDD → Container)

| Element | Type | Use |
|---|---|---|
| `REL_DUPLICATE` | XFELD | result of the first step |

## C. Steps to insert (SWDD → new version of WS99000010)

1. **Very first step after the workflow start** (before "Check Blocked Flag"):
   - Activity, task `SO_REL_START`, *Background step*.
   - Binding workflow → task: `&SALES_ORDER&` → `IV_VBELN`; the ID of this workflow → `IV_WI_ID`
     (system container element `_WORKITEM`, attribute ID – expression `&_WORKITEM.ID&`; pick it with F4
     in the binding editor, the attribute name can differ by release).
   - Binding task → workflow: `EV_DUPLICATE` → `&REL_DUPLICATE&`.
2. **Directly after it**: Condition step `&REL_DUPLICATE& = X`.
   - *True*: step type **Process Control** → function **Cancel workflow** (or *Complete workflow*) –
     another workflow already runs for this order, this one must end.
   - *False*: continue with the existing first step ("Check Blocked Flag").
3. **Final approval branch** – after the step that releases the SAP credit block (the end of the
   *CHECK_FINAL_APPROVAL* = true path, after "Approve Release Sales Order"):
   - Activity, task `SO_REL_APPROVED`, binding `&SALES_ORDER&` → `IV_VBELN`.
   - It must come **after** the credit block release, so CN → CP happens only when the credit is
     really approved.
   - It converts **only the lines of the release plan** (approved in YSDA/YSDAX, fixed when the workflow
     started); lines rejected in YSDA/YSDAX stay CN.
4. **Rejection branch** – after the rejection step (*REJECT_STEP*, after the decision note is read).
   This step **cancels the order**: every open line gets the rejection reason from TVARVC `ZSD_SO_REL_REJ_ABGRU`
   (lines already rejected in YSDA/YSDAX keep their reason 63).
   - Activity, task `SO_REL_REJECTED`, binding `&SALES_ORDER&` → `IV_VBELN`, decision note → `IV_NOTE`
     (the same note the workflow already writes to the log via `ZCL_WF_NOTE_READER`).

Activate the new version. Running workflows stay on the old version; new starts use the new one.

## D. Event linkages (SWE2) – no change

**How the workflow starts without VA02:** YSDA / YSDAX → `ZCL_SD_SO_RELEASE->ON_ITEM_DECISION` → when the last
production line of a credit-blocked order is decided → `RAISE_START_EVENT` → `SAP_WAPI_CREATE_EVENT`
BUS2032 / `CHANGED` with event container element `SOLDTOPARTY` = VBAK-KUNNR → linkage below → check FM →
WS99000010. The start bindings of the workflow are filled exactly as for a sales order save:
`_EVT_OBJECT` → `SALES_ORDER_BOR`, `_EVT_OBJECT.SALESDOCUMENT` → `SALES_ORDER`, `SOLDTOPARTY` →
`BUSINESS_PARTNER`, `_EVT_CREATOR` → `_WF_INITIATOR` (the YSDA/YSDAX user).

Test in SWEL (event trace on, `SWELS`): approve the last line in YSDA → one BUS2032 CHANGED entry with
receiver WS99000010 and status "Receiver started".

`BUS2032 CREATED` and `BUS2032 CHANGED` → `WS99000010`, check function module `Z_FM_SD_WF_CHECK_CREDIT`.
The new logic is inside `ZCL_WF_SD_CREDIT->IS_START_ALLOWED` (change A1 in `CHANGES_TO_EXISTING_OBJECTS.md`).
