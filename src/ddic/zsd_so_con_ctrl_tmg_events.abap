*&---------------------------------------------------------------------*
*& Table Maintenance Generator - events for ZSD_SO_CON_CTRL
*& SE11 > Utilities > Table Maintenance Generator > Environment >
*& Modification > Events
*&   Event 01 (Before saving the data in the database)
*&     -> FORM ZSD_SO_CON_CTRL_BEFORE_SAVE
*&---------------------------------------------------------------------*
FORM zsd_so_con_ctrl_before_save.

  DATA ls_rule TYPE zsd_so_con_ctrl.

  LOOP AT total.
    CHECK <action> = neuer_eintrag OR <action> = aendern.

    ls_rule = <vim_total_struc>.

*   All key fields are mandatory
    IF ls_rule-vkorg     IS INITIAL
    OR ls_rule-vtweg     IS INITIAL
    OR ls_rule-spart     IS INITIAL
    OR ls_rule-auart_so  IS INITIAL
    OR ls_rule-auart_con IS INITIAL.
      MESSAGE 'Sales Area, Sales Order Type and Contract Type are mandatory'
        TYPE 'S' DISPLAY LIKE 'E'.
      vim_abort_saving = abap_true.
      sy-subrc = 4.
      RETURN.
    ENDIF.

*   AUART_SO must be a sales order type, AUART_CON must be a contract type
    SELECT SINGLE vbtyp FROM tvak
      WHERE auart = @ls_rule-auart_so
      INTO @DATA(lv_vbtyp_so).
    IF lv_vbtyp_so <> 'C'.
      MESSAGE |{ ls_rule-auart_so } is not a sales order type|
        TYPE 'S' DISPLAY LIKE 'E'.
      vim_abort_saving = abap_true.
      sy-subrc = 4.
      RETURN.
    ENDIF.

    SELECT SINGLE vbtyp FROM tvak
      WHERE auart = @ls_rule-auart_con
      INTO @DATA(lv_vbtyp_con).
    IF lv_vbtyp_con <> 'G'.
      MESSAGE |{ ls_rule-auart_con } is not a contract type|
        TYPE 'S' DISPLAY LIKE 'E'.
      vim_abort_saving = abap_true.
      sy-subrc = 4.
      RETURN.
    ENDIF.
  ENDLOOP.

ENDFORM.
