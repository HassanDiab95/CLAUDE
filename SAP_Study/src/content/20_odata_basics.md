@part Part II — OData & SAP Gateway | REST & OData protocol, Gateway architecture, SEGW, CRUD, / query options, deep insert, $batch, CDS-based services & RAP

# 13. REST and OData Fundamentals

## Why OData?

SAP Fiori apps (SAPUI5), mobile apps, SAP BTP extensions and third-party systems all need to read and change SAP data over HTTP. **OData (Open Data Protocol)** is the OASIS standard SAP chose for this: a **REST-based** protocol with a uniform way to describe data (metadata), query it (URL options) and change it (HTTP verbs). It is the backbone of Fiori.

## REST in five minutes

REST (*Representational State Transfer*) is an architectural style:

- Everything is a **resource** identified by a **URI**: `/SalesOrderSet('4711')`.
- You act on resources using standard **HTTP methods**.
- Communication is **stateless** – every request carries everything needed.
- Representations are exchanged as **JSON** or **XML (Atom)**.

| HTTP method | CRUD | OData example | SEGW (DPC) method |
|---|---|---|---|
| `GET` (collection) | Read list | `GET /OrderSet` | `*_GET_ENTITYSET` |
| `GET` (single) | Read one | `GET /OrderSet('4711')` | `*_GET_ENTITY` |
| `POST` | Create | `POST /OrderSet` + body | `*_CREATE_ENTITY` |
| `PUT` | Replace / update | `PUT /OrderSet('4711')` + body | `*_UPDATE_ENTITY` |
| `PATCH` / `MERGE` | Partial update | `PATCH /OrderSet('4711')` | `*_UPDATE_ENTITY` (or PATCH_ENTITY) |
| `DELETE` | Delete | `DELETE /OrderSet('4711')` | `*_DELETE_ENTITY` |

## HTTP status codes you must know

| Code | Meaning | Typical OData situation |
|---|---|---|
| 200 OK | Success with body | GET, also PUT in some versions |
| 201 Created | Entity created | POST successful |
| 204 No Content | Success, no body | PUT / PATCH / DELETE successful |
| 400 Bad Request | Wrong request / business error | Validation failed (`/IWBEP/CX_MGW_BUSI_EXCEPTION`) |
| 401 Unauthorized | Not logged on | Missing/wrong credentials |
| 403 Forbidden | No authorization / CSRF failed | Missing `S_SERVICE` role or CSRF token |
| 404 Not Found | Resource/service not found | Wrong key, service not activated |
| 405 Method Not Allowed | Operation not implemented | e.g. DELETE not redefined |
| 412 Precondition Failed | ETag mismatch | Someone else changed the entity |
| 428 Precondition Required | ETag missing | `If-Match` header required |
| 500 Internal Server Error | Technical error / dump | `/IWBEP/CX_MGW_TECH_EXCEPTION`, short dump |
| 501 Not Implemented | Method not implemented | Default DPC method raised "not implemented" |

## OData versions

| | OData V2 | OData V4 |
|---|---|---|
| Status | Most widespread in SAP (SEGW, Fiori elements V2) | Current standard (RAP, Fiori elements V4, CAP) |
| Build tool in SAP | SEGW, CDS `@OData.publish`, RAP binding V2 | RAP service binding V4 (SEGW V4 exists but rare) |
| Count | `$inlinecount=allpages`, `/$count` | `$count=true`, `/$count` |
| Partial update | `MERGE` / `PATCH` | `PATCH` |
| Operations | Function imports | Actions (POST, can change data) & functions (GET, read-only) |
| Payload | JSON verbose (`d`, `results`, `__metadata`) | Leaner JSON (`value`, `@odata.context`) |
| Search | SAP extension `search=` | Standard `$search` |
| Expand options | `$expand=Items` | `$expand=Items($select=..;$filter=..)` nested options |

## The building blocks of an OData service (EDM)

The **Entity Data Model (EDM)** describes the service:

- **Entity Type** – a structure with properties and a key (like a DB table definition): `SalesOrder` with `OrderId`, `Customer`, `NetAmount`.
- **Property** – a field with an EDM type (`Edm.String`, `Edm.Decimal`, `Edm.DateTime` (V2) / `Edm.Date` (V4), `Edm.Boolean`, `Edm.Guid`, `Edm.Int32` ...).
- **Key** – one or more properties identifying an entity.
- **Entity Set** – a collection of entities of one type – what you call in the URL: `SalesOrderSet`.
- **Association** (V2) – a relationship between two entity types with cardinality (1:1, 1:n, n:m).
- **Navigation Property** – a named path through an association: `SalesOrder/ToItems`.
- **Complex Type** – a structure without a key, used as a property type or function return.
- **Function Import** (V2) / **Action & Function** (V4) – custom operations that are not plain CRUD: `ReleaseOrder`.

