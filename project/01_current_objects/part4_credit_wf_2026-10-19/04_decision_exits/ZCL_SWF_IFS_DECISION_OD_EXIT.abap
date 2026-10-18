class ZCL_SWF_IFS_DECISION_OD_EXIT definition
  public
  final
  create public .

public section.

  interfaces IF_SWF_IFS_DECISION_EXIT .
  interfaces IF_SWF_IFS_WORKITEM_EXIT .

  methods HANDLE_USER_SELECTION
    importing
      !IM_EVENT_NAME type SWW_EVTTYP optional
      !IM_WORKITEM_CONTEXT type ref to IF_WAPI_WORKITEM_CONTEXT optional .
  methods GET_DYNAMIC_OPTIONS
    importing
      !IM_EVENT_NAME type SWW_EVTTYP
      !IM_WORKITEM_CONTEXT type ref to IF_WAPI_WORKITEM_CONTEXT
    exporting
      !RT_OPTIONS type SWRTDECIALTS .
protected section.
private section.
ENDCLASS.



CLASS ZCL_SWF_IFS_DECISION_OD_EXIT IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_SWF_IFS_DECISION_OD_EXIT->GET_DYNAMIC_OPTIONS
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





  DATA: lt_header           TYPE TABLE OF swwwihead,
        ls_header           TYPE swwwihead,
        lv_top_wi_id        TYPE sww_wiid,
        lt_wf_container     TYPE TABLE OF swr_cont,  " Workflow container
        lt_users            TYPE zwf_users_ty,       " Table type for USERS
        current_level       TYPE int2,
        lwa_decialt         TYPE swr_decialts,
        ls_users             TYPE zwf_users,         " Line type of ZWF_USER_TY
        lt_users_wi         TYPE ZWF_USERS_WI_TY,
        ls_users_wi         TYPE zwf_users_wi,
        lv_return_code      TYPE sysubrc,
        lv_value            TYPE swr_cont-value,    " Buffer for scalar values
        lv_error_message    TYPE string.

  " Step 1: Get the current work item ID
  TRY.
      DATA(lv_current_wi_id) = im_workitem_context->get_workitem_id( ).
    CATCH cx_root INTO DATA(lx_root).
      lv_error_message = |Error getting work item ID: { lx_root->get_text( ) }|.
      MESSAGE lv_error_message TYPE 'E'.
      CLEAR lwa_decialt.
      lwa_decialt-altkey = '0001'.
      lwa_decialt-alttext = 'Error retrieving work item ID'.
      "APPEND lwa_decialt TO rt_options.
      RETURN.
  ENDTRY.

  " Step 2: Read the work item header to get the top-level workflow work item ID
  TRY.
      CALL FUNCTION 'SWW_WI_HEADER_READ'
        EXPORTING
          wi_id     = lv_current_wi_id
        IMPORTING
          wi_header = ls_header
        EXCEPTIONS
          error_reading_header = 1
          OTHERS              = 2.
      IF sy-subrc <> 0.
        lv_error_message = |Error reading work item header for WI_ID { lv_current_wi_id }, SY-SUBRC: { sy-subrc }|.
        MESSAGE lv_error_message TYPE 'E'.
        CLEAR lwa_decialt.
        lwa_decialt-altkey = '0001'.
        lwa_decialt-alttext = 'Error reading work item header'.
        "APPEND lwa_decialt TO rt_options.
        RETURN.
      ENDIF.
    CATCH cx_sy_dyn_call_param_not_found INTO DATA(lx_param_error).
      lv_error_message = |Parameter error in SWW_WI_HEADER_READ: { lx_param_error->get_text( ) }|.
      MESSAGE lv_error_message TYPE 'E'.
      CLEAR lwa_decialt.
      lwa_decialt-altkey = '0001'.
      lwa_decialt-alttext = 'Parameter error in header read'.
      "APPEND lwa_decialt TO rt_options.
      RETURN.
    CATCH cx_root INTO lx_root.
      lv_error_message = |Unexpected error in SWW_WI_HEADER_READ: { lx_root->get_text( ) }|.
      MESSAGE lv_error_message TYPE 'E'.
      CLEAR lwa_decialt.
      lwa_decialt-altkey = '0001'.
      lwa_decialt-alttext = 'Unexpected error in header read'.
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
  lv_top_wi_id = ls_header-top_wi_id.

  " Step 3: Read the workflow container
  CLEAR lt_wf_container.
  TRY.
      CALL FUNCTION 'SAP_WAPI_READ_CONTAINER'
        EXPORTING
          workitem_id      = lv_top_wi_id
        TABLES
          simple_container = lt_wf_container
        EXCEPTIONS
          error_reading_container = 1
          OTHERS                 = 2.
      IF sy-subrc <> 0.
        lv_error_message = |Error reading workflow container for WI_ID { lv_top_wi_id }, SY-SUBRC: { sy-subrc }|.
        MESSAGE lv_error_message TYPE 'E'.
        CLEAR lwa_decialt.
        lwa_decialt-altkey = '0001'.
        lwa_decialt-alttext = 'Error reading workflow container'.
        "APPEND lwa_decialt TO rt_options.
        RETURN.
      ENDIF.
    CATCH cx_sy_dyn_call_param_not_found INTO lx_param_error.
      lv_error_message = |Parameter error in SAP_WAPI_READ_CONTAINER: { lx_param_error->get_text( ) }|.
      MESSAGE lv_error_message TYPE 'E'.
      CLEAR lwa_decialt.
      lwa_decialt-altkey = '0001'.
      lwa_decialt-alttext = 'Parameter error in container read'.
      "APPEND lwa_decialt TO rt_options.
      RETURN.
    CATCH cx_root INTO lx_root.
      lv_error_message = |Unexpected error in SAP_WAPI_READ_CONTAINER: { lx_root->get_text( ) }|.
      MESSAGE lv_error_message TYPE 'E'.
      CLEAR lwa_decialt.
      lwa_decialt-altkey = '0001'.
      lwa_decialt-alttext = 'Unexpected error in container read'.
      "APPEND lwa_decialt TO rt_options.
      RETURN.
  ENDTRY.

  " Step 4: Retrieve 'USERS' table from workflow container
  CLEAR lt_users.
  CLEAR lt_users_wi.
  "READ TABLE lt_wf_container INTO DATA(ls_container) WITH KEY element = 'USERS'.
  LOOP AT lt_wf_container INTO DATA(ls_container) WHERE element = 'USERS_OD'.
    TRY.
        " Deserialize the table into ZWF_USER_TY
        CALL TRANSFORMATION id
          SOURCE XML = ls_container-value
          RESULT tab = ls_users.
        CLEAR ls_users.
        ls_users-MANDT = ls_container-value+0(3)."4001001071LABS_MARAKBYSALES MANAGER
        ls_users-TYPE = ls_container-value+3(1).
        ls_users-CREDIT_GROUP = ls_container-value+4(4).
        ls_users-RANGE_CODE = ls_container-value+8(1).
        ls_users-SEQUENCE = ls_container-value+9(1).
        ls_users-BNAME = ls_container-value+10(12).
        ls_users-USER_DESC = ls_container-value+22(30).

        APPEND ls_users TO lt_users.
      CATCH cx_transformation_error INTO DATA(lx_transform_error).
        lv_error_message = |Deserialization error for USERS: { lx_transform_error->get_text( ) }|.
        MESSAGE lv_error_message TYPE 'E'.
        CLEAR lwa_decialt.
        lwa_decialt-altkey = '0001'.
        lwa_decialt-alttext = 'Error deserializing USERS table'.
        "APPEND lwa_decialt TO rt_options.
        RETURN.
      CATCH cx_root INTO lx_root.
        lv_error_message = |Unexpected error deserializing USERS: { lx_root->get_text( ) }|.
        MESSAGE lv_error_message TYPE 'E'.
        CLEAR lwa_decialt.
        lwa_decialt-altkey = '0001'.
        lwa_decialt-alttext = 'Unexpected error deserializing USERS'.
        "APPEND lwa_decialt TO rt_options.
        RETURN.
    ENDTRY.
  ENDLOOP.

  LOOP AT lt_wf_container INTO DATA(ls_container_wi) WHERE element = 'USERS_OD_WI'.
    TRY.
        " Deserialize the table into ZWF_USER_TY
        CALL TRANSFORMATION id
          SOURCE XML = ls_container_wi-value
          RESULT tab = ls_users_wi.

        CLEAR ls_users_wi.
        ls_users_wi-SEQUENCE = ls_container_wi-value(1).
        ls_users_wi-USER_DESC = ls_container_wi-value+1(30)." = ls_container-value+0(3)."4001001071LABS_MARAKBYSALES MANAGER
        CONDENSE ls_users_wi-USER_DESC.
        APPEND ls_users_wi TO lt_users_wi.
      CATCH cx_transformation_error INTO DATA(lx_transform_error2).
        lv_error_message = |Deserialization error for USERS: { lx_transform_error2->get_text( ) }|.
        MESSAGE lv_error_message TYPE 'E'.
        CLEAR lwa_decialt.
        lwa_decialt-altkey = '0001'.
        lwa_decialt-alttext = 'Error deserializing USERS table'.
        "APPEND lwa_decialt TO rt_options.
        RETURN.
      CATCH cx_root INTO lx_root.
        lv_error_message = |Unexpected error deserializing USERS: { lx_root->get_text( ) }|.
        MESSAGE lv_error_message TYPE 'E'.
        CLEAR lwa_decialt.
        lwa_decialt-altkey = '0001'.
        lwa_decialt-alttext = 'Unexpected error deserializing USERS'.
        "APPEND lwa_decialt TO rt_options.
        RETURN.
    ENDTRY.
  ENDLOOP.



  " Step 5: Retrieve 'CURRENT_LEVEL_OD' from workflow container
  CLEAR current_level.
  READ TABLE lt_wf_container INTO ls_container WITH KEY element = 'CURRENT_LEVEL_OD'.
  IF sy-subrc = 0 AND ls_container-value IS NOT INITIAL.
    TRY.
        current_level = ls_container-value. " Convert to INT2
      CATCH cx_sy_conversion_error INTO DATA(lx_conv_error).
        lv_error_message = |Conversion error for CURRENT_LEVEL: { lx_conv_error->get_text( ) }|.
        MESSAGE lv_error_message TYPE 'E'.
        CLEAR lwa_decialt.
        lwa_decialt-altkey = '0001'.
        lwa_decialt-alttext = 'Error converting CURRENT_LEVEL'.
        "APPEND lwa_decialt TO rt_options.
        RETURN.
      CATCH cx_root INTO lx_root.
        lv_error_message = |Unexpected error converting CURRENT_LEVEL: { lx_root->get_text( ) }|.
        MESSAGE lv_error_message TYPE 'E'.
        CLEAR lwa_decialt.
        lwa_decialt-altkey = '0001'.
        lwa_decialt-alttext = 'Unexpected error converting CURRENT_LEVEL'.
        "APPEND lwa_decialt TO rt_options.
        RETURN.
    ENDTRY.
  ELSE.
    lv_error_message = |CURRENT_LEVEL element not found or empty|.
    MESSAGE lv_error_message TYPE 'E'.
    CLEAR lwa_decialt.
    lwa_decialt-altkey = '0001'.
    lwa_decialt-alttext = 'CURRENT_LEVEL not found'.
    "APPEND lwa_decialt TO rt_options.
    RETURN.
  ENDIF.

  " Step 6: Clear flags in workflow container
  CLEAR ls_container.
  READ TABLE lt_wf_container ASSIGNING FIELD-SYMBOL(<fs_container>) WITH KEY element = 'APPROVE_FLAG'.
  IF sy-subrc = 0.
    <fs_container>-value = space.
  ELSE.
    CLEAR ls_container.
    ls_container-element = 'APPROVE_FLAG'.
    ls_container-value = space.
    APPEND ls_container TO lt_wf_container.
  ENDIF.

  CLEAR ls_container.
  READ TABLE lt_wf_container ASSIGNING <fs_container> WITH KEY element = 'REJECT_FLAG'.
  IF sy-subrc = 0.
    <fs_container>-value = space.
  ELSE.
    CLEAR ls_container.
    ls_container-element = 'REJECT_FLAG'.
    ls_container-value = space.
    APPEND ls_container TO lt_wf_container.
  ENDIF.

  " Step 7: Write the updated workflow container back
  TRY.
      CALL FUNCTION 'SAP_WAPI_WRITE_CONTAINER'
        EXPORTING
          workitem_id      = lv_top_wi_id
        IMPORTING
          return_code      = lv_return_code
        TABLES
          simple_container = lt_wf_container

        EXCEPTIONS
          error_writing_container = 1
          OTHERS                = 2.
      IF lv_return_code <> 0 OR sy-subrc <> 0.
