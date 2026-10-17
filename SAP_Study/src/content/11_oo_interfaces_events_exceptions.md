# 7. Interfaces

An **interface** is a pure contract: a named list of method signatures (plus optionally types, constants, attributes and events) **without implementation**. Any class that says `INTERFACES zif_x` promises to implement all its methods. Interfaces give you:

- **Multiple "inheritance" of contracts** – a class may implement many interfaces.
- **Loose coupling** – code depends on `REF TO zif_x`, not on a concrete class, so you can swap implementations (e.g. a real DB access class vs. a test double).
- The basis of **BAdIs**, SAP standard frameworks (`IF_HTTP_EXTENSION`, `IF_SALV_*`, `IF_OO_ADT_CLASSRUN`) and RAP.

```abap
INTERFACE lif_printable.
  CONSTANTS gc_width TYPE i VALUE 80.
  METHODS print RETURNING VALUE(rv_text) TYPE string.
ENDINTERFACE.

INTERFACE lif_exportable.
  METHODS to_json RETURNING VALUE(rv_json) TYPE string.
ENDINTERFACE.

CLASS lcl_invoice DEFINITION.
  PUBLIC SECTION.
    INTERFACES: lif_printable, lif_exportable.
    ALIASES print FOR lif_printable~print.      " shorter name
    METHODS constructor IMPORTING iv_no TYPE string iv_amount TYPE decfloat34.
  PRIVATE SECTION.
    DATA mv_no     TYPE string.
    DATA mv_amount TYPE decfloat34.
ENDCLASS.

CLASS lcl_invoice IMPLEMENTATION.
  METHOD constructor.
    mv_no = iv_no. mv_amount = iv_amount.
  ENDMETHOD.
  METHOD lif_printable~print.                   " interface method: intf~method
    rv_text = |Invoice { mv_no }: { mv_amount }|.
  ENDMETHOD.
  METHOD lif_exportable~to_json.
    rv_json = |\{"no":"{ mv_no }","amount":{ mv_amount }\}|.
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  DATA lo_p TYPE REF TO lif_printable.
  lo_p = NEW lcl_invoice( iv_no = 'INV-1' iv_amount = 500 ).   " up-cast to interface
  WRITE / lo_p->print( ).

  DATA(lo_inv) = NEW lcl_invoice( iv_no = 'INV-2' iv_amount = 99 ).
  WRITE / lo_inv->print( ).                         " via alias
  WRITE / lo_inv->lif_exportable~to_json( ).        " full name
  WRITE / lif_printable=>gc_width.                  " interface constant
```

## Interface rules you must know

- All interface components are **public**; the implementing class must declare `INTERFACES` in its **PUBLIC SECTION**.
- Components are addressed with the **interface component selector** `~`: `lif_printable~print`.
- You **cannot instantiate** an interface, but you can declare reference variables of it.
- An interface can include other interfaces (**nested / composite interface**): `INTERFACE lif_doc. INTERFACES lif_printable. ENDINTERFACE.`
- When a class implements an interface, all its **subclasses** implement it too (and can redefine its methods: `METHODS lif_printable~print REDEFINITION.`).
- Partial implementation: `INTERFACES lif_x ABSTRACT METHODS m1` (in an abstract class) or `ALL METHODS ABSTRACT`; in test doubles you can use `PARTIALLY IMPLEMENTED` (only in test classes).
- Newer releases allow `METHODS m DEFAULT IGNORE` / `DEFAULT FAIL` in an interface, so implementing classes may skip optional methods.

## Interfaces + polymorphism: dependency injection

```abap
INTERFACE lif_notifier.
  METHODS send IMPORTING iv_to TYPE string iv_text TYPE string.
ENDINTERFACE.

CLASS lcl_email_notifier DEFINITION.
  PUBLIC SECTION. INTERFACES lif_notifier.
ENDCLASS.
CLASS lcl_email_notifier IMPLEMENTATION.
  METHOD lif_notifier~send.
    WRITE: / 'EMAIL to', iv_to, ':', iv_text.  " real code: CL_BCS
  ENDMETHOD.
ENDCLASS.

CLASS lcl_sms_notifier DEFINITION.
  PUBLIC SECTION. INTERFACES lif_notifier.
ENDCLASS.
CLASS lcl_sms_notifier IMPLEMENTATION.
  METHOD lif_notifier~send.
    WRITE: / 'SMS to', iv_to, ':', iv_text.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_order_service DEFINITION.
  PUBLIC SECTION.
    " the dependency is INJECTED through the constructor
    METHODS constructor IMPORTING io_notifier TYPE REF TO lif_notifier.
    METHODS release_order IMPORTING iv_order TYPE vbeln.
  PRIVATE SECTION.
    DATA mo_notifier TYPE REF TO lif_notifier.
ENDCLASS.
CLASS lcl_order_service IMPLEMENTATION.
  METHOD constructor.
    mo_notifier = io_notifier.
  ENDMETHOD.
  METHOD release_order.
    " ... business logic ...
    mo_notifier->send( iv_to = 'customer' iv_text = |Order { iv_order } released| ).
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  NEW lcl_order_service( NEW lcl_sms_notifier( ) )->release_order( '0000004711' ).
```

