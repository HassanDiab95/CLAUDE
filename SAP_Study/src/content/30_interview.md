@part Part III — Interview Questions | ABAP Objects and OData questions with model answers, / grouped Beginner → Intermediate → Advanced, plus scenario questions

# 24. ABAP Objects – Interview Questions

:::tip How to answer
Give a one-line definition, then a concrete example from SAP or from your own project, then (if relevant) a pitfall. Interviewers care more about *why* and *when* than about memorised definitions.
:::

## Beginner

Q: 1. What is the difference between a class and an object?
A: A class is the blueprint (definition of attributes and methods); an object is a runtime instance of that class, created with `NEW` or `CREATE OBJECT`, living in memory and accessed through a reference variable. One class can have many objects, each with its own instance attribute values.

Q: 2. What are the visibility sections in ABAP classes?
A: PUBLIC (accessible everywhere), PROTECTED (class + subclasses), PRIVATE (only the class and its friends). They must be declared in this order. Interfaces' components are always public.

Q: 3. What is the difference between instance and static components?
A: Instance components (`DATA`, `METHODS`, `EVENTS`) exist once per object and are accessed with `->`. Static components (`CLASS-DATA`, `CLASS-METHODS`, `CLASS-EVENTS`) exist once per class per internal session, are shared by all objects and accessed with `=>`. Static methods cannot access instance attributes or `me`.

Q: 4. What is a constructor? How many types exist?
A: A special method executed automatically on creation. The instance constructor `constructor` runs once per object (only IMPORTING parameters and exceptions). The static constructor `class_constructor` runs once per class per internal session before the first access, has no parameters.

Q: 5. What is `me`?
A: The self-reference inside instance methods – points to the current object. Used to resolve name conflicts (`me->mv_name = mv_name`) or to pass the current object to another method (`lo_x->register( me )`).

Q: 6. What is the difference between local and global classes?
A: Global classes are stored in the class library (SE24/ADT) and usable system-wide; local classes are defined inside a program/include and visible only there. Local classes are often used for helpers and for unit tests (test classes are always local).

Q: 7. What are the parameter types of a method?
A: IMPORTING, EXPORTING, CHANGING, RETURNING (one, always by value – makes a functional method), and RAISING for class-based exceptions (or EXCEPTIONS for classic ones).

Q: 8. What is a functional method?
A: A method with a RETURNING parameter. It can be used directly in expressions and operand positions: `IF lo_order->is_released( ) = abap_true.` or `lv_total = lo_calc->sum( ) * 2.`

Q: 9. What is the difference between `NEW` and `CREATE OBJECT`?
A: Both create an object. `NEW` (7.40+) is a constructor expression that returns the reference, allows inline declaration and chaining (`NEW zcl_x( )->run( )`). `CREATE OBJECT` is the older statement; it is still the way to create objects of a class whose name is only known at runtime: `CREATE OBJECT lo TYPE (lv_class)`.

Q: 10. What happens if you call a method on an initial reference?
A: Runtime error `OBJECTS_OBJREF_NOT_ASSIGNED` (exception `CX_SY_REF_IS_INITIAL`). Always check `IS BOUND` when a reference might not be set.

Q: 11. What is encapsulation? Give an example.
A: Hiding internal state and allowing changes only through methods that enforce rules. Example: a `ZCL_BANK_ACCOUNT` has a private balance and a `withdraw` method that refuses to go below zero; nobody can set the balance directly.

Q: 12. What does READ-ONLY mean for an attribute?
A: A public attribute declared READ-ONLY can be read from outside but only changed inside the class (and its subclasses for protected). It avoids writing a getter for simple values.

## Intermediate

Q: 13. What is inheritance and which kind does ABAP support?
A: A subclass takes over all components of its superclass and can add new ones or redefine instance methods. ABAP supports single inheritance only (one direct superclass); multiple contracts are realised with interfaces. All classes ultimately inherit from `OBJECT`.

Q: 14. What can and cannot be redefined?
A: Public and protected **instance** methods can be redefined (signature unchanged). You cannot redefine static methods, constructors (a subclass defines its own), private methods, or FINAL methods. Attributes cannot be redefined.

