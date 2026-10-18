CLASS ZCL_SWF_IFS_DECISION_EXIT DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES IF_SWF_IFS_DECISION_EXIT .
    INTERFACES IF_SWF_IFS_WORKITEM_EXIT .

    METHODS HANDLE_USER_SELECTION
      IMPORTING
        !IM_EVENT_NAME       TYPE SWW_EVTTYP OPTIONAL
        !IM_WORKITEM_CONTEXT TYPE REF TO IF_WAPI_WORKITEM_CONTEXT OPTIONAL .
    METHODS GET_DYNAMIC_OPTIONS
      IMPORTING
        !IM_EVENT_NAME       TYPE SWW_EVTTYP
        !IM_WORKITEM_CONTEXT TYPE REF TO IF_WAPI_WORKITEM_CONTEXT
      EXPORTING
        !RT_OPTIONS          TYPE SWRTDECIALTS .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_SWF_IFS_DECISION_EXIT IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_SWF_IFS_DECISION_EXIT->GET_DYNAMIC_OPTIONS
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_EVENT_NAME                  TYPE        SWW_EVTTYP
* | [--->] IM_WORKITEM_CONTEXT            TYPE REF TO IF_WAPI_WORKITEM_CONTEXT
* | [<---] RT_OPTIONS                     TYPE        SWRTDECIALTS
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD GET_DYNAMIC_OPTIONS.

*  DATA: lt_users TYPE TABLE OF ZWF_USERS. " Your table type
*  DATA: lwa_decialt TYPE swr_decialts.
*
*  DATA: CURRENT_LEVEL TYPE INT2.
*
*  " Declare the container reference from the workitem context
*  "im_workitem_context = me->m_wi_context.
*  DATA(lo_container) = im_workitem_context->get_wi_container( ).
*
*  TRY.
*    " Retrieve the table data from the workflow container element 'USER'
*    lo_container->get( EXPORTING name = 'USERS' IMPORTING VALUE = lt_users ).
*    "Get current level to choose from lower levels
*    lo_container->get(  EXPORTING name = 'CURRENT_LEVEL' IMPORTING VALUE = CURRENT_LEVEL ).
*    "clear Approve amd Reject Flags
*    lo_container->SET( EXPORTING NAME = 'APPROVE_FLAG' VALUE = SPACE ).
*    lo_container->SET( EXPORTING NAME = 'REJECT_FLAG' VALUE = SPACE ).
*
*
*  CATCH cx_swf_cnt_elem_not_found.
*    " Handle error if the element is not found
*    " Log an error or return an empty table
*    RETURN.
*  CATCH cx_swf_cnt_elem_type_conflict.
*    " Handle error if there is a type mismatch
*    " Log an error or return an empty table
*    RETURN.
*  CATCH cx_swf_cnt_unit_type_conflict.
*    " Handle other conversion errors
*    " Log an error or return an empty table
*    RETURN.
*  CATCH CX_SWF_CNT_CONTAINER.
*    " Handle error if the element is not found
*    " Log an error or return an empty table
*    RETURN.
*
*  ENDTRIMY.
*
*  " Loop through the retrieved user data and build the decision options
*  DATA: ls_user TYPE ZWF_USERS.
*  LOOP AT lt_users INTO ls_user WHERE SEQUENCE <= CURRENT_LEVEL.
*
*    lwa_decialt-altkey = ls_user-SEQUENCE.      " Example: use the user ID as the key
*    lwa_decialt-alttext = ls_user-user_desc."|User { ls_user-userid } - { ls_user-fullname }|. " Example: concatenate fields for display
*
*    APPEND lwa_decialt TO rt_options.
*  ENDLOOP.





    DATA: LT_HEADER        TYPE TABLE OF SWWWIHEAD,
          LS_HEADER        TYPE SWWWIHEAD,
          LV_TOP_WI_ID     TYPE SWW_WIID,
          LT_WF_CONTAINER  TYPE TABLE OF SWR_CONT,  " Workflow container
          LT_USERS         TYPE ZWF_USERS_TY,       " Table type for USERS
          CURRENT_LEVEL    TYPE INT2,
          LWA_DECIALT      TYPE SWR_DECIALTS,
          LS_USERS         TYPE ZWF_USERS,         " Line type of ZWF_USER_TY
          LT_USERS_WI      TYPE ZWF_USERS_WI_TY,
          LS_USERS_WI      TYPE ZWF_USERS_WI,
          LV_RETURN_CODE   TYPE SYSUBRC,
          LV_VALUE         TYPE SWR_CONT-VALUE,    " Buffer for scalar values
          LV_ERROR_MESSAGE TYPE STRING.

    " Step 1: Get the current work item ID
    TRY.
        DATA(LV_CURRENT_WI_ID) = IM_WORKITEM_CONTEXT->GET_WORKITEM_ID( ).
      CATCH CX_ROOT INTO DATA(LX_ROOT).
        LV_ERROR_MESSAGE = |Error getting work item ID: { LX_ROOT->GET_TEXT( ) }|.
        MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
        CLEAR LWA_DECIALT.
        LWA_DECIALT-ALTKEY = '0001'.
        LWA_DECIALT-ALTTEXT = 'Error retrieving work item ID'.
        "APPEND lwa_decialt TO rt_options.
        RETURN.
    ENDTRY.

    " Step 2: Read the work item header to get the top-level workflow work item ID
    TRY.
        CALL FUNCTION 'SWW_WI_HEADER_READ'
          EXPORTING
            WI_ID                = LV_CURRENT_WI_ID
          IMPORTING
            WI_HEADER            = LS_HEADER
          EXCEPTIONS
            ERROR_READING_HEADER = 1
            OTHERS               = 2.
        IF SY-SUBRC <> 0.
          LV_ERROR_MESSAGE = |Error reading work item header for WI_ID { LV_CURRENT_WI_ID }, SY-SUBRC: { SY-SUBRC }|.
          MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
          CLEAR LWA_DECIALT.
          LWA_DECIALT-ALTKEY = '0001'.
          LWA_DECIALT-ALTTEXT = 'Error reading work item header'.
          "APPEND lwa_decialt TO rt_options.
          RETURN.
        ENDIF.
      CATCH CX_SY_DYN_CALL_PARAM_NOT_FOUND INTO DATA(LX_PARAM_ERROR).
        LV_ERROR_MESSAGE = |Parameter error in SWW_WI_HEADER_READ: { LX_PARAM_ERROR->GET_TEXT( ) }|.
        MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
        CLEAR LWA_DECIALT.
        LWA_DECIALT-ALTKEY = '0001'.
        LWA_DECIALT-ALTTEXT = 'Parameter error in header read'.
        "APPEND lwa_decialt TO rt_options.
        RETURN.
      CATCH CX_ROOT INTO LX_ROOT.
        LV_ERROR_MESSAGE = |Unexpected error in SWW_WI_HEADER_READ: { LX_ROOT->GET_TEXT( ) }|.
        MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
        CLEAR LWA_DECIALT.
        LWA_DECIALT-ALTKEY = '0001'.
        LWA_DECIALT-ALTTEXT = 'Unexpected error in header read'.
        "APPEND lwa_decialt TO rt_options.
        RETURN.
    ENDTRY.

