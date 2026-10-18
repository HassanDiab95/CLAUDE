*&---------------------------------------------------------------------*
*& Object Name    : ZCL_SD_SO_RELEASE
*& Object Type    : Class (SE24, package ZSD)
*&---------------------------------------------------------------------*
*& Purpose        : Release cycle of production sales orders, per item.
*&                   1. every production item is approved / rejected
*&                      in YSDA / YSDAX
*&                   2. if the order has a credit block (credit limit
*&                      and/or overdue) the credit workflow WS99000010
*&                      runs once all production items are decided
*&                   3. each approved item is released CN -> CP when
*&                      credit is approved or not needed
*&                   This class is the only code that writes
*&                   ZSD_SO_REL_H / _I / _LOG and the only code that
*&                   changes CN to CP for managed orders.
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
                 ERROR     TYPE ZSD_REL_PROD VALUE 'E',
                 KEPT      TYPE ZSD_REL_PROD VALUE 'K',   " rejected in YSDA/YSDAX, stays CN
                 CANCELLED TYPE ZSD_REL_PROD VALUE 'X',   " credit rejected, order cancelled
               END OF GC_PROD.

    CONSTANTS: BEGIN OF GC_OVERALL,
                 COSTING  TYPE ZSD_REL_OVERALL VALUE '1',
                 CREDIT   TYPE ZSD_REL_OVERALL VALUE '2',
                 RELEASED TYPE ZSD_REL_OVERALL VALUE '3',
                 REJECTED TYPE ZSD_REL_OVERALL VALUE '9',
                 DELETED  TYPE ZSD_REL_OVERALL VALUE 'D',
               END OF GC_OVERALL.

    " Answer of CAN_START_CREDIT_WF
    CONSTANTS: BEGIN OF GC_START,
                 YES       TYPE CHAR1 VALUE 'Y',
                 NO        TYPE CHAR1 VALUE 'N',
                 UNMANAGED TYPE CHAR1 VALUE 'U',
               END OF GC_START.

    CONSTANTS GC_CN          TYPE ETTYP      VALUE 'CN'.
    CONSTANTS GC_CP          TYPE ETTYP      VALUE 'CP'.
    CONSTANTS GC_REJ_AUTO    TYPE ABGRU_VA   VALUE 'Z8'.   " automatic YSDA rejection
    "! TVARVC parameter with the go-live date (only TVARVC entry)
    CONSTANTS GC_TVARVC_DATE TYPE RVARI_VNAM VALUE 'ZSD_SO_REL_START_DATE'.

    "--- Settings of the release cycle (constants, no customizing) ------
    "! Allowed growth of the order net value (in %) without restarting
    "! the credit workflow
    CONSTANTS GC_TOL_PCT     TYPE P LENGTH 5 DECIMALS 2 VALUE '0.00'.
    "! X = restart the credit workflow also when value / quantity goes down
    CONSTANTS GC_ANY_CHANGE  TYPE ABAP_BOOL VALUE ABAP_FALSE.
    CONSTANTS GC_ALL         TYPE CHAR1      VALUE '*'.    " ZSD_SO_REL_CFG: any value

    " Order data as the user exit sees it at save time
    TYPES: BEGIN OF TY_S_ORDER,
             VBELN TYPE VBAK-VBELN,
             BUKRS TYPE VBAK-BUKRS_VF,
             VKORG TYPE VBAK-VKORG,
             AUART TYPE VBAK-AUART,
             VBTYP TYPE VBAK-VBTYP,
             ERDAT TYPE VBAK-ERDAT,
             KNKLI TYPE VBAK-KNKLI,
             KKBER TYPE VBAK-KKBER,
             WAERK TYPE VBAK-WAERK,
             NETWR TYPE VBAK-NETWR,
             ZTERM TYPE VBKD-ZTERM,
           END OF TY_S_ORDER.

    TYPES: BEGIN OF TY_S_ITEM,
             POSNR  TYPE VBAP-POSNR,
             WERKS  TYPE VBAP-WERKS,
             PSTYV  TYPE VBAP-PSTYV,
             KWMENG TYPE VBAP-KWMENG,
             NETWR  TYPE VBAP-NETWR,
             ABGRU  TYPE VBAP-ABGRU,
             UPDKZ  TYPE VBAPVB-UPDKZ,
           END OF TY_S_ITEM.
    TYPES TT_ITEM  TYPE STANDARD TABLE OF TY_S_ITEM WITH EMPTY KEY.
    TYPES TT_POSNR TYPE STANDARD TABLE OF POSNR_VA WITH EMPTY KEY.

    " One order line with its YSDA/YSDAX decision and what happens to it
    " at the credit final approval (for the workflow mail / monitor)
    TYPES: BEGIN OF TY_S_PLAN,
             POSNR         TYPE VBAP-POSNR,
             MATNR         TYPE VBAP-MATNR,
             ARKTX         TYPE VBAP-ARKTX,
             KWMENG        TYPE VBAP-KWMENG,
             VRKME         TYPE VBAP-VRKME,
             DECISION      TYPE STRING,      " approved / rejected by ... on ...
             TARGET        TYPE STRING,      " CN -> CP / stays CN / ...
             TO_PRODUCTION TYPE ABAP_BOOL,
           END OF TY_S_PLAN.
    TYPES TT_PLAN TYPE STANDARD TABLE OF TY_S_PLAN WITH EMPTY KEY.

    "--- sales order: MV45AFZZ (no COMMIT, written with the order) ------
    "! USEREXIT_SAVE_DOCUMENT
    METHODS ON_ORDER_SAVED
      IMPORTING IS_ORDER    TYPE TY_S_ORDER
                IT_ITEMS    TYPE TT_ITEM
                IT_CN_POSNR TYPE TT_POSNR.

    "! USEREXIT_DELETE_DOCUMENT
    METHODS ON_ORDER_DELETED
      IMPORTING IV_VBELN TYPE VBELN_VA.

    METHODS IS_MANAGED
      IMPORTING IV_VBELN          TYPE VBELN_VA
      RETURNING VALUE(RV_MANAGED) TYPE ABAP_BOOL.

    METHODS IS_IN_CREDIT_APPROVAL
      IMPORTING IV_VBELN         TYPE VBELN_VA
      RETURNING VALUE(RV_ACTIVE) TYPE ABAP_BOOL.

    "! USEREXIT_MOVE_FIELD_TO_VBEP - may this item go from CN to CP?
    METHODS IS_ITEM_RELEASE_ALLOWED
      IMPORTING IV_VBELN          TYPE VBELN_VA
                IV_POSNR          TYPE POSNR_VA
      RETURNING VALUE(RV_ALLOWED) TYPE ABAP_BOOL.

    "--- YSDA / YSDAX (commits) ------------------------------------------
    "! Call after every approve / reject of an item.
    "! RV_MANAGED = false: order not in the cycle -> old YSDA logic.
    METHODS ON_ITEM_DECISION
      IMPORTING IV_VBELN          TYPE VBELN_VA
      RETURNING VALUE(RV_MANAGED) TYPE ABAP_BOOL.

    "! Text for the YSDA log / message, e.g. "waiting for credit approval"
    METHODS GET_ITEM_STATUS_TEXT
      IMPORTING IV_VBELN       TYPE VBELN_VA
                IV_POSNR       TYPE POSNR_VA
      RETURNING VALUE(RV_TEXT) TYPE STRING.

    "! Every production line: YSDA/YSDAX decision and planned result
    METHODS GET_RELEASE_PLAN
      IMPORTING IV_VBELN       TYPE VBELN_VA
      RETURNING VALUE(RT_PLAN) TYPE TT_PLAN.

    "--- credit workflow ---------------------------------------------------
    "! Check FM Z_FM_SD_WF_CHECK_CREDIT via ZCL_WF_SD_CREDIT->IS_START_ALLOWED
    METHODS CAN_START_CREDIT_WF
      IMPORTING IV_VBELN        TYPE VBELN_VA
      RETURNING VALUE(RV_START) TYPE CHAR1.

    "! First step of WS99000010. RV_DUPLICATE = true -> end this workflow
    METHODS ON_CREDIT_STARTED
      IMPORTING IV_VBELN            TYPE VBELN_VA
                IV_WI_ID            TYPE SWW_WIID
      RETURNING VALUE(RV_DUPLICATE) TYPE ABAP_BOOL.

    "! Final approval step. RV_RELEASED = false -> retry (order locked)
    METHODS ON_CREDIT_APPROVED
      IMPORTING IV_VBELN           TYPE VBELN_VA
      RETURNING VALUE(RV_RELEASED) TYPE ABAP_BOOL.

    "! Credit rejected - runs BEFORE the existing REJECT_STEP of WS99000010.
    "! Records every line as YSDA / YSDAX decided it; the existing step
    "! (TS99000044 "Cancel Sales Order Credit") then cancels the order.
    "! No change to the order here.
    METHODS ON_CREDIT_REJECTED
      IMPORTING IV_VBELN TYPE VBELN_VA
                IV_NOTE  TYPE CSEQUENCE OPTIONAL
                IV_ABGRU TYPE ABGRU_VA OPTIONAL.

    "--- engine / job ------------------------------------------------------
    "! Re-evaluates the whole order and releases every item that may go
    "! to production. Safe to call any number of times. Commits.
    METHODS PROCESS
      IMPORTING IV_VBELN       TYPE VBELN_VA
                IV_RETRY_START TYPE ABAP_BOOL DEFAULT ABAP_FALSE
      RETURNING VALUE(RV_NOTE) TYPE STRING.

    "! Public for ABAP Unit
    METHODS IS_CREDIT_RELEVANT_CHANGE
      IMPORTING IS_ORDER           TYPE TY_S_ORDER
                IT_ITEMS           TYPE TT_ITEM
                IV_ANY_CHANGE      TYPE ABAP_BOOL DEFAULT ABAP_FALSE
      EXPORTING EV_REASON          TYPE STRING
      RETURNING VALUE(RV_RELEVANT) TYPE ABAP_BOOL.

  PRIVATE SECTION.

    TYPES TT_REL_I TYPE SORTED TABLE OF ZSD_SO_REL_I WITH UNIQUE KEY POSNR.

    "! changes of this LUW that are not committed yet
    DATA MT_HDR_BUF TYPE SORTED TABLE OF ZSD_SO_REL_H WITH UNIQUE KEY VBELN.
    DATA MT_ITM_BUF TYPE SORTED TABLE OF ZSD_SO_REL_I WITH UNIQUE KEY VBELN POSNR.
    DATA MT_ITM_SET TYPE SORTED TABLE OF VBELN_VA WITH UNIQUE KEY TABLE_LINE.

    METHODS READ_HEADER
      IMPORTING IV_VBELN      TYPE VBELN_VA
      RETURNING VALUE(RS_HDR) TYPE ZSD_SO_REL_H.

    METHODS READ_ITEMS
      IMPORTING IV_VBELN        TYPE VBELN_VA
      RETURNING VALUE(RT_ITEMS) TYPE TT_REL_I.

    METHODS SAVE
      IMPORTING IS_HDR   TYPE ZSD_SO_REL_H
                IT_ITEMS TYPE TT_REL_I
                IV_EVENT TYPE CSEQUENCE
                IV_NOTE  TYPE CSEQUENCE OPTIONAL.

    METHODS SET_SUMMARY
      IMPORTING IT_ITEMS TYPE TT_REL_I
      CHANGING  CS_HDR   TYPE ZSD_SO_REL_H.

    METHODS REFRESH_ITEM_STATUS
      IMPORTING IV_VBELN TYPE VBELN_VA
      CHANGING  CT_ITEMS TYPE TT_REL_I.

    METHODS RELEASE_ITEMS
      IMPORTING IV_VBELN       TYPE VBELN_VA
      CHANGING  CS_HDR         TYPE ZSD_SO_REL_H
                CT_ITEMS       TYPE TT_REL_I
      RETURNING VALUE(RV_NOTE) TYPE STRING.

    METHODS TAKE_SNAPSHOT
      CHANGING CS_HDR   TYPE ZSD_SO_REL_H
               CT_ITEMS TYPE TT_REL_I.

    METHODS SET_RELEASE_PLAN
      CHANGING CT_ITEMS      TYPE TT_REL_I
      RETURNING VALUE(RV_NOTE) TYPE STRING.


    METHODS ITEM_LOG
      IMPORTING IS_OLD         TYPE ZSD_SO_REL_I
                IS_NEW         TYPE ZSD_SO_REL_I
      RETURNING VALUE(RV_NOTE) TYPE STRING.

    "! Go-live date reached and order category as in YSDA/YSDAX (C / I)
    METHODS IS_CONFIGURED
      IMPORTING IS_ORDER         TYPE TY_S_ORDER
      RETURNING VALUE(RV_ACTIVE) TYPE ABAP_BOOL.

    "! Would YSDA / YSDAX show this line? (plant + order type + item
    "! category as hard coded in the two programs, kept in ZSD_SO_REL_CFG)
    METHODS IS_ITEM_IN_SCOPE
      IMPORTING IV_WERKS           TYPE WERKS_D
                IV_AUART           TYPE AUART
                IV_PSTYV           TYPE PSTYV
      RETURNING VALUE(RV_IN_SCOPE) TYPE ABAP_BOOL.

    METHODS IS_WORKITEM_ACTIVE
      IMPORTING IV_WI_ID         TYPE SWW_WIID
      RETURNING VALUE(RV_ACTIVE) TYPE ABAP_BOOL.

    METHODS RAISE_START_EVENT
      IMPORTING IV_VBELN TYPE VBELN_VA.