Q: 15. Why must the subclass constructor call `super->constructor( )`?
A: To initialise the superclass part of the object. If the superclass has an explicit instance constructor, the compiler forces the call before instance components are accessed in the subclass constructor.

Q: 16. What is the difference between an abstract class and an interface?
A: An abstract class can contain implemented methods, state (attributes), constructors and visibility sections; a class can inherit from only one. An interface only declares a public contract (no implementation, apart from DEFAULT IGNORE/FAIL), and a class can implement many. Use an abstract class for an "is-a" family with shared code, an interface for a capability/contract and loose coupling.

Q: 17. What is polymorphism? Give an ABAP example.
A: The same call executes different implementations depending on the object's dynamic type. Example: a table of `REF TO zif_payment` containing cash, card and wallet objects; looping and calling `pay( )` runs each class's own logic without any CASE on type.

Q: 18. Explain up-cast and down-cast.
A: Up-cast (narrowing cast) assigns a subclass/implementing-class reference to a superclass/interface reference – implicit with `=`, always safe. Down-cast (widening cast) assigns a general reference to a more specific one – requires `?=` or `CAST`, checked at runtime, raises `CX_SY_MOVE_CAST_ERROR` if the object is not compatible. Use `IS INSTANCE OF` or `CASE TYPE OF` to check first.

Q: 19. What are static type and dynamic type of a reference?
A: The static type is the declared type (`TYPE REF TO zcl_shape`), fixed at compile time and defines which components you can address. The dynamic type is the class of the object it currently points to; it determines which implementation runs (dynamic binding).

Q: 20. What is an alias in an interface context?
A: `ALIASES name FOR intf~method` gives an interface component a short name in the implementing class, so callers can write `lo->print( )` instead of `lo->zif_printable~print( )`. Also used when composing interfaces.

Q: 21. Explain events in ABAP Objects – the four steps.
A: Declare (`EVENTS`/`CLASS-EVENTS` with EXPORTING parameters), raise (`RAISE EVENT`), define a handler method (`FOR EVENT evt OF class IMPORTING ... sender`), register at runtime (`SET HANDLER h FOR obj` / `FOR ALL INSTANCES`; static events without FOR). Handlers run synchronously; without registered handlers nothing happens.

Q: 22. What is the implicit `sender` parameter?
A: Every instance event automatically passes a reference to the object that raised it. The handler can import `sender` to know which object triggered the event (e.g. which ALV grid was double-clicked).

Q: 23. What are the three exception class categories?
A: `CX_STATIC_CHECK` (must be handled or declared; checked by compiler – expected business errors), `CX_DYNAMIC_CHECK` (checked only at runtime; caller can prevent them – e.g. `CX_SY_ZERODIVIDE`), `CX_NO_CHECK` (can occur anywhere, not declared – e.g. resource shortages). All inherit from `CX_ROOT`.

Q: 24. What is the purpose of CLEANUP?
A: The CLEANUP block runs when an exception raised in the TRY block is **not** caught by this TRY but propagates to an outer handler. It is used to restore a consistent state (release locks, close files) before leaving the context.

Q: 25. What is the difference between RETRY and RESUME?
A: RETRY (in CATCH) re-executes the whole TRY block – after fixing the cause. RESUME continues processing right after the point where a **resumable** exception was raised (`RAISE RESUMABLE EXCEPTION`, method declared with `RAISING RESUMABLE(...)`, handled with `CATCH BEFORE UNWIND`).

Q: 26. How do you attach a message class text to an exception class?
A: Implement `IF_T100_MESSAGE` (or `IF_T100_DYN_MSG`), define text-ID constants with msgid/msgno and attribute names for placeholders `&1..&4`, and raise with `RAISE EXCEPTION TYPE zcx_x EXPORTING textid = zcx_x=>not_found attr = value` (or `RAISE EXCEPTION TYPE zcx_x MESSAGE e001(zsd) WITH lv_vbeln` with IF_T100_DYN_MSG).

