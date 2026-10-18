# Changes to existing objects – apply manually

Only the lines that change. Every change gives:
- **Where** – object / include / FORM or method,
- **Find** – the existing line(s) exactly as they are in your system today,
- **Action** – INSERT AFTER, INSERT BEFORE, REPLACE or DELETE,
- **Code** – the new lines (marked `"REQ1`).

New objects (tables, `ZCL_SD_SO_RELEASE`, update FM, workflow step class, job, monitor) are in
`02_new_objects` and must exist **before** these changes are activated.

Draft – not compiled or tested in SAP.

| # | Object | Changes |
|---|---|---|
| A | `ZCL_WF_SD_CREDIT` → `IS_START_ALLOWED` | 1 insert |
| B | `MV45AFZZ` | B1–B2 kill on change, B3 new enhancement (save), B4 kill on delete, B5 new enhancement (prepare), B6–B7 `ZSD_CHECK_APPROVAL`, B8 VA02 redirect |
| C | YSDA `YSP_MTOSO_APPROVE` | C1 list filter, C2–C5 `APPROVE_FUN`, C6–C7 `REJECT_FUN` |
| D | YSDAX `YSP_MTOSO_APPROVE_CX` | D1 list filter, D2–D4 `APPROVE_FUN`, D5–D6 `REJECT_FUN` |
| E | Workflow `WS99000010` | see `WS99000010_workflow_changes.md` |
| F | `ZCL_WF_SD_ALERT` → `BUILD_HTML` | F1 – table of the order lines in the approver mail / work item: YSDA decision and CN → CP or stays CN |

---

## A. Class `ZCL_WF_SD_CREDIT`, method `IS_START_ALLOWED` (SE24)

### A1 – INSERT AFTER
**Find:**
```abap
    IF LV_START_ON IS NOT INITIAL AND LV_ERDAT < LV_START_ON.
      RETURN.
    ENDIF.
```
**Insert after it:**
```abap
    "REQ1: production orders - every item decided in YSDA/YSDAX first,
    "      only one workflow at a time, no new start after approval/rejection
    IF NEW ZCL_SD_SO_RELEASE( )->CAN_START_CREDIT_WF( IV_VBELN )
       = ZCL_SD_SO_RELEASE=>GC_START-NO.
      RETURN.
    ENDIF.
```
The check FM `Z_FM_SD_WF_CHECK_CREDIT` itself does not change.

---

## B. Include `MV45AFZZ` (SE80)

> Why `IF` instead of `CHECK`: an enhancement is part of the user exit it sits in. A failing `CHECK` leaves
> the **whole** user exit, so every enhancement after it is skipped. Today `ZEN_CMEXOD_KILL_WORKFLOW` is the
> first enhancement in `USEREXIT_SAVE_DOCUMENT`; its CHECKs skip `ZO2C_CREDITLMIT_CHECK`,
> `ZSAVE_DIFF_COST_PROFIT`, `ZSD_CHECK_SALESOFFICE`, `ZSD_DISCOUNT_BLOCK` … on almost every save.

### FORM `USEREXIT_SAVE_DOCUMENT`, enhancement `ZEN_CMEXOD_KILL_WORKFLOW`

#### B1 – REPLACE
**Find:**
```abap
  CHECK ( T180-TRTYP = 'V' AND T180-TCODE = 'VA02' )   "SY-TCODE = 'VA02'
     AND VBAK-VBELN IS NOT INITIAL.
```
**Replace with:**
```abap
  "REQ1: IF instead of CHECK; release-cycle orders handled by ZEN_SO_RELEASE_SAVE
  IF ( T180-TRTYP = 'V' AND T180-TCODE = 'VA02' )   "SY-TCODE = 'VA02'
     AND VBAK-VBELN IS NOT INITIAL
     AND NEW ZCL_SD_SO_RELEASE( )->IS_MANAGED( VBAK-VBELN ) = ABAP_FALSE.
```

#### B2 – REPLACE + INSERT
**Find:**
```abap
CHECK LO_CREDIT->IS_ORDER_LOCKED( VBAK-VBELN ) = ABAP_TRUE.
```
**Replace with:**
```abap
IF LO_CREDIT->IS_ORDER_LOCKED( VBAK-VBELN ) = ABAP_TRUE.          "REQ1
```
**Then find** (the end of the active code, before the commented `CALL FUNCTION 'Z_WF_SD_KILL_WORKFLOW_UPD'`):
```abap
                              |Approval Cancel, credit check will re-run.| )    ).
```
**Insert after it:**
```abap
  ENDIF.                                                           "REQ1
  ENDIF.                                                           "REQ1
```

