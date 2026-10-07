*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : Nayera Makram
*&---------------------------------------------------------------------*
*& PR types Z306/Z307 -> PO types Z406/Z407 (ME21N / ME22N)
*&  1) PO item created with reference to the PR item:
*&     EBAN-PREIS is copied to EKPO-EXPECTED_VALUE
*&  2) error if EKPO-EXPECTED_VALUE > EBAN-PREIS
*&     (Expected value more than purchase requisition valuation price)
*&  3) PR item closing on save is done by ZCL_PR_AUTO_CLOSE
*&---------------------------------------------------------------------*
CLASS ZCL_PO_PR_PREIS_CHECK DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS CO_MSGID       TYPE SYMSGID VALUE 'ZMM_PO'.
    CONSTANTS CO_MSGNO_PREIS TYPE SYMSGNO VALUE '003'.

    TYPES: BEGIN OF TY_PR,
             BANFN TYPE BANFN,
             BNFPO TYPE BNFPO,
             BSART TYPE EBAN-BSART,
             PREIS TYPE EBAN-PREIS,
             WAERS TYPE EBAN-WAERS,
           END OF TY_PR.

    CLASS-METHODS GET_INSTANCE
      RETURNING VALUE(RO_INSTANCE) TYPE REF TO ZCL_PO_PR_PREIS_CHECK.

    CLASS-METHODS IS_PO_TYPE
      IMPORTING IV_BSART         TYPE EKKO-BSART
      RETURNING VALUE(RV_RESULT) TYPE ABAP_BOOL.

    CLASS-METHODS IS_PR_TYPE
      IMPORTING IV_BSART         TYPE EBAN-BSART
      RETURNING VALUE(RV_RESULT) TYPE ABAP_BOOL.

    CLASS-METHODS GET_PR_DATA
      IMPORTING IV_BANFN     TYPE BANFN
                IV_BNFPO     TYPE BNFPO
      RETURNING VALUE(RS_PR) TYPE TY_PR.

    METHODS EXECUTE_FOR_ITEM
      IMPORTING IO_ITEM TYPE REF TO IF_PURCHASE_ORDER_ITEM_MM.

    METHODS EXECUTE_FOR_PO
      IMPORTING IO_HEADER TYPE REF TO IF_PURCHASE_ORDER_MM
      CHANGING  CV_FAILED TYPE MMPUR_BOOL.

    METHODS RESET.

  PRIVATE SECTION.

*   PO items whose expected value was already defaulted from the PR,
*   so a value the user typed in afterwards is not overwritten again
    TYPES: BEGIN OF TY_DONE,
             ITEM  TYPE REF TO IF_PURCHASE_ORDER_ITEM_MM,
             BANFN TYPE BANFN,
             BNFPO TYPE BNFPO,
           END OF TY_DONE,
           TY_DONES TYPE HASHED TABLE OF TY_DONE WITH UNIQUE KEY ITEM.

    CLASS-DATA GO_INSTANCE TYPE REF TO ZCL_PO_PR_PREIS_CHECK.

    DATA MT_DONE TYPE TY_DONES.

    METHODS IS_ACTIVE
      RETURNING VALUE(RV_RESULT) TYPE ABAP_BOOL.

    METHODS GET_RELEVANT_PR
      IMPORTING IO_ITEM      TYPE REF TO IF_PURCHASE_ORDER_ITEM_MM
                IS_ITEM      TYPE MEPOITEM
      RETURNING VALUE(RS_PR) TYPE TY_PR.

    METHODS DEFAULT_EXPECTED_VALUE
      IMPORTING IO_ITEM TYPE REF TO IF_PURCHASE_ORDER_ITEM_MM
                IS_PR   TYPE TY_PR
      CHANGING  CS_ITEM TYPE MEPOITEM.

    METHODS CHECK_ITEM
      IMPORTING IO_ITEM          TYPE REF TO IF_PURCHASE_ORDER_ITEM_MM
                IS_ITEM          TYPE MEPOITEM
                IS_PR            TYPE TY_PR
      RETURNING VALUE(RV_FAILED) TYPE ABAP_BOOL.

    METHODS RAISE_MESSAGE
      IMPORTING IV_MSGTY TYPE SYMSGTY
                IV_MSGID TYPE SYMSGID
                IV_MSGNO TYPE SYMSGNO
                IV_MSGV1 TYPE ANY OPTIONAL
                IV_MSGV2 TYPE ANY OPTIONAL
                IV_MSGV3 TYPE ANY OPTIONAL
                IV_MSGV4 TYPE ANY OPTIONAL.

    METHODS FORMAT_AMOUNT
      IMPORTING IV_AMOUNT      TYPE BAPICURR_D
                IV_WAERS       TYPE WAERS
      RETURNING VALUE(RV_TEXT) TYPE CHAR30.

