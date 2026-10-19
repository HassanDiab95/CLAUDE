REPORT zsd_mass_closing.

TABLES vbak.

SELECT-OPTIONS s_vbeln FOR vbak-vbeln.

START-OF-SELECTION.
  NEW zcl_sd_mass_closing( )->run( s_vbeln[] ).
