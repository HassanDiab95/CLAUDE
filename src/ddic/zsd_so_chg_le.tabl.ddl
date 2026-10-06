@EndUserText.label : 'SD: SO Change Approval WF Log - Events'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zsd_so_chg_le {

  key mandt  : mandt not null;
  key log_id : sysuuid_c32 not null;
  key seqnr  : zsd_so_seqnr not null;
  event      : zsd_so_wf_event;
  appr_level : zsd_so_level;
  uname      : xubname;
  text       : zsd_so_chg_text;
  created_on : datum;
  created_at : uzeit;
  created_by : syuname;

}