*  READ TABLE lt_header INTO ls_header INDEX 1.
*  IF sy-subrc <> 0.
*    lv_error_message = |No header found for WI_ID { lv_current_wi_id }|.
*    MESSAGE lv_error_message TYPE 'E'.
*    CLEAR lwa_decialt.
*    lwa_decialt-altkey = '0001'.
*    lwa_decialt-alttext = 'No work item header found'.
*    APPEND lwa_decialt TO rt_options.
*    RETURN.
*  ENDIF.
    LV_TOP_WI_ID = LS_HEADER-TOP_WI_ID.

    " Step 3: Read the workflow container
    CLEAR LT_WF_CONTAINER.
    TRY.
        CALL FUNCTION 'SAP_WAPI_READ_CONTAINER'
          EXPORTING
            WORKITEM_ID             = LV_TOP_WI_ID
          TABLES
            SIMPLE_CONTAINER        = LT_WF_CONTAINER
          EXCEPTIONS
            ERROR_READING_CONTAINER = 1
            OTHERS                  = 2.
        IF SY-SUBRC <> 0.
          LV_ERROR_MESSAGE = |Error reading workflow container for WI_ID { LV_TOP_WI_ID }, SY-SUBRC: { SY-SUBRC }|.
          MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
          CLEAR LWA_DECIALT.
          LWA_DECIALT-ALTKEY = '0001'.
          LWA_DECIALT-ALTTEXT = 'Error reading workflow container'.
          "APPEND lwa_decialt TO rt_options.
          RETURN.
        ENDIF.
      CATCH CX_SY_DYN_CALL_PARAM_NOT_FOUND INTO LX_PARAM_ERROR.
        LV_ERROR_MESSAGE = |Parameter error in SAP_WAPI_READ_CONTAINER: { LX_PARAM_ERROR->GET_TEXT( ) }|.
        MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
        CLEAR LWA_DECIALT.
        LWA_DECIALT-ALTKEY = '0001'.
        LWA_DECIALT-ALTTEXT = 'Parameter error in container read'.
        "APPEND lwa_decialt TO rt_options.
        RETURN.
      CATCH CX_ROOT INTO LX_ROOT.
        LV_ERROR_MESSAGE = |Unexpected error in SAP_WAPI_READ_CONTAINER: { LX_ROOT->GET_TEXT( ) }|.
        MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
        CLEAR LWA_DECIALT.
        LWA_DECIALT-ALTKEY = '0001'.
        LWA_DECIALT-ALTTEXT = 'Unexpected error in container read'.
        "APPEND lwa_decialt TO rt_options.
        RETURN.
    ENDTRY.

    " Step 4: Retrieve 'USERS' table from workflow container
    CLEAR LT_USERS.
    CLEAR LT_USERS_WI.
    "READ TABLE lt_wf_container INTO DATA(ls_container) WITH KEY element = 'USERS'.
    LOOP AT LT_WF_CONTAINER INTO DATA(LS_CONTAINER) WHERE ELEMENT = 'USERS'.
      TRY.
          " Deserialize the table into ZWF_USER_TY
          CALL TRANSFORMATION ID
            SOURCE XML = LS_CONTAINER-VALUE
            RESULT TAB = LS_USERS.
          CLEAR LS_USERS.
          LS_USERS-MANDT = LS_CONTAINER-VALUE+0(3)."4001001071LABS_MARAKBYSALES MANAGER
          LS_USERS-TYPE = LS_CONTAINER-VALUE+3(1).
          LS_USERS-CREDIT_GROUP = LS_CONTAINER-VALUE+4(4).
          LS_USERS-RANGE_CODE = LS_CONTAINER-VALUE+8(1).
          LS_USERS-SEQUENCE = LS_CONTAINER-VALUE+9(1).
          LS_USERS-BNAME = LS_CONTAINER-VALUE+10(12).
          LS_USERS-USER_DESC = LS_CONTAINER-VALUE+22(30).

          APPEND LS_USERS TO LT_USERS.
        CATCH CX_TRANSFORMATION_ERROR INTO DATA(LX_TRANSFORM_ERROR).
          LV_ERROR_MESSAGE = |Deserialization error for USERS: { LX_TRANSFORM_ERROR->GET_TEXT( ) }|.
          MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
          CLEAR LWA_DECIALT.
          LWA_DECIALT-ALTKEY = '0001'.
          LWA_DECIALT-ALTTEXT = 'Error deserializing USERS table'.
          "APPEND lwa_decialt TO rt_options.
          RETURN.
        CATCH CX_ROOT INTO LX_ROOT.
          LV_ERROR_MESSAGE = |Unexpected error deserializing USERS: { LX_ROOT->GET_TEXT( ) }|.
          MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
          CLEAR LWA_DECIALT.
          LWA_DECIALT-ALTKEY = '0001'.
          LWA_DECIALT-ALTTEXT = 'Unexpected error deserializing USERS'.
          "APPEND lwa_decialt TO rt_options.
          RETURN.
      ENDTRY.
    ENDLOOP.

    LOOP AT LT_WF_CONTAINER INTO DATA(LS_CONTAINER_WI) WHERE ELEMENT = 'USERS_WI'.
      TRY.
          " Deserialize the table into ZWF_USER_TY
          CALL TRANSFORMATION ID
            SOURCE XML = LS_CONTAINER_WI-VALUE
            RESULT TAB = LS_USERS_WI.

          CLEAR LS_USERS_WI.
          LS_USERS_WI-SEQUENCE = LS_CONTAINER_WI-VALUE(1).
          LS_USERS_WI-USER_DESC = LS_CONTAINER_WI-VALUE+1(30)." = ls_container-value+0(3)."4001001071LABS_MARAKBYSALES MANAGER
          CONDENSE LS_USERS_WI-USER_DESC.
          APPEND LS_USERS_WI TO LT_USERS_WI.
        CATCH CX_TRANSFORMATION_ERROR INTO DATA(LX_TRANSFORM_ERROR2).
          LV_ERROR_MESSAGE = |Deserialization error for USERS: { LX_TRANSFORM_ERROR2->GET_TEXT( ) }|.
          MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
          CLEAR LWA_DECIALT.
          LWA_DECIALT-ALTKEY = '0001'.
          LWA_DECIALT-ALTTEXT = 'Error deserializing USERS table'.
          "APPEND lwa_decialt TO rt_options.
          RETURN.
        CATCH CX_ROOT INTO LX_ROOT.
          LV_ERROR_MESSAGE = |Unexpected error deserializing USERS: { LX_ROOT->GET_TEXT( ) }|.
          MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
          CLEAR LWA_DECIALT.
          LWA_DECIALT-ALTKEY = '0001'.
          LWA_DECIALT-ALTTEXT = 'Unexpected error deserializing USERS'.
          "APPEND lwa_decialt TO rt_options.
          RETURN.
      ENDTRY.
    ENDLOOP.



    " Step 5: Retrieve 'CURRENT_LEVEL' from workflow container
    CLEAR CURRENT_LEVEL.
    READ TABLE LT_WF_CONTAINER INTO LS_CONTAINER WITH KEY ELEMENT = 'CURRENT_LEVEL'.
    IF SY-SUBRC = 0 AND LS_CONTAINER-VALUE IS NOT INITIAL.
      TRY.
          CURRENT_LEVEL = LS_CONTAINER-VALUE. " Convert to INT2
        CATCH CX_SY_CONVERSION_ERROR INTO DATA(LX_CONV_ERROR).
          LV_ERROR_MESSAGE = |Conversion error for CURRENT_LEVEL: { LX_CONV_ERROR->GET_TEXT( ) }|.
          MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
          CLEAR LWA_DECIALT.
          LWA_DECIALT-ALTKEY = '0001'.
          LWA_DECIALT-ALTTEXT = 'Error converting CURRENT_LEVEL'.
          "APPEND lwa_decialt TO rt_options.
          RETURN.
        CATCH CX_ROOT INTO LX_ROOT.
          LV_ERROR_MESSAGE = |Unexpected error converting CURRENT_LEVEL: { LX_ROOT->GET_TEXT( ) }|.
          MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
          CLEAR LWA_DECIALT.
          LWA_DECIALT-ALTKEY = '0001'.
          LWA_DECIALT-ALTTEXT = 'Unexpected error converting CURRENT_LEVEL'.
          "APPEND lwa_decialt TO rt_options.
          RETURN.
      ENDTRY.
    ELSE.
      LV_ERROR_MESSAGE = |CURRENT_LEVEL element not found or empty|.
      MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
      CLEAR LWA_DECIALT.
      LWA_DECIALT-ALTKEY = '0001'.
      LWA_DECIALT-ALTTEXT = 'CURRENT_LEVEL not found'.
      "APPEND lwa_decialt TO rt_options.
      RETURN.
    ENDIF.

    " Step 6: Clear flags in workflow container
    CLEAR LS_CONTAINER.
    READ TABLE LT_WF_CONTAINER ASSIGNING FIELD-SYMBOL(<FS_CONTAINER>) WITH KEY ELEMENT = 'APPROVE_FLAG'.
    IF SY-SUBRC = 0.
      <FS_CONTAINER>-VALUE = SPACE.
    ELSE.
      CLEAR LS_CONTAINER.
      LS_CONTAINER-ELEMENT = 'APPROVE_FLAG'.
      LS_CONTAINER-VALUE = SPACE.
      APPEND LS_CONTAINER TO LT_WF_CONTAINER.
    ENDIF.

    CLEAR LS_CONTAINER.
    READ TABLE LT_WF_CONTAINER ASSIGNING <FS_CONTAINER> WITH KEY ELEMENT = 'REJECT_FLAG'.
    IF SY-SUBRC = 0.
      <FS_CONTAINER>-VALUE = SPACE.
    ELSE.
      CLEAR LS_CONTAINER.
      LS_CONTAINER-ELEMENT = 'REJECT_FLAG'.
      LS_CONTAINER-VALUE = SPACE.
      APPEND LS_CONTAINER TO LT_WF_CONTAINER.
    ENDIF.

    " Step 7: Write the updated workflow container back
    TRY.
        CALL FUNCTION 'SAP_WAPI_WRITE_CONTAINER'
          EXPORTING
            WORKITEM_ID             = LV_TOP_WI_ID
          IMPORTING
            RETURN_CODE             = LV_RETURN_CODE
          TABLES
            SIMPLE_CONTAINER        = LT_WF_CONTAINER
          EXCEPTIONS
            ERROR_WRITING_CONTAINER = 1
            OTHERS                  = 2.
        IF LV_RETURN_CODE <> 0 OR SY-SUBRC <> 0.