ENDCLASS.



CLASS ZCL_SD_SO_RELEASE IMPLEMENTATION.


*======================================================================*
* Sales order (MV45AFZZ)
*======================================================================*
  METHOD ON_ORDER_SAVED.

    CHECK IS_ORDER-VBELN IS NOT INITIAL.

    DATA(LS_HDR) = READ_HEADER( IS_ORDER-VBELN ).

    "--- first save of a production order: the cycle starts -----------
    IF LS_HDR IS INITIAL.

      CHECK IT_CN_POSNR IS NOT INITIAL
        AND IS_CONFIGURED( IS_ORDER ) = ABAP_TRUE.

      LS_HDR = VALUE #( VBELN         = IS_ORDER-VBELN
                        BUKRS         = IS_ORDER-BUKRS
                        VKORG         = IS_ORDER-VKORG
                        AUART         = IS_ORDER-AUART
                        ERDAT         = IS_ORDER-ERDAT
                        CREDIT_STATUS = GC_CREDIT-OPEN
                        CREATED_BY    = SY-UNAME
                        CREATED_ON    = SY-DATUM
                        CREATED_AT    = SY-UZEIT ).

      DATA LT_NEW TYPE TT_REL_I.

      " production line = CN schedule line + shown in YSDA / YSDAX
      LOOP AT IT_ITEMS INTO DATA(LS_NEW) WHERE UPDKZ <> 'D'.
        DATA(LV_CN) = XSDBOOL( LINE_EXISTS( IT_CN_POSNR[ TABLE_LINE = LS_NEW-POSNR ] )
                           AND IS_ITEM_IN_SCOPE( IV_WERKS = LS_NEW-WERKS
                                                 IV_AUART = IS_ORDER-AUART
                                                 IV_PSTYV = LS_NEW-PSTYV ) = ABAP_TRUE ).
        INSERT VALUE #( VBELN         = IS_ORDER-VBELN
                        POSNR         = LS_NEW-POSNR
                        PROD_RELEVANT = LV_CN
                        COST_STATUS   = COND #( WHEN LV_CN = ABAP_TRUE THEN GC_COST-PENDING )
                        PROD_STATUS   = COND #( WHEN LV_CN = ABAP_TRUE THEN GC_PROD-BLOCKED )
                        CREATED_ON    = SY-DATUM ) INTO TABLE LT_NEW.
      ENDLOOP.

      " no line YSDA / YSDAX would show -> not a managed order
      CHECK LINE_EXISTS( LT_NEW[ PROD_RELEVANT = ABAP_TRUE ] ).

      SAVE( IS_HDR   = LS_HDR
            IT_ITEMS = LT_NEW
            IV_EVENT = 'CREATE'
            IV_NOTE  = |Saved in { SY-TCODE }: | &&
                       |{ REDUCE I( INIT N = 0 FOR LS_C IN LT_NEW WHERE ( PROD_RELEVANT = ABAP_TRUE ) NEXT N = N + 1 ) } | &&
                       |production item(s) | &&
                       |waiting for YSDA/YSDAX| ).
      RETURN.

    ENDIF.

    CHECK LS_HDR-OVERALL_STATUS <> GC_OVERALL-DELETED.

    DATA(LT_ITM) = READ_ITEMS( IS_ORDER-VBELN ).
    DATA LV_SAVE  TYPE ABAP_BOOL.
    DATA LV_EVENT TYPE STRING VALUE 'CHANGE'.
    DATA LV_NOTE  TYPE STRING.

    "--- items added / deleted ---------------------------------------------
    LOOP AT IT_ITEMS INTO DATA(LS_ITEM) WHERE UPDKZ = 'I' OR UPDKZ = 'D'.

      IF LS_ITEM-UPDKZ = 'D'.
        DELETE LT_ITM WHERE POSNR = LS_ITEM-POSNR.
        LV_SAVE = ABAP_TRUE.
        CONTINUE.
      ENDIF.

      CHECK NOT LINE_EXISTS( LT_ITM[ POSNR = LS_ITEM-POSNR ] ).

      LV_CN = XSDBOOL( LINE_EXISTS( IT_CN_POSNR[ TABLE_LINE = LS_ITEM-POSNR ] )
                   AND IS_ITEM_IN_SCOPE( IV_WERKS = LS_ITEM-WERKS
                                         IV_AUART = IS_ORDER-AUART
                                         IV_PSTYV = LS_ITEM-PSTYV ) = ABAP_TRUE ).

      INSERT VALUE #( VBELN         = IS_ORDER-VBELN
                      POSNR         = LS_ITEM-POSNR
                      PROD_RELEVANT = LV_CN
                      COST_STATUS   = COND #( WHEN LV_CN = ABAP_TRUE THEN GC_COST-PENDING )
                      PROD_STATUS   = COND #( WHEN LV_CN = ABAP_TRUE THEN GC_PROD-BLOCKED )
                      CREATED_ON    = SY-DATUM ) INTO TABLE LT_ITM.

      LV_SAVE = ABAP_TRUE.
      IF LV_CN = ABAP_TRUE.
        LV_NOTE = |Item { LS_ITEM-POSNR ALPHA = OUT } added, waiting for YSDA/YSDAX|.
      ENDIF.

    ENDLOOP.

    "--- credit running or approved: compare with what credit approved ---
    "    (after a credit rejection the order is cancelled - nothing to compare)
    IF LS_HDR-CREDIT_STATUS = GC_CREDIT-IN_APPROVAL
    OR LS_HDR-CREDIT_STATUS = GC_CREDIT-APPROVED.

      DATA LV_REASON TYPE STRING.

      DATA(LV_RELEVANT) = IS_CREDIT_RELEVANT_CHANGE(
        EXPORTING IS_ORDER  = IS_ORDER
                  IT_ITEMS  = IT_ITEMS
        IMPORTING EV_REASON = LV_REASON ).

      IF LV_RELEVANT = ABAP_TRUE.

        IF LS_HDR-CREDIT_STATUS = GC_CREDIT-IN_APPROVAL.
          NEW ZCL_WF_SD_CREDIT( )->KILL_RUNNING_WORKFLOW(
            IV_VBELN  = IS_ORDER-VBELN
            IV_REASON = |Changed in { SY-TCODE } by { SY-UNAME }: { LV_REASON }| ).
        ENDIF.

        " new credit decision needed (items already on CP stay CP)
        LS_HDR-CREDIT_STATUS = GC_CREDIT-OPEN.
        CLEAR LS_HDR-WI_ID.
        LV_EVENT = 'RESTART'.
        LV_NOTE  = LV_REASON.
        LV_SAVE  = ABAP_TRUE.

      ELSEIF LS_HDR-CREDIT_STATUS = GC_CREDIT-IN_APPROVAL.

        LV_EVENT = 'NO_RESTART'.
        LV_NOTE  = |Change in { SY-TCODE } not credit relevant, workflow continues|.
        LV_SAVE  = ABAP_TRUE.

      ENDIF.

    ENDIF.

    CHECK LV_SAVE = ABAP_TRUE.

    SAVE( IS_HDR   = LS_HDR
          IT_ITEMS = LT_ITM
          IV_EVENT = LV_EVENT
          IV_NOTE  = LV_NOTE ).

  ENDMETHOD.


  METHOD IS_CREDIT_RELEVANT_CHANGE.

    CLEAR EV_REASON.

    DATA(LS_HDR) = READ_HEADER( IS_ORDER-VBELN ).

    " no snapshot = credit never looked at this order
    CHECK LS_HDR-SNAP_ON IS NOT INITIAL.

    DATA(LV_ANY) = XSDBOOL( IV_ANY_CHANGE = ABAP_TRUE OR GC_ANY_CHANGE = ABAP_TRUE ).

    "--- header data the credit decision is based on -------------------
    IF IS_ORDER-KNKLI <> LS_HDR-SNAP_KNKLI.
      EV_REASON = |Credit account { LS_HDR-SNAP_KNKLI ALPHA = OUT } -> { IS_ORDER-KNKLI ALPHA = OUT }|.
    ELSEIF IS_ORDER-KKBER <> LS_HDR-SNAP_KKBER.
      EV_REASON = |Credit control area { LS_HDR-SNAP_KKBER } -> { IS_ORDER-KKBER }|.
    ELSEIF IS_ORDER-WAERK <> LS_HDR-SNAP_WAERK.
      EV_REASON = |Currency { LS_HDR-SNAP_WAERK } -> { IS_ORDER-WAERK }|.
    ELSEIF IS_ORDER-ZTERM <> LS_HDR-SNAP_ZTERM.
      EV_REASON = |Payment terms { LS_HDR-SNAP_ZTERM } -> { IS_ORDER-ZTERM }|.
    ENDIF.

    IF EV_REASON IS NOT INITIAL.
      RV_RELEVANT = ABAP_TRUE.
      RETURN.
    ENDIF.

    "--- order net value ------------------------------------------------
    DATA LV_LIMIT TYPE VBAK-NETWR.
    LV_LIMIT = LS_HDR-SNAP_NETWR + LS_HDR-SNAP_NETWR * GC_TOL_PCT / 100.

    IF IS_ORDER-NETWR > LV_LIMIT
    OR ( LV_ANY = ABAP_TRUE AND IS_ORDER-NETWR <> LS_HDR-SNAP_NETWR ).
      EV_REASON = |Net value { IS_ORDER-NETWR } { IS_ORDER-WAERK }, | &&
                  |approved { LS_HDR-SNAP_NETWR } { LS_HDR-SNAP_WAERK }|.
      RV_RELEVANT = ABAP_TRUE.
      RETURN.
    ENDIF.

    "--- items -------------------------------------------------------------
    DATA(LT_SNAP) = READ_ITEMS( IS_ORDER-VBELN ).

    LOOP AT IT_ITEMS INTO DATA(LS_ITEM) WHERE UPDKZ <> 'D'.

      DATA(LS_SNAP) = VALUE ZSD_SO_REL_I( LT_SNAP[ POSNR = LS_ITEM-POSNR ] OPTIONAL ).
      DATA(LV_OPEN) = XSDBOOL( LS_ITEM-ABGRU IS INITIAL ).

      IF LV_OPEN = ABAP_TRUE AND LS_SNAP-SNAP_TAKEN = ABAP_FALSE.
        EV_REASON = |Item { LS_ITEM-POSNR ALPHA = OUT } added|.
      ELSEIF LV_OPEN = ABAP_TRUE AND LS_SNAP-SNAP_ABGRU IS NOT INITIAL.
        EV_REASON = |Item { LS_ITEM-POSNR ALPHA = OUT } rejection { LS_SNAP-SNAP_ABGRU } removed|.
      ELSEIF LV_OPEN = ABAP_TRUE AND LS_ITEM-KWMENG > LS_SNAP-SNAP_KWMENG.
        EV_REASON = |Item { LS_ITEM-POSNR ALPHA = OUT } quantity { LS_ITEM-KWMENG }, | &&
                    |approved { LS_SNAP-SNAP_KWMENG }|.
      ELSEIF LV_ANY = ABAP_TRUE AND LS_SNAP-SNAP_TAKEN = ABAP_TRUE
         AND ( LS_ITEM-KWMENG <> LS_SNAP-SNAP_KWMENG OR LS_ITEM-ABGRU <> LS_SNAP-SNAP_ABGRU ).
        EV_REASON = |Item { LS_ITEM-POSNR ALPHA = OUT } quantity / rejection changed|.
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
          IT_ITEMS = READ_ITEMS( IV_VBELN )
          IV_EVENT = 'DELETE'
          IV_NOTE  = |Sales order deleted in { SY-TCODE }| ).

  ENDMETHOD.


  METHOD IS_MANAGED.

    DATA(LS_HDR) = READ_HEADER( IV_VBELN ).
    RV_MANAGED = XSDBOOL( LS_HDR IS NOT INITIAL
                          AND LS_HDR-OVERALL_STATUS <> GC_OVERALL-DELETED ).

  ENDMETHOD.


  METHOD IS_IN_CREDIT_APPROVAL.

    RV_ACTIVE = XSDBOOL( READ_HEADER( IV_VBELN )-CREDIT_STATUS = GC_CREDIT-IN_APPROVAL ).

  ENDMETHOD.


  METHOD IS_ITEM_RELEASE_ALLOWED.

    DATA(LS_HDR) = READ_HEADER( IV_VBELN ).

    " not managed: old rules apply
    IF LS_HDR IS INITIAL.
      RV_ALLOWED = ABAP_TRUE.
      RETURN.
    ENDIF.

    DATA(LT_ITM) = READ_ITEMS( IV_VBELN ).
    DATA(LS_ITM) = VALUE ZSD_SO_REL_I( LT_ITM[ POSNR = IV_POSNR ] OPTIONAL ).

    " not a production item of the cycle: old rules apply
    IF LS_ITM-PROD_RELEVANT = ABAP_FALSE.
      RV_ALLOWED = ABAP_TRUE.
      RETURN.
    ENDIF.

    RV_ALLOWED = XSDBOOL( LS_ITM-COST_STATUS = GC_COST-APPROVED
                          AND ( LS_HDR-CREDIT_STATUS = GC_CREDIT-APPROVED
                             OR LS_HDR-CREDIT_STATUS = GC_CREDIT-NOT_NEEDED ) ).

  ENDMETHOD.


