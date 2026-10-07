*&---------------------------------------------------------------------*
*& Technical Consultant  : Hassan Diab
*& Functional Consultant : Nayera Makram
*&---------------------------------------------------------------------*
class ZCL_PR_AUTO_CLOSE definition
  public
  final
  create public .

public section.

  constants CO_ITEMCAT_LIMIT type PSTYP value 'A' ##NO_TEXT.

  methods CONSTRUCTOR
    importing
      !IV_SOURCE type CHAR4 default 'BADI'
      !IV_TESTRUN type ABAP_BOOL default ABAP_FALSE .
  methods EXECUTE_FOR_PO
    importing
      !IO_HEADER type ref to IF_PURCHASE_ORDER_MM .
  PRIVATE SECTION.

    TYPES: BEGIN OF TY_SUM,
             BANFN  TYPE BANFN,
             BNFPO  TYPE BNFPO,
             EBELP  TYPE EBELP,
             WAERS  TYPE WAERS,
             AMOUNT TYPE BAPICURR_D,
           END OF TY_SUM,
           TY_SUMS TYPE SORTED TABLE OF TY_SUM WITH UNIQUE KEY BANFN BNFPO.

    DATA: MV_SOURCE  TYPE CHAR4,
          MV_TESTRUN TYPE ABAP_BOOL,
          MV_EBELN   TYPE EBELN,
          MV_WAERS   TYPE WAERS,
          MV_BSART   TYPE EKKO-BSART.

    METHODS COLLECT_PO_VALUES
      IMPORTING IO_HEADER     TYPE REF TO IF_PURCHASE_ORDER_MM
      RETURNING VALUE(RT_SUM) TYPE TY_SUMS.

    METHODS ADD_POSTED_VALUES
      CHANGING CT_SUM TYPE TY_SUMS.

    METHODS GET_EXPECTED_VALUE
      IMPORTING IV_BANFN        TYPE BANFN
                IV_BNFPO        TYPE BNFPO
      RETURNING VALUE(RV_VALUE) TYPE BAPICURR_D.

    METHODS CLOSE_PR_ITEM
      IMPORTING IS_SUM           TYPE TY_SUM
      RETURNING VALUE(RT_RETURN) TYPE BAPIRET2_T.

    METHODS WRITE_LOG
      IMPORTING IS_SUM    TYPE TY_SUM
                IT_RETURN TYPE BAPIRET2_T.

ENDCLASS.



CLASS ZCL_PR_AUTO_CLOSE IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_PR_AUTO_CLOSE->ADD_POSTED_VALUES
* +-------------------------------------------------------------------------------------------------+
* | [<-->] CT_SUM                         TYPE        TY_SUMS
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD ADD_POSTED_VALUES.

    LOOP AT CT_SUM ASSIGNING FIELD-SYMBOL(<LS_SUM>).
      SELECT P~EFFWR
        FROM EKPO AS P
        INNER JOIN EKKO AS K ON K~EBELN = P~EBELN
        WHERE P~BANFN =  @<LS_SUM>-BANFN
          AND P~BNFPO =  @<LS_SUM>-BNFPO
          AND P~EBELN <> @MV_EBELN
          AND P~LOEKZ =  @SPACE
          AND K~WAERS =  @<LS_SUM>-WAERS   " ignore other currencies
        INTO TABLE @DATA(LT_EFFWR).

      LOOP AT LT_EFFWR INTO DATA(LS_EFFWR).
        <LS_SUM>-AMOUNT += LS_EFFWR-EFFWR.
      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_PR_AUTO_CLOSE->CLOSE_PR_ITEM
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_SUM                         TYPE        TY_SUM
* | [<-()] RT_RETURN                      TYPE        BAPIRET2_T
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD CLOSE_PR_ITEM.
    DATA: LT_PRITEM   TYPE STANDARD TABLE OF BAPIMEREQITEMIMP,
          LT_PRITEMX  TYPE STANDARD TABLE OF BAPIMEREQITEMX,
          LS_PRHDREXP TYPE BAPIMEREQHEADER.
    LT_PRITEM  = VALUE #( ( PREQ_ITEM = IS_SUM-BNFPO CLOSED = ABAP_TRUE ) ).
    LT_PRITEMX = VALUE #( ( PREQ_ITEM = IS_SUM-BNFPO CLOSED = ABAP_TRUE ) ).
    CALL FUNCTION 'BAPI_PR_CHANGE'
      EXPORTING
        NUMBER      = IS_SUM-BANFN
      IMPORTING
        PRHEADEREXP = LS_PRHDREXP
      TABLES
        RETURN      = RT_RETURN
        PRITEM      = LT_PRITEM
        PRITEMX     = LT_PRITEMX.
    IF LINE_EXISTS( RT_RETURN[ TYPE = 'E' ] )
    OR LINE_EXISTS( RT_RETURN[ TYPE = 'A' ] )
    OR MV_TESTRUN = ABAP_TRUE.
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    ELSE.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING WAIT = ABAP_TRUE.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_PR_AUTO_CLOSE->COLLECT_PO_VALUES
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_HEADER                      TYPE REF TO IF_PURCHASE_ORDER_MM
* | [<-()] RT_SUM                         TYPE        TY_SUMS
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD COLLECT_PO_VALUES.

    LOOP AT IO_HEADER->GET_ITEMS( ) INTO DATA(LS_ITEM).
      DATA(LS_POTDATA) = LS_ITEM-ITEM->GET_DATA( ).
      CHECK LS_POTDATA-BANFN IS NOT INITIAL
        AND LS_POTDATA-BNFPO IS NOT INITIAL
        AND LS_POTDATA-LOEKZ IS INITIAL.
