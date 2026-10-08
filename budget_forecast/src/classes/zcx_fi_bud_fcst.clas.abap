"! <p class="shorttext synchronized">Budget Forecast - exception (messages of class ZBUD_FCST)</p>
"! Raised with RAISE EXCEPTION TYPE zcx_fi_bud_fcst MESSAGE eNNN(zbud_fcst) WITH ...
"! FIELDNAME / ITEM_INDEX tell the screen which item cell to put the cursor on.
CLASS zcx_fi_bud_fcst DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_t100_dyn_msg.
    INTERFACES if_t100_message.

    "! Item field with the error (e.g. 'PRIORITY'), initial for header errors
    DATA mv_fieldname  TYPE fieldname READ-ONLY.
    "! Line of the item table with the error, 0 for header errors
    DATA mv_item_index TYPE i READ-ONLY.

    METHODS constructor
      IMPORTING
        textid     LIKE if_t100_message=>t100key OPTIONAL
        previous   LIKE previous OPTIONAL
        fieldname  TYPE fieldname OPTIONAL
        item_index TYPE i OPTIONAL.

ENDCLASS.



CLASS zcx_fi_bud_fcst IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).

    mv_fieldname  = fieldname.
    mv_item_index = item_index.

    CLEAR me->textid.
    if_t100_message~t100key = COND #( WHEN textid IS INITIAL
                                      THEN if_t100_message=>default_textid
                                      ELSE textid ).
  ENDMETHOD.

ENDCLASS.
