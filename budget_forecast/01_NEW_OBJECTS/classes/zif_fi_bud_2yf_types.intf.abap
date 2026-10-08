"! <p class="shorttext synchronized">Budget Forecast - shared types and constants</p>
"! Technical Consultant : Hassan Diab / Functional Consultant : Ahmed Tawfik
"! Created 08.10.2026 - Request <TBD>
INTERFACE zif_fi_bud_2yf_types PUBLIC.

  TYPES ty_header TYPE zfi_bud_fcst_h.
  TYPES ty_item   TYPE zfi_bud_fcst_i.
  TYPES tt_items  TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.
  TYPES ty_log    TYPE zfi_bud_fcst_log.
  TYPES tt_log    TYPE STANDARD TABLE OF ty_log WITH EMPTY KEY.
  TYPES tt_users  TYPE SORTED TABLE OF syuname WITH UNIQUE KEY table_line.

  "! Business key of one forecast submission (duplicate prevention key)
  TYPES: BEGIN OF ty_key,
           bukrs      TYPE bukrs,
           kostl      TYPE kostl,
           fyear_from TYPE zfcst_year_from,
           fyear_to   TYPE zfcst_year_to,
         END OF ty_key.

  TYPES: BEGIN OF ty_years,
           fyear_from TYPE zfcst_year_from,
           fyear_to   TYPE zfcst_year_to,
         END OF ty_years,
         tt_years TYPE STANDARD TABLE OF ty_years WITH EMPTY KEY.

  "! Result of the modification rules (creator / max. updates / year)
  TYPES: BEGIN OF ty_change_check,
           allowed TYPE abap_bool,
           msgno   TYPE symsgno,
           msgv1   TYPE symsgv,
         END OF ty_change_check.

  TYPES: BEGIN OF ty_save_result,
           header     TYPE ty_header,
           mail_error TYPE string,
         END OF ty_save_result.

  CONSTANTS c_msgid TYPE symsgid VALUE 'ZBUD_FCST'.

  "! Maximum number of updates of one forecast submission
  CONSTANTS c_max_changes TYPE i VALUE 2.

  "! First forecast year = current year + c_year_offset.
  "! 2 -> in 2026 the forecast is 2028-2029 (as in the business template).
  "! Set to 1 if the forecast must start right after the current year.
  CONSTANTS c_year_offset TYPE i VALUE 2.

  CONSTANTS c_currency TYPE waers VALUE 'SAR'.

  "! Screen / save mode: C = create, M = modify
  TYPES ty_mode TYPE c LENGTH 1.

  CONSTANTS: BEGIN OF c_mode,
               create TYPE ty_mode VALUE 'C',
               modify TYPE ty_mode VALUE 'M',
             END OF c_mode.

  "! Change log action
  CONSTANTS: BEGIN OF c_chg_ind,
               insert TYPE zfcst_chg_ind VALUE 'I',
               update TYPE zfcst_chg_ind VALUE 'U',
               delete TYPE zfcst_chg_ind VALUE 'D',
             END OF c_chg_ind.

  CONSTANTS: BEGIN OF c_tcode,
               create TYPE sytcode VALUE 'ZFI_BUD_2YF_C',
               modify TYPE sytcode VALUE 'ZFI_BUD_2YF_M',
               report TYPE sytcode VALUE 'ZFI_BUD_2YF_R',
             END OF c_tcode.

  "! Texts of the screen, the report and the change log (one place to
  "! change the wording). English for now - replace the values by the
  "! Arabic wording once the customer has confirmed it.
  TYPES ty_text TYPE c LENGTH 60.
  CONSTANTS: BEGIN OF c_text_ar,
               bukrs         TYPE ty_text VALUE 'Company Code',
               kostl         TYPE ty_text VALUE 'Sector / Department',
               dept_code     TYPE ty_text VALUE 'Department Code',
               dept_name     TYPE ty_text VALUE 'Department Name',
               years         TYPE ty_text VALUE 'Forecast Budget Years',
               item_no       TYPE ty_text VALUE 'Seq.',
               budget_year   TYPE ty_text VALUE 'Budget Year',
               proj_name     TYPE ty_text VALUE 'Project Name',
               proj_desc     TYPE ty_text VALUE 'Project Description',
               priority      TYPE ty_text VALUE 'Project Priority',
               amount        TYPE ty_text VALUE 'Project Budget',
               waers         TYPE ty_text VALUE 'Currency',
               bud_type      TYPE ty_text VALUE 'Opex / Capex',
               proj_type     TYPE ty_text VALUE 'Project Type',
               total_amount  TYPE ty_text VALUE 'Total Forecast Amount',
               ernam         TYPE ty_text VALUE 'Created By',
               erdat         TYPE ty_text VALUE 'Created On',
               aenam         TYPE ty_text VALUE 'Last Changed By',
               aedat         TYPE ty_text VALUE 'Last Changed On',
               change_count  TYPE ty_text VALUE 'Updates Used',
               change_no     TYPE ty_text VALUE 'Update No.',
               changed_by    TYPE ty_text VALUE 'Changed By',
               user_name     TYPE ty_text VALUE 'Name',
               changed_on    TYPE ty_text VALUE 'Date',
               changed_at    TYPE ty_text VALUE 'Time',
               action        TYPE ty_text VALUE 'Action',
               field         TYPE ty_text VALUE 'Field',
               value_old     TYPE ty_text VALUE 'Old Value',
               value_new     TYPE ty_text VALUE 'New Value',
               act_insert    TYPE ty_text VALUE 'Item Added',
               act_update    TYPE ty_text VALUE 'Changed',
               act_delete    TYPE ty_text VALUE 'Item Deleted',
               of_updates    TYPE ty_text VALUE 'of',
               used          TYPE ty_text VALUE 'used',
               btn_create    TYPE ty_text VALUE 'Create Items',
               btn_change    TYPE ty_text VALUE 'Change Items',
               title_create  TYPE ty_text VALUE 'Create Budget Forecast',
               title_modify  TYPE ty_text VALUE 'Modify Budget Forecast',
               title_display TYPE ty_text VALUE 'Display Budget Forecast',
             END OF c_text_ar.

ENDINTERFACE.
