FUNCTION Z_SD_SO_REL_UPDATE.
*"----------------------------------------------------------------------
*"*"Update Function Module: start immediately (V1)
*"
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IS_HEADER)        TYPE  ZSD_SO_REL_H
*"     VALUE(IT_ITEMS)         TYPE  ZSD_SO_REL_I_TT OPTIONAL
*"     VALUE(IV_REPLACE_ITEMS) TYPE  ABAP_BOOL DEFAULT ABAP_FALSE
*"     VALUE(IS_LOG)           TYPE  ZSD_SO_REL_LOG OPTIONAL
*"----------------------------------------------------------------------
* Writes the release tables of ZCL_SD_SO_RELEASE. Called IN UPDATE TASK
* only, so the release status is saved together with the sales order /
* YSDA approval / workflow step, or not at all.
* DRAFT - not compiled / not tested in SAP

  MODIFY ZSD_SO_REL_H FROM @IS_HEADER.

  IF IV_REPLACE_ITEMS = ABAP_TRUE.
    DELETE FROM ZSD_SO_REL_I WHERE VBELN = @IS_HEADER-VBELN.
    IF IT_ITEMS IS NOT INITIAL.
      INSERT ZSD_SO_REL_I FROM TABLE @IT_ITEMS.
    ENDIF.
  ENDIF.

  IF IS_LOG IS NOT INITIAL.
    INSERT ZSD_SO_REL_LOG FROM @IS_LOG.
  ENDIF.

ENDFUNCTION.
