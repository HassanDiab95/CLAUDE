*======================================================================*
* ZCL_WF_SD_CREDIT -> IS_START_ALLOWED   (SE24, method)
* REPLACE the whole method. Called by the check function module
* Z_FM_SD_WF_CHECK_CREDIT of the BUS2032 CREATED / CHANGED linkages
* of WS99000010 (no change in the function module itself).
* DRAFT - not compiled / not tested in SAP
*======================================================================*
* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_SD_CREDIT->IS_START_ALLOWED
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_VBELN                       TYPE        VBELN_VA
* | [<-()] RV_START                       TYPE        ABAP_BOOL
* | [!CX!] ZCX_WF_SD
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD IS_START_ALLOWED.

    DATA LV_ERDAT    TYPE ERDAT.
    DATA LV_START_ON TYPE DATS.
    DATA LV_BLOCK    TYPE CHAR1.

    CLEAR RV_START.

    IF IV_VBELN IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE ERDAT FROM VBAK
      WHERE VBELN = @IV_VBELN
      INTO @LV_ERDAT.

    IF SY-SUBRC <> 0.
      RAISE EXCEPTION TYPE ZCX_WF_SD
        EXPORTING
          TEXTID   = ZCX_WF_SD=>ORDER_NOT_FOUND
          IV_ATTR1 = IV_VBELN.
    ENDIF.

    LV_START_ON = GET_WF_START_DATE( ).

    IF LV_START_ON IS NOT INITIAL AND LV_ERDAT < LV_START_ON.
      RETURN.
    ENDIF.

    "--- REQ1 release cycle --------------------------------------------
    " production orders: every item decided in YSDA / YSDAX first,
    " only one workflow at a time, no new start after approval/rejection
    " (a credit relevant order change re-opens it)
    IF NEW ZCL_SD_SO_RELEASE( )->CAN_START_CREDIT_WF( IV_VBELN )
       = ZCL_SD_SO_RELEASE=>GC_START-NO.
      RETURN.
    ENDIF.
    "--- end REQ1 -------------------------------------------------------

    LV_BLOCK = CHECK_SO_BLOCK( IV_VBELN ).

    RV_START = XSDBOOL( LV_BLOCK = 'X' ).

  ENDMETHOD.
