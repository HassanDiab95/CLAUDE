*&---------------------------------------------------------------------*
*& Object Name    : ZCL_SD_SO_RELEASE
*& Object Type    : Class
*& Package        : ZSD
*&---------------------------------------------------------------------*
*& Purpose        : Release cycle of production sales orders.
*&                   1. YSDA / YSDAX costing approval
*&                   2. credit workflow WS99000010 (only if credit block)
*&                   3. production release CN -> CP
*&                   Owns ZSD_SO_REL_H / _I / _LOG. Nobody else writes
*&                   them and nobody else changes CN to CP.
*&---------------------------------------------------------------------*
*& Status         : DRAFT - not compiled / not tested in SAP
*&---------------------------------------------------------------------*
CLASS ZCL_SD_SO_RELEASE DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS: BEGIN OF GC_COST,
                 PENDING  TYPE ZSD_REL_COST VALUE 'P',
                 APPROVED TYPE ZSD_REL_COST VALUE 'A',
                 REJECTED TYPE ZSD_REL_COST VALUE 'R',
               END OF GC_COST.

    CONSTANTS: BEGIN OF GC_CREDIT,
                 OPEN        TYPE ZSD_REL_CREDIT VALUE ' ',
                 NOT_NEEDED  TYPE ZSD_REL_CREDIT VALUE 'N',
                 WAITING     TYPE ZSD_REL_CREDIT VALUE 'W',
                 IN_APPROVAL TYPE ZSD_REL_CREDIT VALUE 'I',
                 APPROVED    TYPE ZSD_REL_CREDIT VALUE 'A',
                 REJECTED    TYPE ZSD_REL_CREDIT VALUE 'R',
               END OF GC_CREDIT.

    CONSTANTS: BEGIN OF GC_PROD,
                 BLOCKED  TYPE ZSD_REL_PROD VALUE 'B',
                 RELEASED TYPE ZSD_REL_PROD VALUE 'R',
                 ERROR    TYPE ZSD_REL_PROD VALUE 'E',
               END OF GC_PROD.

    CONSTANTS: BEGIN OF GC_OVERALL,
                 COSTING  TYPE ZSD_REL_OVERALL VALUE '1',
                 CREDIT   TYPE ZSD_REL_OVERALL VALUE '2',
                 RELEASED TYPE ZSD_REL_OVERALL VALUE '3',
                 REJECTED TYPE ZSD_REL_OVERALL VALUE '9',
                 DELETED  TYPE ZSD_REL_OVERALL VALUE 'D',
               END OF GC_OVERALL.

    "! Answer of CAN_START_CREDIT_WF
    CONSTANTS: BEGIN OF GC_START,
                 YES       TYPE CHAR1 VALUE 'Y',
                 NO        TYPE CHAR1 VALUE 'N',
                 UNMANAGED TYPE CHAR1 VALUE 'U',
               END OF GC_START.

    CONSTANTS GC_CN TYPE ETTYP VALUE 'CN'.
    CONSTANTS GC_CP TYPE ETTYP VALUE 'CP'.

    "! Order data as the user exit sees it at save time
    TYPES: BEGIN OF TY_S_ORDER,
             VBELN TYPE VBAK-VBELN,
             BUKRS TYPE VBAK-BUKRS_VF,
             VKORG TYPE VBAK-VKORG,
             AUART TYPE VBAK-AUART,
             KNKLI TYPE VBAK-KNKLI,
             KKBER TYPE VBAK-KKBER,
             WAERK TYPE VBAK-WAERK,
             NETWR TYPE VBAK-NETWR,
             ZTERM TYPE VBKD-ZTERM,
           END OF TY_S_ORDER.

    TYPES: BEGIN OF TY_S_ITEM,
             POSNR  TYPE VBAP-POSNR,
             KWMENG TYPE VBAP-KWMENG,
             NETWR  TYPE VBAP-NETWR,
             ABGRU  TYPE VBAP-ABGRU,
             UPDKZ  TYPE VBAPVB-UPDKZ,
           END OF TY_S_ITEM.
    TYPES TT_ITEM TYPE STANDARD TABLE OF TY_S_ITEM WITH EMPTY KEY.

    "--- sales order (MV45AFZZ) -----------------------------------------
    METHODS ON_ORDER_SAVED
      IMPORTING IS_ORDER  TYPE TY_S_ORDER
                IT_ITEMS  TYPE TT_ITEM
                IV_HAS_CN TYPE ABAP_BOOL.

    METHODS ON_ORDER_DELETED
      IMPORTING IV_VBELN TYPE VBELN_VA.

    METHODS IS_IN_CREDIT_APPROVAL
      IMPORTING IV_VBELN         TYPE VBELN_VA
      RETURNING VALUE(RV_ACTIVE) TYPE ABAP_BOOL.

    METHODS IS_PRODUCTION_RELEASE_ALLOWED
      IMPORTING IV_VBELN          TYPE VBELN_VA
      RETURNING VALUE(RV_ALLOWED) TYPE ABAP_BOOL.

    "--- YSDA / YSDAX ---------------------------------------------------
    "! Call after every approve / reject. Commits.
    METHODS ON_COSTING_DECISION
      IMPORTING IV_VBELN TYPE VBELN_VA.

    "--- credit workflow ------------------------------------------------
    METHODS CAN_START_CREDIT_WF
      IMPORTING IV_VBELN        TYPE VBELN_VA
      RETURNING VALUE(RV_START) TYPE CHAR1.

    "! First step of WS99000010. RV_DUPLICATE = true -> end this workflow
    METHODS ON_CREDIT_STARTED
      IMPORTING IV_VBELN            TYPE VBELN_VA
                IV_WI_ID            TYPE SWW_WIID
      RETURNING VALUE(RV_DUPLICATE) TYPE ABAP_BOOL.

    METHODS ON_CREDIT_APPROVED
      IMPORTING IV_VBELN           TYPE VBELN_VA
      RETURNING VALUE(RV_RELEASED) TYPE ABAP_BOOL.

    METHODS ON_CREDIT_REJECTED
      IMPORTING IV_VBELN TYPE VBELN_VA
                IV_NOTE  TYPE CSEQUENCE OPTIONAL.

    "--- production release / job ---------------------------------------
    METHODS RELEASE_PRODUCTION
      IMPORTING IV_VBELN           TYPE VBELN_VA
      EXPORTING ET_RETURN          TYPE BAPIRET2_T
      RETURNING VALUE(RV_RELEASED) TYPE ABAP_BOOL.

    METHODS RECONCILE
      IMPORTING IV_VBELN       TYPE VBELN_VA
      RETURNING VALUE(RV_NOTE) TYPE STRING.

    "! Public for ABAP Unit
    METHODS IS_CREDIT_RELEVANT_CHANGE
      IMPORTING IS_ORDER           TYPE TY_S_ORDER
                IT_ITEMS           TYPE TT_ITEM
      EXPORTING EV_REASON          TYPE STRING
      RETURNING VALUE(RV_RELEVANT) TYPE ABAP_BOOL.

  PRIVATE SECTION.

    TYPES TT_REL_I TYPE ZSD_SO_REL_I_TT.   " DDIC table type, same as the update FM

    "! headers changed in this LUW but not yet committed
    DATA MT_BUFFER TYPE SORTED TABLE OF ZSD_SO_REL_H WITH UNIQUE KEY VBELN.

    METHODS READ_HEADER
      IMPORTING IV_VBELN      TYPE VBELN_VA
      RETURNING VALUE(RS_HDR) TYPE ZSD_SO_REL_H.

    METHODS SAVE
      IMPORTING IS_HDR           TYPE ZSD_SO_REL_H
                IV_EVENT         TYPE CSEQUENCE
                IV_NOTE          TYPE CSEQUENCE OPTIONAL
                IT_ITEMS         TYPE TT_REL_I  OPTIONAL
                IV_REPLACE_ITEMS TYPE ABAP_BOOL DEFAULT ABAP_FALSE.

    METHODS SET_OVERALL
      CHANGING CS_HDR TYPE ZSD_SO_REL_H.

    METHODS IS_CONFIGURED
      IMPORTING IV_BUKRS         TYPE BUKRS
                IV_AUART         TYPE AUART
      RETURNING VALUE(RV_ACTIVE) TYPE ABAP_BOOL.

    METHODS READ_CONFIG
      IMPORTING IV_BUKRS      TYPE BUKRS
                IV_AUART      TYPE AUART
      RETURNING VALUE(RS_CFG) TYPE ZSD_SO_REL_CFG.

    METHODS COSTING_STATUS
      IMPORTING IV_VBELN         TYPE VBELN_VA
      RETURNING VALUE(RV_STATUS) TYPE ZSD_REL_COST.

    METHODS TAKE_SNAPSHOT
      CHANGING CS_HDR          TYPE ZSD_SO_REL_H
      RETURNING VALUE(RT_ITEMS) TYPE TT_REL_I.

    METHODS IS_WORKITEM_ACTIVE
      IMPORTING IV_WI_ID         TYPE SWW_WIID
      RETURNING VALUE(RV_ACTIVE) TYPE ABAP_BOOL.

    METHODS RAISE_START_EVENT
      IMPORTING IV_VBELN TYPE VBELN_VA.

