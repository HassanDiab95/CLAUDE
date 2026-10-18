*&---------------------------------------------------------------------*
*& Module Pool      YSP_MTOSO_APPROVE_CX   (transaction YSDAX)
*&---------------------------------------------------------------------*
*& MTO sales order approval (SD / FI) per order item.
*& OOP version of the old program - same logic, same screens
*& (0099 / 0100), same GUI status and titles.
*&
*&   YSP_MTOSO_APPROVE_CX_TOP global data, types, class definitions
*&   YSP_MTOSO_APPROVE_CX_C01 class implementations (all the logic)
*&   YSP_MTOSO_APPROVE_CX_M01 PBO / PAI modules (only call the classes)
*&---------------------------------------------------------------------*
*& DRAFT - not compiled / not tested in SAP
*&---------------------------------------------------------------------*

INCLUDE ysp_mtoso_approve_cx_top.   " Global data + class definitions
INCLUDE ysp_mtoso_approve_cx_c01.   " Class implementations
INCLUDE ysp_mtoso_approve_cx_m01.   " PBO / PAI modules
