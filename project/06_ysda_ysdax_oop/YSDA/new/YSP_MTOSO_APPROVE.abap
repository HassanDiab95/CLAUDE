*&---------------------------------------------------------------------*
*& Module Pool      YSP_MTOSO_APPROVE   (transaction YSDA)
*&---------------------------------------------------------------------*
*& MTO sales order approval (SD / FI) per order item.
*& OOP version of the old program - same logic, same screens
*& (0099 / 0100), same GUI status and titles.
*&
*&   YSP_MTOSO_APPROVE_TOP  global data, types, class definitions
*&   YSP_MTOSO_APPROVE_C01  class implementations (all the logic)
*&   YSP_MTOSO_APPROVE_M01  PBO / PAI modules (only call the classes)
*&---------------------------------------------------------------------*
*& DRAFT - not compiled / not tested in SAP
*&---------------------------------------------------------------------*

INCLUDE ysp_mtoso_approve_top.    " Global data + class definitions
INCLUDE ysp_mtoso_approve_c01.    " Class implementations
INCLUDE ysp_mtoso_approve_m01.    " PBO / PAI modules
