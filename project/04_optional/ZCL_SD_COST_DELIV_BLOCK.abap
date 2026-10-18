*&---------------------------------------------------------------------*
*& Object Name    : ZCL_SD_COST_DELIV_BLOCK
*& Object Type    : Class
*& Package        : ZSD
*&---------------------------------------------------------------------*
*& Purpose        : Delivery block 80 when the item cost difference
*&                   (ZOVC + ZBPC + WAVWR - ZPRO) is higher than the
*&                   approved difference in VBAP-WRF_CHARSTC1, and the
*&                   screen locks that go with it.
*&                   Replaces the logic of the MV45AFZZ enhancements
*&                   ZDLIVERY_BLOCK (USEREXIT_MOVE_FIELD_TO_VBAK) and
*&                   ZSD_DELIVERY_BLOCK_DIMMED (USEREXIT_FIELD_MODIFICATION).
*& Tables         : ZORDER_CHECK      block log per order item
*&                   ZUSER_DELV_BLOCK  users allowed to change block 80
*&---------------------------------------------------------------------*
*& Status         : DRAFT - not compiled / not tested in SAP
*&---------------------------------------------------------------------*
CLASS ZCL_SD_COST_DELIV_BLOCK DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    TYPES: BEGIN OF TY_S_ITEM,
             POSNR        TYPE VBAP-POSNR,
             BEDAE        TYPE VBAP-BEDAE,
             LFSTA        TYPE VBAP-LFSTA,
             WAVWR        TYPE VBAP-WAVWR,
             WRF_CHARSTC1 TYPE VBAP-WRF_CHARSTC1,
           END OF TY_S_ITEM.
    TYPES TT_ITEM TYPE STANDARD TABLE OF TY_S_ITEM WITH EMPTY KEY.

    TYPES: BEGIN OF TY_S_COND,
             KPOSN TYPE KOMV-KPOSN,
             KSCHL TYPE KOMV-KSCHL,
             KWERT TYPE KOMV-KWERT,
           END OF TY_S_COND.
    TYPES TT_COND TYPE STANDARD TABLE OF TY_S_COND WITH EMPTY KEY.

    CONSTANTS GC_BLOCK TYPE LIFSK VALUE '80'.

    CONSTANTS: BEGIN OF GC_FLAG,
                 EXIST     TYPE ZORDER_CHECK-COST_PERSON_FLAG VALUE 'EXIST',
                 NOT_EXIST TYPE ZORDER_CHECK-COST_PERSON_FLAG VALUE 'NEXST',
               END OF GC_FLAG.

    CONSTANTS: BEGIN OF GC_ORIGIN,
                 COST     TYPE ZORDER_CHECK-FROM_COST  VALUE 'COST',
                 NOT_COST TYPE ZORDER_CHECK-FROM_COST  VALUE 'NCST',
                 SALES    TYPE ZORDER_CHECK-FROM_SALES VALUE 'SALE',
                 NOT_SALE TYPE ZORDER_CHECK-FROM_SALES VALUE 'NSAL',
               END OF GC_ORIGIN.

    CLASS-METHODS CLASS_CONSTRUCTOR.

    "! One instance per internal session (the exits are called many times)
    CLASS-METHODS GET_INSTANCE
      RETURNING VALUE(RO_INSTANCE) TYPE REF TO ZCL_SD_COST_DELIV_BLOCK.

    "! USEREXIT_MOVE_FIELD_TO_VBAK - set / keep delivery block 80
    METHODS APPLY_COST_BLOCK
      IMPORTING IV_TCODE      TYPE SY-TCODE
                IV_VKORG      TYPE VKORG
                IV_VBELN      TYPE VBELN_VA
                IV_LFSTK      TYPE LFSTK
                IT_ITEMS      TYPE TT_ITEM
                IT_CONDITIONS TYPE TT_COND
      CHANGING  CV_LIFSK      TYPE LIFSK.

    "! USEREXIT_FIELD_MODIFICATION - true = make the field display only
    METHODS IS_FIELD_LOCKED
      IMPORTING IV_FIELD         TYPE CSEQUENCE
                IV_TCODE         TYPE SY-TCODE
                IV_VBELN         TYPE VBELN_VA
                IV_LIFSK         TYPE LIFSK
      RETURNING VALUE(RV_LOCKED) TYPE ABAP_BOOL.

    "! USEREXIT_SAVE_DOCUMENT - write the ZORDER_CHECK changes with the
    "! order (no COMMIT WORK here, the order save commits)
    METHODS SAVE.

    "! USEREXIT_REFRESH_DOCUMENT - forget the buffer of the last order
    METHODS REFRESH.

  PRIVATE SECTION.

    TYPES TT_CHECK TYPE SORTED TABLE OF ZORDER_CHECK
                   WITH UNIQUE KEY SALES_ORDER LINE_ITEM.

    CLASS-DATA GO_INSTANCE    TYPE REF TO ZCL_SD_COST_DELIV_BLOCK.
    CLASS-DATA GR_BEDAE       TYPE RANGE OF BEDAE.
    CLASS-DATA GR_VKORG_STD   TYPE RANGE OF VKORG.
    CLASS-DATA GR_VKORG_PRIV  TYPE RANGE OF VKORG.

    DATA MV_PRIVILEGED TYPE ABAP_BOOL.
    DATA MT_CHECK      TYPE TT_CHECK.   " DB rows + changes not yet saved
    DATA MT_PENDING    TYPE TT_CHECK.   " changes to write at save
    DATA MT_LOADED     TYPE SORTED TABLE OF VBELN_VA WITH UNIQUE KEY TABLE_LINE.

    METHODS CONSTRUCTOR.

    METHODS APPLY_STANDARD
      IMPORTING IV_VBELN      TYPE VBELN_VA
                IT_ITEMS      TYPE TT_ITEM
                IT_CONDITIONS TYPE TT_COND
      CHANGING  CV_LIFSK      TYPE LIFSK.

    METHODS APPLY_PRIVILEGED
      IMPORTING IV_VBELN      TYPE VBELN_VA
                IT_ITEMS      TYPE TT_ITEM
                IT_CONDITIONS TYPE TT_COND
      CHANGING  CV_LIFSK      TYPE LIFSK.

    METHODS COST_EXCEEDED
      IMPORTING IS_ITEM          TYPE TY_S_ITEM
                IT_CONDITIONS    TYPE TT_COND
      RETURNING VALUE(RV_EXCEED) TYPE ABAP_BOOL.

    METHODS APPROVED_DIFFERENCE
      IMPORTING IV_TEXT          TYPE VBAP-WRF_CHARSTC1
      RETURNING VALUE(RV_AMOUNT) TYPE KOMV-KWERT.

    METHODS LOAD
      IMPORTING IV_VBELN TYPE VBELN_VA.

    METHODS READ_CHECK
      IMPORTING IV_VBELN        TYPE VBELN_VA
                IV_POSNR        TYPE POSNR_VA
      RETURNING VALUE(RS_CHECK) TYPE ZORDER_CHECK.

    METHODS PUT_CHECK
      IMPORTING IS_CHECK TYPE ZORDER_CHECK.

