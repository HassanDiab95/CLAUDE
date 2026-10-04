@EndUserText.label : 'SD: SO with Ref. to Contract - Filter per Process'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
define structure zssd_so_con_filter {

  process   : ze_sd_process;
  vkorg     : ztt_sd_r_vkorg;
  vtweg     : ztt_sd_r_vtweg;
  spart     : ztt_sd_r_spart;
  auart_so  : ztt_sd_r_auart_so;
  auart_con : ztt_sd_r_auart_con;

}
