# YSDA / YSDAX – conversion to OOP, clean core and new ABAP syntax

The logic is converted **1:1**: the same selection, the same checks, the same texts and colours, the same
database updates, BAPI calls, commits, messages and log entries, in the same order. Only the structure and
the syntax change. Screens 0099 / 0100, GUI status, titles, transaction codes YSDA / YSDAX, the DDIC
structures `YSP_MTOSO_APPROVE` / `YSP_MTOSO_APPROVE_CX` and the tables `ZSOAPPROVAL`, `ZAPPROVEUSER` and
`YSP_MTOSO_LOG` stay as they are.
**No TVARVC entry** is needed for YSDA / YSDAX: plants, item categories, order types and texts stay
constants in the code, as before.

Status: DRAFT – not compiled / not tested in SAP.

## 1. Files

| Folder | File | What it is |
|---|---|---|
| `YSDA/old` | `YSP_MTOSO_APPROVE_OLD_all_includes.abap` | old YSDA code (all 9 includes, as uploaded) |
| `YSDA/new` | `YSP_MTOSO_APPROVE.abap` | main program – only the 3 INCLUDE lines |
| `YSDA/new` | `YSP_MTOSO_APPROVE_TOP.abap` | global data (only the screen fields), types, class definitions |
| `YSDA/new` | `YSP_MTOSO_APPROVE_C01.abap` | class implementations – all the logic |
| `YSDA/new` | `YSP_MTOSO_APPROVE_M01.abap` | PBO / PAI modules – one line each, they call the class |
| `YSDAX/old` | `YSP_MTOSO_APPROVE_CX_OLD_all_includes.abap` | old YSDAX code (all 9 includes, as uploaded) |
| `YSDAX/new` | `YSP_MTOSO_APPROVE_CX.abap` | main program – only the 3 INCLUDE lines |
| `YSDAX/new` | `YSP_MTOSO_APPROVE_CX_TOP.abap` | global data, types, class definitions |
| `YSDAX/new` | `YSP_MTOSO_APPROVE_CX_C01.abap` | class implementations |
| `YSDAX/new` | `YSP_MTOSO_APPROVE_CX_M01.abap` | PBO / PAI modules |

## 2. How to apply (per program, SE80)

1. Create a workbench request, e.g. "YSDA / YSDAX OOP conversion – no functional change".
2. Download a backup of the program: SE38 → Utilities → More Utilities → Upload/Download → Download, or
   keep the files in the `old` folder.
3. Create the new includes in the module pool (SE80 → program → Create → Include):
   - YSDA: `YSP_MTOSO_APPROVE_C01` and `YSP_MTOSO_APPROVE_M01`. The include `YSP_MTOSO_APPROVE_TOP` already
     exists – replace its source with the new one.
   - YSDAX: `YSP_MTOSO_APPROVE_CX_TOP`, `YSP_MTOSO_APPROVE_CX_C01` and `YSP_MTOSO_APPROVE_CX_M01`.
4. Paste the new source into each include.
5. Replace the main program source with the new main program. It contains only the 3 `INCLUDE` lines.
6. Activate all objects together (main program + 3 includes).
7. **Screens: no change.** The flow logic calls the same modules as before (`STATUS_0099`, `USER_COMMAND_0099`,
   `USER_COMMAND_0099_EXIT`, `STATUS_0100`, `USER_COMMAND_0100`, `USER_COMMAND_0100_EXIT`). Their names
   are unchanged; they now live in the `_M01` include. The screen fields `BUKRS`, `DATEV_F`, `DATEV_T` stay
   global, with the same names and types, in the `_TOP` include. **GUI status / titles / transactions:** no change.
8. Test (part 6). After the test, delete the old includes, which are no longer used:
   - YSDA: `YSP_MTOSO_APPROVE_STATUS_01O01`, `_USER_COMMI01`, `_SCREEN_STF01`, `_APPROVE_FF01`,
     `_REJECT_FUF01`, `_STATUS_00O01`, `_USER_COMMI02`, `_EXECUTEF01`
   - YSDAX: `YSP_MTOSO_APP_TOP_CX`, `YSP_MTOSO_APP_STATUS_01O01_CX`, `YSP_MTOSO_APP_USER_COMMI01_CX`,
     `YSP_MTOSO_APP_SCREEN_STF01_CX`, `YSP_MTOSO_APPROVE_FF01_CX`, `YSP_MTOSO_APP_REJECT_FUF01_CX`,
     `YSP_MTOSO_APP_STATUS_00O01_CX`, `YSP_MTOSO_APP_USER_COMMI02_CX`, `YSP_MTOSO_APP_EXECUTEF01_CX`

