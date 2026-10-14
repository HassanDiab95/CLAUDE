# Requirement 1: YSDA/YSDAX approval first, then credit management, production block until both are done

Status: design and draft code, **not compiled or tested in SAP**.

## Target flow per sales order

| Step | Who | Schedule line | Shown in YSDA/YSDAX | Credit WF WS99000010 |
|---|---|---|---|---|
| 1. Order saved | VA01/VA02 | `CN` (blocked) | yes | event arrives, check FM says **not relevant** (costing pending) |
| 2a. All items SD+FI approved, order **not** credit blocked | YSDA/YSDAX | `CN` → `CP` | no (not CN any more) | never needed |
| 2b. All items SD+FI approved, order credit blocked (`CMGST = 'B'`) | YSDA/YSDAX | stays `CN` | **no** (hidden: already approved) | YSDA/YSDAX raises BUS2032 `CHANGED` → WF starts |
| 3. Final credit approval | WS99000010 | `CN` → `CP` | no | ends |
| Safety net | background job | `CN` → `CP` for approved orders no longer credit blocked | no | – |

Principle: the schedule line category is the *production* block only. "Is costing approval done?" is read from
`ZSOAPPROVAL` (SD_APPROVE / FI_APPROVE), never from `CN`. That is what lets an order stay `CN` without coming back
into YSDA/YSDAX. One release method (`RELEASE_PRODUCTION`) is used by YSDA, YSDAX, the workflow and the job.

## A. ZCL_WF_SD_CREDIT – new public methods

```abap
    "! An item of the order is still waiting for YSDA / YSDAX approval
    METHODS IS_COSTING_PENDING
      IMPORTING IV_VBELN          TYPE VBELN_VA
      RETURNING VALUE(RV_PENDING) TYPE ABAP_BOOL.

    "! Raise BUS2032 CHANGED so WS99000010 is checked again
    METHODS RAISE_START_EVENT
      IMPORTING IV_VBELN TYPE VBELN_VA.

    "! Production release: CN -> CP on the items approved in YSDA / YSDAX
    METHODS RELEASE_PRODUCTION
      IMPORTING IV_VBELN           TYPE VBELN_VA
      EXPORTING ET_RETURN          TYPE BAPIRET2_T
      RETURNING VALUE(RV_RELEASED) TYPE ABAP_BOOL.
```

```abap
  METHOD IS_COSTING_PENDING.

    " open items with a production block: not rejected, or rejected
    " with Z8 (the automatic YSDA rejection that FI approval clears)
    SELECT DISTINCT E~POSNR
      FROM VBEP AS E
      INNER JOIN VBAP AS P ON P~VBELN = E~VBELN
                          AND P~POSNR = E~POSNR
      WHERE E~VBELN = @IV_VBELN
        AND E~ETTYP = 'CN'
        AND ( P~ABGRU = @SPACE OR P~ABGRU = 'Z8' )
      INTO TABLE @DATA(LT_POSNR).

    LOOP AT LT_POSNR INTO DATA(LV_POSNR).

      " no row yet = nobody has opened it in YSDA / YSDAX = pending
      SELECT SINGLE @ABAP_TRUE
        FROM ZSOAPPROVAL
        WHERE VBELN      = @IV_VBELN
          AND POSNR      = @LV_POSNR
          AND SD_APPROVE = 'X'
          AND FI_APPROVE = 'X'
        INTO @DATA(LV_DONE).

      IF SY-SUBRC <> 0.
        RV_PENDING = ABAP_TRUE.
        RETURN.
      ENDIF.

    ENDLOOP.

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


  METHOD RELEASE_PRODUCTION.

    DATA LT_SCHDL  TYPE STANDARD TABLE OF BAPISCHDL.
    DATA LT_SCHDLX TYPE STANDARD TABLE OF BAPISCHDLX.
    DATA LT_RETURN TYPE STANDARD TABLE OF BAPIRET2.

    CLEAR ET_RETURN.

    CHECK IV_VBELN IS NOT INITIAL.

    " only the schedule lines of items approved by SD and FI
    SELECT E~POSNR, E~ETENR
      FROM VBEP AS E
      INNER JOIN ZSOAPPROVAL AS Z ON Z~VBELN = E~VBELN
                                 AND Z~POSNR = E~POSNR
      WHERE E~VBELN      = @IV_VBELN
        AND E~ETTYP      = 'CN'
        AND E~WMENG      > 0
        AND Z~SD_APPROVE = 'X'
        AND Z~FI_APPROVE = 'X'
      INTO TABLE @DATA(LT_SL).

    SORT LT_SL BY POSNR ETENR.
    DELETE ADJACENT DUPLICATES FROM LT_SL COMPARING POSNR ETENR.

    IF LT_SL IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT LT_SL INTO DATA(LS_SL).

      APPEND VALUE #( ITM_NUMBER = LS_SL-POSNR
                      SCHED_LINE = LS_SL-ETENR
                      SCHED_TYPE = 'CP' ) TO LT_SCHDL.

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

    IF LINE_EXISTS( LT_RETURN[ TYPE = 'E' ] )
    OR LINE_EXISTS( LT_RETURN[ TYPE = 'A' ] ).
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    ELSE.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          WAIT = ABAP_TRUE.
      RV_RELEASED = ABAP_TRUE.
    ENDIF.

    ET_RETURN = LT_RETURN.

  ENDMETHOD.
```