### B3 – NEW enhancement implementation in `USEREXIT_SAVE_DOCUMENT`
At the enhancement point at the start of `USEREXIT_SAVE_DOCUMENT` (where `ZEN_CMEXOD_KILL_WORKFLOW` is):
right click → Enhancement Implementation → Create → name `ZEN_SO_RELEASE_SAVE`.
```abap
ENHANCEMENT 1  ZEN_SO_RELEASE_SAVE.    "active version
*--- REQ1 release cycle: create the release row, detect new items,
*--- restart the credit workflow only on a credit relevant change.
  IF XVBAK_UPDKZ <> 'D' AND VBAK-VBELN IS NOT INITIAL.
    NEW ZCL_SD_SO_RELEASE( )->ON_ORDER_SAVED(
      IS_ORDER    = VALUE #( VBELN = VBAK-VBELN
                             BUKRS = VBAK-BUKRS_VF
                             VKORG = VBAK-VKORG
                             AUART = VBAK-AUART
                             ERDAT = VBAK-ERDAT
                             KNKLI = VBAK-KNKLI
                             KKBER = VBAK-KKBER
                             WAERK = VBAK-WAERK
                             NETWR = VBAK-NETWR
                             ZTERM = VALUE #( XVBKD[ POSNR = '000000' ]-ZTERM OPTIONAL ) )
      IT_ITEMS    = CORRESPONDING #( XVBAP[] )
      IT_CN_POSNR = VALUE #( FOR LS_REL_EP IN XVBEP[]
                             WHERE ( ETTYP = 'CN' AND UPDKZ <> 'D' )
                             ( LS_REL_EP-POSNR ) ) ).
  ENDIF.
ENDENHANCEMENT.
```

### FORM `USEREXIT_DELETE_DOCUMENT`, enhancement `ZEN_CMEXOD_KILL_WORKFLOW_WDEL`

#### B4 – REPLACE + INSERT
**Find:**
```abap
  CHECK ( XVBAK_UPDKZ = 'D' AND T180-TRTYP = 'V' )   " SY-TCODE = 'VA02'
     AND VBAK-VBELN IS NOT INITIAL.
```
**Replace with:**
```abap
  "REQ1: IF instead of CHECK; release-cycle orders are closed by the release class
  IF ( XVBAK_UPDKZ = 'D' AND T180-TRTYP = 'V' )   " SY-TCODE = 'VA02'
     AND VBAK-VBELN IS NOT INITIAL.

  IF NEW ZCL_SD_SO_RELEASE( )->IS_MANAGED( VBAK-VBELN ) = ABAP_TRUE.
    NEW ZCL_SD_SO_RELEASE( )->ON_ORDER_DELETED( VBAK-VBELN ).
  ELSE.
```
**Find:**
```abap
CHECK LO_CREDIT->IS_ORDER_LOCKED( VBAK-VBELN ) = ABAP_TRUE.
```
**Replace with:**
```abap
IF LO_CREDIT->IS_ORDER_LOCKED( VBAK-VBELN ) = ABAP_TRUE.          "REQ1
```
**Find:**
```abap
    IV_REASON = CONV STRING( |Sales order Deleted In { SY-TCODE } by { SY-UNAME }.| && |Approval Cancel.| ) ).
```
**Insert after it:**
```abap
  ENDIF.                                                           "REQ1
  ENDIF.                                                           "REQ1
  ENDIF.                                                           "REQ1
```

### B5 – NEW enhancement implementation in `USEREXIT_SAVE_DOCUMENT_PREPARE`
At the enhancement point at the start of `USEREXIT_SAVE_DOCUMENT_PREPARE`, create `ZEN_SO_RELEASE_NO_VKM`:
```abap
ENHANCEMENT 1  ZEN_SO_RELEASE_NO_VKM.    "active version
*--- REQ1: no manual credit release while the credit workflow runs
  IF ( SY-TCODE = 'VKM1' OR SY-TCODE = 'VKM3' OR SY-TCODE = 'VKM4' )
     AND VBAK-VBELN IS NOT INITIAL
     AND NEW ZCL_SD_SO_RELEASE( )->IS_IN_CREDIT_APPROVAL( VBAK-VBELN ) = ABAP_TRUE.
    MESSAGE E015(ZSD_WF) WITH VBAK-VBELN.
  ENDIF.
ENDENHANCEMENT.
```

