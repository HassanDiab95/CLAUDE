
# Budget Forecast (2-Year Forecast) – Technical Design & Setup (v2.1)

A **new, separate** application for the two-year forecast budget. It is attached to the Budget Preparation application (`ZFI_BUDGET_PREPERATION` / `ZFI_BUDGET_PRE`) **only through new buttons on its screen 0001**.

> **Nothing existing is changed or reused by name.**
> * The existing program `ZFI_BUDGET_FORECAST` and its cycle are **not touched**. The new programs, classes and transactions use their own prefix **`2YF`** (two-year forecast), e.g. `ZFI_BUD_2YF_ENTRY`, so no name collides with existing objects. The dictionary objects and the message class keep the names **already created** in the system: tables `ZFI_BUD_FCST_H/_I/_LOG`, domains and data elements `ZFCST_*`, message class `ZBUD_FCST`.
> * The existing screens of `ZFI_BUDGET_PREPERATION` (including screen 0100) are **not changed**. Only screen 0001 gets 3 new buttons.
> * The existing logic and workflow of Budget Preparation are **not changed**. The new forecast has its own tables, does not use the workflow, and only reads the existing role tables (`ZBUD_CREATORS`, `ZFI_BUD_WF_AGENT`, `ZFIBUD_ASSISTANT`).

## 0. Package contents – two separate parts

| Folder | What | You do |
|---|---|---|
| `01_NEW_OBJECTS/` | Everything new: interfaces and classes, the new module pool `ZFI_BUD_2YF_ENTRY` with its **new screen 0100**, report `ZFI_BUD_2YF_REPORT` | Create these as new objects (the DDIC objects and message class of section 3 are already created) |
| `02_CHANGES_TO_EXISTING_ZFI_BUDGET_PREPERATION/` | The **only** changes to the existing program: (1) screen 0001 with 3 extra buttons, (2) one block in `HIDE_BUTTONS_0001`, (3) three `WHEN` branches in `USER_COMMAND_0001` | Add these manually |

### New object names

| Kind | Name |
|---|---|
| Module pool (entry screen 0100) | `ZFI_BUD_2YF_ENTRY` + includes `ZFI_BUD_2YF_ENTRY_TOP`, `_C01`, `_PBO`, `_PAI` |
| Report | `ZFI_BUD_2YF_REPORT` |
| Transactions | `ZFI_BUD_2YF_C` (create), `ZFI_BUD_2YF_M` (modify), `ZFI_BUD_2YF_R` (report) |
| Tables | `ZFI_BUD_FCST_H` (header), `ZFI_BUD_FCST_I` (items), `ZFI_BUD_FCST_LOG` (change log) |
| Classes | `ZCL_FI_BUD_2YF`, `ZCL_FI_BUD_2YF_REPOSITORY`, `ZCL_FI_BUD_2YF_AUTH`, `ZCL_FI_BUD_2YF_NOTIFIER`, `ZCL_FI_BUD_2YF_REPORT` |
| Interfaces | `ZIF_FI_BUD_2YF_TYPES`, `ZIF_FI_BUD_2YF_REPOSITORY`, `ZIF_FI_BUD_2YF_AUTH`, `ZIF_FI_BUD_2YF_NOTIFIER` |
| Exception class | `ZCX_FI_BUD_2YF` |
| Message class | `ZBUD_FCST` |
| Domains / data elements | `ZFCST_*` |

The tables, domains, data elements and message class are already created with these names. For the programs, classes, interfaces and transactions, check in SE80 / SE24 / SE93 that the names are free. If one is taken, rename that object and search-and-replace it in the sources.

| | |
|---|---|
| Technical Consultant | Hassan Diab |
| Functional Consultant | Ahmed Tawfik |
| Package | `ZFI` |
| Version | 2.2 – 08.10.2026 (Arabic texts, action icons, corporate e-mail design) – see `CHANGES_v2.2.md` |

The full step-by-step guide with all source code is the Word document `TSD - Budget Forecast 2YF (ZFI_BUD_2YF).docx`.

---

## 1. Requirement → implementation

