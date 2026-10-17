# 10. Design Patterns in ABAP

Design patterns are proven solutions to recurring design problems. Interviewers for mid/senior roles almost always ask "Which patterns have you used in ABAP?" – know at least Singleton, Factory, Strategy, Observer, Decorator, MVC and Facade, with an example from SAP.

## Singleton – exactly one instance

Use for: a central logger, an application buffer, a configuration reader.

```abap
CLASS lcl_logger DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    CLASS-METHODS get_instance RETURNING VALUE(ro) TYPE REF TO lcl_logger.
    METHODS add  IMPORTING iv_msg TYPE string.
    METHODS show.
  PRIVATE SECTION.
    CLASS-DATA go_instance TYPE REF TO lcl_logger.
    DATA mt_log TYPE string_table.
ENDCLASS.

CLASS lcl_logger IMPLEMENTATION.
  METHOD get_instance.
    IF go_instance IS NOT BOUND.          " lazy creation
      go_instance = NEW #( ).
    ENDIF.
    ro = go_instance.
  ENDMETHOD.
  METHOD add.
    APPEND |{ sy-uzeit TIME = ISO } { iv_msg }| TO mt_log.
  ENDMETHOD.
  METHOD show.
    LOOP AT mt_log INTO DATA(lv_line).
      WRITE / lv_line.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  lcl_logger=>get_instance( )->add( 'Program started' ).
  lcl_logger=>get_instance( )->add( 'Data selected' ).   " same object
  lcl_logger=>get_instance( )->show( ).
```

:::note Singleton scope in ABAP
A singleton lives per **internal session** (one program run), not system-wide. For cross-session sharing use shared memory objects (`CL_SHM_AREA`) or the database. Real SAP example: `CL_ABAP_TSTMP`, many `*_FACTORY=>get_instance` methods, BAL application log wrappers.
:::

## Factory – centralise object creation

The caller asks for "a document handler for type X" and gets the right subclass without knowing it. Combined with `CREATE PRIVATE`/`FRIENDS`, only the factory can create objects.

```abap
INTERFACE lif_doc_handler.
  METHODS process IMPORTING iv_id TYPE string.
ENDINTERFACE.

CLASS lcl_invoice_handler DEFINITION.
  PUBLIC SECTION. INTERFACES lif_doc_handler.
ENDCLASS.
CLASS lcl_invoice_handler IMPLEMENTATION.
  METHOD lif_doc_handler~process. WRITE: / 'Posting invoice', iv_id. ENDMETHOD.
ENDCLASS.

CLASS lcl_credit_handler DEFINITION.
  PUBLIC SECTION. INTERFACES lif_doc_handler.
ENDCLASS.
CLASS lcl_credit_handler IMPLEMENTATION.
  METHOD lif_doc_handler~process. WRITE: / 'Posting credit memo', iv_id. ENDMETHOD.
ENDCLASS.

CLASS lcl_handler_factory DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS create IMPORTING iv_type   TYPE string
                         RETURNING VALUE(ro) TYPE REF TO lif_doc_handler
                         RAISING   cx_abap_invalid_value.
ENDCLASS.
CLASS lcl_handler_factory IMPLEMENTATION.
  METHOD create.
    ro = SWITCH #( iv_type
                   WHEN 'INV' THEN NEW lcl_invoice_handler( )
                   WHEN 'CRM' THEN NEW lcl_credit_handler( )
                   ELSE THROW cx_abap_invalid_value( ) ).
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  lcl_handler_factory=>create( 'INV' )->process( '9000001' ).
```

A more flexible variant reads the class name from a customizing table and uses **dynamic instantiation**: `CREATE OBJECT ro TYPE (lv_class_name).` – new document types need only a new class + a table entry (Open/Closed principle).

## Strategy – interchangeable algorithms

Define a family of algorithms behind one interface and choose at runtime (e.g. different pricing or tax calculations per country).