*        lv_error_message = |Error writing to workflow container for WI_ID { lv_top_wi_id }, RETURN_CODE: { lv_return_code }|.
*        MESSAGE lv_error_message TYPE 'E'.
*        CLEAR lwa_decialt.
*        lwa_decialt-altkey = '0001'.
*        lwa_decialt-alttext = 'Error writing to container'.
*        APPEND lwa_decialt TO rt_options.
*        RETURN.
        ENDIF.
      CATCH CX_SY_DYN_CALL_PARAM_NOT_FOUND INTO LX_PARAM_ERROR.
        LV_ERROR_MESSAGE = |Parameter error in SAP_WAPI_WRITE_CONTAINER: { LX_PARAM_ERROR->GET_TEXT( ) }|.
        MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
        CLEAR LWA_DECIALT.
        LWA_DECIALT-ALTKEY = '0001'.
        LWA_DECIALT-ALTTEXT = 'Parameter error in container write'.
        "APPEND lwa_decialt TO rt_options.
        RETURN.
      CATCH CX_ROOT INTO LX_ROOT.
        LV_ERROR_MESSAGE = |Unexpected error in SAP_WAPI_WRITE_CONTAINER: { LX_ROOT->GET_TEXT( ) }|.
        MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
        CLEAR LWA_DECIALT.
        LWA_DECIALT-ALTKEY = '0001'.
        LWA_DECIALT-ALTTEXT = 'Unexpected error in container write'.
        "APPEND lwa_decialt TO rt_options.
        RETURN.
    ENDTRY.

    " Step 8: Build dynamic decision options from filtered USERS table
    CLEAR RT_OPTIONS.