| # | Requirement | Where / how |
|---|---|---|
| 1 | Header: Company, Department Code, Forecast Years; item grid as in the Excel template | Screen 0100 of `ZFI_BUD_2YF_ENTRY` |
| 1.1 | Entry only for Budget Preparation **creators** | `ZCL_FI_BUD_2YF_AUTH->IS_CREATOR` (`ZBUD_CREATORS`, roles `CRE`, `C&M`, `CMD`, `ALL`) |
| 1.2 | Years dropdown = next two years | `ZCL_FI_BUD_2YF->GET_FORECAST_WINDOW` (current year + `C_YEAR_OFFSET`) |
| 2 | Modification screen | Transaction `ZFI_BUD_2YF_M`, button **Change Forecast** |
| 2 | Max. **two** updates | `CHECK_CHANGE_ALLOWED` + optimistic `UPDATE … WHERE CHANGE_COUNT = <old>` |
| 2 | Only the **creator** may modify | `VALIDATE_HEADER` / `CHECK_CHANGE_ALLOWED` |
| 2 | No change once the year after creation starts | `CHECK_CHANGE_ALLOWED` (message 022) |
| 3 | Consolidated report, Excel, FR + assistants only | `ZCL_FI_BUD_2YF_REPORT` / `ZFI_BUD_2YF_R` |
| 3 | **New:** change history on double-click | Every update writes `ZFI_BUD_FCST_LOG`; double-click in the report shows who changed it, the date, the time, the item, the field, the old value and the new value |
| 4 | E-mail to all FR + assistants on create / change | `ZCL_FI_BUD_2YF_NOTIFIER` |
| 5 | No duplicate Company + Department + Years | Primary key + `VALIDATE_HEADER` (message 006) |

---

## 2. Architecture (OOP)

```
 Screen 0001 (existing ZFI_BUDGET_PREPERATION)   new buttons -> ZFI_BUD_2YF_C / _M / _R
            |
 ZFI_BUD_2YF_ENTRY (module pool)        ZFI_BUD_2YF_REPORT (report)
   screen fields + LCL_SCREEN_0100           selection screen only
            |                                        |
            v                                        v
   ZCL_FI_BUD_2YF  (business object)      ZCL_FI_BUD_2YF_REPORT (ALV, double-click)
   rules, save, change log                           |
      |            |              |                   |
      v            v              v                   v
 ZIF_..._REPOSITORY  ZIF_..._AUTH  ZIF_..._NOTIFIER   (same interfaces)
 ZCL_..._REPOSITORY  ZCL_..._AUTH  ZCL_..._NOTIFIER
 Z tables + released CDS   role tables     BCS e-mail
```

| Object | Type | Responsibility |
|---|---|---|
| `ZIF_FI_BUD_2YF_TYPES` | Interface | Shared types and constants (max. changes, year offset, currency, modes, transaction codes) |
| `ZCX_FI_BUD_2YF` | Exception class | All errors as T100 messages of `ZBUD_FCST` (`IF_T100_DYN_MSG`), with the item field / line to place the cursor |
| `ZIF_FI_BUD_2YF_REPOSITORY` / `ZCL_FI_BUD_2YF_REPOSITORY` | Interface / class | Reads and writes the Z tables. Company and cost center data come from the released CDS views `I_CompanyCode`, `I_CostCenter`, `I_CostCenterText`. Never commits |
| `ZIF_FI_BUD_2YF_AUTH` / `ZCL_FI_BUD_2YF_AUTH` | Interface / class | Creator, Final Reviewer / assistant checks, list of e-mail recipients |
| `ZIF_FI_BUD_2YF_NOTIFIER` / `ZCL_FI_BUD_2YF_NOTIFIER` | Interface / class | HTML e-mail via BCS; addresses from `BAPI_USER_GET_DETAIL` |
| `ZCL_FI_BUD_2YF` | Class | **All business rules**: window, header and item validation, change rules, create, change, change log (field-level diff). Owns the LUW (`COMMIT` / `ROLLBACK`) |
| `ZCL_FI_BUD_2YF` test classes | ABAP Unit | 12 tests for the rules and the change log, with test doubles (no DB, no mail) |
| `ZCL_FI_BUD_2YF_REPORT` | Class | Consolidated ALV, Excel, double-click → change history popup |
| `ZFI_BUD_2YF_ENTRY` + includes `_TOP`, `_C01`, `_PBO`, `_PAI` | Module pool | Screen fields and the local controller `LCL_SCREEN_0100`. Modules contain one line each |
| `ZFI_BUD_2YF_REPORT` | Report | Selection screen and one call of `ZCL_FI_BUD_2YF_REPORT->RUN` |