## Service document and $metadata

```text
GET /sap/opu/odata/sap/ZSALES_SRV/              -> service document (list of entity sets)
GET /sap/opu/odata/sap/ZSALES_SRV/$metadata     -> full EDM in XML (CSDL)
GET /sap/opu/odata/sap/ZSALES_SRV/OrderSet?$format=json
GET /sap/opu/odata/sap/ZSALES_SRV/OrderSet('4711')/ToItems
```

Excerpt of `$metadata` (V2):

```text
<EntityType Name="Order" sap:content-version="1">
  <Key><PropertyRef Name="OrderId"/></Key>
  <Property Name="OrderId"   Type="Edm.String"  Nullable="false" MaxLength="10"/>
  <Property Name="Customer"  Type="Edm.String"  MaxLength="10"/>
  <Property Name="NetAmount" Type="Edm.Decimal" Precision="15" Scale="2"/>
  <Property Name="Currency"  Type="Edm.String"  MaxLength="5" sap:semantics="currency-code"/>
  <NavigationProperty Name="ToItems" Relationship="ZSALES_SRV.Order_Items"
                      FromRole="FromRole_Order" ToRole="ToRole_Items"/>
</EntityType>
<EntitySet Name="OrderSet" EntityType="ZSALES_SRV.Order" sap:creatable="true"
           sap:updatable="true" sap:deletable="true" sap:pageable="true"/>
```

## A V2 JSON response

```text
{
  "d": {
    "results": [
      { "__metadata": { "uri": ".../OrderSet('4711')", "type": "ZSALES_SRV.Order" },
        "OrderId": "4711", "Customer": "100001",
        "NetAmount": "1500.00", "Currency": "EGP" }
    ]
  }
}
```

:::lab Lab 13 – Read a public OData service
Open `https://services.odata.org/V2/Northwind/Northwind.svc/` in a browser (or Postman). 1) Read `$metadata` and find the entity type `Product`, its key and the navigation property to `Category`. 2) Read the first 5 products sorted by price descending as JSON. 3) Read product 1 with its category expanded. 4) Count products with UnitPrice > 50.
:::

:::solution Lab 13
```text
1) .../Northwind.svc/$metadata  -> EntityType Product, Key ProductID,
   NavigationProperty "Category" (also Order_Details, Supplier)
2) .../Products?$top=5&$orderby=UnitPrice desc&$format=json
3) .../Products(1)?$expand=Category&$format=json
4) .../Products/$count?$filter=UnitPrice gt 50
```
:::

# 14. SAP Gateway Architecture

**SAP Gateway** is the SAP NetWeaver / ABAP Platform component that exposes OData services. Since 7.40 it is part of the standard stack (`SAP_GWFND`). It has two logical layers:

| Layer | Component (old add-ons) | Role | Key transactions |
|---|---|---|---|
| **Gateway Hub / Frontend server** | `IW_FND` (now in SAP_GWFND) | Receives HTTP requests, routes to backend, service registry, caching, ICF | `/IWFND/MAINT_SERVICE`, `/IWFND/GW_CLIENT`, `/IWFND/ERROR_LOG`, `/IWFND/CACHE_CLEANUP` |
| **Backend (BEP)** | `IW_BEP` | Contains the service implementation (MPC/DPC classes) and business logic | `SEGW`, `/IWBEP/REG_SERVICE`, `/IWBEP/ERROR_LOG`, `/IWBEP/CACHE_CLEANUP` |

## Deployment options

- **Embedded deployment** – Gateway hub and backend in the **same** system (typical for S/4HANA). Simpler, no RFC; recommended by SAP for S/4HANA.
- **Hub deployment (central hub)** – a separate Gateway/Fiori Frontend Server (FES) connected via **trusted RFC** to one or more backends (ECC, CRM...). The UI5 apps and Fiori Launchpad run on the hub. *System alias* (`/IWFND/MAINT_SERVICE` → *Add System Alias*) tells the hub which backend serves the service.

