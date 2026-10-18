*======================================================================*
* YSDA - module pool YSP_MTOSO_APPROVE - all changes for REQ1
* DRAFT - not compiled / not tested in SAP
*
* Approve / reject stay per line item, exactly as today. New: when an
* item is fully approved (SD + FI) or rejected, ZCL_SD_SO_RELEASE
* decides per item:
*   - order without credit block      -> this item CN -> CP now
*   - order with credit block         -> item stays CN; when every
*     production item of the order is approved or rejected, the credit
*     workflow starts; after its final approval all approved items CP
*   - order not in the release cycle  -> old logic (CN -> CP here)
*======================================================================*


*----------------------------------------------------------------------*
* CHANGE 1 - include YSP_MTOSO_APPROVE_SCREEN_STF01, FORM SCREEN_START
*            INSERT right after the end of the big SELECT statement,
*            i.e. after the line
*                AND vbak~audat >= datev_f AND vbak~audat <= datev_t.
*            and before the line
*                "vbap~absta <> 'C'
*----------------------------------------------------------------------*

      "REQ1: item already approved by SD and FI - it stays CN while the
      "      credit workflow runs, but must not be shown here again
      SELECT SINGLE @abap_true FROM zsoapproval
        WHERE vbeln      = @so_wa-so_num
          AND posnr      = @so_wa-posnr
          AND sd_approve = 'X'
          AND fi_approve = 'X'
        INTO @DATA(lv_rel_approved).
      IF sy-subrc = 0.
        CLEAR: so_wa, lv_rel_approved.   " the INTO list does not fill every field
        CONTINUE.
      ENDIF.
      "end REQ1


*----------------------------------------------------------------------*
* CHANGE 2 - include YSP_MTOSO_APPROVE_APPROVE_FF01
*            REPLACE the whole FORM APPROVE_FUN
*----------------------------------------------------------------------*
*-----------------------------------------------------------------------------*
* Modification history                                                        *
*-----------------------------------------------------------------------------*
* Date        |Request No  |Author             |Description                   *
*-----------------------------------------------------------------------------*
* 17/02/2021  |DE3K919734 |IABAPT [Heba] |SD Support "T00002246/CH1555"       *
* 23/11/2021  |DE3K921092 |IABAPT [Heba] |SD Support "T00002916/CH1970"       *
* <date>      |<request>  |<author>      |REQ1 release cycle: production      *
*             |           |              |release by ZCL_SD_SO_RELEASE, FI    *
*             |           |              |alone no longer sets CP, BAPI       *
*             |           |              |tables refreshed per row            *
*-----------------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& Form APPROVE_FUN
*&---------------------------------------------------------------------*
FORM APPROVE_FUN .
 DATA : ORDER_HEADER_INX TYPE BAPISDH1X,
        RETURN TYPE BAPIRET2,
        lt_schdl TYPE TABLE OF bapischdl WITH HEADER LINE,
        lt_return TYPE TABLE OF bapiret2 WITH HEADER LINE,
        lt_schdlx TYPE TABLE OF bapischdlx WITH HEADER LINE,
        ORDER_ITEM_IN	TYPE TABLE OF	BAPISDITM WITH HEADER LINE,
        ORDER_ITEM_INX  TYPE TABLE OF BAPISDITMX WITH HEADER LINE.
 DATA : LO_RELEASE TYPE REF TO ZCL_SD_SO_RELEASE.          "REQ1

  LO_RELEASE = NEW #( ).                                    "REQ1

  REFRESH : IT_PROG_ROW_INDEX.
  CALL METHOD GRID->GET_SELECTED_ROWS
    IMPORTING
      ET_INDEX_ROWS = IT_PROG_ROW_INDEX.
  DATA : ZPOSNUM(2) TYPE C.
  LOOP AT IT_PROG_ROW_INDEX INTO WA_PROG_ROW_INDEX.
    READ TABLE SO_TAB INTO SO_WA INDEX WA_PROG_ROW_INDEX-INDEX.

    "REQ1: each selected row starts with empty BAPI tables (before, the
    "      lines of the previous row were sent again)
    REFRESH: ORDER_ITEM_IN, ORDER_ITEM_INX, LT_SCHDL, LT_SCHDLX, LT_RETURN.
    CLEAR:   ORDER_ITEM_IN, ORDER_ITEM_INX, LT_SCHDL, LT_SCHDLX,
             ORDER_HEADER_INX, WA_LOG, SD_APPROVE, FI_APPROVE.


