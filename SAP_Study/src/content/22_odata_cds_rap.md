# 20. CDS-Based OData Services

Writing SELECTs, filters and paging by hand in the DPC is a lot of code. With **Core Data Services (CDS)** views, the **SADL** framework (Service Adaptation Definition Language) translates OData requests (`$filter`, `$orderby`, `$top`, `$select`, `$expand`, `$count`, search) **directly into optimised SQL** on HANA – no ABAP code for read operations.

There are three ways to expose CDS as OData (oldest → newest):

| Approach | How | Write operations | Status |
|---|---|---|---|
| **@OData.publish: true** | Annotation in the CDS view; activates a generated service `<VIEW>_CDS` | Only via BOPF (`@ObjectModel.transactionalProcessingEnabled`) | Legacy (7.50 – S/4 1909 programming model) – still common in projects |
| **SEGW Reference Data Source (RDS)** | SEGW → *Data Model → Reference → Data Source* → CDS view; associations become navigation | Redefine DPC_EXT methods for create/update/delete | Common when you need SEGW + custom logic |
| **SEGW Mapping to Data Source** | Map entity set to a CDS view in *Service Implementation* | DPC_EXT | Less common |
| **RAP Service Binding** | Service definition + binding (V2/V4) | Behavior definition (managed/unmanaged) | **Recommended** (S/4HANA 1909+, BTP) – Chapter 21 |

## Example: CDS view with @OData.publish

```cds
@AbapCatalog.sqlViewName: 'ZVSALESORD'
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Sales orders'
@OData.publish: true
define view ZC_SalesOrder
  as select from vbak
  association [0..*] to ZC_SalesOrderItem as _Items
    on $projection.SalesOrder = _Items.SalesOrder
  association [0..1] to I_Customer as _Customer
    on $projection.SoldToParty = _Customer.Customer
{
  key vbeln as SalesOrder,
      erdat as CreatedOn,
      @ObjectModel.text.association: '_Customer'
      kunnr as SoldToParty,
      @Semantics.amount.currencyCode: 'Currency'
      netwr as NetAmount,
      @Semantics.currencyCode: true
      waerk as Currency,
      _Items,
      _Customer
}
```

After activation, ADT shows a marker "Service ZC_SALESORDER_CDS is not active" → register it in `/IWFND/MAINT_SERVICE` (Add service, search `ZC_SALESORDER_CDS`). Then:

```text
GET /sap/opu/odata/sap/ZC_SALESORDER_CDS/ZC_SalesOrder?$filter=SoldToParty eq '100001'
GET /sap/opu/odata/sap/ZC_SALESORDER_CDS/ZC_SalesOrder('4711')/to_Items
```

Associations that are exposed in the projection list become navigation properties named `to_<Association>` (e.g. `to_Items`).

## SEGW with Reference Data Source

1. Create SEGW project → right-click *Data Model* → *Reference* → *Data Source* → choose CDS view `ZC_SalesOrder` (and associated views).
2. Generate. All reads (incl. filter, paging, expand via associations) are handled by SADL.
3. For create/update/delete or special logic redefine methods in `DPC_EXT`. You can still add custom entity sets (manual ones) to the same project.

## CDS concepts you need for OData

| Concept | Purpose |
|---|---|
| Basic / Interface view (`I_`) | Reusable, close to the DB table, clean names |
| Consumption view (`C_`) | Tailored for one app / service, with UI annotations |
| Association | Lazy join – becomes a navigation property; only joined when used (`$expand`) |
| `@AccessControl.authorizationCheck` + DCL (`define role`) | Row-level authorizations applied automatically to OData reads |
| `@UI.*` annotations / Metadata extension (`@Metadata.allowExtensions: true`) | Fiori elements layout: `@UI.lineItem`, `@UI.selectionField`, `@UI.identification`, `@UI.facet` |
| `@Consumption.valueHelpDefinition` | Value help for a field |
| `@Search.searchable` + `@Search.defaultSearchElement` | Enables free-text search (`search=` / `$search`) |
| `@ObjectModel.text.element` / `text.association` | Shows descriptions next to IDs |
| CDS view entity (`define view entity`) | New syntax (7.55+) without SQL view, recommended for new development |