ENDCLASS.



CLASS ZCL_SD_SO_RELEASE IMPLEMENTATION.


*======================================================================*
* Sales order
*======================================================================*
  METHOD ON_ORDER_SAVED.

    CHECK IS_ORDER-VBELN IS NOT INITIAL.

    DATA(LS_HDR) = READ_HEADER( IS_ORDER-VBELN ).

    "--- first save of a production order: start the cycle ------------
    IF LS_HDR IS INITIAL.

      CHECK IV_HAS_CN = ABAP_TRUE
        AND IS_CONFIGURED( IV_BUKRS = IS_ORDER-BUKRS
                           IV_AUART = IS_ORDER-AUART ) = ABAP_TRUE.

      LS_HDR = VALUE #( VBELN         = IS_ORDER-VBELN
                        BUKRS         = IS_ORDER-BUKRS
                        VKORG         = IS_ORDER-VKORG
                        AUART         = IS_ORDER-AUART
                        COST_STATUS   = GC_COST-PENDING
                        CREDIT_STATUS = GC_CREDIT-OPEN
                        PROD_STATUS   = GC_PROD-BLOCKED
                        CREATED_BY    = SY-UNAME
                        CREATED_ON    = SY-DATUM
                        CREATED_AT    = SY-UZEIT ).

      SAVE( IS_HDR   = LS_HDR
            IV_EVENT = 'CREATE'
            IV_NOTE  = |Production order saved in { SY-TCODE }, waiting for YSDA/YSDAX| ).
      RETURN.

    ENDIF.

    CHECK LS_HDR-OVERALL_STATUS <> GC_OVERALL-DELETED.

    DATA LV_NOTE   TYPE STRING.
    DATA LV_EVENT  TYPE STRING.
    DATA LV_SAVE   TYPE ABAP_BOOL.

    "--- new open item: YSDA / YSDAX must approve it first --------------
    IF LINE_EXISTS( IT_ITEMS[ UPDKZ = 'I' ABGRU = SPACE ] )
       AND LS_HDR-COST_STATUS <> GC_COST-PENDING.
      LS_HDR-COST_STATUS = GC_COST-PENDING.
      LS_HDR-PROD_STATUS = GC_PROD-BLOCKED.
      LV_EVENT = 'COST'.
      LV_NOTE  = |New item added in { SY-TCODE }, waiting for YSDA/YSDAX|.
      LV_SAVE  = ABAP_TRUE.
    ENDIF.

    "--- workflow running: restart only on a credit relevant change ----
    IF LS_HDR-CREDIT_STATUS = GC_CREDIT-IN_APPROVAL.

      DATA LV_REASON TYPE STRING.

      IF IS_CREDIT_RELEVANT_CHANGE( EXPORTING IS_ORDER  = IS_ORDER
                                              IT_ITEMS  = IT_ITEMS
                                    IMPORTING EV_REASON = LV_REASON ) = ABAP_TRUE.

        NEW ZCL_WF_SD_CREDIT( )->KILL_RUNNING_WORKFLOW(
          IV_VBELN  = IS_ORDER-VBELN
          IV_REASON = |Changed in { SY-TCODE } by { SY-UNAME }: { LV_REASON }| ).

        LS_HDR-CREDIT_STATUS = GC_CREDIT-OPEN.
        CLEAR LS_HDR-WI_ID.
        LV_EVENT = 'RESTART'.
        LV_NOTE  = LV_REASON.

      ELSE.

        LV_EVENT = 'NO_RESTART'.
        LV_NOTE  = |Change in { SY-TCODE } not credit relevant, workflow continues|.

      ENDIF.

      LV_SAVE = ABAP_TRUE.

    ENDIF.

    CHECK LV_SAVE = ABAP_TRUE.

    SAVE( IS_HDR   = LS_HDR
          IV_EVENT = LV_EVENT
          IV_NOTE  = LV_NOTE ).

  ENDMETHOD.


  METHOD IS_CREDIT_RELEVANT_CHANGE.

    CLEAR EV_REASON.

    DATA(LS_HDR) = READ_HEADER( IS_ORDER-VBELN ).

    " no snapshot = nothing approved yet = nothing to compare
    CHECK LS_HDR-SNAP_ON IS NOT INITIAL.

    DATA(LS_CFG) = READ_CONFIG( IV_BUKRS = LS_HDR-BUKRS
                                IV_AUART = LS_HDR-AUART ).

    "--- header data the credit decision is based on -------------------
    IF IS_ORDER-KNKLI <> LS_HDR-SNAP_KNKLI.
      EV_REASON = |Credit account changed { LS_HDR-SNAP_KNKLI ALPHA = OUT } -> { IS_ORDER-KNKLI ALPHA = OUT }|.
    ELSEIF IS_ORDER-KKBER <> LS_HDR-SNAP_KKBER.
      EV_REASON = |Credit control area changed { LS_HDR-SNAP_KKBER } -> { IS_ORDER-KKBER }|.
    ELSEIF IS_ORDER-WAERK <> LS_HDR-SNAP_WAERK.
      EV_REASON = |Currency changed { LS_HDR-SNAP_WAERK } -> { IS_ORDER-WAERK }|.
    ELSEIF IS_ORDER-ZTERM <> LS_HDR-SNAP_ZTERM.
      EV_REASON = |Payment terms changed { LS_HDR-SNAP_ZTERM } -> { IS_ORDER-ZTERM }|.
    ENDIF.

    IF EV_REASON IS NOT INITIAL.
      RV_RELEVANT = ABAP_TRUE.
      RETURN.
    ENDIF.

    "--- order value ----------------------------------------------------
    DATA(LV_LIMIT) = LS_HDR-SNAP_NETWR + LS_HDR-SNAP_NETWR * LS_CFG-TOL_PCT / 100.

    IF IS_ORDER-NETWR > LV_LIMIT
    OR ( LS_CFG-ANY_CHANGE = ABAP_TRUE AND IS_ORDER-NETWR <> LS_HDR-SNAP_NETWR ).
      EV_REASON = |Net value { IS_ORDER-NETWR } { IS_ORDER-WAERK }, | &&
                  |approved { LS_HDR-SNAP_NETWR } { LS_HDR-SNAP_WAERK }|.
      RV_RELEVANT = ABAP_TRUE.
      RETURN.
    ENDIF.

    "--- items ------------------------------------------------------------
    SELECT * FROM ZSD_SO_REL_I
      WHERE VBELN = @IS_ORDER-VBELN
      INTO TABLE @DATA(LT_SNAP).

    LOOP AT IT_ITEMS INTO DATA(LS_ITEM)
         WHERE UPDKZ <> 'D'
           AND ABGRU = SPACE.

      READ TABLE LT_SNAP INTO DATA(LS_SNAP) WITH KEY POSNR = LS_ITEM-POSNR.

      IF SY-SUBRC <> 0.
        EV_REASON = |Item { LS_ITEM-POSNR ALPHA = OUT } added|.
      ELSEIF LS_SNAP-ABGRU IS NOT INITIAL.
        EV_REASON = |Item { LS_ITEM-POSNR ALPHA = OUT } rejection removed|.
      ELSEIF LS_ITEM-KWMENG > LS_SNAP-KWMENG
          OR ( LS_CFG-ANY_CHANGE = ABAP_TRUE AND LS_ITEM-KWMENG <> LS_SNAP-KWMENG ).
        EV_REASON = |Item { LS_ITEM-POSNR ALPHA = OUT } quantity { LS_ITEM-KWMENG }, | &&
                    |approved { LS_SNAP-KWMENG }|.
      ENDIF.

      IF EV_REASON IS NOT INITIAL.
        RV_RELEVANT = ABAP_TRUE.
        RETURN.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD ON_ORDER_DELETED.

    DATA(LS_HDR) = READ_HEADER( IV_VBELN ).
    CHECK LS_HDR IS NOT INITIAL.

    IF LS_HDR-CREDIT_STATUS = GC_CREDIT-IN_APPROVAL.
      NEW ZCL_WF_SD_CREDIT( )->KILL_RUNNING_WORKFLOW(
        IV_VBELN  = IV_VBELN
        IV_REASON = |Sales order deleted in { SY-TCODE } by { SY-UNAME }| ).
    ENDIF.

    LS_HDR-OVERALL_STATUS = GC_OVERALL-DELETED.

    SAVE( IS_HDR   = LS_HDR
          IV_EVENT = 'DELETE'
          IV_NOTE  = |Sales order deleted in { SY-TCODE }| ).

  ENDMETHOD.


  METHOD IS_IN_CREDIT_APPROVAL.

    RV_ACTIVE = XSDBOOL( READ_HEADER( IV_VBELN )-CREDIT_STATUS = GC_CREDIT-IN_APPROVAL ).

  ENDMETHOD.


  METHOD IS_PRODUCTION_RELEASE_ALLOWED.

    DATA(LS_HDR) = READ_HEADER( IV_VBELN ).

    " not managed by this cycle: old rules apply
    IF LS_HDR IS INITIAL.
      RV_ALLOWED = ABAP_TRUE.
      RETURN.
    ENDIF.

    RV_ALLOWED = XSDBOOL( LS_HDR-COST_STATUS = GC_COST-APPROVED
                          AND ( LS_HDR-CREDIT_STATUS = GC_CREDIT-APPROVED
                             OR LS_HDR-CREDIT_STATUS = GC_CREDIT-NOT_NEEDED ) ).

  ENDMETHOD.