`LCL_ORDER_SERVICE` does not know whether it sends e-mail or SMS – and in a unit test we can inject a fake notifier. This is the core idea behind testable OO code.

:::lab Lab 7 – Storage contract
Define `LIF_STORAGE` with methods `save( iv_key iv_value )`, `load( iv_key ) RETURNING rv_value` and `count( ) RETURNING rv`. Implement it twice: `LCL_MEMORY_STORAGE` (hashed internal table) and `LCL_LOGGING_STORAGE` that *wraps* another `LIF_STORAGE` and writes a log line before delegating (this is the **Decorator** pattern). Use both through a `REF TO lif_storage`.
:::

:::solution Lab 7
```abap
INTERFACE lif_storage.
  METHODS save  IMPORTING iv_key TYPE string iv_value TYPE string.
  METHODS load  IMPORTING iv_key TYPE string RETURNING VALUE(rv_value) TYPE string.
  METHODS count RETURNING VALUE(rv) TYPE i.
ENDINTERFACE.

CLASS lcl_memory_storage DEFINITION.
  PUBLIC SECTION. INTERFACES lif_storage.
  PRIVATE SECTION.
    TYPES: BEGIN OF ty_kv, key TYPE string, value TYPE string, END OF ty_kv.
    DATA mt_data TYPE HASHED TABLE OF ty_kv WITH UNIQUE KEY key.
ENDCLASS.
CLASS lcl_memory_storage IMPLEMENTATION.
  METHOD lif_storage~save.
    INSERT VALUE #( key = iv_key value = iv_value ) INTO TABLE mt_data.
    IF sy-subrc <> 0.                       " key exists -> update
      mt_data[ key = iv_key ]-value = iv_value.
    ENDIF.
  ENDMETHOD.
  METHOD lif_storage~load.
    rv_value = VALUE #( mt_data[ key = iv_key ]-value OPTIONAL ).
  ENDMETHOD.
  METHOD lif_storage~count.
    rv = lines( mt_data ).
  ENDMETHOD.
ENDCLASS.

CLASS lcl_logging_storage DEFINITION.
  PUBLIC SECTION.
    INTERFACES lif_storage.
    METHODS constructor IMPORTING io_inner TYPE REF TO lif_storage.
  PRIVATE SECTION.
    DATA mo_inner TYPE REF TO lif_storage.
ENDCLASS.
CLASS lcl_logging_storage IMPLEMENTATION.
  METHOD constructor. mo_inner = io_inner. ENDMETHOD.
  METHOD lif_storage~save.
    WRITE: / 'LOG save', iv_key.
    mo_inner->save( iv_key = iv_key iv_value = iv_value ).
  ENDMETHOD.
  METHOD lif_storage~load.
    WRITE: / 'LOG load', iv_key.
    rv_value = mo_inner->load( iv_key ).
  ENDMETHOD.
  METHOD lif_storage~count.
    rv = mo_inner->count( ).
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  DATA(lo_store) = CAST lif_storage(
                     NEW lcl_logging_storage( NEW lcl_memory_storage( ) ) ).
  lo_store->save( iv_key = 'A' iv_value = 'Apple' ).
  lo_store->save( iv_key = 'A' iv_value = 'Avocado' ).
  WRITE: / lo_store->load( 'A' ), lo_store->count( ).   " Avocado 1
```
:::

# 8. Events

Events let an object **announce** that something happened without knowing who is interested (publish/subscribe – the **Observer** pattern). Four steps:

1. **Declare** the event in the publishing class: `EVENTS` (instance) or `CLASS-EVENTS` (static). Events may only have `EXPORTING` parameters, always passed by value. Every instance event automatically has the implicit parameter `sender` (reference to the raising object).
2. **Raise** it in a method of the publisher: `RAISE EVENT evt EXPORTING p = v.`
3. **Declare a handler method** in the subscriber: `METHODS on_evt FOR EVENT evt OF lcl_publisher IMPORTING p sender.`
4. **Register** the handler at runtime: `SET HANDLER lo_sub->on_evt FOR lo_pub.` (or `FOR ALL INSTANCES`; static events need no `FOR`). Deregister with `ACTIVATION abap_false`.