### IS_START_ALLOWED – two new checks before CHECK_SO_BLOCK

```abap
    " YSDA / YSDAX approval runs first
    IF IS_COSTING_PENDING( IV_VBELN ) = ABAP_TRUE.
      RETURN.
    ENDIF.

    " a credit workflow is already running for this order
    " (only if WS99000010 deletes ZSD_WF_SO when it ends - confirm)
    IF IS_ORDER_LOCKED( IV_VBELN ) = ABAP_TRUE.
      RETURN.
    ENDIF.
```

## B. YSDA and YSDAX – FORM SCREEN_START: hide approved items

Inside the `SELECT ... ENDSELECT`, right after the `INTO (...)` list
(YSDA `part1/YSDA_YSP_MTOSO_APPROVE.abap.txt:1062`, YSDAX `part1/YSDAX_YSP_MTOSO_APPROVE_CX.abap.txt:892`):

```abap
      " approved by SD and FI: production stays blocked (CN) until
      " the credit workflow is done, so not shown here any more
      SELECT SINGLE @ABAP_TRUE FROM ZSOAPPROVAL
        WHERE VBELN      = @SO_WA-SO_NUM
          AND POSNR      = @SO_WA-POSNR
          AND SD_APPROVE = 'X'
          AND FI_APPROVE = 'X'
        INTO @DATA(LV_APPROVED).
      IF SY-SUBRC = 0.
        CLEAR: SO_WA, LV_APPROVED.
        CONTINUE.
      ENDIF.
```

`CLEAR SO_WA` matters: the `INTO` list does not overwrite every field (customer name, colours, ...).

## C. YSDA and YSDAX – FORM APPROVE_FUN

### C1. Replace the body of `IF SD_APPROVE = 'X' AND FI_APPROVE = 'X'.`
(YSDA line 1704, YSDAX line 1285). Keep the YSP_MTOSO_LOG insert after it.

```abap
    IF SD_APPROVE = 'X' AND FI_APPROVE = 'X'.

      DATA(LO_CREDIT) = NEW ZCL_WF_SD_CREDIT( ).

      IF LO_CREDIT->CHECK_SO_BLOCK( SO_WA-SO_NUM ) = 'X'.

        " credit limit / overdue: keep the production block (CN),
        " the credit workflow releases it after final approval
        WA_LOG-NOTE = 'Costing approved - waiting for credit approval'.

        IF LO_CREDIT->IS_COSTING_PENDING( SO_WA-SO_NUM ) = ABAP_FALSE.
          LO_CREDIT->RAISE_START_EVENT( SO_WA-SO_NUM ).
        ENDIF.

      ELSE.

        " no credit issue: release production now (as before)
        LO_CREDIT->RELEASE_PRODUCTION(
          EXPORTING IV_VBELN  = SO_WA-SO_NUM
          IMPORTING ET_RETURN = DATA(LT_REL_RETURN) ).

        LOOP AT LT_REL_RETURN INTO DATA(LS_REL) WHERE ID = 'V1'.
          MESSAGE LS_REL-MESSAGE(100) TYPE 'I'.
          WA_LOG-NOTE = LS_REL-MESSAGE(100).
        ENDLOOP.

      ENDIF.

      " ... existing *INSERT LOG block unchanged ...
```

### C2. YSDA only – FI branch must not release production
In the `ELSEIF ZPOSNUM = 'FI'` branch (YSDA lines 1631–1670) the BAPI call clears Z8 **and** sets CP.
Keep clearing Z8, remove the schedule lines (delete the `SELECT ETENR ... ENDSELECT` and the
`SCHEDULE_LINES` / `SCHEDULE_LINESX` parameters), and refresh the tables per row:

