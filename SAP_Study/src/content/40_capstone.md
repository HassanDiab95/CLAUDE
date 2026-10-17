@part Part IV — Capstone & Cheat Sheets | One end-to-end project combining ABAP OO + OData, / exercise bank and one-page revision sheets

# 26. Capstone Project: Leave Request Management

Build a small but realistic application end-to-end. It uses **every** concept of this guide and is a great story to tell in interviews ("I built a leave request service with a layered OO design, unit tests and an OData service consumed by Fiori").

## Requirements

- Employees create leave requests (type ANNUAL / SICK / UNPAID, from date, to date, reason).
- Rules: end date ≥ start date; ANNUAL leave max 21 working days per year; SICK leave > 2 days requires an attachment; no overlapping requests.
- Managers approve or reject (with a comment). An e-mail/notification is triggered on status change.
- A Fiori list (or Postman) reads requests with filter by status/employee, paging and count; header shows employee name.
- Attachments (PDF/JPG) can be uploaded and downloaded.

## Architecture (layers)

```text
 Fiori / Postman
      |  OData V2 (SEGW)   or   OData V4 (RAP)
      v
 ZCL_ZLEAVE_DPC_EXT      <- thin: map OData <-> ABAP, convert exceptions
      |
 ZCL_LEAVE_SERVICE       <- business logic (validations, approval), events
   |-- ZIF_LEAVE_REPOSITORY  -> ZCL_LEAVE_REPOSITORY (Open SQL on ZLEAVE_REQ)
   |-- ZIF_LEAVE_RULE (Strategy) -> ZCL_RULE_DATES, ZCL_RULE_QUOTA, ZCL_RULE_OVERLAP
   |-- ZIF_NOTIFIER          -> ZCL_MAIL_NOTIFIER (CL_BCS) / test double
 ZCX_LEAVE_ERROR         <- static check exception with T100 messages (ZLEAVE)
 LTC_* test classes      <- ABAP Unit with injected test doubles
```

## Step 1 – Data model (SE11)

| Table `ZLEAVE_REQ` field | Type | Note |
|---|---|---|
| MANDT | MANDT | key |
| REQ_ID | NUMC 10 | key |
| PERNR | PERSNO | employee |
| LEAVE_TYPE | CHAR 10 | ANNUAL / SICK / UNPAID |
| BEGDA / ENDDA | DATS | period |
| DAYS | INT4 | calculated working days |
| STATUS | CHAR 1 | N=new, A=approved, R=rejected |
| REASON / MGR_COMMENT | CHAR 255 | texts |
| CHANGED_AT | TIMESTAMPL | ETag |

## Step 2 – Interfaces and exception

```abap
INTERFACE zif_leave_repository PUBLIC.
  TYPES ty_request  TYPE zleave_req.
  TYPES tt_requests TYPE STANDARD TABLE OF zleave_req WITH EMPTY KEY.
  METHODS read     IMPORTING iv_id TYPE zleave_req-req_id
                   RETURNING VALUE(rs) TYPE ty_request
                   RAISING   zcx_leave_error.
  METHODS by_employee IMPORTING iv_pernr TYPE persno
                      RETURNING VALUE(rt) TYPE tt_requests.
  METHODS save     IMPORTING is_request TYPE ty_request.
ENDINTERFACE.

INTERFACE zif_leave_rule PUBLIC.
  METHODS check IMPORTING is_request  TYPE zleave_req
                          it_existing TYPE zif_leave_repository=>tt_requests
                RAISING   zcx_leave_error.
ENDINTERFACE.

INTERFACE zif_notifier PUBLIC.
  METHODS notify IMPORTING is_request TYPE zleave_req.
ENDINTERFACE.
```

## Step 3 – Rules (Strategy pattern)

```abap
CLASS zcl_rule_dates DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION. INTERFACES zif_leave_rule.
ENDCLASS.
CLASS zcl_rule_dates IMPLEMENTATION.
  METHOD zif_leave_rule~check.
    IF is_request-endda < is_request-begda.
      RAISE EXCEPTION TYPE zcx_leave_error
        EXPORTING textid = zcx_leave_error=>invalid_period.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

CLASS zcl_rule_overlap DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION. INTERFACES zif_leave_rule.
ENDCLASS.
CLASS zcl_rule_overlap IMPLEMENTATION.
  METHOD zif_leave_rule~check.
    LOOP AT it_existing INTO DATA(ls_old)
         WHERE status <> 'R' AND req_id <> is_request-req_id
           AND begda <= is_request-endda AND endda >= is_request-begda.
      RAISE EXCEPTION TYPE zcx_leave_error
        EXPORTING textid = zcx_leave_error=>overlap
                  mv_req_id = ls_old-req_id.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
```