## 3. Old → new

| Old (FORM / MODULE / data) | New |
|---|---|
| ~40 global variables, header-line tables | only `BUKRS`, `DATEV_F`, `DATEV_T` (screen) + `GO_APP`; the rest are class attributes or local variables |
| `MODULE STATUS_0100` – grid, field catalog, toolbar, layout | `LCL_VIEW->SHOW` (+ `BUILD_FIELDCAT`, `BUILD_TOOLBAR_EXCLUDE`) |
| `FORM SCREEN_START` | `LCL_APP->SCREEN_START` → `LOAD_ROWS` → per row `SET_PROFIT`, `SET_CREDIT`, `SET_APPROVAL`, `SET_CONFIGURATION` (YSDA also `SET_FIGURES`; YSDAX also `SET_CONTRIBUTION`, `HAS_STOCK`) |
| YSDA: Z8 loop at the end of `SCREEN_START` (T00005055) | `LCL_APP->REJECT_FI_NOT_APPROVED` |
| `FORM APPROVE_FUN` | `LCL_APP->APPROVE` |
| `FORM REJECT_FUN` | `LCL_APP->REJECT` |
| `WHEN 'DISPLAY'` (VA03) | `LCL_APP->DISPLAY_ORDERS` |
| `FORM EXECUTE` | `LCL_APP->EXECUTE` |
| `SELECT SINGLE ZPOSNUM FROM ZAPPROVEUSER` (3 copies) | `LCL_APP->GET_USER_POSITION` |
| `SELECT ETENR FROM VBEP ... APPEND LT_SCHDL` (2–3 copies) | `LCL_APP->ADD_CP_SCHEDULE_LINES` |
| log block `WA_LOG-... INSERT YSP_MTOSO_LOG` (3 copies) | `LCL_APP->WRITE_LOG` |
| colour block `COLOR-COL = '6' ... APPEND COLN TO COLTAB` (12 copies) | `LCL_APP->ADD_COLOR` |
| `FLAG` | `MV_LOADED` |
| `SO_TAB` / `SO_WA` | `MT_OUT` / local `LS_ROW` |

New syntax used: inline declarations, `NEW #( )`, `VALUE #( )`, `CORRESPONDING #( )`, `xsdbool( )`, strict
Open SQL with `@` host variables, `SELECT ... INTO TABLE` instead of `SELECT ... ENDSELECT`, `SELECT SUM( )`,
functional method calls, constants instead of literals, typed internal tables (no header lines, no `OCCURS`,
no `TABLES` statement).

## 4. Old behaviour kept 1:1 (please read – these look like bugs)

You asked not to change the logic, so these points behave exactly as before. Each one is marked in the code
with "as in the old code".

| # | Where | What happens (old and new) | Fixed by REQ1? |
|---|---|---|---|
| 1 | APPROVE / REJECT / YSDA Z8 step | The BAPI tables (`ORDER_ITEM_IN`, schedule lines, `RETURN`) are not cleared between the selected rows. With 2+ rows in one click, the rows of the first order are sent again for the next order, and the messages of earlier rows are shown again. | yes – C2 / C6 / D2 / D5 |
| 2 | approval record creation | `APPRV_WA` (now `MS_APPRV`) still holds the last row of the previous APPROVE. The first new `ZSOAPPROVAL` row created after an approval can inherit `SD_APPROVE` / dates from it. | no – one line `CLEAR ms_apprv.` at the start of `SET_APPROVAL`'s "first time" branch fixes it |
| 3 | log | `WA_LOG-NOTE` (now `MS_LOG-NOTE`) is never cleared – a log row can carry the BAPI message of an earlier action. | yes – C2 / C6 |
| 4 | APPROVE | If the `ZSOAPPROVAL` row is missing, `SD_APPROVE` / `FI_APPROVE` keep the values of the previous row. | partly – C2 |
| 5 | YSDAX selection | If `KEKO` / `KEPH` has no entry for a line, the contribution margin uses the cost of the previous line. | no |
| 6 | YSDA APPROVE | FI approval alone sets the schedule lines to CP and clears Z8 (see investigation document). | yes – C3 / C4 |
| 7 | YSDA selection | Every display of the list sets Z8 on all lines that FI has not approved. | no (by design, T00005055) |
| 8 | log | `LOG_NUMBER` = `COUNT(*) + 1` – two users at the same second can get the same number (the second INSERT fails). | no |
| 9 | APPROVE | `COMMIT WORK AND WAIT` followed by `BAPI_TRANSACTION_COMMIT` (double commit, harmless). | no |
| 10 | field catalog | The field name `'Posnr'` is lower case, as in the old code. | no |