### 2.1 Clean core and modern ABAP

What this design does:

* **No modification** of SAP standard objects. Everything is in custom Z objects. The existing Z program only gets two small blocks that call the new classes.
* **Released APIs instead of table reads:**
  * Company code and controlling area come from `I_CompanyCode` (instead of T001 and TKA02).
  * Cost center data comes from `I_CostCenter` and `I_CostCenterText` (instead of CSKS and CSKT).
  * The user's name and e-mail come from `BAPI_USER_GET_DETAIL` (instead of USR21 and ADR6).
  * The date and time come from `CL_ABAP_CONTEXT_INFO`.
* **Logic separated from the UI.** The classes have no dynpro code, so the same `ZCL_FI_BUD_2YF` could serve a future RAP / Fiori app.
* **Dependency injection and ABAP Unit.** Rules are tested without a database or mail system.
* **Modern syntax:**
  * inline declarations;
  * `VALUE`, `CORRESPONDING` (with `MAPPING` / `EXCEPT`), `COND`, `SWITCH`, `REDUCE` and `FOR`;
  * `xsdbool`, `line_exists` and table expressions;
  * string templates;
  * new Open SQL with `@` host variables and `INTO` at the end;
  * `RAISE EXCEPTION … MESSAGE`;
  * `LOOP AT SCREEN INTO`;
  * no `FORM`s and no `TABLES`.

Limits to be aware of:

* A module pool / SAP GUI screen is **classic UI**, not ABAP Cloud (tier 1). A fully cloud-ready version would be a RAP business object with a Fiori elements app. The class layer is ready for that, but the screen would be replaced.
* `CL_BCS` and `CL_GUI_FRONTEND_SERVICES` are not released for ABAP Cloud.
  * `CL_BCS` is isolated in `ZCL_FI_BUD_2YF_NOTIFIER`. On S/4HANA 2022+ it can be switched to the released `CL_BCS_MAIL_MESSAGE` in that class only.
  * `CL_GUI_FRONTEND_SERVICES` is used only for the optional direct .xlsx download.
* Set the ABAP language version of the classes to **Standard ABAP**.

### 2.2 Change history

On every successful update, `ZCL_FI_BUD_2YF->BUILD_CHANGE_LOG` compares the saved version with the new one and writes one `ZFI_BUD_FCST_LOG` line per difference:

| Case | CHG_IND | FIELD_TEXT | VALUE_OLD → VALUE_NEW |
|---|---|---|---|
| Item field changed (year, name, description, priority, amount, Opex/Capex, type) | `U` | field label from the DDIC | old → new value |
| Total forecast amount changed | `U` | Total amount label | old → new total |
| Item added | `I` | Item added | – → year / name / priority / amount / type |
| Item deleted | `D` | Item deleted | year / name / priority / amount / type → – |

Each line stores `CHANGE_NO` (update 1 or 2), `CHANGED_BY`, `CHANGED_ON` and `CHANGED_AT`. Items are compared by sequence number. When an item is deleted, the items after it are renumbered, so they can show as changed lines.

In the report, the user **double-clicks any line** of a forecast with *Updates Used* > 0. A popup opens with Update No., Changed By, Name, Date, Time, Item, Action, Field, Old Value and New Value. The popup can be sorted, filtered and exported like any ALV. A forecast that was never changed gives message 027.

---

## 3. Data Dictionary

### 3.1 Domains