`ZCL_RULE_QUOTA` sums `days` of approved ANNUAL requests of the year and compares with 21.

## Step 4 – Service class with events

```abap
CLASS zcl_leave_service DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES tt_rules TYPE STANDARD TABLE OF REF TO zif_leave_rule WITH EMPTY KEY.
    EVENTS status_changed EXPORTING VALUE(es_request) TYPE zleave_req.

    METHODS constructor IMPORTING io_repo  TYPE REF TO zif_leave_repository
                                  it_rules TYPE tt_rules
                                  io_notifier TYPE REF TO zif_notifier OPTIONAL.
    METHODS create  IMPORTING is_request TYPE zleave_req
                    RETURNING VALUE(rs)  TYPE zleave_req
                    RAISING   zcx_leave_error.
    METHODS approve IMPORTING iv_id TYPE zleave_req-req_id iv_comment TYPE string OPTIONAL
                    RETURNING VALUE(rs) TYPE zleave_req
                    RAISING   zcx_leave_error.
    METHODS reject  IMPORTING iv_id TYPE zleave_req-req_id iv_comment TYPE string
                    RETURNING VALUE(rs) TYPE zleave_req
                    RAISING   zcx_leave_error.
  PRIVATE SECTION.
    DATA mo_repo     TYPE REF TO zif_leave_repository.
    DATA mt_rules    TYPE tt_rules.
    DATA mo_notifier TYPE REF TO zif_notifier.
    METHODS set_status IMPORTING iv_id TYPE zleave_req-req_id iv_status TYPE char1
                                 iv_comment TYPE string
                       RETURNING VALUE(rs) TYPE zleave_req
                       RAISING   zcx_leave_error.
    METHODS working_days IMPORTING iv_from TYPE d iv_to TYPE d RETURNING VALUE(rv) TYPE i.
ENDCLASS.

CLASS zcl_leave_service IMPLEMENTATION.
  METHOD constructor.
    mo_repo = io_repo. mt_rules = it_rules. mo_notifier = io_notifier.
  ENDMETHOD.

  METHOD create.
    rs = is_request.
    rs-status = 'N'.
    rs-days   = working_days( iv_from = rs-begda iv_to = rs-endda ).
    DATA(lt_existing) = mo_repo->by_employee( rs-pernr ).
    LOOP AT mt_rules INTO DATA(lo_rule).          " polymorphic rule check
      lo_rule->check( is_request = rs it_existing = lt_existing ).
    ENDLOOP.
    GET TIME STAMP FIELD rs-changed_at.
    mo_repo->save( rs ).
  ENDMETHOD.

  METHOD approve.
    rs = set_status( iv_id = iv_id iv_status = 'A' iv_comment = iv_comment ).
  ENDMETHOD.

  METHOD reject.
    rs = set_status( iv_id = iv_id iv_status = 'R' iv_comment = iv_comment ).
  ENDMETHOD.

  METHOD set_status.
    rs = mo_repo->read( iv_id ).
    IF rs-status <> 'N'.
      RAISE EXCEPTION TYPE zcx_leave_error
        EXPORTING textid = zcx_leave_error=>already_decided mv_req_id = iv_id.
    ENDIF.
    rs-status      = iv_status.
    rs-mgr_comment = iv_comment.
    GET TIME STAMP FIELD rs-changed_at.
    mo_repo->save( rs ).
    RAISE EVENT status_changed EXPORTING es_request = rs.
    IF mo_notifier IS BOUND.
      mo_notifier->notify( rs ).
    ENDIF.
  ENDMETHOD.

  METHOD working_days.
    DATA(lv_day) = iv_from.
    WHILE lv_day <= iv_to.
      " 1 = Monday ... 7 = Sunday ; weekend here: Friday + Saturday
      DATA(lv_wd) = ( lv_day - CONV d( '19000101' ) ) MOD 7 + 1.
      IF lv_wd <> 5 AND lv_wd <> 6.
        rv += 1.
      ENDIF.
      lv_day += 1.
    ENDWHILE.
  ENDMETHOD.
ENDCLASS.
```