ENDCLASS.



CLASS ZCL_SD_COST_DELIV_BLOCK IMPLEMENTATION.


  METHOD CLASS_CONSTRUCTOR.

    " requirement types of make-to-order items
    GR_BEDAE = VALUE #( SIGN = 'I' OPTION = 'EQ'
                        ( LOW = '011' )  ( LOW = '021' )  ( LOW = '031' )
                        ( LOW = '041' )  ( LOW = 'LSF' )  ( LOW = 'LCO' )
                        ( LOW = 'MSR' )  ( LOW = 'KSL' )  ( LOW = 'KSV' )
                        ( LOW = 'KE' )   ( LOW = 'KEB' )  ( LOW = 'KEVV' )
                        ( LOW = 'KSVS' ) ( LOW = 'KSVV' ) ).

    " sales orgs checked for normal users
    GR_VKORG_STD = VALUE #( SIGN = 'I' OPTION = 'EQ'
                            ( LOW = '1200' ) ( LOW = '1300' ) ( LOW = '1400' )
                            ( LOW = '1500' ) ( LOW = '1600' ) ( LOW = '1700' ) ).

    " sales orgs checked for users in ZUSER_DELV_BLOCK
    GR_VKORG_PRIV = VALUE #( SIGN = 'I' OPTION = 'EQ'
                             ( LOW = '1300' ) ( LOW = '1400' ) ( LOW = '1500' ) ).

  ENDMETHOD.


  METHOD GET_INSTANCE.

    IF GO_INSTANCE IS NOT BOUND.
      GO_INSTANCE = NEW #( ).
    ENDIF.

    RO_INSTANCE = GO_INSTANCE.

  ENDMETHOD.


  METHOD CONSTRUCTOR.

    SELECT SINGLE @ABAP_TRUE
      FROM ZUSER_DELV_BLOCK
      WHERE USER_NAME = @SY-UNAME
      INTO @MV_PRIVILEGED.

  ENDMETHOD.


  METHOD APPLY_COST_BLOCK.

    CHECK IV_LFSTK <> 'C'
      AND IV_TCODE = 'VA02'
      AND IV_VBELN IS NOT INITIAL.

    IF MV_PRIVILEGED = ABAP_FALSE.

      CHECK IV_VKORG IN GR_VKORG_STD.

      APPLY_STANDARD( EXPORTING IV_VBELN      = IV_VBELN
                                IT_ITEMS      = IT_ITEMS
                                IT_CONDITIONS = IT_CONDITIONS
                      CHANGING  CV_LIFSK      = CV_LIFSK ).

    ELSE.

      CHECK IV_VKORG IN GR_VKORG_PRIV.

      APPLY_PRIVILEGED( EXPORTING IV_VBELN      = IV_VBELN
                                  IT_ITEMS      = IT_ITEMS
                                  IT_CONDITIONS = IT_CONDITIONS
                        CHANGING  CV_LIFSK      = CV_LIFSK ).

    ENDIF.

  ENDMETHOD.


  METHOD APPLY_STANDARD.

    " normal user: block 80 for every open item over the approved
    " difference, until the cost person releases it
    LOOP AT IT_ITEMS INTO DATA(LS_ITEM)
         WHERE BEDAE IN GR_BEDAE
           AND LFSTA <> 'C'.

      CHECK COST_EXCEEDED( IS_ITEM       = LS_ITEM
                           IT_CONDITIONS = IT_CONDITIONS ) = ABAP_TRUE.

      DATA(LS_CHECK) = READ_CHECK( IV_VBELN = IV_VBELN
                                   IV_POSNR = LS_ITEM-POSNR ).

      IF LS_CHECK IS INITIAL.

        CV_LIFSK = GC_BLOCK.

        PUT_CHECK( VALUE #( SALES_ORDER       = IV_VBELN
                            LINE_ITEM         = LS_ITEM-POSNR
                            STATUS            = CV_LIFSK
                            COST_PERSON_FLAG  = GC_FLAG-EXIST
                            SALES_PERSON_FLAG = GC_FLAG-NOT_EXIST
                            FROM_COST         = GC_ORIGIN-NOT_COST
                            FROM_SALES        = GC_ORIGIN-SALES ) ).

      ELSEIF LS_CHECK-COST_PERSON_FLAG = GC_FLAG-EXIST.

        CV_LIFSK = GC_BLOCK.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD APPLY_PRIVILEGED.

    " cost person: may set or remove block 80, the decision is logged
    LOOP AT IT_ITEMS INTO DATA(LS_ITEM)
         WHERE BEDAE IN GR_BEDAE.

      CHECK COST_EXCEEDED( IS_ITEM       = LS_ITEM
                           IT_CONDITIONS = IT_CONDITIONS ) = ABAP_TRUE.

      DATA(LS_CHECK) = READ_CHECK( IV_VBELN = IV_VBELN
                                   IV_POSNR = LS_ITEM-POSNR ).

      IF LS_CHECK IS INITIAL.

        CV_LIFSK = GC_BLOCK.

        PUT_CHECK( VALUE #( SALES_ORDER       = IV_VBELN
                            LINE_ITEM         = LS_ITEM-POSNR
                            STATUS            = CV_LIFSK
                            COST_PERSON_FLAG  = GC_FLAG-NOT_EXIST
                            SALES_PERSON_FLAG = GC_FLAG-NOT_EXIST
                            FROM_COST         = GC_ORIGIN-COST
                            FROM_SALES        = GC_ORIGIN-NOT_SALE ) ).
        CONTINUE.

      ENDIF.

      " another block than the logged one is not allowed
      IF CV_LIFSK <> LS_CHECK-STATUS AND CV_LIFSK IS NOT INITIAL.
        CV_LIFSK = LS_CHECK-STATUS.
      ENDIF.

      CASE CV_LIFSK.

        WHEN GC_BLOCK.
          LS_CHECK-COST_PERSON_FLAG  = GC_FLAG-EXIST.
          LS_CHECK-SALES_PERSON_FLAG = GC_FLAG-NOT_EXIST.
          LS_CHECK-STATUS            = CV_LIFSK.
          PUT_CHECK( LS_CHECK ).

        WHEN SPACE.
          " block removed by the cost person
          LS_CHECK-COST_PERSON_FLAG  = GC_FLAG-NOT_EXIST.
          LS_CHECK-SALES_PERSON_FLAG = GC_FLAG-NOT_EXIST.
          LS_CHECK-STATUS            = CV_LIFSK.
          PUT_CHECK( LS_CHECK ).

      ENDCASE.

    ENDLOOP.

  ENDMETHOD.


  METHOD COST_EXCEEDED.

    DATA LV_PRICE TYPE KOMV-KWERT.
    DATA LV_COST  TYPE KOMV-KWERT.

    LOOP AT IT_CONDITIONS INTO DATA(LS_COND)
         WHERE KPOSN = IS_ITEM-POSNR.

      CASE LS_COND-KSCHL.
        WHEN 'ZPRO'.
          LV_PRICE = LS_COND-KWERT.
        WHEN 'ZOVC' OR 'ZBPC'.
          LV_COST = LV_COST + LS_COND-KWERT.
      ENDCASE.

    ENDLOOP.

    LV_COST = LV_COST + IS_ITEM-WAVWR.

    RV_EXCEED = XSDBOOL( LV_COST - LV_PRICE
                         > APPROVED_DIFFERENCE( IS_ITEM-WRF_CHARSTC1 ) ).

  ENDMETHOD.


  METHOD APPROVED_DIFFERENCE.

    " ZSAVE_DIFF_COST_PROFIT stores the amount as user formatted text
    DATA(LV_TEXT) = CONV STRING( IV_TEXT ).
    CONDENSE LV_TEXT NO-GAPS.

    TRY.
        RV_AMOUNT = LV_TEXT.
      CATCH CX_SY_CONVERSION_ERROR.
        " not a number: treat as nothing approved -> item gets blocked
        RV_AMOUNT = 0.
    ENDTRY.

  ENDMETHOD.


  METHOD IS_FIELD_LOCKED.

    CHECK MV_PRIVILEGED = ABAP_FALSE.

    CASE IV_FIELD.

      WHEN 'VBAK-LIFSK'.
        " only a cost person may remove block 80
        RV_LOCKED = XSDBOOL( ( IV_TCODE = 'VA01' OR IV_TCODE = 'VA02' )
                             AND IV_LIFSK = GC_BLOCK ).

      WHEN 'RV45A-KWMENG'.
        " quantity is frozen once the cost person has released an item
        CHECK IV_TCODE = 'VA02' AND IV_VBELN IS NOT INITIAL.
        LOAD( IV_VBELN ).
        RV_LOCKED = XSDBOOL( LINE_EXISTS( MT_CHECK[ SALES_ORDER      = IV_VBELN
                                                    COST_PERSON_FLAG = GC_FLAG-NOT_EXIST ] ) ).

    ENDCASE.

  ENDMETHOD.


  METHOD SAVE.

    CHECK MT_PENDING IS NOT INITIAL.

    MODIFY ZORDER_CHECK FROM TABLE @MT_PENDING.

    CLEAR MT_PENDING.

  ENDMETHOD.


  METHOD REFRESH.

    CLEAR: MT_CHECK, MT_PENDING, MT_LOADED.

  ENDMETHOD.


  METHOD LOAD.

    CHECK NOT LINE_EXISTS( MT_LOADED[ TABLE_LINE = IV_VBELN ] ).

    SELECT *
      FROM ZORDER_CHECK
      WHERE SALES_ORDER = @IV_VBELN
      INTO TABLE @DATA(LT_DB).

    LOOP AT LT_DB INTO DATA(LS_DB).
      INSERT LS_DB INTO TABLE MT_CHECK.
    ENDLOOP.

    INSERT IV_VBELN INTO TABLE MT_LOADED.

  ENDMETHOD.


  METHOD READ_CHECK.

    LOAD( IV_VBELN ).

    RS_CHECK = VALUE #( MT_CHECK[ SALES_ORDER = IV_VBELN
                                  LINE_ITEM   = IV_POSNR ] OPTIONAL ).

  ENDMETHOD.


  METHOD PUT_CHECK.

    MODIFY TABLE MT_CHECK FROM IS_CHECK.
    IF SY-SUBRC <> 0.
      INSERT IS_CHECK INTO TABLE MT_CHECK.
    ENDIF.

    MODIFY TABLE MT_PENDING FROM IS_CHECK.
    IF SY-SUBRC <> 0.
      INSERT IS_CHECK INTO TABLE MT_PENDING.
    ENDIF.

  ENDMETHOD.