*======================================================================*
* YSDA / YSDAX
*======================================================================*
  METHOD ON_COSTING_DECISION.

    DATA(LS_HDR) = READ_HEADER( IV_VBELN ).
    CHECK LS_HDR IS NOT INITIAL
      AND LS_HDR-OVERALL_STATUS <> GC_OVERALL-DELETED.

    DATA(LV_COST) = COSTING_STATUS( IV_VBELN ).

    " YSDA calls this per selected row: act only when something changed
    IF LV_COST = LS_HDR-COST_STATUS
       AND ( LV_COST <> GC_COST-APPROVED
          OR LS_HDR-CREDIT_STATUS <> GC_CREDIT-OPEN ).
      RETURN.
    ENDIF.

    LS_HDR-COST_STATUS = LV_COST.

    CASE LV_COST.

      WHEN GC_COST-PENDING.
        SAVE( IS_HDR = LS_HDR IV_EVENT = 'COST' IV_NOTE = |Costing approval in progress| ).
        COMMIT WORK.

      WHEN GC_COST-REJECTED.
        SAVE( IS_HDR = LS_HDR IV_EVENT = 'COST' IV_NOTE = |All items rejected in YSDA/YSDAX| ).
        COMMIT WORK.

      WHEN GC_COST-APPROVED.

        LS_HDR-COST_DONE_ON = SY-DATUM.

        IF NEW ZCL_WF_SD_CREDIT( )->CHECK_SO_BLOCK( IV_VBELN ) = 'X'.

          " credit limit / overdue: CN stays, the workflow decides
          LS_HDR-CREDIT_STATUS = GC_CREDIT-WAITING.
          SAVE( IS_HDR   = LS_HDR
                IV_EVENT = 'CREDIT_WT'
                IV_NOTE  = |Costing approved, credit block - starting credit workflow| ).

          " status must be on the DB before the event is checked
          COMMIT WORK AND WAIT.
          RAISE_START_EVENT( IV_VBELN ).

        ELSE.

          LS_HDR-CREDIT_STATUS = GC_CREDIT-NOT_NEEDED.
          SAVE( IS_HDR   = LS_HDR
                IV_EVENT = 'COST'
                IV_NOTE  = |Costing approved, no credit block| ).

          " commits
          RELEASE_PRODUCTION( IV_VBELN ).

        ENDIF.

    ENDCASE.

  ENDMETHOD.


  METHOD COSTING_STATUS.

    " open items with production block: not rejected, or Z8 (automatic
    " YSDA rejection that the FI approval removes again)
    SELECT DISTINCT E~POSNR
      FROM VBEP AS E
      INNER JOIN VBAP AS P ON P~VBELN = E~VBELN
                          AND P~POSNR = E~POSNR
      WHERE E~VBELN = @IV_VBELN
        AND E~ETTYP = @GC_CN
        AND ( P~ABGRU = @SPACE OR P~ABGRU = 'Z8' )
      INTO TABLE @DATA(LT_OPEN).

    LOOP AT LT_OPEN INTO DATA(LV_POSNR).

      " no row yet = never opened in YSDA / YSDAX = pending
      SELECT SINGLE @ABAP_TRUE
        FROM ZSOAPPROVAL
        WHERE VBELN      = @IV_VBELN
          AND POSNR      = @LV_POSNR
          AND SD_APPROVE = 'X'
          AND FI_APPROVE = 'X'
        INTO @DATA(LV_DONE).

      IF SY-SUBRC <> 0.
        RV_STATUS = GC_COST-PENDING.
        RETURN.
      ENDIF.

    ENDLOOP.

    " nothing open: approved if at least one item is still alive
    SELECT SINGLE @ABAP_TRUE
      FROM VBAP
      WHERE VBELN = @IV_VBELN
        AND ABGRU = @SPACE
      INTO @DATA(LV_ALIVE).

    RV_STATUS = COND #( WHEN SY-SUBRC = 0 OR LT_OPEN IS NOT INITIAL
                        THEN GC_COST-APPROVED
                        ELSE GC_COST-REJECTED ).

  ENDMETHOD.


