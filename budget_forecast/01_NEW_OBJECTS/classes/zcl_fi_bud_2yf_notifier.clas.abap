"! <p class="shorttext synchronized">Budget Forecast - e-mail notification</p>
"! Technical Consultant : Hassan Diab / Functional Consultant : Ahmed Tawfik
"! Created 08.10.2026 - Request <TBD>
"!
"! Clean core: user e-mail and name come from the standard API
"! BAPI_USER_GET_DETAIL (no direct read of USR21 / ADR6).
"! Sending uses BCS (CL_BCS). On S/4HANA 2022 or later this class is
"! the only place to switch to the released API CL_BCS_MAIL_MESSAGE.
CLASS zcl_fi_bud_2yf_notifier DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_fi_bud_2yf_notifier.

    METHODS constructor
      IMPORTING io_auth TYPE REF TO zif_fi_bud_2yf_auth.

  PRIVATE SECTION.
    DATA mo_auth TYPE REF TO zif_fi_bud_2yf_auth.

    METHODS get_address
      IMPORTING iv_user           TYPE syuname
      RETURNING VALUE(rs_address) TYPE bapiaddr3.

    "! Corporate colour palette (from the company colour scheme)
    CONSTANTS: BEGIN OF c_color,
                 navy       TYPE string VALUE `#454775`,
                 navy_dark  TYPE string VALUE `#343558`,
                 navy_light TYPE string VALUE `#6a6c91`,
                 teal       TYPE string VALUE `#59b5b0`,
                 teal_light TYPE string VALUE `#7AC4C0`,
                 green      TYPE string VALUE `#91B061`,
                 orange     TYPE string VALUE `#E38C33`,
                 rose       TYPE string VALUE `#D96978`,
                 blue       TYPE string VALUE `#009ED9`,
                 grey_bg    TYPE string VALUE `#F4F5F8`,
                 label_bg   TYPE string VALUE `#EEEEF4`,
               END OF c_color.

    "! Link of the Fiori app for the reviewers - fill it when the Fiori
    "! tile is available; while empty, no link / button is shown
    "! Arabic labels of the e-mail (fixed, independent of C_TEXT_AR,
    "! so the e-mail is always bilingual)
    CONSTANTS: BEGIN OF c_label_ar,
                 company     TYPE string VALUE `الشركة`,
                 cost_center TYPE string VALUE `كود الإدارة`,
                 years       TYPE string VALUE `سنوات الميزانية التقديرية`,
                 item_count  TYPE string VALUE `عدد البنود`,
                 total       TYPE string VALUE `إجمالي الموازنة التقديرية`,
                 created_by  TYPE string VALUE `أنشئ بواسطة`,
                 changed_by  TYPE string VALUE `عُدّل بواسطة`,
                 date_time   TYPE string VALUE `التاريخ / الوقت`,
                 items       TYPE string VALUE `بنود الموازنة`,
                 changes     TYPE string VALUE `التغييرات`,
               END OF c_label_ar.

    CONSTANTS c_fiori_url TYPE string VALUE ``.

    "! Max. number of change lines listed in the mail
    CONSTANTS c_max_log_lines TYPE i VALUE 30.

    METHODS build_body
      IMPORTING is_header           TYPE zif_fi_bud_2yf_types=>ty_header
                iv_mode             TYPE zif_fi_bud_2yf_types=>ty_mode
                iv_actor            TYPE string
                iv_item_count       TYPE i
                iv_cost_center_text TYPE kltxt
                it_log              TYPE zif_fi_bud_2yf_types=>tt_log
                it_items            TYPE zif_fi_bud_2yf_types=>tt_items
      RETURNING VALUE(rv_html)      TYPE string.

    "! Budget line items table (all items of the forecast)
    CLASS-METHODS item_table
      IMPORTING it_items       TYPE zif_fi_bud_2yf_types=>tt_items
                iv_currency    TYPE waers
      RETURNING VALUE(rv_html) TYPE string.

    "! One row of the details table: English label / Arabic label / value
    CLASS-METHODS detail_row
      IMPORTING iv_label_en    TYPE string
                iv_label_ar    TYPE csequence
                iv_value       TYPE string
      RETURNING VALUE(rv_html) TYPE string.

    "! "What changed" table for an update
    "! Section title: English left, Arabic right (table - works in Outlook)
    CLASS-METHODS section_title
      IMPORTING iv_title_en    TYPE string
                iv_title_ar    TYPE string
      RETURNING VALUE(rv_html) TYPE string.

    CLASS-METHODS change_table
      IMPORTING it_log         TYPE zif_fi_bud_2yf_types=>tt_log
      RETURNING VALUE(rv_html) TYPE string.

    CLASS-METHODS html
      IMPORTING iv_text        TYPE csequence
      RETURNING VALUE(rv_html) TYPE string.

