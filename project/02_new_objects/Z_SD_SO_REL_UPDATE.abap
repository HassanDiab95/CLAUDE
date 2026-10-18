*&---------------------------------------------------------------------*
*& Function group : ZSD_SO_REL   (SE80 / SE37, package ZSD)
*& Function module: Z_SD_SO_REL_UPDATE
*& Processing type: Update module -> Start immediately (V1)
*&---------------------------------------------------------------------*
*& Writes the release tables of ZCL_SD_SO_RELEASE. Always called
*& IN UPDATE TASK, so the release status is saved together with the
*& sales order / YSDA approval / workflow step - or not at all.
*& DRAFT - not compiled / not tested in SAP
*&---------------------------------------------------------------------*
FUNCTION Z_SD_SO_REL_UPDATE.
*"----------------------------------------------------------------------
*"*"Update Function Module:
*"
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IS_HEADER) TYPE  ZSD_SO_REL_H
*"     VALUE(IT_ITEMS)  TYPE  ZSD_SO_REL_I_TT
*"     VALUE(IS_LOG)    TYPE  ZSD_SO_REL_LOG OPTIONAL
*"----------------------------------------------------------------------

  MODIFY ZSD_SO_REL_H FROM @IS_HEADER.

  " the class always sends all items of the order
  DELETE FROM ZSD_SO_REL_I WHERE VBELN = @IS_HEADER-VBELN.
  IF IT_ITEMS IS NOT INITIAL.
    INSERT ZSD_SO_REL_I FROM TABLE @IT_ITEMS.
  ENDIF.

  IF IS_LOG IS NOT INITIAL.
    INSERT ZSD_SO_REL_LOG FROM @IS_LOG.
  ENDIF.

ENDFUNCTION.