*======================================================================*
* YSDA / YSDAX
*======================================================================*
  METHOD ON_ITEM_DECISION.

    RV_MANAGED = IS_MANAGED( IV_VBELN ).
    CHECK RV_MANAGED = ABAP_TRUE.

    PROCESS( IV_VBELN ).

  ENDMETHOD.


  METHOD GET_ITEM_STATUS_TEXT.

    DATA(LS_HDR) = READ_HEADER( IV_VBELN ).
    DATA(LT_ITM) = READ_ITEMS( IV_VBELN ).
    DATA(LS_ITM) = VALUE ZSD_SO_REL_I( LT_ITM[ POSNR = IV_POSNR ] OPTIONAL ).

    RV_TEXT = COND #(
      WHEN LS_HDR IS INITIAL OR LS_ITM-PROD_RELEVANT = ABAP_FALSE
        THEN ``
      WHEN LS_ITM-PROD_STATUS = GC_PROD-CANCELLED
        THEN |Cancelled - credit rejected (reason { LS_ITM-REJ_ABGRU })|
      WHEN LS_ITM-COST_STATUS = GC_COST-REJECTED
        THEN |Rejected in YSDA/YSDAX (reason { LS_ITM-REJ_ABGRU }) - stays CN|
      WHEN LS_ITM-COST_STATUS = GC_COST-PENDING
        THEN `Waiting for SD and FI approval`
      WHEN LS_ITM-PROD_STATUS = GC_PROD-RELEASED
        THEN `Released to production (CP)`
      WHEN LS_ITM-PROD_STATUS = GC_PROD-ERROR
        THEN `Release to production failed - job will retry`
      WHEN LS_HDR-CREDIT_STATUS = GC_CREDIT-REJECTED
        THEN `Credit rejected - production stays blocked`
      WHEN LS_HDR-COST_STATUS = GC_COST-PENDING
        THEN `Approved - credit approval starts when all items are decided`
      WHEN LS_ITM-REL_PLAN = ABAP_TRUE
        THEN `Approved - goes CN -> CP at the credit final approval`
      ELSE `Approved - production blocked until credit approval` ).

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
      WHEN LS_HDR-OVERALL_STATUS = GC_OVERALL-DELETED    THEN GC_START-NO
      WHEN LS_HDR-COST_STATUS   <> GC_COST-APPROVED      THEN GC_START-NO    " YSDA first
      WHEN LS_HDR-CREDIT_STATUS  = GC_CREDIT-IN_APPROVAL THEN GC_START-NO    " one workflow
      WHEN LS_HDR-CREDIT_STATUS  = GC_CREDIT-REJECTED    THEN GC_START-NO
      WHEN LS_HDR-CREDIT_STATUS  = GC_CREDIT-APPROVED    THEN GC_START-NO
      ELSE                                                    GC_START-YES ).

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

    " order not managed: workflow runs as before
    CHECK LS_HDR IS NOT INITIAL.

    " another workflow already runs for this order -> this one ends
    IF LS_HDR-CREDIT_STATUS = GC_CREDIT-IN_APPROVAL
       AND LS_HDR-WI_ID IS NOT INITIAL
       AND LS_HDR-WI_ID <> IV_WI_ID
       AND IS_WORKITEM_ACTIVE( LS_HDR-WI_ID ) = ABAP_TRUE.
      RV_DUPLICATE = ABAP_TRUE.
      RETURN.
    ENDIF.

    DATA(LT_ITM) = READ_ITEMS( IV_VBELN ).

    LS_HDR-CREDIT_STATUS = GC_CREDIT-IN_APPROVAL.
    LS_HDR-WI_ID         = IV_WI_ID.
    LS_HDR-CREDIT_CYCLE  = LS_HDR-CREDIT_CYCLE + 1.

    TAKE_SNAPSHOT( CHANGING CS_HDR   = LS_HDR
                            CT_ITEMS = LT_ITM ).

    " which lines go CN -> CP at the final approval and which stay CN
    DATA(LV_PLAN) = SET_RELEASE_PLAN( CHANGING CT_ITEMS = LT_ITM ).

    SAVE( IS_HDR   = LS_HDR
          IT_ITEMS = LT_ITM
          IV_EVENT = 'CREDIT_ST'
          IV_NOTE  = |Credit workflow { IV_WI_ID ALPHA = OUT } started, cycle | &&
                     |{ LS_HDR-CREDIT_CYCLE }, value { LS_HDR-SNAP_NETWR } | &&
                     |{ LS_HDR-SNAP_WAERK }. { LV_PLAN }| ).

    " the workflow runtime commits after the step; the lock goes with it

  ENDMETHOD.


  METHOD ON_CREDIT_APPROVED.

    DATA(LS_HDR) = READ_HEADER( IV_VBELN ).

    IF LS_HDR IS INITIAL.
      RV_RELEASED = ABAP_TRUE.      " not managed - nothing to do
      RETURN.
    ENDIF.

    LS_HDR-CREDIT_STATUS  = GC_CREDIT-APPROVED.
    LS_HDR-CREDIT_DONE_ON = SY-DATUM.

    SAVE( IS_HDR   = LS_HDR
          IT_ITEMS = READ_ITEMS( IV_VBELN )
          IV_EVENT = 'CREDIT_OK'
          IV_NOTE  = |Credit workflow final approval| ).

    " PROCESS reads the DB, so the approval must be there first
    COMMIT WORK AND WAIT.

    " releases every approved item, commits
    PROCESS( IV_VBELN ).

    " false if an approved item is still on CN (order locked) -> retry
    DATA(LT_ITM) = READ_ITEMS( IV_VBELN ).
    RV_RELEASED = XSDBOOL( NOT LINE_EXISTS( LT_ITM[ COST_STATUS = GC_COST-APPROVED
                                                    PROD_STATUS = GC_PROD-ERROR ] ) ).

  ENDMETHOD.


  METHOD ON_CREDIT_REJECTED.

    DATA(LS_HDR) = READ_HEADER( IV_VBELN ).
    CHECK LS_HDR IS NOT INITIAL                     " not managed - nothing to do
      AND LS_HDR-CREDIT_STATUS <> GC_CREDIT-REJECTED.

    DATA(LT_ITM) = READ_ITEMS( IV_VBELN ).

    LS_HDR-CREDIT_STATUS  = GC_CREDIT-REJECTED.
    LS_HDR-CREDIT_DONE_ON = SY-DATUM.

    " every line as YSDA / YSDAX decided it:
    "  - rejected in YSDA / YSDAX: stays as it is (reason 63, CN)
    "  - approved in YSDA / YSDAX: not released (stays CN), cancelled
    "    together with the order by the next workflow step
    DATA LV_LINES TYPE I.
    LOOP AT LT_ITM ASSIGNING FIELD-SYMBOL(<LS_ITM>)
         WHERE PROD_RELEVANT = ABAP_TRUE
           AND COST_STATUS  <> GC_COST-REJECTED.
      CLEAR <LS_ITM>-REL_PLAN.
      <LS_ITM>-PROD_STATUS  = GC_PROD-CANCELLED.
      <LS_ITM>-CANCEL_ABGRU = IV_ABGRU.
      <LS_ITM>-CANCEL_ON    = SY-DATUM.
      LV_LINES = LV_LINES + 1.
    ENDLOOP.

    SAVE( IS_HDR   = LS_HDR
          IT_ITEMS = LT_ITM
          IV_EVENT = 'CREDIT_NOK'
          IV_NOTE  = |Credit rejected{ COND string( WHEN IV_NOTE IS NOT INITIAL THEN `: ` && IV_NOTE ) }. | &&
                     |{ LV_LINES } approved line(s) not released, order is cancelled by the workflow| ).

    " the workflow runtime commits after the step

  ENDMETHOD.