:::lab Lab 20 – CDS-based read service
Create interface view entity `ZI_Student` on table `ZTB_STUDENT` (from Lab 16) and consumption view `ZC_Student` with `@OData.publish: true` (use classic `define view` with sqlViewName if your release requires it), UI annotations so that Fiori elements shows Name, Email, City in the list and City as filter field, and `@Search.searchable` on Name. Register and test `$filter`, `$orderby`, `$top`, `$inlinecount` and `search` without writing any ABAP code.
:::

:::solution Lab 20
```cds
@AbapCatalog.sqlViewName: 'ZISTUDENT'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Student - interface view'
define view ZI_Student as select from ztb_student {
  key student_id as StudentId,
      name       as Name,
      email      as Email,
      city       as City,
      created_on as CreatedOn
}
```
```cds
@AbapCatalog.sqlViewName: 'ZCSTUDENT'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Students'
@OData.publish: true
@Search.searchable: true
define view ZC_Student as select from ZI_Student {
      @UI.lineItem: [{ position: 10 }]
  key StudentId,
      @UI.lineItem: [{ position: 20 }]
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      Name,
      @UI.lineItem: [{ position: 30 }]
      Email,
      @UI.lineItem: [{ position: 40 }]
      @UI.selectionField: [{ position: 10 }]
      City,
      CreatedOn
}
```
```text
/sap/opu/odata/sap/ZC_STUDENT_CDS/ZC_Student?$filter=City eq 'Cairo'&$orderby=Name&$top=5&$inlinecount=allpages
/sap/opu/odata/sap/ZC_STUDENT_CDS/ZC_Student?search=ali
```
:::

# 21. RAP – ABAP RESTful Application Programming Model (OData V4)

**RAP** is SAP's current model for building Fiori apps and Web APIs on S/4HANA (1909+) and SAP BTP ABAP Environment ("Steampunk"). It replaces SEGW + BOPF for new development. Everything is built in **ADT (Eclipse)**.

## The RAP layers

| Layer | Artifact | Purpose |
|---|---|---|
| Data model | CDS view entities: `define root view entity` + child entities (`composition`) | The Business Object (BO) structure |
| Behavior | **Behavior Definition** (BDEF) | Which operations: create/update/delete, actions, validations, determinations, locking, ETag, draft |
| Behavior implementation | **Behavior pool** – ABAP class (`ZBP_...`) with local handler (`LHC_`) and saver (`LSC_`) classes | Your ABAP logic (in EML) |
| Projection | Projection views (`as projection on`) + projection BDEF | Expose only what this app/API needs, UI annotations |
| Business service | **Service Definition** (`define service`) | Which entities are exposed |
| Binding | **Service Binding** (OData V2/V4, UI/Web API) | Protocol + publish → URL; *Preview* Fiori elements app |

## Managed vs. unmanaged

- **Managed** – the RAP framework does CRUD, buffering, locking and saving to DB tables automatically. You add validations, determinations and actions. Best for new applications ("greenfield").
- **Unmanaged** – you implement CRUD and save yourself (e.g. calling existing BAPIs / legacy code) – "brownfield".
- **Managed with unmanaged save** / **additional save** – framework handles transactional buffer, you control saving.
- **Draft** – `with draft;` lets users save incomplete data in draft tables and continue later (typical Fiori elements behaviour).

## Example: Travel booking (managed, simplified)

### 1. Database table

```cds
@EndUserText.label : 'Travel'
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztravel_a {
  key client      : abap.clnt not null;
  key travel_uuid : sysuuid_x16 not null;
  travel_id       : abap.numc(8);
  customer_id     : abap.numc(6);
  begin_date      : abap.dats;
  end_date        : abap.dats;
  @Semantics.amount.currencyCode : 'ztravel_a.currency_code'
  total_price     : abap.curr(16,2);
  currency_code   : abap.cuky;
  status          : abap.char(1);
  created_by      : abp_creation_user;
  created_at      : abp_creation_tstmpl;
  last_changed_by : abp_lastchange_user;
  last_changed_at : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
```

### 2. Root view entity

```cds
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Travel - root'
define root view entity ZI_Travel
  as select from ztravel_a
{
  key travel_uuid     as TravelUUID,
      travel_id       as TravelID,
      customer_id     as CustomerID,
      begin_date      as BeginDate,
      end_date        as EndDate,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      total_price     as TotalPrice,
      currency_code   as CurrencyCode,
      status          as Status,
      @Semantics.user.createdBy: true
      created_by      as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at      as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt
}
```