ENDCLASS.



CLASS ZCL_PO_PR_PREIS_CHECK IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_PO_PR_PREIS_CHECK->CHECK_ITEM
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_ITEM                        TYPE REF TO IF_PURCHASE_ORDER_ITEM_MM
* | [--->] IS_ITEM                        TYPE        MEPOITEM
* | [--->] IS_PR                          TYPE        TY_PR
* | [<-()] RV_FAILED                      TYPE        ABAP_BOOL
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD CHECK_ITEM.

    CHECK IS_ITEM-EXPECTED_VALUE > IS_PR-PREIS.

    RV_FAILED = ABAP_TRUE.

*   Item &1: Expected value &2 more than PR &3 valuation price &4
    RAISE_MESSAGE( IV_MSGTY = 'E'
                   IV_MSGID = CO_MSGID
                   IV_MSGNO = CO_MSGNO_PREIS
                   IV_MSGV1 = |{ IS_ITEM-EBELP ALPHA = OUT }|
                   IV_MSGV2 = FORMAT_AMOUNT( IV_AMOUNT = CONV #( IS_ITEM-EXPECTED_VALUE )
                                             IV_WAERS  = IS_PR-WAERS )
                   IV_MSGV3 = |{ IS_PR-BANFN } / { IS_PR-BNFPO ALPHA = OUT }|
                   IV_MSGV4 = FORMAT_AMOUNT( IV_AMOUNT = CONV #( IS_PR-PREIS )
                                             IV_WAERS  = IS_PR-WAERS ) ).

    IO_ITEM->INVALIDATE( ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_PO_PR_PREIS_CHECK->DEFAULT_EXPECTED_VALUE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_ITEM                        TYPE REF TO IF_PURCHASE_ORDER_ITEM_MM
* | [--->] IS_PR                          TYPE        TY_PR
* | [<-->] CS_ITEM                        TYPE        MEPOITEM
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD DEFAULT_EXPECTED_VALUE.

    READ TABLE MT_DONE ASSIGNING FIELD-SYMBOL(<LS_DONE>)
         WITH TABLE KEY ITEM = IO_ITEM.
    IF SY-SUBRC <> 0.
      INSERT VALUE #( ITEM  = IO_ITEM
                      BANFN = CS_ITEM-BANFN
                      BNFPO = CS_ITEM-BNFPO )
             INTO TABLE MT_DONE.

*     item already saved (ME22N) -> keep its value, only check it
      SELECT SINGLE @ABAP_TRUE
        FROM EKPO
        WHERE EBELN = @CS_ITEM-EBELN
          AND EBELP = @CS_ITEM-EBELP
        INTO @DATA(LV_SAVED).
      CHECK LV_SAVED = ABAP_FALSE.

    ELSE.
*     already defaulted for this PR item -> the user's value stays
      CHECK <LS_DONE>-BANFN <> CS_ITEM-BANFN
         OR <LS_DONE>-BNFPO <> CS_ITEM-BNFPO.
      <LS_DONE>-BANFN = CS_ITEM-BANFN.
      <LS_DONE>-BNFPO = CS_ITEM-BNFPO.
    ENDIF.

    CHECK CS_ITEM-EXPECTED_VALUE <> IS_PR-PREIS.
    CS_ITEM-EXPECTED_VALUE = IS_PR-PREIS.
    IO_ITEM->SET_DATA( CS_ITEM ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_PO_PR_PREIS_CHECK->EXECUTE_FOR_ITEM
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_ITEM                        TYPE REF TO IF_PURCHASE_ORDER_ITEM_MM
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD EXECUTE_FOR_ITEM.

    CHECK IO_ITEM IS BOUND
      AND IS_ACTIVE( ) = ABAP_TRUE.

    DATA(LS_ITEM) = IO_ITEM->GET_DATA( ).
    DATA(LS_PR)   = GET_RELEVANT_PR( IO_ITEM = IO_ITEM
                                     IS_ITEM = LS_ITEM ).
    CHECK LS_PR IS NOT INITIAL.

*   1) EBAN-PREIS -> EKPO-EXPECTED_VALUE
    DEFAULT_EXPECTED_VALUE( EXPORTING IO_ITEM = IO_ITEM
                                      IS_PR   = LS_PR
                            CHANGING  CS_ITEM = LS_ITEM ).