```abap
INTERFACE lif_tax_strategy.
  METHODS calc IMPORTING iv_net TYPE decfloat34 RETURNING VALUE(rv_tax) TYPE decfloat34.
ENDINTERFACE.

CLASS lcl_tax_eg DEFINITION.
  PUBLIC SECTION. INTERFACES lif_tax_strategy.
ENDCLASS.
CLASS lcl_tax_eg IMPLEMENTATION.
  METHOD lif_tax_strategy~calc. rv_tax = iv_net * '0.14'. ENDMETHOD.   " Egypt VAT 14 %
ENDCLASS.

CLASS lcl_tax_sa DEFINITION.
  PUBLIC SECTION. INTERFACES lif_tax_strategy.
ENDCLASS.
CLASS lcl_tax_sa IMPLEMENTATION.
  METHOD lif_tax_strategy~calc. rv_tax = iv_net * '0.15'. ENDMETHOD.   " KSA VAT 15 %
ENDCLASS.

CLASS lcl_invoice_calc DEFINITION.
  PUBLIC SECTION.
    METHODS constructor IMPORTING io_tax TYPE REF TO lif_tax_strategy.
    METHODS gross IMPORTING iv_net TYPE decfloat34 RETURNING VALUE(rv) TYPE decfloat34.
  PRIVATE SECTION.
    DATA mo_tax TYPE REF TO lif_tax_strategy.
ENDCLASS.
CLASS lcl_invoice_calc IMPLEMENTATION.
  METHOD constructor. mo_tax = io_tax. ENDMETHOD.
  METHOD gross. rv = iv_net + mo_tax->calc( iv_net ). ENDMETHOD.
ENDCLASS.
```

## Observer

Implemented natively with ABAP **events** (Chapter 8): the subject raises an event; observers register with `SET HANDLER`.

## Decorator

Wrap an object implementing an interface with another object implementing the same interface to add behaviour (logging, caching, authorization checks) – see Lab 7 (`LCL_LOGGING_STORAGE`).

## Facade

A single simple class in front of a complex subsystem: e.g. `ZCL_SALES_ORDER_API=>create( )` hides BAPI_SALESORDER_CREATEFROMDAT2, BAPI_TRANSACTION_COMMIT, message conversion and locking.

## MVC (Model–View–Controller)

Split a report into: **Model** (data selection and business logic class), **View** (SALV/ALV display class), **Controller** (reacts to user actions, coordinates). This is how SAP structures Web Dynpro and BSP, and the idea behind Fiori (UI5 view ↔ OData model).

## Persistence layer / Repository (DAO)

All database access for an entity goes through one class (`ZCL_ORDER_REPOSITORY` with `read`, `query`, `save`). Business logic never contains `SELECT` statements directly → easier testing (replace the repository with a test double) and reuse.

:::lab Lab 10 – Discount engine
Use Strategy + Factory: interface `LIF_DISCOUNT` with `apply( iv_amount ) RETURNING rv`. Implementations: `LCL_NO_DISCOUNT`, `LCL_PERCENT_DISCOUNT` (constructor takes percent), `LCL_VIP_DISCOUNT` (15 % but at most 500). A factory method `for_customer( iv_category )` returns the right strategy for categories '', 'REGULAR' (5 %) and 'VIP'. Calculate the final price of 5000 for each category.
:::

:::solution Lab 10
```abap
INTERFACE lif_discount.
  METHODS apply IMPORTING iv_amount TYPE decfloat34 RETURNING VALUE(rv) TYPE decfloat34.
ENDINTERFACE.

CLASS lcl_no_discount DEFINITION.
  PUBLIC SECTION. INTERFACES lif_discount.
ENDCLASS.
CLASS lcl_no_discount IMPLEMENTATION.
  METHOD lif_discount~apply. rv = iv_amount. ENDMETHOD.
ENDCLASS.

CLASS lcl_percent_discount DEFINITION.
  PUBLIC SECTION.
    INTERFACES lif_discount.
    METHODS constructor IMPORTING iv_percent TYPE decfloat34.
  PRIVATE SECTION.
    DATA mv_percent TYPE decfloat34.
ENDCLASS.
CLASS lcl_percent_discount IMPLEMENTATION.
  METHOD constructor. mv_percent = iv_percent. ENDMETHOD.
  METHOD lif_discount~apply. rv = iv_amount * ( 1 - mv_percent / 100 ). ENDMETHOD.
ENDCLASS.

CLASS lcl_vip_discount DEFINITION.
  PUBLIC SECTION. INTERFACES lif_discount.
ENDCLASS.
CLASS lcl_vip_discount IMPLEMENTATION.
  METHOD lif_discount~apply.
    rv = iv_amount - nmin( val1 = iv_amount * '0.15' val2 = 500 ).
  ENDMETHOD.
ENDCLASS.

CLASS lcl_discount_factory DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS for_customer IMPORTING iv_category TYPE string
                               RETURNING VALUE(ro) TYPE REF TO lif_discount.
ENDCLASS.
CLASS lcl_discount_factory IMPLEMENTATION.
  METHOD for_customer.
    ro = SWITCH #( iv_category
                   WHEN 'REGULAR' THEN NEW lcl_percent_discount( 5 )
                   WHEN 'VIP'     THEN NEW lcl_vip_discount( )
                   ELSE                NEW lcl_no_discount( ) ).
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  LOOP AT VALUE string_table( ( `` ) ( `REGULAR` ) ( `VIP` ) ) INTO DATA(lv_cat).
    WRITE: / lv_cat, lcl_discount_factory=>for_customer( lv_cat )->apply( 5000 ).
  ENDLOOP.
  " -> 5000 / 4750 / 4500
```
:::

