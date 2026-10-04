@EndUserText.label : 'SD: SO with Ref. to Contract - Filter Ranges'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zsd_so_con_flt {

  key mandt     : mandt not null;
  key process   : ze_sd_process not null;
  key fieldname : ze_sd_flt_field not null;
  key seqno     : ze_sd_flt_seqno not null;
  sign          : ddsign;
  opti          : ddoption;
  low           : ze_sd_flt_low;
  high          : ze_sd_flt_high;
  active        : xfeld;

}