*======================================================================*
* Credit workflow
*======================================================================*
  METHOD CAN_START_CREDIT_WF.

    DATA(LS_HDR) = READ_HEADER( IV_VBELN ).

    IF LS_HDR IS INITIAL.
      RV_START = GC_START-UNMANAGED.
      RETURN.
    ENDIF.

    RV_START = COND #(
      WHEN LS_HDR-OVERALL_STATUS = GC_OVERALL-DELETED      THEN GC_START-NO
      WHEN LS_HDR-COST_STATUS   <> GC_COST-APPROVED        THEN GC_START-NO
      WHEN LS_HDR-CREDIT_STATUS  = GC_CREDIT-IN_APPROVAL   THEN GC_START-NO
      ELSE                                                      GC_START-YES ).

  ENDMETHOD.


  METHOD ON_CREDIT_STARTED.

    CALL FUNCTION 'ENQUEUE_EZSD_SO_REL'
      EXPORTING
        VBELN          = IV_VBELN
        _WAIT          = ABAP_TRUE
      EXCEPTIONS
        FOREIGN_LOCK   = 1
        SYSTEM_FAILURE = 2
        OTHERS         = 3.

    DATA(LS_HDR) = READ_HEADER( IV_VBELN ).

    " not managed: nothing to record
    CHECK LS_HDR IS NOT INITIAL.

    " another workflow already runs for this order -> this one ends
    IF LS_HDR-CREDIT_STATUS = GC_CREDIT-IN_APPROVAL
       AND LS_HDR-WI_ID IS NOT INITIAL
       AND LS_HDR-WI_ID <> IV_WI_ID
       AND IS_WORKITEM_ACTIVE( LS_HDR-WI_ID ) = ABAP_TRUE.
      RV_DUPLICATE = ABAP_TRUE.
      RETURN.
    ENDIF.

    LS_HDR-CREDIT_STATUS = GC_CREDIT-IN_APPROVAL.
    LS_HDR-WI_ID         = IV_WI_ID.
    LS_HDR-CREDIT_CYCLE  = LS_HDR-CREDIT_CYCLE + 1.

    DATA(LT_ITEMS) = TAKE_SNAPSHOT( CHANGING CS_HDR = LS_HDR ).

    SAVE( IS_HDR           = LS_HDR
          IV_EVENT         = 'CREDIT_ST'
          IV_NOTE          = |Credit workflow { IV_WI_ID ALPHA = OUT } started, | &&
                             |cycle { LS_HDR-CREDIT_CYCLE }, approved value | &&
                             |{ LS_HDR-SNAP_NETWR } { LS_HDR-SNAP_WAERK }|
          IT_ITEMS         = LT_ITEMS
          IV_REPLACE_ITEMS = ABAP_TRUE ).

    " the workflow runtime commits after the step; lock is released then

  ENDMETHOD.


  METHOD ON_CREDIT_APPROVED.

    DATA(LS_HDR) = READ_HEADER( IV_VBELN ).
    CHECK LS_HDR IS NOT INITIAL.

    LS_HDR-CREDIT_STATUS  = GC_CREDIT-APPROVED.
    LS_HDR-CREDIT_DONE_ON = SY-DATUM.

    SAVE( IS_HDR   = LS_HDR
          IV_EVENT = 'CREDIT_OK'
          IV_NOTE  = |Credit workflow final approval| ).

    " commits
    RV_RELEASED = RELEASE_PRODUCTION( IV_VBELN ).

  ENDMETHOD.


  METHOD ON_CREDIT_REJECTED.

    DATA(LS_HDR) = READ_HEADER( IV_VBELN ).
    CHECK LS_HDR IS NOT INITIAL.

    LS_HDR-CREDIT_STATUS  = GC_CREDIT-REJECTED.
    LS_HDR-CREDIT_DONE_ON = SY-DATUM.

    SAVE( IS_HDR   = LS_HDR
          IV_EVENT = 'CREDIT_NOK'
          IV_NOTE  = COND #( WHEN IV_NOTE IS NOT INITIAL THEN IV_NOTE
                             ELSE |Credit workflow rejected - production stays blocked| ) ).

  ENDMETHOD.


  METHOD TAKE_SNAPSHOT.

    SELECT SINGLE NETWR, WAERK, KNKLI, KKBER
      FROM VBAK
      WHERE VBELN = @CS_HDR-VBELN
      INTO ( @CS_HDR-SNAP_NETWR, @CS_HDR-SNAP_WAERK,
             @CS_HDR-SNAP_KNKLI, @CS_HDR-SNAP_KKBER ).

    SELECT SINGLE ZTERM
      FROM VBKD
      WHERE VBELN = @CS_HDR-VBELN
        AND POSNR = '000000'
      INTO @CS_HDR-SNAP_ZTERM.

    CS_HDR-SNAP_ON = SY-DATUM.
    CS_HDR-SNAP_AT = SY-UZEIT.

    SELECT VBELN, POSNR, KWMENG, VRKME, NETWR, ABGRU
      FROM VBAP
      WHERE VBELN = @CS_HDR-VBELN
      INTO CORRESPONDING FIELDS OF TABLE @RT_ITEMS.

  ENDMETHOD.


  METHOD IS_WORKITEM_ACTIVE.

    SELECT SINGLE WI_STAT
      FROM SWWWIHEAD
      WHERE WI_ID = @IV_WI_ID
      INTO @DATA(LV_STAT).

    RV_ACTIVE = XSDBOOL( SY-SUBRC = 0
                         AND LV_STAT <> 'COMPLETED'
                         AND LV_STAT <> 'CANCELLED' ).

  ENDMETHOD.


  METHOD RAISE_START_EVENT.

    DATA LV_RC TYPE SY-SUBRC.

    CALL FUNCTION 'SAP_WAPI_CREATE_EVENT'
      EXPORTING
        OBJECT_TYPE = CONV SWR_STRUCT-OBJECT_TYP( 'BUS2032' )
        OBJECT_KEY  = CONV SWR_STRUCT-OBJECT_KEY( IV_VBELN )
        EVENT       = CONV SWR_STRUCT-EVENT( 'CHANGED' )
        COMMIT_WORK = ABAP_TRUE
      IMPORTING
        RETURN_CODE = LV_RC.

  ENDMETHOD.