ENDCLASS.


*======================================================================*
* MV45AFZZ - the enhancements become one call each
*======================================================================*

* FORM USEREXIT_MOVE_FIELD_TO_VBAK
*ENHANCEMENT 1  ZDLIVERY_BLOCK.    "active version
*  ZCL_SD_COST_DELIV_BLOCK=>GET_INSTANCE( )->APPLY_COST_BLOCK(
*    EXPORTING IV_TCODE      = SY-TCODE
*              IV_VKORG      = VBAK-VKORG
*              IV_VBELN      = VBAK-VBELN
*              IV_LFSTK      = VBUK-LFSTK
*              IT_ITEMS      = CORRESPONDING #( XVBAP[] )
*              IT_CONDITIONS = CORRESPONDING #( XKOMV[] )
*    CHANGING  CV_LIFSK      = VBAK-LIFSK ).
*ENDENHANCEMENT.

* FORM USEREXIT_FIELD_MODIFICATION
*ENHANCEMENT 1  ZSD_DELIVERY_BLOCK_DIMMED.    "active version
*  IF ZCL_SD_COST_DELIV_BLOCK=>GET_INSTANCE( )->IS_FIELD_LOCKED(
*       IV_FIELD = SCREEN-NAME
*       IV_TCODE = SY-TCODE
*       IV_VBELN = VBAK-VBELN
*       IV_LIFSK = VBAK-LIFSK ) = ABAP_TRUE.
*    SCREEN-INPUT = 0.
*    MODIFY SCREEN.
*  ENDIF.
*ENDENHANCEMENT.

* FORM USEREXIT_SAVE_DOCUMENT (new enhancement)
*  ZCL_SD_COST_DELIV_BLOCK=>GET_INSTANCE( )->SAVE( ).

* FORM USEREXIT_REFRESH_DOCUMENT in MV45AFZA (new enhancement)
*  ZCL_SD_COST_DELIV_BLOCK=>GET_INSTANCE( )->REFRESH( ).