*======================================================================*
* Engine
*======================================================================*
  METHOD PROCESS.

    " always decide on the committed state (YSDA calls this per row,
    " the workflow may have changed the order meanwhile)
    CLEAR: MT_HDR_BUF, MT_ITM_BUF, MT_ITM_SET.

    DATA(LS_HDR) = READ_HEADER( IV_VBELN ).
    CHECK LS_HDR IS NOT INITIAL
      AND LS_HDR-OVERALL_STATUS <> GC_OVERALL-DELETED.

    DATA(LT_ITM) = READ_ITEMS( IV_VBELN ).

    DATA(LS_HDR_OLD) = LS_HDR.
    DATA(LT_ITM_OLD) = LT_ITM.

    "--- 1. item status from YSDA / YSDAX and the schedule lines --------
    REFRESH_ITEM_STATUS( EXPORTING IV_VBELN = IV_VBELN
                         CHANGING  CT_ITEMS = LT_ITM ).

    SET_SUMMARY( EXPORTING IT_ITEMS = LT_ITM
                 CHANGING  CS_HDR   = LS_HDR ).

    "--- 2. credit ------------------------------------------------------
    DATA(LV_BLOCK) = XSDBOOL( NEW ZCL_WF_SD_CREDIT( )->CHECK_SO_BLOCK( IV_VBELN ) = 'X' ).
    DATA LV_START TYPE ABAP_BOOL.

    CASE LS_HDR-CREDIT_STATUS.

      WHEN GC_CREDIT-OPEN OR GC_CREDIT-NOT_NEEDED.

        IF LV_BLOCK = ABAP_FALSE.
          " no credit limit / overdue problem: production may go
          LS_HDR-CREDIT_STATUS = GC_CREDIT-NOT_NEEDED.
        ELSEIF LS_HDR-COST_STATUS = GC_COST-APPROVED.
          " every production item decided, at least one approved
          LS_HDR-CREDIT_STATUS = GC_CREDIT-WAITING.
          LV_START = ABAP_TRUE.
        ELSE.
          " credit block, but YSDA / YSDAX not finished yet
          LS_HDR-CREDIT_STATUS = GC_CREDIT-OPEN.
        ENDIF.

      WHEN GC_CREDIT-WAITING.

        IF LV_BLOCK = ABAP_FALSE.
          LS_HDR-CREDIT_STATUS = GC_CREDIT-NOT_NEEDED.
        ELSEIF IV_RETRY_START = ABAP_TRUE.
          LV_START = ABAP_TRUE.            " job: start event got lost
        ENDIF.

    ENDCASE.

    IF LS_HDR-CREDIT_STATUS = GC_CREDIT-NOT_NEEDED
       AND LS_HDR_OLD-CREDIT_STATUS <> GC_CREDIT-NOT_NEEDED.
      LS_HDR-CREDIT_DONE_ON = SY-DATUM.
    ENDIF.

    IF LS_HDR-COST_STATUS <> GC_COST-PENDING
       AND LS_HDR_OLD-COST_STATUS = GC_COST-PENDING.
      LS_HDR-COST_DONE_ON = SY-DATUM.
    ENDIF.

    SET_SUMMARY( EXPORTING IT_ITEMS = LT_ITM
                 CHANGING  CS_HDR   = LS_HDR ).

    IF LS_HDR <> LS_HDR_OLD OR LT_ITM <> LT_ITM_OLD.

      SAVE( IS_HDR   = LS_HDR
            IT_ITEMS = LT_ITM
            IV_EVENT = COND #( WHEN LV_START = ABAP_TRUE THEN 'CREDIT_WT' ELSE 'STATUS' )
            IV_NOTE  = |Costing { LS_HDR-COST_STATUS }, credit { LS_HDR-CREDIT_STATUS }, | &&
                       |production { LS_HDR-PROD_STATUS }| ).

      " status must be on the DB before the workflow event is checked
      COMMIT WORK AND WAIT.

    ENDIF.

    IF LV_START = ABAP_TRUE.
      RAISE_START_EVENT( IV_VBELN ).
      RV_NOTE = `Credit workflow start requested`.
    ENDIF.

    "--- 3. production: every approved item, if credit allows ---------
    CHECK LS_HDR-CREDIT_STATUS = GC_CREDIT-APPROVED
       OR LS_HDR-CREDIT_STATUS = GC_CREDIT-NOT_NEEDED.

    DATA(LV_REL) = RELEASE_ITEMS( EXPORTING IV_VBELN = IV_VBELN
                                  CHANGING  CS_HDR   = LS_HDR
                                            CT_ITEMS = LT_ITM ).

    RV_NOTE = COND #( WHEN RV_NOTE IS INITIAL THEN LV_REL
                      WHEN LV_REL  IS INITIAL THEN RV_NOTE
                      ELSE |{ RV_NOTE }; { LV_REL }| ).

  ENDMETHOD.


  METHOD REFRESH_ITEM_STATUS.

    SELECT POSNR, ABGRU
      FROM VBAP
      WHERE VBELN = @IV_VBELN
      INTO TABLE @DATA(LT_VBAP).

    " items still blocked for production
    SELECT DISTINCT POSNR
      FROM VBEP
      WHERE VBELN = @IV_VBELN
        AND ETTYP = @GC_CN
        AND WMENG > 0
      INTO TABLE @DATA(LT_CN).

    " items approved by SD and FI in YSDA / YSDAX
    SELECT POSNR
      FROM ZSOAPPROVAL
      WHERE VBELN      = @IV_VBELN
        AND SD_APPROVE = 'X'
        AND FI_APPROVE = 'X'
      INTO TABLE @DATA(LT_OK).

    LOOP AT CT_ITEMS ASSIGNING FIELD-SYMBOL(<LS_ITM>) WHERE PROD_RELEVANT = ABAP_TRUE.

      " cancelled after a credit rejection: final, keep the YSDA decision
      CHECK <LS_ITM>-PROD_STATUS <> GC_PROD-CANCELLED.

      DATA(LV_ABGRU) = VALUE ABGRU_VA( LT_VBAP[ POSNR = <LS_ITM>-POSNR ]-ABGRU OPTIONAL ).
      DATA(LV_EXIST) = XSDBOOL( LINE_EXISTS( LT_VBAP[ POSNR = <LS_ITM>-POSNR ] ) ).

      " cost: rejected (63 or any reason except the automatic Z8),
      "       approved (SD + FI), or still pending
      DATA(LV_COST) = COND ZSD_REL_COST(
        WHEN LV_EXIST = ABAP_FALSE
          OR ( LV_ABGRU IS NOT INITIAL AND LV_ABGRU <> GC_REJ_AUTO ) THEN GC_COST-REJECTED
        WHEN LINE_EXISTS( LT_OK[ POSNR = <LS_ITM>-POSNR ] )             THEN GC_COST-APPROVED
        ELSE                                                                 GC_COST-PENDING ).

      " YSDA / YSDAX decision of this line: who, when, reason
      IF LV_COST <> <LS_ITM>-COST_STATUS.
        IF LV_COST = GC_COST-PENDING.
          CLEAR: <LS_ITM>-COST_DONE_ON, <LS_ITM>-DECIDED_BY,
                 <LS_ITM>-DECIDED_ON, <LS_ITM>-DECIDED_AT, <LS_ITM>-REJ_ABGRU.
        ELSE.
          <LS_ITM>-COST_DONE_ON = SY-DATUM.
          <LS_ITM>-DECIDED_BY   = SY-UNAME.
          <LS_ITM>-DECIDED_ON   = SY-DATUM.
          <LS_ITM>-DECIDED_AT   = SY-UZEIT.
          <LS_ITM>-REJ_ABGRU    = COND #( WHEN LV_COST = GC_COST-REJECTED THEN LV_ABGRU ).
        ENDIF.
      ENDIF.
      <LS_ITM>-COST_STATUS = LV_COST.

      " production: no CN line left = released (by us or before go-live)
      IF NOT LINE_EXISTS( LT_CN[ POSNR = <LS_ITM>-POSNR ] ).
        IF <LS_ITM>-PROD_STATUS <> GC_PROD-RELEASED.
          <LS_ITM>-PROD_STATUS = GC_PROD-RELEASED.
          <LS_ITM>-PROD_REL_ON = SY-DATUM.
        ENDIF.
      ELSEIF <LS_ITM>-PROD_STATUS = GC_PROD-RELEASED.
        <LS_ITM>-PROD_STATUS = GC_PROD-BLOCKED.       " CN again
      ELSEIF LV_COST = GC_COST-REJECTED.
        <LS_ITM>-PROD_STATUS = GC_PROD-KEPT.          " rejected: stays CN
        CLEAR <LS_ITM>-REL_PLAN.
      ELSEIF <LS_ITM>-PROD_STATUS = GC_PROD-KEPT.
        <LS_ITM>-PROD_STATUS = GC_PROD-BLOCKED.       " rejection removed
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD SET_SUMMARY.

    "--- costing: P while any production item is open ------------------
    DATA(LV_ITEMS) = REDUCE I( INIT N = 0 FOR L IN IT_ITEMS
                               WHERE ( PROD_RELEVANT = ABAP_TRUE ) NEXT N = N + 1 ).

    CS_HDR-COST_STATUS = COND #(
      WHEN LINE_EXISTS( IT_ITEMS[ PROD_RELEVANT = ABAP_TRUE COST_STATUS = GC_COST-PENDING ] )
        THEN GC_COST-PENDING
      WHEN LV_ITEMS > 0
       AND NOT LINE_EXISTS( IT_ITEMS[ PROD_RELEVANT = ABAP_TRUE COST_STATUS = GC_COST-APPROVED ] )
        THEN GC_COST-REJECTED
      ELSE GC_COST-APPROVED ).

    "--- production: over the approved items -----------------------------
    CS_HDR-PROD_STATUS = COND #(
      WHEN LINE_EXISTS( IT_ITEMS[ COST_STATUS = GC_COST-APPROVED PROD_STATUS = GC_PROD-ERROR ] )
        THEN GC_PROD-ERROR
      WHEN LINE_EXISTS( IT_ITEMS[ COST_STATUS = GC_COST-APPROVED PROD_STATUS = GC_PROD-BLOCKED ] )
        THEN GC_PROD-BLOCKED
      WHEN LINE_EXISTS( IT_ITEMS[ COST_STATUS = GC_COST-APPROVED PROD_STATUS = GC_PROD-RELEASED ] )
        THEN GC_PROD-RELEASED
      ELSE GC_PROD-BLOCKED ).

    "--- overall ----------------------------------------------------------
    CHECK CS_HDR-OVERALL_STATUS <> GC_OVERALL-DELETED.

    CS_HDR-OVERALL_STATUS = COND #(
      WHEN CS_HDR-COST_STATUS   = GC_COST-REJECTED
        OR CS_HDR-CREDIT_STATUS = GC_CREDIT-REJECTED      THEN GC_OVERALL-REJECTED
      WHEN CS_HDR-COST_STATUS   = GC_COST-PENDING         THEN GC_OVERALL-COSTING
      WHEN CS_HDR-PROD_STATUS   = GC_PROD-RELEASED        THEN GC_OVERALL-RELEASED
      ELSE                                                     GC_OVERALL-CREDIT ).

  ENDMETHOD.


  METHOD RELEASE_ITEMS.

    DATA LT_SCHDL  TYPE STANDARD TABLE OF BAPISCHDL.
    DATA LT_SCHDLX TYPE STANDARD TABLE OF BAPISCHDLX.
    DATA LT_RETURN TYPE STANDARD TABLE OF BAPIRET2.
    DATA LR_POSNR  TYPE RANGE OF POSNR_VA.

    " approved lines still blocked (B) or failed before (E); after a credit
    " approval only the lines of the release plan fixed at workflow start
    DATA(LV_PLAN_ONLY) = XSDBOOL( CS_HDR-CREDIT_STATUS = GC_CREDIT-APPROVED ).

    LR_POSNR = VALUE #( FOR L IN CT_ITEMS
                        WHERE ( PROD_RELEVANT = ABAP_TRUE
                            AND COST_STATUS   = GC_COST-APPROVED
                            AND ( PROD_STATUS = GC_PROD-BLOCKED OR PROD_STATUS = GC_PROD-ERROR ) )
                        ( SIGN = 'I' OPTION = 'EQ' LOW = L-POSNR ) ).

    IF LV_PLAN_ONLY = ABAP_TRUE.
      LOOP AT CT_ITEMS INTO DATA(LS_NOPLAN) WHERE REL_PLAN = ABAP_FALSE.
        DELETE LR_POSNR WHERE LOW = LS_NOPLAN-POSNR.
      ENDLOOP.
    ENDIF.

    CHECK LR_POSNR IS NOT INITIAL.

    SELECT POSNR, ETENR
      FROM VBEP
      WHERE VBELN = @IV_VBELN
        AND POSNR IN @LR_POSNR
        AND ETTYP = @GC_CN
        AND WMENG > 0
      INTO TABLE @DATA(LT_SL).

    CHECK LT_SL IS NOT INITIAL.

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

    DATA(LV_ERROR) = XSDBOOL( LINE_EXISTS( LT_RETURN[ TYPE = 'E' ] )
                           OR LINE_EXISTS( LT_RETURN[ TYPE = 'A' ] ) ).

    IF LV_ERROR = ABAP_TRUE.
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    ENDIF.

    LOOP AT CT_ITEMS ASSIGNING FIELD-SYMBOL(<LS_ITM>) WHERE POSNR IN LR_POSNR.
      IF LV_ERROR = ABAP_TRUE.
        <LS_ITM>-PROD_STATUS = GC_PROD-ERROR.
      ELSE.
        <LS_ITM>-PROD_STATUS = GC_PROD-RELEASED.
        <LS_ITM>-PROD_REL_ON = SY-DATUM.
        <LS_ITM>-PROD_REL_BY = SY-UNAME.
      ENDIF.
    ENDLOOP.

    SET_SUMMARY( EXPORTING IT_ITEMS = CT_ITEMS
                 CHANGING  CS_HDR   = CS_HDR ).

    IF LV_ERROR = ABAP_TRUE.
      DATA(LS_ERR) = VALUE BAPIRET2( LT_RETURN[ TYPE = 'E' ] OPTIONAL ).
      RV_NOTE = |CN->CP failed, job retries: { LS_ERR-MESSAGE }|.
      SAVE( IS_HDR = CS_HDR IT_ITEMS = CT_ITEMS IV_EVENT = 'PROD_ERR' IV_NOTE = RV_NOTE ).
      COMMIT WORK.
      RETURN.
    ENDIF.

    RV_NOTE = |{ LINES( LR_POSNR ) } item(s) released to production (CN -> CP)|.
    SAVE( IS_HDR = CS_HDR IT_ITEMS = CT_ITEMS IV_EVENT = 'PROD_REL' IV_NOTE = RV_NOTE ).

    " one commit for the order change and the release tables
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        WAIT = ABAP_TRUE.

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

    SELECT POSNR, KWMENG, VRKME, NETWR, ABGRU
      FROM VBAP
      WHERE VBELN = @CS_HDR-VBELN
      INTO TABLE @DATA(LT_VBAP).

    LOOP AT LT_VBAP INTO DATA(LS_VBAP).

      ASSIGN CT_ITEMS[ POSNR = LS_VBAP-POSNR ] TO FIELD-SYMBOL(<LS_ITM>).
      IF SY-SUBRC <> 0.
        " item without CN (e.g. service item): snapshot only
        INSERT VALUE #( VBELN      = CS_HDR-VBELN
                        POSNR      = LS_VBAP-POSNR
                        CREATED_ON = SY-DATUM ) INTO TABLE CT_ITEMS ASSIGNING <LS_ITM>.
      ENDIF.

      <LS_ITM>-SNAP_TAKEN  = ABAP_TRUE.
      <LS_ITM>-SNAP_KWMENG = LS_VBAP-KWMENG.
      <LS_ITM>-SNAP_VRKME  = LS_VBAP-VRKME.
      <LS_ITM>-SNAP_NETWR  = LS_VBAP-NETWR.
      <LS_ITM>-SNAP_ABGRU  = LS_VBAP-ABGRU.

    ENDLOOP.

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

    " Same event as a sales order save (BUS2032 CHANGED), so the existing
    " linkage of WS99000010 starts the workflow - nobody has to open the
    " order in VA02. Raised by YSDA/YSDAX when the last line is decided
    " (or by the job when a start got lost).
    DATA LV_RC     TYPE SY-SUBRC.
    DATA LV_EVT_ID TYPE SWR_STRUCT-EVENT_ID.
    DATA LT_CONT   TYPE STANDARD TABLE OF SWR_CONT.
    DATA LT_MSG    TYPE STANDARD TABLE OF SWR_MESSAG.

    " the start binding of WS99000010 maps &SOLDTOPARTY& -> &BUSINESS_PARTNER&
    SELECT SINGLE KUNNR FROM VBAK
      WHERE VBELN = @IV_VBELN
      INTO @DATA(LV_KUNNR).

    LT_CONT = VALUE #( ( ELEMENT = 'SOLDTOPARTY' VALUE = LV_KUNNR ) ).

    CALL FUNCTION 'SAP_WAPI_CREATE_EVENT'
      EXPORTING
        OBJECT_TYPE     = CONV SWR_STRUCT-OBJECT_TYP( 'BUS2032' )
        OBJECT_KEY      = CONV SWR_STRUCT-OBJECT_KEY( IV_VBELN )
        EVENT           = CONV SWR_STRUCT-EVENT( 'CHANGED' )
        COMMIT_WORK     = ABAP_TRUE
        USER            = SY-UNAME          " -> _EVT_CREATOR -> _WF_INITIATOR
      IMPORTING
        RETURN_CODE     = LV_RC
        EVENT_ID        = LV_EVT_ID
      TABLES
        INPUT_CONTAINER = LT_CONT
        MESSAGE_LINES   = LT_MSG.

    " log the start request (or its failure - the job raises it again)
    DATA(LS_HDR) = READ_HEADER( IV_VBELN ).
    CHECK LS_HDR IS NOT INITIAL.

    DATA(LS_MSG) = VALUE SWR_MESSAG( LT_MSG[ 1 ] OPTIONAL ).
    SAVE( IS_HDR   = LS_HDR
          IT_ITEMS = READ_ITEMS( IV_VBELN )
          IV_EVENT = COND #( WHEN LV_RC = 0 THEN 'EVENT' ELSE 'EVENT_ERR' )
          IV_NOTE  = COND #( WHEN LV_RC = 0
                             THEN |BUS2032 CHANGED raised by { SY-UNAME } ({ SY-TCODE }) to start WS99000010|
                             ELSE |BUS2032 CHANGED not raised (rc { LV_RC }): { LS_MSG-LINE }| ) ).
    COMMIT WORK.

  ENDMETHOD.


