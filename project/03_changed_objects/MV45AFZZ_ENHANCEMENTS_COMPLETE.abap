*======================================================================
* MV45AFZZ - complete code of every enhancement of the release cycle
* Replace the whole code between ENHANCEMENT and ENDENHANCEMENT.
* (these separator lines are only for this file - do not paste them)
*======================================================================


*----------------------------------------------------------------------
* 1) FORM USEREXIT_SAVE_DOCUMENT - existing ZEN_CMEXOD_KILL_WORKFLOW
*    (B1 + B2)
*----------------------------------------------------------------------
ENHANCEMENT 1  ZEN_CMEXOD_KILL_WORKFLOW.
  IF ( T180-TRTYP = 'V' AND T180-TCODE = 'VA02' )
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
ENDENHANCEMENT.


*----------------------------------------------------------------------
* 2) FORM USEREXIT_SAVE_DOCUMENT - NEW ZEN_SO_RELEASE_SAVE
*    (B3) same enhancement point as ZEN_CMEXOD_KILL_WORKFLOW:
*    right click -> Enhancement Implementation -> Create
*----------------------------------------------------------------------
ENHANCEMENT 1  ZEN_SO_RELEASE_SAVE.
  IF XVBAK_UPDKZ <> 'D' AND VBAK-VBELN IS NOT INITIAL.
    NEW ZCL_SD_SO_RELEASE( )->ON_ORDER_SAVED(
      IS_ORDER    = VALUE #( VBELN = VBAK-VBELN
                             BUKRS = VBAK-BUKRS_VF
                             VKORG = VBAK-VKORG
                             AUART = VBAK-AUART
                             VBTYP = VBAK-VBTYP
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


*----------------------------------------------------------------------
* 3) FORM USEREXIT_DELETE_DOCUMENT - existing ZEN_CMEXOD_KILL_WORKFLOW_WDEL
*    (B4)
*----------------------------------------------------------------------
ENHANCEMENT 1  ZEN_CMEXOD_KILL_WORKFLOW_WDEL.
  IF ( XVBAK_UPDKZ = 'D' AND T180-TRTYP = 'V' )
     AND VBAK-VBELN IS NOT INITIAL.

    IF NEW ZCL_SD_SO_RELEASE( )->IS_MANAGED( VBAK-VBELN ) = ABAP_TRUE.
      NEW ZCL_SD_SO_RELEASE( )->ON_ORDER_DELETED( VBAK-VBELN ).
    ELSE.
      DATA(LO_CREDIT) = NEW ZCL_WF_SD_CREDIT( ).
      IF LO_CREDIT->IS_ORDER_LOCKED( VBAK-VBELN ) = ABAP_TRUE.
        LO_CREDIT->KILL_RUNNING_WORKFLOW(
          IV_VBELN  = VBAK-VBELN
          IV_REASON = CONV STRING( |Sales order Deleted In { SY-TCODE } by { SY-UNAME }.| &&
                                   |Approval Cancel.| ) ).
      ENDIF.
    ENDIF.

  ENDIF.
ENDENHANCEMENT.


*----------------------------------------------------------------------
* 4) FORM USEREXIT_SAVE_DOCUMENT_PREPARE - NEW ZEN_SO_RELEASE_NO_VKM
*    (B5) enhancement point at the start of the FORM -> Create
*----------------------------------------------------------------------
ENHANCEMENT 1  ZEN_SO_RELEASE_NO_VKM.
  IF ( SY-TCODE = 'VKM1' OR SY-TCODE = 'VKM3' OR SY-TCODE = 'VKM4' )
     AND VBAK-VBELN IS NOT INITIAL
     AND NEW ZCL_SD_SO_RELEASE( )->IS_IN_CREDIT_APPROVAL( VBAK-VBELN ) = ABAP_TRUE.
    MESSAGE E017(ZSD_WF) WITH VBAK-VBELN.
  ENDIF.
ENDENHANCEMENT.


*----------------------------------------------------------------------
* 5) FORM USEREXIT_MOVE_FIELD_TO_VBEP - existing ZSD_CHECK_APPROVAL
*    (B6 + B7)
*----------------------------------------------------------------------
ENHANCEMENT 1  ZSD_CHECK_APPROVAL.
TABLES: ZSOAPPROVAL.
DATA: SD_APRV TYPE ZSOAPPROVAL-SD_APPROVE,
      FI_APRV TYPE ZSOAPPROVAL-SD_APPROVE.

IF ( SY-TCODE = 'VA01' OR SY-TCODE = 'VA02' ) AND SVBEP-TABIX > 0
  AND ( VBEP-ETTYP NE *VBEP-ETTYP ).

  IF ( VBAK-BUKRS_VF = '1400' AND ( VBAK-AUART = 'ZEM' OR VBAK-AUART = 'ZMT') )
  OR ( VBAK-BUKRS_VF = '1200' AND VBAK-AUART = 'YPMT')
  OR ( VBAK-BUKRS_VF = '1500' AND VBAK-AUART = 'YCMT')
  OR ( VBAK-BUKRS_VF = '1600' AND VBAK-AUART = 'YXMT').

    IF SY-TCODE = 'VA01'.
      MESSAGE 'Error: Schedule Line cannot be Changed...' TYPE 'E'.
    ELSE.

      CLEAR: SD_APRV, FI_APRV.
      SELECT SINGLE SD_APPROVE FI_APPROVE
        FROM ZSOAPPROVAL
        INTO ( SD_APRV , FI_APRV )
        WHERE VBELN = VBEP-VBELN
        AND   POSNR = VBEP-POSNR.

      IF SY-DBCNT = 0 OR ( SD_APRV IS INITIAL OR FI_APRV IS INITIAL ).
        MESSAGE 'Change Schedule Line Error: Document is not yet approved via YSDAX/YSDA' TYPE 'E'.
      ENDIF.

    ENDIF.
  ENDIF.

  IF SY-TCODE = 'VA02'
     AND *VBEP-ETTYP = 'CN'
     AND NEW ZCL_SD_SO_RELEASE( )->IS_ITEM_RELEASE_ALLOWED(
           IV_VBELN = VBEP-VBELN
           IV_POSNR = VBEP-POSNR ) = ABAP_FALSE.
    MESSAGE E018(ZSD_WF) WITH VBEP-POSNR.
  ENDIF.

ENDIF.
ENDENHANCEMENT.


*----------------------------------------------------------------------
* 6) FORM USEREXIT_READ_DOCUMENT - existing ZEN_DISAB_VA02_CM_WF_RUNNINNG
*    (B8)
*----------------------------------------------------------------------
ENHANCEMENT 1  ZEN_DISAB_VA02_CM_WF_RUNNINNG.
  IF SY-TCODE = 'VA02'
     AND VBAK-VBELN IS NOT INITIAL
     AND NEW ZCL_WF_SD_CREDIT( )->IS_ORDER_LOCKED( VBAK-VBELN ) = ABAP_TRUE
     AND NEW ZCL_SD_SO_RELEASE( )->IS_MANAGED( VBAK-VBELN ) = ABAP_FALSE.
    MESSAGE S014(ZSD_WF) WITH VBAK-VBELN DISPLAY LIKE 'E'.
    SET PARAMETER ID 'AUN' FIELD VBAK-VBELN.
    LEAVE TO TRANSACTION 'VA03' AND SKIP FIRST SCREEN.
  ENDIF.
ENDENHANCEMENT.
