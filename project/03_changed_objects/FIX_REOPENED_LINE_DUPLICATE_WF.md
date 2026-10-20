# Fix: rejected line reopened in VA02 → two credit workflows

Scenario: order with line 10 approved (CP) and line 20 rejected (63, stays CN); YSDA and WS99000010
finished. User removes the rejection of line 20 in VA02 → workflow 1 starts from VA02 → line 20 shows in
YSDA → approver decides → workflow 2 starts → two work items.

Target behaviour: VA02 starts **no** workflow; the line goes back to YSDA/YSDAX; after the YSDA/YSDAX
decision **exactly one** workflow starts.

## 1. ZCL_SD_SO_RELEASE – PRIVATE SECTION (new attribute)

```abap
    DATA MV_IN_WORKFLOW TYPE ABAP_BOOL.
    CLASS-DATA GV_OWN_START TYPE ABAP_BOOL.
```

## 2. ZCL_SD_SO_RELEASE – ON_ORDER_SAVED (whole method)

```abap
  METHOD ON_ORDER_SAVED.

    CHECK IS_ORDER-VBELN IS NOT INITIAL.

    DATA(LS_HDR) = READ_HEADER( IS_ORDER-VBELN ).

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

    LOOP AT LT_ITM ASSIGNING FIELD-SYMBOL(<LS_REOPEN>)
         WHERE PROD_RELEVANT = ABAP_TRUE
           AND COST_STATUS   = GC_COST-REJECTED.

      READ TABLE IT_ITEMS INTO DATA(LS_VBAP) WITH KEY POSNR = <LS_REOPEN>-POSNR.
      CHECK SY-SUBRC = 0
        AND LS_VBAP-UPDKZ <> 'D'
        AND ( LS_VBAP-ABGRU IS INITIAL OR LS_VBAP-ABGRU = GC_REJ_AUTO ).

      <LS_REOPEN>-COST_STATUS = GC_COST-PENDING.
      <LS_REOPEN>-PROD_STATUS = GC_PROD-BLOCKED.
      CLEAR: <LS_REOPEN>-REL_PLAN,     <LS_REOPEN>-COST_DONE_ON,
             <LS_REOPEN>-DECIDED_BY,   <LS_REOPEN>-DECIDED_ON,
             <LS_REOPEN>-DECIDED_AT,   <LS_REOPEN>-REJ_ABGRU.

      LV_SAVE = ABAP_TRUE.
      LV_NOTE = |Item { <LS_REOPEN>-POSNR ALPHA = OUT } rejection removed, waiting for YSDA/YSDAX again|.

    ENDLOOP.

    IF LS_HDR-CREDIT_STATUS = GC_CREDIT-APPROVED.

      DATA LV_REASON TYPE STRING.

      IF IS_CREDIT_RELEVANT_CHANGE( EXPORTING IS_ORDER  = IS_ORDER
                                              IT_ITEMS  = IT_ITEMS
                                    IMPORTING EV_REASON = LV_REASON ) = ABAP_TRUE.
        LS_HDR-CREDIT_STATUS = GC_CREDIT-OPEN.
        CLEAR LS_HDR-WI_ID.
        LV_EVENT = 'RESTART'.
        LV_NOTE  = LV_REASON.
        LV_SAVE  = ABAP_TRUE.
      ENDIF.

    ENDIF.

    CHECK LV_SAVE = ABAP_TRUE.

    SAVE( IS_HDR   = LS_HDR
          IT_ITEMS = LT_ITM
          IV_EVENT = LV_EVENT
          IV_NOTE  = LV_NOTE ).

  ENDMETHOD.
```

## 3. ZCL_SD_SO_RELEASE – CAN_START_CREDIT_WF (whole method)

