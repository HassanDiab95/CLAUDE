*&---------------------------------------------------------------------*
*& Table Maintenance Generator - events for ZSD_SO_CON_FLT
*& SE11 > Utilities > Table Maintenance Generator > Environment >
*& Modification > Events
*&   Event 01 (Before saving the data in the database)
*&     -> FORM ZSD_SO_CON_FLT_BEFORE_SAVE
*&---------------------------------------------------------------------*
FORM zsd_so_con_flt_before_save.

  TYPES:
    BEGIN OF ty_rule_field,
      rule_id   TYPE ze_sd_rule_id,
      fieldname TYPE ze_sd_flt_field,
    END OF ty_rule_field.

  DATA lt_active TYPE SORTED TABLE OF ty_rule_field WITH UNIQUE KEY rule_id fieldname.
  DATA lt_rules  TYPE SORTED TABLE OF ze_sd_rule_id WITH UNIQUE KEY table_line.
  DATA ls_line   TYPE zsd_so_con_flt.
  DATA lv_error  TYPE abap_bool.

  LOOP AT total.
    ls_line = <vim_total_struc>.

*   Deleted lines: only the completeness of their rule is re-checked
    IF <action> = geloescht OR <action> = neuer_geloescht OR <action> = update_geloescht.
      INSERT ls_line-rule_id INTO TABLE lt_rules.
      CONTINUE.
    ENDIF.

    IF <action> = neuer_eintrag OR <action> = aendern.
      PERFORM zsd_so_con_flt_check_line USING ls_line CHANGING lv_error.
      IF lv_error = abap_true.
        vim_abort_saving = abap_true.
        sy-subrc = 4.
        RETURN.
      ENDIF.
      INSERT ls_line-rule_id INTO TABLE lt_rules.
    ENDIF.

    IF ls_line-active = abap_true.
      INSERT VALUE #( rule_id = ls_line-rule_id fieldname = ls_line-fieldname ) INTO TABLE lt_active.
    ENDIF.
  ENDLOOP.

* Every rule with active lines must restrict all 5 fields (all mandatory)
  LOOP AT lt_rules INTO DATA(lv_rule_id).
    CHECK line_exists( lt_active[ rule_id = lv_rule_id ] ).
    LOOP AT VALUE string_table( ( `VKORG` ) ( `VTWEG` ) ( `SPART` ) ( `AUART_SO` ) ( `AUART_CON` ) )
         INTO DATA(lv_field).
      IF NOT line_exists( lt_active[ rule_id = lv_rule_id fieldname = CONV ze_sd_flt_field( lv_field ) ] ).
        MESSAGE |Rule { lv_rule_id }: at least one active line for { lv_field } is required|
          TYPE 'S' DISPLAY LIKE 'E'.
        vim_abort_saving = abap_true.
        sy-subrc = 4.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDLOOP.

ENDFORM.


*&---------------------------------------------------------------------*
*& Checks one filter line: SIGN/OPTION/LOW/HIGH and value existence
*&---------------------------------------------------------------------*
FORM zsd_so_con_flt_check_line USING    is_line  TYPE zsd_so_con_flt
                               CHANGING cv_error TYPE abap_bool.

  DATA lv_maxlen TYPE i.

  cv_error = abap_true.

  CASE is_line-fieldname.
    WHEN 'VKORG' OR 'AUART_SO' OR 'AUART_CON'.
      lv_maxlen = 4.
    WHEN 'VTWEG' OR 'SPART'.
      lv_maxlen = 2.
    WHEN OTHERS.
      MESSAGE |Field { is_line-fieldname } is not allowed| TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
  ENDCASE.

  IF is_line-sign IS INITIAL OR is_line-opti IS INITIAL OR is_line-low IS INITIAL.
    MESSAGE |Rule { is_line-rule_id } / { is_line-fieldname }: Sign, Option and Low are mandatory|
      TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  IF strlen( is_line-low ) > lv_maxlen OR strlen( is_line-high ) > lv_maxlen.
    MESSAGE |{ is_line-fieldname }: value longer than { lv_maxlen } characters|
      TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

* From-to options need HIGH >= LOW, single-value options no HIGH
  IF is_line-opti = 'BT' OR is_line-opti = 'NB'.
    IF is_line-high IS INITIAL OR is_line-high < is_line-low.
      MESSAGE |{ is_line-fieldname }: enter a valid To value (To >= From)|
        TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
  ELSEIF is_line-high IS NOT INITIAL.
    MESSAGE |{ is_line-fieldname }: To value only allowed with option BT/NB|
      TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

* Single values (EQ/NE) must exist in the check table
  IF is_line-opti = 'EQ' OR is_line-opti = 'NE'.
    CASE is_line-fieldname.
      WHEN 'VKORG'.
        SELECT SINGLE @abap_true FROM tvko WHERE vkorg = @is_line-low INTO @DATA(lv_found).
      WHEN 'VTWEG'.
        SELECT SINGLE @abap_true FROM tvtw WHERE vtweg = @is_line-low INTO @lv_found.
      WHEN 'SPART'.
        SELECT SINGLE @abap_true FROM tspa WHERE spart = @is_line-low INTO @lv_found.
      WHEN 'AUART_SO'.
        SELECT SINGLE @abap_true FROM tvak
          WHERE auart = @is_line-low AND vbtyp = 'C' INTO @lv_found.
      WHEN 'AUART_CON'.
        SELECT SINGLE @abap_true FROM tvak
          WHERE auart = @is_line-low AND vbtyp = 'G' INTO @lv_found.
    ENDCASE.
    IF lv_found = abap_false.
      MESSAGE |{ is_line-fieldname }: value { is_line-low } does not exist or has wrong document category|
        TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
  ENDIF.

  cv_error = abap_false.

ENDFORM.