*======================================================================*
* Production release
*======================================================================*
  METHOD RELEASE_PRODUCTION.

    DATA LT_SCHDL  TYPE STANDARD TABLE OF BAPISCHDL.
    DATA LT_SCHDLX TYPE STANDARD TABLE OF BAPISCHDLX.
    DATA LT_RETURN TYPE STANDARD TABLE OF BAPIRET2.

    CLEAR ET_RETURN.

    DATA(LS_HDR) = READ_HEADER( IV_VBELN ).

    " both approvals are required, whoever calls this
    CHECK IS_PRODUCTION_RELEASE_ALLOWED( IV_VBELN ) = ABAP_TRUE.

    SELECT E~POSNR, E~ETENR
      FROM VBEP AS E
      INNER JOIN ZSOAPPROVAL AS Z ON Z~VBELN = E~VBELN
                                 AND Z~POSNR = E~POSNR
      WHERE E~VBELN      = @IV_VBELN
        AND E~ETTYP      = @GC_CN
        AND E~WMENG      > 0
        AND Z~SD_APPROVE = 'X'
        AND Z~FI_APPROVE = 'X'
      INTO TABLE @DATA(LT_SL).

    SORT LT_SL BY POSNR ETENR.
    DELETE ADJACENT DUPLICATES FROM LT_SL COMPARING POSNR ETENR.

    " nothing on CN any more = already released
    IF LT_SL IS INITIAL.
      IF LS_HDR IS NOT INITIAL AND LS_HDR-PROD_STATUS <> GC_PROD-RELEASED.
        LS_HDR-PROD_STATUS = GC_PROD-RELEASED.
        SAVE( IS_HDR = LS_HDR IV_EVENT = 'PROD_REL' IV_NOTE = |No CN schedule line left| ).
        COMMIT WORK.
      ENDIF.
      RV_RELEASED = ABAP_TRUE.
      RETURN.
    ENDIF.

    LOOP AT LT_SL INTO DATA(LS_SL).
      APPEND VALUE #( ITM_NUMBER = LS_SL-POSNR
                      SCHED_LINE = LS_SL-ETENR
                      SCHED_TYPE = GC_CP ) TO LT_SCHDL.
      APPEND VALUE #( ITM_NUMBER = LS_SL-POSNR
                      SCHED_LINE = LS_SL-ETENR
                      UPDATEFLAG = 'U'
                      SCHED_TYPE = 'X' ) TO LT_SCHDLX.
    ENDLOOP.

    CALL FUNCTION 'BAPI_SALESORDER_CHANGE'  "#EC CI_USAGE_OK[2438131]
      EXPORTING
        SALESDOCUMENT    = IV_VBELN
        ORDER_HEADER_INX = VALUE BAPISDH1X( UPDATEFLAG = 'U' )
      TABLES
        RETURN           = LT_RETURN
        SCHEDULE_LINES   = LT_SCHDL
        SCHEDULE_LINESX  = LT_SCHDLX.

    ET_RETURN = LT_RETURN.

    IF LINE_EXISTS( LT_RETURN[ TYPE = 'E' ] )
    OR LINE_EXISTS( LT_RETURN[ TYPE = 'A' ] ).

      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.

      CHECK LS_HDR IS NOT INITIAL.
      LS_HDR-PROD_STATUS = GC_PROD-ERROR.
      DATA(LS_ERR) = VALUE #( LT_RETURN[ TYPE = 'E' ] OPTIONAL ).
      SAVE( IS_HDR   = LS_HDR
            IV_EVENT = 'PROD_ERR'
            IV_NOTE  = |CN->CP failed, job retries: { LS_ERR-MESSAGE }| ).
      COMMIT WORK.
      RETURN.

    ENDIF.

    IF LS_HDR IS NOT INITIAL.
      LS_HDR-PROD_STATUS = GC_PROD-RELEASED.
      LS_HDR-PROD_REL_ON = SY-DATUM.
      LS_HDR-PROD_REL_BY = SY-UNAME.
      SAVE( IS_HDR   = LS_HDR
            IV_EVENT = 'PROD_REL'
            IV_NOTE  = |{ LINES( LT_SCHDL ) } schedule line(s) CN -> CP| ).
    ENDIF.

    " one commit for the order change and the release table
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        WAIT = ABAP_TRUE.

    RV_RELEASED = ABAP_TRUE.

  ENDMETHOD.


  METHOD RECONCILE.

    DATA(LS_HDR) = READ_HEADER( IV_VBELN ).
    CHECK LS_HDR IS NOT INITIAL
      AND LS_HDR-OVERALL_STATUS <> GC_OVERALL-DELETED.

    "--- both approved but production still blocked ---------------------
    IF IS_PRODUCTION_RELEASE_ALLOWED( IV_VBELN ) = ABAP_TRUE
       AND LS_HDR-PROD_STATUS <> GC_PROD-RELEASED.
      RV_NOTE = COND #( WHEN RELEASE_PRODUCTION( IV_VBELN ) = ABAP_TRUE
                        THEN `Production released`
                        ELSE `Production release failed - see log` ).
      RETURN.
    ENDIF.

    "--- costing done, credit not decided (start lost, or restarted and
    "    the new credit check passed) -------------------------------------
    IF LS_HDR-COST_STATUS = GC_COST-APPROVED
       AND ( LS_HDR-CREDIT_STATUS = GC_CREDIT-OPEN
          OR LS_HDR-CREDIT_STATUS = GC_CREDIT-WAITING ).

      IF NEW ZCL_WF_SD_CREDIT( )->CHECK_SO_BLOCK( IV_VBELN ) = 'X'.
        RAISE_START_EVENT( IV_VBELN ).
        RV_NOTE = `Credit block - start event raised again`.
      ELSE.
        LS_HDR-CREDIT_STATUS = GC_CREDIT-NOT_NEEDED.
        SAVE( IS_HDR   = LS_HDR
              IV_EVENT = 'RECONCILE'
              IV_NOTE  = |No credit block any more - credit approval not needed| ).
        RV_NOTE = COND #( WHEN RELEASE_PRODUCTION( IV_VBELN ) = ABAP_TRUE
                          THEN `No credit block - production released`
                          ELSE `No credit block - production release failed` ).
      ENDIF.
      RETURN.

    ENDIF.

    "--- in approval but the work item is gone (admin cancel, error) --
    IF LS_HDR-CREDIT_STATUS = GC_CREDIT-IN_APPROVAL
       AND IS_WORKITEM_ACTIVE( LS_HDR-WI_ID ) = ABAP_FALSE.
      RV_NOTE = |Work item { LS_HDR-WI_ID ALPHA = OUT } not active - check in SWIA|.
      RETURN.
    ENDIF.

  ENDMETHOD.