## 5. Removed – no effect on the logic

- **Class `LCL_EVENT_RECEIVER`:** it was never instantiated and `SET HANDLER` was commented out. Its hotspot and
  double-click methods contained `BREAK-POINT`.
- **Debug statements:** `BREAK MSALAH` (user breakpoint) and `SET CURSOR FIELD 'BAR_TXT'` (the field does not exist on screen 0100).
- **Empty FORM `SEARCH`:** all of its code was commented out. The function code `SEARCH` still exists and does nothing, as before.
- **Unused global data:** `ITAB`, `IT_SO_TEMP`, `G_GRID`, `FROM_DATE`, `TO_DATE`, `DOC_NUMBER`, `BUKRS1`, `OK_CODE`,
  `FI_APPROVE_IND_PROFIT`, `FI_APPROVE_IND_CREDIT` (only written, never read), `TABLES ZSOAPPROVAL`, `TA_LOG`,
  `LT_EVENTS`, `L_VALID` and others.
- **Commented-out old code blocks.**

## 6. Small technical differences (same result)

| Old | New | Note |
|---|---|---|
| `IF bukrs = 1200` (number) | `IF mv_plant = '1200'` (text) | same for every numeric plant; the old compare would dump on a non-numeric plant |
| `SELECT ... ENDSELECT` | `SELECT ... INTO TABLE` + `LOOP` | same rows, same processing |
| `REDUCE` over `PRCD_ELEMENTS` | `SELECT SUM( kwert )` | same total |
| `CALL TRANSACTION 'VA03' AND SKIP FIRST SCREEN` | `... WITHOUT AUTHORITY-CHECK AND SKIP FIRST SCREEN` | explicit form of the old default, same behaviour |
| `CONCATENATE count1 ...` for the approval ID | same statement and same `C(8)` field | the ID format stays identical |

## 7. Clean core

- Only released APIs are used to change sales orders: `BAPI_SALESORDER_CHANGE` and `BAPI_TRANSACTION_COMMIT`.
  There are no modifications or implicit enhancements, and no direct update of SAP tables.
- **Direct reads of SAP tables stay:** `VBAK`, `VBAP`, `VBEP`, `VBKD`, `KNA1`, `BSID`, `PRCD_ELEMENTS`,
  `UKMBP_CMS_SGM`, `MSKA`, `KEKO`, `KEPH`, `TVZBT`. Switching them to released CDS views (e.g.
  `I_SalesOrderItem`, `I_SalesOrderScheduleLine`, `I_Customer`) would change field names and could change
  results, so it is a separate step after this conversion has been tested.
- **No business logic in screens or modules.** Every module is one line that calls the class.

## 8. Test – old and new must give the same result

Run each test with the old version (before the transport) and with the new version, using the same plant and dates:

1. **List compare:** same rows, same columns, same values, same colours. Export both lists to Excel and compare them.
2. **YSDA Z8 step:** the same lines get Z8 (check VA03 or `VBAP-ABGRU`).
3. **SD approve, FI approve, approve with both:** the same `ZSOAPPROVAL` flags, dates and times; CN → CP on the
   same lines; the same `YSP_MTOSO_LOG` rows.
4. **Reject:** reason 63, the same messages, the same log row.
5. **User without a `ZAPPROVEUSER` entry:** the same warning on approve, the same info message on reject.
6. **User without `M_MSEG_WWA` authorization for the plant:** the same message on Execute.
7. **Display:** VA03 opens for every selected row.
8. **YSDAX only:** lines with sales order stock (`MSKA`) are hidden; the contribution margin is the same;
   plant 1400 shows only order types ZEM / ZMT / ZOR / ZFC; plant 1600 shows only item categories YZTC / YFRE.

## 9. REQ1 changes on the new code

The new code contains **no REQ1 change** – it is the old logic only. The REQ1 changes for the new code are in
**`REQ1_CHANGES_ON_NEW_CODE.md`** (N1–N7 for YSDA, X1–X6 for YSDAX, only in the `_C01` include). The folders
`YSDA/new_with_REQ1` and `YSDAX/new_with_REQ1` show the `_C01` include with these changes already applied, for
comparison.