### 3. Behavior definition

```cds
managed implementation in class zbp_i_travel unique;
strict ( 2 );

define behavior for ZI_Travel alias Travel
persistent table ztravel_a
lock master
authorization master ( instance )
etag master LocalLastChangedAt
{
  create;
  update;
  delete;

  field ( numbering : managed, readonly ) TravelUUID;
  field ( readonly ) TravelID, Status, CreatedBy, CreatedAt, LastChangedBy, LastChangedAt;
  field ( mandatory ) CustomerID, BeginDate, EndDate;

  action acceptTravel result [1] $self;
  action rejectTravel result [1] $self;

  determination setInitialValues on modify { create; }
  validation validateDates on save { create; field BeginDate, EndDate; }

  mapping for ztravel_a
  {
    TravelUUID = travel_uuid;   TravelID = travel_id;     CustomerID = customer_id;
    BeginDate = begin_date;     EndDate = end_date;       TotalPrice = total_price;
    CurrencyCode = currency_code; Status = status;        CreatedBy = created_by;
    CreatedAt = created_at;     LastChangedBy = last_changed_by;
    LastChangedAt = last_changed_at; LocalLastChangedAt = local_last_changed_at;
  }
}
```

### 4. Behavior implementation (EML – Entity Manipulation Language)

```abap
CLASS lhc_travel DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Travel RESULT result.
    METHODS setinitialvalues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Travel~setInitialValues.
    METHODS validatedates FOR VALIDATE ON SAVE
      IMPORTING keys FOR Travel~validateDates.
    METHODS accepttravel FOR MODIFY
      IMPORTING keys FOR ACTION Travel~acceptTravel RESULT result.
    METHODS rejecttravel FOR MODIFY
      IMPORTING keys FOR ACTION Travel~rejectTravel RESULT result.
ENDCLASS.

CLASS lhc_travel IMPLEMENTATION.
  METHOD get_instance_authorizations.
    " everyone may do everything in this demo
  ENDMETHOD.

  METHOD setinitialvalues.
    READ ENTITIES OF zi_travel IN LOCAL MODE
      ENTITY Travel FIELDS ( Status TravelID ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_travel).

    SELECT MAX( travel_id ) FROM ztravel_a INTO @DATA(lv_max_id).

    MODIFY ENTITIES OF zi_travel IN LOCAL MODE
      ENTITY Travel UPDATE FIELDS ( Status TravelID )
      WITH VALUE #( FOR ls IN lt_travel INDEX INTO i
                    ( %tky     = ls-%tky
                      Status   = 'O'                    " open
                      TravelID = lv_max_id + i ) ).
  ENDMETHOD.

  METHOD validatedates.
    READ ENTITIES OF zi_travel IN LOCAL MODE
      ENTITY Travel FIELDS ( BeginDate EndDate ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_travel).

    LOOP AT lt_travel INTO DATA(ls_travel).
      IF ls_travel-EndDate < ls_travel-BeginDate.
        APPEND VALUE #( %tky = ls_travel-%tky ) TO failed-travel.
        APPEND VALUE #( %tky = ls_travel-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'End date must be after begin date' )
                        %element-EndDate = if_abap_behv=>mk-on )
               TO reported-travel.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD accepttravel.
    MODIFY ENTITIES OF zi_travel IN LOCAL MODE
      ENTITY Travel UPDATE FIELDS ( Status )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'A' ) ).

    READ ENTITIES OF zi_travel IN LOCAL MODE
      ENTITY Travel ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_travel).
    result = VALUE #( FOR ls IN lt_travel ( %tky = ls-%tky %param = ls ) ).
  ENDMETHOD.

  METHOD rejecttravel.
    MODIFY ENTITIES OF zi_travel IN LOCAL MODE
      ENTITY Travel UPDATE FIELDS ( Status )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'X' ) ).
    READ ENTITIES OF zi_travel IN LOCAL MODE
      ENTITY Travel ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_travel).
    result = VALUE #( FOR ls IN lt_travel ( %tky = ls-%tky %param = ls ) ).
  ENDMETHOD.
ENDCLASS.
```

### 5. Projection, service definition and binding

```cds
@EndUserText.label: 'Travel - projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_Travel
  provider contract transactional_query
  as projection on ZI_Travel
{
  key TravelUUID,
      @Search.defaultSearchElement: true
      TravelID,
      CustomerID,
      BeginDate,
      EndDate,
      TotalPrice,
      CurrencyCode,
      Status,
      LocalLastChangedAt
}
```

