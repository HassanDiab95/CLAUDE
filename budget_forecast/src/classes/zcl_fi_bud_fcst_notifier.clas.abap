"! <p class="shorttext synchronized">Budget Forecast - e-mail notification</p>
"! Technical Consultant : Hassan Diab / Functional Consultant : Ahmed Tawfik
"! Created 08.10.2026 - Request <TBD>
"!
"! Clean core: user e-mail and name come from the standard API
"! BAPI_USER_GET_DETAIL (no direct read of USR21 / ADR6).
"! Sending uses BCS (CL_BCS). On S/4HANA 2022 or later this class is
"! the only place to switch to the released API CL_BCS_MAIL_MESSAGE.
CLASS zcl_fi_bud_fcst_notifier DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_fi_bud_fcst_notifier.

    METHODS constructor
      IMPORTING io_auth TYPE REF TO zif_fi_bud_fcst_auth.

  PRIVATE SECTION.
    DATA mo_auth TYPE REF TO zif_fi_bud_fcst_auth.

    METHODS get_address
      IMPORTING iv_user           TYPE syuname
      RETURNING VALUE(rs_address) TYPE bapiaddr3.

    METHODS build_body
      IMPORTING is_header           TYPE zif_fi_bud_fcst_types=>ty_header
                iv_action           TYPE string
                iv_actor_label      TYPE string
                iv_actor            TYPE string
                iv_item_count       TYPE i
                iv_cost_center_text TYPE kltxt
      RETURNING VALUE(rv_html)      TYPE string.

    CLASS-METHODS html
      IMPORTING iv_text        TYPE csequence
      RETURNING VALUE(rv_html) TYPE string.

ENDCLASS.



CLASS zcl_fi_bud_fcst_notifier IMPLEMENTATION.

  METHOD constructor.
    mo_auth = io_auth.
  ENDMETHOD.


  METHOD zif_fi_bud_fcst_notifier~notify.
    DATA(lt_users) = mo_auth->get_notification_recipients( ).
    IF lt_users IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_years) = |{ is_header-fyear_from }-{ is_header-fyear_to }|.

    DATA(lv_action) = COND string(
      WHEN iv_mode = zif_fi_bud_fcst_types=>c_mode-create
      THEN `created`
      ELSE |changed (update { is_header-change_count } of { zif_fi_bud_fcst_types=>c_max_changes })| ).

    DATA(lv_actor_user) = COND syuname( WHEN iv_mode = zif_fi_bud_fcst_types=>c_mode-create
                                        THEN is_header-ernam
                                        ELSE is_header-aenam ).
    DATA(lv_actor_name) = CONV string( get_address( lv_actor_user )-fullname ).
    DATA(lv_actor) = COND string( WHEN lv_actor_name IS INITIAL THEN CONV string( lv_actor_user )
                                  ELSE |{ lv_actor_name } ({ lv_actor_user })| ).

    DATA(lv_subject) = |Budget Forecast { lv_years } { lv_action } - | &&
                       |Company { is_header-bukrs } / Cost Center { is_header-kostl ALPHA = OUT }|.

    DATA(lv_html) = build_body(
      is_header           = is_header
      iv_action           = lv_action
      iv_actor_label      = COND #( WHEN iv_mode = zif_fi_bud_fcst_types=>c_mode-create
                                    THEN `Created By` ELSE `Changed By` )
      iv_actor            = lv_actor
      iv_item_count       = iv_item_count
      iv_cost_center_text = iv_cost_center_text ).

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

    rv_html =
      |<html><body style="font-family:Arial,sans-serif;font-size:10pt">| &&
      |<p>Dear Final Reviewer,</p>| &&
      |<p>A budget forecast has been <b>{ html( iv_action ) }</b>.</p>| &&
      |<table border="1" cellpadding="4" cellspacing="0" style="border-collapse:collapse">| &&
      |<tr><td><b>Company</b></td><td>{ is_header-bukrs }</td></tr>| &&
      |<tr><td><b>Cost Center Code</b></td><td>{ is_header-kostl ALPHA = OUT } - | &&
      |{ html( iv_cost_center_text ) }</td></tr>| &&
      |<tr><td><b>Forecast Budget Years</b></td><td>{ is_header-fyear_from }-{ is_header-fyear_to }</td></tr>| &&
      |<tr><td><b>Number of Items</b></td><td>{ iv_item_count }</td></tr>| &&
      |<tr><td><b>Total Forecast Amount</b></td><td>| &&
      |{ is_header-total_amount NUMBER = USER } { is_header-waers }</td></tr>| &&
      |<tr><td><b>{ iv_actor_label }</b></td><td>{ html( iv_actor ) }</td></tr>| &&
      |<tr><td><b>Date / Time</b></td><td>{ lv_today DATE = USER } { lv_now TIME = USER }</td></tr>| &&
      |</table>| &&
      |<p>The submission and its change history can be reviewed in the consolidated | &&
      |forecast report (transaction { zif_fi_bud_fcst_types=>c_tcode-report }).</p>| &&
      |<p>This is an automatic notification from the SAP Budget Forecast application.</p>| &&
      |</body></html>|.
  ENDMETHOD.


  METHOD html.
    rv_html = escape( val = CONV string( iv_text ) format = cl_abap_format=>e_html_text ).
  ENDMETHOD.

ENDCLASS.
