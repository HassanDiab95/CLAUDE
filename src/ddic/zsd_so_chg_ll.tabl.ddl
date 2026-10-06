@EndUserText.label : 'SD: SO Change Approval WF Log - Levels'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zsd_so_chg_ll {

  key mandt      : mandt not null;
  key log_id     : sysuuid_c32 not null;
  key appr_level : zsd_so_level not null;
  uname          : xubname;
  full_name      : ad_namtext;
  email          : ad_smtpadr;
  email_src      : char1;
  status         : zsd_so_wf_status;
  started_on     : datum;
  started_at     : uzeit;
  decided_on     : datum;
  decided_at     : uzeit;
  decided_by     : xubname;

}