:::note Calendar
In a real system use the factory calendar (`DATE_CONVERT_TO_FACTORYDATE` / `CL_SCAL_UTILS` / HR work schedules) instead of the simple weekday formula. 01.01.1900 was a Monday, which is why the formula works.
:::

## Step 5 – Unit tests with test doubles

```abap
CLASS ltd_repo DEFINITION FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_leave_repository.
    DATA mt_db TYPE zif_leave_repository=>tt_requests.
ENDCLASS.
CLASS ltd_repo IMPLEMENTATION.
  METHOD zif_leave_repository~read.
    rs = VALUE #( mt_db[ req_id = iv_id ] OPTIONAL ).
    IF rs IS INITIAL.
      RAISE EXCEPTION TYPE zcx_leave_error.
    ENDIF.
  ENDMETHOD.
  METHOD zif_leave_repository~by_employee.
    rt = VALUE #( FOR r IN mt_db WHERE ( pernr = iv_pernr ) ( r ) ).
  ENDMETHOD.
  METHOD zif_leave_repository~save.
    DELETE mt_db WHERE req_id = is_request-req_id.
    APPEND is_request TO mt_db.
  ENDMETHOD.
ENDCLASS.

CLASS ltc_leave_service DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA mo_repo TYPE REF TO ltd_repo.
    DATA mo_cut  TYPE REF TO zcl_leave_service.
    METHODS setup.
    METHODS overlap_is_rejected  FOR TESTING.
    METHODS approve_sets_status  FOR TESTING RAISING cx_static_check.
    METHODS cannot_approve_twice FOR TESTING RAISING cx_static_check.
ENDCLASS.

CLASS ltc_leave_service IMPLEMENTATION.
  METHOD setup.
    mo_repo = NEW #( ).
    mo_cut  = NEW #( io_repo  = mo_repo
                     it_rules = VALUE #( ( NEW zcl_rule_dates( ) )
                                         ( NEW zcl_rule_overlap( ) ) ) ).
  ENDMETHOD.

  METHOD overlap_is_rejected.
    mo_repo->mt_db = VALUE #( ( req_id = '1' pernr = '100' status = 'A'
                                begda = '20261101' endda = '20261105' ) ).
    TRY.
        mo_cut->create( VALUE #( req_id = '2' pernr = '100'
                                 begda = '20261104' endda = '20261108' ) ).
        cl_abap_unit_assert=>fail( msg = 'Overlap not detected' ).
      CATCH zcx_leave_error.
    ENDTRY.
  ENDMETHOD.

  METHOD approve_sets_status.
    mo_repo->mt_db = VALUE #( ( req_id = '1' pernr = '100' status = 'N' ) ).
    DATA(ls) = mo_cut->approve( '1' ).
    cl_abap_unit_assert=>assert_equals( act = ls-status exp = 'A' ).
  ENDMETHOD.

  METHOD cannot_approve_twice.
    mo_repo->mt_db = VALUE #( ( req_id = '1' pernr = '100' status = 'A' ) ).
    TRY.
        mo_cut->approve( '1' ).
        cl_abap_unit_assert=>fail( msg = 'Second approval must fail' ).
      CATCH zcx_leave_error.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
```

## Step 6 – OData service (SEGW)

- Project `ZLEAVE`: entity `LeaveRequest` (set `LeaveRequestSet`) from `ZLEAVE_REQ`, ETag on `ChangedAt`; entity `Employee` (`EmployeeSet`, from PA0001/PA0002 or a CDS) with association `Employee 1 : n LeaveRequest` (`ToRequests`); media entity `Attachment` (key `ReqId`, `FileName`); function imports `Approve` (POST, ReqId, Comment → LeaveRequest) and `Reject`.
- DPC_EXT creates the service in a factory method and maps exceptions:

