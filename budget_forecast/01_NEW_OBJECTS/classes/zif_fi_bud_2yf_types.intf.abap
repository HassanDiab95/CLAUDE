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

  "! Arabic texts of the screen, the report and the change log
  "! (one place to change the wording; filled at runtime like the
  "! existing Arabic column texts of ZFI_BUDGET_PREPERATION)
  TYPES ty_text TYPE c LENGTH 60.
  CONSTANTS: BEGIN OF c_text_ar,
               bukrs        TYPE ty_text VALUE 'الشركة',
               kostl        TYPE ty_text VALUE 'القطاع / الإدارة',
               dept_code    TYPE ty_text VALUE 'كود الإدارة',
               dept_name    TYPE ty_text VALUE 'اسم الإدارة',
               years        TYPE ty_text VALUE 'سنوات الميزانية التقديرية',
               item_no      TYPE ty_text VALUE 'التسلسل',
               budget_year  TYPE ty_text VALUE 'سنة الميزانية',
               proj_name    TYPE ty_text VALUE 'اسم المشروع',
               proj_desc    TYPE ty_text VALUE 'وصف المشروع',
               priority     TYPE ty_text VALUE 'أولوية المشروع',
               amount       TYPE ty_text VALUE 'ميزانية المشروع',
               waers        TYPE ty_text VALUE 'العملة',
               bud_type     TYPE ty_text VALUE 'تشغيلية / رأسمالية',
               proj_type    TYPE ty_text VALUE 'نوع المشروع',
               total_amount TYPE ty_text VALUE 'إجمالي الموازنة التقديرية',
               ernam        TYPE ty_text VALUE 'أنشئ بواسطة',
               erdat        TYPE ty_text VALUE 'تاريخ الإنشاء',
               aenam        TYPE ty_text VALUE 'آخر تعديل بواسطة',
               aedat        TYPE ty_text VALUE 'تاريخ آخر تعديل',
               change_count TYPE ty_text VALUE 'عدد التعديلات',
               change_no    TYPE ty_text VALUE 'رقم التعديل',
               changed_by   TYPE ty_text VALUE 'عُدّل بواسطة',
               user_name    TYPE ty_text VALUE 'الاسم',
               changed_on   TYPE ty_text VALUE 'التاريخ',
               changed_at   TYPE ty_text VALUE 'الوقت',
               action       TYPE ty_text VALUE 'الإجراء',
               field        TYPE ty_text VALUE 'الحقل',
               value_old    TYPE ty_text VALUE 'القيمة السابقة',
               value_new    TYPE ty_text VALUE 'القيمة الجديدة',
               act_insert   TYPE ty_text VALUE 'إضافة بند',
               act_update   TYPE ty_text VALUE 'تعديل',
               act_delete   TYPE ty_text VALUE 'حذف بند',
               of_updates   TYPE ty_text VALUE 'من',
               used         TYPE ty_text VALUE 'مستخدمة',
               btn_create   TYPE ty_text VALUE 'إدخال البنود',
               btn_change   TYPE ty_text VALUE 'تعديل البنود',
               title_create TYPE ty_text VALUE 'إنشاء الموازنة التقديرية',
               title_modify TYPE ty_text VALUE 'تعديل الموازنة التقديرية',
               title_display TYPE ty_text VALUE 'عرض الموازنة التقديرية',
             END OF c_text_ar.

ENDINTERFACE.
