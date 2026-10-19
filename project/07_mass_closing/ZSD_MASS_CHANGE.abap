REPORT zsd_mass_change.

TABLES vbak.

SELECT-OPTIONS s_vbeln FOR vbak-vbeln OBLIGATORY.

START-OF-SELECTION.
  NEW zcl_sd_mass_change( )->run( s_vbeln[] ).