```abap
          REFRESH: ORDER_ITEM_IN, ORDER_ITEM_INX, LT_RETURN.

          ORDER_HEADER_INX-UPDATEFLAG = 'U'.
          ORDER_ITEM_IN-ITM_NUMBER  = SO_WA-POSNR.
          ORDER_ITEM_IN-REASON_REJ  = ''.
          APPEND ORDER_ITEM_IN.
          ORDER_ITEM_INX-ITM_NUMBER = SO_WA-POSNR.
          ORDER_ITEM_INX-UPDATEFLAG = 'U'.
          ORDER_ITEM_INX-REASON_REJ = 'X'.
          APPEND ORDER_ITEM_INX.

          CALL FUNCTION 'BAPI_SALESORDER_CHANGE'  "#EC CI_USAGE_OK[2438131]
            EXPORTING
              SALESDOCUMENT    = SO_WA-SO_NUM
              ORDER_HEADER_INX = ORDER_HEADER_INX
            TABLES
              RETURN           = LT_RETURN
              ORDER_ITEM_IN    = ORDER_ITEM_IN
              ORDER_ITEM_INX   = ORDER_ITEM_INX.
```

Existing bug fixed by this: `ORDER_ITEM_IN`, `LT_SCHDL`, `LT_SCHDLX` are header-line tables that are never refreshed
inside the row loop, so with several rows selected the 2nd BAPI call also carries the 1st row's lines.

## D. Workflow WS99000010 – release production after final approval

Background step right after the final "Approve Release Sales Order" (the place where the credit block is released),
in the class your other background steps use (must implement IF_WORKFLOW):

```abap
  " RAISING CX_BO_TEMPORARY -> step goes into retry (e.g. order open in VA02)
  METHOD RELEASE_PRODUCTION_STEP.

    DATA(LO_CREDIT) = NEW ZCL_WF_SD_CREDIT( ).

    IF LO_CREDIT->RELEASE_PRODUCTION( IV_VBELN ) = ABAP_FALSE.
      " nothing left on CN = already released, that is fine;
      " CN still there = BAPI failed (e.g. order locked) -> retry
      SELECT SINGLE @ABAP_TRUE FROM VBEP
        WHERE VBELN = @IV_VBELN AND ETTYP = 'CN' AND WMENG > 0
        INTO @DATA(LV_OPEN).
      IF SY-SUBRC = 0.
        RAISE EXCEPTION TYPE CX_BO_TEMPORARY.
      ENDIF.
    ENDIF.

  ENDMETHOD.
```

## E. Safety net job ZSD_MTO_RELEASE_PENDING (every 30–60 min)

Releases orders that are costing-approved, still `CN`, and no longer credit blocked
(credit released outside the workflow, BAPI failed because the order was locked, workflow killed, ...).

```abap
REPORT ZSD_MTO_RELEASE_PENDING.

SELECT DISTINCT E~VBELN
  FROM VBEP AS E
  INNER JOIN ZSOAPPROVAL AS Z ON Z~VBELN = E~VBELN
                             AND Z~POSNR = E~POSNR
  INNER JOIN VBAK AS K ON K~VBELN = E~VBELN
  WHERE E~ETTYP      = 'CN'
    AND E~WMENG      > 0
    AND Z~SD_APPROVE = 'X'
    AND Z~FI_APPROVE = 'X'
    AND K~CMGST     IN ( @SPACE, 'A', 'D' )
  INTO TABLE @DATA(LT_ORDER).

DATA(LO_CREDIT) = NEW ZCL_WF_SD_CREDIT( ).

LOOP AT LT_ORDER INTO DATA(LS_ORDER).

  CHECK LO_CREDIT->IS_ORDER_LOCKED( LS_ORDER-VBELN ) = ABAP_FALSE.

  IF LO_CREDIT->RELEASE_PRODUCTION( LS_ORDER-VBELN ) = ABAP_TRUE.
    WRITE: / LS_ORDER-VBELN, 'released to production (CP)'.
  ELSE.
    WRITE: / LS_ORDER-VBELN, 'NOT released - check order'.
  ENDIF.

ENDLOOP.
```

## Test cases

1. Order without credit issue → YSDA SD+FI → CP immediately, no workflow.
2. Order with credit exceed → no workflow at save → YSDA SD+FI → order disappears from YSDA, still CN → workflow starts → final approval → CP.
3. Same with overdue only, and with both.
4. Order with 3 items, approve 2 → no workflow; approve 3rd → workflow starts once.
5. Workflow rejection → order stays CN, not in YSDA.
6. Order open in VA02 during final approval → step retries / job releases later.
7. Changing CN → CP must not re-run the credit check and set `CMGST = 'B'` again (would restart the workflow).
8. YSDAX item hidden because it has sales order stock (MSKA) but still CN → would keep the order "pending" forever.