## Request flow

```text
Browser / Fiori app
   |  HTTPS  GET /sap/opu/odata/sap/ZSALES_SRV/OrderSet?$top=10
   v
ICF node /sap/opu/odata  (SICF)  ->  Gateway Hub runtime (IWFND)
   |  checks service registry + system alias (+ RFC if hub deployment)
   v
Backend runtime (IWBEP) -> Model Provider Class (MPC_EXT) builds the model
                        -> Data Provider Class  (DPC_EXT) ORDERSET_GET_ENTITYSET
   |                         -> your ABAP: SELECT / BAPI / CDS / class call
   v
Response serialized to JSON/XML and returned
```

## Key transactions & tools

| Transaction | Purpose |
|---|---|
| `SEGW` | Gateway Service Builder – create projects, model, generate classes |
| `/IWFND/MAINT_SERVICE` | Register/activate services on the hub, assign system alias, ICF node, roles |
| `/IWFND/GW_CLIENT` | Built-in REST client to test requests (incl. $batch, headers, CSRF) |
| `/IWFND/ERROR_LOG` / `/IWBEP/ERROR_LOG` | Error logs with call stack, replay of failing request |
| `/IWFND/TRACES` | Performance & payload traces for a user/service |
| `/IWFND/CACHE_CLEANUP` / `/IWBEP/CACHE_CLEANUP` | Clear metadata cache after model changes |
| `SICF` | Activate ICF nodes (`/sap/opu/odata`) |
| `/IWFND/V4_ADMIN` | Publish OData V4 service groups |
| `SE80` / ADT | Edit DPC_EXT / MPC_EXT classes |

# 15. Building Your First Service in SEGW

We will build `ZSALES_SRV` with an entity `Order` based on table VBAK.

## Step-by-step

1. **Create project** – `SEGW` → *Create Project* → `ZSALES`, description, *Project Type: Service with SAP Annotations*, *Generation Strategy: Standard*, package (or `$TMP` for practice).
2. **Model the data** – right-click *Data Model* → *Import* → *DDIC Structure* → `VBAK` (or your own structure `ZSTR_ORDER`). Name the entity type `Order`, select fields VBELN, ERDAT, KUNNR, NETWR, WAERK, mark **VBELN as key**, tick *Create Default Entity Set* (`OrderSet`). Rename ABAP field names to readable OData names (`OrderId`, `CreatedOn`, `Customer`, `NetAmount`, `Currency`).
   Alternatives: *Create → Entity Type* manually, import from *RFC/BOR interface* (wizard maps a BAPI), or *Redefine* from CDS / BW query.
3. **Set properties** – on the Entity Set: Creatable, Updatable, Deletable, Pageable, Addressable; on properties: Nullable, Filterable, Sortable, label (`sap:label`).
4. **Generate Runtime Objects** (red/white wheel icon). SEGW generates:

| Generated object | Name | Purpose | Edit it? |
|---|---|---|---|
| Model Provider base class | `ZCL_ZSALES_MPC` | Defines the model in code (from SEGW) | **No** – regenerated |
| Model Provider extension | `ZCL_ZSALES_MPC_EXT` | Redefine `DEFINE` to add annotations / changes in code | Yes |
| Data Provider base class | `ZCL_ZSALES_DPC` | Generated CRUD method stubs raising "not implemented" | **No** – regenerated |
| Data Provider extension | `ZCL_ZSALES_DPC_EXT` | **Your business logic**: redefine CRUD methods | Yes |
| Technical model name | `ZSALES_MDL` | Registered model (`/IWBEP/REG_MODEL`) | – |
| Technical service name | `ZSALES_SRV` | Registered service (`/IWBEP/REG_SERVICE`) | – |

5. **Register the service** – `/IWFND/MAINT_SERVICE` → *Add Service* → system alias `LOCAL` (embedded) → search `ZSALES_SRV` → *Add selected services* → package. (Or in SEGW: *Service Maintenance* folder → system → *Register*.)
6. **Test** – in `/IWFND/MAINT_SERVICE` select the service → *SAP Gateway Client* → `GET /sap/opu/odata/sap/ZSALES_SRV/$metadata` → status 200.

:::warn Golden rule
Never put code in the `*_MPC` or `*_DPC` base classes – they are **overwritten** every time you click *Generate*. Always redefine the methods in `*_DPC_EXT` / `*_MPC_EXT`.
:::