*  LOOP AT lt_users INTO ls_users WHERE sequence <= current_level.
*    lwa_decialt-altkey  = ls_users-sequence.  " Use sequence as the key
*    lwa_decialt-alttext = |{ ls_users-user_desc }|.  " Customize as needed
*    APPEND lwa_decialt TO rt_options.
*  ENDLOOP.

    LOOP AT LT_USERS_WI INTO LS_USERS_WI WHERE SEQUENCE <= CURRENT_LEVEL.
      READ TABLE RT_OPTIONS INTO LWA_DECIALT WITH TABLE KEY
      ALTKEY = LS_USERS_WI-SEQUENCE ALTTEXT = LS_USERS_WI-USER_DESC ALTNATURE = '' .
      IF SY-SUBRC = 0.
        CONTINUE.
      ELSE.
        LWA_DECIALT-ALTKEY  = LS_USERS_WI-SEQUENCE.  " Use sequence as the key
        LWA_DECIALT-ALTTEXT = |{ LS_USERS_WI-USER_DESC }|.
        APPEND LWA_DECIALT TO RT_OPTIONS.
      ENDIF.

    ENDLOOP.


    " Step 9: Ensure at least one option is returned
    IF RT_OPTIONS IS INITIAL.
*    lv_error_message = |No valid users found for CURRENT_LEVEL { current_level }|.
*    MESSAGE lv_error_message TYPE 'E'.
*    CLEAR lwa_decialt.
*    lwa_decialt-altkey = '0001'.
*    lwa_decialt-alttext = 'No users available'.
      "APPEND lwa_decialt TO rt_options.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_SWF_IFS_DECISION_EXIT->HANDLE_USER_SELECTION
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_EVENT_NAME                  TYPE        SWW_EVTTYP(optional)
* | [--->] IM_WORKITEM_CONTEXT            TYPE REF TO IF_WAPI_WORKITEM_CONTEXT(optional)
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD HANDLE_USER_SELECTION.
    DATA: "lo_container TYPE REF TO if_swf_cnt_container,
          LV_DECISION_KEY TYPE SWR_DECIALTS-ALTKEY.

    DATA: MY_DESCISION TYPE INT2.

    TRY.
        " Get the work item container object
        DATA(LO_CONTAINER) = IM_WORKITEM_CONTEXT->GET_WI_CONTAINER( ).

        " Read the decision result key from the standard container element '_WI_RESULT'
        LO_CONTAINER->GET( EXPORTING NAME = '_WI_RESULT' IMPORTING VALUE = LV_DECISION_KEY ).

        MY_DESCISION = LV_DECISION_KEY.
        "lo_container->set( EXPORTING name = '_WI_RESULT'  VALUE = '000' ).
        "SHIFT LV_DECISION_KEY LEFT DELETING LEADING '0'.
        "lo_container->SET( EXPORTING NAME = 'CURRENT_LEVEL' VALUE = MY_DESCISION ).


      CATCH CX_SWF_CNT_ELEM_NOT_FOUND.
        " Handle error if the element is not found
        " Log an error or return an empty table
        RETURN.
      CATCH CX_SWF_CNT_ELEM_TYPE_CONFLICT.
        " Handle error if there is a type mismatch
        " Log an error or return an empty table
        RETURN.
      CATCH CX_SWF_CNT_UNIT_TYPE_CONFLICT.
        " Handle other conversion errors
        " Log an error or return an empty table
        RETURN.
      CATCH CX_SWF_CNT_CONTAINER.
        " Handle error if the element is not found
        " Log an error or return an empty table
        RETURN.
    ENDTRY.

    DATA: LT_HEADER        TYPE TABLE OF SWWWIHEAD,
          LS_HEADER        TYPE SWWWIHEAD,
          LV_TOP_WI_ID     TYPE SWW_WIID,
          LT_WF_CONTAINER  TYPE TABLE OF SWR_CONT,  " Workflow container
          LS_CONTAINER     TYPE SWR_CONT,  " Workflow container
          LT_USERS         TYPE ZWF_USERS_TY,       " Table type for USERS
          CURRENT_LEVEL    TYPE INT2,
          LWA_DECIALT      TYPE SWR_DECIALTS,
          LS_USERS         TYPE ZWF_USERS,         " Line type of ZWF_USER_TY
          LV_RETURN_CODE   TYPE SYSUBRC,
          LV_VALUE         TYPE SWR_CONT-VALUE,    " Buffer for scalar values
          LV_ERROR_MESSAGE TYPE STRING.


    " Step 1: Get the current work item ID
    TRY.
        DATA(LV_CURRENT_WI_ID) = IM_WORKITEM_CONTEXT->GET_WORKITEM_ID( ).
      CATCH CX_ROOT INTO DATA(LX_ROOT).
        LV_ERROR_MESSAGE = |Error getting WORK item ID: { LX_ROOT->GET_TEXT( ) }|.
        MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
        CLEAR LWA_DECIALT.
        LWA_DECIALT-ALTKEY = '0001'.
        LWA_DECIALT-ALTTEXT = 'Error retrieving work item ID'.

        RETURN.
    ENDTRY.

    " Step 2: Read the work item header to get the top-level workflow work item ID
    TRY.
        CALL FUNCTION 'SWW_WI_HEADER_READ'
          EXPORTING
            WI_ID                = LV_CURRENT_WI_ID
          IMPORTING
            WI_HEADER            = LS_HEADER
          EXCEPTIONS
            ERROR_READING_HEADER = 1
            OTHERS               = 2.
        IF SY-SUBRC <> 0.
          LV_ERROR_MESSAGE = |Error reading WORK item HEADER FOR WI_ID { LV_CURRENT_WI_ID }, SY-SUBRC: { SY-SUBRC }|.
          MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
          CLEAR LWA_DECIALT.
          LWA_DECIALT-ALTKEY = '0001'.
          LWA_DECIALT-ALTTEXT = 'Error reading work item header'.

          RETURN.
        ENDIF.
      CATCH CX_SY_DYN_CALL_PARAM_NOT_FOUND INTO DATA(LX_PARAM_ERROR).
        LV_ERROR_MESSAGE = |PARAMETER error IN SWW_WI_HEADER_READ: { LX_PARAM_ERROR->GET_TEXT( ) }|.
        MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
        CLEAR LWA_DECIALT.
        LWA_DECIALT-ALTKEY = '0001'.
        LWA_DECIALT-ALTTEXT = 'Parameter error in header read'.

        RETURN.
      CATCH CX_ROOT INTO LX_ROOT.
        LV_ERROR_MESSAGE = |Unexpected error IN SWW_WI_HEADER_READ: { LX_ROOT->GET_TEXT( ) }|.
        MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
        CLEAR LWA_DECIALT.
        LWA_DECIALT-ALTKEY = '0001'.
        LWA_DECIALT-ALTTEXT = 'Unexpected error in header read'.

        RETURN.
    ENDTRY.