# 11. ABAP Unit Testing

ABAP Unit is the built-in xUnit framework. Test classes are **local classes** with the addition `FOR TESTING`, written in the *Test Classes* include of a global class (ADT tab "Test Classes") or at the end of a report. Run with **Ctrl+Shift+F10** in ADT or *Execute → Unit Test* in SE80/SE24. Code Inspector / ATC can enforce unit tests.

```abap
" ---------- code under test (global class ZCL_PRICE_CALC) ----------
CLASS zcl_price_calc DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS net_to_gross IMPORTING iv_net TYPE decfloat34
                                   iv_vat TYPE decfloat34
                         RETURNING VALUE(rv) TYPE decfloat34
                         RAISING   cx_abap_invalid_value.
ENDCLASS.
CLASS zcl_price_calc IMPLEMENTATION.
  METHOD net_to_gross.
    IF iv_net < 0 OR iv_vat < 0.
      RAISE EXCEPTION TYPE cx_abap_invalid_value.
    ENDIF.
    rv = iv_net * ( 1 + iv_vat / 100 ).
  ENDMETHOD.
ENDCLASS.

" ---------- Test Classes include ----------
CLASS ltc_price_calc DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_price_calc.     " class under test
    METHODS setup.
    METHODS gross_with_14_percent FOR TESTING RAISING cx_static_check.
    METHODS zero_vat_returns_net  FOR TESTING RAISING cx_static_check.
    METHODS negative_net_raises   FOR TESTING.
ENDCLASS.

CLASS ltc_price_calc IMPLEMENTATION.
  METHOD setup.                 " runs before EACH test method
    mo_cut = NEW #( ).
  ENDMETHOD.

  METHOD gross_with_14_percent.
    " given / when / then
    DATA(lv_act) = mo_cut->net_to_gross( iv_net = 100 iv_vat = 14 ).
    cl_abap_unit_assert=>assert_equals( act = lv_act exp = 114
                                        msg = 'VAT 14% not applied' ).
  ENDMETHOD.

  METHOD zero_vat_returns_net.
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->net_to_gross( iv_net = 50 iv_vat = 0 ) exp = 50 ).
  ENDMETHOD.

  METHOD negative_net_raises.
    TRY.
        mo_cut->net_to_gross( iv_net = -1 iv_vat = 14 ).
        cl_abap_unit_assert=>fail( msg = 'Exception expected' ).
      CATCH cx_abap_invalid_value.
        " expected - test passes
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
```

## Fixture methods

| Method | When it runs |
|---|---|
| `class_setup` (static) | Once before the first test method of the class |
| `setup` | Before **each** test method |
| `teardown` | After each test method |
| `class_teardown` (static) | Once after the last test method |

## Test attributes

- `RISK LEVEL HARMLESS | DANGEROUS | CRITICAL` – what the test may change (harmless = no persistent changes).
- `DURATION SHORT | MEDIUM | LONG` – expected runtime (< 1 s / < 10 s / longer by default settings).
- Main assertions: `assert_equals`, `assert_differs`, `assert_true`, `assert_false`, `assert_bound`, `assert_not_bound`, `assert_initial`, `assert_not_initial`, `assert_subrc`, `assert_char_cp`, `assert_table_contains`, `fail`.