*--Added by Heba for Support Task 'T00002640/IN5492'...
      SELECT SINGLE ZPOSNUM FROM ZAPPROVEUSER INTO ZPOSNUM
                  WHERE USER_NAME = SY-UNAME
                   AND BUKRS = BUKRS.  "--Added by Heba for Support Task "T00002246/CH1555"
*--End Add...


    IF SY-SUBRC = 0.
      IF ZPOSNUM = 'SD'.
        SELECT * FROM ZSOAPPROVAL INTO CORRESPONDING FIELDS OF TABLE APPRV_TAB
                WHERE VBELN = SO_WA-SO_NUM AND POSNR = SO_WA-POSNR.
        IF SY-SUBRC = 0.
          LOOP AT APPRV_TAB INTO APPRV_WA .
            APPRV_WA-SD_APPROVE = 'X'.

*&--Added by Heba for Task 'T00002916 /CH1970'...
            "Set Approval Date and Time
            APPRV_WA-SD_APRV_DATE = SY-DATUM.
            APPRV_WA-SD_APRV_TIME = SY-UZEIT.
*&--End Add...

            MODIFY APPRV_TAB FROM APPRV_WA.
            MODIFY ZSOAPPROVAL FROM APPRV_WA.

*&--Added by Menna for Task 'T00003072/IN6038'...
          COMMIT WORK AND WAIT.
*&--End of edit by Menna for Task 'T00003072/IN6038'...

*&--Added by Heba for Task 'T00003072/IN6038'...
            "Commit the changes in the DB
            CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
              EXPORTING
                WAIT = 'X'.
*&--End Add...

            SD_APPROVE = 'X'.
          ENDLOOP.
        ENDIF.

      ELSEIF ZPOSNUM = 'FI'.

        SELECT * FROM ZSOAPPROVAL INTO CORRESPONDING FIELDS OF TABLE APPRV_TAB
                 WHERE VBELN = SO_WA-SO_NUM AND POSNR = SO_WA-POSNR.
        LOOP AT APPRV_TAB INTO APPRV_WA .
          APPRV_WA-FI_APPROVE = 'X'.

*&--Added by Heba for Task 'T00002916 /CH1970'...
            "Set Approval Date and Time
            APPRV_WA-FI_APRV_DATE = SY-DATUM.
            APPRV_WA-FI_APRV_TIME = SY-UZEIT.
*&--End Add...

          MODIFY APPRV_TAB FROM APPRV_WA.
          MODIFY ZSOAPPROVAL FROM APPRV_WA.
*&--Added by Menna for Task 'T00003072/IN6038'...
          COMMIT WORK AND WAIT.
           "Commit the changes in the DB
            CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
              EXPORTING
                WAIT = 'X'.
*&--End of edit by Menna for Task 'T00003072/IN6038'...

          FI_APPROVE = 'X'.
        ENDLOOP.

        " added by hager mohsen 24.12.2024 Support Task T00005055
        " REQ1: FI approval removes the automatic Z8 rejection of this
        "       item only. The schedule line stays CN - production is
        "       released when SD + FI (+ credit, if blocked) are done.
        IF APPRV_TAB IS NOT INITIAL.

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

          CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
            EXPORTING
              WAIT   = 'X'
            IMPORTING
              RETURN = RETURN.

        ENDIF.

      ENDIF.
    ELSE.

      MESSAGE 'You are not Authorized to Approve' TYPE 'W'.