| Domain | Type | Fixed values |
|---|---|---|
| `ZFCST_PRIORITY` | CHAR 10 | `BASIS` Basis, `EXISTING` Existing, `SECONDARY` Secondary |
| `ZFCST_BUD_TYPE` | CHAR 5 | `OPEX` Opex, `CAPEX` Capex |
| `ZFCST_PROJ_TYPE` | CHAR 12 | `STRATEGIC` Strategic, `OPERATIONAL` Operational |
| `ZFCST_CHG_IND` | CHAR 1 | `I` Item added, `U` Changed, `D` Item deleted |
| `ZFCST_AMOUNT` | DEC 15,2 | – |
| `ZFCST_ITEM_NO` | NUMC 4 | – |
| `ZFCST_TEXT100` | CHAR 100, lower case | – |
| `ZFCST_TEXT255` | CHAR 255, lower case | – |

### 3.2 Data elements

| Data element | Domain | Label |
|---|---|---|
| `ZFCST_YEAR_FROM` / `ZFCST_YEAR_TO` / `ZFCST_BUDGET_YEAR` | `GJAHR` | Forecast Year From / To / Budget Year |
| `ZFCST_ITEM_NO` | `ZFCST_ITEM_NO` | Sequence |
| `ZFCST_LOG_NO` | `ZFCST_ITEM_NO` | Log Line |
| `ZFCST_PROJ_NAME` | `ZFCST_TEXT100` | Project Name |
| `ZFCST_PROJ_DESC` | `ZFCST_TEXT255` | Project Description |
| `ZFCST_PRIORITY` | `ZFCST_PRIORITY` | Project Priority |
| `ZFCST_AMOUNT` | `ZFCST_AMOUNT` | Project Budget |
| `ZFCST_TOTAL_AMOUNT` | `ZFCST_AMOUNT` | Total Forecast Amount |
| `ZFCST_BUD_TYPE` | `ZFCST_BUD_TYPE` | Opex / Capex |
| `ZFCST_PROJ_TYPE` | `ZFCST_PROJ_TYPE` | Project Type |
| `ZFCST_CHANGE_CNT` | `INT1` | Updates Used / Update No. |
| `ZFCST_CHG_IND` | `ZFCST_CHG_IND` | Action |
| `ZFCST_FIELD_TEXT` | `ZFCST_TEXT100` | Changed Field |
| `ZFCST_VALUE_OLD` / `ZFCST_VALUE_NEW` | `ZFCST_TEXT255` | Old Value / New Value |

### 3.3 Tables (delivery class A, data class APPL1, size 0, display/maintenance with restrictions)

**`ZFI_BUD_FCST_H` – Forecast header.** Key: `MANDT`, `BUKRS`, `KOSTL`, `FYEAR_FROM`, `FYEAR_TO`. Other fields:

* `WAERS`
* `TOTAL_AMOUNT` (`ZFCST_TOTAL_AMOUNT`)
* `CHANGE_COUNT` (`ZFCST_CHANGE_CNT`)
* `ERNAM`, `ERDAT`, `ERZET`
* `AENAM`, `AEDAT`, `AEZET` (use `UZEIT` if `AEZET` does not exist)

Add index `Z01` on `MANDT, ERNAM`.

**`ZFI_BUD_FCST_I` – Forecast items.** Key: `MANDT`, `BUKRS`, `KOSTL`, `FYEAR_FROM`, `FYEAR_TO`, `ITEM_NO`. Other fields:

* `BUDGET_YEAR`
* `PROJ_NAME`, `PROJ_DESC`
* `PRIORITY`
* `AMOUNT`, `WAERS`
* `BUD_TYPE`, `PROJ_TYPE`

**`ZFI_BUD_FCST_LOG` – Forecast change log (new).** Key: `MANDT`, `BUKRS`, `KOSTL`, `FYEAR_FROM`, `FYEAR_TO`, `CHANGE_NO` (`ZFCST_CHANGE_CNT`), `LOG_NO` (`ZFCST_LOG_NO`). Other fields:

* `ITEM_NO` (`ZFCST_ITEM_NO`)
* `CHG_IND` (`ZFCST_CHG_IND`)
* `FIELDNAME` (`FIELDNAME`), `FIELD_TEXT` (`ZFCST_FIELD_TEXT`)
* `VALUE_OLD` (`ZFCST_VALUE_OLD`), `VALUE_NEW` (`ZFCST_VALUE_NEW`)
* `CHANGED_BY` (`AENAM`), `CHANGED_ON` (`AEDAT`), `CHANGED_AT` (`AEZET` or `UZEIT`)

