MODULE status_0099 OUTPUT.
  SET PF-STATUS 'YSP_MTOSO_STATUS90'.
  SET TITLEBAR 'YSP_MTOSO_TITLE90'.
  IF go_app IS NOT BOUND.
    go_app = NEW #( ).
  ENDIF.
ENDMODULE.

MODULE user_command_0099 INPUT.
  CASE sy-ucomm.
    WHEN 'EXECUTE'.
      go_app->execute( iv_plant     = bukrs
                       iv_date_from = datev_f
                       iv_date_to   = datev_t ).
  ENDCASE.
ENDMODULE.

MODULE user_command_0099_exit INPUT.
  CASE sy-ucomm.
    WHEN 'EXIT' OR 'BACK' OR 'CANCEL'.
      LEAVE PROGRAM.
  ENDCASE.
ENDMODULE.

MODULE status_0100 OUTPUT.
  SET PF-STATUS 'YSP_MTOSO_STATUS1'.
  SET TITLEBAR 'YSP_MTOSO_TITLE'.
  go_app->pbo_0100( ).
ENDMODULE.

MODULE user_command_0100 INPUT.
  go_app->pai_0100( sy-ucomm ).
ENDMODULE.

MODULE user_command_0100_exit INPUT.
  CASE sy-ucomm.
    WHEN 'EXIT' OR 'BACK' OR 'CANCEL'.
      LEAVE PROGRAM.
  ENDCASE.
ENDMODULE.