# 16. Implementing CRUD in the DPC_EXT

Open `ZCL_ZSALES_DPC_EXT` in SE80/ADT, select a method such as `ORDERSET_GET_ENTITYSET` and click *Redefine*. Every CRUD method follows the naming pattern `<ENTITYSET>_<OPERATION>`.

## Method signature essentials

| Parameter | Content |
|---|---|
| `iv_entity_name`, `iv_entity_set_name`, `iv_source_name` | Names of the requested entity (set) and of the source entity when navigating |
| `it_key_tab` | Key values from the URI: `('4711')` → name/value pairs |
| `it_navigation_path` | Path of navigation properties used |
| `it_filter_select_options`, `iv_filter_string` | `$filter` as select-options / as string (old style) |
| `is_paging` (`top`, `skip`), `it_order` | `$top`, `$skip`, `$orderby` |
| `io_tech_request_context` | **Recommended**: object with everything (keys, filter, select, paging, navigation) using **technical (ABAP) names** |
| `io_data_provider` | (CREATE/UPDATE) Reads the request body: `io_data_provider->read_entry_data( IMPORTING es_data = ls_entity )` |
| `er_entity` / `et_entityset` | Your result |
| `es_response_context` | Inline count, delta token, etc. |

## GET_ENTITYSET – read a list

```abap
METHOD orderset_get_entityset.
  " 1) $filter as SQL WHERE clause built by the framework (technical names!)
  DATA(lv_where) = io_tech_request_context->get_osql_where_clause_convert( ).

  " 2) select data (use a field list - never SELECT * in real services)
  SELECT vbeln, erdat, kunnr, netwr, waerk
    FROM vbak
    WHERE (lv_where)
    ORDER BY vbeln
    INTO CORRESPONDING FIELDS OF TABLE @et_entityset
    UP TO 1000 ROWS.

  " 3) $inlinecount=allpages
  IF io_tech_request_context->has_inlinecount( ) = abap_true.
    es_response_context-inlinecount = lines( et_entityset ).
  ENDIF.

  " 4) $orderby, $top / $skip - generic helpers
  /iwbep/cl_mgw_data_util=>orderby( EXPORTING it_order = it_order
                                    CHANGING  ct_data  = et_entityset ).
  /iwbep/cl_mgw_data_util=>paging(  EXPORTING is_paging = is_paging
                                    CHANGING  ct_data   = et_entityset ).
ENDMETHOD.
```

:::tip Paging on the database
The helper above pages in ABAP memory. For big tables push paging to the DB: read `io_tech_request_context->get_top( )` / `get_skip( )` and use `UP TO lv_top ROWS OFFSET lv_skip` in the SELECT (with an `ORDER BY`). Count separately with `SELECT COUNT(*)` for `$inlinecount`.
:::

## GET_ENTITY – read one

```abap
METHOD orderset_get_entity.
  DATA ls_key TYPE zcl_zsales_mpc=>ts_order.

  " converts key values into the entity structure (technical names)
  io_tech_request_context->get_converted_keys( IMPORTING es_key_values = ls_key ).

  SELECT SINGLE vbeln, erdat, kunnr, netwr, waerk
    FROM vbak
    WHERE vbeln = @ls_key-vbeln
    INTO CORRESPONDING FIELDS OF @er_entity.

  IF sy-subrc <> 0.
    RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
      EXPORTING textid  = /iwbep/cx_mgw_busi_exception=>resource_not_found
                entity_type = iv_entity_name.
  ENDIF.
ENDMETHOD.
```

`zcl_zsales_mpc=>ts_order` is the structure type generated for the entity (also `tt_order` for the table type).

## CREATE_ENTITY – POST

```abap
METHOD orderset_create_entity.
  DATA ls_order TYPE zcl_zsales_mpc=>ts_order.

  io_data_provider->read_entry_data( IMPORTING es_data = ls_order ).

  " validation -> 400 with readable message
  IF ls_order-kunnr IS INITIAL.
    DATA(lo_msg) = mo_context->get_message_container( ).
    lo_msg->add_message_text_only( iv_msg_type = 'E'
                                   iv_msg_text = 'Customer is mandatory' ).
    RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
      EXPORTING message_container = lo_msg.
  ENDIF.

  " real life: call BAPI_SALESORDER_CREATEFROMDAT2 / a RAP BO / your API class
  DATA(lo_api) = NEW zcl_order_api( ).
  TRY.
      ls_order-vbeln = lo_api->create( ls_order ).
    CATCH zcx_order_error INTO DATA(lx).
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING previous = lx
                  message  = CONV #( lx->get_text( ) ).
  ENDTRY.

  er_entity = ls_order.          " return the created entity (with new key) -> 201
ENDMETHOD.
```

