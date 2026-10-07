*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : Nayera Makram
*&---------------------------------------------------------------------*
CLASS ZCL_PO_PR_LIMIT_CHECK DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS CO_ITEMCAT_LIMIT TYPE PSTYP   VALUE 'A'.
    CONSTANTS CO_MSGID         TYPE SYMSGID VALUE 'ZMM_PO'.
    CONSTANTS CO_MSGNO_EXCEED  TYPE SYMSGNO VALUE '001'.
    CONSTANTS CO_MSGNO_DETAIL  TYPE SYMSGNO VALUE '002'.

    TYPES: BEGIN OF TY_ERROR,
             EBELP    TYPE EBELP,
             BANFN    TYPE BANFN,
             BNFPO    TYPE BNFPO,
             PR       TYPE CHAR20,     " BANFN / BNFPO - ready for the message
             AMOUNT   TYPE CHAR30,     " expected value of this PO item
             EXPECTED TYPE CHAR30,     " expected value of the PR item
             CONSUMED TYPE CHAR30,     " already taken by other POs
             REST     TYPE CHAR30,     " still available
             ITEM     TYPE REF TO IF_PURCHASE_ORDER_ITEM_MM,
           END OF TY_ERROR,
           TY_ERRORS TYPE STANDARD TABLE OF TY_ERROR WITH EMPTY KEY.

    CLASS-METHODS GET_INSTANCE
      RETURNING VALUE(RO_INSTANCE) TYPE REF TO ZCL_PO_PR_LIMIT_CHECK.


    METHODS EXECUTE_FOR_PO
      IMPORTING IO_HEADER TYPE REF TO IF_PURCHASE_ORDER_MM
      EXPORTING ET_ERROR  TYPE TY_ERRORS
      CHANGING  CV_FAILED TYPE MMPUR_BOOL.


    METHODS EXECUTE_FOR_ITEM
      IMPORTING IO_ITEM TYPE REF TO IF_PURCHASE_ORDER_ITEM_MM.

  PRIVATE SECTION.

    TYPES: BEGIN OF TY_ITEM,
             BANFN  TYPE BANFN,
             BNFPO  TYPE BNFPO,
             EBELP  TYPE EBELP,
             AMOUNT TYPE BAPICURR_D,
             ITEM   TYPE REF TO IF_PURCHASE_ORDER_ITEM_MM,
           END OF TY_ITEM,
           TY_ITEMS TYPE STANDARD TABLE OF TY_ITEM WITH EMPTY KEY.

    TYPES: BEGIN OF TY_SUM,
             BANFN  TYPE BANFN,
             BNFPO  TYPE BNFPO,
             WAERS  TYPE WAERS,
             AMOUNT TYPE BAPICURR_D,
           END OF TY_SUM,
           TY_SUMS TYPE SORTED TABLE OF TY_SUM WITH UNIQUE KEY BANFN BNFPO.

    TYPES: BEGIN OF TY_BUFFER,
             BANFN    TYPE BANFN,
             BNFPO    TYPE BNFPO,
             WAERS    TYPE WAERS,
             EXPECTED TYPE BAPICURR_D,
             CONSUMED TYPE BAPICURR_D,
           END OF TY_BUFFER,
           TY_BUFFERS TYPE HASHED TABLE OF TY_BUFFER
                      WITH UNIQUE KEY BANFN BNFPO WAERS.

    CLASS-DATA GO_INSTANCE TYPE REF TO ZCL_PO_PR_LIMIT_CHECK.

    DATA: MV_EBELN  TYPE EBELN,
          MV_WAERS  TYPE WAERS,
          MT_ITEM   TYPE TY_ITEMS,
          MT_ERROR  TYPE TY_ERRORS,
          MT_BUFFER TYPE TY_BUFFERS.

    METHODS COMPUTE_ERRORS
      IMPORTING IO_HEADER TYPE REF TO IF_PURCHASE_ORDER_MM.

    METHODS COLLECT_PO_VALUES
      IMPORTING IO_HEADER     TYPE REF TO IF_PURCHASE_ORDER_MM
      RETURNING VALUE(RT_SUM) TYPE TY_SUMS.

    METHODS GET_LIMIT_DATA
      IMPORTING IS_SUM      TYPE TY_SUM
      EXPORTING EV_EXPECTED TYPE BAPICURR_D
                EV_CONSUMED TYPE BAPICURR_D.

    METHODS GET_EXPECTED_VALUE
      IMPORTING IV_BANFN        TYPE BANFN
                IV_BNFPO        TYPE BNFPO
      RETURNING VALUE(RV_VALUE) TYPE BAPICURR_D.

    METHODS GET_CONSUMED_VALUE
      IMPORTING IS_SUM          TYPE TY_SUM
      RETURNING VALUE(RV_VALUE) TYPE BAPICURR_D.

    METHODS COLLECT_ERRORS
      IMPORTING IS_SUM      TYPE TY_SUM
                IV_EXPECTED TYPE BAPICURR_D
                IV_CONSUMED TYPE BAPICURR_D
                IV_REST     TYPE BAPICURR_D.

    METHODS RAISE_ERRORS.

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



