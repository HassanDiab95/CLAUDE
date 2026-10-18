CLASS ZCL_WF_SD_FINDER DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    CLASS-METHODS CREATE
      IMPORTING IO_READER        TYPE REF TO ZIF_WF_SD_READER OPTIONAL
      RETURNING VALUE(RO_FINDER) TYPE REF TO ZCL_WF_SD_FINDER.

    METHODS DETERMINE_LEVEL
      IMPORTING IS_KEY          TYPE ZIF_WF_SD_TYPES=>TY_KEY
      RETURNING VALUE(RS_LEVEL) TYPE ZIF_WF_SD_TYPES=>TY_LEVEL
      RAISING   ZCX_WF_SD.

    METHODS FIND_APPROVERS
      IMPORTING IS_KEY              TYPE ZIF_WF_SD_TYPES=>TY_KEY
      RETURNING VALUE(RT_APPROVERS) TYPE ZIF_WF_SD_TYPES=>TT_APPROVER
      RAISING   ZCX_WF_SD.

    METHODS FIND_APPROVERS_MULTI
      IMPORTING IT_KEYS             TYPE ZIF_WF_SD_TYPES=>TT_KEY
      RETURNING VALUE(RT_APPROVERS) TYPE ZIF_WF_SD_TYPES=>TT_APPROVER
      RAISING   ZCX_WF_SD.

    METHODS GET_APPROVERS_WF
      IMPORTING IV_WF_TYPE      TYPE ZWF_TYPE
                IV_BUKRS        TYPE BUKRS
                IV_CREDIT_GROUP TYPE UKM_CRED_GROUP
                IV_RANGE_CODE   TYPE ZRANGE_CODE
                IV_VBELN        TYPE VBELN_VA OPTIONAL
      RETURNING VALUE(RT_USERS) TYPE ZWF_USERS_TY.


  PRIVATE SECTION.

    DATA MO_READER TYPE REF TO ZIF_WF_SD_READER.

    METHODS CONSTRUCTOR
      IMPORTING IO_READER TYPE REF TO ZIF_WF_SD_READER.

    METHODS MAP_LEVEL
      IMPORTING IS_CONTROL      TYPE ZWF_CONTROL
      RETURNING VALUE(RV_LEVEL) TYPE CHAR1.

    METHODS MAP_VIEW
      IMPORTING IV_LEVEL       TYPE CHAR1
      RETURNING VALUE(RV_VIEW) TYPE DD02L-TABNAME.

    METHODS VALIDATE_KEY
      IMPORTING IS_KEY TYPE ZIF_WF_SD_TYPES=>TY_KEY
      RAISING   ZCX_WF_SD.

    METHODS BUILD_KEYS
      IMPORTING IV_WF_TYPE      TYPE ZWF_TYPE
                IV_BUKRS        TYPE BUKRS
                IV_CREDIT_GROUP TYPE UKM_CRED_GROUP
                IV_RANGE_CODE   TYPE ZRANGE_CODE
                IV_VBELN        TYPE VBELN_VA
      RETURNING VALUE(RT_KEYS)  TYPE ZIF_WF_SD_TYPES=>TT_KEY.

ENDCLASS.