Request in the Gateway Client:

```text
POST /sap/opu/odata/sap/ZSALES_SRV/OrderSet
Content-Type: application/json
X-CSRF-Token: <token from a previous GET with X-CSRF-Token: Fetch>

{ "Customer": "100001", "NetAmount": "250.00", "Currency": "EGP" }
```

## UPDATE_ENTITY – PUT / PATCH

```abap
METHOD orderset_update_entity.
  DATA: ls_key   TYPE zcl_zsales_mpc=>ts_order,
        ls_order TYPE zcl_zsales_mpc=>ts_order.

  io_tech_request_context->get_converted_keys( IMPORTING es_key_values = ls_key ).
  io_data_provider->read_entry_data( IMPORTING es_data = ls_order ).
  ls_order-vbeln = ls_key-vbeln.               " key always from the URI

  " ... lock, update via BAPI / API class, unlock ...
  er_entity = ls_order.                        " -> 204 No Content
ENDMETHOD.
```

:::note PATCH / MERGE
For partial updates the framework calls `PATCH_ENTITY` (if redefined in `/IWBEP/IF_MGW_APPL_SRV_RUNTIME~PATCH_ENTITY`) – by default it reads the current entity via GET_ENTITY, merges the sent fields and calls UPDATE_ENTITY. So a working GET_ENTITY is required for PATCH.
:::

## DELETE_ENTITY

```abap
METHOD orderset_delete_entity.
  DATA ls_key TYPE zcl_zsales_mpc=>ts_order.
  io_tech_request_context->get_converted_keys( IMPORTING es_key_values = ls_key ).

  DATA(lo_api) = NEW zcl_order_api( ).
  TRY.
      lo_api->delete( ls_key-vbeln ).          " -> 204 No Content
    CATCH zcx_order_error INTO DATA(lx).
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING message = CONV #( lx->get_text( ) ).
  ENDTRY.
ENDMETHOD.
```

## Error handling in Gateway

| Exception | HTTP | Use |
|---|---|---|
| `/IWBEP/CX_MGW_BUSI_EXCEPTION` | 400 (or as set via `http_status_code`) | Business / validation errors – shown to the user |
| `/IWBEP/CX_MGW_TECH_EXCEPTION` | 500 | Technical errors (unexpected) |
| `/IWBEP/CX_MGW_NOT_IMPL_EXC` | 501 | Raised by the generated base class for non-redefined methods |

The **message container** (`mo_context->get_message_container( )`) collects one or many messages (from BAPI `RETURN` tables with `add_messages_from_bapi`) that the UI shows in a message popover. Warnings and info can be sent with a successful response via the `sap-message` header (`add_message` with `iv_add_to_response_header = abap_true`).

:::lab Lab 16 – Your first CRUD service
Create table `ZTB_STUDENT` (MANDT, STUDENT_ID NUMC 8 key, NAME CHAR 40, EMAIL CHAR 60, CITY CHAR 30, CREATED_ON DATS). In SEGW create project `ZSTUDENT` with entity `Student` (set `StudentSet`) imported from the table. Implement all five CRUD methods. Test: create 3 students with POST, read all, read one, update the city with PUT, delete one. Return error 400 if the email does not contain '@' and 404 if a student does not exist.
:::