```cds
projection;
strict ( 2 );

define behavior for ZC_Travel alias Travel
use etag
{
  use create;
  use update;
  use delete;
  use action acceptTravel;
  use action rejectTravel;
}
```

```cds
@EndUserText.label: 'Travel service'
define service ZUI_TRAVEL {
  expose ZC_Travel as Travel;
}
```

Finally: *New → Service Binding* `ZUI_TRAVEL_O4`, binding type **OData V4 – UI**, service definition `ZUI_TRAVEL` → **Publish** → select the entity → **Preview** to open a generated Fiori elements List Report. Choose **OData V4 – Web API** for an API without UI annotations.

## EML cheat sheet

| Statement | Purpose |
|---|---|
| `READ ENTITIES OF bo ENTITY e FIELDS ( ... ) WITH keys RESULT lt` | Read BO data (incl. transactional buffer) |
| `MODIFY ENTITIES OF bo ENTITY e CREATE / UPDATE / DELETE / EXECUTE action ...` | Change BO data |
| `COMMIT ENTITIES.` | Save (outside behavior pool – e.g. in a report or class) |
| `IN LOCAL MODE` | Skip authorization & feature control (inside own BO) |
| `%tky` / `%key` / `%cid` / `%param` / `%msg` / `%element` | Derived-type components: transactional key, key, content ID (for create), action result, message, field marker |
| `failed` / `reported` / `mapped` | Response structures: failed keys, messages, mapping of `%cid` to new keys |

```abap
" Using a RAP BO from any ABAP code (e.g. a report)
MODIFY ENTITIES OF zi_travel
  ENTITY Travel
  CREATE FIELDS ( CustomerID BeginDate EndDate CurrencyCode )
  WITH VALUE #( ( %cid = 'T1' CustomerID = '000001'
                  BeginDate = '20261101' EndDate = '20261110' CurrencyCode = 'EUR' ) )
  MAPPED DATA(ls_mapped) FAILED DATA(ls_failed) REPORTED DATA(ls_reported).

COMMIT ENTITIES RESPONSE OF zi_travel
  FAILED DATA(ls_commit_failed) REPORTED DATA(ls_commit_reported).
```

## SEGW (classic) vs. RAP – interview comparison

| SEGW / Gateway | RAP |
|---|---|
| Model in SEGW, code in DPC_EXT/MPC_EXT | Model in CDS, behavior in BDEF + behavior pool |
| You implement query options manually (or use RDS) | SADL handles queries automatically |
| OData V2 mainly | OData V2 and **V4**, UI and Web API |
| Transaction handling: you (BAPIs, COMMIT) | Transactional buffer, save sequence, locking, ETag, draft by framework |
| SAP GUI based | ADT (Eclipse) only |
| Still used for legacy/complex custom logic | Strategic for S/4HANA and BTP (Clean Core) |

:::lab Lab 21 – RAP student app
Using ADT: create table `ZSTUDENT_A` (UUID key + admin fields), root view entity `ZI_StudentR`, managed BDEF with: create/update/delete, managed UUID numbering, determination that sets `Status = 'N'` on create, validation that the e-mail contains '@', action `activate` that sets `Status = 'A'`. Create projection, service definition, **OData V4 UI** binding, publish and preview the Fiori app. Then test the same service with an HTTP client: `GET .../Student?$top=2&$count=true`.
:::