## Test doubles: isolating dependencies

Unit tests must not depend on database content or external systems. Techniques, from best to "last resort":

1. **Dependency injection via interface** – pass a fake implementation in the constructor (see Chapter 7).
2. **ABAP Test Double Framework** – generate doubles of interfaces at runtime: `cl_abap_testdouble=>create( 'ZIF_ORDER_REPO' )` and configure return values.
3. **SQL / CDS Test Double Framework** – replace DB tables or CDS views with test data: `cl_osql_test_environment=>create( VALUE #( ( 'VBAK' ) ) )`, `cl_cds_test_environment`.
4. **Test seams** (`TEST-SEAM` / `TEST-INJECTION`) – replace code blocks in legacy code you cannot refactor.

```abap
" Fake repository for tests - implements the same interface
CLASS ltd_order_repo DEFINITION FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_order_repo PARTIALLY IMPLEMENTED.
    DATA mt_orders TYPE zif_order_repo=>tt_orders.
ENDCLASS.
CLASS ltd_order_repo IMPLEMENTATION.
  METHOD zif_order_repo~get_open_orders.
    rt_orders = mt_orders.            " deterministic data, no DB access
  ENDMETHOD.
ENDCLASS.

" in the test class
METHOD sums_open_orders.
  DATA(lo_repo) = NEW ltd_order_repo( ).
  lo_repo->mt_orders = VALUE #( ( vbeln = '1' netwr = 100 )
                                ( vbeln = '2' netwr = 250 ) ).
  DATA(lo_cut) = NEW zcl_order_stats( io_repo = lo_repo ).
  cl_abap_unit_assert=>assert_equals( act = lo_cut->total_open( ) exp = 350 ).
ENDMETHOD.
```

```abap
" SQL test double: SELECTs on VBAK inside the code under test read this data
CLASS ltc_with_db DEFINITION FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS reads_orders FOR TESTING.
ENDCLASS.
CLASS ltc_with_db IMPLEMENTATION.
  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'VBAK' ) ) ).
  ENDMETHOD.
  METHOD setup.
    go_env->clear_doubles( ).
    DATA lt_vbak TYPE STANDARD TABLE OF vbak WITH EMPTY KEY.
    lt_vbak = VALUE #( ( vbeln = '0000000001' netwr = 10 ) ).
    go_env->insert_test_data( lt_vbak ).
  ENDMETHOD.
  METHOD reads_orders.
    " ... call code that selects from VBAK and assert ...
  ENDMETHOD.
  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.
ENDCLASS.
```

:::tip TDD in one sentence
Red (write a failing test) → Green (write the minimum code to pass) → Refactor (clean up while tests stay green). Mention it in interviews and show you write tests for business logic classes, not for UI code.
:::

:::lab Lab 11 – Test your Lab 10 discount engine
Write test class `LTC_DISCOUNT` with methods: regular customer gets 5 %, VIP discount is capped at 500 for 10 000, unknown category returns the full amount, and the factory returns an object of type `LCL_VIP_DISCOUNT` for 'VIP' (use `IS INSTANCE OF` + `assert_true`).
:::

:::solution Lab 11
```abap
CLASS ltc_discount DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS regular_gets_5_percent FOR TESTING.
    METHODS vip_is_capped          FOR TESTING.
    METHODS unknown_pays_full      FOR TESTING.
    METHODS factory_returns_vip    FOR TESTING.
ENDCLASS.

CLASS ltc_discount IMPLEMENTATION.
  METHOD regular_gets_5_percent.
    cl_abap_unit_assert=>assert_equals(
      act = lcl_discount_factory=>for_customer( 'REGULAR' )->apply( 1000 ) exp = 950 ).
  ENDMETHOD.
  METHOD vip_is_capped.
    cl_abap_unit_assert=>assert_equals(
      act = lcl_discount_factory=>for_customer( 'VIP' )->apply( 10000 ) exp = 9500 ).
  ENDMETHOD.
  METHOD unknown_pays_full.
    cl_abap_unit_assert=>assert_equals(
      act = lcl_discount_factory=>for_customer( 'XYZ' )->apply( 700 ) exp = 700 ).
  ENDMETHOD.
  METHOD factory_returns_vip.
    DATA(lo) = lcl_discount_factory=>for_customer( 'VIP' ).
    cl_abap_unit_assert=>assert_true( xsdbool( lo IS INSTANCE OF lcl_vip_discount ) ).
  ENDMETHOD.
ENDCLASS.
```
:::