*   2) expected value must not exceed the PR valuation price
    CHECK_ITEM( IO_ITEM = IO_ITEM
                IS_ITEM = LS_ITEM
                IS_PR   = LS_PR ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_PO_PR_PREIS_CHECK->EXECUTE_FOR_PO
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_HEADER                      TYPE REF TO IF_PURCHASE_ORDER_MM
* | [<-->] CV_FAILED                      TYPE        MMPUR_BOOL
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD EXECUTE_FOR_PO.

    CHECK IO_HEADER IS BOUND
      AND IS_ACTIVE( ) = ABAP_TRUE.

    LOOP AT IO_HEADER->GET_ITEMS( ) INTO DATA(LS_ITEMS).

      DATA(LS_ITEM) = LS_ITEMS-ITEM->GET_DATA( ).
      DATA(LS_PR)   = GET_RELEVANT_PR( IO_ITEM = LS_ITEMS-ITEM
                                       IS_ITEM = LS_ITEM ).
      CHECK LS_PR IS NOT INITIAL.

      IF CHECK_ITEM( IO_ITEM = LS_ITEMS-ITEM
                     IS_ITEM = LS_ITEM
                     IS_PR   = LS_PR ) = ABAP_TRUE.
        CV_FAILED = CL_MMPUR_CONSTANTS=>YES.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_PO_PR_PREIS_CHECK->FORMAT_AMOUNT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_AMOUNT                      TYPE        BAPICURR_D
* | [--->] IV_WAERS                       TYPE        WAERS
* | [<-()] RV_TEXT                        TYPE        CHAR30
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD FORMAT_AMOUNT.
    DATA LV_AMT TYPE P LENGTH 13 DECIMALS 2.
    LV_AMT  = IV_AMOUNT.
    RV_TEXT = |{ LV_AMT NUMBER = USER } { IV_WAERS }|.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_PO_PR_PREIS_CHECK=>GET_INSTANCE
* +-------------------------------------------------------------------------------------------------+
* | [<-()] RO_INSTANCE                    TYPE REF TO ZCL_PO_PR_PREIS_CHECK
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD GET_INSTANCE.
    IF GO_INSTANCE IS NOT BOUND.
      CREATE OBJECT GO_INSTANCE.
    ENDIF.
    RO_INSTANCE = GO_INSTANCE.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_PO_PR_PREIS_CHECK=>GET_PR_DATA
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_BANFN                       TYPE        BANFN
* | [--->] IV_BNFPO                       TYPE        BNFPO
* | [<-()] RS_PR                          TYPE        TY_PR
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD GET_PR_DATA.
*   no EBAKZ filter: in ME22N the PR item is already closed by the
*   first save, but the check must still apply
    SELECT SINGLE BANFN, BNFPO, BSART, PREIS, WAERS
      FROM EBAN
      WHERE BANFN = @IV_BANFN
        AND BNFPO = @IV_BNFPO
        AND LOEKZ = @SPACE
      INTO CORRESPONDING FIELDS OF @RS_PR.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_PO_PR_PREIS_CHECK->GET_RELEVANT_PR
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_ITEM                        TYPE REF TO IF_PURCHASE_ORDER_ITEM_MM
* | [--->] IS_ITEM                        TYPE        MEPOITEM
* | [<-()] RS_PR                          TYPE        TY_PR
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD GET_RELEVANT_PR.

    CHECK IS_ITEM-BANFN IS NOT INITIAL
      AND IS_ITEM-BNFPO IS NOT INITIAL
      AND IS_ITEM-LOEKZ IS INITIAL.

    DATA(LO_HEADER) = IO_ITEM->GET_HEADER( ).
    CHECK LO_HEADER IS BOUND.
    DATA(LS_HEADER) = LO_HEADER->GET_DATA( ).
    CHECK IS_PO_TYPE( LS_HEADER-BSART ) = ABAP_TRUE.

    DATA(LS_PR) = GET_PR_DATA( IV_BANFN = IS_ITEM-BANFN
                               IV_BNFPO = IS_ITEM-BNFPO ).
    CHECK IS_PR_TYPE( LS_PR-BSART ) = ABAP_TRUE.

*   PR price in another currency is not comparable with the PO
    IF LS_PR-WAERS IS INITIAL.
      LS_PR-WAERS = LS_HEADER-WAERS.
    ENDIF.
    CHECK LS_PR-WAERS = LS_HEADER-WAERS.

    RS_PR = LS_PR.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_PO_PR_PREIS_CHECK->IS_ACTIVE
* +-------------------------------------------------------------------------------------------------+
* | [<-()] RV_RESULT                      TYPE        ABAP_BOOL
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD IS_ACTIVE.
    RV_RESULT = XSDBOOL( SY-TCODE = 'ME21N' OR SY-TCODE = 'ME22N' ).
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_PO_PR_PREIS_CHECK=>IS_PO_TYPE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_BSART                       TYPE        EKKO-BSART
* | [<-()] RV_RESULT                      TYPE        ABAP_BOOL
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD IS_PO_TYPE.
    RV_RESULT = XSDBOOL( IV_BSART = 'Z406' OR IV_BSART = 'Z407' ).
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_PO_PR_PREIS_CHECK=>IS_PR_TYPE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_BSART                       TYPE        EBAN-BSART
* | [<-()] RV_RESULT                      TYPE        ABAP_BOOL
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD IS_PR_TYPE.
    RV_RESULT = XSDBOOL( IV_BSART = 'Z306' OR IV_BSART = 'Z307' ).
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_PO_PR_PREIS_CHECK->RAISE_MESSAGE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_MSGTY                       TYPE        SYMSGTY
* | [--->] IV_MSGID                       TYPE        SYMSGID
* | [--->] IV_MSGNO                       TYPE        SYMSGNO
* | [--->] IV_MSGV1                       TYPE        ANY(optional)
* | [--->] IV_MSGV2                       TYPE        ANY(optional)
* | [--->] IV_MSGV3                       TYPE        ANY(optional)
* | [--->] IV_MSGV4                       TYPE        ANY(optional)
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD RAISE_MESSAGE.
*   inlined replacement of macro MMPUR_MESSAGE_FORCED (include MM_MESSAGES_MAC)

    DATA: LV_TABIX TYPE SY-TABIX,
          LV_SUBRC TYPE SY-SUBRC,
          LV_DUMMY TYPE STRING.

    LV_TABIX = SY-TABIX.
    LV_SUBRC = SY-SUBRC.

    MESSAGE ID IV_MSGID TYPE IV_MSGTY NUMBER IV_MSGNO
            WITH IV_MSGV1 IV_MSGV2 IV_MSGV3 IV_MSGV4
            INTO LV_DUMMY.

    CALL METHOD CL_MESSAGE_MM=>CREATE
      EXPORTING
        IM_MSGID         = IV_MSGID
        IM_MSGTY         = IV_MSGTY
        IM_MSGNO         = IV_MSGNO
        IM_MSGV1         = SY-MSGV1
        IM_MSGV2         = SY-MSGV2
        IM_MSGV3         = SY-MSGV3
        IM_MSGV4         = SY-MSGV4
        IM_FORCE_COLLECT = CL_MMPUR_CONSTANTS=>YES
      EXCEPTIONS
        FAILURE          = 1
        DIALOG           = 2
        OTHERS           = 3.
    IF SY-SUBRC <> 0.
      MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
              WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
    ENDIF.

    SY-SUBRC = LV_SUBRC.
    SY-TABIX = LV_TABIX.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_PO_PR_PREIS_CHECK->RESET
* +-------------------------------------------------------------------------------------------------+
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD RESET.
    CLEAR MT_DONE.
  ENDMETHOD.
ENDCLASS.