```abap
CLASS zcl_zleave_dpc_ext DEFINITION PUBLIC INHERITING FROM zcl_zleave_dpc CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS /iwbep/if_mgw_appl_srv_runtime~execute_action REDEFINITION.
  PROTECTED SECTION.
    METHODS leaverequestset_create_entity REDEFINITION.
    METHODS leaverequestset_get_entityset REDEFINITION.
  PRIVATE SECTION.
    METHODS service RETURNING VALUE(ro) TYPE REF TO zcl_leave_service.
    METHODS to_gw_error IMPORTING ix TYPE REF TO zcx_leave_error
                        RAISING   /iwbep/cx_mgw_busi_exception.
ENDCLASS.

CLASS zcl_zleave_dpc_ext IMPLEMENTATION.
  METHOD service.
    ro = NEW #( io_repo     = NEW zcl_leave_repository( )
                it_rules    = VALUE #( ( NEW zcl_rule_dates( ) )
                                       ( NEW zcl_rule_overlap( ) )
                                       ( NEW zcl_rule_quota( ) ) )
                io_notifier = NEW zcl_mail_notifier( ) ).
  ENDMETHOD.

  METHOD to_gw_error.
    DATA(lo_msg) = mo_context->get_message_container( ).
    lo_msg->add_message_text_only( iv_msg_type = 'E'
                                   iv_msg_text = CONV #( ix->get_text( ) ) ).
    RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
      EXPORTING message_container = lo_msg previous = ix.
  ENDMETHOD.

  METHOD leaverequestset_create_entity.
    DATA ls_req TYPE zleave_req.
    io_data_provider->read_entry_data( IMPORTING es_data = er_entity ).
    ls_req = CORRESPONDING #( er_entity ).
    TRY.
        er_entity = CORRESPONDING #( service( )->create( ls_req ) ).
      CATCH zcx_leave_error INTO DATA(lx).
        to_gw_error( lx ).
    ENDTRY.
  ENDMETHOD.

  METHOD leaverequestset_get_entityset.
    DATA(lv_where) = io_tech_request_context->get_osql_where_clause_convert( ).
    DATA(lv_top)   = CONV i( io_tech_request_context->get_top( ) ).
    DATA(lv_skip)  = CONV i( io_tech_request_context->get_skip( ) ).
    IF lv_top = 0. lv_top = 200. ENDIF.
    SELECT * FROM zleave_req WHERE (lv_where)
      ORDER BY req_id DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @et_entityset
      UP TO @lv_top ROWS OFFSET @lv_skip.
    IF io_tech_request_context->has_inlinecount( ) = abap_true.
      SELECT COUNT(*) FROM zleave_req WHERE (lv_where) INTO @DATA(lv_cnt).
      es_response_context-inlinecount = lv_cnt.
    ENDIF.
  ENDMETHOD.

  METHOD /iwbep/if_mgw_appl_srv_runtime~execute_action.
    DATA(lv_id) = CONV zleave_req-req_id(
                    VALUE string( it_parameter[ name = 'ReqId' ]-value OPTIONAL ) ).
    DATA(lv_comment) = VALUE string( it_parameter[ name = 'Comment' ]-value OPTIONAL ).
    TRY.
        DATA(ls_req) = SWITCH zleave_req( iv_action_name
          WHEN 'Approve' THEN service( )->approve( iv_id = lv_id iv_comment = lv_comment )
          WHEN 'Reject'  THEN service( )->reject(  iv_id = lv_id iv_comment = lv_comment ) ).
        DATA(ls_entity) = CORRESPONDING zcl_zleave_mpc=>ts_leaverequest( ls_req ).
        copy_data_to_ref( EXPORTING is_data = ls_entity CHANGING cr_data = er_data ).
      CATCH zcx_leave_error INTO DATA(lx).
        to_gw_error( lx ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
```

## Step 7 – Test script (Gateway Client / Postman)

```text
GET  /sap/opu/odata/sap/ZLEAVE_SRV/$metadata
POST /sap/opu/odata/sap/ZLEAVE_SRV/LeaveRequestSet
     {"Pernr":"00000100","LeaveType":"ANNUAL","Begda":"\/Date(1793404800000)\/",
      "Endda":"\/Date(1793750400000)\/","Reason":"Family trip"}
GET  /sap/opu/odata/sap/ZLEAVE_SRV/LeaveRequestSet?$filter=Status eq 'N'&$top=10&$inlinecount=allpages
POST /sap/opu/odata/sap/ZLEAVE_SRV/Approve?ReqId='0000000001'&Comment='OK'
GET  /sap/opu/odata/sap/ZLEAVE_SRV/EmployeeSet('00000100')?$expand=ToRequests
POST /sap/opu/odata/sap/ZLEAVE_SRV/AttachmentSet   (binary body, header slug: sick_note.pdf)
GET  /sap/opu/odata/sap/ZLEAVE_SRV/AttachmentSet('0000000001')/$value
```

