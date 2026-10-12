# ZBP_COMMENTS_UPLOAD – Business Partner Comments Upload

Uploads the **Comments** field of a Business Partner (Tcode `BP` → Address →
Communication → *Comments*, table `ADRCT-REMARK`) from an Excel file. The update
goes through the standard BAPI `BAPI_BUPA_ADDRESS_CHANGE` (table `BAPIADREM`).

## Objects

| Object | Type | Purpose |
|---|---|---|
| `ZBP_COMMENTS_UPLOAD` | Executable program | Selection screen and entry point |
| `ZBP_COMMENTS_UPLOAD_CLS` | Include | Local classes and ABAP Unit tests |
| `BP_Comments_Upload_Template.xlsx` | Excel template | Upload file layout |

## Design (OOP / clean core)

| Class / Interface | Responsibility |
|---|---|
| `lif_types` | Shared types and status constants |
| `lcx_upload_error` | Class-based exception |
| `lif_file_reader` / `lcl_frontend_file` | Reads the file from the PC (F4 dialog plus binary upload) |
| `lcl_excel_parser` | Parses the `.xlsx` (`CL_FDT_XL_SPREADSHEET`) into upload records |
| `lif_bp_address_api` / `lcl_bp_address_api` | Wraps the standard BAPIs: `BAPI_BUPA_ADDRESSES_GET`, `BAPI_BUPA_ADDRESS_GETDETAIL`, `BAPI_BUPA_ADDRESS_CHANGE`, `BAPI_TRANSACTION_COMMIT/ROLLBACK` |
| `lcl_comment_updater` | Business logic: validation, insert or update of the comment, commit or rollback per BP |
| `lcl_result_view` | Shows the result log in SALV |
| `lcl_app` | Controller |
| `ltc_comment_updater` / `ltd_bp_address_api` | ABAP Unit tests with a test double (no database changes) |

- No modifications or enhancements to SAP standard. It uses only standard BAPIs
  and APIs, and all calls to non-released APIs sit behind interfaces.
- It uses new ABAP syntax: inline declarations, `NEW`, `VALUE`, `COND`,
  `CONV`, table expressions, string templates and `ALPHA = IN`.
- Each BP gets its own LUW, so one failing line doesn't block the others.

## Excel layout

The program reads the first worksheet. Row 1 is the header and is skipped
when *Skip header* is ticked.

| Column | Content | Mandatory |
|---|---|---|
| A | Business Partner number, e.g. `20000000` | Yes |
| B | Comments (max. 50 characters) | Yes |
| C | Language, ISO 2-character code (e.g. `EN`, `AR`). Defaults to the logon language | No |

If no comment exists yet for that language it is inserted (`UPDATEFLAG = 'I'`).
If one already exists it is overwritten (`'U'`).

## Selection screen

| Parameter | Meaning |
|---|---|
| `P_FILE` | Excel file (F4 opens the file dialog) |
| `P_HEAD` | Skip the header row (default: on) |
| `P_TEST` | Test run. The BAPI is called and then rolled back (default: on) |

### Text elements to maintain (SE38 → Goto → Text elements)

Text symbols:

| ID | Text |
|---|---|
| `B01` | Upload parameters |
| `F01` | Select Excel file |
| `E01` | No data found in the Excel file |
| `E02` | Business Partner number is missing |
| `M01` | Comment updated successfully |
| `M02` | Test run – comment validated, not saved |

Selection texts: `P_FILE` = *Excel file*, `P_HEAD` = *Skip header row*,
`P_TEST` = *Test run (no update)*.

## Test case – DEV client 110

1. Create the program and include in SE38 (or pull with abapGit), maintain the
   text elements, then activate.
2. Run the unit tests: SE80 → program → *Execute → Unit Tests* (Ctrl+Shift+F10).
3. Fill the template with BP `20000000` and a comment.
4. Run with **Test run = X** and check the result list (yellow = validated).
5. Run with **Test run = blank** and check the result list (green = saved).
6. Open Tcode `BP` → `20000000` → Address → Communication → *Comments* and
   check the value. Change documents are written by the standard.

## Estimation

| Activity | Effort (hours) |
|---|---|
| Analysis and technical design | 2 |
| Development (upload, parsing, BAPI wrapper, logic, ALV log) | 8 |
| ABAP Unit tests | 2 |
| Unit test in DEV 110 and fixes | 3 |
| Technical documentation and transport | 1 |
| **Total** | **16 h (≈ 2 man-days)** |

Support for the functional test (FUT/UAT) isn't included and is estimated at
about 0.5 day if needed.