*INSERT LOG

      WA_LOG-LOGDATE = SY-DATUM.
      WA_LOG-TIME = SY-UZEIT.
      WA_LOG-USER_NAME = SY-UNAME.
      WA_LOG-EVENT = 'not Authorized'.
      WA_LOG-SO_NUMBER = SO_WA-SO_NUM.
      SELECT COUNT(*) FROM YSP_MTOSO_LOG INTO LOG_COUNT .
      IF LOG_COUNT = 0.
        WA_LOG-LOG_NUMBER = 1.
      ELSE.
        WA_LOG-LOG_NUMBER = LOG_COUNT + 1.
      ENDIF.
      INSERT YSP_MTOSO_LOG FROM  WA_LOG.
      SD_APPROVE = ''.FI_APPROVE = ''.
    ENDIF.

    SELECT SINGLE SD_APPROVE FI_APPROVE FROM ZSOAPPROVAL
      INTO (SD_APPROVE , FI_APPROVE)
    WHERE VBELN = SO_WA-SO_NUM AND POSNR = SO_WA-POSNR.

    IF SD_APPROVE = 'X' AND FI_APPROVE = 'X'.

      "REQ1: production order of the release cycle -> the cycle decides
      "      (CN -> CP now, or after the credit workflow)
      IF LO_RELEASE->ON_ITEM_DECISION( SO_WA-SO_NUM ) = ABAP_TRUE.

        WA_LOG-NOTE = LO_RELEASE->GET_ITEM_STATUS_TEXT( IV_VBELN = SO_WA-SO_NUM
                                                        IV_POSNR = SO_WA-POSNR ).
        MESSAGE |{ SO_WA-SO_NUM ALPHA = OUT }/{ SO_WA-POSNR ALPHA = OUT }: { WA_LOG-NOTE }| TYPE 'S'.

      ELSE.

        "order not in the release cycle: release this item as before
        ORDER_HEADER_INX-UPDATEFLAG = 'U'.

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

        CALL FUNCTION 'BAPI_SALESORDER_CHANGE'  "#EC CI_USAGE_OK[2438131]
          EXPORTING
            SALESDOCUMENT    = SO_WA-SO_NUM
            ORDER_HEADER_INX = ORDER_HEADER_INX
          TABLES
            RETURN           = LT_RETURN
            SCHEDULE_LINES   = LT_SCHDL
            SCHEDULE_LINESX  = LT_SCHDLX.

        CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
          EXPORTING
            WAIT   = 'X'
          IMPORTING
            RETURN = RETURN.

        LOOP AT LT_RETURN WHERE ID = 'V1'.
          MESSAGE LT_RETURN-MESSAGE(100) TYPE 'I'.
          WA_LOG-NOTE = LT_RETURN-MESSAGE(100).
        ENDLOOP.

      ENDIF.
      "end REQ1

*INSERT LOG

      WA_LOG-LOGDATE = SY-DATUM.
      WA_LOG-TIME = SY-UZEIT.
      WA_LOG-USER_NAME = SY-UNAME.
      WA_LOG-EVENT = 'APPROVAL'.
      WA_LOG-SO_NUMBER = SO_WA-SO_NUM.
      SELECT COUNT(*) FROM YSP_MTOSO_LOG INTO LOG_COUNT .
      IF LOG_COUNT = 0.
        WA_LOG-LOG_NUMBER = 1.
      ELSE.
        WA_LOG-LOG_NUMBER = LOG_COUNT + 1.
      ENDIF.
      INSERT YSP_MTOSO_LOG FROM  WA_LOG.

    ENDIF.

  ENDLOOP.
  FLAG = ''.
  PERFORM SCREEN_START.
ENDFORM.