# 12. Modern ABAP, SALV, RTTS and Real-World OO

## Modern syntax you will use inside every method (7.40 – 7.58)

| Feature | Example |
|---|---|
| Inline declaration | `DATA(lv_x) = 5.` / `SELECT ... INTO TABLE @DATA(lt_tab).` / `LOOP AT lt INTO DATA(ls).` |
| Constructor `NEW` | `DATA(lo) = NEW zcl_x( iv = 1 ).` |
| `VALUE` | `lt = VALUE #( ( id = 1 ) ( id = 2 ) ).` |
| `CORRESPONDING` | `ls_b = CORRESPONDING #( ls_a MAPPING kunnr = customer EXCEPT mandt ).` |
| `CONV` / `CAST` / `REF` | `CONV string( lv_num )`, `CAST zif_x( lo )`, `REF #( ls )` |
| `COND` / `SWITCH` | `COND #( WHEN a > 0 THEN 'P' ELSE 'N' )` |
| `REDUCE` / `FOR` | `REDUCE i( INIT s = 0 FOR w IN lt NEXT s = s + w-qty )` |
| `FILTER` | `FILTER #( lt_sorted WHERE status = 'A' )` (needs sorted/hashed key) |
| Table expressions | `lt[ id = 5 ]-name`, `line_exists( lt[ id = 5 ] )`, `line_index( ... )` |
| String templates | `|Order { lv_vbeln ALPHA = OUT } total { lv_amt CURRENCY = 'EGP' }|` |
| `xsdbool` | `DATA(lv_ok) = xsdbool( lv_a > lv_b ).` |
| New Open SQL | `SELECT FROM vbak FIELDS vbeln, netwr WHERE erdat >= @lv_d INTO TABLE @DATA(lt).` |
| GROUP BY loop | `LOOP AT lt INTO DATA(ls) GROUP BY ls-kunnr INTO DATA(grp).` |

## SALV – the OO way to display an ALV

```abap
CLASS lcl_report DEFINITION.
  PUBLIC SECTION.
    METHODS run.
  PRIVATE SECTION.
    TYPES tt_vbak TYPE STANDARD TABLE OF vbak WITH EMPTY KEY.
    DATA mt_data TYPE tt_vbak.
    DATA mo_alv  TYPE REF TO cl_salv_table.
    METHODS select_data.
    METHODS display.
    METHODS on_double_click FOR EVENT double_click OF cl_salv_events_table
      IMPORTING row column.
ENDCLASS.

CLASS lcl_report IMPLEMENTATION.
  METHOD run.
    select_data( ).
    display( ).
  ENDMETHOD.

  METHOD select_data.
    SELECT * FROM vbak UP TO 200 ROWS INTO TABLE @mt_data.
  ENDMETHOD.

  METHOD display.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = mo_alv
                                CHANGING  t_table      = mt_data ).
        mo_alv->get_functions( )->set_all( abap_true ).          " toolbar
        mo_alv->get_columns( )->set_optimize( abap_true ).
        mo_alv->get_columns( )->get_column( 'MANDT' )->set_visible( abap_false ).
        mo_alv->get_display_settings( )->set_striped_pattern( abap_true ).
        SET HANDLER on_double_click FOR mo_alv->get_event( ).
        mo_alv->display( ).
      CATCH cx_salv_msg cx_salv_not_found INTO DATA(lx).
        MESSAGE lx TYPE 'I'.
    ENDTRY.
  ENDMETHOD.

  METHOD on_double_click.
    DATA(ls_row) = mt_data[ row ].
    SET PARAMETER ID 'AUN' FIELD ls_row-vbeln.
    CALL TRANSACTION 'VA03' AND SKIP FIRST SCREEN.
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  NEW lcl_report( )->run( ).
```

## RTTS – Run Time Type Services

RTTS lets you inspect (RTTI) and create (RTTC) types at runtime – essential for generic tools, dynamic ALV, file uploads, and OData frameworks.