*        lv_error_message = |Error writing to workflow container for WI_ID { lv_top_wi_id }, RETURN_CODE: { lv_return_code }|.
*        MESSAGE lv_error_message TYPE 'E'.
*        CLEAR lwa_decialt.
*        lwa_decialt-altkey = '0001'.
*        lwa_decialt-alttext = 'Error writing to container'.
*        APPEND lwa_decialt TO rt_options.
*        RETURN.
      ENDIF.
    CATCH cx_sy_dyn_call_param_not_found INTO lx_param_error.
      lv_error_message = |Parameter error in SAP_WAPI_WRITE_CONTAINER: { lx_param_error->get_text( ) }|.
      MESSAGE lv_error_message TYPE 'E'.
      CLEAR lwa_decialt.
      lwa_decialt-altkey = '0001'.
      lwa_decialt-alttext = 'Parameter error in container write'.
      "APPEND lwa_decialt TO rt_options.
      RETURN.
    CATCH cx_root INTO lx_root.
      lv_error_message = |Unexpected error in SAP_WAPI_WRITE_CONTAINER: { lx_root->get_text( ) }|.
      MESSAGE lv_error_message TYPE 'E'.
      CLEAR lwa_decialt.
      lwa_decialt-altkey = '0001'.
      lwa_decialt-alttext = 'Unexpected error in container write'.
      "APPEND lwa_decialt TO rt_options.
      RETURN.
  ENDTRY.

  " Step 8: Build dynamic decision options from filtered USERS table
  CLEAR rt_options.