```abap
  METHOD CAN_START_CREDIT_WF.

    DATA(LS_HDR) = READ_HEADER( IV_VBELN ).

    IF LS_HDR IS INITIAL.
      RV_START = GC_START-UNMANAGED.
      RETURN.
    ENDIF.

    RV_START = COND #(
      WHEN LS_HDR-OVERALL_STATUS = GC_OVERALL-DELETED    THEN GC_START-NO
      WHEN LS_HDR-COST_STATUS   <> GC_COST-APPROVED      THEN GC_START-NO
      WHEN LS_HDR-CREDIT_STATUS  = GC_CREDIT-REJECTED    THEN GC_START-NO
      WHEN LS_HDR-CREDIT_STATUS  = GC_CREDIT-APPROVED    THEN GC_START-NO
      WHEN ( LS_HDR-CREDIT_STATUS = GC_CREDIT-WAITING
          OR LS_HDR-CREDIT_STATUS = GC_CREDIT-IN_APPROVAL )
       AND GV_OWN_START = ABAP_FALSE                     THEN GC_START-NO
      ELSE                                                    GC_START-YES ).

  ENDMETHOD.
```

## 4. ZCL_SD_SO_RELEASE – RAISE_START_EVENT (whole method)

```abap
  METHOD RAISE_START_EVENT.

    DATA LV_RC    TYPE SY-SUBRC.
    DATA LV_WI_ID TYPE SWR_STRUCT-WORKITEMID.
    DATA LV_START TYPE ABAP_BOOL.
    DATA LT_CONT  TYPE STANDARD TABLE OF SWR_CONT.
    DATA LT_MSG   TYPE STANDARD TABLE OF SWR_MESSAG.

    DATA(LS_HDR) = READ_HEADER( IV_VBELN ).
    CHECK LS_HDR IS NOT INITIAL.

    GV_OWN_START = ABAP_TRUE.
    TRY.
        LV_START = NEW ZCL_WF_SD_CREDIT( )->IS_START_ALLOWED( IV_VBELN ).
      CATCH ZCX_WF_SD.
        CLEAR LV_START.
    ENDTRY.
    GV_OWN_START = ABAP_FALSE.

    IF LV_START = ABAP_FALSE.
      SAVE( IS_HDR   = LS_HDR
            IT_ITEMS = READ_ITEMS( IV_VBELN )
            IV_EVENT = 'EVENT_ERR'
            IV_NOTE  = |WS99000010 not started: start check (IS_START_ALLOWED) not passed| ).
      COMMIT WORK.
      RETURN.
    ENDIF.

    SELECT SINGLE KUNNR FROM VBAK
      WHERE VBELN = @IV_VBELN
      INTO @DATA(LV_KUNNR).

    DATA(LS_BOR) = VALUE SWOTOBJID( OBJTYPE = 'BUS2032'
                                    OBJKEY  = IV_VBELN ).

    LT_CONT = VALUE #(
      ( ELEMENT = 'SALES_ORDER_BOR'
        VALUE   = LS_BOR )
      ( ELEMENT = 'SALES_ORDER'      VALUE = IV_VBELN )
      ( ELEMENT = 'BUSINESS_PARTNER' VALUE = LV_KUNNR ) ).

    CALL FUNCTION 'SAP_WAPI_START_WORKFLOW'
      EXPORTING
        TASK            = CONV SWR_STRUCT-TASK( 'WS99000010' )
        DO_COMMIT       = ABAP_TRUE
        USER            = SY-UNAME
      IMPORTING
        RETURN_CODE     = LV_RC
        WORKITEM_ID     = LV_WI_ID
      TABLES
        INPUT_CONTAINER = LT_CONT
        MESSAGE_LINES   = LT_MSG.

    DATA(LV_MSG) = REDUCE STRING( INIT LV_TXT = ``
                                  FOR LS_MSG IN LT_MSG
                                  NEXT LV_TXT = COND #( WHEN LV_TXT IS INITIAL THEN CONV STRING( LS_MSG-LINE )
                                                        ELSE |{ LV_TXT } / { LS_MSG-LINE }| ) ).
    SAVE( IS_HDR   = LS_HDR
          IT_ITEMS = READ_ITEMS( IV_VBELN )
          IV_EVENT = COND #( WHEN LV_RC = 0 THEN 'EVENT' ELSE 'EVENT_ERR' )
          IV_NOTE  = COND #( WHEN LV_RC = 0
                             THEN |WS99000010 started (work item { LV_WI_ID ALPHA = OUT }) by { SY-UNAME } ({ SY-TCODE })|
                             ELSE |WS99000010 not started (rc { LV_RC }): { LV_MSG }| ) ).
    COMMIT WORK.

  ENDMETHOD.
```
