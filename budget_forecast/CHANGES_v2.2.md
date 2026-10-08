# Budget Forecast 2YF – v2.2 changes (what to re-apply in SAP)

Three changes:

1. Every line of the change-history popup gets an **action icon**.
2. The notification **e-mail** is redesigned in the corporate colour palette.
3. The entry screen and the report show **Arabic** column and field names.

Everything is still only in the new `2YF` objects. **Nothing in `ZFI_BUDGET_PREPERATION` or the existing `ZFI_BUDGET_FORECAST` changes.**

| # | Object | What changed | How to apply |
|---|---|---|---|
| 1 | `ZIF_FI_BUD_2YF_TYPES` (interface) | **New** at the end: type `TY_TEXT` and constant structure `C_TEXT_AR`. These are all the Arabic texts, kept in one place | Paste the new block before `ENDINTERFACE` (or replace the whole source) |
| 2 | `ZIF_FI_BUD_2YF_NOTIFIER` (interface) | Method `NOTIFY`: new optional parameter `IT_LOG` (the changed values for the e-mail) | Replace the source |
| 3 | `ZCL_FI_BUD_2YF_NOTIFIER` (class) | **E-mail redesigned** in the colour palette. Navy `#454775` header with Arabic title and teal `#59b5b0` accent line. Status badge: green `#91B061` for a new submission, orange `#E38C33` for "Update n of 2". English + Arabic labels on every row. Total in blue `#009ED9`. For updates, a "What changed / التغييرات" table: green Added, orange Changed, rose `#D96978` Deleted, with old and new value. Teal call-to-action box and dark-navy `#343558` footer. New private methods `DETAIL_ROW` and `CHANGE_TABLE`, and a new signature for `BUILD_BODY` | Replace the whole source |
| 4 | `ZCL_FI_BUD_2YF` (class) | (a) `FIELD_TEXT`: Arabic field names first (used in validation messages and the change log). (b) `BUILD_CHANGE_LOG`: Arabic texts for "item added / deleted". (c) `CHANGE` and the private `NOTIFY`: pass the change log to the e-mail (new optional parameter `IT_LOG` on private `NOTIFY`) | Replace the whole source (test classes unchanged) |
| 5 | `ZCL_FI_BUD_2YF_REPORT` (class) | (a) Change-history popup: new first column **ICON** (`ICON_CREATE` for added, `ICON_CHANGE` for changed, `ICON_DELETE` for deleted), shown as an icon column. (b) Action text in Arabic (إضافة بند / تعديل / حذف بند). (c) Arabic column headers in the main list and the popup. Type `TY_LOG_OUT` gets the field `ICON`, and `ACTION` becomes `TY_TEXT` | Replace the whole source |
| 6 | `ZFI_BUD_2YF_ENTRY_TOP` (include) | **New** structure `GS_LBL`: the Arabic labels and column headers of screen 0100. New method `SET_LABELS` in the class definition | Replace the source |
| 7 | `ZFI_BUD_2YF_ENTRY_C01` (include) | New method `SET_LABELS`, called in the constructor. The title is in Arabic. The "Create Items / Change Items" button text is in Arabic (now set directly with `ICON_BOM_SUB_ITEM`; `ICON_CREATE` is no longer called). "Updates used" text is in Arabic | Replace the source |
| 8 | Screen 0100 of `ZFI_BUD_2YF_ENTRY` | The English fixed texts (labels and table column headers) are replaced by **output fields** `GS_LBL-*` and `GS_LBL-HDR_*`, filled with Arabic at runtime. This is the same technique `ZFI_BUDGET_PREPERATION` uses for its Arabic columns. The flow logic is unchanged | Re-upload `01_NEW_OBJECTS/screens/ZFI_BUD_2YF_ENTRY_0100.txt` (see below) |
| 9 | Title `TITLE_0100` (SE41) | Text changes from `&1 Budget Forecast` to just **`&1`**, because the whole Arabic title now comes from the program | Change the title text in SE41 |

Unchanged:

* `ZCX_FI_BUD_2YF`, `ZCL_FI_BUD_2YF_REPOSITORY`, `ZCL_FI_BUD_2YF_AUTH`, `ZIF_FI_BUD_2YF_REPOSITORY`, `ZIF_FI_BUD_2YF_AUTH`
* includes `_PBO` / `_PAI`, report program `ZFI_BUD_2YF_REPORT`
* the test classes, the DDIC objects, message class `ZBUD_FCST`
* GUI status `GUI_0100`, the transactions
* the changes to `ZFI_BUDGET_PREPERATION`

## Screen 0100 – re-upload or change by hand

* **Upload:** SE51 → `ZFI_BUD_2YF_ENTRY` / 0100 → Utilities → More Utilities → Upload → `ZFI_BUD_2YF_ENTRY_0100.txt` → Activate.
* **By hand (if you already built the screen manually):**
  1. Delete the static text elements next to the header and info fields.
  2. In their place, add **output-only** fields of the program fields below. Use **Dict./Program fields** (F6), enter `GS_LBL-*`, then *Get from program*. Set the attribute "Output only".

  | Position | Field | Visible length |
  |---|---|---|
  | Label of Company | `GS_LBL-BUKRS` | 25 |
  | Label of Cost Center | `GS_LBL-KOSTL` | 25 |
  | Label of Forecast Years | `GS_LBL-YEARS` | 25 |
  | Info block labels | `GS_LBL-ERNAM`, `-ERDAT`, `-AENAM`, `-AEDAT`, `-CHANGES`, `-TOTAL` | 21 |
  | Table control column headers | `GS_LBL-HDR_ITEM_NO`, `-HDR_BUDGET_YEAR`, `-HDR_KOSTL`, `-HDR_PROJ_NAME`, `-HDR_PROJ_DESC`, `-HDR_PRIORITY`, `-HDR_AMOUNT`, `-HDR_WAERS`, `-HDR_BUD_TYPE`, `-HDR_PROJ_TYPE` | width of the column |

  For the column headers: in the table control, select the column header, delete the static text, and drag the output field into the header cell. This is the same way the existing screen uses `GV_AGRD_POINTS_TEXT`.
* **Frame titles** ("Forecast Header", "Submission Information", "Forecast Items") and the "Other Forecast" button are static texts. Type the Arabic directly in the Layout Editor (double-click the frame or button → Text). For example:
  * الموازنة التقديرية – البيانات الأساسية
  * معلومات التقديم
  * بنود الموازنة التقديرية
  * موازنة أخرى

## Notes

* To change any Arabic wording, edit only `ZIF_FI_BUD_2YF_TYPES=>C_TEXT_AR`. The screen, the report, the change log and the validation messages all use it.
* Messages of `ZBUD_FCST` are still English. For Arabic messages, translate the message class in SE63 (logon language AR) or change the texts in SE91.
* Old change-log lines already saved keep their English "Item added / Item deleted" text. New changes use Arabic.
