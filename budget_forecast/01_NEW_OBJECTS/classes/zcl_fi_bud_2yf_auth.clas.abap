"! <p class="shorttext synchronized">Budget Forecast - authorization (Budget Preparation roles)</p>
"! Technical Consultant : Hassan Diab / Functional Consultant : Ahmed Tawfik
"! Created 08.10.2026 - Request <TBD>
"!
"! Reuses the role tables of the Budget Preparation application:
"!   ZBUD_CREATORS     - creators per cost center
"!   ZFI_BUD_WF_AGENT  - workflow agents, level FR = Final Reviewer
"!   ZFIBUD_ASSISTANT  - Final Reviewer assistants
CLASS zcl_fi_bud_2yf_auth DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_fi_bud_2yf_auth.

    METHODS constructor
      IMPORTING iv_user TYPE syuname OPTIONAL
                iv_date TYPE d OPTIONAL.

  PRIVATE SECTION.
    CONSTANTS c_level_final_reviewer TYPE c LENGTH 2 VALUE 'FR'.

    DATA mv_user TYPE syuname.
    DATA mv_date TYPE d.
    "! Creator roles that allow creating a budget - same decode as
    "! ROLE_TO_FLAGS in ZFI_BUDGET_PREPERATION
    DATA mt_create_roles TYPE RANGE OF zcreator_role.

ENDCLASS.



CLASS zcl_fi_bud_2yf_auth IMPLEMENTATION.

  METHOD constructor.
    mv_user = COND #( WHEN iv_user IS NOT INITIAL THEN iv_user ELSE sy-uname ).
    mv_date = COND #( WHEN iv_date IS NOT INITIAL THEN iv_date
                      ELSE cl_abap_context_info=>get_system_date( ) ).

    mt_create_roles = VALUE #( sign = 'I' option = 'EQ'
                               ( low = 'CRE' ) ( low = 'C&M' )
                               ( low = 'CMD' ) ( low = 'ALL' ) ).
  ENDMETHOD.


  METHOD zif_fi_bud_2yf_auth~is_creator.
    DATA lr_kostl TYPE RANGE OF kostl.

    IF iv_kostl IS NOT INITIAL.
      lr_kostl = VALUE #( ( sign = 'I' option = 'EQ' low = iv_kostl ) ).
    ENDIF.

    SELECT SINGLE @abap_true
      FROM zbud_creators
      WHERE user_id      = @mv_user
        AND kostl       IN @lr_kostl
        AND creator_role IN @mt_create_roles
        AND valid_from  <= @mv_date
        AND valid_to    >= @mv_date
        AND active       = @abap_true
      INTO @rv_result.
  ENDMETHOD.


  METHOD zif_fi_bud_2yf_auth~is_final_reviewer.
    SELECT SINGLE @abap_true
      FROM zfi_bud_wf_agent
      WHERE agent_user = @mv_user
        AND zlevel     = @c_level_final_reviewer
        AND active     = @abap_true
      INTO @rv_result.

    IF rv_result = abap_false.
      SELECT SINGLE @abap_true
        FROM zfibud_assistant
        WHERE user_id = @mv_user
          AND active  = @abap_true
        INTO @rv_result.
    ENDIF.
  ENDMETHOD.


  METHOD zif_fi_bud_2yf_auth~get_notification_recipients.
    SELECT agent_user
      FROM zfi_bud_wf_agent
      WHERE zlevel = @c_level_final_reviewer
        AND active = @abap_true
      INTO TABLE @DATA(lt_final_reviewers).

    SELECT user_id
      FROM zfibud_assistant
      WHERE active = @abap_true
      INTO TABLE @DATA(lt_assistants).

    " sorted unique table: a user in both tables is mailed once
    LOOP AT lt_final_reviewers INTO DATA(ls_final_reviewer).
      INSERT CONV syuname( ls_final_reviewer-agent_user ) INTO TABLE rt_users.
    ENDLOOP.
    LOOP AT lt_assistants INTO DATA(ls_assistant).
      INSERT CONV syuname( ls_assistant-user_id ) INTO TABLE rt_users.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