V2 JSON dates use the format `\/Date(<milliseconds since 1970>)\/` for `Edm.DateTime`.

## Stretch goals

- Rebuild the same BO with **RAP** (managed, draft, actions `approve`/`reject`, validations = your rule classes reused) and an OData V4 UI binding – compare the amount of code.
- Add a Fiori elements List Report on top of the RAP service using CDS UI annotations.
- Add an ATC check run and reach > 80 % unit test coverage on `ZCL_LEAVE_SERVICE`.

# 27. Exercise Bank (extra practice)

Use these to keep practising after the labs. Each one should take 30–90 minutes.

## ABAP Objects

1. **Library system** – classes Book, Member, Library; members can borrow max 3 books; raise `ZCX_LIBRARY` for violations; event `book_returned` notifies a waiting list.
2. **Shape area calculator** – abstract Shape; Circle, Rectangle, Triangle; sort a table of shapes by area. (Hint: `SORT ... BY table_line->attr` works only with public attributes, not methods – build a helper table of area + reference and sort that.)
3. **Generic table exporter** – a class that receives `ANY TABLE`, uses RTTI to build a CSV header and lines, returns a string table.
4. **Plug-in architecture** – read handler class names from table `ZHANDLERS` and instantiate them dynamically through an interface.
5. **Refactor a legacy report** – take an old report with FORMs and global data and rewrite it into model/view/controller classes with unit tests for the model.
6. **Application log wrapper** – singleton `ZCL_LOG` around `BAL_LOG_CREATE`, `BAL_LOG_MSG_ADD`, `BAL_DB_SAVE`, method `add_exception( ix )` that walks the `previous` chain.

## OData

7. **Material master read service** – MARA/MAKT with language-dependent description, `$filter` on material type, search by description.
8. **Customer with addresses** – 1:n navigation, `$expand` optimised with GET_EXPANDED_ENTITYSET.
9. **Purchase requisition creation** – deep insert calling `BAPI_PR_CREATE`, messages from BAPI RETURN in the message container.
10. **Invoice PDF download** – media entity that returns a SmartForm/Adobe form converted to PDF in GET_STREAM.
11. **Batch update** – update 20 items in one `$batch` changeset with defer mode, single COMMIT in CHANGESET_END.
12. **RAP inventory app** – managed BO with draft, validation of stock quantity, action `reserve`, determination for total value, Fiori preview.

# 28. Cheat Sheets

## ABAP Objects syntax

| Need | Syntax |
|---|---|
| Define class | `CLASS lcl_x DEFINITION [FINAL] [ABSTRACT] [CREATE PRIVATE] [INHERITING FROM lcl_super] [FRIENDS lcl_f].` |
| Sections | `PUBLIC SECTION. PROTECTED SECTION. PRIVATE SECTION.` |
| Attributes | `DATA`, `CLASS-DATA`, `CONSTANTS`, `... READ-ONLY` |
| Methods | `METHODS m IMPORTING .. EXPORTING .. CHANGING .. RETURNING VALUE(r) .. RAISING cx_..` |
| Static method | `CLASS-METHODS m ...` → call `lcl_x=>m( )` |
| Constructors | `METHODS constructor IMPORTING ...` / `CLASS-METHODS class_constructor.` |
| Create object | `DATA(lo) = NEW lcl_x( p = 1 ).` / `CREATE OBJECT lo TYPE (lv_name).` |
| Inherit/redefine | `INHERITING FROM`, `METHODS m REDEFINITION.`, `super->m( )` |
| Abstract | `CLASS ... ABSTRACT`, `METHODS m ABSTRACT` |
| Interface | `INTERFACE lif. METHODS m. ENDINTERFACE.` / `INTERFACES lif.` / `METHOD lif~m.` / `ALIASES m FOR lif~m.` |
| Casting | up: `lo_super = lo_sub.` down: `lo_sub ?= lo_super.` / `CAST lcl_sub( lo )` / `IS INSTANCE OF` / `CASE TYPE OF` |
| Events | `EVENTS e EXPORTING VALUE(p) TYPE t.` → `RAISE EVENT e EXPORTING p = v.` → `METHODS h FOR EVENT e OF lcl IMPORTING p sender.` → `SET HANDLER lo->h FOR lo_pub.` |
| Exceptions | `TRY. ... CATCH cx_a cx_b INTO DATA(lx). ... CLEANUP. ... ENDTRY.` / `RAISE EXCEPTION TYPE zcx EXPORTING ...` / `RAISE EXCEPTION NEW zcx( )` |
| Unit test | `CLASS ltc DEFINITION FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.` / `METHODS t FOR TESTING.` / `cl_abap_unit_assert=>assert_equals( act = .. exp = .. )` |
| RTTI | `cl_abap_typedescr=>describe_by_data( x )`, `cl_abap_classdescr=>get_class_name( lo )` |