*  READ TABLE lt_header INTO ls_header INDEX 1.
*  IF sy-subrc <> 0.
*    lv_error_message = |No header found for WI_ID { lv_current_wi_id }|.
*    MESSAGE lv_error_message TYPE 'E'.
*    CLEAR lwa_decialt.
*    lwa_decialt-altkey = '0001'.
*    lwa_decialt-alttext = 'No work item header found'.
*    APPEND lwa_decialt TO rt_options.
*    RETURN.
*  ENDIF.
    LV_TOP_WI_ID = LS_HEADER-TOP_WI_ID.

    " Step 3: Read the workflow container
    CLEAR LT_WF_CONTAINER.
    TRY.
        CALL FUNCTION 'SAP_WAPI_READ_CONTAINER'
          EXPORTING
            WORKITEM_ID             = LV_TOP_WI_ID
          TABLES
            SIMPLE_CONTAINER        = LT_WF_CONTAINER
          EXCEPTIONS
            ERROR_READING_CONTAINER = 1
            OTHERS                  = 2.
        IF SY-SUBRC <> 0.
          LV_ERROR_MESSAGE = |Error reading workflow container FOR WI_ID { LV_TOP_WI_ID }, SY-SUBRC: { SY-SUBRC }|.
          MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
          CLEAR LWA_DECIALT.
          LWA_DECIALT-ALTKEY = '0001'.
          LWA_DECIALT-ALTTEXT = 'Error reading workflow container'.

          RETURN.
        ENDIF.
      CATCH CX_SY_DYN_CALL_PARAM_NOT_FOUND INTO LX_PARAM_ERROR.
        LV_ERROR_MESSAGE = |PARAMETER error IN SAP_WAPI_READ_CONTAINER: { LX_PARAM_ERROR->GET_TEXT( ) }|.
        MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
        CLEAR LWA_DECIALT.
        LWA_DECIALT-ALTKEY = '0001'.
        LWA_DECIALT-ALTTEXT = 'Parameter error in container read'.

        RETURN.
      CATCH CX_ROOT INTO LX_ROOT.
        LV_ERROR_MESSAGE = |Unexpected error IN SAP_WAPI_READ_CONTAINER: { LX_ROOT->GET_TEXT( ) }|.
        MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
        CLEAR LWA_DECIALT.
        LWA_DECIALT-ALTKEY = '0001'.
        LWA_DECIALT-ALTTEXT = 'Unexpected error in container read'.

        RETURN.
    ENDTRY.

    CLEAR LS_CONTAINER.


