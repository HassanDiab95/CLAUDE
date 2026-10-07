# Budget Forecast – Technical Design & Setup

Extension of the Budget Preparation application (`ZFI_BUDGET_PREPERATION` / `ZFI_BUDGET_PRE`).
Creators submit a **two-year forecast budget** per Company / Department (cost center).
The forecast is a **separate program** that does **not** use the Budget Preparation workflow.
It is started from new buttons on screen 0001 of the existing application.

| | |
|---|---|
| Technical Consultant | Hassan Diab |
| Functional Consultant | Ahmed Tawfik |
| Package | `ZFI` |
| Version | 1.0 – 07.10.2026 |

---

## 1. Requirement → implementation

| # | Requirement | Where / how |
|---|---|---|
| 1 | Header: Company, Department Code, Forecast Years (e.g. 2028-2029) | Screen 0100 of `ZFI_BUDGET_FORECAST`: `GS_HEAD-BUKRS`, `GS_HEAD-KOSTL` (+ text), listbox `GV_FCST_YEARS` |
| 1 | Item grid as in the Excel template | Table control `CT_FCST`: Seq., Budget Year, Dept. Code, Project Name, Description, Priority (Basis/Existing/Secondary), Project Budget, Currency, Opex/Capex, Project Type (Strategic/Operational), plus a total |
| 1.1 | Entry only for Budget Preparation **creators** | `VALIDATE_HEADER`: active, valid `ZBUD_CREATORS` row for the user **and that cost center** with a create role (`CRE`, `C&M`, `CMD`, `ALL`, same decode as `ROLE_TO_FLAGS`). The **Create Forecast** button is shown only when `GV_GLOB_CREATE = 'X'` |
| 1.2 | Years dropdown = next two years | `GET_FORECAST_WINDOW`: current year + `GC_YEAR_OFFSET` and the year after. Create mode offers only this one value and re-checks it on save |
| 2 | Dedicated modification screen | Transaction `ZFI_BUD_FCST_M` (same program, mode `M`), button **Change Forecast** |
| 2 | Max. **two** updates per submission | `ZFI_BUD_FCST_H-CHANGE_COUNT`; `CHECK_CHANGE_ALLOWED` + optimistic `UPDATE … WHERE CHANGE_COUNT = <old>` |
| 2 | Only the **creator** of the request may modify | `VALIDATE_HEADER` (modify) rejects anyone but `ERNAM`; the listbox only shows the user's own forecasts |
| 2 | No change once the year after creation starts | `CHECK_CHANGE_ALLOWED`: `SY-DATUM(4) > ERDAT(4)` → display only (see §6) |
| 3 | One consolidated report, Excel export | `ZFI_BUDGET_FORECAST_REP` / `ZFI_BUD_FCST_R`: SALV with totals per submission and a grand total, standard ALV spreadsheet export, plus the **Download directly to Excel (.xlsx)** checkbox |
| 3 | Report only for Final Reviewers + assistants | `CHECK_AUTHORIZATION` (`ZFI_BUD_WF_AGENT` level `FR`, or `ZFIBUD_ASSISTANT`). The **Forecast Report** button is shown only when `GV_GLOB_IS_FR = 'X'` (assistants included) |
| 4 | E-mail on submit (and on change) to all FR + assistants with header info | `SEND_NOTIFICATION`: HTML mail (Company, Cost Center Code + name, Forecast Years, item count, total, user, date/time). Sent to the SU01 e-mail address, or to the SAP inbox if the user has no address |
| 5 | No duplicate Company + Department + Years | Primary key `BUKRS, KOSTL, FYEAR_FROM, FYEAR_TO`. Checked on header entry (message 006 names the creator) and enforced again by the `INSERT` on save |
| – | Separate from the existing workflow | No `ZFI_BUD_WF_STAT`, no `ZCL_WF_FI_BUDGET` events. Separate tables, program and transactions |

---

## 2. Objects

### 2.1 Repository contents