### FORM `USEREXIT_MOVE_FIELD_TO_VBEP`, enhancement `ZSD_CHECK_APPROVAL`

#### B6 – REPLACE (existing bug: ZSOAPPROVAL-BUKRS holds the plant, not the company code)
**Find:**
```abap
        AND   POSNR = VBEP-POSNR
        AND   BUKRS = VBAK-BUKRS_VF.
```
**Replace with:**
```abap
        AND   POSNR = VBEP-POSNR.      "REQ1: no BUKRS - YSDA/YSDAX store the plant in it
```

#### B7 – INSERT AFTER
**Find:**
```abap
      IF SY-DBCNT = 0 OR ( SD_APRV IS INITIAL OR FI_APRV IS INITIAL ).
        MESSAGE 'Change Schedule Line Error: Document is not yet approved via YSDAX/YSDA' TYPE 'E'.
      ENDIF.
```
**Insert after it:**
```abap
      "REQ1: release cycle - the item leaves CN only after the credit approval
      IF *VBEP-ETTYP = 'CN'
         AND NEW ZCL_SD_SO_RELEASE( )->IS_ITEM_RELEASE_ALLOWED(
               IV_VBELN = VBEP-VBELN
               IV_POSNR = VBEP-POSNR ) = ABAP_FALSE.
        MESSAGE E016(ZSD_WF) WITH VBEP-POSNR.
      ENDIF.
```

### FORM `USEREXIT_READ_DOCUMENT`, enhancement `ZEN_DISAB_VA02_CM_WF_RUNNINNG`

#### B8 – REPLACE + INSERT
**Find:**
```abap
  CHECK SY-TCODE = 'VA02'
     AND VBAK-VBELN IS NOT INITIAL
     AND NEW ZCL_WF_SD_CREDIT( )->IS_ORDER_LOCKED( VBAK-VBELN ) = ABAP_TRUE.
```
**Replace with:**
```abap
  "REQ1: IF instead of CHECK; release-cycle orders may be changed during the
  "      workflow (the release class restarts it only on a credit change)
  IF SY-TCODE = 'VA02'
     AND VBAK-VBELN IS NOT INITIAL
     AND NEW ZCL_WF_SD_CREDIT( )->IS_ORDER_LOCKED( VBAK-VBELN ) = ABAP_TRUE
     AND NEW ZCL_SD_SO_RELEASE( )->IS_MANAGED( VBAK-VBELN ) = ABAP_FALSE.
```
**Find:**
```abap
  LEAVE TO TRANSACTION 'VA03' AND SKIP FIRST SCREEN.
```
**Insert after it:**
```abap
  ENDIF.                                                           "REQ1
```

---

## C. YSDA – module pool `YSP_MTOSO_APPROVE`

### Include `YSP_MTOSO_APPROVE_SCREEN_STF01`, FORM `SCREEN_START`

#### C1 – INSERT AFTER (hide items already approved by SD + FI)
**Find** (end of the big SELECT ... ENDSELECT statement):
```abap
     AND vbak~audat >= datev_f AND vbak~audat <= datev_t.
"vbap~absta <> 'C'
```
**Insert between these two lines:**
```abap
      "REQ1: item already approved by SD and FI - it stays CN while the
      "      credit workflow runs, but must not be shown again
      SELECT SINGLE @abap_true FROM zsoapproval
        WHERE vbeln      = @so_wa-so_num
          AND posnr      = @so_wa-posnr
          AND sd_approve = 'X'
          AND fi_approve = 'X'
        INTO @DATA(lv_rel_approved).
      IF sy-subrc = 0.
        CLEAR: so_wa, lv_rel_approved.
        CONTINUE.
      ENDIF.
```

### Include `YSP_MTOSO_APPROVE_APPROVE_FF01`, FORM `APPROVE_FUN`

#### C2 – INSERT AFTER (clean BAPI tables per selected row)
**Find:**
```abap
  LOOP AT IT_PROG_ROW_INDEX INTO WA_PROG_ROW_INDEX.
    READ TABLE SO_TAB INTO SO_WA INDEX WA_PROG_ROW_INDEX-INDEX.
```
**Insert after it:**
```abap
    "REQ1: every selected row starts clean (the header-line tables kept the
    "      lines of the previous row and sent them again)
    REFRESH: ORDER_ITEM_IN, ORDER_ITEM_INX, LT_SCHDL, LT_SCHDLX, LT_RETURN.
    CLEAR:   ORDER_ITEM_IN, ORDER_ITEM_INX, LT_SCHDL, LT_SCHDLX,
             ORDER_HEADER_INX, WA_LOG, SD_APPROVE, FI_APPROVE.
```