*--- Begin of Enhancement | Hassan Diab | workflow log -----------------
    DATA LV_OLD_LEVEL TYPE INT2.
    DATA LV_LOG_ID    TYPE ZWF_LOG_ID.
    DATA LV_NOTE      TYPE ZWF_NOTE.

    READ TABLE LT_WF_CONTAINER INTO LS_CONTAINER
         WITH KEY ELEMENT = 'CURRENT_LEVEL'.
    IF SY-SUBRC = 0.
      LV_OLD_LEVEL = LS_CONTAINER-VALUE.
    ENDIF.

    READ TABLE LT_WF_CONTAINER INTO LS_CONTAINER
         WITH KEY ELEMENT = 'LOG_ID'.
    IF SY-SUBRC = 0.
      LV_LOG_ID = LS_CONTAINER-VALUE.
    ENDIF.

    READ TABLE LT_WF_CONTAINER INTO LS_CONTAINER
         WITH KEY ELEMENT = 'DECISION_NOTE'.
    IF SY-SUBRC = 0.
      LV_NOTE = LS_CONTAINER-VALUE.
    ENDIF.

    DATA(LO_LOG) = NEW ZCL_WF_LOG_CL( ).

    " fallback when LOG_ID is not bound into the task
    IF LV_LOG_ID IS INITIAL.
      LV_LOG_ID = LO_LOG->FIND_OPEN( LV_TOP_WI_ID ).
    ENDIF.