## OData / Gateway quick reference

| Need | Where / how |
|---|---|
| Create service | SEGW → project → import DDIC/RFC/CDS → Generate |
| Register | `/IWFND/MAINT_SERVICE` → Add Service (alias LOCAL) |
| Test | `/IWFND/GW_CLIENT`, Postman (`X-CSRF-Token: Fetch`) |
| Read keys | `io_tech_request_context->get_converted_keys( IMPORTING es_key_values = ls )` |
| Read body | `io_data_provider->read_entry_data( IMPORTING es_data = ls )` |
| Filter | `get_osql_where_clause_convert( )` / `get_filter( )->get_filter_select_options( )` |
| Paging | `get_top( )`, `get_skip( )`, `UP TO n ROWS OFFSET m` |
| Count | `has_inlinecount( )` → `es_response_context-inlinecount` |
| Navigation source | `get_source_entity_type_name( )`, `get_converted_source_keys( )` |
| Expand | Redefine `GET_EXPANDED_ENTITYSET`, fill `et_expanded_tech_clauses` |
| Deep insert | Redefine `CREATE_DEEP_ENTITY` |
| Function import | Redefine `EXECUTE_ACTION` (`iv_action_name`, `it_parameter`) |
| Media | `GET_STREAM` / `CREATE_STREAM`, `$value`, header `slug` |
| Batch | `CHANGESET_BEGIN` / `CHANGESET_PROCESS` / `CHANGESET_END` |
| Errors | `/IWBEP/CX_MGW_BUSI_EXCEPTION` + `mo_context->get_message_container( )` |
| Logs | `/IWFND/ERROR_LOG`, `/IWBEP/ERROR_LOG`, `ST22`, `/IWFND/TRACES`, `sap-statistics=true` |
| Cache | `/IWFND/CACHE_CLEANUP`, `/IWBEP/CACHE_CLEANUP` |

## RAP quick reference

| Artifact | Keyword |
|---|---|
| Root entity | `define root view entity ZI_X as select from ztab` |
| Child entity | `composition [0..*] of ZI_Child as _Child` / `association to parent ZI_X as _Parent on ...` |
| BDEF | `managed implementation in class zbp_i_x unique; strict ( 2 ); define behavior for ZI_X alias X persistent table ztab lock master authorization master ( instance ) etag master LocalLastChangedAt { create; update; delete; ... }` |
| Numbering | `field ( numbering : managed, readonly ) Uuid;` |
| Action | `action approve result [1] $self;` |
| Determination | `determination setDefaults on modify { create; }` |
| Validation | `validation checkDates on save { create; field BeginDate, EndDate; }` |
| Draft | `with draft;` + `draft table ztab_d` |
| Projection | `define root view entity ZC_X provider contract transactional_query as projection on ZI_X` |
| Service | `define service ZUI_X { expose ZC_X as X; }` |
| Binding | Service Binding → OData V4 – UI / Web API → Publish → Preview |
| EML | `READ ENTITIES OF`, `MODIFY ENTITIES OF`, `COMMIT ENTITIES`, `IN LOCAL MODE`, `%tky`, `%cid`, `failed`, `reported`, `mapped` |

## Final interview checklist

- I can write a class with constructor, static & instance members from memory.
- I can explain inheritance vs. interface with a real example, and up-cast vs. down-cast.
- I can describe events with the 4 steps and name where SAP uses them (ALV).
- I can create an exception class with T100 texts and explain the 3 categories.
- I can name and sketch 5 design patterns in ABAP.
- I can write a unit test with a test double.
- I can create a SEGW service with CRUD, filter, paging, navigation, expand, deep insert and function import.
- I know the Gateway transactions and how to debug/analyse errors and performance.
- I can explain CDS-based OData and the RAP layers, managed vs. unmanaged, EML basics.
- I can explain V2 vs. V4, CSRF, ETag, $batch.