```abap
CLASS lcl_stock DEFINITION.
  PUBLIC SECTION.
    EVENTS low_stock EXPORTING VALUE(ev_matnr) TYPE matnr
                               VALUE(ev_qty)   TYPE i.
    METHODS constructor IMPORTING iv_matnr TYPE matnr iv_qty TYPE i.
    METHODS withdraw    IMPORTING iv_qty TYPE i.
  PRIVATE SECTION.
    CONSTANTS gc_min TYPE i VALUE 10.
    DATA: mv_matnr TYPE matnr, mv_qty TYPE i.
ENDCLASS.

CLASS lcl_stock IMPLEMENTATION.
  METHOD constructor.
    mv_matnr = iv_matnr. mv_qty = iv_qty.
  ENDMETHOD.
  METHOD withdraw.
    mv_qty -= iv_qty.
    IF mv_qty < gc_min.
      RAISE EVENT low_stock EXPORTING ev_matnr = mv_matnr ev_qty = mv_qty.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_purchasing DEFINITION.
  PUBLIC SECTION.
    METHODS on_low_stock FOR EVENT low_stock OF lcl_stock
      IMPORTING ev_matnr ev_qty sender.
ENDCLASS.

CLASS lcl_purchasing IMPLEMENTATION.
  METHOD on_low_stock.
    WRITE: / 'Create purchase requisition for', ev_matnr, 'qty left', ev_qty.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_alert DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS on_low_stock FOR EVENT low_stock OF lcl_stock
      IMPORTING ev_matnr.
ENDCLASS.

CLASS lcl_alert IMPLEMENTATION.
  METHOD on_low_stock.
    WRITE: / 'ALERT: low stock of', ev_matnr.
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  DATA(lo_stock) = NEW lcl_stock( iv_matnr = 'MAT-01' iv_qty = 15 ).
  DATA(lo_purch) = NEW lcl_purchasing( ).

  SET HANDLER lo_purch->on_low_stock FOR lo_stock.     " one publisher
  SET HANDLER lcl_alert=>on_low_stock FOR ALL INSTANCES. " every stock object

  lo_stock->withdraw( 3 ).    " 12 - nothing happens
  lo_stock->withdraw( 5 ).    " 7  - both handlers run
```

:::note Where you meet events in real projects
ALV grids (`CL_GUI_ALV_GRID` events `double_click`, `toolbar`, `user_command`, `hotspot_click`), `CL_SALV_TABLE` (`get_event( )` → `added_function`, `link_click`), Workflow (`BOR`/class events with `IF_WORKFLOW`), and custom frameworks.
:::

:::warn Event pitfalls
- Handlers run **synchronously** in registration order – the raising method continues only after all handlers finish.
- If no handler is registered, `RAISE EVENT` simply does nothing.
- Registered handlers keep the handler object alive (it is referenced by the registration) – deregister when no longer needed.
:::

:::lab Lab 8 – Order status observer
Create `LCL_ORDER` with method `set_status( iv_status )` that raises event `status_changed` with old and new status. Register two observers: `LCL_AUDIT_LOG` (writes "old → new") and `LCL_CUSTOMER_MAIL` that only reacts when new status = 'SHIPPED'. Then deregister the mail handler and change the status again.
:::

:::solution Lab 8
```abap
CLASS lcl_order DEFINITION.
  PUBLIC SECTION.
    EVENTS status_changed EXPORTING VALUE(ev_old) TYPE string
                                    VALUE(ev_new) TYPE string.
    METHODS set_status IMPORTING iv_status TYPE string.
  PRIVATE SECTION.
    DATA mv_status TYPE string VALUE 'NEW'.
ENDCLASS.
CLASS lcl_order IMPLEMENTATION.
  METHOD set_status.
    DATA(lv_old) = mv_status.
    mv_status = iv_status.
    RAISE EVENT status_changed EXPORTING ev_old = lv_old ev_new = iv_status.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_audit_log DEFINITION.
  PUBLIC SECTION.
    METHODS on_change FOR EVENT status_changed OF lcl_order IMPORTING ev_old ev_new.
ENDCLASS.
CLASS lcl_audit_log IMPLEMENTATION.
  METHOD on_change. WRITE: / |AUDIT: { ev_old } -> { ev_new }|. ENDMETHOD.
ENDCLASS.

CLASS lcl_customer_mail DEFINITION.
  PUBLIC SECTION.
    METHODS on_change FOR EVENT status_changed OF lcl_order IMPORTING ev_new.
ENDCLASS.
CLASS lcl_customer_mail IMPLEMENTATION.
  METHOD on_change.
    CHECK ev_new = 'SHIPPED'.
    WRITE: / 'MAIL: your order has been shipped'.
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  DATA(lo_order) = NEW lcl_order( ).
  DATA(lo_audit) = NEW lcl_audit_log( ).
  DATA(lo_mail)  = NEW lcl_customer_mail( ).
  SET HANDLER: lo_audit->on_change FOR lo_order,
               lo_mail->on_change  FOR lo_order.
  lo_order->set_status( 'PACKED' ).
  lo_order->set_status( 'SHIPPED' ).
  SET HANDLER lo_mail->on_change FOR lo_order ACTIVATION abap_false.
  lo_order->set_status( 'DELIVERED' ).   " only audit reacts
```
:::