*--- End of Enhancement -----------------------------------------------







    READ TABLE LT_WF_CONTAINER ASSIGNING FIELD-SYMBOL(<FS_CONTAINER>) WITH KEY ELEMENT = 'CURRENT_LEVEL'.
    IF SY-SUBRC = 0.
      <FS_CONTAINER>-VALUE = MY_DESCISION.
      CONDENSE <FS_CONTAINER>-VALUE.
    ENDIF.

    " Step 7: Write the updated workflow container back
    TRY.
        CALL FUNCTION 'SAP_WAPI_WRITE_CONTAINER'
          EXPORTING
            WORKITEM_ID             = LV_TOP_WI_ID
            DO_COMMIT               = ''
          IMPORTING
            RETURN_CODE             = LV_RETURN_CODE
          TABLES
            SIMPLE_CONTAINER        = LT_WF_CONTAINER
          EXCEPTIONS
            ERROR_WRITING_CONTAINER = 1
            OTHERS                  = 2.
        IF LV_RETURN_CODE <> 0 OR SY-SUBRC <> 0.
*        lv_error_message = |Error writing to workflow container for WI_ID { lv_top_wi_id }, RETURN_CODE: { lv_return_code }|.
*        MESSAGE lv_error_message TYPE 'E'.
*        CLEAR lwa_decialt.
*        lwa_decialt-altkey = '0001'.
*        lwa_decialt-alttext = 'Error writing to container'.
*        APPEND lwa_decialt TO rt_options.
*        RETURN.
        ENDIF.
      CATCH CX_SY_DYN_CALL_PARAM_NOT_FOUND INTO LX_PARAM_ERROR.
        LV_ERROR_MESSAGE = |Parameter error in SAP_WAPI_WRITE_CONTAINER: { LX_PARAM_ERROR->GET_TEXT( ) }|.
        MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
        CLEAR LWA_DECIALT.
        LWA_DECIALT-ALTKEY = '0001'.
        LWA_DECIALT-ALTTEXT = 'Parameter error in container write'.
        "APPEND lwa_decialt TO rt_options.
        RETURN.
      CATCH CX_ROOT INTO LX_ROOT.
        LV_ERROR_MESSAGE = |Unexpected error in SAP_WAPI_WRITE_CONTAINER: { LX_ROOT->GET_TEXT( ) }|.
        MESSAGE LV_ERROR_MESSAGE TYPE 'E'.
        CLEAR LWA_DECIALT.
        LWA_DECIALT-ALTKEY = '0001'.
        LWA_DECIALT-ALTTEXT = 'Unexpected error in container write'.
        "APPEND lwa_decialt TO rt_options.
        RETURN.
    ENDTRY.

