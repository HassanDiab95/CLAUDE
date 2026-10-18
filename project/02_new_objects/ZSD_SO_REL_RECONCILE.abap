*&---------------------------------------------------------------------*
*& Report ZSD_SO_REL_RECONCILE
*&---------------------------------------------------------------------*
*& Safety net of the release cycle - schedule every 30 minutes (SM36).
*& For every order that is not finished it calls
*& ZCL_SD_SO_RELEASE->PROCESS, which:
*&   - releases approved items that are still on CN (order was locked)
*&   - raises the workflow start event again if it got lost
*&   - sets credit "not needed" when the credit block disappeared
*& and it reports workflows that are no longer active.
*& DRAFT - not compiled / not tested in SAP
*&---------------------------------------------------------------------*
REPORT ZSD_SO_REL_RECONCILE.

TABLES ZSD_SO_REL_H.

SELECT-OPTIONS S_VBELN FOR ZSD_SO_REL_H-VBELN.
SELECT-OPTIONS S_VKORG FOR ZSD_SO_REL_H-VKORG.
PARAMETERS     P_WAIT  TYPE I DEFAULT 30.   " minutes before a lost start is retried
PARAMETERS     P_TEST  AS CHECKBOX.          " list only, change nothing

START-OF-SELECTION.

  SELECT VBELN, CREDIT_STATUS, PROD_STATUS, WI_ID, CHANGED_ON, CHANGED_AT
    FROM ZSD_SO_REL_H
    WHERE VBELN IN @S_VBELN
      AND VKORG IN @S_VKORG
      AND ( OVERALL_STATUS IN ( '1', '2' )      " waiting costing / credit
         OR PROD_STATUS = 'E' )                 " release failed
    INTO TABLE @DATA(LT_ORDER).

  IF LT_ORDER IS INITIAL.
    WRITE / 'Nothing to reconcile'.
    RETURN.
  ENDIF.

  DATA(LO_REL) = NEW ZCL_SD_SO_RELEASE( ).

  DATA LV_NOW   TYPE TIMESTAMP.
  DATA LV_LAST  TYPE TIMESTAMP.
  GET TIME STAMP FIELD LV_NOW.

  LOOP AT LT_ORDER INTO DATA(LS_ORDER).

    " workflow should run but its work item is gone
    IF LS_ORDER-CREDIT_STATUS = ZCL_SD_SO_RELEASE=>GC_CREDIT-IN_APPROVAL.
      SELECT SINGLE WI_STAT FROM SWWWIHEAD
        WHERE WI_ID = @LS_ORDER-WI_ID
        INTO @DATA(LV_STAT).
      IF SY-SUBRC <> 0 OR LV_STAT = 'CANCELLED' OR LV_STAT = 'COMPLETED'.
        WRITE: / LS_ORDER-VBELN, 'Credit workflow', LS_ORDER-WI_ID, 'not active - check SWIA'.
      ENDIF.
      CONTINUE.
    ENDIF.

    CHECK P_TEST = ABAP_FALSE.

    " a lost start event is retried only after P_WAIT minutes
    CONVERT DATE LS_ORDER-CHANGED_ON TIME LS_ORDER-CHANGED_AT
            INTO TIME STAMP LV_LAST TIME ZONE SY-ZONLO.
    DATA(LV_RETRY) = XSDBOOL( LS_ORDER-CREDIT_STATUS = ZCL_SD_SO_RELEASE=>GC_CREDIT-WAITING
                              AND CL_ABAP_TSTMP=>SUBTRACT( TSTMP1 = LV_NOW
                                                           TSTMP2 = LV_LAST ) > P_WAIT * 60 ).

    DATA(LV_NOTE) = LO_REL->PROCESS( IV_VBELN       = LS_ORDER-VBELN
                                     IV_RETRY_START = LV_RETRY ).

    IF LV_NOTE IS NOT INITIAL.
      WRITE: / LS_ORDER-VBELN, LV_NOTE.
    ENDIF.

  ENDLOOP.
