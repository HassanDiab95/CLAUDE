CLASS ZCL_WF_NOTE_READER DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS READ_SOFM
      IMPORTING IV_OBJKEY      TYPE SWOTOBJID-OBJKEY
      RETURNING VALUE(RV_TEXT) TYPE ZWF_NOTE.

    CLASS-METHODS READ_FROM_WI
      IMPORTING IV_WI_ID       TYPE SWW_WIID
      RETURNING VALUE(RV_TEXT) TYPE ZWF_NOTE.

  PRIVATE SECTION.

    CLASS-METHODS LINES_TO_TEXT
      IMPORTING IT_LINES       TYPE SOLI_TAB
      RETURNING VALUE(RV_TEXT) TYPE ZWF_NOTE.
    CLASS-METHODS EXTRACT_DOCUMENT_ID
      IMPORTING
        IV_OBJECT_ID     TYPE STRING
      RETURNING
        VALUE(RV_DOC_ID) TYPE STRING.

ENDCLASS.



CLASS ZCL_WF_NOTE_READER IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Private Method ZCL_WF_NOTE_READER=>EXTRACT_DOCUMENT_ID
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_OBJECT_ID                   TYPE        STRING
* | [<-()] RV_DOC_ID                      TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD EXTRACT_DOCUMENT_ID.
    RV_DOC_ID = SHIFT_LEFT( VAL = IV_OBJECT_ID SUB = 'SOFM' ).
    RV_DOC_ID = CONDENSE( RV_DOC_ID ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Private Method ZCL_WF_NOTE_READER=>LINES_TO_TEXT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IT_LINES                       TYPE        SOLI_TAB
* | [<-()] RV_TEXT                        TYPE        ZWF_NOTE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD LINES_TO_TEXT.

    DATA LV_FULL TYPE STRING.

    LOOP AT IT_LINES INTO DATA(LS_LINE).

      IF LS_LINE-LINE IS INITIAL.
        CONTINUE.
      ENDIF.

      IF LV_FULL IS INITIAL.
        LV_FULL = LS_LINE-LINE.
      ELSE.
        LV_FULL = |{ LV_FULL } { LS_LINE-LINE }|.
      ENDIF.

    ENDLOOP.

    CONDENSE LV_FULL.

    RV_TEXT = LV_FULL.          " truncates at 255, which is fine

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_WF_NOTE_READER=>READ_FROM_WI
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_WI_ID                       TYPE        SWW_WIID
* | [<-()] RV_TEXT                        TYPE        ZWF_NOTE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD READ_FROM_WI.

    IF IV_WI_ID IS INITIAL.
      RETURN.
    ENDIF.

    DATA LT_ATT    TYPE STANDARD TABLE OF SWR_OBJECT.
    DATA LT_RETURN TYPE STANDARD TABLE OF SWR_MESSAG.

    CALL FUNCTION 'SAP_WAPI_GET_ATTACHMENTS'
      EXPORTING
        WORKITEM_ID   = IV_WI_ID
      TABLES
        ATTACHMENTS   = LT_ATT
        MESSAGE_LINES = LT_RETURN.

    IF LT_ATT IS INITIAL.
      RETURN.
    ENDIF.

    DELETE LT_ATT WHERE OBJECT_TYP <> 'CM'.

    IF LT_ATT IS INITIAL.
      RETURN.
    ENDIF.

    READ TABLE LT_ATT INDEX LINES( LT_ATT ) INTO DATA(LS_ATT).


    RV_TEXT = READ_SOFM( CONV #(  EXTRACT_DOCUMENT_ID( CONV STRING( LS_ATT-OBJECT_ID ) ) ) ).
    IF RV_TEXT IS INITIAL.
      RV_TEXT = LS_ATT-DEF_ATTRIB.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_WF_NOTE_READER=>READ_SOFM
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_OBJKEY                      TYPE        SWOTOBJID-OBJKEY
* | [<-()] RV_TEXT                        TYPE        ZWF_NOTE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD READ_SOFM.

    IF IV_OBJKEY IS INITIAL.
      RETURN.
    ENDIF.

    DATA LS_DOC_ID  TYPE SOFOLENTI1.
    DATA LT_CONTENT TYPE STANDARD TABLE OF SOLISTI1.
    DATA LT_LINES   TYPE SOLI_TAB.


    DATA LV_DOC_ID TYPE SOFOLENTI1-DOC_ID.

    LV_DOC_ID = IV_OBJKEY.
    CONDENSE LV_DOC_ID NO-GAPS.

    CALL FUNCTION 'SO_DOCUMENT_READ_API1'
      EXPORTING
        DOCUMENT_ID                = LV_DOC_ID
      IMPORTING
        DOCUMENT_DATA              = LS_DOC_ID
      TABLES
        OBJECT_CONTENT             = LT_CONTENT
      EXCEPTIONS
        DOCUMENT_ID_NOT_EXIST      = 1
        OPERATION_NO_AUTHORIZATION = 2
        X_ERROR                    = 3
        OTHERS                     = 4.

    IF SY-SUBRC <> 0.
      RETURN.
    ENDIF.

    LOOP AT LT_CONTENT INTO DATA(LS_CONTENT).
      APPEND VALUE #( LINE = LS_CONTENT-LINE ) TO LT_LINES.
    ENDLOOP.

    RV_TEXT = LINES_TO_TEXT( LT_LINES ).

  ENDMETHOD.
ENDCLASS.