*----------------------------------------------------------------------*
* CHANGE 3 - include YSP_MTOSO_APPROVE_REJECT_FUF01
*            REPLACE the whole FORM REJECT_FUN
*----------------------------------------------------------------------*
*-----------------------------------------------------------------------------*
* Modification history                                                        *
*-----------------------------------------------------------------------------*
* Date        |Request No  |Author             |Description                   *
*-----------------------------------------------------------------------------*
* 17/02/2021  |DE3K919734 |IABAPT [Heba] |SD Support "T00002246/CH1555"       *
* <date>      |<request>  |<author>      |REQ1 release cycle informed per     *
*             |           |              |rejected item, BAPI tables per row  *
*-----------------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form REJECT_FUN
*&---------------------------------------------------------------------*
FORM REJECT_FUN .
   DATA : SD_APPROVE TYPE C , FI_APPROVE TYPE C , ZPOSNUM(2) TYPE C.
   DATA : ORDER_HEADER_INX TYPE BAPISDH1X,
          RETURN TYPE BAPIRET2,
          lt_return TYPE TABLE OF bapiret2 WITH HEADER LINE,
          ORDER_ITEM_IN	TYPE TABLE OF	BAPISDITM WITH HEADER LINE,
          ORDER_ITEM_INX  TYPE TABLE OF BAPISDITMX WITH HEADER LINE.
   DATA : LO_RELEASE TYPE REF TO ZCL_SD_SO_RELEASE.          "REQ1

   SELECT SINGLE ZPOSNUM FROM ZAPPROVEUSER INTO ZPOSNUM
            WHERE USER_NAME = SY-UNAME
             AND BUKRS = BUKRS.  "--Added by Heba for Support Task "T00002246/CH1555"

   IF SY-SUBRC = 0.

     LO_RELEASE = NEW #( ).                                   "REQ1

     REFRESH : IT_PROG_ROW_INDEX.
     CALL METHOD GRID->GET_SELECTED_ROWS
       IMPORTING
         ET_INDEX_ROWS = IT_PROG_ROW_INDEX.

     LOOP AT IT_PROG_ROW_INDEX INTO WA_PROG_ROW_INDEX.
       READ TABLE SO_TAB INTO SO_WA INDEX WA_PROG_ROW_INDEX-INDEX.

       "REQ1: each selected row starts with empty BAPI tables
       REFRESH: ORDER_ITEM_IN, ORDER_ITEM_INX, LT_RETURN.
       CLEAR:   ORDER_ITEM_IN, ORDER_ITEM_INX, ORDER_HEADER_INX, WA_LOG.

       ORDER_HEADER_INX-UPDATEFLAG = 'U'.
       ORDER_ITEM_IN-ITM_NUMBER =  SO_WA-POSNR .
       ORDER_ITEM_IN-REASON_REJ = '63'.
       APPEND ORDER_ITEM_IN.
       ORDER_ITEM_INX-ITM_NUMBER =  SO_WA-POSNR .
       ORDER_ITEM_INX-UPDATEFLAG = 'U'.
       ORDER_ITEM_INX-REASON_REJ  = 'X'.
       APPEND  ORDER_ITEM_INX.

       CALL FUNCTION 'BAPI_SALESORDER_CHANGE'  "#EC CI_USAGE_OK[2438131]
         EXPORTING
           SALESDOCUMENT    = SO_WA-SO_NUM
           ORDER_HEADER_INX = ORDER_HEADER_INX
         TABLES
           RETURN           = LT_RETURN
           ORDER_ITEM_IN    = ORDER_ITEM_IN
           ORDER_ITEM_INX   = ORDER_ITEM_INX.

       CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'  "#EC CI_USAGE_OK[2438131]
         EXPORTING
           WAIT   = 'X'
         IMPORTING
           RETURN = RETURN.

       LOOP AT LT_RETURN.
         MESSAGE LT_RETURN-MESSAGE(100) TYPE 'I'.
         WA_LOG-NOTE = LT_RETURN-MESSAGE(100).
       ENDLOOP.

       "REQ1: item rejected - if it was the last open item of a blocked
       "      order, the credit workflow starts for the approved items
       LO_RELEASE->ON_ITEM_DECISION( SO_WA-SO_NUM ).

*INSERT LOG

       WA_LOG-LOGDATE = SY-DATUM.
       WA_LOG-TIME = SY-UZEIT.
       WA_LOG-USER_NAME = SY-UNAME.
       WA_LOG-EVENT = 'REJECT'.
       WA_LOG-SO_NUMBER = SO_WA-SO_NUM.
       SELECT COUNT(*) FROM YSP_MTOSO_LOG INTO LOG_COUNT .
       IF LOG_COUNT = 0.
         WA_LOG-LOG_NUMBER = 1.
       ELSE.
         WA_LOG-LOG_NUMBER = LOG_COUNT + 1.
       ENDIF.
       INSERT YSP_MTOSO_LOG FROM  WA_LOG.

     ENDLOOP.
     FLAG = ''.
     PERFORM SCREEN_START.
   ELSE.
     MESSAGE 'No Authorization For reject this order' TYPE 'I'.
   ENDIF.
ENDFORM.
