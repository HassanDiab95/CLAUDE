# Project – Part 3 (uploaded 2026-10-14)

| File | What it is |
|---|---|
| `ZCL_WF_SD_CREDIT.abap.txt` | Main helper for WS99000010: order/partner/credit/overdue data, approver ranges, order lock table ZSD_WF_SO, start check (IS_START_ALLOWED / CHECK_SO_BLOCK), kill running workflow + close open logs |
| `ZCL_WF_LOG_EX.abap.txt` | Approval log for the credit exceed branch (ZWF_LOG_EX_H / ZWF_LOG_EX_I, number range ZCM_LOG_EX) |
| `ZCL_WF_NOTE_READER.abap.txt` | Reads the approver's decision note from the work item attachment (SOFM) |
| `MV45AFZZ_enhancements.abap.txt` | Pasted in chat: enhancements in USEREXIT_DELETE_DOCUMENT (kill on delete), USEREXIT_READ_DOCUMENT (block VA02 while workflow runs → VA03), and ZEN_CMEXOD_KILL_WORKFLOW (kill on change; host FORM not included in the paste) |

Uploaded files are stored exactly as uploaded (only renamed).