:::solution Lab 21 (behavior part)
```cds
managed implementation in class zbp_i_studentr unique;
strict ( 2 );
define behavior for ZI_StudentR alias Student
persistent table zstudent_a
lock master
authorization master ( instance )
etag master LocalLastChangedAt
{
  create; update; delete;
  field ( numbering : managed, readonly ) StudentUUID;
  field ( readonly ) Status;
  action activate result [1] $self;
  determination setStatusNew on modify { create; }
  validation validateEmail on save { create; field Email; }
  mapping for zstudent_a corresponding;
}
```
```abap
METHOD setstatusnew.
  MODIFY ENTITIES OF zi_studentr IN LOCAL MODE
    ENTITY Student UPDATE FIELDS ( Status )
    WITH VALUE #( FOR k IN keys ( %tky = k-%tky Status = 'N' ) ).
ENDMETHOD.

METHOD validateemail.
  READ ENTITIES OF zi_studentr IN LOCAL MODE
    ENTITY Student FIELDS ( Email ) WITH CORRESPONDING #( keys )
    RESULT DATA(lt_students).
  LOOP AT lt_students INTO DATA(ls) WHERE Email NS '@'.
    APPEND VALUE #( %tky = ls-%tky ) TO failed-student.
    APPEND VALUE #( %tky = ls-%tky
                    %msg = new_message_with_text( text = 'Invalid e-mail address' )
                    %element-Email = if_abap_behv=>mk-on ) TO reported-student.
  ENDLOOP.
ENDMETHOD.

METHOD activate.
  MODIFY ENTITIES OF zi_studentr IN LOCAL MODE
    ENTITY Student UPDATE FIELDS ( Status )
    WITH VALUE #( FOR k IN keys ( %tky = k-%tky Status = 'A' ) ).
  READ ENTITIES OF zi_studentr IN LOCAL MODE
    ENTITY Student ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt).
  result = VALUE #( FOR s IN lt ( %tky = s-%tky %param = s ) ).
ENDMETHOD.
```
`mapping for zstudent_a corresponding;` works only when the CDS element names equal the table field names (case is ignored) – otherwise list the mapping explicitly as in the Travel example. Because of `authorization master ( instance )` you also need an (empty) `get_instance_authorizations` method, exactly as in the Travel example.
:::

# 22. Consuming OData Services

## From SAPUI5 (Fiori)

```text
// manifest.json - data source and model
"dataSources": {
  "mainService": { "uri": "/sap/opu/odata/sap/ZSALES_SRV/", "type": "OData",
                   "settings": { "odataVersion": "2.0" } } },
"models": { "": { "dataSource": "mainService" } }

// Controller (JavaScript) - V2 model
const oModel = this.getView().getModel();
oModel.read("/OrderSet", {
  urlParameters: { "$expand": "ToItems", "$top": "20" },
  filters: [ new sap.ui.model.Filter("Customer", "EQ", "100001") ],
  success: (oData) => console.log(oData.results),
  error:   (oErr)  => sap.m.MessageBox.error(oErr.message)
});
oModel.create("/OrderSet", { Customer: "100001", Currency: "EGP" }, { success: ... });
oModel.update("/OrderSet('4711')", { Customer: "100002" });
oModel.remove("/OrderSet('4711')");
oModel.callFunction("/ReleaseOrder", { method: "POST", urlParameters: { OrderId: "4711" } });
```

The V2 ODataModel fetches the **CSRF token**, bundles requests into **$batch**, and handles ETags automatically.

## From Postman / any HTTP client – the CSRF dance

1. `GET /sap/opu/odata/sap/ZSALES_SRV/` with header `X-CSRF-Token: Fetch` (and Basic Auth). Response header contains the token + session cookies.
2. `POST/PUT/DELETE` with header `X-CSRF-Token: <token>` and the same cookies. Without it you get **403 – CSRF token validation failed**.

## From ABAP (consume a remote OData service)

Option A – generic HTTP client:

```abap
DATA lo_client TYPE REF TO if_http_client.
cl_http_client=>create_by_destination( EXPORTING destination = 'Z_REMOTE_ODATA'   " SM59
                                       IMPORTING client      = lo_client ).
lo_client->request->set_method( if_http_request=>co_request_method_get ).
cl_http_utility=>set_request_uri( request = lo_client->request
                                  uri     = '/sap/opu/odata/sap/ZSALES_SRV/OrderSet?$format=json&$top=5' ).
lo_client->send( ).
lo_client->receive( ).
lo_client->response->get_status( IMPORTING code = DATA(lv_code) ).
DATA(lv_json) = lo_client->response->get_cdata( ).
lo_client->close( ).

" parse JSON into ABAP
TYPES: BEGIN OF ty_order, orderid TYPE string, customer TYPE string, END OF ty_order.
DATA: BEGIN OF ls_resp,
        BEGIN OF d,
          results TYPE STANDARD TABLE OF ty_order WITH EMPTY KEY,
        END OF d,
      END OF ls_resp.
/ui2/cl_json=>deserialize( EXPORTING json = lv_json
                           CHANGING  data = ls_resp ).
```