```abap
" RTTI - describe a structure
DATA(lo_struct) = CAST cl_abap_structdescr(
                    cl_abap_typedescr=>describe_by_name( 'VBAK' ) ).
LOOP AT lo_struct->components INTO DATA(ls_comp).
  WRITE: / ls_comp-name, ls_comp-type_kind, ls_comp-length.
ENDLOOP.

" class name of an object at runtime
DATA(lv_class) = cl_abap_classdescr=>get_class_name( lo_shape ).

" RTTC - build an internal table type dynamically and create data
DATA(lo_table_type) = cl_abap_tabledescr=>create( p_line_type = lo_struct ).
DATA lr_data TYPE REF TO data.
CREATE DATA lr_data TYPE HANDLE lo_table_type.
ASSIGN lr_data->* TO FIELD-SYMBOL(<lt_any>).
SELECT * FROM vbak UP TO 10 ROWS INTO TABLE @<lt_any>.
```

## Dynamic programming with objects

```abap
DATA lo_obj TYPE REF TO object.
DATA(lv_cls)  = `ZCL_INVOICE_HANDLER`.
DATA(lv_meth) = `PROCESS`.
CREATE OBJECT lo_obj TYPE (lv_cls).
CALL METHOD lo_obj->(lv_meth) EXPORTING iv_id = '1001'.

" with a parameter table
DATA(lv_id) = CONV string( '1001' ).
DATA(lt_params) = VALUE abap_parmbind_tab(
  ( name = 'IV_ID' kind = cl_abap_objectdescr=>exporting value = REF #( lv_id ) ) ).
CALL METHOD lo_obj->(lv_meth) PARAMETER-TABLE lt_params.
```

## BAdIs – OO-based enhancements

A **BAdI** (Business Add-In) is SAP's object-oriented enhancement technique: SAP defines a **BAdI interface** (`IF_EX_*` / `IF_BADI_*`) and calls it at a specific point; you create an **implementation class** that implements the interface.

- **Classic BAdI**: SE18 (definition) / SE19 (implementation); called with `CL_EXITHANDLER=>get_instance`.
- **New (kernel) BAdI**: part of an *Enhancement Spot*; called with `GET BADI lo_badi FILTERS ...` and `CALL BADI lo_badi->method`. Faster, supports filters and fallback classes.
- Find BAdIs: put a breakpoint in `CL_EXITHANDLER=>GET_INSTANCE` (classic) or search for `GET BADI` / `CALL BADI` in the program, or use SE84 / the enhancement spot.

```abap
" Your implementation class (created via SE19)
CLASS zcl_im_sd_check_order DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_ex_badi_sd_sales.        " example interface name
ENDCLASS.
```

## Clean ABAP & SOLID principles

