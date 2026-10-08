*&---------------------------------------------------------------------*
*& Include        : ZFI_BUD_2YF_ENTRY_PBO
*& Main Program   : ZFI_BUD_2YF_ENTRY
*&---------------------------------------------------------------------*
*& Purpose        : PBO modules of screen 0100 - delegate to the
*&                   screen controller LCL_SCREEN_0100.
*&---------------------------------------------------------------------*
MODULE status_0100 OUTPUT.
  IF go_screen IS NOT BOUND.
    go_screen = NEW #( ).
  ENDIF.
  go_screen->pbo_status( ).
ENDMODULE.

MODULE ct_fcst_change_tc_attr OUTPUT.
  ct_fcst-lines = lines( gt_item ).
ENDMODULE.

MODULE ct_fcst_get_lines OUTPUT.
  go_screen->pbo_table_line( ).
ENDMODULE.

MODULE screen_edits_0100 OUTPUT.
  go_screen->pbo_screen_edits( ).
ENDMODULE.

MODULE get_texts OUTPUT.
  go_screen->pbo_texts( ).
ENDMODULE.

MODULE status_0001 OUTPUT.
  IF go_menu IS NOT BOUND.
    go_menu = NEW #( ).
  ENDIF.
  go_menu->pbo( ).
ENDMODULE.
