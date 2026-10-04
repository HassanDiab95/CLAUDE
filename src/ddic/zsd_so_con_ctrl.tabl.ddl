@EndUserText.label : 'SD: Sales Order with Ref. to Contract - Control Rules'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zsd_so_con_ctrl {

  key mandt     : mandt not null;

  @AbapCatalog.foreignKey.screenCheck : true
  key vkorg     : vkorg not null
    with foreign key [0..*,1] tvko
      where mandt = zsd_so_con_ctrl.mandt
        and vkorg = zsd_so_con_ctrl.vkorg;

  @AbapCatalog.foreignKey.screenCheck : true
  key vtweg     : vtweg not null
    with foreign key [0..*,1] tvtw
      where mandt = zsd_so_con_ctrl.mandt
        and vtweg = zsd_so_con_ctrl.vtweg;

  @AbapCatalog.foreignKey.screenCheck : true
  key spart     : spart not null
    with foreign key [0..*,1] tspa
      where mandt = zsd_so_con_ctrl.mandt
        and spart = zsd_so_con_ctrl.spart;

  @AbapCatalog.foreignKey.label : 'Sales Order Type'
  @AbapCatalog.foreignKey.screenCheck : true
  key auart_so  : auart not null
    with foreign key [0..*,1] tvak
      where mandt = zsd_so_con_ctrl.mandt
        and auart = zsd_so_con_ctrl.auart_so;

  @AbapCatalog.foreignKey.label : 'Contract Type'
  @AbapCatalog.foreignKey.screenCheck : true
  key auart_con : auart not null
    with foreign key [0..*,1] tvak
      where mandt = zsd_so_con_ctrl.mandt
        and auart = zsd_so_con_ctrl.auart_con;

  active        : xfeld;

}
