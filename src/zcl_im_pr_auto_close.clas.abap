CLASS ZCL_IM_PR_AUTO_CLOSE DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES IF_BADI_INTERFACE .
    INTERFACES IF_EX_ME_PROCESS_PO_CUST .
  PROTECTED SECTION.
private section.
ENDCLASS.



CLASS ZCL_IM_PR_AUTO_CLOSE IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_IM_PR_AUTO_CLOSE->IF_EX_ME_PROCESS_PO_CUST~CHECK
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_HEADER                      TYPE REF TO IF_PURCHASE_ORDER_MM
* | [--->] IM_HOLD                        TYPE        MMPUR_BOOL
* | [--->] IM_PARK                        TYPE        MMPUR_BOOL(optional)
* | [<-->] CH_FAILED                      TYPE        MMPUR_BOOL
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD IF_EX_ME_PROCESS_PO_CUST~CHECK.
    IF SY-UNAME = 'HASSAN.C'. BREAK-POINT.ENDIF.
    ZCL_PO_PR_LIMIT_CHECK=>GET_INSTANCE( )->EXECUTE_FOR_PO(
  EXPORTING IO_HEADER = IM_HEADER
  CHANGING  CV_FAILED = CH_FAILED ).
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_IM_PR_AUTO_CLOSE->IF_EX_ME_PROCESS_PO_CUST~CLOSE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_HEADER                      TYPE REF TO IF_PURCHASE_ORDER_MM
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD IF_EX_ME_PROCESS_PO_CUST~CLOSE.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_IM_PR_AUTO_CLOSE->IF_EX_ME_PROCESS_PO_CUST~FIELDSELECTION_HEADER
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_HEADER                      TYPE REF TO IF_PURCHASE_ORDER_MM
* | [--->] IM_INITIATOR                   TYPE        MEPO_INITIATOR(optional)
* | [<-->] CH_FIELDSELECTION              TYPE        TTYP_FIELDSELECTION_MM
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD IF_EX_ME_PROCESS_PO_CUST~FIELDSELECTION_HEADER.
ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_IM_PR_AUTO_CLOSE->IF_EX_ME_PROCESS_PO_CUST~FIELDSELECTION_HEADER_REFKEYS
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_HEADER                      TYPE REF TO IF_PURCHASE_ORDER_MM
* | [<-->] CH_KEY0                        TYPE        BREFN
* | [<-->] CH_KEY1                        TYPE        BREFN
* | [<-->] CH_KEY2                        TYPE        BREFN
* | [<-->] CH_KEY3                        TYPE        BREFN
* | [<-->] CH_KEY4                        TYPE        BREFN
* | [<-->] CH_KEY5                        TYPE        BREFN
* | [<-->] CH_KEY6                        TYPE        BREFN
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD IF_EX_ME_PROCESS_PO_CUST~FIELDSELECTION_HEADER_REFKEYS.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_IM_PR_AUTO_CLOSE->IF_EX_ME_PROCESS_PO_CUST~FIELDSELECTION_ITEM
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_HEADER                      TYPE REF TO IF_PURCHASE_ORDER_MM
* | [--->] IM_ITEM                        TYPE REF TO IF_PURCHASE_ORDER_ITEM_MM
* | [<-->] CH_FIELDSELECTION              TYPE        TTYP_FIELDSELECTION_MM
* +--------------------------------------------------------------------------------------</SIGNATURE>
METHOD IF_EX_ME_PROCESS_PO_CUST~FIELDSELECTION_ITEM.
ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_IM_PR_AUTO_CLOSE->IF_EX_ME_PROCESS_PO_CUST~FIELDSELECTION_ITEM_REFKEYS
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_ITEM                        TYPE REF TO IF_PURCHASE_ORDER_ITEM_MM
* | [<-->] CH_KEY0                        TYPE        BREFN
* | [<-->] CH_KEY1                        TYPE        BREFN
* | [<-->] CH_KEY2                        TYPE        BREFN
* | [<-->] CH_KEY3                        TYPE        BREFN
* | [<-->] CH_KEY4                        TYPE        BREFN
* | [<-->] CH_KEY5                        TYPE        BREFN
* | [<-->] CH_KEY6                        TYPE        BREFN
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD IF_EX_ME_PROCESS_PO_CUST~FIELDSELECTION_ITEM_REFKEYS.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_IM_PR_AUTO_CLOSE->IF_EX_ME_PROCESS_PO_CUST~INITIALIZE
* +-------------------------------------------------------------------------------------------------+
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD IF_EX_ME_PROCESS_PO_CUST~INITIALIZE.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_IM_PR_AUTO_CLOSE->IF_EX_ME_PROCESS_PO_CUST~OPEN
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_TRTYP                       TYPE        TRTYP
* | [--->] IM_HEADER                      TYPE REF TO IF_PURCHASE_ORDER_MM
* | [<-->] CH_VALID                       TYPE        MMPUR_BOOL
* | [<-->] CH_DISPLAY_ONLY                TYPE        MMPUR_BOOL
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD IF_EX_ME_PROCESS_PO_CUST~OPEN.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_IM_PR_AUTO_CLOSE->IF_EX_ME_PROCESS_PO_CUST~POST
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_EBELN                       TYPE        EBELN
* | [--->] IM_HEADER                      TYPE REF TO IF_PURCHASE_ORDER_MM
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD IF_EX_ME_PROCESS_PO_CUST~POST.
*&--------------------------------------------------------------------------*
*& Enhancement Raise PR Closed for line item When PO Created ---------------*
*&------------------ Technical Consultant  : Hassan Diab     ---------------*
*&------------------ Functional Consultant : Nayera Makram   ---------------*
*------- Enhancement Raise PR Closed for line item When PO Created ---------*
*&--------------------------------------------------------------------------*
    IF SY-UNAME = 'HASSAN.C'. BREAK-POINT. ENDIF.
    NEW ZCL_PR_AUTO_CLOSE( )->EXECUTE_FOR_PO( IM_HEADER ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_IM_PR_AUTO_CLOSE->IF_EX_ME_PROCESS_PO_CUST~PROCESS_ACCOUNT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_ACCOUNT                     TYPE REF TO IF_PURCHASE_ORDER_ACCOUNT_MM
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD IF_EX_ME_PROCESS_PO_CUST~PROCESS_ACCOUNT.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_IM_PR_AUTO_CLOSE->IF_EX_ME_PROCESS_PO_CUST~PROCESS_HEADER
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_HEADER                      TYPE REF TO IF_PURCHASE_ORDER_MM
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD IF_EX_ME_PROCESS_PO_CUST~PROCESS_HEADER.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_IM_PR_AUTO_CLOSE->IF_EX_ME_PROCESS_PO_CUST~PROCESS_ITEM
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_ITEM                        TYPE REF TO IF_PURCHASE_ORDER_ITEM_MM
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD IF_EX_ME_PROCESS_PO_CUST~PROCESS_ITEM.
    IF SY-UNAME = 'HASSAN.C'. BREAK-POINT.ENDIF.
    ZCL_PO_PR_LIMIT_CHECK=>GET_INSTANCE( )->EXECUTE_FOR_ITEM( IM_ITEM ).
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_IM_PR_AUTO_CLOSE->IF_EX_ME_PROCESS_PO_CUST~PROCESS_SCHEDULE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IM_SCHEDULE                    TYPE REF TO IF_PURCHASE_ORDER_SCHEDULE_MM
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD IF_EX_ME_PROCESS_PO_CUST~PROCESS_SCHEDULE.
  ENDMETHOD.
ENDCLASS.