| Principle | In ABAP terms |
|---|---|
| **S**ingle responsibility | One class = one reason to change (repository ≠ calculator ≠ ALV view) |
| **O**pen/closed | Add new behaviour with new classes (strategy/factory), not by editing CASE statements |
| **L**iskov substitution | A subclass must work anywhere the superclass is expected (don't throw "not supported" in redefinitions) |
| **I**nterface segregation | Several small interfaces > one huge interface |
| **D**ependency inversion | Depend on interfaces (`REF TO zif_repo`), inject implementations |

Clean ABAP rules worth quoting: prefer `RETURNING` over `EXPORTING`; keep methods short (< 20 statements); prefer class-based exceptions; no `FORM` routines in new code; prefer `NEW` over `CREATE OBJECT`; use `IS BOUND` / `IS NOT INITIAL` intentionally; avoid static methods for business logic (hard to test – no polymorphism).

## Other advanced OO topics (know the definition)

- **Persistent classes** (Object Services) – classes mapped to DB tables, generated via SE24 *Persistence*; managed by `CA_*`/`CB_*` agent classes. Rare in new projects.
- **Shared memory objects** – `CL_SHM_AREA`, area classes created in SHMA; share data between sessions on one application server.
- **AMDP** – ABAP Managed Database Procedures: a class implementing `IF_AMDP_MARKER_HDB`, methods `BY DATABASE PROCEDURE FOR HDB LANGUAGE SQLSCRIPT` – code pushdown to HANA.
- **Local types in global classes** – *Class-relevant local types* (definitions include) and *Local types* (implementation include); test classes in the *Test classes* include.
- **Garbage collection & weak references** – `CL_ABAP_WEAK_REFERENCE` holds an object without keeping it alive.

:::lab Lab 12 – OO sales report with SALV
Build a report `ZOO_SALES_REPORT` with select-options for sales org (`VKORG`) and creation date (`ERDAT`). Structure: `LCL_MODEL` (selects VBAK fields VBELN, ERDAT, KUNNR, NETWR, WAERK and computes the total per customer with `GROUP BY` or `REDUCE`), `LCL_VIEW` (SALV with total line and double-click to VA03), `LCL_CONTROLLER` (connects them). No global data except the selection screen.
:::

:::solution Lab 12
```abap
REPORT zoo_sales_report.

TABLES vbak.
SELECT-OPTIONS: s_vkorg FOR vbak-vkorg,
                s_erdat FOR vbak-erdat.

CLASS lcl_model DEFINITION.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_order,
             vbeln TYPE vbak-vbeln,
             erdat TYPE vbak-erdat,
             kunnr TYPE vbak-kunnr,
             netwr TYPE vbak-netwr,
             waerk TYPE vbak-waerk,
           END OF ty_order,
           tt_orders TYPE STANDARD TABLE OF ty_order WITH EMPTY KEY.
    METHODS constructor IMPORTING it_vkorg LIKE s_vkorg[] it_erdat LIKE s_erdat[].
    METHODS get_orders RETURNING VALUE(rt) TYPE tt_orders.
  PRIVATE SECTION.
    DATA: mt_vkorg LIKE s_vkorg[], mt_erdat LIKE s_erdat[].
ENDCLASS.

CLASS lcl_model IMPLEMENTATION.
  METHOD constructor.
    mt_vkorg = it_vkorg. mt_erdat = it_erdat.
  ENDMETHOD.
  METHOD get_orders.
    SELECT FROM vbak
      FIELDS vbeln, erdat, kunnr, netwr, waerk
      WHERE vkorg IN @mt_vkorg AND erdat IN @mt_erdat
      ORDER BY kunnr, vbeln
      INTO TABLE @rt
      UP TO 1000 ROWS.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_view DEFINITION.
  PUBLIC SECTION.
    METHODS show CHANGING ct_data TYPE lcl_model=>tt_orders.
  PRIVATE SECTION.
    DATA mr_data TYPE REF TO lcl_model=>tt_orders.
    METHODS on_dbl FOR EVENT double_click OF cl_salv_events_table IMPORTING row.
ENDCLASS.

CLASS lcl_view IMPLEMENTATION.
  METHOD show.
    mr_data = REF #( ct_data ).
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                                CHANGING  t_table      = ct_data ).
        lo_alv->get_functions( )->set_all( ).
        lo_alv->get_columns( )->set_optimize( ).
        DATA(lo_aggr) = lo_alv->get_aggregations( ).
        lo_aggr->add_aggregation( columnname  = 'NETWR'
                                  aggregation = if_salv_c_aggregation=>total ).
        DATA(lo_sort) = lo_alv->get_sorts( ).
        lo_sort->add_sort( columnname = 'KUNNR' subtotal = abap_true ).
        SET HANDLER on_dbl FOR lo_alv->get_event( ).
        lo_alv->display( ).
      CATCH cx_salv_error INTO DATA(lx).
        MESSAGE lx TYPE 'I'.
    ENDTRY.
  ENDMETHOD.
  METHOD on_dbl.
    SET PARAMETER ID 'AUN' FIELD mr_data->*[ row ]-vbeln.
    CALL TRANSACTION 'VA03' AND SKIP FIRST SCREEN.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_controller DEFINITION.
  PUBLIC SECTION.
    METHODS run.
ENDCLASS.
CLASS lcl_controller IMPLEMENTATION.
  METHOD run.
    DATA(lt_orders) = NEW lcl_model( it_vkorg = s_vkorg[] it_erdat = s_erdat[]
                                   )->get_orders( ).
    IF lt_orders IS INITIAL.
      MESSAGE 'No orders found' TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.
    NEW lcl_view( )->show( CHANGING ct_data = lt_orders ).
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  NEW lcl_controller( )->run( ).
```
:::