#### C3 – DELETE (FI approval alone must not set CP any more)
In the `ELSEIF ZPOSNUM = 'FI'.` branch, under `" added by hager mohsen 24.12.2024 Support Task T00005055`,
**find and delete** these lines (keep the Z8 clearing above them):
```abap
      SELECT ETENR FROM VBEP INTO ( LT_SCHDL-SCHED_LINE )
        WHERE VBELN = SO_WA-SO_NUM AND POSNR = SO_WA-POSNR AND WMENG > 0.
        LT_SCHDL-ITM_NUMBER = SO_WA-POSNR.
        LT_SCHDL-SCHED_TYPE = 'CP'.
        APPEND LT_SCHDL.
        LT_SCHDLX-ITM_NUMBER =  SO_WA-POSNR .
        LT_SCHDLX-SCHED_LINE = LT_SCHDL-SCHED_LINE.
        LT_SCHDLX-UPDATEFLAG = 'U'.
        LT_SCHDLX-SCHED_TYPE  = 'X'.
        APPEND  LT_SCHDLX.
      ENDSELECT.
```

#### C4 – REPLACE (same BAPI call in the FI branch)
**Find:**
```abap
            ORDER_ITEM_INX   = ORDER_ITEM_INX
             SCHEDULE_LINES   = LT_SCHDL
          SCHEDULE_LINESX  = LT_SCHDLX.
```
**Replace with:**
```abap
            ORDER_ITEM_INX   = ORDER_ITEM_INX.     "REQ1: no schedule line change
```

#### C5 – INSERT BEFORE / INSERT AFTER (both approvals done)
**Find:**
```abap
    IF SD_APPROVE = 'X' AND FI_APPROVE = 'X'.


      ORDER_HEADER_INX-UPDATEFLAG = 'U'.
```
**Insert between `IF SD_APPROVE ...` and `ORDER_HEADER_INX-UPDATEFLAG = 'U'.`:**
```abap
      "REQ1: production order of the release cycle -> the cycle decides
      "      (this item CN -> CP now, or after the credit workflow)
      DATA(LO_RELEASE) = NEW ZCL_SD_SO_RELEASE( ).
      IF LO_RELEASE->ON_ITEM_DECISION( SO_WA-SO_NUM ) = ABAP_TRUE.
        WA_LOG-NOTE = LO_RELEASE->GET_ITEM_STATUS_TEXT( IV_VBELN = SO_WA-SO_NUM
                                                        IV_POSNR = SO_WA-POSNR ).
        MESSAGE |{ SO_WA-SO_NUM ALPHA = OUT }/{ SO_WA-POSNR ALPHA = OUT }: { WA_LOG-NOTE }| TYPE 'S'.
      ELSE.
      "order not in the release cycle: old logic below
```
**Then find** (end of the V1 message loop, just before `*INSERT LOG`):
```abap
      LOOP AT LT_RETURN WHERE ID = 'V1'.
        MESSAGE LT_RETURN-MESSAGE(100) TYPE 'I'.
        WA_LOG-NOTE = LT_RETURN-MESSAGE(100).
      ENDLOOP.
*INSERT LOG
```
**Insert between `ENDLOOP.` and `*INSERT LOG`:**
```abap
      ENDIF.                                                       "REQ1
```

### Include `YSP_MTOSO_APPROVE_REJECT_FUF01`, FORM `REJECT_FUN`

#### C6 – INSERT AFTER (clean BAPI tables per selected row)
**Find** (the DATA block inside the loop):
```abap
        ORDER_ITEM_IN	TYPE TABLE OF	BAPISDITM WITH HEADER LINE,
        ORDER_ITEM_INX  TYPE TABLE OF BAPISDITMX WITH HEADER LINE.
```
**Insert after it:**
```abap
   "REQ1: every selected row starts clean
   REFRESH: ORDER_ITEM_IN, ORDER_ITEM_INX, LT_RETURN.
   CLEAR:   ORDER_ITEM_IN, ORDER_ITEM_INX, ORDER_HEADER_INX, WA_LOG.
```