# 9. Class-Based Exceptions

Modern ABAP handles errors with **exception classes** (`TRY ... CATCH ... ENDTRY`) instead of `sy-subrc` and classic `EXCEPTIONS`. An exception is an **object** that carries information (text, attributes, previous exception).

## The exception class hierarchy

| Superclass | Checked by | Must be declared in RAISING? | Use for |
|---|---|---|---|
| `CX_STATIC_CHECK` | Compiler (syntax check warns) | Yes | Expected business errors the caller must handle (e.g. order not found) |
| `CX_DYNAMIC_CHECK` | Runtime | Only checked at runtime if not handled | Errors the caller can prevent with a check (e.g. `CX_SY_ZERODIVIDE`, invalid parameter) |
| `CX_NO_CHECK` | Never | Not allowed/needed (implicitly propagated) | Fatal / technical errors that can occur anywhere (e.g. out of memory) |

All three inherit from `CX_ROOT`. Useful methods of `CX_ROOT`: `get_text( )`, `get_longtext( )`, `get_source_position( )`, attribute `previous`.

## TRY / CATCH / CLEANUP / RETRY / RESUME

```abap
TRY.
    DATA(lv_res) = lcl_calc=>divide( iv_a = 10 iv_b = 0 ).
  CATCH cx_sy_zerodivide INTO DATA(lx_zero).
    WRITE / lx_zero->get_text( ).
  CATCH cx_sy_arithmetic_error cx_sy_conversion_error INTO DATA(lx_other).
    " several classes in one CATCH; order matters: specific first!
    WRITE / lx_other->get_text( ).
  CLEANUP.
    " runs when the exception is NOT caught here but propagates upwards
    " (use it to release locks, close files, restore state)
ENDTRY.
```

- **CATCH order matters** – catch subclasses before superclasses, otherwise the specific handler is unreachable (syntax warning).
- `RETRY` (inside CATCH) restarts the TRY block – useful after fixing the cause (be careful with endless loops).
- `RESUME` (inside CATCH) continues after the `RAISE RESUMABLE EXCEPTION` statement – only for resumable exceptions declared `RAISING RESUMABLE(cx_...)`.
- `CATCH BEFORE UNWIND` keeps the context of the raising point alive while the handler runs (needed for RESUME).

## Creating your own exception class

In SE24/ADT create `ZCX_ORDER_ERROR` inheriting from `CX_STATIC_CHECK` and implement interface `IF_T100_MESSAGE` (texts from a message class in SE91) – or `IF_T100_DYN_MSG` to use the `MESSAGE` addition of `RAISE EXCEPTION`.

```abap
CLASS zcx_order_error DEFINITION PUBLIC INHERITING FROM cx_static_check
  CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_t100_message.     " or IF_T100_DYN_MSG for RAISE ... MESSAGE

    CONSTANTS:
      BEGIN OF order_not_found,          " text ID -> message ZSD 001
        msgid TYPE symsgid VALUE 'ZSD',
        msgno TYPE symsgno VALUE '001',
        attr1 TYPE scx_attrname VALUE 'MV_VBELN',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF order_not_found,
      BEGIN OF order_locked,             " message ZSD 002: Order &1 locked by &2
        msgid TYPE symsgid VALUE 'ZSD',
        msgno TYPE symsgno VALUE '002',
        attr1 TYPE scx_attrname VALUE 'MV_VBELN',
        attr2 TYPE scx_attrname VALUE 'MV_USER',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF order_locked.

    DATA mv_vbeln TYPE vbeln READ-ONLY.
    DATA mv_user  TYPE syuname READ-ONLY.

    METHODS constructor
      IMPORTING textid   LIKE if_t100_message=>t100key OPTIONAL
                previous LIKE previous OPTIONAL
                mv_vbeln TYPE vbeln OPTIONAL
                mv_user  TYPE syuname OPTIONAL.
ENDCLASS.

CLASS zcx_order_error IMPLEMENTATION.
  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    me->mv_vbeln = mv_vbeln.
    me->mv_user  = mv_user.
    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
```