*  LOOP AT lt_users INTO ls_users WHERE sequence <= current_level.
*    lwa_decialt-altkey  = ls_users-sequence.  " Use sequence as the key
*    lwa_decialt-alttext = |{ ls_users-user_desc }|.  " Customize as needed
*    APPEND lwa_decialt TO rt_options.
*  ENDLOOP.

  LOOP AT lt_users_wi INTO ls_users_wi WHERE sequence <= current_level.
    READ TABLE rt_options INTO lwa_decialt WITH TABLE KEY
    altkey = ls_users_wi-sequence ALTTEXT = ls_users_wi-user_desc ALTNATURE = '' .
    IF SY-SUBRC = 0.
      CONTINUE.
    ELSE.
      lwa_decialt-altkey  = ls_users_wi-sequence.  " Use sequence as the key
      lwa_decialt-alttext = |{ ls_users_wi-user_desc }|.
      APPEND lwa_decialt TO rt_options.
    ENDIF.

  ENDLOOP.


  " Step 9: Ensure at least one option is returned
  IF rt_options IS INITIAL.
*    lv_error_message = |No valid users found for CURRENT_LEVEL { current_level }|.
*    MESSAGE lv_error_message TYPE 'E'.
*    CLEAR lwa_decialt.
*    lwa_decialt-altkey = '0001'.
*    lwa_decialt-alttext = 'No users available'.
    "APPEND lwa_decialt TO rt_options.
  ENDIF.

ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_SWF_IFS_DECISION_OD_EXIT->HANDLE_USER_SELECTION
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_EVENT_NAME                  TYPE        SWW_EVTTYP(optional)
* | [--->] IM_WORKITEM_CONTEXT            TYPE REF TO IF_WAPI_WORKITEM_CONTEXT(optional)
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD HANDLE_USER_SELECTION.
  DATA: "lo_container TYPE REF TO if_swf_cnt_container,
        lv_decision_key TYPE swr_decialts-altkey.

  DATA: MY_DESCISION TYPE INT2.

  TRY.
    " Get the work item container object
    DATA(lo_container) = IM_WORKITEM_CONTEXT->get_wi_container( ).

    " Read the decision result key from the standard container element '_WI_RESULT'
    lo_container->get( EXPORTING name = '_WI_RESULT' IMPORTING VALUE = lv_decision_key ).

    MY_DESCISION = lv_decision_key.
    "lo_container->set( EXPORTING name = '_WI_RESULT'  VALUE = '000' ).
    "SHIFT LV_DECISION_KEY LEFT DELETING LEADING '0'.
    "lo_container->SET( EXPORTING NAME = 'CURRENT_LEVEL' VALUE = MY_DESCISION ).


  CATCH cx_swf_cnt_elem_not_found.
    " Handle error if the element is not found
    " Log an error or return an empty table
    RETURN.
  CATCH cx_swf_cnt_elem_type_conflict.
    " Handle error if there is a type mismatch
    " Log an error or return an empty table
    RETURN.
  CATCH cx_swf_cnt_unit_type_conflict.
    " Handle other conversion errors
    " Log an error or return an empty table
    RETURN.
  CATCH CX_SWF_CNT_CONTAINER.
    " Handle error if the element is not found
    " Log an error or return an empty table
    RETURN.
  ENDTRY.

  DATA: lt_header           TYPE TABLE OF swwwihead,
        ls_header           TYPE swwwihead,
        lv_top_wi_id        TYPE sww_wiid,
        lt_wf_container     TYPE TABLE OF swr_cont,  " Workflow container
        ls_container        TYPE swr_cont,  " Workflow container
        lt_users            TYPE zwf_users_ty,       " Table type for USERS
        current_level       TYPE int2,
        lwa_decialt         TYPE swr_decialts,
        ls_users             TYPE zwf_users,         " Line type of ZWF_USER_TY
        lv_return_code      TYPE sysubrc,
        lv_value            TYPE swr_cont-VALUE,    " Buffer for scalar values
        lv_error_message    TYPE string.


  " Step 1: Get the current work item ID
  TRY.
    DATA(lv_current_wi_id) = im_workitem_context->get_workitem_id( ).
  CATCH cx_root INTO DATA(lx_root).
    lv_error_message = |Error getting WORK item ID: { lx_root->get_text( ) }|.
    MESSAGE lv_error_message TYPE 'E'.
    CLEAR lwa_decialt.
    lwa_decialt-altkey = '0001'.
    lwa_decialt-alttext = 'Error retrieving work item ID'.

    RETURN.
  ENDTRY.

  " Step 2: Read the work item header to get the top-level workflow work item ID
  TRY.
    CALL FUNCTION 'SWW_WI_HEADER_READ'
    EXPORTING
      wi_id     = lv_current_wi_id
    IMPORTING
      wi_header = ls_header
    EXCEPTIONS
      error_reading_header = 1
      OTHERS              = 2.
    IF sy-subrc <> 0.
      lv_error_message = |Error reading WORK item HEADER FOR WI_ID { lv_current_wi_id }, SY-SUBRC: { sy-subrc }|.
      MESSAGE lv_error_message TYPE 'E'.
      CLEAR lwa_decialt.
      lwa_decialt-altkey = '0001'.
      lwa_decialt-alttext = 'Error reading work item header'.

      RETURN.
    ENDIF.
  CATCH cx_sy_dyn_call_param_not_found INTO DATA(lx_param_error).
    lv_error_message = |PARAMETER error IN SWW_WI_HEADER_READ: { lx_param_error->get_text( ) }|.
    MESSAGE lv_error_message TYPE 'E'.
    CLEAR lwa_decialt.
    lwa_decialt-altkey = '0001'.
    lwa_decialt-alttext = 'Parameter error in header read'.

    RETURN.
  CATCH cx_root INTO lx_root.
    lv_error_message = |Unexpected error IN SWW_WI_HEADER_READ: { lx_root->get_text( ) }|.
    MESSAGE lv_error_message TYPE 'E'.
    CLEAR lwa_decialt.
    lwa_decialt-altkey = '0001'.
    lwa_decialt-alttext = 'Unexpected error in header read'.

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
  lv_top_wi_id = ls_header-top_wi_id.

  " Step 3: Read the workflow container
  CLEAR lt_wf_container.
  TRY.
    CALL FUNCTION 'SAP_WAPI_READ_CONTAINER'
    EXPORTING
      workitem_id      = lv_top_wi_id
    TABLES
      simple_container = lt_wf_container
    EXCEPTIONS
      error_reading_container = 1
      OTHERS                 = 2.
    IF sy-subrc <> 0.
      lv_error_message = |Error reading workflow container FOR WI_ID { lv_top_wi_id }, SY-SUBRC: { sy-subrc }|.
      MESSAGE lv_error_message TYPE 'E'.
      CLEAR lwa_decialt.
      lwa_decialt-altkey = '0001'.
      lwa_decialt-alttext = 'Error reading workflow container'.

      RETURN.
    ENDIF.
  CATCH cx_sy_dyn_call_param_not_found INTO lx_param_error.
    lv_error_message = |PARAMETER error IN SAP_WAPI_READ_CONTAINER: { lx_param_error->get_text( ) }|.
    MESSAGE lv_error_message TYPE 'E'.
    CLEAR lwa_decialt.
    lwa_decialt-altkey = '0001'.
    lwa_decialt-alttext = 'Parameter error in container read'.

    RETURN.
  CATCH cx_root INTO lx_root.
    lv_error_message = |Unexpected error IN SAP_WAPI_READ_CONTAINER: { lx_root->get_text( ) }|.
    MESSAGE lv_error_message TYPE 'E'.
    CLEAR lwa_decialt.
    lwa_decialt-altkey = '0001'.
    lwa_decialt-alttext = 'Unexpected error in container read'.

    RETURN.
  ENDTRY.

  CLEAR ls_container.
  READ TABLE lt_wf_container ASSIGNING FIELD-SYMBOL(<fs_container>) WITH KEY element = 'CURRENT_LEVEL_OD'.
  IF sy-subrc = 0.
    <fs_container>-value = MY_DESCISION.
    CONDENSE <fs_container>-value.
  ENDIF.

  " Step 7: Write the updated workflow container back
  TRY.
      CALL FUNCTION 'SAP_WAPI_WRITE_CONTAINER'
        EXPORTING
          workitem_id      = lv_top_wi_id
          DO_COMMIT        = ''
        IMPORTING
          return_code      = lv_return_code
        TABLES
          simple_container = lt_wf_container

        EXCEPTIONS
          error_writing_container = 1
          OTHERS                = 2.
      IF lv_return_code <> 0 OR sy-subrc <> 0.