#### C7 – INSERT AFTER (tell the release cycle)
**Find:**
```abap
  LOOP AT lt_return.
  MESSAGE lt_return-message(100) TYPE 'I'.
  WA_LOG-NOTE = lt_return-message(100).
  ENDLOOP.
```
**Insert after it:**
```abap
  "REQ1: item rejected - if it was the last open item of a blocked order,
  "      the credit workflow starts for the approved items
  NEW ZCL_SD_SO_RELEASE( )->ON_ITEM_DECISION( SO_WA-SO_NUM ).
```

---

## D. YSDAX – module pool `YSP_MTOSO_APPROVE_CX`

### Include `YSP_MTOSO_APP_SCREEN_STF01_CX`, FORM `SCREEN_START`

#### D1 – INSERT AFTER
**Find** (end of the big SELECT ... ENDSELECT statement):
```abap
      AND VBAK~AUDAT >= DATEV_F AND VBAK~AUDAT <= DATEV_T.
```
**Insert after it** (before the comment `*1)	Select Cost estimate number (KALNR) ...`):
```abap
      "REQ1: item already approved by SD and FI - it stays CN while the
      "      credit workflow runs, but must not be shown again
      SELECT SINGLE @ABAP_TRUE FROM ZSOAPPROVAL
        WHERE VBELN      = @SO_WA-SO_NUM
          AND POSNR      = @SO_WA-POSNR
          AND SD_APPROVE = 'X'
          AND FI_APPROVE = 'X'
        INTO @DATA(LV_REL_APPROVED).
      IF SY-SUBRC = 0.
        CLEAR: SO_WA, LV_REL_APPROVED.
        CONTINUE.
      ENDIF.
```

### Include `YSP_MTOSO_APPROVE_FF01_CX`, FORM `APPROVE_FUN`

#### D2 – INSERT AFTER
**Find:**
```abap
  LOOP AT IT_PROG_ROW_INDEX INTO WA_PROG_ROW_INDEX.
    READ TABLE SO_TAB INTO SO_WA INDEX WA_PROG_ROW_INDEX-INDEX.
```
**Insert after it:**
```abap
    CLEAR: SD_APPROVE, FI_APPROVE, WA_LOG.                          "REQ1
```

#### D3 – INSERT (both approvals done)
**Find** (inside `IF SD_APPROVE = 'X' AND FI_APPROVE = 'X'.`):
```abap
             LT_SCHDLX        TYPE TABLE OF BAPISCHDLX WITH HEADER LINE.
      ORDER_HEADER_INX-UPDATEFLAG = 'U'.
```
**Insert between the DATA block and `ORDER_HEADER_INX-UPDATEFLAG = 'U'.`:**
```abap
      "REQ1: every selected row starts clean
      REFRESH: LT_SCHDL, LT_SCHDLX, LT_RETURN.
      CLEAR:   LT_SCHDL, LT_SCHDLX, ORDER_HEADER_INX.

      "REQ1: production order of the release cycle -> the cycle decides
      "      (this item CN -> CP now, or after the credit workflow)
      DATA(LO_RELEASE) = NEW ZCL_SD_SO_RELEASE( ).
      IF LO_RELEASE->ON_ITEM_DECISION( SO_WA-SO_NUM ) = ABAP_TRUE.
        WA_LOG-NOTE = LO_RELEASE->GET_ITEM_STATUS_TEXT( IV_VBELN = SO_WA-SO_NUM
                                                        IV_POSNR = SO_WA-POSNR ).
        MESSAGE |{ SO_WA-SO_NUM ALPHA = OUT }/{ SO_WA-POSNR ALPHA = OUT }: { WA_LOG-NOTE }| TYPE 'S'.
      ELSE.
      "order not in the release cycle: old logic below
```

#### D4 – INSERT
**Find** (end of the V1 message loop, just before `*INSERT LOG`):
```abap
      LOOP AT LT_RETURN WHERE ID = 'V1'.
        MESSAGE LT_RETURN-MESSAGE(100) TYPE 'I'.
        WA_LOG-NOTE = LT_RETURN-MESSAGE(100).
      ENDLOOP.
*INSERT LOG
```
**Insert between `ENDLOOP.` and `*INSERT LOG`:**
```abap
      ENDIF.                                                       "REQ1
```

