*&---------------------------------------------------------------------*
*& Include        : ZFI_BUDGET_FCST_PAI
*& Main Program   : ZFI_BUDGET_FORECAST
*&---------------------------------------------------------------------*
*& Purpose        : PAI modules of screen 0100 - delegate to the
*&                   screen controller LCL_SCREEN_0100.
*&---------------------------------------------------------------------*
MODULE exit_0100 INPUT.
  go_screen->pai_exit( sy-ucomm ).
ENDMODULE.

MODULE check_header INPUT.
  go_screen->pai_check_header( ).
ENDMODULE.

MODULE ct_fcst_modify INPUT.
  go_screen->pai_table_modify( ).
ENDMODULE.

MODULE ct_fcst_mark INPUT.
  go_screen->pai_table_mark( ).
ENDMODULE.

MODULE user_command_0100 INPUT.
  gv_ucomm = sy-ucomm.
  CLEAR sy-ucomm.
  go_screen->pai_user_command( gv_ucomm ).
ENDMODULE.
