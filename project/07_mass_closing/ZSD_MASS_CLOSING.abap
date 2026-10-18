REPORT zsd_mass_closing.

TABLES vbak.

SELECT-OPTIONS s_vbeln FOR vbak-vbeln.

CLASS lcl_mass_closing DEFINITION FINAL.

  PUBLIC SECTION.

    METHODS run.

  PRIVATE SECTION.

    TYPES: BEGIN OF ty_item,
             vbeln TYPE vbeln_va,
             posnr TYPE posnr_va,
             matnr TYPE matnr,
           END OF ty_item,
           tt_item TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.

    CONSTANTS gc_days    TYPE i        VALUE 90.
    CONSTANTS gc_abgru   TYPE abgru_va VALUE '00'.
    CONSTANTS gc_error   TYPE string   VALUE ': An error occured, no change done to the sales order.'.
    CONSTANTS gc_success TYPE string   VALUE ': Sales order changed successfully.'.

    METHODS select_items
      RETURNING VALUE(rt_items) TYPE tt_item.

    METHODS close_order
      IMPORTING iv_vbeln TYPE vbeln_va
                it_items TYPE tt_item.

    METHODS has_error
      IMPORTING it_return       TYPE bapiret2_t
      RETURNING VALUE(rv_error) TYPE abap_bool.

ENDCLASS.

CLASS lcl_mass_closing IMPLEMENTATION.

  METHOD run.

    DATA(lt_items) = select_items( ).

    IF lt_items IS INITIAL.
      WRITE / 'No sales order to close'.
      RETURN.
    ENDIF.

    LOOP AT lt_items INTO DATA(ls_item) GROUP BY ls_item-vbeln INTO DATA(lv_vbeln).
      close_order( iv_vbeln = lv_vbeln
                   it_items = VALUE #( FOR ls_member IN GROUP lv_vbeln ( ls_member ) ) ).
    ENDLOOP.

  ENDMETHOD.

  METHOD select_items.

    DATA(lv_date) = CONV erdat( sy-datum - gc_days ).

    SELECT p~vbeln, p~posnr, p~matnr
      FROM vbak AS k
      INNER JOIN vbap AS p ON p~vbeln = k~vbeln
      WHERE k~vkorg IN ( '1200', '1500', '1600' )
        AND k~erdat <= @lv_date
        AND k~vbeln IN @s_vbeln
        AND k~vbtyp <> 'B'
        AND k~gbstk <> 'C'
        AND p~lfsta <> 'C'
        AND p~abgru = @space
      ORDER BY p~vbeln, p~posnr
      INTO TABLE @rt_items.

  ENDMETHOD.

  METHOD close_order.

    DATA lt_in     TYPE STANDARD TABLE OF bapisditm  WITH EMPTY KEY.
    DATA lt_inx    TYPE STANDARD TABLE OF bapisditmx WITH EMPTY KEY.
    DATA lt_return TYPE bapiret2_t.

    DATA(ls_hdrx) = VALUE bapisdh1x( updateflag = 'U' ).

    lt_in  = VALUE #( FOR ls_item IN it_items ( itm_number = ls_item-posnr
                                                material   = ls_item-matnr
                                                reason_rej = gc_abgru ) ).

    lt_inx = VALUE #( FOR ls_item IN it_items ( itm_number = ls_item-posnr
                                                updateflag = 'U'
                                                reason_rej = abap_true ) ).

    CALL FUNCTION 'BAPI_SALESORDER_CHANGE' "#EC CI_USAGE_OK[2438131]
      EXPORTING
        salesdocument    = iv_vbeln
        order_header_inx = ls_hdrx
      TABLES
        return           = lt_return
        order_item_in    = lt_in
        order_item_inx   = lt_inx.

    IF has_error( lt_return ) = abap_true.
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      WRITE / |{ iv_vbeln ALPHA = OUT }{ gc_error }|.
      LOOP AT lt_return INTO DATA(ls_return) WHERE type = 'E' OR type = 'A'.
        WRITE / |    { ls_return-message }|.
      ENDLOOP.
    ELSE.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = abap_true.
      WRITE / |{ iv_vbeln ALPHA = OUT }{ gc_success }|.
    ENDIF.

    ULINE.

  ENDMETHOD.

  METHOD has_error.

    rv_error = xsdbool( line_exists( it_return[ type = 'E' ] )
                     OR line_exists( it_return[ type = 'A' ] ) ).

  ENDMETHOD.

ENDCLASS.

START-OF-SELECTION.
  NEW lcl_mass_closing( )->run( ).