CLASS ZCL_PO_PR_LIMIT_CHECK IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_PO_PR_LIMIT_CHECK->COLLECT_ERRORS
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_SUM                         TYPE        TY_SUM
* | [--->] IV_EXPECTED                    TYPE        BAPICURR_D
* | [--->] IV_CONSUMED                    TYPE        BAPICURR_D
* | [--->] IV_REST                        TYPE        BAPICURR_D
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD COLLECT_ERRORS.

    DATA(LV_PR)   = |{ IS_SUM-BANFN } / { IS_SUM-BNFPO ALPHA = OUT }|.
    DATA(LV_EXP)  = FORMAT_AMOUNT( IV_AMOUNT = IV_EXPECTED IV_WAERS = IS_SUM-WAERS ).
    DATA(LV_CONS) = FORMAT_AMOUNT( IV_AMOUNT = IV_CONSUMED IV_WAERS = IS_SUM-WAERS ).
    DATA(LV_REST) = FORMAT_AMOUNT( IV_AMOUNT = IV_REST     IV_WAERS = IS_SUM-WAERS ).

    LOOP AT MT_ITEM INTO DATA(LS_ITEM)
         WHERE BANFN = IS_SUM-BANFN AND BNFPO = IS_SUM-BNFPO.

      APPEND VALUE #( EBELP    = LS_ITEM-EBELP
                      BANFN    = IS_SUM-BANFN
                      BNFPO    = IS_SUM-BNFPO
                      PR       = LV_PR
                      AMOUNT   = FORMAT_AMOUNT( IV_AMOUNT = LS_ITEM-AMOUNT
                                                IV_WAERS  = IS_SUM-WAERS )
                      EXPECTED = LV_EXP
                      CONSUMED = LV_CONS
                      REST     = LV_REST
                      ITEM     = LS_ITEM-ITEM ) TO MT_ERROR.

    ENDLOOP.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_PO_PR_LIMIT_CHECK->COLLECT_PO_VALUES
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_HEADER                      TYPE REF TO IF_PURCHASE_ORDER_MM
* | [<-()] RT_SUM                         TYPE        TY_SUMS
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD COLLECT_PO_VALUES.

    LOOP AT IO_HEADER->GET_ITEMS( ) INTO DATA(LS_ITEM).

      DATA(LS_POTDATA) = LS_ITEM-ITEM->GET_DATA( ).
      CHECK LS_POTDATA-BANFN IS NOT INITIAL
        AND LS_POTDATA-BNFPO IS NOT INITIAL
        AND LS_POTDATA-LOEKZ IS INITIAL
        AND LS_POTDATA-PSTYP EQ CO_ITEMCAT_LIMIT.

      APPEND VALUE #( BANFN  = LS_POTDATA-BANFN
                      BNFPO  = LS_POTDATA-BNFPO
                      EBELP  = LS_POTDATA-EBELP
                      AMOUNT = LS_POTDATA-EFFWR
                      ITEM   = LS_ITEM-ITEM ) TO MT_ITEM.

      READ TABLE RT_SUM ASSIGNING FIELD-SYMBOL(<LS_SUM>)
           WITH TABLE KEY BANFN = LS_POTDATA-BANFN
                          BNFPO = LS_POTDATA-BNFPO.
      IF SY-SUBRC <> 0.
        INSERT VALUE #( BANFN = LS_POTDATA-BANFN
                        BNFPO = LS_POTDATA-BNFPO
                        WAERS = MV_WAERS )
               INTO TABLE RT_SUM ASSIGNING <LS_SUM>.
      ENDIF.
      <LS_SUM>-AMOUNT += LS_POTDATA-EFFWR.

    ENDLOOP.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_PO_PR_LIMIT_CHECK->COMPUTE_ERRORS
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_HEADER                      TYPE REF TO IF_PURCHASE_ORDER_MM
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD COMPUTE_ERRORS.

    DATA: LV_EXPECTED TYPE BAPICURR_D,
          LV_CONSUMED TYPE BAPICURR_D,
          LV_REST     TYPE BAPICURR_D.

    CLEAR: MT_ITEM, MT_ERROR.
    CHECK IO_HEADER IS BOUND.

    DATA(LS_HEADER) = IO_HEADER->GET_DATA( ).
    MV_EBELN = LS_HEADER-EBELN.
    MV_WAERS = LS_HEADER-WAERS.

