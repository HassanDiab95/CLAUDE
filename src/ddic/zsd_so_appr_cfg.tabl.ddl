@EndUserText.label : 'SD: SO Change Approval - Approvers per Level'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zsd_so_appr_cfg {

  key mandt    : mandt not null;

  @AbapCatalog.foreignKey.screenCheck : true
  key vkorg    : vkorg not null
    with foreign key [0..*,1] tvko
      where mandt = zsd_so_appr_cfg.mandt
        and vkorg = zsd_so_appr_cfg.vkorg;

  @AbapCatalog.foreignKey.screenCheck : true
  key auart    : auart not null
    with foreign key [0..*,1] tvak
      where mandt = zsd_so_appr_cfg.mandt
        and auart = zsd_so_appr_cfg.auart;

  key appr_lvl : ze_sd_appr_level not null;
  key approver : xubname not null;
  email        : ad_smtpadr;
  active       : xfeld;

}