### Include `YSP_MTOSO_APP_REJECT_FUF01_CX`, FORM `REJECT_FUN`

#### D5 – INSERT AFTER
**Find** (the DATA block inside the loop):
```abap
        ORDER_ITEM_IN	TYPE TABLE OF	BAPISDITM WITH HEADER LINE,
        ORDER_ITEM_INX  TYPE TABLE OF BAPISDITMX WITH HEADER LINE.
```
**Insert after it:**
```abap
   "REQ1: every selected row starts clean
   REFRESH: ORDER_ITEM_IN, ORDER_ITEM_INX, LT_RETURN.
   CLEAR:   ORDER_ITEM_IN, ORDER_ITEM_INX, ORDER_HEADER_INX, WA_LOG.
```

#### D6 – INSERT AFTER
**Find:**
```abap
  LOOP AT lt_return.
  MESSAGE lt_return-message(100) TYPE 'I'.
  WA_LOG-NOTE = lt_return-message(100).
  ENDLOOP.
```
**Insert after it:**
```abap
  "REQ1: item rejected - if it was the last open item of a blocked order,
  "      the credit workflow starts for the approved items
  NEW ZCL_SD_SO_RELEASE( )->ON_ITEM_DECISION( SO_WA-SO_NUM ).
```

---

## E. Workflow `WS99000010`
No code change in the existing workflow classes. Three new background steps – see
`WS99000010_workflow_changes.md`.

---

## F. Class `ZCL_WF_SD_ALERT`, method `BUILD_HTML` (SE24)

The approver sees, for every production line, the YSDA/YSDAX decision and what happens at the final
approval (CN → CP or stays CN).

### F1 – INSERT BEFORE
**Find:**
```abap
    "--- your step ----------------------------------------------------
    APPEND LINES OF LO_HTML->SECTION_TITLE( 'Your Approval Step' ) TO RT_HTML.
```
**Insert before it:**
```abap
    "--- REQ1: order lines - YSDA/YSDAX decision and release plan ------
    DATA(LT_PLAN) = NEW ZCL_SD_SO_RELEASE( )->GET_RELEASE_PLAN( LS-VBELN ).

    IF LT_PLAN IS NOT INITIAL.

      APPEND LINES OF LO_HTML->SECTION_TITLE( 'Order Lines' ) TO RT_HTML.

      APPEND LINES OF LO_HTML->TABLE_OPEN( VALUE #( ( `Item` ) ( `Material` ) ( `Description` )
                                                    ( `Quantity` ) ( `YSDA / YSDAX` )
                                                    ( `At final approval` ) ) ) TO RT_HTML.

      LOOP AT LT_PLAN INTO DATA(LS_PLAN).
        APPEND LINES OF LO_HTML->DATA_ROW(
          IT_CELL = VALUE #(
            ( TEXT = |{ LS_PLAN-POSNR ALPHA = OUT }| )
            ( TEXT = |{ LS_PLAN-MATNR ALPHA = OUT }| )
            ( TEXT = CONV STRING( LS_PLAN-ARKTX ) )
            ( TEXT = |{ LS_PLAN-KWMENG NUMBER = USER } { LS_PLAN-VRKME }| ALIGN = 'right' )
            ( TEXT = LS_PLAN-DECISION )
            ( TEXT  = LS_PLAN-TARGET
              BOLD  = ABAP_TRUE
              COLOR = COND #( WHEN LS_PLAN-TO_PRODUCTION = ABAP_TRUE
                              THEN ZCL_MAIL_HTML=>GC_COLOUR-GREEN
                              ELSE ZCL_MAIL_HTML=>GC_COLOUR-RED ) ) ) ) TO RT_HTML.
      ENDLOOP.

      APPEND LINES OF LO_HTML->TABLE_CLOSE( ) TO RT_HTML.

    ENDIF.
    "--- end REQ1 ----------------------------------------------------------
```

---

## Check after applying

1. Activate in this order: new DDIC → `Z_SD_SO_REL_UPDATE` → `ZCL_SD_SO_RELEASE` + `ZCL_WF_SD_CREDIT` (together)
   → `ZCL_WF_SD_SO_REL_STEP` → MV45AFZZ → YSDA → YSDAX.
2. Syntax check of `SAPMV45A` (all enhancements) and of both module pools.
3. Search each object for `"REQ1` – every marked line must be there:
   - A: 1 block
   - B: B1–B8
   - C: C1–C7
   - D: D1–D6
   - F: F1