Raising and handling it:

```abap
METHOD get_order.     " ... RAISING zcx_order_error
  SELECT SINGLE * FROM vbak WHERE vbeln = @iv_vbeln INTO @rs_order.
  IF sy-subrc <> 0.
    RAISE EXCEPTION TYPE zcx_order_error
      EXPORTING textid   = zcx_order_error=>order_not_found
                mv_vbeln = iv_vbeln.
    " 7.52+: RAISE EXCEPTION NEW zcx_order_error( textid = ... mv_vbeln = ... ).
  ENDIF.
ENDMETHOD.

" caller
TRY.
    DATA(ls_order) = lo_repo->get_order( '0000000001' ).
  CATCH zcx_order_error INTO DATA(lx).
    MESSAGE lx TYPE 'I' DISPLAY LIKE 'E'.     " exception object as message
ENDTRY.
```

## Exception chaining with `previous`

Wrap low-level technical exceptions into meaningful business ones without losing the root cause:

```abap
TRY.
    lo_db->insert_order( ls_order ).
  CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
    RAISE EXCEPTION TYPE zcx_order_error
      EXPORTING textid = zcx_order_error=>order_not_found
                previous = lx_sql.          " keep the original
ENDTRY.
```

## Classic vs. class-based – what to remember

| Classic (`EXCEPTIONS` / `sy-subrc`) | Class-based (`RAISING` / `TRY`) |
|---|---|
| Only a number in `sy-subrc` | An object with text, attributes, chain |
| Must be checked right after the call | Propagates automatically up the call stack |
| Function modules, old methods | All new code; mandatory in RAP/Gateway |
| `MESSAGE ... RAISING` | `RAISE EXCEPTION TYPE` / `NEW` |

:::warn You cannot mix both in one method signature
A method uses either `EXCEPTIONS` (classic) or `RAISING` (class-based), never both. To call a classic FM from OO code, check `sy-subrc` and convert it into an exception.
:::

:::lab Lab 9 – Safe division service
Create exception class `LCX_CALC_ERROR` (inherit `CX_STATIC_CHECK`, attribute `mv_reason` and redefine `get_text` to return it). Class `LCL_SAFE_CALC=>divide` raises it on division by zero, wrapping the original `CX_SY_ZERODIVIDE` as `previous`. In the caller, print both the business text and the previous exception's text, and use `CLEANUP` in an intermediate method to write "cleanup done".
:::

:::solution Lab 9
```abap
CLASS lcx_calc_error DEFINITION INHERITING FROM cx_static_check.
  PUBLIC SECTION.
    DATA mv_reason TYPE string READ-ONLY.
    METHODS constructor IMPORTING iv_reason TYPE string
                                  previous  LIKE previous OPTIONAL.
    METHODS get_text REDEFINITION.
ENDCLASS.
CLASS lcx_calc_error IMPLEMENTATION.
  METHOD constructor.
    super->constructor( previous = previous ).
    mv_reason = iv_reason.
  ENDMETHOD.
  METHOD get_text. result = mv_reason. ENDMETHOD.
ENDCLASS.

CLASS lcl_safe_calc DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS divide IMPORTING iv_a TYPE decfloat34 iv_b TYPE decfloat34
                         RETURNING VALUE(rv) TYPE decfloat34
                         RAISING lcx_calc_error.
    CLASS-METHODS process RAISING lcx_calc_error.
ENDCLASS.
CLASS lcl_safe_calc IMPLEMENTATION.
  METHOD divide.
    TRY.
        rv = iv_a / iv_b.
      CATCH cx_sy_zerodivide INTO DATA(lx).
        RAISE EXCEPTION NEW lcx_calc_error( iv_reason = 'Divisor must not be 0'
                                            previous  = lx ).
    ENDTRY.
  ENDMETHOD.
  METHOD process.
    TRY.
        divide( iv_a = 1 iv_b = 0 ).
      CLEANUP.
        WRITE / 'cleanup done'.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  TRY.
      lcl_safe_calc=>process( ).
    CATCH lcx_calc_error INTO DATA(lx_calc).
      WRITE: / lx_calc->get_text( ),
             / 'Root cause:', lx_calc->previous->get_text( ).
  ENDTRY.
```
:::