| File | SAP object |
|---|---|
| `src/ZFI_BUDGET_FORECAST.abap` | Module pool `ZFI_BUDGET_FORECAST` (main program) |
| `src/ZFI_BUDGET_FCST_TOP.abap` | Include `ZFI_BUDGET_FCST_TOP` |
| `src/ZFI_BUDGET_FCST_F01.abap` | Include `ZFI_BUDGET_FCST_F01` (forms) |
| `src/ZFI_BUDGET_FCST_PBO.abap` | Include `ZFI_BUDGET_FCST_PBO` |
| `src/ZFI_BUDGET_FCST_PAI.abap` | Include `ZFI_BUDGET_FCST_PAI` |
| `src/ZFI_BUDGET_FORECAST_REP.abap` | Executable report `ZFI_BUDGET_FORECAST_REP` |
| `screens/ZFI_BUDGET_FORECAST_0100.txt` | Screen 0100 of `ZFI_BUDGET_FORECAST` (Screen Painter upload file) |
| `screens/ZFI_BUDGET_PREPERATION_0001.txt` | Updated screen 0001 of `ZFI_BUDGET_PREPERATION` (new buttons) |
| `existing_program_changes/ZFI_BUDGET_PREPERATION_changes.abap` | Code to add to `HIDE_BUTTONS_0001` and `USER_COMMAND_0001` |

### 2.2 Transactions (SE93)

| Tcode | Type | Program / screen | Text |
|---|---|---|---|
| `ZFI_BUD_FCST_C` | Dialog | `ZFI_BUDGET_FORECAST` / 0100 | Create Budget Forecast |
| `ZFI_BUD_FCST_M` | Dialog | `ZFI_BUDGET_FORECAST` / 0100 | Modify Budget Forecast |
| `ZFI_BUD_FCST_R` | Report (with selection screen) | `ZFI_BUDGET_FORECAST_REP` / 1000 | Budget Forecast Report |

The program reads `SY-TCODE` to choose between create and modify. Add the three transaction codes (`S_TCODE`) to the PFCG role(s) that already contain `ZFI_BUDGET_PRE`. The buttons call them `WITH AUTHORITY-CHECK`. The business-level authorization (creator / FR / assistant) is still checked from the Z tables, as in Budget Preparation.

---

## 3. Data Dictionary

### 3.1 Domains

| Domain | Type | Fixed values (value – text) |
|---|---|---|
| `ZFCST_PRIORITY` | CHAR 10 | `BASIS` – Basis, `EXISTING` – Existing, `SECONDARY` – Secondary |
| `ZFCST_BUD_TYPE` | CHAR 5 | `OPEX` – Opex, `CAPEX` – Capex |
| `ZFCST_PROJ_TYPE` | CHAR 12 | `STRATEGIC` – Strategic, `OPERATIONAL` – Operational |
| `ZFCST_AMOUNT` | DEC 15, 2 decimals (no sign) | – |
| `ZFCST_ITEM_NO` | NUMC 4 | – |
| `ZFCST_TEXT100` | CHAR 100, lower case | – |
| `ZFCST_TEXT255` | CHAR 255, lower case | – |

The three listboxes on the screen get their values from these fixed values. Change a value only here.

### 3.2 Data elements

| Data element | Domain | Field label (short / medium / long) |
|---|---|---|
| `ZFCST_YEAR_FROM` | `GJAHR` | From Yr / Forecast From / Forecast Year From |
| `ZFCST_YEAR_TO` | `GJAHR` | To Yr / Forecast To / Forecast Year To |
| `ZFCST_BUDGET_YEAR` | `GJAHR` | Bud. Year / Budget Year / Budget Year |
| `ZFCST_ITEM_NO` | `ZFCST_ITEM_NO` | Seq. / Sequence / Sequence |
| `ZFCST_PROJ_NAME` | `ZFCST_TEXT100` | Project / Project Name / Project Name |
| `ZFCST_PROJ_DESC` | `ZFCST_TEXT255` | Descr. / Project Description / Project Description |
| `ZFCST_PRIORITY` | `ZFCST_PRIORITY` | Priority / Project Priority / Project Priority |
| `ZFCST_AMOUNT` | `ZFCST_AMOUNT` | Amount / Project Budget / Project Budget |
| `ZFCST_BUD_TYPE` | `ZFCST_BUD_TYPE` | Opex/Capex / Opex / Capex / Operating / Capital Expenditure |
| `ZFCST_PROJ_TYPE` | `ZFCST_PROJ_TYPE` | Proj.Type / Project Type / Project Type |
| `ZFCST_CHANGE_CNT` | `INT1` | Updates / Updates Used / Number of Updates Used |

### 3.3 Table `ZFI_BUD_FCST_H` – Budget Forecast Header

Delivery class A, Display/Maintenance *Display only*, data class APPL1, size category 0.