CLASS ZCL_WF_SD_FINDER IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_SD_FINDER->BUILD_KEYS
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_WF_TYPE                     TYPE        ZWF_TYPE
* | [--->] IV_BUKRS                       TYPE        BUKRS
* | [--->] IV_CREDIT_GROUP                TYPE        UKM_CRED_GROUP
* | [--->] IV_RANGE_CODE                  TYPE        ZRANGE_CODE
* | [--->] IV_VBELN                       TYPE        VBELN_VA
* | [<-()] RT_KEYS                        TYPE        ZIF_WF_SD_TYPES=>TT_KEY
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD BUILD_KEYS.

    IF IV_VBELN IS INITIAL.

      APPEND VALUE #( WF_TYPE      = IV_WF_TYPE
                      BUKRS        = IV_BUKRS
                      CREDIT_GROUP = IV_CREDIT_GROUP
                      RANGE_CODE   = IV_RANGE_CODE ) TO RT_KEYS.
      RETURN.

    ENDIF.

    SELECT SINGLE SPART
      FROM VBAK
      WHERE VBELN = @IV_VBELN
      INTO @DATA(LV_HEAD_SPART).

    SELECT DISTINCT WERKS, SPART
      FROM VBAP
      WHERE VBELN  = @IV_VBELN
        AND WERKS <> @SPACE
      INTO TABLE @DATA(LT_ITEMS).

    IF LT_ITEMS IS INITIAL.

      APPEND VALUE #( WF_TYPE      = IV_WF_TYPE
                      BUKRS        = IV_BUKRS
                      CREDIT_GROUP = IV_CREDIT_GROUP
                      RANGE_CODE   = IV_RANGE_CODE ) TO RT_KEYS.
      RETURN.

    ENDIF.

    LOOP AT LT_ITEMS INTO DATA(LS_ITEM).

      APPEND VALUE #( WF_TYPE      = IV_WF_TYPE
                      BUKRS        = IV_BUKRS
                      WERKS        = LS_ITEM-WERKS
                      SPART        = COND #( WHEN LS_ITEM-SPART IS NOT INITIAL
                      THEN LS_ITEM-SPART
                      ELSE LV_HEAD_SPART )
                      CREDIT_GROUP = IV_CREDIT_GROUP
                      RANGE_CODE   = IV_RANGE_CODE ) TO RT_KEYS.

    ENDLOOP.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_SD_FINDER->CONSTRUCTOR
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_READER                      TYPE REF TO ZIF_WF_SD_READER
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD CONSTRUCTOR.

    MO_READER = IO_READER.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_WF_SD_FINDER=>CREATE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_READER                      TYPE REF TO ZIF_WF_SD_READER(optional)
