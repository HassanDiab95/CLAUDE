*======================================================================*
* MV45AFZZ - all changes for the release cycle (REQ1)
* DRAFT - not compiled / not tested in SAP
*
* IMPORTANT - why IF instead of CHECK:
* An enhancement is part of the FORM it sits in. A CHECK that fails
* leaves the whole FORM, so every enhancement and every line after it in
* that user exit is skipped. The current ZEN_CMEXOD_KILL_WORKFLOW starts
* USEREXIT_SAVE_DOCUMENT with CHECKs, so today ZO2C_CREDITLMIT_CHECK,
* ZSAVE_DIFF_COST_PROFIT, ZSD_CHECK_SALESOFFICE, ZSD_DISCOUNT_BLOCK ...
* only run when the order is changed in VA02 and is locked by the credit
* workflow. All code below uses IF, never CHECK.
*======================================================================*


*----------------------------------------------------------------------*
* CHANGE 1 - FORM USEREXIT_SAVE_DOCUMENT
*            REPLACE the code of enhancement ZEN_CMEXOD_KILL_WORKFLOW
*            (SE80 -> MV45AFZZ -> enhancement ZEN_CMEXOD_KILL_WORKFLOW
*            -> change, select all, paste)
*----------------------------------------------------------------------*
ENHANCEMENT 1  ZEN_CMEXOD_KILL_WORKFLOW.    "active version
*--- Begin of Enhancement | Hassan Diab | kill on change --------------
*--- REQ1: IF instead of CHECK (CHECK left the whole user exit) and
*---       orders of the release cycle are handled by ZEN_SO_RELEASE_SAVE
  IF T180-TRTYP = 'V' AND T180-TCODE = 'VA02'
     AND VBAK-VBELN IS NOT INITIAL
     AND NEW ZCL_SD_SO_RELEASE( )->IS_MANAGED( VBAK-VBELN ) = ABAP_FALSE.

    DATA(LO_CREDIT) = NEW ZCL_WF_SD_CREDIT( ).

    IF LO_CREDIT->IS_ORDER_LOCKED( VBAK-VBELN ) = ABAP_TRUE.
      LO_CREDIT->KILL_RUNNING_WORKFLOW(
        IV_VBELN  = VBAK-VBELN
        IV_REASON = CONV STRING( |Sales order changed in { SY-TCODE } by { SY-UNAME }.| &&
                                 |Approval Cancel, credit check will re-run.| ) ).
    ENDIF.

  ENDIF.
*--- End of Enhancement -----------------------------------------------
ENDENHANCEMENT.


*----------------------------------------------------------------------*
* CHANGE 2 - FORM USEREXIT_SAVE_DOCUMENT
*            NEW enhancement implementation ZEN_SO_RELEASE_SAVE
*            (at the same enhancement point "Start of USEREXIT_SAVE_DOCUMENT":
*            right click -> Enhancement Implementation -> Create)
*----------------------------------------------------------------------*
ENHANCEMENT 1  ZEN_SO_RELEASE_SAVE.    "active version
*--- REQ1 release cycle: create the release row, detect new items,
*--- restart the credit workflow only on a credit relevant change.
*--- Runs for every save: VA01, VA02, BAPI, YSDA/YSDAX, jobs.
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


*----------------------------------------------------------------------*
* CHANGE 3 - FORM USEREXIT_DELETE_DOCUMENT
*            REPLACE the code of enhancement ZEN_CMEXOD_KILL_WORKFLOW_WDEL
*----------------------------------------------------------------------*
ENHANCEMENT 1  ZEN_CMEXOD_KILL_WORKFLOW_WDEL.    "active version
*--- Begin of Enhancement | Hassan Diab | kill on delete --------------
*--- REQ1: IF instead of CHECK; release cycle orders are closed too
  IF XVBAK_UPDKZ = 'D' AND T180-TRTYP = 'V'
     AND VBAK-VBELN IS NOT INITIAL.

    IF NEW ZCL_SD_SO_RELEASE( )->IS_MANAGED( VBAK-VBELN ) = ABAP_TRUE.

      " kills the workflow, closes the logs, release status 'D'
      NEW ZCL_SD_SO_RELEASE( )->ON_ORDER_DELETED( VBAK-VBELN ).

    ELSE.

      DATA(LO_CREDIT_DEL) = NEW ZCL_WF_SD_CREDIT( ).
      IF LO_CREDIT_DEL->IS_ORDER_LOCKED( VBAK-VBELN ) = ABAP_TRUE.
        LO_CREDIT_DEL->KILL_RUNNING_WORKFLOW(
          IV_VBELN  = VBAK-VBELN
          IV_REASON = CONV STRING( |Sales order Deleted In { SY-TCODE } by { SY-UNAME }.| &&
                                   |Approval Cancel.| ) ).
      ENDIF.

    ENDIF.

  ENDIF.
*--- End of Enhancement -----------------------------------------------
ENDENHANCEMENT.


*----------------------------------------------------------------------*
* CHANGE 4 - FORM USEREXIT_SAVE_DOCUMENT_PREPARE
*            NEW enhancement implementation ZEN_SO_RELEASE_NO_VKM
*            Credit release only through the workflow while it runs.
*----------------------------------------------------------------------*
ENHANCEMENT 1  ZEN_SO_RELEASE_NO_VKM.    "active version
*--- REQ1: no manual credit release (VKM1/VKM3/VKM4) while the
*--- credit approval workflow of the release cycle is running
  IF ( SY-TCODE = 'VKM1' OR SY-TCODE = 'VKM3' OR SY-TCODE = 'VKM4' )
     AND VBAK-VBELN IS NOT INITIAL
     AND NEW ZCL_SD_SO_RELEASE( )->IS_IN_CREDIT_APPROVAL( VBAK-VBELN ) = ABAP_TRUE.
    MESSAGE E015(ZSD_WF) WITH VBAK-VBELN.
  ENDIF.