*======================================================================*
* Release plan, cancellation, line log
*======================================================================*
  METHOD SET_RELEASE_PLAN.

    " fixed when the credit workflow starts: approved lines go CN -> CP at
    " the final approval, rejected lines stay CN
    DATA LV_GO   TYPE STRING.
    DATA LV_KEEP TYPE STRING.

    LOOP AT CT_ITEMS ASSIGNING FIELD-SYMBOL(<LS_ITM>) WHERE PROD_RELEVANT = ABAP_TRUE.

      CASE <LS_ITM>-COST_STATUS.

        WHEN GC_COST-APPROVED.
          <LS_ITM>-REL_PLAN = XSDBOOL( <LS_ITM>-PROD_STATUS <> GC_PROD-RELEASED ).
          IF <LS_ITM>-REL_PLAN = ABAP_TRUE.
            LV_GO = |{ LV_GO } { <LS_ITM>-POSNR ALPHA = OUT }|.
          ENDIF.

        WHEN OTHERS.
          CLEAR <LS_ITM>-REL_PLAN.
          IF <LS_ITM>-PROD_STATUS <> GC_PROD-RELEASED.
            <LS_ITM>-PROD_STATUS = GC_PROD-KEPT.
          ENDIF.
          LV_KEEP = |{ LV_KEEP } { <LS_ITM>-POSNR ALPHA = OUT }|.

      ENDCASE.

    ENDLOOP.

    RV_NOTE = |Release plan - CN->CP:{ COND string( WHEN LV_GO IS INITIAL THEN ` none` ELSE LV_GO ) }; | &&
              |stay CN:{ COND string( WHEN LV_KEEP IS INITIAL THEN ` none` ELSE LV_KEEP ) }|.

  ENDMETHOD.


  METHOD ITEM_LOG.

    " new production line
    IF IS_OLD IS INITIAL.
      RV_NOTE = `Line added - waiting for YSDA/YSDAX`.
      RETURN.
    ENDIF.

    " YSDA / YSDAX decision
    IF IS_NEW-COST_STATUS <> IS_OLD-COST_STATUS.
      RV_NOTE = SWITCH #( IS_NEW-COST_STATUS
        WHEN GC_COST-APPROVED THEN |Approved in YSDA/YSDAX (SD + FI), completed by { IS_NEW-DECIDED_BY }|
        WHEN GC_COST-REJECTED THEN |Rejected in YSDA/YSDAX, reason { IS_NEW-REJ_ABGRU }, by { IS_NEW-DECIDED_BY }|
        ELSE                       `Back to waiting for YSDA/YSDAX` ).
    ENDIF.

    " release plan at credit workflow start
    IF IS_NEW-REL_PLAN = ABAP_TRUE AND IS_OLD-REL_PLAN = ABAP_FALSE.
      RV_NOTE = |{ RV_NOTE }{ COND string( WHEN RV_NOTE IS NOT INITIAL THEN `; ` ) }| &&
                `Release plan: CN -> CP at the credit final approval`.
    ENDIF.

    " production
    IF IS_NEW-PROD_STATUS <> IS_OLD-PROD_STATUS.
      DATA(LV_PROD) = SWITCH STRING( IS_NEW-PROD_STATUS
        WHEN GC_PROD-RELEASED  THEN `Released to production: CN -> CP`
        WHEN GC_PROD-KEPT      THEN `Stays CN - not released to production`
        WHEN GC_PROD-ERROR     THEN `CN -> CP failed - job retries`
        WHEN GC_PROD-CANCELLED THEN |Cancelled - credit rejected, reason { IS_NEW-CANCEL_ABGRU }|
        WHEN GC_PROD-BLOCKED   THEN `Production blocked (CN)` ).
      RV_NOTE = |{ RV_NOTE }{ COND string( WHEN RV_NOTE IS NOT INITIAL THEN `; ` ) }{ LV_PROD }|.
    ENDIF.

  ENDMETHOD.


  METHOD GET_RELEASE_PLAN.

    DATA(LS_HDR) = READ_HEADER( IV_VBELN ).
    CHECK LS_HDR IS NOT INITIAL.

    DATA(LT_ITM) = READ_ITEMS( IV_VBELN ).

    SELECT POSNR, MATNR, ARKTX, KWMENG, VRKME
      FROM VBAP
      WHERE VBELN = @IV_VBELN
      ORDER BY POSNR
      INTO TABLE @DATA(LT_VBAP).

    LOOP AT LT_VBAP INTO DATA(LS_VBAP).

      DATA(LS_ITM) = VALUE ZSD_SO_REL_I( LT_ITM[ POSNR = LS_VBAP-POSNR ] OPTIONAL ).
      CHECK LS_ITM-PROD_RELEVANT = ABAP_TRUE.

      DATA(LS_PLAN) = CORRESPONDING TY_S_PLAN( LS_VBAP ).

      LS_PLAN-DECISION = SWITCH #( LS_ITM-COST_STATUS
        WHEN GC_COST-APPROVED THEN |Approved { LS_ITM-DECIDED_ON DATE = USER } { LS_ITM-DECIDED_BY }|
        WHEN GC_COST-REJECTED THEN |Rejected ({ LS_ITM-REJ_ABGRU }) { LS_ITM-DECIDED_ON DATE = USER } { LS_ITM-DECIDED_BY }|
        ELSE                       `Waiting for YSDA/YSDAX` ).

      LS_PLAN-TO_PRODUCTION = XSDBOOL( LS_ITM-REL_PLAN = ABAP_TRUE
                                    OR LS_ITM-PROD_STATUS = GC_PROD-RELEASED ).

      LS_PLAN-TARGET = SWITCH #( LS_ITM-PROD_STATUS
        WHEN GC_PROD-RELEASED  THEN `Released (CP)`
        WHEN GC_PROD-CANCELLED THEN `Cancelled`
        WHEN GC_PROD-KEPT      THEN `Stays CN`
        ELSE COND #( WHEN LS_ITM-REL_PLAN = ABAP_TRUE THEN `CN -> CP after approval`
                     WHEN LS_ITM-COST_STATUS = GC_COST-REJECTED THEN `Stays CN`
                     ELSE `Blocked (CN)` ) ).

      APPEND LS_PLAN TO RT_PLAN.

    ENDLOOP.

  ENDMETHOD.