*     limit items, or PR Z306/Z307 -> PO Z406/Z407
      CHECK LS_POTDATA-PSTYP EQ CO_ITEMCAT_LIMIT
         OR ( ZCL_PO_PR_PREIS_CHECK=>IS_PO_TYPE( MV_BSART ) = ABAP_TRUE
          AND ZCL_PO_PR_PREIS_CHECK=>IS_PR_TYPE(
                ZCL_PO_PR_PREIS_CHECK=>GET_PR_DATA( IV_BANFN = LS_POTDATA-BANFN
                                                    IV_BNFPO = LS_POTDATA-BNFPO )-BSART ) = ABAP_TRUE ).
      READ TABLE RT_SUM ASSIGNING FIELD-SYMBOL(<LS_SUM>)
           WITH TABLE KEY BANFN = LS_POTDATA-BANFN
                          BNFPO = LS_POTDATA-BNFPO.
      IF SY-SUBRC <> 0.
        INSERT VALUE #( BANFN = LS_POTDATA-BANFN
                        BNFPO = LS_POTDATA-BNFPO
                        EBELP = LS_POTDATA-EBELP
                        WAERS = MV_WAERS )
               INTO TABLE RT_SUM ASSIGNING <LS_SUM>.
      ENDIF.
      <LS_SUM>-AMOUNT += LS_POTDATA-EFFWR.
    ENDLOOP.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_PR_AUTO_CLOSE->CONSTRUCTOR
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_SOURCE                      TYPE        CHAR4 (default ='BADI')
* | [--->] IV_TESTRUN                     TYPE        ABAP_BOOL (default =ABAP_FALSE)
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD CONSTRUCTOR.

    MV_SOURCE  = IV_SOURCE.
    MV_TESTRUN = IV_TESTRUN.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_PR_AUTO_CLOSE->EXECUTE_FOR_PO
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_HEADER                      TYPE REF TO IF_PURCHASE_ORDER_MM
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD EXECUTE_FOR_PO.

    CHECK IO_HEADER IS BOUND.

    DATA(LS_HEADER) = IO_HEADER->GET_DATA( ).
    MV_EBELN = LS_HEADER-EBELN.
    MV_WAERS = LS_HEADER-WAERS.
    MV_BSART = LS_HEADER-BSART.

*   1) this PO's effective value per PR item
    DATA(LT_SUM) = COLLECT_PO_VALUES( IO_HEADER ).
    CHECK LT_SUM IS NOT INITIAL.