Q: 27. What is a friend class?
A: A class granted access to the protected and private components of another class via `FRIENDS`. Friendship is one-way. Typical use: test classes (`FRIENDS ltc_test`) or a factory creating instances of a CREATE PRIVATE class.

Q: 28. What do CREATE PUBLIC / PROTECTED / PRIVATE control?
A: Who may instantiate the class: anyone / the class and subclasses / only the class itself (and friends). CREATE PRIVATE is used for Singleton and for forcing creation through a factory method.

## Advanced

Q: 29. Implement a Singleton in ABAP. What is its scope?
A: `CLASS ... CREATE PRIVATE`, a private static attribute `go_instance`, and a static `get_instance( )` that creates the object on first call (`IF go_instance IS NOT BOUND`). Its scope is one internal session – not shared across users or programs (use shared memory for that).

Q: 30. Which design patterns have you used in ABAP?
A: Example answer: *Factory* to create the right document handler per document type read from a customizing table (dynamic `CREATE OBJECT TYPE (lv_class)`); *Strategy* for country-specific tax calculation; *Singleton* for an application log wrapper; *Observer* via events for status changes; *Facade* class wrapping BAPI calls + commit; *MVC* in reports (model/view/controller classes); *Decorator* for adding logging/caching around a repository interface.

Q: 31. How do you write unit tests in ABAP?
A: Local test classes `FOR TESTING` with `RISK LEVEL` and `DURATION`, fixture methods (`class_setup`, `setup`, `teardown`, `class_teardown`), test methods `FOR TESTING`, assertions from `CL_ABAP_UNIT_ASSERT`. Run with Ctrl+Shift+F10, check coverage. Isolate dependencies with interfaces + test doubles (manual or `CL_ABAP_TESTDOUBLE`), `CL_OSQL_TEST_ENVIRONMENT`/`CL_CDS_TEST_ENVIRONMENT` for DB, and test seams for legacy code.

Q: 32. What is dependency injection and why is it important in ABAP?
A: Passing collaborators (e.g. a repository or notifier as `REF TO zif_*`) into an object from outside (constructor/setter/parameter) instead of creating them inside. It decouples classes and makes unit tests possible by injecting test doubles.

Q: 33. What are test seams?
A: `TEST-SEAM name ... END-TEST-SEAM` marks code in production code that can be replaced in unit tests by `TEST-INJECTION name ... END-TEST-INJECTION` in a test class. A last resort for legacy code that cannot be refactored to use DI.

Q: 34. What is RTTS? Where have you used it?
A: Run Time Type Services: RTTI (describe types at runtime: `CL_ABAP_TYPEDESCR=>describe_by_data/name`, `CL_ABAP_STRUCTDESCR`, `CL_ABAP_CLASSDESCR`) and RTTC (create types at runtime: `CL_ABAP_TABLEDESCR=>create` + `CREATE DATA ... TYPE HANDLE`). Used for generic uploads/downloads, dynamic ALV, generic table display, field catalog building.

Q: 35. How do you call a method dynamically?
A: `CALL METHOD lo_obj->(lv_method_name) EXPORTING ...` or with `PARAMETER-TABLE` (`ABAP_PARMBIND_TAB`) and `EXCEPTION-TABLE`. Static: `CALL METHOD (lv_class)=>(lv_method)`. Errors raise `CX_SY_DYN_CALL_*` exceptions.

Q: 36. What is a BAdI and how is it related to OO?
A: A Business Add-In is an OO enhancement: SAP defines an interface and calls implementations at defined points. Classic BAdIs (SE18/SE19, `CL_EXITHANDLER`), new kernel BAdIs inside enhancement spots (`GET BADI`/`CALL BADI`, filters, fallback class). Your implementation is a class implementing the BAdI interface.

Q: 37. What is the difference between `CX_STATIC_CHECK` and `CX_DYNAMIC_CHECK` in terms of design?
A: Use static check for errors the caller must consciously handle (business conditions); use dynamic check when the caller can avoid the error by checking preconditions (invalid argument) – forcing every caller to handle it would clutter code.

Q: 38. Explain SOLID in an ABAP context.
A: Single responsibility (repository vs. calculator vs. view class), Open/closed (add new strategy classes instead of editing CASE), Liskov (subclasses fully usable as superclass), Interface segregation (small focused interfaces), Dependency inversion (depend on interfaces, inject implementations).