*   1) expected value of THIS document per PR item
*      (several PO items may refer to the same PR item)
    DATA(LT_SUM) = COLLECT_PO_VALUES( IO_HEADER ).
    CHECK LT_SUM IS NOT INITIAL.

    LOOP AT LT_SUM INTO DATA(LS_SUM).

*     2) PR expected value and what other POs already consumed
      GET_LIMIT_DATA( EXPORTING IS_SUM      = LS_SUM
                      IMPORTING EV_EXPECTED = LV_EXPECTED
                                EV_CONSUMED = LV_CONSUMED ).
      CHECK LV_EXPECTED > 0.            " no limit maintained -> nothing to check

*     3) what is left for this PO
      LV_REST = LV_EXPECTED - LV_CONSUMED.

*     4) still inside the limit?
      CHECK LS_SUM-AMOUNT > LV_REST.

      COLLECT_ERRORS( IS_SUM      = LS_SUM
                      IV_EXPECTED = LV_EXPECTED
                      IV_CONSUMED = LV_CONSUMED
                      IV_REST     = LV_REST ).

    ENDLOOP.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_PO_PR_LIMIT_CHECK->EXECUTE_FOR_ITEM
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_ITEM                        TYPE REF TO IF_PURCHASE_ORDER_ITEM_MM
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD EXECUTE_FOR_ITEM.
    CHECK IO_ITEM IS BOUND.

    DATA(LS_ITEMDATA) = IO_ITEM->GET_DATA( ).
    CHECK LS_ITEMDATA-BANFN IS NOT INITIAL
      AND LS_ITEMDATA-BNFPO IS NOT INITIAL
      AND LS_ITEMDATA-LOEKZ IS INITIAL
      AND LS_ITEMDATA-PSTYP EQ CO_ITEMCAT_LIMIT.

    DATA(LO_HEADER) = IO_ITEM->GET_HEADER( ).
    CHECK LO_HEADER IS BOUND.
    COMPUTE_ERRORS( LO_HEADER ).
    DELETE MT_ERROR WHERE EBELP <> LS_ITEMDATA-EBELP.
    CHECK MT_ERROR IS NOT INITIAL.
    RAISE_ERRORS( ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_PO_PR_LIMIT_CHECK->EXECUTE_FOR_PO
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_HEADER                      TYPE REF TO IF_PURCHASE_ORDER_MM
* | [<---] ET_ERROR                       TYPE        TY_ERRORS
* | [<-->] CV_FAILED                      TYPE        MMPUR_BOOL
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD EXECUTE_FOR_PO.
    CLEAR: ET_ERROR, MT_BUFFER.

    COMPUTE_ERRORS( IO_HEADER ).
    CHECK MT_ERROR IS NOT INITIAL.

    RAISE_ERRORS( ).

    ET_ERROR  = MT_ERROR.
    CV_FAILED = CL_MMPUR_CONSTANTS=>YES.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_PO_PR_LIMIT_CHECK->FORMAT_AMOUNT
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
* | Instance Private Method ZCL_PO_PR_LIMIT_CHECK->GET_CONSUMED_VALUE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_SUM                         TYPE        TY_SUM
* | [<-()] RV_VALUE                       TYPE        BAPICURR_D
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD GET_CONSUMED_VALUE.
*    SELECT SUM( P~EFFWR )
    SELECT SUM( P~EXPECTED_VALUE )
      FROM EKPO AS P
      INNER JOIN EKKO AS K ON K~EBELN = P~EBELN
      WHERE P~BANFN =  @IS_SUM-BANFN
        AND P~BNFPO =  @IS_SUM-BNFPO
        AND P~EBELN <> @MV_EBELN
        AND P~LOEKZ =  @SPACE
        AND K~WAERS =  @IS_SUM-WAERS
      INTO @RV_VALUE.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_PO_PR_LIMIT_CHECK->GET_EXPECTED_VALUE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_BANFN                       TYPE        BANFN
* | [--->] IV_BNFPO                       TYPE        BNFPO
* | [<-()] RV_VALUE                       TYPE        BAPICURR_D
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD GET_EXPECTED_VALUE.
    SELECT SINGLE EXPECTED_VALUE
      FROM EBAN
      WHERE BANFN = @IV_BANFN
        AND BNFPO = @IV_BNFPO
        AND LOEKZ = @SPACE
        AND EBAKZ = @SPACE
      INTO @RV_VALUE.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_PO_PR_LIMIT_CHECK=>GET_INSTANCE
* +-------------------------------------------------------------------------------------------------+
* | [<-()] RO_INSTANCE                    TYPE REF TO ZCL_PO_PR_LIMIT_CHECK
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD GET_INSTANCE.
    IF GO_INSTANCE IS NOT BOUND.
      CREATE OBJECT GO_INSTANCE.
    ENDIF.
    RO_INSTANCE = GO_INSTANCE.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_PO_PR_LIMIT_CHECK->GET_LIMIT_DATA
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_SUM                         TYPE        TY_SUM
* | [<---] EV_EXPECTED                    TYPE        BAPICURR_D
* | [<---] EV_CONSUMED                    TYPE        BAPICURR_D
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD GET_LIMIT_DATA.
    READ TABLE MT_BUFFER INTO DATA(LS_BUFFER)
         WITH TABLE KEY BANFN = IS_SUM-BANFN
                        BNFPO = IS_SUM-BNFPO
                        WAERS = IS_SUM-WAERS.
    IF SY-SUBRC <> 0.
      LS_BUFFER-BANFN    = IS_SUM-BANFN.
      LS_BUFFER-BNFPO    = IS_SUM-BNFPO.
      LS_BUFFER-WAERS    = IS_SUM-WAERS.
      LS_BUFFER-EXPECTED = GET_EXPECTED_VALUE( IV_BANFN = IS_SUM-BANFN
                                               IV_BNFPO = IS_SUM-BNFPO ).
      LS_BUFFER-CONSUMED = GET_CONSUMED_VALUE( IS_SUM ).
      INSERT LS_BUFFER INTO TABLE MT_BUFFER.
    ENDIF.

    EV_EXPECTED = LS_BUFFER-EXPECTED.
    EV_CONSUMED = LS_BUFFER-CONSUMED.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_PO_PR_LIMIT_CHECK->RAISE_ERRORS
* +-------------------------------------------------------------------------------------------------+
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD RAISE_ERRORS.

    DATA LV_EBELP TYPE CHAR5.

    LOOP AT MT_ERROR INTO DATA(LS_ERROR).

      LV_EBELP = |{ LS_ERROR-EBELP ALPHA = OUT }|.

      RAISE_MESSAGE( IV_MSGTY = 'E'
                     IV_MSGID = CO_MSGID
                     IV_MSGNO = CO_MSGNO_EXCEED
                     IV_MSGV1 = LV_EBELP
                     IV_MSGV2 = LS_ERROR-AMOUNT
                     IV_MSGV3 = LS_ERROR-PR
                     IV_MSGV4 = LS_ERROR-REST ).

      RAISE_MESSAGE( IV_MSGTY = 'I'
                     IV_MSGID = CO_MSGID
                     IV_MSGNO = CO_MSGNO_DETAIL
                     IV_MSGV1 = LS_ERROR-PR
                     IV_MSGV2 = LS_ERROR-EXPECTED
                     IV_MSGV3 = LS_ERROR-CONSUMED
                     IV_MSGV4 = LS_ERROR-REST ).

      LS_ERROR-ITEM->INVALIDATE( ).
    ENDLOOP.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_PO_PR_LIMIT_CHECK->RAISE_MESSAGE
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
ENDCLASS.
