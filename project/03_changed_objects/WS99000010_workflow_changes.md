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
| TS9xxxxxx3 | `SO_REL_REJECTED` – Release cycle: credit rejected | `CREDIT_REJECTED` | IV_VBELN, IV_NOTE (import) |

For `SO_REL_APPROVED`: tab *Temporary error* → retry 10 times every 15 minutes (the order may be open
in VA02 when production is released; after the retries the job `ZSD_SO_REL_RECONCILE` still releases it).

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
4. **Rejection branch** – after the rejection step (*REJECT_STEP*, after the decision note is read):
   - Activity, task `SO_REL_REJECTED`, binding `&SALES_ORDER&` → `IV_VBELN`, decision note → `IV_NOTE`
     (the same note the workflow already writes to the log via `ZCL_WF_NOTE_READER`).

Activate the new version. Running workflows stay on the old version; new starts use the new one.

## D. Event linkages (SWE2) – no change

`BUS2032 CREATED` and `BUS2032 CHANGED` → `WS99000010`, check function module `Z_FM_SD_WF_CHECK_CREDIT`.
The new logic is inside `ZCL_WF_SD_CREDIT->IS_START_ALLOWED` (see `ZCL_WF_SD_CREDIT_IS_START_ALLOWED.abap`).