*   2) plus whatever earlier POs already consumed
    ADD_POSTED_VALUES( CHANGING CT_SUM = LT_SUM ).

*   3) close the PR items that are fully consumed
    LOOP AT LT_SUM INTO DATA(LS_SUM).

      DATA(LV_EXPECTED) = GET_EXPECTED_VALUE( IV_BANFN = LS_SUM-BANFN
                                              IV_BNFPO = LS_SUM-BNFPO ).
      CHECK LV_EXPECTED > 0.
*      CHECK LS_SUM-AMOUNT >= LV_EXPECTED.
      WRITE_LOG( IS_SUM    = LS_SUM
                 IT_RETURN = CLOSE_PR_ITEM( LS_SUM ) ).
    ENDLOOP.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_PR_AUTO_CLOSE->GET_EXPECTED_VALUE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_BANFN                       TYPE        BANFN
* | [--->] IV_BNFPO                       TYPE        BNFPO
* | [<-()] RV_VALUE                       TYPE        BAPICURR_D
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD GET_EXPECTED_VALUE.
    SELECT SINGLE EXPECTED_VALUE, PREIS, BSART
      FROM EBAN
      WHERE BANFN = @IV_BANFN
        AND BNFPO = @IV_BNFPO
        AND LOEKZ = @SPACE
        AND EBAKZ = @SPACE
      INTO @DATA(LS_EBAN).
    CHECK SY-SUBRC = 0.

    RV_VALUE = LS_EBAN-EXPECTED_VALUE.
*   PR Z306/Z307: the valuation price is the PR value
    IF RV_VALUE IS INITIAL
    AND ZCL_PO_PR_PREIS_CHECK=>IS_PR_TYPE( LS_EBAN-BSART ) = ABAP_TRUE.
      RV_VALUE = LS_EBAN-PREIS.
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_PR_AUTO_CLOSE->WRITE_LOG
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_SUM                         TYPE        TY_SUM
* | [--->] IT_RETURN                      TYPE        BAPIRET2_T
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD WRITE_LOG.
    DATA LV_GUID TYPE GUID_16.
    TRY.
        LV_GUID = CL_SYSTEM_UUID=>CREATE_UUID_X16_STATIC( ).
      CATCH CX_UUID_ERROR.
        CLEAR LV_GUID.
    ENDTRY.
    DATA(LS_MSG) = VALUE BAPIRET2( IT_RETURN[ TYPE = 'E' ] OPTIONAL ).
    IF LS_MSG IS INITIAL.
      LS_MSG = VALUE #( IT_RETURN[ TYPE = 'A' ] OPTIONAL ).
    ENDIF.
    IF LS_MSG IS INITIAL.
      LS_MSG = VALUE #( IT_RETURN[ ID = '06' NUMBER = 403 TYPE = 'S' ] OPTIONAL ).
    ENDIF.
    DATA(LS_LOG) = VALUE ZPR_CLOSE_LOG(
      MANDT    = SY-MANDT
      GUID     = LV_GUID
      LOG_DATE = SY-DATUM
      LOG_TIME = SY-UZEIT
      SOURCE   = MV_SOURCE
      BANFN    = IS_SUM-BANFN
      BNFPO    = IS_SUM-BNFPO
      EBELN    = MV_EBELN
      EBELP    = IS_SUM-EBELP
      TESTRUN  = MV_TESTRUN
      ERNAM    = SY-UNAME
      PROG     = SY-CPROG
      STATUS   = COND #( WHEN LS_MSG IS NOT INITIAL THEN LS_MSG-TYPE   ELSE 'S' )
      MSGID    = COND #( WHEN LS_MSG IS NOT INITIAL THEN LS_MSG-ID     ELSE SPACE )
      MSGNO    = COND #( WHEN LS_MSG IS NOT INITIAL THEN LS_MSG-NUMBER ELSE '000' )
      MESSAGE  = COND #( WHEN LS_MSG IS NOT INITIAL THEN LS_MSG-MESSAGE
                         ELSE 'PR item closed successfully' ) ).
    INSERT ZPR_CLOSE_LOG FROM @LS_LOG.
  ENDMETHOD.
ENDCLASS.
