REPORT zsd_mass_closing.

TABLES vbak.

SELECT-OPTIONS s_vbeln FOR vbak-vbeln.

START-OF-SELECTION.
  NEW zcl_sd_mass_change( )->run( it_vbeln   = s_vbeln[]
                                  iv_90_days = abap_true ).