| Field | Key | Data element | Notes |
|---|---|---|---|
| `MANDT` | X | `MANDT` | |
| `BUKRS` | X | `BUKRS` | check table `T001` |
| `KOSTL` | X | `KOSTL` | |
| `FYEAR_FROM` | X | `ZFCST_YEAR_FROM` | e.g. 2028 |
| `FYEAR_TO` | X | `ZFCST_YEAR_TO` | e.g. 2029 |
| `WAERS` | | `WAERS` | always SAR |
| `TOTAL_AMOUNT` | | `ZFCST_AMOUNT` | sum of the items, kept for the report and the e-mail |
| `CHANGE_COUNT` | | `ZFCST_CHANGE_CNT` | 0 after create, max. 2 |
| `ERNAM` | | `ERNAM` | creator, the only user who can modify |
| `ERDAT` | | `ERDAT` | |
| `ERZET` | | `ERZET` | |
| `AENAM` | | `AENAM` | |
| `AEDAT` | | `AEDAT` | |
| `AEZET` | | `AEZET` | use `UZEIT` if `AEZET` does not exist in your system |

Secondary index `Z01` on `MANDT, ERNAM`. The modify listbox and the button check read by creator.

### 3.4 Table `ZFI_BUD_FCST_I` – Budget Forecast Items

Same technical settings as the header.

| Field | Key | Data element | Notes |
|---|---|---|---|
| `MANDT` | X | `MANDT` | |
| `BUKRS` | X | `BUKRS` | foreign key to `ZFI_BUD_FCST_H` (key fields) |
| `KOSTL` | X | `KOSTL` | = "Department Code" column of the template |
| `FYEAR_FROM` | X | `ZFCST_YEAR_FROM` | |
| `FYEAR_TO` | X | `ZFCST_YEAR_TO` | |
| `ITEM_NO` | X | `ZFCST_ITEM_NO` | التسلسل |
| `BUDGET_YEAR` | | `ZFCST_BUDGET_YEAR` | سنة الميزانية – must be FYEAR_FROM or FYEAR_TO |
| `PROJ_NAME` | | `ZFCST_PROJ_NAME` | أسم المشروع |
| `PROJ_DESC` | | `ZFCST_PROJ_DESC` | وصف المشروع |
| `PRIORITY` | | `ZFCST_PRIORITY` | أولوية المشروع |
| `AMOUNT` | | `ZFCST_AMOUNT` | ميزانية المشروع |
| `WAERS` | | `WAERS` | SAR |
| `BUD_TYPE` | | `ZFCST_BUD_TYPE` | النفقات التشغيلية / الرأسمالية |
| `PROJ_TYPE` | | `ZFCST_PROJ_TYPE` | نوع المشروع |

Amounts are DEC (like `BUDGET_AMOUNT` in `ZFI_BUD_PREP_002`), so the screen needs no currency reference field. The currency is always SAR.

### 3.5 Message class `ZBUD_FCST` (SE91)

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

### 3.6 GUI status / title (SE41, program `ZFI_BUDGET_FORECAST`)

* **Status `GUI_0100`** (dialog status)
  * Function keys: `ENTER` (Enter), `SAVE` (Ctrl+S, save icon), `BACK` (F3), `EXIT` (Shift+F3), `CANCEL` (F12).
  * Set `BACK`, `EXIT`, `CANCEL` to function type **E** (exit command), as in `ZFI_BUDGET_PREPERATION`.
  * The other function codes come from screen pushbuttons and need no status entry: `PROCESS`, `OTHER`, `INSERT_LINE`, `DELETE_LINE`, `SEL_ALL`, `DESEL_ALL`.
* **Title `TITLE_0100`**: `&1 Budget Forecast` (filled with Create / Modify / Display).

### 3.7 Report texts (`ZFI_BUDGET_FORECAST_REP`)

* Text symbols: `B01` = *Selection*, `B02` = *Output*.
* Selection texts: `S_BUKRS` Company Code, `S_KOSTL` Cost Center, `S_FYEAR` Forecast Year From, `S_ERNAM` Created By, `P_XLSX` Download directly to Excel (.xlsx). Tick "Dictionary ref." for the first four.

---

## 4. Screens

### 4.1 `ZFI_BUDGET_FORECAST` 0100 (normal screen, 30 × 160)

The upload file is `screens/ZFI_BUDGET_FORECAST_0100.txt`. It uses the same Screen Painter format as the existing 0001/0100 downloads.
SE51 → program `ZFI_BUDGET_FORECAST`, screen `0100` → *Utilities → More Utilities → Upload*. Then open the layout, run *Check* and activate.