### 3.4 Message class `ZBUD_FCST`

| No | Text |
|---|---|
| 001 | Company code &1 does not exist |
| 002 | Cost center &1 does not exist in controlling area &2 |
| 003 | Select the forecast budget years from the list |
| 004 | Forecasts can only be created for the years &1 |
| 005 | You are not authorized to create forecasts for cost center &1 |
| 006 | Forecast &1 / &2 / &3 already exists (created by &4) |
| 007 | No forecast found for &1 / &2 / &3 |
| 008 | Only the creator of this forecast (&1) can modify it |
| 009 | Enter at least one forecast item |
| 010 | Item &1: &2 is required |
| 011 | Item &1: the project budget must be greater than zero |
| 012 | Forecast &1 / &2 / &3 submitted successfully |
| 013 | Forecast updated successfully (update &1 of &2) |
| 014 | No changes to save |
| 015 | The forecast was changed in another session; open it again |
| 016 | Error while saving the forecast; no data was changed |
| 018 | Data saved, but the notification e-mail failed: &1 |
| 019 | Action cancelled |
| 020 | Updates used: &1 of &2 - the forecast can still be changed |
| 021 | Maximum of &1 updates reached - the forecast is display only |
| 022 | Forecasts can only be changed during their creation year (&1) |
| 023 | You are not authorized for the consolidated forecast report |
| 024 | No forecasts found for the selection |
| 025 | Item &1: budget year must be &2 or &3 |
| 026 | The forecast is display only; changes cannot be saved |
| 027 | Forecast &1 / &2 / &3 has not been changed - no change history |

### 3.5 GUI status / title (program `ZFI_BUD_2YF_ENTRY`)

* Status `GUI_0100`:
  * `ENTER`, `SAVE` (Ctrl+S), `BACK` (F3), `EXIT` (Shift+F3), `CANCEL` (F12).
  * `BACK`, `EXIT` and `CANCEL` are of type **E**.
* Title `TITLE_0100`: `&1` (the Arabic title text comes from the program).

### 3.6 Report texts

* Text symbols: `B01` Selection, `B02` Output.
* Selection texts:
  * `S_BUKRS`, `S_KOSTL`, `S_FYEAR` and `S_ERNAM` use the dictionary reference.
  * `P_XLSX` = Download directly to Excel (.xlsx).

---

## 4. Screens

* **New** screen 0100 of the new program `ZFI_BUD_2YF_ENTRY`: upload `01_NEW_OBJECTS/screens/ZFI_BUD_2YF_ENTRY_0100.txt` in SE51. The flow logic is also in `ZFI_BUD_2YF_ENTRY_0100_flowlogic.txt`. The existing screen 0100 of `ZFI_BUDGET_PREPERATION` is **not** touched.
* **Existing** screen 0001 of `ZFI_BUDGET_PREPERATION`: `02_CHANGES_TO_EXISTING_ZFI_BUDGET_PREPERATION/ZFI_BUDGET_PREPERATION_0001_with_forecast_buttons.txt`.
  * It is your current screen 0001 unchanged, plus frame `FCST_FRAME` and buttons `FCST_CREATE`, `FCST_CHANGE`, `FCST_REPORT` to the right of "Select Process".
  * Download a backup first.
  * You can also add the frame and 3 buttons by hand instead (function code = element name).

## 5. Installation sequence

**Part A – new objects (`01_NEW_OBJECTS`)**