ENDENHANCEMENT.


*----------------------------------------------------------------------*
* CHANGE 5 - FORM USEREXIT_MOVE_FIELD_TO_VBEP
*            REPLACE the code of enhancement ZSD_CHECK_APPROVAL
*----------------------------------------------------------------------*
ENHANCEMENT 1  ZSD_CHECK_APPROVAL.    "active version
*----------------------------------------------------------------------------*
* OBJECT ID               :  ZSD_CHECK_APPROVAL                              *
* PROGRAM TITLE           :  Check Sales Order Approval Status at VA01/VA02  *
* MODULE                  :  SD                                              *
* PROGRAM TYPE            :  Implicit Enhancement Implementation             *
* CREATED BY              :  SUPPORTABAP [HEBA]                              *
* CREATION DATE           :  16/12/2021                                      *
* ORIGINAL REQUEST        :  DE3K921298 - DE3K921308 - DE3K921310            *
*                         :  DE3K921312                                      *
* SUPPORT TASK            :  T00003003                                       *
* CHANGE REQ/INCIDENT     :  CH1997                                          *
*----------------------------------------------------------------------------*
* Modification history                                                       *
*----------------------------------------------------------------------------*
* Date        |Request No  |Author      |Description                         *
* 27/12/2021  |DE3K921350  |HEBA        |SD Support "T00003069/IN6060"       *
* <date>      |<request>   |<author>    |REQ1: approval read by order/item   *
*             |            |            |(BUKRS held the plant); no CN->CP   *
*             |            |            |before the credit approval          *
*----------------------------------------------------------------------------*

TABLES: ZSOAPPROVAL.
DATA: SD_APRV TYPE ZSOAPPROVAL-SD_APPROVE,
      FI_APRV TYPE ZSOAPPROVAL-SD_APPROVE.


"Check Tcodes
IF ( SY-TCODE = 'VA01' OR SY-TCODE = 'VA02' ) AND SVBEP-TABIX > 0
  AND ( VBEP-ETTYP NE *VBEP-ETTYP ). "Change Schedule line category


"Check Company Code and Doc. Type
  IF ( VBAK-BUKRS_VF = '1400' AND ( VBAK-AUART = 'ZEM' OR VBAK-AUART = 'ZMT') )
  OR ( VBAK-BUKRS_VF = '1200' AND VBAK-AUART = 'YPMT')
  OR ( VBAK-BUKRS_VF = '1500' AND VBAK-AUART = 'YCMT')
  OR ( VBAK-BUKRS_VF = '1600' AND VBAK-AUART = 'YXMT').


    IF SY-TCODE = 'VA01'.
      "Display Error Msg
      MESSAGE 'Error: Schedule Line cannot be Changed...' TYPE 'E'.
    ELSE.


      "Check Sales Order SD Approval Status
      "REQ1: no BUKRS in the key - YSDA/YSDAX store the plant in it,
      "      so plants 1202 / 1501 never found their approval
      CLEAR: SD_APRV, FI_APRV.
      SELECT SINGLE SD_APPROVE FI_APPROVE
        FROM ZSOAPPROVAL
        INTO ( SD_APRV , FI_APRV )
        WHERE VBELN = VBEP-VBELN
        AND   POSNR = VBEP-POSNR.


    "Display Error Msg in case not SD approved
      IF SY-DBCNT = 0 OR ( SD_APRV IS INITIAL OR FI_APRV IS INITIAL ).
        MESSAGE 'Change Schedule Line Error: Document is not yet approved via YSDAX/YSDA' TYPE 'E'.
      ENDIF.

      "REQ1: release cycle - item leaves CN only after the credit approval
      IF *VBEP-ETTYP = 'CN'
         AND NEW ZCL_SD_SO_RELEASE( )->IS_ITEM_RELEASE_ALLOWED(
               IV_VBELN = VBEP-VBELN
               IV_POSNR = VBEP-POSNR ) = ABAP_FALSE.
        MESSAGE E016(ZSD_WF) WITH VBEP-POSNR.
      ENDIF.

  ENDIF.
 ENDIF.
ENDIF.

ENDENHANCEMENT.


*----------------------------------------------------------------------*
* CHANGE 6 - FORM USEREXIT_READ_DOCUMENT
*            REPLACE the code of enhancement ZEN_DISAB_VA02_CM_WF_RUNNINNG
*            Release cycle orders may be changed in VA02 during the
*            credit workflow (ZEN_SO_RELEASE_SAVE decides if the workflow
*            restarts). Other orders keep the VA03 redirect.
*----------------------------------------------------------------------*
ENHANCEMENT 1  ZEN_DISAB_VA02_CM_WF_RUNNINNG.    "active version
*--- REQ1: IF instead of CHECK; redirect only orders outside the cycle
  IF SY-TCODE = 'VA02'
     AND VBAK-VBELN IS NOT INITIAL
     AND NEW ZCL_WF_SD_CREDIT( )->IS_ORDER_LOCKED( VBAK-VBELN ) = ABAP_TRUE
     AND NEW ZCL_SD_SO_RELEASE( )->IS_MANAGED( VBAK-VBELN ) = ABAP_FALSE.
    MESSAGE S014(ZSD_WF) WITH VBAK-VBELN DISPLAY LIKE 'E'.
    SET PARAMETER ID 'AUN' FIELD VBAK-VBELN.
    LEAVE TO TRANSACTION 'VA03' AND SKIP FIRST SCREEN.
  ENDIF.
ENDENHANCEMENT.