The file was generated by copying the element definitions of the existing screen 0100. If the upload is rejected, build the screen by hand using this layout:

```
Line 1  [Forecast Header ............................]  [Submission Information ...................]
Line 2   Company Code                    GS_HEAD-BUKRS*      Created By        GS_HEAD-ERNAM
Line 3   Department Code (Cost Center)   GS_HEAD-KOSTL*  GV_KTEXT   Created On  GS_HEAD-ERDAT GS_HEAD-ERZET
Line 4   Forecast Budget Years           GV_FCST_YEARS* (Listbox)   Last Changed By  GS_HEAD-AENAM
Line 5                                                             Last Changed On  GS_HEAD-AEDAT GS_HEAD-AEZET
Line 6                                                             Updates Used     GV_CHANGES_TEXT
Line 7   [GV_PROCEED_TO_ITEMS]  [Other Forecast]                   Total Forecast Amount GS_HEAD-TOTAL_AMOUNT GS_HEAD-WAERS
Line 10 [Forecast Items .............................................................................]
Line 11  [+] [-] [Select all] [Deselect all]
Line 13  Table control CT_FCST (sel. column GS_ITEM-SELECTED, line selection multiple, resizable)
         Seq. | Budget Year (LB) | Dept. Code | Project Name | Project Description | Project Priority (LB)
         | Project Budget | Curr. | Opex/Capex (LB) | Project Type (LB)
```
`*` = required, `LB` = dropdown *Listbox*.

| Element | Attributes |
|---|---|
| `GS_HEAD-BUKRS`, `GS_HEAD-KOSTL`, `GV_FCST_YEARS`, `GV_PROCEED_TO_ITEMS` (pushbutton, output field, FctCode `PROCESS`) | Group1 = `1` |
| `INSERT_LINE` (`@17@`), `DELETE_LINE` (`@18@`), `SEL_ALL` (`@4B@`), `DESEL_ALL` (`@4D@`) | Group1 = `2`, FctCode = element name |
| `OTHER_FCST` (FctCode `OTHER`) | Group1 = `3` |
| `GS_ITEM-ITEM_NO`, `GS_ITEM-KOSTL`, `GS_ITEM-WAERS`, all fields on the right block | Output only |
| `GS_ITEM-*` input columns | Input, **not** required (the program checks mandatory columns on save and puts the cursor on the field) |

The flow logic is part of the upload file. It is also listed here:

```abap
PROCESS BEFORE OUTPUT.
  MODULE STATUS_0100.
  MODULE CT_FCST_CHANGE_TC_ATTR.
  LOOP AT GT_ITEM INTO GS_ITEM WITH CONTROL CT_FCST
  CURSOR CT_FCST-CURRENT_LINE.
    MODULE CT_FCST_GET_LINES.
  ENDLOOP.
  MODULE SCREEN_EDITS_0100.
  MODULE GET_TEXTS.

PROCESS AFTER INPUT.
  MODULE EXIT_0100 AT EXIT-COMMAND.
  CHAIN.
    FIELD GS_HEAD-BUKRS.
    FIELD GS_HEAD-KOSTL.
    FIELD GV_FCST_YEARS.
    MODULE CHECK_HEADER.
  ENDCHAIN.
  LOOP AT GT_ITEM.
    CHAIN.
      FIELD GS_ITEM-BUDGET_YEAR.
      FIELD GS_ITEM-PROJ_NAME.
      FIELD GS_ITEM-PROJ_DESC.
      FIELD GS_ITEM-PRIORITY.
      FIELD GS_ITEM-AMOUNT.
      FIELD GS_ITEM-BUD_TYPE.
      FIELD GS_ITEM-PROJ_TYPE.
      MODULE CT_FCST_MODIFY ON CHAIN-REQUEST.
    ENDCHAIN.
    FIELD GS_ITEM-SELECTED MODULE CT_FCST_MARK ON REQUEST.
  ENDLOOP.
  MODULE USER_COMMAND_0100.
```

### 4.2 `ZFI_BUDGET_PREPERATION` 0001 (existing screen)

`screens/ZFI_BUDGET_PREPERATION_0001.txt` is the current screen 0001 with no existing element changed. It adds:

* a second frame `FCST_FRAME` "Budget Forecast" to the right of "Select Process" (screen width 29 → 62),
* pushbuttons `FCST_CREATE` (`@0Y@` Create Forecast), `FCST_CHANGE` (`@0Z@` Change Forecast), `FCST_REPORT` (`@AL@` Forecast Report). The function code of each button is the same as its name.