*        lv_error_message = |Error writing to workflow container for WI_ID { lv_top_wi_id }, RETURN_CODE: { lv_return_code }|.
*        MESSAGE lv_error_message TYPE 'E'.
*        CLEAR lwa_decialt.
*        lwa_decialt-altkey = '0001'.
*        lwa_decialt-alttext = 'Error writing to container'.
*        APPEND lwa_decialt TO rt_options.
*        RETURN.
      ENDIF.
    CATCH cx_sy_dyn_call_param_not_found INTO lx_param_error.
      lv_error_message = |Parameter error in SAP_WAPI_WRITE_CONTAINER: { lx_param_error->get_text( ) }|.
      MESSAGE lv_error_message TYPE 'E'.
      CLEAR lwa_decialt.
      lwa_decialt-altkey = '0001'.
      lwa_decialt-alttext = 'Parameter error in container write'.
      "APPEND lwa_decialt TO rt_options.
      RETURN.
    CATCH cx_root INTO lx_root.
      lv_error_message = |Unexpected error in SAP_WAPI_WRITE_CONTAINER: { lx_root->get_text( ) }|.
      MESSAGE lv_error_message TYPE 'E'.
      CLEAR lwa_decialt.
      lwa_decialt-altkey = '0001'.
      lwa_decialt-alttext = 'Unexpected error in container write'.
      "APPEND lwa_decialt TO rt_options.
      RETURN.
  ENDTRY.


ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_SWF_IFS_DECISION_OD_EXIT->IF_SWF_IFS_WORKITEM_EXIT~EVENT_RAISED
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_EVENT_NAME                  TYPE        SWW_EVTTYP
* | [--->] IM_WORKITEM_CONTEXT            TYPE REF TO IF_WAPI_WORKITEM_CONTEXT
* | [!CX!] CX_SWF_IFS_WORKITEM_EXIT_ERROR
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD IF_SWF_IFS_WORKITEM_EXIT~EVENT_RAISED.
  DATA: lt_decialts TYPE swrtdecialts,
        lwa_decialt TYPE swr_decialts.

  " Check if the event is raised before the decision screen is shown
  IF im_event_name = if_swf_ifs_decision_exit~c_evttyp_before_decision.
    " Retrieve list of options from a custom table or dynamic logic
    CALL METHOD GET_DYNAMIC_OPTIONS
    EXPORTING
      IM_WORKITEM_CONTEXT =  IM_WORKITEM_CONTEXT
      IM_EVENT_NAME = im_event_name
    IMPORTING
    RT_OPTIONS = DATA(lt_dynamic_options).
    "DATA(lt_dynamic_options) = get_dynamic_options( ). " Custom ABAP method




    " Clear standard options and build new ones
    CLEAR lt_decialts.
    LOOP AT lt_dynamic_options INTO lwa_decialt.
      APPEND lwa_decialt TO lt_decialts.
    ENDLOOP.

    " Set the new decision options in the work item context
    im_workitem_context->set_decision_alts( it_decialts = lt_decialts ).

  " Handle event after the decision is made
  ELSEIF im_event_name = if_swf_ifs_workitem_exit~c_evttyp_after_action OR im_event_name = if_swf_ifs_workitem_exit~C_EVTTYP_AFTER_EXECUTION."AFT_EXEC.
    CALL METHOD handle_user_selection
      EXPORTING
      IM_WORKITEM_CONTEXT =  IM_WORKITEM_CONTEXT.
  ENDIF.


ENDMETHOD.
ENDCLASS.