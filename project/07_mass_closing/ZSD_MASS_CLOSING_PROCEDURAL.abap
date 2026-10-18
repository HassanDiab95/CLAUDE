*&---------------------------------------------------------------------*
*& Report ZSD_MASS_CLOSING
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zsd_mass_closing.
************************************************************************
* DATA DECLARATIONS                                                    *
************************************************************************
*Tables:
TABLES:
  vbap.

*Internal tables:
DATA:
  gt_vbap     TYPE STANDARD TABLE OF vbap,
  gt_item_in  TYPE STANDARD TABLE OF bapisditm,
  gt_item_inx TYPE STANDARD TABLE OF bapisditmx,
  gt_return   TYPE STANDARD TABLE OF bapiret2.

*Field Symbols:
FIELD-SYMBOLS:
  <fs_vbap>         TYPE vbap.

*Structures:
DATA:
  gst_item_hedx TYPE bapisdh1x,
  gst_item_in   TYPE bapisditm,
  gst_item_inx  TYPE bapisditmx.

*Variables:
DATA:
  gv_msg            TYPE string.

*Constants:
CONSTANTS:
  gc_error   TYPE string VALUE ': An error occured, no change done to the sales order.',
  gc_success TYPE string VALUE ': Sales order changed successfully.'.

************************************************************************
* SELECTION SCREEN                                                     *
************************************************************************
SELECT-OPTIONS:
*  Sales Order Number.
   s_vbeln FOR vbap-vbeln ."OBLIGATORY.

************************************************************************
* CODE LOGIC                                                           *
************************************************************************
DATA: it_vbak          TYPE TABLE OF vbak,
      wa_vbak          TYPE vbak,
      it_vbap          TYPE TABLE OF vbap,
      wa_vbap          TYPE vbap,
      it_prcd_elements TYPE TABLE OF prcd_elements,
      zkwert           TYPE prcd_elements-kwert.
DATA:
  ld_calc_date TYPE p0001-begda,
  ld_date      TYPE p0001-begda,
  ld_days      TYPE t5a4a-dlydy,
  ld_months    TYPE t5a4a-dlymo,
  ld_signum    TYPE t5a4a-split,
  ld_years     TYPE t5a4a-dlyyr.

"in case of 90 days.

ld_date = sy-datum.
ld_days = '90'.
ld_months = '00'.
ld_years = '00'.
ld_signum = '-'.

CALL FUNCTION 'RP_CALC_DATE_IN_INTERVAL'
  EXPORTING
    date      = ld_date
    days      = ld_days
    months    = ld_months
    signum    = ld_signum
    years     = ld_years
  IMPORTING
    calc_date = ld_calc_date.

IF sy-subrc EQ 0.
  "All OK
ENDIF.

"new code
TYPES: BEGIN OF st_outputdata,
         vbeln TYPE vbak-vbeln,
         posnr TYPE vbap-posnr,
         matnr TYPE vbap-matnr,
         lfsta TYPE vbap-lfsta,
         abgru TYPE vbap-abgru,
       END OF st_outputdata.

DATA: it TYPE  TABLE OF st_outputdata,
      wa TYPE st_outputdata.

SELECT vbak~vbeln
  vbap~posnr vbap~matnr vbap~lfsta
  FROM vbak INNER JOIN vbap ON ( vbak~vbeln = vbap~vbeln )
   INTO CORRESPONDING FIELDS OF TABLE it WHERE  vbak~vkorg IN ('1200','1500','1600') AND  vbak~erdat <= ld_calc_date  AND vbak~vbeln IN s_vbeln AND
  vbak~vbtyp <> 'B' AND vbak~gbstk <> 'C' AND vbap~lfsta <> 'C' AND vbap~abgru <> '00'.

IF sy-subrc EQ 0.
  SORT it BY vbeln. "ATC Changes by REHM on 17.11.2025
  LOOP AT it INTO wa.

*   (Order Item Level)
*   Setting of the material number(MATNR) at order item level.
    gst_item_in-material = wa-matnr.

*   Setting of the item number(POSNR) at order item level.
    gst_item_in-itm_number  = wa-posnr.
    gst_item_inx-itm_number = wa-posnr.

*   Setting of the reason for rejection(ABGRU) at order item level.
    gst_item_in-reason_rej  = '00'."P_ABGRU.
    gst_item_inx-reason_rej = 'X'.

*   Setting the update flag at order item level to update mode.
    gst_item_inx-updateflag = 'U'.

*   BAPI items level tables:
    APPEND:
      gst_item_in  TO gt_item_in,
      gst_item_inx TO gt_item_inx.

    CLEAR:
      gst_item_in,
      gst_item_inx.

*--- Begin of change | SAP incident | one BAPI call and one commit per order
*   All items of the order are collected first; the order is saved once.
    AT END OF vbeln.

*     (Order Header Level)
*     Setting the update flag at order header level to update mode.
      gst_item_hedx-updateflag = 'U'.

*     Calling BAPI to update reason for rejection in the selected sales order.
      CALL FUNCTION 'BAPI_SALESORDER_CHANGE'  "#EC CI_USAGE_OK[2438131]
        EXPORTING
          salesdocument    = wa-vbeln
          order_header_inx = gst_item_hedx
        TABLES
          return           = gt_return
          order_item_in    = gt_item_in
          order_item_inx   = gt_item_inx.

*     Preparing the result message.
      gv_msg = wa-vbeln.

*     Check if at least one error was raised by the BAPI.
      LOOP AT gt_return TRANSPORTING NO FIELDS
      WHERE type EQ 'E'
         OR type EQ 'A'.

*       Exit and rollback changes.
        EXIT.

      ENDLOOP.

*     If error found, rollback database changes.
      IF sy-subrc EQ 0.

*       Rollback changes.
        CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.

*       Preparing error message.
        CONCATENATE gv_msg        "Sales Order Number
                    gc_error      "Error Message
               INTO gv_msg
       SEPARATED BY space.

*       Output message.
        WRITE / gv_msg.

*     Else, no error found, commit database changes.
      ELSE.

*       Commit changes.
        CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
          EXPORTING
            wait = abap_true.

*       Preparing success message.
        CONCATENATE gv_msg        "Sales Order Number
                    gc_success    "Success Message
               INTO gv_msg
       SEPARATED BY space.

*       Output message.
        WRITE / gv_msg.

      ENDIF.

*     Write a line after each sales order.
      WRITE: sy-uline.

*     Clearing of variables and structures:
      CLEAR:
        gv_msg,
        gst_item_hedx.

*     Refreshing internal tables:
      REFRESH:
        gt_item_in,
        gt_item_inx,
        gt_return.

    ENDAT.
*--- End of change ----------------------------------------------------

  ENDLOOP.

ENDIF.