* | [<-()] RO_FINDER                      TYPE REF TO ZCL_WF_SD_FINDER
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD CREATE.

    RO_FINDER = NEW #( COND #( WHEN IO_READER IS BOUND
                               THEN IO_READER
                               ELSE NEW ZCL_WF_SD_READER( ) ) ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_SD_FINDER->DETERMINE_LEVEL
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_KEY                         TYPE        ZIF_WF_SD_TYPES=>TY_KEY
* | [<-()] RS_LEVEL                       TYPE        ZIF_WF_SD_TYPES=>TY_LEVEL
* | [!CX!] ZCX_WF_SD
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD DETERMINE_LEVEL.

    VALIDATE_KEY( IS_KEY ).

    DATA LS_CONTROL TYPE ZWF_CONTROL.

    IF IS_KEY-WERKS IS NOT INITIAL.

      LS_CONTROL = MO_READER->READ_CONTROL( IV_WF_TYPE = IS_KEY-WF_TYPE
                                            IV_BUKRS   = IS_KEY-BUKRS
                                            IV_WERKS   = IS_KEY-WERKS ).

    ENDIF.

    IF LS_CONTROL IS INITIAL.

      LS_CONTROL = MO_READER->READ_CONTROL( IV_WF_TYPE = IS_KEY-WF_TYPE
                                            IV_BUKRS   = IS_KEY-BUKRS
                                            IV_WERKS   = SPACE ).

    ENDIF.

    IF LS_CONTROL IS INITIAL.
      RAISE EXCEPTION TYPE ZCX_WF_SD
        EXPORTING
          TEXTID   = ZCX_WF_SD=>NO_CONTROL_ENTRY
          IV_ATTR1 = IS_KEY-BUKRS
          IV_ATTR2 = IS_KEY-WERKS.
    ENDIF.

    DATA(LV_LEVEL) = MAP_LEVEL( LS_CONTROL ).

    RS_LEVEL = VALUE #( LEVEL = LV_LEVEL
                        BUKRS = LS_CONTROL-BUKRS
                        WERKS = LS_CONTROL-WERKS
                        VIEW  = MAP_VIEW( LV_LEVEL ) ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_SD_FINDER->FIND_APPROVERS
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_KEY                         TYPE        ZIF_WF_SD_TYPES=>TY_KEY
* | [<-()] RT_APPROVERS                   TYPE        ZIF_WF_SD_TYPES=>TT_APPROVER
* | [!CX!] ZCX_WF_SD
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD FIND_APPROVERS.

    DATA(LS_LEVEL) = DETERMINE_LEVEL( IS_KEY ).

    DATA(LS_KEY) = IS_KEY.
    LS_KEY-WERKS = LS_LEVEL-WERKS.

    CASE LS_LEVEL-LEVEL.

      WHEN ZIF_WF_SD_TYPES=>GC_LEVEL-COMPANY.
        CLEAR LS_KEY-SPART.
        RT_APPROVERS = MO_READER->READ_USERS_COMPANY( LS_KEY ).

      WHEN ZIF_WF_SD_TYPES=>GC_LEVEL-PLANT.
        CLEAR LS_KEY-SPART.
        RT_APPROVERS = MO_READER->READ_USERS_PLANT( LS_KEY ).

      WHEN ZIF_WF_SD_TYPES=>GC_LEVEL-DIVISION.
        IF LS_KEY-SPART IS INITIAL.
          RAISE EXCEPTION TYPE ZCX_WF_SD
            EXPORTING
              TEXTID   = ZCX_WF_SD=>SPART_MISSING
              IV_ATTR1 = LS_KEY-WERKS.
        ENDIF.
        RT_APPROVERS = MO_READER->READ_USERS_DIVISION( LS_KEY ).

    ENDCASE.

    IF RT_APPROVERS IS INITIAL.
      RAISE EXCEPTION TYPE ZCX_WF_SD
        EXPORTING
          TEXTID   = ZCX_WF_SD=>NO_APPROVER
          IV_ATTR1 = IS_KEY-BUKRS
          IV_ATTR2 = IS_KEY-WERKS
          IV_ATTR3 = IS_KEY-SPART.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_SD_FINDER->FIND_APPROVERS_MULTI
