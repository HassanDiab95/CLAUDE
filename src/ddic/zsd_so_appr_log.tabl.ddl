@EndUserText.label : 'SD: SO Change Approval - Requests and Status'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zsd_so_appr_log {

  key mandt    : mandt not null;
  key vbeln    : vbeln_va not null;
  key counter  : ze_sd_appr_counter not null;
  status       : ze_sd_appr_status;
  chg_user     : ernam;
  chg_date     : erdat;
  chg_time     : erzet;
  change_text  : ze_sd_appr_chg_text;
  appr_lvl     : ze_sd_appr_level;
  decided_by   : xubname;
  decided_date : datum;
  decided_time : uzeit;

}