Q: 39. Why are static methods considered harmful for business logic?
A: They cannot be redefined or replaced by test doubles (no polymorphism), so code calling them is hard to test and extend. Use instances + interfaces; static methods are fine for factories and pure utilities.

Q: 40. What happens with a superclass constructor that calls a redefined method?
A: During the superclass constructor the object is not yet a complete subclass instance, so the **superclass** implementation is executed, not the redefinition. A common source of bugs.

Q: 41. How does garbage collection work in ABAP?
A: Objects that are no longer referenced by any reference variable (including event handler registrations and internal tables) are deleted by the garbage collector automatically. `CLEAR`/`FREE` of the last reference makes an object eligible. Weak references (`CL_ABAP_WEAK_REFERENCE`) don't keep objects alive.

Q: 42. What is AMDP?
A: ABAP Managed Database Procedures – methods of a class implementing `IF_AMDP_MARKER_HDB`, declared `BY DATABASE PROCEDURE FOR HDB LANGUAGE SQLSCRIPT USING <tables>`, executed on HANA. Used for complex calculations close to the data (code pushdown); also as implementation of CDS table functions.

Q: 43. What is the difference between `?=` and `CAST`?
A: Same down-cast semantics. `?=` is a statement; `CAST type( ref )` is a constructor expression usable inline (e.g. `CAST zcl_wallet( lo_pay )->get_cashback( )`), and `CAST #( )` infers the type from the target.

Q: 44. Can an interface have attributes and events? Can it be instantiated?
A: Yes, interfaces can declare constants, attributes (discouraged), types, events and methods. They cannot be instantiated, but reference variables `TYPE REF TO zif_x` can point to any implementing object.

Q: 45. How do you persist objects?
A: Usually via a repository/DAO class with Open SQL, or in modern development with RAP business objects. Classic Object Services (persistent classes with `CA_`/`CB_` agents) exist but are rarely used today.

# 25. OData & SAP Gateway – Interview Questions

## Beginner

Q: 1. What is OData?
A: An OASIS standard REST-based protocol for querying and updating data over HTTP, using URIs for resources, HTTP methods for CRUD, a metadata document describing the model, and JSON/XML payloads. SAP uses it as the main interface for Fiori/UI5 and APIs.

Q: 2. What is SAP Gateway?
A: The ABAP platform component (SAP_GWFND) that exposes OData services: tools (SEGW), runtime (hub/frontend IWFND and backend IWBEP), registry, logs and caching.

Q: 3. What are entity type, entity set, property, association and navigation property?
A: Entity type = structure with key (like a table definition); entity set = collection of entities addressed in the URL; property = field; association = relationship with cardinality between two entity types; navigation property = named path to follow an association (`/OrderSet('1')/ToItems`).

Q: 4. Which HTTP methods map to which DPC methods?
A: GET collection → GET_ENTITYSET, GET single → GET_ENTITY, POST → CREATE_ENTITY (or CREATE_DEEP_ENTITY), PUT/PATCH/MERGE → UPDATE_ENTITY (PATCH_ENTITY), DELETE → DELETE_ENTITY. Function imports → EXECUTE_ACTION; media → GET_STREAM/CREATE_STREAM/UPDATE_STREAM.

Q: 5. Which classes does SEGW generate and which ones do you change?
A: MPC + MPC_EXT (model provider), DPC + DPC_EXT (data provider), plus the technical model and service. You change only the `_EXT` classes; base classes are regenerated and overwritten.

Q: 6. How do you register and test a service?
A: `/IWFND/MAINT_SERVICE` → Add Service → system alias (LOCAL for embedded) → select technical service → package. Test with SAP Gateway Client (`/IWFND/GW_CLIENT`) – first `$metadata`, then the entity sets.

Q: 7. What is `$metadata`?
A: The service metadata document (CSDL/EDMX XML) that describes entity types, sets, properties with types and facets, associations, function imports and annotations. Clients like UI5 build their model from it.