Option B – **OData Client Proxy** (`/IWBEP/CL_CP_FACTORY_REMOTE` / `CL_WEB_ODATA_CLIENT_FACTORY` on BTP) with a **Service Consumption Model** generated in ADT from the `$metadata` – typed, recommended in S/4HANA Cloud and BTP.

## OData in SAP integration

- **SAP Integration Suite (CPI)** – OData receiver/sender adapters.
- **S/4HANA standard APIs** – published on the **SAP Business Accelerator Hub** (api.sap.com), e.g. `API_SALES_ORDER_SRV` (V2), `api_salesorder` (V4). Prefer them over custom services when available (Clean Core).

# 23. Performance, Security and Troubleshooting

## Performance checklist

- Push filter, sorting and paging **to the database** (`WHERE`, `ORDER BY`, `UP TO ... OFFSET`) – or use CDS/RAP so SADL does it.
- Never `SELECT *` – select only fields of the entity, honour `$select` for wide entities.
- Avoid the N+1 problem with `$expand` → implement `GET_EXPANDED_ENTITYSET` or use CDS associations.
- Always enforce a **maximum page size** if `$top` is missing.
- Implement `$count` / `$inlinecount` with `SELECT COUNT(*)`, not by reading all rows.
- Use `/IWFND/TRACES` and the *Performance Trace* (`sap-statistics=true` in the URL → response header shows gateway / backend / DB time).
- Use `ST05` (SQL trace) and `SAT` (runtime analysis) on the backend for slow methods.
- Metadata cache: after model changes clear `/IWFND/CACHE_CLEANUP` and `/IWBEP/CACHE_CLEANUP` – but keep caches active in production.

## Security checklist

- Users need authorization object **`S_SERVICE`** for the service (add via role in PFCG – *Authorization Default → TADIR Service → IWSG / IWSV*) plus `S_RFC` (hub) and the **business authorizations** inside your code (`AUTHORITY-CHECK` in DPC or DCL in CDS).
- CSRF protection is on by default for modifying requests – don't switch it off.
- Validate all input – never build dynamic WHERE clauses from raw strings (SQL injection); use `cl_abap_dyn_prg=>escape_quotes` / the framework's converted where clause.
- Don't return more fields than needed (e.g. salary data) – the client can see everything in the payload.
- Use HTTPS and SSO (SAML/X.509) in productive landscapes.

## Troubleshooting guide

| Symptom | Where to look / typical cause |
|---|---|
| 404 *Service not found* | Service not registered/activated in `/IWFND/MAINT_SERVICE`; ICF node inactive (SICF); wrong system alias |
| 403 *Forbidden* | Missing CSRF token or `S_SERVICE`/role; check `SU53` for the user |
| 500 *Internal Server Error* | Short dump → `ST22`; `/IWFND/ERROR_LOG` and `/IWBEP/ERROR_LOG` (call stack + *Replay*) |
| 501 *Not implemented* | The DPC_EXT method for that operation is not redefined |
| `$metadata` shows old model | Clear metadata cache (`/IWFND/CACHE_CLEANUP`, `/IWBEP/CACHE_CLEANUP`) |
| Expanded data empty | Deep structure component name ≠ navigation property name; `et_expanded_tech_clauses` not filled |
| Filter ignored | Filter not implemented in GET_ENTITYSET, or complex filter not in select-options |
| Debugging | External breakpoint (for the service user) in DPC_EXT method; then call from browser/Gateway Client/Fiori |

:::lab Lab 23 – Debug and analyse
1) Set an external breakpoint in your `STUDENTSET_GET_ENTITYSET`, call the service from the browser and step through. 2) Call `...StudentSet('99999999')` and find the entry in `/IWFND/ERROR_LOG`; use *Replay*. 3) Call `...StudentSet?sap-statistics=true` and read the `sap-statistics` response header. 4) Remove `S_SERVICE` from a test user and observe the 403 + `SU53`.
:::

:::solution Lab 23 – what you should observe
- The debugger stops in the DPC_EXT method with `io_tech_request_context` filled – inspect `get_filter( )`, `get_top( )`.
- The error log shows the 404 `resource_not_found` exception with the entity type; Replay opens the Gateway Client with the same request.
- `sap-statistics` shows `total`, `fw` (framework), `app` (your code), `gwtotal` times in ms – use it to prove where time is spent.
- SU53 shows the failed check on `S_SERVICE` with the service hash value.
:::