*--- Begin of Enhancement | Hassan Diab | workflow log -----------------
    " GET_DYNAMIC_OPTIONS offers sequence <= current level, so the
    " approver can pick their OWN level - that is not a return
    IF LV_LOG_ID IS NOT INITIAL AND MY_DESCISION < LV_OLD_LEVEL.
      LV_NOTE = ZCL_WF_NOTE_READER=>READ_FROM_WI( LV_CURRENT_WI_ID ).
      LO_LOG->ADD_ITEM(
        IV_LOG_ID     = LV_LOG_ID
        IV_ACTION     = ZCL_WF_LOG_CL=>GC_ACTION-RETURN
        IV_WI_ID      = LV_CURRENT_WI_ID
        IV_LEVEL_FROM = LV_OLD_LEVEL
        IV_LEVEL_TO   = MY_DESCISION
        IV_AGENT      = SY-UNAME
        IV_NOTE       = |Returned from level { LV_OLD_LEVEL } to | &&
                        |{ MY_DESCISION }. { LV_NOTE }| ).

      LO_LOG->SET_LEVEL( IV_LOG_ID = LV_LOG_ID
                         IV_LEVEL  = MY_DESCISION ).

    ENDIF.
*--- End of Enhancement -----------------------------------------------
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_SWF_IFS_DECISION_EXIT->IF_SWF_IFS_WORKITEM_EXIT~EVENT_RAISED
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_EVENT_NAME                  TYPE        SWW_EVTTYP
* | [--->] IM_WORKITEM_CONTEXT            TYPE REF TO IF_WAPI_WORKITEM_CONTEXT
* | [!CX!] CX_SWF_IFS_WORKITEM_EXIT_ERROR
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD IF_SWF_IFS_WORKITEM_EXIT~EVENT_RAISED.
  DATA: LT_DECIALTS TYPE SWRTDECIALTS,
        LWA_DECIALT TYPE SWR_DECIALTS.

  " Check if the event is raised before the decision screen is shown
  IF IM_EVENT_NAME = IF_SWF_IFS_DECISION_EXIT~C_EVTTYP_BEFORE_DECISION.
    " Retrieve list of options from a custom table or dynamic logic
    CALL METHOD GET_DYNAMIC_OPTIONS
      EXPORTING
        IM_WORKITEM_CONTEXT = IM_WORKITEM_CONTEXT
        IM_EVENT_NAME       = IM_EVENT_NAME
      IMPORTING
        RT_OPTIONS          = DATA(LT_DYNAMIC_OPTIONS).
    "DATA(lt_dynamic_options) = get_dynamic_options( ). " Custom ABAP method




    " Clear standard options and build new ones
    CLEAR LT_DECIALTS.
    LOOP AT LT_DYNAMIC_OPTIONS INTO LWA_DECIALT.
      APPEND LWA_DECIALT TO LT_DECIALTS.
    ENDLOOP.

    " Set the new decision options in the work item context
    IM_WORKITEM_CONTEXT->SET_DECISION_ALTS( IT_DECIALTS = LT_DECIALTS ).

    " Handle event after the decision is made
  ELSEIF IM_EVENT_NAME = IF_SWF_IFS_WORKITEM_EXIT~C_EVTTYP_AFTER_ACTION OR IM_EVENT_NAME = IF_SWF_IFS_WORKITEM_EXIT~C_EVTTYP_AFTER_EXECUTION."AFT_EXEC.
    CALL METHOD HANDLE_USER_SELECTION
      EXPORTING
        IM_WORKITEM_CONTEXT = IM_WORKITEM_CONTEXT.
  ENDIF.


ENDMETHOD.
ENDCLASS.