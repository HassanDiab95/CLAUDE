@EndUserText.label : 'SD: SO Change Approval - Approver per Level'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zsd_so_appr_cfg {

  key mandt      : mandt not null;

  @AbapCatalog.foreignKey.screenCheck : true
  key vkorg      : vkorg not null
    with foreign key [0..*,1] tvko
      where mandt = zsd_so_appr_cfg.mandt
        and vkorg = zsd_so_appr_cfg.vkorg;

  @AbapCatalog.foreignKey.screenCheck : true
  key auart      : auart not null
    with foreign key [0..*,1] tvak
      where mandt = zsd_so_appr_cfg.mandt
        and auart = zsd_so_appr_cfg.auart;

  key appr_level : zsd_so_level not null;
  uname          : xubname;
  email          : ad_smtpadr;
  active         : xfeld;

}