ENDCLASS.



CLASS zcl_fi_bud_2yf_notifier IMPLEMENTATION.

  METHOD constructor.
    mo_auth = io_auth.
  ENDMETHOD.


  METHOD zif_fi_bud_2yf_notifier~notify.
    DATA(lt_users) = mo_auth->get_notification_recipients( ).
    IF lt_users IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_years) = |{ is_header-fyear_from }-{ is_header-fyear_to }|.

    DATA(lv_action) = COND string(
      WHEN iv_mode = zif_fi_bud_2yf_types=>c_mode-create
      THEN `created`
      ELSE |changed (update { is_header-change_count } of { zif_fi_bud_2yf_types=>c_max_changes })| ).

    DATA(lv_actor_user) = COND syuname( WHEN iv_mode = zif_fi_bud_2yf_types=>c_mode-create
                                        THEN is_header-ernam
                                        ELSE is_header-aenam ).
    DATA(lv_actor_name) = CONV string( get_address( lv_actor_user )-fullname ).
    DATA(lv_actor) = COND string( WHEN lv_actor_name IS INITIAL THEN CONV string( lv_actor_user )
                                  ELSE |{ lv_actor_name } ({ lv_actor_user })| ).

    DATA(lv_subject) = |Budget Forecast { lv_years } { lv_action } - | &&
                       |Company { is_header-bukrs } / Cost Center { is_header-kostl ALPHA = OUT }|.

    DATA(lv_html) = build_body(
      is_header           = is_header
      iv_mode             = iv_mode
      iv_actor            = lv_actor
      iv_item_count       = iv_item_count
      iv_cost_center_text = iv_cost_center_text
      it_log              = it_log
      it_items            = it_items ).

    TRY.
        DATA(lo_send) = cl_bcs=>create_persistent( ).

        lo_send->set_document( cl_document_bcs=>create_document(
                                 i_type    = 'HTM'
                                 i_text    = cl_document_bcs=>string_to_soli( lv_html )
                                 i_subject = CONV so_obj_des( lv_subject ) ) ).
        lo_send->set_message_subject( lv_subject ).
        lo_send->set_sender( cl_sapuser_bcs=>create( sy-uname ) ).

        LOOP AT lt_users INTO DATA(lv_user).
          DATA(lv_mail) = get_address( lv_user )-e_mail.
          " no e-mail in SU01 -> SAP Business Workplace inbox (SBWP)
          lo_send->add_recipient( COND #(
            WHEN lv_mail IS NOT INITIAL
            THEN cl_cam_address_bcs=>create_internet_address( lv_mail )
            ELSE cl_sapuser_bcs=>create( lv_user ) ) ).
        ENDLOOP.

        lo_send->set_send_immediately( abap_true ).
        lo_send->send( ).
        COMMIT WORK.

      CATCH cx_bcs INTO DATA(lx_bcs).
        rv_error = lx_bcs->get_text( ).
    ENDTRY.
  ENDMETHOD.


  METHOD get_address.
    DATA lt_return TYPE STANDARD TABLE OF bapiret2 WITH EMPTY KEY.

    CALL FUNCTION 'BAPI_USER_GET_DETAIL'
      EXPORTING
        username = iv_user
      IMPORTING
        address  = rs_address
      TABLES
        return   = lt_return.
  ENDMETHOD.


  METHOD build_body.
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_now)   = cl_abap_context_info=>get_system_time( ).
    DATA(lv_is_new) = xsdbool( iv_mode = zif_fi_bud_2yf_types=>c_mode-create ).

    " status badge: green = new submission, orange = update n of 2
    DATA(lv_badge_color) = COND string( WHEN lv_is_new = abap_true THEN c_color-green ELSE c_color-orange ).
    DATA(lv_badge_text)  = COND string(
      WHEN lv_is_new = abap_true
      THEN `NEW SUBMISSION &nbsp;|&nbsp; تقديم جديد`
      ELSE |UPDATE { is_header-change_count } OF { zif_fi_bud_2yf_types=>c_max_changes } &nbsp;\|&nbsp; | &&
           |التعديل { is_header-change_count } من { zif_fi_bud_2yf_types=>c_max_changes }| ).

    DATA(lv_intro_en) = COND string(
      WHEN lv_is_new = abap_true
      THEN `A new two-year budget forecast has been submitted and is available for your review.`
      ELSE `A submitted two-year budget forecast has been updated. The changed values are listed below.` ).
    DATA(lv_intro_ar) = COND string(
      WHEN lv_is_new = abap_true
      THEN `تم تقديم موازنة تقديرية جديدة لسنتين وهي متاحة للمراجعة.`
      ELSE `تم تعديل موازنة تقديرية مقدمة، وتظهر القيم المعدلة أدناه.` ).

    DATA(lv_years) = |{ is_header-fyear_from }-{ is_header-fyear_to }|.

    " company code name (released CDS view I_CompanyCode)
    SELECT SINGLE companycodename
      FROM i_companycode
      WHERE companycode = @is_header-bukrs
      INTO @DATA(lv_company_name).

    DATA(lv_total) = |<span style="color:{ c_color-blue };font-weight:bold;font-size:12pt">| &&
                     |{ is_header-total_amount NUMBER = USER } { is_header-waers }</span>|.

    rv_html =
      |<!DOCTYPE html><html><head><meta charset="utf-8"></head>| &&
      |<body style="margin:0;padding:0;background:{ c_color-grey_bg }">| &&
      |<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:{ c_color-grey_bg }">| &&
      |<tr><td align="center" style="padding:24px 12px">| &&
      |<table role="presentation" width="640" cellpadding="0" cellspacing="0" | &&
      |style="background:#ffffff;border:1px solid #dcdde6;font-family:Tahoma,Arial,sans-serif;color:#333333">| &&

      " header band
      |<tr><td style="background:{ c_color-navy };padding:22px 28px">| &&
      |<div style="color:#ffffff;font-size:18pt;font-weight:bold">Budget Forecast</div>| &&
      |<div style="color:{ c_color-teal_light };font-size:12pt;padding-top:2px" dir="rtl" align="right">الموازنة التقديرية</div>| &&
      |</td></tr>| &&
      |<tr><td style="background:{ c_color-teal };height:4px;line-height:4px;font-size:1px">&nbsp;</td></tr>| &&

      " badge + intro
      |<tr><td style="padding:22px 28px 6px 28px">| &&
      |<span style="display:inline-block;background:{ lv_badge_color };color:#ffffff;font-size:9pt;| &&
      |font-weight:bold;padding:5px 12px;border-radius:12px">{ lv_badge_text }</span>| &&
      |<p style="font-size:10.5pt;margin:16px 0 4px 0">Dear Final Reviewer,</p>| &&
      |<p style="font-size:10.5pt;margin:0 0 4px 0">{ lv_intro_en }</p>| &&
      |<p style="font-size:10.5pt;margin:0" dir="rtl" align="right">{ lv_intro_ar }</p>| &&
      |</td></tr>| &&

      " details
      |<tr><td style="padding:12px 28px">| &&
      |<table role="presentation" width="100%" cellpadding="0" cellspacing="0" | &&
      |style="border:1px solid #dcdde6;border-collapse:collapse;font-size:10pt">| &&
      detail_row( iv_label_en = `Company`               iv_label_ar = c_label_ar-company
                  iv_value    = COND #( WHEN lv_company_name IS INITIAL THEN CONV string( is_header-bukrs )
                                        ELSE |{ is_header-bukrs } - { html( lv_company_name ) }| ) ) &&
      detail_row( iv_label_en = `Cost Center Code`      iv_label_ar = c_label_ar-cost_center
                  iv_value    = |{ is_header-kostl ALPHA = OUT } - { html( iv_cost_center_text ) }| ) &&
      detail_row( iv_label_en = `Forecast Budget Years` iv_label_ar = c_label_ar-years
                  iv_value    = |<b>{ lv_years }</b>| ) &&
      detail_row( iv_label_en = `Number of Items`       iv_label_ar = c_label_ar-item_count
                  iv_value    = |{ iv_item_count }| ) &&
      detail_row( iv_label_en = `Total Forecast Amount` iv_label_ar = c_label_ar-total
                  iv_value    = lv_total ) &&
      detail_row( iv_label_en = COND #( WHEN lv_is_new = abap_true THEN `Created By` ELSE `Changed By` )
                  iv_label_ar = COND string( WHEN lv_is_new = abap_true THEN c_label_ar-created_by
                                        ELSE c_label_ar-changed_by )
                  iv_value    = html( iv_actor ) ) &&
      detail_row( iv_label_en = `Date / Time`           iv_label_ar = c_label_ar-date_time
                  iv_value    = |{ lv_today DATE = USER } { lv_now TIME = USER }| ) &&
      |</table></td></tr>| &&

      " budget line items (create and change)
      COND string( WHEN it_items IS NOT INITIAL
                   THEN |<tr><td style="padding:8px 28px 4px 28px">| &&
                        |{ section_title( iv_title_en = `Budget Line Items` iv_title_ar = c_label_ar-items ) }| &&
                        |</td></tr><tr><td style="padding:4px 28px 12px 28px">| &&
                        |{ item_table( it_items = it_items iv_currency = is_header-waers ) }</td></tr>| ) &&

      " what changed (updates only)
      COND string( WHEN lv_is_new = abap_false AND it_log IS NOT INITIAL
                   THEN |<tr><td style="padding:8px 28px 4px 28px">| &&
                        |{ section_title( iv_title_en = `What changed` iv_title_ar = c_label_ar-changes ) }| &&
                        |</td></tr><tr><td style="padding:4px 28px 12px 28px">{ change_table( it_log ) }</td></tr>| ) &&

      " link to the Fiori app (shown only when C_FIORI_URL is filled)
      COND string( WHEN c_fiori_url IS NOT INITIAL
                   THEN |<tr><td align="center" style="padding:10px 28px 22px 28px">| &&
                        |<a href="{ c_fiori_url }" style="display:inline-block;background:{ c_color-teal };| &&
                        |color:#ffffff;text-decoration:none;font-weight:bold;font-size:10.5pt;| &&
                        |padding:10px 26px;border-radius:4px">Open Budget Forecast &nbsp;\|&nbsp; فتح الموازنة التقديرية</a>| &&
                        |</td></tr>| ) &&

      " footer
      |<tr><td style="background:{ c_color-navy_dark };padding:12px 28px;color:#c9cadb;font-size:8.5pt">| &&
      |This is an automatic notification from the SAP Budget Forecast application. Please do not reply.| &&
      |<div dir="rtl" align="right" style="padding-top:2px">هذه رسالة آلية من نظام SAP - يرجى عدم الرد.</div>| &&
      |</td></tr>| &&
      |</table></td></tr></table></body></html>|.
  ENDMETHOD.


  METHOD detail_row.
    rv_html = |<tr>| &&
              |<td width="34%" style="background:{ c_color-label_bg };color:{ c_color-navy_dark };| &&
              |font-weight:bold;padding:8px 10px;border-bottom:1px solid #dcdde6">{ iv_label_en }</td>| &&
              |<td align="center" style="padding:8px 10px;border-bottom:1px solid #dcdde6;text-align:center">| &&
              |{ iv_value }</td>| &&
              |<td width="26%" dir="rtl" align="right" style="background:{ c_color-label_bg };| &&
              |color:{ c_color-navy_dark };font-weight:bold;padding:8px 10px;border-bottom:1px solid #dcdde6">| &&
              |{ condense( CONV string( iv_label_ar ) ) }</td></tr>|.
  ENDMETHOD.


  METHOD item_table.
    DATA(lv_head) = |style="background:{ c_color-teal };color:#ffffff;padding:6px 8px;text-align:left;font-size:9pt"|.
    DATA(lv_num)  = |style="background:{ c_color-teal };color:#ffffff;padding:6px 8px;text-align:right;font-size:9pt"|.

    rv_html = |<table role="presentation" width="100%" cellpadding="0" cellspacing="0" | &&
              |style="border:1px solid #dcdde6;border-collapse:collapse;font-size:9pt">| &&
              |<tr><th { lv_head }>#</th><th { lv_head }>Year</th><th { lv_head }>Project</th>| &&
              |<th { lv_head }>Priority</th><th { lv_head }>Opex/Capex</th><th { lv_head }>Type</th>| &&
              |<th { lv_num }>Budget</th></tr>|.

    LOOP AT it_items INTO DATA(ls_item).
      " light striping for readability
      DATA(lv_bg)   = COND string( WHEN sy-tabix MOD 2 = 0 THEN `#F7F8FB` ELSE `#ffffff` ).
      DATA(lv_cell) = |style="padding:6px 8px;border-bottom:1px solid #eeeeee;background:{ lv_bg }"|.

      rv_html = rv_html &&
        |<tr><td { lv_cell }>{ ls_item-item_no ALPHA = OUT }</td>| &&
        |<td { lv_cell }>{ ls_item-budget_year }</td>| &&
        |<td { lv_cell } dir="auto"><b>{ html( ls_item-proj_name ) }</b>| &&
        |<div style="color:#8a8a8a;font-size:8.5pt">{ html( ls_item-proj_desc ) }</div></td>| &&
        |<td { lv_cell }>{ ls_item-priority }</td>| &&
        |<td { lv_cell }>{ ls_item-bud_type }</td>| &&
        |<td { lv_cell }>{ zcl_fi_bud_2yf=>proj_type_text( ls_item-proj_type ) }</td>| &&
        |<td { lv_cell } align="right" nowrap>{ ls_item-amount NUMBER = USER }</td></tr>|.
    ENDLOOP.

    " total line
    DATA(lv_total) = REDUCE zfcst_amount( INIT lv_sum TYPE zfcst_amount
                                          FOR ls_line IN it_items
                                          NEXT lv_sum = lv_sum + ls_line-amount ).
    rv_html = rv_html &&
      |<tr><td colspan="6" style="padding:7px 8px;background:{ c_color-label_bg };font-weight:bold;| &&
      |color:{ c_color-navy_dark }">Total</td>| &&
      |<td align="right" nowrap style="padding:7px 8px;background:{ c_color-label_bg };font-weight:bold;| &&
      |color:{ c_color-blue }">{ lv_total NUMBER = USER } { iv_currency }</td></tr></table>|.
  ENDMETHOD.


  METHOD section_title.
    rv_html = |<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>| &&
              |<td align="left" style="font-size:11pt;font-weight:bold;color:{ c_color-navy }">{ iv_title_en }</td>| &&
              |<td align="right" dir="rtl" style="font-size:11pt;font-weight:bold;color:{ c_color-navy }">| &&
              |{ iv_title_ar }</td></tr></table>|.
  ENDMETHOD.

  METHOD change_table.
    DATA(lv_head) = |style="background:{ c_color-navy };color:#ffffff;padding:6px 8px;text-align:left;font-size:9pt"|.

    rv_html = |<table role="presentation" width="100%" cellpadding="0" cellspacing="0" | &&
              |style="border:1px solid #dcdde6;border-collapse:collapse;font-size:9pt">| &&
              |<tr><th { lv_head }>Action</th><th { lv_head }>Item</th><th { lv_head }>Field</th>| &&
              |<th { lv_head }>Old Value</th><th { lv_head }>New Value</th></tr>|.

    LOOP AT it_log INTO DATA(ls_log) TO c_max_log_lines.
      DATA(lv_color) = SWITCH string( ls_log-chg_ind
                         WHEN zif_fi_bud_2yf_types=>c_chg_ind-insert THEN c_color-green
                         WHEN zif_fi_bud_2yf_types=>c_chg_ind-delete THEN c_color-rose
                         ELSE c_color-orange ).
      DATA(lv_action) = SWITCH string( ls_log-chg_ind
                          WHEN zif_fi_bud_2yf_types=>c_chg_ind-insert THEN `Added`
                          WHEN zif_fi_bud_2yf_types=>c_chg_ind-delete THEN `Deleted`
                          ELSE `Changed` ).
      DATA(lv_cell) = |style="padding:6px 8px;border-bottom:1px solid #eeeeee"|.

      rv_html = rv_html &&
        |<tr><td { lv_cell } nowrap><span style="color:{ lv_color };font-weight:bold;white-space:nowrap">| &&
        |&#9679;&nbsp;{ lv_action }</span></td>| &&
        |<td { lv_cell }>{ COND string( WHEN ls_log-item_no IS INITIAL THEN `-` ELSE |{ ls_log-item_no ALPHA = OUT }| ) }</td>| &&
        |<td { lv_cell } dir="auto">{ html( ls_log-field_text ) }</td>| &&
        |<td { lv_cell } dir="auto" style="color:#8a8a8a">{ html( ls_log-value_old ) }</td>| &&
        |<td { lv_cell } dir="auto"><b>{ html( ls_log-value_new ) }</b></td></tr>|.
    ENDLOOP.

    IF lines( it_log ) > c_max_log_lines.
      rv_html = rv_html && |<tr><td colspan="5" style="padding:6px 8px;color:#8a8a8a">| &&
                |... { lines( it_log ) - c_max_log_lines } more change(s) - see the report.</td></tr>|.
    ENDIF.

    rv_html = rv_html && |</table>|.
  ENDMETHOD.


  METHOD html.
    rv_html = escape( val = CONV string( iv_text ) format = cl_abap_format=>e_html_text ).
  ENDMETHOD.

ENDCLASS.