Q: 8. What is the service document?
A: The root URL of the service (`.../ZSALES_SRV/`), listing all entity sets (collections) available.

Q: 9. Name the main system query options.
A: `$filter`, `$orderby`, `$top`, `$skip`, `$select`, `$expand`, `$format`, `$inlinecount` (V2) / `$count` (V4), `/$count`, `$skiptoken`, `search`/`$search`.

Q: 10. What are the main transactions for Gateway?
A: SEGW, /IWFND/MAINT_SERVICE, /IWFND/GW_CLIENT, /IWFND/ERROR_LOG, /IWBEP/ERROR_LOG, /IWFND/TRACES, /IWFND/CACHE_CLEANUP, /IWBEP/CACHE_CLEANUP, SICF, /IWFND/V4_ADMIN.

## Intermediate

Q: 11. Hub vs. embedded deployment?
A: Embedded: Gateway and backend in one system (standard for S/4HANA, no RFC). Hub: separate frontend server with UI5/FLP and Gateway hub connected via trusted RFC to backends; system alias routes the service. Hub allows one UI layer for multiple backends and separate upgrade cycles.

Q: 12. How do you implement $filter in GET_ENTITYSET?
A: Use `io_tech_request_context->get_filter( )->get_filter_select_options( )` to build ranges for the SELECT, or `get_osql_where_clause_convert( )` for a dynamic WHERE using ABAP names. For non-convertible filters read `iv_filter_string`. With CDS/RDS or RAP, SADL does it automatically.

Q: 13. How do you implement paging and why push it to the DB?
A: Read `is_paging-top/skip` or `get_top( )/get_skip( )` and use `UP TO n ROWS OFFSET m` with `ORDER BY` in the SELECT. Doing it in ABAP (`/iwbep/cl_mgw_data_util=>paging`) still reads all rows from the DB – slow and memory heavy for big tables.

Q: 14. What is the difference between `$expand` and navigation?
A: Navigation (`/OrderSet('1')/ToItems`) returns only the related entities. `$expand=ToItems` returns the main entity **plus** the related ones inline in one response, avoiding a second round trip.

Q: 15. How does the framework handle $expand and how do you optimise it?
A: By default it calls GET_ENTITYSET for the parent and then the child entity set method once per parent row (N+1 calls). Optimise by redefining GET_EXPANDED_ENTITYSET / GET_EXPANDED_ENTITY, reading children in one SELECT (`FOR ALL ENTRIES` or join), building a deep structure whose child component is named like the navigation property, and filling `et_expanded_tech_clauses`.

Q: 16. What is deep insert?
A: Creating a parent and its children in one POST with nested JSON (`"ToItems":[...]`). Implemented in CREATE_DEEP_ENTITY by reading the payload into a deep structure with `io_data_provider->read_entry_data`.

Q: 17. What is $batch and what is a changeset?
A: `$batch` bundles multiple requests into one HTTP POST (multipart). A changeset groups modifying requests that must succeed or fail together (one LUW). Implement CHANGESET_BEGIN (allow multiple ops, defer mode), CHANGESET_PROCESS (process together) and CHANGESET_END (commit). Don't COMMIT inside individual CRUD methods when in a changeset.

Q: 18. What is a function import? GET or POST?
A: A custom operation outside CRUD (e.g. ReleaseOrder, CalculatePrice) defined in SEGW with parameters and return type (entity, complex type or none). Implemented in EXECUTE_ACTION. Use GET for read-only, POST for operations with side effects. In V4 they are split into functions (read-only) and actions (modifying).

Q: 19. How do you return error messages to the UI?
A: Raise `/IWBEP/CX_MGW_BUSI_EXCEPTION` (HTTP 400, or set `http_status_code`) with a message or a message container filled via `mo_context->get_message_container( )` (`add_message`, `add_message_text_only`, `add_messages_from_bapi`). Technical errors: `/IWBEP/CX_MGW_TECH_EXCEPTION` (500). Warnings with success go in the `sap-message` header.

Q: 20. What is the CSRF token and why is it needed?
A: A token protecting against Cross-Site Request Forgery. The client fetches it with `X-CSRF-Token: Fetch` on a GET and sends it in modifying requests (POST/PUT/PATCH/DELETE). Missing/invalid token → 403. UI5 does it automatically.

