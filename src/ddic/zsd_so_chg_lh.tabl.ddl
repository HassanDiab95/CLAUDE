@EndUserText.label : 'SD: SO Change Approval WF Log - Header'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zsd_so_chg_lh {

  key mandt   : mandt not null;
  key log_id  : sysuuid_c32 not null;
  vbeln       : vbeln_va;
  contract    : vbeln_va;
  auart       : auart;
  vkorg       : vkorg;
  vtweg       : vtweg;
  spart       : spart;
  kunnr       : kunag;
  cust_name   : name1_gp;
  netwr       : netwr_ak;
  waerk       : waerk;
  change_text : zsd_so_chg_text;
  status      : zsd_so_wf_status;
  curr_level  : zsd_so_level;
  levels      : zsd_so_level;
  wf_id       : sww_wiid;
  replaced_by : sysuuid_c32;
  trigger_evt : sibfevent;
  trigger_by  : xubname;
  trigger_on  : datum;
  trigger_at  : uzeit;
  created_on  : datum;
  created_at  : uzeit;
  created_by  : syuname;
  changed_on  : datum;
  changed_at  : uzeit;
  finished_on : datum;
  finished_at : uzeit;

}