*======================================================================*
* Persistence
*======================================================================*
  METHOD READ_HEADER.

    " changes of this LUW first, then the DB
    RS_HDR = VALUE #( MT_BUFFER[ VBELN = IV_VBELN ] OPTIONAL ).
    CHECK RS_HDR IS INITIAL.

    SELECT SINGLE * FROM ZSD_SO_REL_H
      WHERE VBELN = @IV_VBELN
      INTO @RS_HDR.

  ENDMETHOD.


  METHOD SAVE.

    DATA(LS_HDR) = IS_HDR.

    SET_OVERALL( CHANGING CS_HDR = LS_HDR ).

    LS_HDR-CHANGED_BY = SY-UNAME.
    LS_HDR-CHANGED_ON = SY-DATUM.
    LS_HDR-CHANGED_AT = SY-UZEIT.

    DATA LV_TS TYPE TIMESTAMPL.
    GET TIME STAMP FIELD LV_TS.

    DATA(LS_LOG) = VALUE ZSD_SO_REL_LOG( VBELN          = LS_HDR-VBELN
                                         LOG_TS         = LV_TS
                                         EVENT          = IV_EVENT
                                         COST_STATUS    = LS_HDR-COST_STATUS
                                         CREDIT_STATUS  = LS_HDR-CREDIT_STATUS
                                         PROD_STATUS    = LS_HDR-PROD_STATUS
                                         OVERALL_STATUS = LS_HDR-OVERALL_STATUS
                                         NOTE           = IV_NOTE
                                         UNAME          = SY-UNAME
                                         TCODE          = SY-TCODE ).

    " written with the caller's commit (order save, YSDA, workflow, job)
    CALL FUNCTION 'Z_SD_SO_REL_UPDATE' IN UPDATE TASK
      EXPORTING
        IS_HEADER        = LS_HDR
        IT_ITEMS         = IT_ITEMS
        IV_REPLACE_ITEMS = IV_REPLACE_ITEMS
        IS_LOG           = LS_LOG.

    MODIFY TABLE MT_BUFFER FROM LS_HDR.
    IF SY-SUBRC <> 0.
      INSERT LS_HDR INTO TABLE MT_BUFFER.
    ENDIF.

  ENDMETHOD.


  METHOD SET_OVERALL.

    CHECK CS_HDR-OVERALL_STATUS <> GC_OVERALL-DELETED.

    CS_HDR-OVERALL_STATUS = COND #(
      WHEN CS_HDR-COST_STATUS   = GC_COST-REJECTED
        OR CS_HDR-CREDIT_STATUS = GC_CREDIT-REJECTED THEN GC_OVERALL-REJECTED
      WHEN CS_HDR-PROD_STATUS   = GC_PROD-RELEASED   THEN GC_OVERALL-RELEASED
      WHEN CS_HDR-COST_STATUS   = GC_COST-PENDING    THEN GC_OVERALL-COSTING
      ELSE                                                GC_OVERALL-CREDIT ).

  ENDMETHOD.


  METHOD READ_CONFIG.

    SELECT SINGLE * FROM ZSD_SO_REL_CFG
      WHERE BUKRS = @IV_BUKRS
        AND AUART = @IV_AUART
      INTO @RS_CFG.

  ENDMETHOD.


  METHOD IS_CONFIGURED.

    RV_ACTIVE = READ_CONFIG( IV_BUKRS = IV_BUKRS
                             IV_AUART = IV_AUART )-ACTIVE.

  ENDMETHOD.
ENDCLASS.