:::solution Lab 16
```abap
CLASS zcl_zstudent_dpc_ext DEFINITION PUBLIC INHERITING FROM zcl_zstudent_dpc CREATE PUBLIC.
  PROTECTED SECTION.
    METHODS studentset_get_entityset REDEFINITION.
    METHODS studentset_get_entity    REDEFINITION.
    METHODS studentset_create_entity REDEFINITION.
    METHODS studentset_update_entity REDEFINITION.
    METHODS studentset_delete_entity REDEFINITION.
  PRIVATE SECTION.
    METHODS raise_busi IMPORTING iv_text TYPE bapi_msg
                       RAISING   /iwbep/cx_mgw_busi_exception.
    METHODS check_email IMPORTING iv_email TYPE ztb_student-email
                        RAISING   /iwbep/cx_mgw_busi_exception.
ENDCLASS.

CLASS zcl_zstudent_dpc_ext IMPLEMENTATION.
  METHOD raise_busi.
    DATA(lo_msg) = mo_context->get_message_container( ).
    lo_msg->add_message_text_only( iv_msg_type = 'E' iv_msg_text = iv_text ).
    RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
      EXPORTING message_container = lo_msg.
  ENDMETHOD.

  METHOD check_email.
    IF iv_email NS '@'.
      raise_busi( |Invalid e-mail { iv_email }| ).
    ENDIF.
  ENDMETHOD.

  METHOD studentset_get_entityset.
    DATA(lv_where) = io_tech_request_context->get_osql_where_clause_convert( ).
    SELECT * FROM ztb_student WHERE (lv_where)
      INTO CORRESPONDING FIELDS OF TABLE @et_entityset.
    /iwbep/cl_mgw_data_util=>orderby( EXPORTING it_order = it_order
                                      CHANGING  ct_data  = et_entityset ).
    /iwbep/cl_mgw_data_util=>paging( EXPORTING is_paging = is_paging
                                     CHANGING  ct_data   = et_entityset ).
  ENDMETHOD.

  METHOD studentset_get_entity.
    DATA ls_key TYPE zcl_zstudent_mpc=>ts_student.
    io_tech_request_context->get_converted_keys( IMPORTING es_key_values = ls_key ).
    SELECT SINGLE * FROM ztb_student WHERE student_id = @ls_key-student_id
      INTO CORRESPONDING FIELDS OF @er_entity.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING textid           = /iwbep/cx_mgw_busi_exception=>resource_not_found
                  entity_type      = iv_entity_name
                  http_status_code = /iwbep/cx_mgw_busi_exception=>gcs_http_status_codes-not_found.
    ENDIF.
  ENDMETHOD.

  METHOD studentset_create_entity.
    DATA ls_db TYPE ztb_student.
    io_data_provider->read_entry_data( IMPORTING es_data = er_entity ).
    check_email( er_entity-email ).
    IF er_entity-student_id IS INITIAL.        " simple number: max + 1
      SELECT MAX( student_id ) FROM ztb_student INTO @DATA(lv_max).
      er_entity-student_id = lv_max + 1.
    ENDIF.
    er_entity-created_on = sy-datum.
    ls_db = CORRESPONDING #( er_entity ).
    INSERT ztb_student FROM @ls_db.
    IF sy-subrc <> 0.
      raise_busi( 'Student already exists' ).
    ENDIF.
  ENDMETHOD.

  METHOD studentset_update_entity.
    DATA: ls_key TYPE zcl_zstudent_mpc=>ts_student,
          ls_db  TYPE ztb_student.
    io_tech_request_context->get_converted_keys( IMPORTING es_key_values = ls_key ).
    io_data_provider->read_entry_data( IMPORTING es_data = er_entity ).
    er_entity-student_id = ls_key-student_id.
    check_email( er_entity-email ).
    ls_db = CORRESPONDING #( er_entity ).
    UPDATE ztb_student FROM @ls_db.
    IF sy-subrc <> 0.
      raise_busi( 'Student not found' ).
    ENDIF.
  ENDMETHOD.

  METHOD studentset_delete_entity.
    DATA ls_key TYPE zcl_zstudent_mpc=>ts_student.
    io_tech_request_context->get_converted_keys( IMPORTING es_key_values = ls_key ).
    DELETE FROM ztb_student WHERE student_id = @ls_key-student_id.
    IF sy-subrc <> 0.
      raise_busi( 'Student not found' ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
```
```text
GET    /sap/opu/odata/sap/ZSTUDENT_SRV/StudentSet?$format=json
GET    /sap/opu/odata/sap/ZSTUDENT_SRV/StudentSet('00000001')
POST   /sap/opu/odata/sap/ZSTUDENT_SRV/StudentSet  {"Name":"Ali","Email":"ali@x.com","City":"Cairo"}
PUT    /sap/opu/odata/sap/ZSTUDENT_SRV/StudentSet('00000001')  {"Name":"Ali","Email":"ali@x.com","City":"Giza"}
DELETE /sap/opu/odata/sap/ZSTUDENT_SRV/StudentSet('00000002')
```
In real projects never write directly to the DB from the DPC – call an API/BO class (and use locks and `COMMIT WORK` handled properly). Direct `INSERT` is fine for a learning table.
:::
