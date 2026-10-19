REPORT zsd_mass_change.

TABLES vbak.

SELECT-OPTIONS s_vbeln FOR vbak-vbeln.
PARAMETERS     p_90day AS CHECKBOX DEFAULT 'X'.

AT SELECTION-SCREEN.
  IF p_90day = abap_false AND s_vbeln[] IS INITIAL.
    MESSAGE 'Enter sales orders when the 90 days condition is not used' TYPE 'E'.
  ENDIF.

START-OF-SELECTION.
  NEW zcl_sd_mass_change( )->run( it_vbeln   = s_vbeln[]
                                  iv_90_days = p_90day ).