*======================================================================*
* Configuration / persistence
*======================================================================*
  METHOD IS_CONFIGURED.

    " only orders created on / after the go-live date (TVARVC)
    SELECT SINGLE LOW FROM TVARVC
      WHERE NAME = @GC_TVARVC_DATE
        AND TYPE = 'P'
        AND NUMB = '0000'
      INTO @DATA(LV_LOW).

    IF SY-SUBRC <> 0 OR LV_LOW IS INITIAL.
      RETURN.                                   " not live yet
    ENDIF.

    DATA(LV_ERDAT) = COND ERDAT( WHEN IS_ORDER-ERDAT IS INITIAL THEN SY-DATUM
                                 ELSE IS_ORDER-ERDAT ).
    CHECK LV_ERDAT >= CONV DATS( LV_LOW(8) ).

    " YSDA and YSDAX select only sales orders (C) and free of charge orders (I)
    RV_ACTIVE = XSDBOOL( IS_ORDER-VBTYP = 'C' OR IS_ORDER-VBTYP = 'I' ).

  ENDMETHOD.


  METHOD IS_ITEM_IN_SCOPE.

    " the selection rules of YSDA / YSDAX, '*' = any value
    SELECT SINGLE @ABAP_TRUE FROM ZSD_SO_REL_CFG
      WHERE WERKS  = @IV_WERKS
        AND ( AUART = @IV_AUART OR AUART = @GC_ALL )
        AND ( PSTYV = @IV_PSTYV OR PSTYV = @GC_ALL )
        AND ACTIVE = @ABAP_TRUE
      INTO @RV_IN_SCOPE.

  ENDMETHOD.


  METHOD READ_HEADER.

    RS_HDR = VALUE #( MT_HDR_BUF[ VBELN = IV_VBELN ] OPTIONAL ).
    CHECK RS_HDR IS INITIAL.

    SELECT SINGLE * FROM ZSD_SO_REL_H
      WHERE VBELN = @IV_VBELN
      INTO @RS_HDR.

  ENDMETHOD.


  METHOD READ_ITEMS.

    IF LINE_EXISTS( MT_ITM_SET[ TABLE_LINE = IV_VBELN ] ).
      LOOP AT MT_ITM_BUF INTO DATA(LS_BUF) WHERE VBELN = IV_VBELN.
        INSERT LS_BUF INTO TABLE RT_ITEMS.
      ENDLOOP.
      RETURN.
    ENDIF.

    SELECT * FROM ZSD_SO_REL_I
      WHERE VBELN = @IV_VBELN
      INTO TABLE @RT_ITEMS.

  ENDMETHOD.


  METHOD SAVE.

    DATA(LS_HDR) = IS_HDR.

    SET_SUMMARY( EXPORTING IT_ITEMS = IT_ITEMS
                 CHANGING  CS_HDR   = LS_HDR ).

    LS_HDR-CHANGED_BY = SY-UNAME.
    LS_HDR-CHANGED_ON = SY-DATUM.
    LS_HDR-CHANGED_AT = SY-UZEIT.

    DATA LV_TS TYPE TIMESTAMPL.
    GET TIME STAMP FIELD LV_TS.

    "--- order level log row (POSNR 000000) ---------------------------------
    DATA LT_LOG TYPE STANDARD TABLE OF ZSD_SO_REL_LOG WITH EMPTY KEY.

    APPEND VALUE #( VBELN          = LS_HDR-VBELN
                    LOG_TS         = LV_TS
                    POSNR          = '000000'
                    EVENT          = IV_EVENT
                    COST_STATUS    = LS_HDR-COST_STATUS
                    CREDIT_STATUS  = LS_HDR-CREDIT_STATUS
                    PROD_STATUS    = LS_HDR-PROD_STATUS
                    OVERALL_STATUS = LS_HDR-OVERALL_STATUS
                    NOTE           = IV_NOTE
                    UNAME          = SY-UNAME
                    TCODE          = SY-TCODE ) TO LT_LOG.

    "--- one log row per line whose status changed --------------------------
    DATA(LT_OLD) = READ_ITEMS( LS_HDR-VBELN ).

    LOOP AT IT_ITEMS INTO DATA(LS_NEW) WHERE PROD_RELEVANT = ABAP_TRUE.

      DATA(LS_OLD) = VALUE ZSD_SO_REL_I( LT_OLD[ POSNR = LS_NEW-POSNR ] OPTIONAL ).
      DATA(LV_ITEM_NOTE) = ITEM_LOG( IS_OLD = LS_OLD
                                     IS_NEW = LS_NEW ).
      CHECK LV_ITEM_NOTE IS NOT INITIAL.

      APPEND VALUE #( VBELN          = LS_HDR-VBELN
                      LOG_TS         = LV_TS
                      POSNR          = LS_NEW-POSNR
                      EVENT          = 'ITEM'
                      COST_STATUS    = LS_NEW-COST_STATUS
                      CREDIT_STATUS  = LS_HDR-CREDIT_STATUS
                      PROD_STATUS    = LS_NEW-PROD_STATUS
                      OVERALL_STATUS = LS_HDR-OVERALL_STATUS
                      NOTE           = LV_ITEM_NOTE
                      UNAME          = SY-UNAME
                      TCODE          = SY-TCODE ) TO LT_LOG.

    ENDLOOP.

    "--- write directly - no COMMIT here --------------------------------------
    "    The caller's COMMIT WORK saves it: the sales order save in VA01 / VA02
    "    (MV45AFZZ), the commit in PROCESS after a YSDA / YSDAX decision, the
    "    workflow runtime after a workflow step, the commit of the job.
    "    A ROLLBACK of the caller removes it again.
    MODIFY ZSD_SO_REL_H FROM @LS_HDR.

    " all items of the order are always passed
    DELETE FROM ZSD_SO_REL_I WHERE VBELN = @LS_HDR-VBELN.
    IF IT_ITEMS IS NOT INITIAL.
      INSERT ZSD_SO_REL_I FROM TABLE @IT_ITEMS.
    ENDIF.

    INSERT ZSD_SO_REL_LOG FROM TABLE @LT_LOG ACCEPTING DUPLICATE KEYS.

    "--- buffer, so later reads in this LUW see the change ----------------
    MODIFY TABLE MT_HDR_BUF FROM LS_HDR.
    IF SY-SUBRC <> 0.
      INSERT LS_HDR INTO TABLE MT_HDR_BUF.
    ENDIF.

    DELETE MT_ITM_BUF WHERE VBELN = LS_HDR-VBELN.
    INSERT LINES OF IT_ITEMS INTO TABLE MT_ITM_BUF.
    INSERT LS_HDR-VBELN INTO TABLE MT_ITM_SET.

  ENDMETHOD.
ENDCLASS.
