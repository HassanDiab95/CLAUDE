"! <p class="shorttext synchronized">Budget Forecast - shared types and constants</p>
"! Technical Consultant : Hassan Diab / Functional Consultant : Ahmed Tawfik
"! Created 08.10.2026 - Request <TBD>
INTERFACE zif_fi_bud_2yf_types PUBLIC.

  TYPES ty_header TYPE zfi_bud_2yf_h.
  TYPES ty_item   TYPE zfi_bud_2yf_i.
  TYPES tt_items  TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.
  TYPES ty_log    TYPE zfi_bud_2yf_log.
  TYPES tt_log    TYPE STANDARD TABLE OF ty_log WITH EMPTY KEY.
  TYPES tt_users  TYPE SORTED TABLE OF syuname WITH UNIQUE KEY table_line.

  "! Business key of one forecast submission (duplicate prevention key)
  TYPES: BEGIN OF ty_key,
           bukrs      TYPE bukrs,
           kostl      TYPE kostl,
           fyear_from TYPE z2yf_year_from,
           fyear_to   TYPE z2yf_year_to,
         END OF ty_key.

  TYPES: BEGIN OF ty_years,
           fyear_from TYPE z2yf_year_from,
           fyear_to   TYPE z2yf_year_to,
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

  CONSTANTS c_msgid TYPE symsgid VALUE 'ZBUD_2YF'.

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
               insert TYPE z2yf_chg_ind VALUE 'I',
               update TYPE z2yf_chg_ind VALUE 'U',
               delete TYPE z2yf_chg_ind VALUE 'D',
             END OF c_chg_ind.

  CONSTANTS: BEGIN OF c_tcode,
               create TYPE sytcode VALUE 'ZFI_BUD_2YF_C',
               modify TYPE sytcode VALUE 'ZFI_BUD_2YF_M',
               report TYPE sytcode VALUE 'ZFI_BUD_2YF_R',
             END OF c_tcode.

ENDINTERFACE.