* +-------------------------------------------------------------------------------------------------+
* | [--->] IT_KEYS                        TYPE        ZIF_WF_SD_TYPES=>TT_KEY
* | [<-()] RT_APPROVERS                   TYPE        ZIF_WF_SD_TYPES=>TT_APPROVER
* | [!CX!] ZCX_WF_SD
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD FIND_APPROVERS_MULTI.

    LOOP AT IT_KEYS INTO DATA(LS_KEY).

      LOOP AT FIND_APPROVERS( LS_KEY ) INTO DATA(LS_APPROVER).

        IF NOT LINE_EXISTS( RT_APPROVERS[ SEQUENCE = LS_APPROVER-SEQUENCE
                                          BNAME    = LS_APPROVER-BNAME ] ).
          APPEND LS_APPROVER TO RT_APPROVERS.
        ENDIF.

      ENDLOOP.

    ENDLOOP.

    SORT RT_APPROVERS BY SEQUENCE ASCENDING BNAME ASCENDING.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_WF_SD_FINDER->GET_APPROVERS_WF
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_WF_TYPE                     TYPE        ZWF_TYPE
* | [--->] IV_BUKRS                       TYPE        BUKRS
* | [--->] IV_CREDIT_GROUP                TYPE        UKM_CRED_GROUP
* | [--->] IV_RANGE_CODE                  TYPE        ZRANGE_CODE
* | [--->] IV_VBELN                       TYPE        VBELN_VA(optional)
* | [<-()] RT_USERS                       TYPE        ZWF_USERS_TY
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD GET_APPROVERS_WF.

    DATA(LT_KEYS) = BUILD_KEYS( IV_WF_TYPE      = IV_WF_TYPE
                                IV_BUKRS        = IV_BUKRS
                                IV_CREDIT_GROUP = IV_CREDIT_GROUP
                                IV_RANGE_CODE   = IV_RANGE_CODE
                                IV_VBELN        = IV_VBELN ).

    DATA LT_APPROVERS TYPE ZIF_WF_SD_TYPES=>TT_APPROVER.

    TRY.
        LT_APPROVERS = FIND_APPROVERS_MULTI( LT_KEYS ).
      CATCH ZCX_WF_SD.
        CLEAR RT_USERS.
        RETURN.
    ENDTRY.

    LOOP AT LT_APPROVERS INTO DATA(LS_APPROVER).

      APPEND VALUE #( MANDT        = SY-MANDT
                      TYPE         = IV_WF_TYPE
                      CREDIT_GROUP = IV_CREDIT_GROUP
                      RANGE_CODE   = IV_RANGE_CODE
                      SEQUENCE     = LS_APPROVER-SEQUENCE
                      BNAME        = LS_APPROVER-BNAME
                      USER_DESC    = LS_APPROVER-USER_DESC
                      COMPANY_CODE = LS_APPROVER-BUKRS ) TO RT_USERS.

    ENDLOOP.

    SORT RT_USERS ASCENDING BY SEQUENCE.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_SD_FINDER->MAP_LEVEL
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_CONTROL                     TYPE        ZWF_CONTROL
* | [<-()] RV_LEVEL                       TYPE        CHAR1
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD MAP_LEVEL.

    RV_LEVEL = COND #(
      WHEN IS_CONTROL-X_DIV   = ABAP_TRUE THEN ZIF_WF_SD_TYPES=>GC_LEVEL-DIVISION
      WHEN IS_CONTROL-X_PLANT = ABAP_TRUE THEN ZIF_WF_SD_TYPES=>GC_LEVEL-PLANT
      WHEN IS_CONTROL-X_COMP  = ABAP_TRUE THEN ZIF_WF_SD_TYPES=>GC_LEVEL-COMPANY ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_SD_FINDER->MAP_VIEW
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_LEVEL                       TYPE        CHAR1
* | [<-()] RV_VIEW                        TYPE        DD02L-TABNAME
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD MAP_VIEW.

    RV_VIEW = SWITCH #( IV_LEVEL
                WHEN ZIF_WF_SD_TYPES=>GC_LEVEL-COMPANY
                  THEN ZIF_WF_SD_TYPES=>GC_VIEW-COMPANY
                WHEN ZIF_WF_SD_TYPES=>GC_LEVEL-PLANT
                  THEN ZIF_WF_SD_TYPES=>GC_VIEW-PLANT
                WHEN ZIF_WF_SD_TYPES=>GC_LEVEL-DIVISION
                  THEN ZIF_WF_SD_TYPES=>GC_VIEW-DIVISION
                ELSE SPACE ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_WF_SD_FINDER->VALIDATE_KEY
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_KEY                         TYPE        ZIF_WF_SD_TYPES=>TY_KEY
* | [!CX!] ZCX_WF_SD
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD VALIDATE_KEY.

    IF IS_KEY-BUKRS IS INITIAL.
      RAISE EXCEPTION TYPE ZCX_WF_SD
        EXPORTING
          TEXTID = ZCX_WF_SD=>BUKRS_MISSING.
    ENDIF.

    IF MO_READER->TYPE_EXISTS( IS_KEY-WF_TYPE ) = ABAP_FALSE.
      RAISE EXCEPTION TYPE ZCX_WF_SD
        EXPORTING
          TEXTID   = ZCX_WF_SD=>TYPE_NOT_FOUND
          IV_ATTR1 = IS_KEY-WF_TYPE.
    ENDIF.

  ENDMETHOD.
ENDCLASS.