**Before uploading, download the current version** as a backup (SE51 → Utilities → Download).

---

## 5. Installation sequence

1. SE11: domains → data elements → tables `ZFI_BUD_FCST_H`, `ZFI_BUD_FCST_I` (+ index Z01) → activate.
2. SE91: message class `ZBUD_FCST`.
3. SE38/SE80: program `ZFI_BUDGET_FORECAST` (type M) and its four includes. Do not activate yet.
4. SE51: upload screen 0100 → check → activate.
5. SE41: status `GUI_0100`, title `TITLE_0100`. Activate the whole program.
6. SE38: report `ZFI_BUDGET_FORECAST_REP` + text symbols and selection texts. Activate.
7. SE93: transactions `ZFI_BUD_FCST_C`, `ZFI_BUD_FCST_M`, `ZFI_BUD_FCST_R`.
8. Existing program: apply `existing_program_changes/…`, upload screen 0001, activate.
9. PFCG: add the three transactions to the Budget Preparation role(s).
10. SCOT/SOST: check that mails from the client are sent (the notification uses BCS with *send immediately*).

---

## 6. Assumptions to confirm with the business

1. **Forecast years.** The mail says "next two years after the current calendar year", but every example says **2028-2029** (in 2026). The program follows the examples: first year = current year **+ 2**. To use 2027-2028 instead, set `GC_YEAR_OFFSET = 1` in `ZFI_BUDGET_FCST_TOP`.
2. **Modification period.** Rule used: *"once the year after the creation year starts, the creator can no longer change the forecast."* A forecast created in 2026 can be updated (max. twice) until 31.12.2026 and is display only from 01.01.2027. This is the same day the year window moves to 2029-2030.
3. **"Creator role"** means an active, currently valid `ZBUD_CREATORS` row **for the entered cost center** whose role allows *create* (`CRE`, `C&M`, `CMD`, `ALL`).
4. **E-mail recipients** = *all* active Final Reviewers (`ZFI_BUD_WF_AGENT`, `ZLEVEL = 'FR'`, any cost center) + *all* active assistants, as written in the requirement. To mail only the FR of the forecast's cost center, add `AND BUKRS = … AND KOSTL = …` in `GET_NOTIFICATION_RECIPIENTS`.
5. An e-mail is sent on **create and on each change**. The subject and body say which one it is (and "update n of 2").
6. A forecast cannot be deleted in this release. Saving a change with no items is rejected.

---

## 7. Test cases

| # | Scenario | Expected |
|---|---|---|
| 1 | User not in `ZBUD_CREATORS` opens `ZFI_BUD_FCST_C` | Popup "not authorized", program ends |
| 2 | Creator of CC 10005000 creates 1000 / 10005000 / 2028-2029 with 2 items | Saved, CHANGE_COUNT = 0, mail to all FR + assistants, back to screen 0001 |
| 3 | Same or another creator creates 1000 / 10005000 / 2028-2029 again | E006 "already exists (created by …)" on the header |
| 4 | Creator of CC A enters CC B (not assigned) | E005 |
| 5 | Item without priority / Opex-Capex / type / name, or amount 0 | Save blocked, cursor on the field, message 010 / 011 |
| 6 | Creator opens the forecast in `ZFI_BUD_FCST_M`, changes an amount, saves | Popup "update 1 of 2", saved, CHANGE_COUNT = 1, mail "changed (update 1 of 2)" |
| 7 | Second change | "update 2 of 2 – no further updates", saved |
| 8 | Third attempt | Opens display only with message 021, Save button hidden |
| 9 | Another user enters the same key in `ZFI_BUD_FCST_M` | E008 "Only the creator (…) can modify" |
| 10 | Creator opens a forecast created last year | Display only, message 022 |
| 11 | Save without any change | S014 "No changes to save", counter not increased |
| 12 | Two sessions of the creator save the same forecast | Second save gets S015, nothing overwritten |
| 13 | FR / assistant runs `ZFI_BUD_FCST_R` | All forecasts, subtotal per submission, grand total, ALV → Spreadsheet works; with *Download directly* an .xlsx is saved |
| 14 | Creator (not FR) runs `ZFI_BUD_FCST_R` | S023, program ends. The Forecast Report button is not shown on 0001 |
| 15 | FR user without SU01 e-mail | Mail arrives in the SAP Business Workplace inbox (SBWP) |