Q: 21. What is an ETag?
A: A version identifier (e.g. last-changed timestamp) used for optimistic locking. The client sends it in `If-Match`; if it differs from the current value, the server returns 412 Precondition Failed, preventing lost updates. Defined per entity type in SEGW (property as ETag) or `etag master` in RAP.

Q: 22. How do you handle media/file upload and download?
A: Mark the entity type as media, set the content-type property in MPC_EXT, implement CREATE_STREAM (upload; file name from `slug` header) and GET_STREAM (download via `/$value`), returning `ty_s_media_resource` with value (XSTRING) and mime_type.

Q: 23. What is the difference between PUT and PATCH/MERGE?
A: PUT replaces the whole entity (missing fields may be initialised); PATCH (V2 also MERGE) updates only the sent fields. Gateway's default PATCH implementation reads the entity via GET_ENTITY, merges and calls UPDATE_ENTITY.

Q: 24. What is `io_tech_request_context` and why use it?
A: The request context object passed to DPC methods. It provides keys, filter, select, paging, navigation and expand information with **technical ABAP names** (independent of the external OData property names), e.g. `get_converted_keys`, `get_filter`, `get_top`, `get_expand`, `get_source_entity_type_name`.

Q: 25. How do you read the keys in GET_ENTITY?
A: `io_tech_request_context->get_converted_keys( IMPORTING es_key_values = ls_key )` where `ls_key` is the entity structure; or loop `it_key_tab` (name/value pairs, external names). For navigation use `get_converted_source_keys`.

## Advanced

Q: 26. How do you expose a CDS view as OData? Compare the options.
A: (1) `@OData.publish: true` – quick, read-only unless BOPF is used; (2) SEGW Reference Data Source – SADL handles reads, custom write logic in DPC_EXT; (3) RAP service definition + binding – modern, full transactional support, V2/V4. Prefer RAP for new development on S/4HANA ≥ 1909 or BTP.

Q: 27. What is SADL?
A: Service Adaptation Definition Language – the framework that maps OData requests on CDS-based entities into optimised SQL (filter, sort, paging, count, search, expand) and handles authorizations from DCL. It is the engine behind RDS, @OData.publish and RAP queries.

Q: 28. Explain the RAP architecture.
A: Data model with CDS view entities (root + compositions) → behavior definition (operations, numbering, validations, determinations, actions, locking, ETag, draft) → behavior pool class (handler and saver classes, EML) → projection layer (views + projection BDEF) → service definition → service binding (OData V2/V4, UI/Web API).

Q: 29. Managed vs. unmanaged RAP?
A: Managed: framework provides CRUD, transactional buffer, locking and saving – you add business logic. Unmanaged: you implement create/update/delete/read/lock and the save sequence yourself – used to wrap existing legacy code/BAPIs. Hybrid: managed with unmanaged/additional save.

Q: 30. What are determinations and validations in RAP?
A: Determinations compute/derive values when trigger conditions occur (`on modify` or `on save`, triggered by create/field changes). Validations check data consistency `on save` and reject invalid instances by filling `failed` and `reported`.

Q: 31. What is EML?
A: Entity Manipulation Language – ABAP statements to access RAP BOs: `READ ENTITIES`, `MODIFY ENTITIES` (create, update, delete, execute action), `COMMIT ENTITIES`, `ROLLBACK ENTITIES`, with derived types `%tky`, `%cid`, `%param`, and response structures `failed`, `reported`, `mapped`.

Q: 32. What is draft in RAP?
A: `with draft;` enables storing in-progress changes in a draft table so users can leave and continue later, with exclusive locks per draft and the actions Edit/Activate/Discard/Resume/Prepare handled by the framework. Typical for Fiori elements object pages.

Q: 33. Differences between OData V2 and V4?
A: V4 has leaner JSON, `$count=true`, standard `$search`, nested expand options, actions vs. functions, better batch/delta, and is used by RAP V4 bindings and Fiori elements V4. V2 is still most common with SEGW and existing Fiori apps.