1. **SE11:** domains, data elements and tables `ZFI_BUD_FCST_H`, `ZFI_BUD_FCST_I`, `ZFI_BUD_FCST_LOG` are **already created**. Only compare them with section 3 (field names and types must match the code).
2. **SE91:** message class `ZBUD_FCST` is **already created**. Check that messages 001–027 of section 3.4 exist (027 is the newest one, for the change history).
3. **SE24 / ADT**, in this order:
   1. `ZIF_FI_BUD_2YF_TYPES`
   2. `ZCX_FI_BUD_2YF`
   3. `ZIF_FI_BUD_2YF_REPOSITORY`, `_AUTH`, `_NOTIFIER`
   4. `ZCL_FI_BUD_2YF_REPOSITORY`, `_AUTH`, `_NOTIFIER`
   5. `ZCL_FI_BUD_2YF` (+ test classes)
   6. `ZCL_FI_BUD_2YF_REPORT`

   Activate them together, then run the unit tests.
4. **Module pool** `ZFI_BUD_2YF_ENTRY`:
   1. Create the program with includes `_TOP`, `_C01`, `_PBO`, `_PAI`.
   2. Upload the new screen 0100.
   3. Create status `GUI_0100` and title `TITLE_0100`.
   4. Activate.
5. **Report** `ZFI_BUD_2YF_REPORT`: add its text symbols and selection texts, then activate.
6. **SE93:**
   * `ZFI_BUD_2YF_C` and `ZFI_BUD_2YF_M`: dialog transactions, `ZFI_BUD_2YF_ENTRY` / 0100.
   * `ZFI_BUD_2YF_R`: report transaction, `ZFI_BUD_2YF_REPORT`.
   * Test the three transactions directly before connecting them.

**Part B – connect to the existing program (`02_CHANGES_TO_EXISTING_ZFI_BUDGET_PREPERATION`)**

7. Screen 0001: add the frame and 3 buttons (upload or by hand).
8. `ZFI_BUDGET_PREPER_INCLUDE_PBO` → `HIDE_BUTTONS_0001`: paste `1_PBO_add_to_HIDE_BUTTONS_0001.abap` before `ENDMODULE`.
9. `ZFI_BUDGET_PREPER_INCLUDE_PAI` → `USER_COMMAND_0001`: paste `2_PAI_add_to_USER_COMMAND_0001.abap` after `WHEN 'REPORT_BUD'`.
10. Activate `ZFI_BUDGET_PREPERATION`. Nothing else in it changes.

**Part C – basis**

11. **PFCG:** add the 3 transactions to the Budget Preparation role(s). **SU01 / SCOT:** e-mail addresses and the SMTP node.

## 6. Assumptions to confirm

1. **Forecast years** = current year + 2 (2028-2029 in 2026). This is the constant `ZIF_FI_BUD_2YF_TYPES=>C_YEAR_OFFSET`.
2. **Changes** are allowed only in the creation year, max. 2 per forecast, and only by the creator.
3. **E-mail** goes to all active Final Reviewers and assistants, on create and on each change.
4. **Change history** is available from the first update on, not only after the second.
5. Amounts are DEC 15,2 in SAR. Deleting a forecast is not in scope.

## 7. Test cases

| # | Scenario | Expected |
|---|---|---|
| 1 | Non-creator starts `ZFI_BUD_2YF_C` | Popup, program ends |
| 2 | Creator creates 1000 / 10005000 / 2028-2029 | Saved, mail sent |
| 3 | Same combination again | E006 |
| 4 | Cost center not assigned | E005 |
| 5 | Missing mandatory column / amount 0 | Cursor on the field, 010 / 011 |
| 6 | 1st change (amount of item 1) | "update 1 of 2", 2 log lines (item amount, total) |
| 7 | 2nd change (add item 3, delete item 2) | "update 2 of 2", log lines I / D / U |
| 8 | 3rd attempt | Display only, 021 |
| 9 | Other user in `ZFI_BUD_2YF_M` | E008 |
| 10 | Forecast from last year | Display only, 022 |
| 11 | Save without change | 014, no log |
| 12 | Parallel save | 015 |
| 13 | FR runs `ZFI_BUD_2YF_R`, double-clicks a changed forecast | Popup with all log lines of updates 1 and 2: user, name, date, time, field, old / new |
| 14 | Double-click an unchanged forecast | Message 027 |
| 15 | Non-FR runs `ZFI_BUD_2YF_R` | 023 |
| 16 | ABAP Unit on `ZCL_FI_BUD_2YF` | 12 tests green |