Q: 34. How do you consume an external OData service from ABAP?
A: Via HTTP client (`CL_HTTP_CLIENT` with SM59 destination + JSON parsing with `/UI2/CL_JSON` or `XCO`), or the typed OData client proxy (`/IWBEP/CL_CP_FACTORY_REMOTE`, Service Consumption Model in ADT; `CL_WEB_ODATA_CLIENT_FACTORY` on BTP).

Q: 35. How do you secure an OData service?
A: Role with `S_SERVICE` (service authorization), business authority checks in DPC or DCL access control on CDS, CSRF protection, HTTPS/SSO, input validation (no SQL injection in dynamic WHERE), expose only needed fields, limit page sizes.

Q: 36. How do you analyse a slow OData service?
A: `sap-statistics=true` to split framework/application/DB time, `/IWFND/TRACES` (performance trace), ST05 SQL trace and SAT on the backend, check for N+1 `$expand`, missing DB paging, SELECT *, missing indexes; use CDS/SADL push-down.

Q: 37. Where do you see Gateway errors?
A: `/IWFND/ERROR_LOG` (hub) and `/IWBEP/ERROR_LOG` (backend) with error context, call stack and replay; `ST22` for dumps; browser network tab; UI5 message popover.

Q: 38. What is soft state?
A: A mode where the backend session (and its ABAP memory/buffers) is kept alive between requests for a configurable timeout, enabled per service and by implementing `/IWBEP/IF_MGW_SOST_SRV_RUNTIME`. Improves performance for expensive initialisations, but costs memory.

Q: 39. How do you add annotations to a SEGW service?
A: In MPC_EXT->DEFINE via `create_annotation` on entity/property (SAP annotations like `sap:label`, `sap:filterable`), or with an annotation model (vocabulary-based) in SEGW, or – for CDS-based services – via CDS annotations / metadata extensions. Clear the metadata cache afterwards.

Q: 40. What is a system alias?
A: A configuration on the hub (`/IWFND/MAINT_SERVICE` + SPRO) that maps a service to a backend RFC destination. `LOCAL` is used in embedded deployment.

## Scenario questions (senior level)

Q: S1. A Fiori list takes 15 s to load. How do you approach it?
A: Reproduce with `sap-statistics=true` → see whether time is in app or DB. Check `/IWFND/TRACES` for number of calls (e.g. $expand N+1). In the backend use ST05/SAT on the GET_ENTITYSET: missing WHERE push-down, SELECT *, paging in ABAP, FOR ALL ENTRIES with empty table, missing index. Fix by pushing filter/paging to DB, implementing GET_EXPANDED_ENTITYSET, or moving the read to a CDS view with SADL. Add a maximum page size.

Q: S2. The UI must create an order with 50 items atomically. Design it.
A: Deep insert (CREATE_DEEP_ENTITY) with header + items, one BAPI call, error messages via message container from BAPI RETURN, rollback on error and commit on success; alternatively $batch with one changeset in defer mode processed in CHANGESET_PROCESS. In RAP: composition root/child, `create by \_Items`, one MODIFY ENTITIES with `%cid` references.

Q: S3. Two users edit the same record. How do you avoid lost updates?
A: ETag (last changed timestamp) on the entity; UI sends If-Match, backend returns 412 if outdated. Plus pessimistic locks (ENQUEUE) during the actual update. RAP: `etag master` + `lock master` (or draft with exclusive locks).

Q: S4. You need a new API for an external system to read customer credit data. SEGW or RAP?
A: On S/4HANA 1909+ or BTP: RAP with a CDS-based read-only BO (or custom entity if data comes from logic) exposed as OData V4 Web API, with DCL authorizations. First check the SAP Business Accelerator Hub for a released standard API (Clean Core). SEGW only on older ECC/NetWeaver releases.

Q: S5. How do you design OO code behind a Gateway service?
A: Keep DPC_EXT thin: map OData ↔ ABAP and translate exceptions. Put business logic into separate classes (service/API class, repository for DB access, validator) behind interfaces – reusable from reports, RFC and RAP, and unit-testable with test doubles.
