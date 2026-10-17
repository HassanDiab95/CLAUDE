@part Part I — ABAP Objects | Classes, objects, inheritance, interfaces, events, / exceptions, design patterns, unit testing & modern ABAP

# 1. Why Object-Oriented ABAP?

ABAP started as a **procedural** language: reports, subroutines (`FORM`) and function modules. Since release 4.6 SAP added **ABAP Objects**, and today almost everything new in SAP is built on it: BAdIs, SALV, Gateway/OData (DPC/MPC classes), RAP behavior pools, AMDP, Workflow, ABAP Unit. You **cannot** be an advanced SAP developer without OO.

## Procedural vs. Object-Oriented

| Aspect | Procedural ABAP | ABAP Objects |
|---|---|---|
| Building block | Program, FORM, function module | Class, object, interface |
| Data | Global data shared by everything | Data encapsulated inside objects |
| Reuse | Copy code / call FM | Inheritance, interfaces, composition |
| Multiple instances | Hard (function group = one global state) | Easy – create as many objects as you need |
| Extensibility | Modify or copy | Subclass / implement interface / BAdI |
| Testability | Hard | ABAP Unit + test doubles |
| Stricter syntax | Obsolete statements allowed | Obsolete statements forbidden inside classes |

## The four pillars of OOP

- **Encapsulation** – an object hides its internal data and exposes only a public interface (methods). Others cannot corrupt its state.
- **Abstraction** – you work with *what* an object does, not *how* (e.g. `lo_printer->print( )`).
- **Inheritance** – a subclass reuses and specialises a superclass (`ZCL_TRUCK` inherits from `ZCL_VEHICLE`).
- **Polymorphism** – one call, many behaviours: the same method call runs different code depending on the real object type at runtime.

## Key vocabulary

| Term | Meaning |
|---|---|
| Class | The blueprint / template (definition of attributes + methods) |
| Object (instance) | A concrete thing created from a class at runtime, lives in memory |
| Attribute | Data inside a class (variable, constant, structure, table, reference) |
| Method | Behaviour – a procedure that belongs to the class |
| Reference variable | A pointer to an object: `DATA lo_car TYPE REF TO lcl_car.` |
| Instance component | Belongs to each object separately (`DATA`, `METHODS`) |
| Static component | Belongs to the class itself, shared by all objects (`CLASS-DATA`, `CLASS-METHODS`) |
| Interface | A contract – list of methods without implementation |
| Event | A notification raised by one object and handled by others |

# 2. Classes and Objects

## Local vs. global classes

- **Local class** – defined inside a program (report, include, function group, or the "Local Types" of a global class). Visible only in that program. Great for learning and for helper classes.
- **Global class** – stored in the class library (**SE24** or **ADT**: *New → ABAP Class*). Usable from any program in the system. Names start with `ZCL_`/`YCL_` for customer objects.

## Anatomy of a class

Every class has two parts: the **DEFINITION** (what it has – declarations) and the **IMPLEMENTATION** (how methods work).

```abap
REPORT zoo_demo_01.

CLASS lcl_bank_account DEFINITION.
  PUBLIC SECTION.
    " visible to everyone
    METHODS constructor IMPORTING iv_owner TYPE string
                                  iv_balance TYPE p DEFAULT 0.
    METHODS deposit     IMPORTING iv_amount TYPE p.
    METHODS withdraw    IMPORTING iv_amount TYPE p.
    METHODS get_balance RETURNING VALUE(rv_balance) TYPE decfloat34.
    CLASS-DATA gv_count TYPE i READ-ONLY.     " static: shared by all accounts

  PROTECTED SECTION.
    " visible to this class and its subclasses

  PRIVATE SECTION.
    " visible only inside this class
    DATA mv_owner   TYPE string.
    DATA mv_balance TYPE decfloat34.
ENDCLASS.

CLASS lcl_bank_account IMPLEMENTATION.
  METHOD constructor.
    mv_owner   = iv_owner.
    mv_balance = iv_balance.
    gv_count  += 1.
  ENDMETHOD.

  METHOD deposit.
    mv_balance = mv_balance + iv_amount.
  ENDMETHOD.

  METHOD withdraw.
    IF iv_amount > mv_balance.
      MESSAGE 'Insufficient funds' TYPE 'I'.
      RETURN.
    ENDIF.
    mv_balance = mv_balance - iv_amount.
  ENDMETHOD.

  METHOD get_balance.
    rv_balance = mv_balance.
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  DATA(lo_acc1) = NEW lcl_bank_account( iv_owner = 'Hassan' iv_balance = 1000 ).
  DATA(lo_acc2) = NEW lcl_bank_account( iv_owner = 'Mona' ).

  lo_acc1->deposit( 500 ).
  lo_acc1->withdraw( 200 ).

  WRITE: / 'Balance 1:', lo_acc1->get_balance( ).
  WRITE: / 'Balance 2:', lo_acc2->get_balance( ).
  WRITE: / 'Accounts :', lcl_bank_account=>gv_count.
```

Things to notice:

- `->` accesses **instance** components (via an object reference); `=>` accesses **static** components (via the class name).
- `NEW lcl_bank_account( ... )` creates an object and returns a reference. The older equivalent is `CREATE OBJECT lo_acc1 EXPORTING iv_owner = 'Hassan'.`
- A method with a single non-optional importing parameter can be called with the value only: `lo_acc1->deposit( 500 )`.
- `READ-ONLY` lets outsiders read a public attribute but not change it.

## Visibility sections

| Section | Accessible from | Typical content |
|---|---|---|
| `PUBLIC SECTION` | Everywhere | The API: methods consumers call, constants, types |
| `PROTECTED SECTION` | The class itself + its subclasses | Helper methods/attributes subclasses need |
| `PRIVATE SECTION` | Only the class itself (and its *friends*) | Internal state and helpers |

:::warn Order of sections
In the definition the sections **must** appear in the order PUBLIC → PROTECTED → PRIVATE. Each one is optional.
:::

## Attributes

```abap
CLASS lcl_demo DEFINITION.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_item,
             matnr TYPE matnr,
             menge TYPE i,
           END OF ty_item,
           tt_items TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.

    CONSTANTS gc_max_items TYPE i VALUE 100.     " constant (always static)
    DATA      mv_name      TYPE string.          " instance attribute
    DATA      mt_items     TYPE tt_items.        " instance internal table
    DATA      mo_logger    TYPE REF TO lcl_logger. " reference attribute
    CLASS-DATA gv_counter  TYPE i.                " static attribute
ENDCLASS.
```

## Methods and their parameters

| Parameter kind | Direction | Notes |
|---|---|---|
| `IMPORTING` | Caller → method | Read-only inside the method (unless `VALUE( )` is used) |
| `EXPORTING` | Method → caller | Not initialised automatically when passed by reference |
| `CHANGING` | Both ways | Caller's value comes in, modified value goes out |
| `RETURNING VALUE( )` | Method → caller | Exactly one; always pass by value; makes it a **functional method** usable in expressions |
| `RAISING` | – | Lists class-based exceptions the method may propagate |

```abap
CLASS lcl_calc DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS add
      IMPORTING iv_a          TYPE i
                iv_b          TYPE i
      RETURNING VALUE(rv_sum) TYPE i.

    CLASS-METHODS divide
      IMPORTING iv_a          TYPE decfloat34
                iv_b          TYPE decfloat34
      RETURNING VALUE(rv_res) TYPE decfloat34
      RAISING   cx_sy_zerodivide.

    CLASS-METHODS split_name
      IMPORTING iv_full  TYPE string
      EXPORTING ev_first TYPE string
                ev_last  TYPE string.

    CLASS-METHODS increment
      CHANGING cv_value TYPE i.
ENDCLASS.

CLASS lcl_calc IMPLEMENTATION.
  METHOD add.
    rv_sum = iv_a + iv_b.
  ENDMETHOD.
  METHOD divide.
    rv_res = iv_a / iv_b.            " raises CX_SY_ZERODIVIDE if iv_b = 0
  ENDMETHOD.
  METHOD split_name.
    SPLIT iv_full AT space INTO ev_first ev_last.
  ENDMETHOD.
  METHOD increment.
    cv_value += 1.
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  " functional call inside an expression
  DATA(lv_total) = lcl_calc=>add( iv_a = 2 iv_b = 3 ) * 10.

  lcl_calc=>split_name( EXPORTING iv_full  = 'Hassan Diab'
                        IMPORTING ev_first = DATA(lv_first)
                                  ev_last  = DATA(lv_last) ).
  DATA(lv_n) = 5.
  lcl_calc=>increment( CHANGING cv_value = lv_n ).   " lv_n = 6
```

:::note Pass by value vs. pass by reference
By default IMPORTING/EXPORTING/CHANGING are passed **by reference** (fast, no copy). `VALUE( iv_x )` passes **by value** (a copy). RETURNING is always by value. With EXPORTING by reference the parameter keeps the caller's old value until you assign it – always `CLEAR` exporting tables before filling them.
:::

### Optional and default parameters, preferred parameter

```abap
METHODS log
  IMPORTING iv_text TYPE string
            iv_type TYPE symsgty DEFAULT 'I'
            iv_ctx  TYPE string OPTIONAL.
" inside the method:  IF iv_ctx IS SUPPLIED. ... ENDIF.
```

`PREFERRED PARAMETER` lets you call a method with several optional parameters using a single unnamed value.

## Instance vs. static components

```abap
CLASS lcl_counter DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS get_total RETURNING VALUE(rv) TYPE i.   " static method
    METHODS       hit.                                    " instance method
  PRIVATE SECTION.
    CLASS-DATA gv_total TYPE i.     " one value for the whole class
    DATA       mv_mine  TYPE i.     " one value per object
ENDCLASS.

CLASS lcl_counter IMPLEMENTATION.
  METHOD hit.
    mv_mine  += 1.
    gv_total += 1.                 " instance methods may use static attributes
  ENDMETHOD.
  METHOD get_total.
    rv = gv_total.                 " static methods can NOT use mv_mine or me
  ENDMETHOD.
ENDCLASS.
```

:::warn Static methods have no `me`
A static method is not executed on an object, so it cannot access instance attributes, call instance methods directly, or use the self-reference `me`.
:::

## Reference variables, `me`, and object lifetime

- `DATA lo_obj TYPE REF TO lcl_x.` declares a reference – it is **initial** (points to nothing) until you create an object.
- Calling a method on an initial reference raises the runtime error `CX_SY_REF_IS_INITIAL` (dump `OBJECTS_OBJREF_NOT_ASSIGNED`). Check with `IF lo_obj IS BOUND.`
- Assigning one reference to another (`lo_b = lo_a.`) copies the **pointer**, not the object – both now point at the *same* object.
- `me` is the self-reference inside instance methods: `me->mv_name = iv_name.` (needed when a parameter has the same name as an attribute).
- When no reference points to an object any more, the **garbage collector** frees it. `CLEAR lo_obj.` or `FREE lo_obj.` releases your reference.

```abap
DATA(lo_a) = NEW lcl_counter( ).
DATA(lo_b) = lo_a.            " same object!
lo_b->hit( ).
" lo_a and lo_b both see mv_mine = 1
IF lo_a = lo_b.               " compares references (identity)
  WRITE / 'Same object'.
ENDIF.
```

## Global class in SE24 / ADT – step by step

1. ADT: right-click package → *New → ABAP Class* → name `ZCL_BANK_ACCOUNT`, description. (SE24: enter name → *Create* → *Usual ABAP class*, *Final* checkbox as needed.)
2. In ADT you write the full DEFINITION/IMPLEMENTATION in source code. In SE24 you use the form-based tabs **Attributes**, **Methods**, **Events**, **Types**, **Friends** – or switch to *Source Code-Based* mode.
3. Activate (**Ctrl+F3**). Test with **F8** (SE24 test environment) or by implementing `IF_OO_ADT_CLASSRUN` in ADT and pressing **F9**:

```abap
CLASS zcl_hello DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_hello IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    out->write( |Hello from ABAP Objects - { sy-uname }| ).
  ENDMETHOD.
ENDCLASS.
```

:::lab Lab 2 – Your first class
Create a local class `LCL_STUDENT` with private attributes name, list of grades (internal table of integers). Public methods: `constructor` (name), `add_grade` (one grade 0–100, ignore invalid values), `get_average` (functional, returns decfloat34), `get_max` (functional). Add a static attribute that counts how many students were created. Create three students in START-OF-SELECTION and print their averages.
:::

:::solution Lab 2
```abap
CLASS lcl_student DEFINITION.
  PUBLIC SECTION.
    TYPES tt_grades TYPE STANDARD TABLE OF i WITH EMPTY KEY.
    CLASS-DATA gv_created TYPE i READ-ONLY.
    METHODS constructor IMPORTING iv_name TYPE string.
    METHODS add_grade   IMPORTING iv_grade TYPE i.
    METHODS get_average RETURNING VALUE(rv_avg) TYPE decfloat34.
    METHODS get_max     RETURNING VALUE(rv_max) TYPE i.
    METHODS get_name    RETURNING VALUE(rv_name) TYPE string.
  PRIVATE SECTION.
    DATA mv_name   TYPE string.
    DATA mt_grades TYPE tt_grades.
ENDCLASS.

CLASS lcl_student IMPLEMENTATION.
  METHOD constructor.
    mv_name = iv_name.
    gv_created += 1.
  ENDMETHOD.
  METHOD add_grade.
    CHECK iv_grade BETWEEN 0 AND 100.
    APPEND iv_grade TO mt_grades.
  ENDMETHOD.
  METHOD get_average.
    CHECK mt_grades IS NOT INITIAL.
    rv_avg = REDUCE decfloat34( INIT s = 0 FOR g IN mt_grades NEXT s = s + g )
             / lines( mt_grades ).
  ENDMETHOD.
  METHOD get_max.
    LOOP AT mt_grades INTO DATA(lv_g).
      rv_max = nmax( val1 = rv_max val2 = lv_g ).
    ENDLOOP.
  ENDMETHOD.
  METHOD get_name.
    rv_name = mv_name.
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  DATA(lo_s1) = NEW lcl_student( 'Ali' ).
  lo_s1->add_grade( 90 ). lo_s1->add_grade( 70 ). lo_s1->add_grade( 150 ).
  WRITE: / lo_s1->get_name( ), lo_s1->get_average( ), lo_s1->get_max( ).
  WRITE: / 'Students created:', lcl_student=>gv_created.
```
:::

# 3. Constructors

A **constructor** is a special method called automatically when something is created. ABAP has two kinds.

| | Instance constructor | Static constructor |
|---|---|---|
| Name | `constructor` | `class_constructor` |
| Declared with | `METHODS constructor` | `CLASS-METHODS class_constructor` |
| Called | Once per object, on `NEW` / `CREATE OBJECT` | Once per class per internal session, before the first access to the class |
| Parameters | IMPORTING only (+ RAISING) | **No** parameters |
| Section | Public (or protected/private with CREATE PROTECTED/PRIVATE) | Public |
| Typical use | Initialise object state, validate input | Fill static buffers, read customizing once |

```abap
CLASS lcl_config DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS class_constructor.
    CLASS-DATA gt_plants TYPE STANDARD TABLE OF t001w WITH EMPTY KEY READ-ONLY.
    METHODS constructor IMPORTING iv_werks TYPE werks_d
                        RAISING   cx_abap_invalid_value.
  PRIVATE SECTION.
    DATA mv_werks TYPE werks_d.
ENDCLASS.

CLASS lcl_config IMPLEMENTATION.
  METHOD class_constructor.
    " runs only once - before first use of LCL_CONFIG
    SELECT * FROM t001w INTO TABLE @gt_plants UP TO 100 ROWS.
  ENDMETHOD.

  METHOD constructor.
    IF NOT line_exists( gt_plants[ werks = iv_werks ] ).
      RAISE EXCEPTION TYPE cx_abap_invalid_value.
    ENDIF.
    mv_werks = iv_werks.
  ENDMETHOD.
ENDCLASS.
```

## Constructor order with inheritance

When you create an object of a subclass:

1. Static constructors run first, **top-down** (superclass, then subclass) – only if they have not run yet in this session.
2. The subclass instance constructor runs; it **must** call `super->constructor( )` before accessing instance components (the compiler enforces this when the superclass has an explicit constructor).

:::warn Constructor gotchas
- If a constructor raises an exception, the object is **not** created and the reference stays initial (or keeps its old value).
- In the superclass constructor, calls to redefined methods run the **superclass** version (the subclass part is not ready yet).
- Exceptions from `class_constructor` cannot be caught – they cause a runtime error. Keep static constructors simple.
:::

:::lab Lab 3 – Constructor order
Create `LCL_PARENT` and `LCL_CHILD INHERITING FROM lcl_parent`, each with a static and an instance constructor that only `WRITE`s its name. Create two `LCL_CHILD` objects and predict the output before running.
:::

:::solution Lab 3
Output: `Parent static` → `Child static` → `Child instance (before super)` → `Parent instance` → `Child instance (after super)` → then for the second object only the three instance lines. Static constructors run once per internal session.
```abap
CLASS lcl_parent DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS class_constructor.
    METHODS constructor.
ENDCLASS.
CLASS lcl_parent IMPLEMENTATION.
  METHOD class_constructor. WRITE / 'Parent static'.   ENDMETHOD.
  METHOD constructor.       WRITE / 'Parent instance'. ENDMETHOD.
ENDCLASS.

CLASS lcl_child DEFINITION INHERITING FROM lcl_parent.
  PUBLIC SECTION.
    CLASS-METHODS class_constructor.
    METHODS constructor.
ENDCLASS.
CLASS lcl_child IMPLEMENTATION.
  METHOD class_constructor. WRITE / 'Child static'. ENDMETHOD.
  METHOD constructor.
    WRITE / 'Child instance (before super)'.
    super->constructor( ).
    WRITE / 'Child instance (after super)'.
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  DATA(lo1) = NEW lcl_child( ).
  DATA(lo2) = NEW lcl_child( ).
```
:::

# 4. Encapsulation

Encapsulation = **hide the data, expose behaviour**. Outsiders change an object's state only through methods that can validate the change.

```abap
CLASS lcl_employee DEFINITION.
  PUBLIC SECTION.
    METHODS set_salary IMPORTING iv_salary TYPE p
                       RAISING   cx_abap_invalid_value.
    METHODS get_salary RETURNING VALUE(rv_salary) TYPE decfloat34.
  PRIVATE SECTION.
    DATA mv_salary TYPE decfloat34.
ENDCLASS.

CLASS lcl_employee IMPLEMENTATION.
  METHOD set_salary.
    IF iv_salary < 0.
      RAISE EXCEPTION TYPE cx_abap_invalid_value.   " validation lives in one place
    ENDIF.
    mv_salary = iv_salary.
  ENDMETHOD.
  METHOD get_salary.
    rv_salary = mv_salary.
  ENDMETHOD.
ENDCLASS.
```

## Controlling instantiation: CREATE PUBLIC / PROTECTED / PRIVATE

| Addition | Who may create objects |
|---|---|
| `CREATE PUBLIC` (default) | Anyone |
| `CREATE PROTECTED` | The class itself and its subclasses |
| `CREATE PRIVATE` | Only the class itself (and friends) – used for **Singleton** and **Factory** patterns |

## FINAL and friendship

- `CLASS lcl_x DEFINITION FINAL.` – the class cannot be inherited from. `METHODS m FINAL.` – a method cannot be redefined.
- `CLASS lcl_x DEFINITION FRIENDS lcl_y.` – `LCL_Y` may access protected and private components of `LCL_X` and create its instances even if it is CREATE PRIVATE. Friendship is **one-way** (LCL_X does not get access to LCL_Y). Subclasses of the *friend* also become friends (so grant it carefully), but subclasses of LCL_X do **not** automatically grant friendship to LCL_Y. It is typically used for test classes (`FRIENDS ltc_test`) or tightly coupled helper classes.

:::tip Interview phrase
"Encapsulation is not about getters and setters for every attribute. It means the object owns its invariants: a bank account never lets its balance go negative, no matter who calls it."
:::

:::lab Lab 4 – Protect the invariant
Create `LCL_TEMPERATURE` that stores a temperature in Celsius privately. Provide `set_celsius` (reject values below -273.15 with an exception), `get_celsius`, `get_fahrenheit` (F = C × 9/5 + 32). Make the class FINAL and CREATE PRIVATE with a static factory `from_celsius( iv ) RETURNING VALUE(ro)`.
:::

:::solution Lab 4
```abap
CLASS lcl_temperature DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    CLASS-METHODS from_celsius IMPORTING iv_c       TYPE decfloat34
                               RETURNING VALUE(ro)   TYPE REF TO lcl_temperature
                               RAISING   cx_abap_invalid_value.
    METHODS set_celsius    IMPORTING iv_c TYPE decfloat34
                           RAISING   cx_abap_invalid_value.
    METHODS get_celsius    RETURNING VALUE(rv) TYPE decfloat34.
    METHODS get_fahrenheit RETURNING VALUE(rv) TYPE decfloat34.
  PRIVATE SECTION.
    CONSTANTS gc_abs_zero TYPE decfloat34 VALUE '-273.15'.
    DATA mv_c TYPE decfloat34.
ENDCLASS.

CLASS lcl_temperature IMPLEMENTATION.
  METHOD from_celsius.
    ro = NEW #( ).
    ro->set_celsius( iv_c ).
  ENDMETHOD.
  METHOD set_celsius.
    IF iv_c < gc_abs_zero.
      RAISE EXCEPTION TYPE cx_abap_invalid_value.
    ENDIF.
    mv_c = iv_c.
  ENDMETHOD.
  METHOD get_celsius.    rv = mv_c.                ENDMETHOD.
  METHOD get_fahrenheit. rv = mv_c * 9 / 5 + 32.   ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  TRY.
      DATA(lo_t) = lcl_temperature=>from_celsius( 25 ).
      WRITE: / lo_t->get_fahrenheit( ).            " 77
      lo_t->set_celsius( -300 ).                   " raises
    CATCH cx_abap_invalid_value.
      WRITE: / 'Invalid temperature rejected'.
  ENDTRY.
```
:::

# 5. Inheritance

A subclass **inherits all components** of its superclass (public and protected are accessible; private exist but cannot be accessed directly by the subclass). The subclass can **add** new components and **redefine** inherited instance methods. ABAP supports **single inheritance** only (one direct superclass); multiple "inheritance of behaviour contracts" is done with interfaces. The root of all classes is `OBJECT`.

```abap
CLASS lcl_vehicle DEFINITION.
  PUBLIC SECTION.
    METHODS constructor IMPORTING iv_plate TYPE string.
    METHODS describe RETURNING VALUE(rv) TYPE string.
    METHODS get_wheels RETURNING VALUE(rv) TYPE i.
  PROTECTED SECTION.
    DATA mv_plate TYPE string.
ENDCLASS.

CLASS lcl_vehicle IMPLEMENTATION.
  METHOD constructor.
    mv_plate = iv_plate.
  ENDMETHOD.
  METHOD describe.
    rv = |Vehicle { mv_plate } with { get_wheels( ) } wheels|.
  ENDMETHOD.
  METHOD get_wheels.
    rv = 4.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_truck DEFINITION INHERITING FROM lcl_vehicle.
  PUBLIC SECTION.
    METHODS constructor IMPORTING iv_plate TYPE string
                                  iv_load  TYPE i.
    METHODS describe   REDEFINITION.
    METHODS get_wheels REDEFINITION.
  PRIVATE SECTION.
    DATA mv_load TYPE i.
ENDCLASS.

CLASS lcl_truck IMPLEMENTATION.
  METHOD constructor.
    super->constructor( iv_plate ).     " mandatory, first
    mv_load = iv_load.
  ENDMETHOD.
  METHOD describe.
    " reuse the superclass logic and extend it
    rv = super->describe( ) && | and load { mv_load } t|.
  ENDMETHOD.
  METHOD get_wheels.
    rv = 18.
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  DATA(lo_truck) = NEW lcl_truck( iv_plate = 'CAI-123' iv_load = 20 ).
  WRITE / lo_truck->describe( ).
  " -> Vehicle CAI-123 with 18 wheels and load 20 t
```

:::note Dynamic binding inside the superclass
`describe( )` in `LCL_VEHICLE` calls `get_wheels( )`. Because the object is a truck, the **redefined** `get_wheels` of `LCL_TRUCK` runs – even though the call is written in the superclass. This is polymorphism at work (also called *late binding*).
:::

## Rules of redefinition

- Only **instance** methods can be redefined (not static methods, not constructors – a subclass declares its *own* constructor).
- The signature cannot change – you only write `METHODS name REDEFINITION.`
- The visibility stays as in the superclass. You cannot redefine private methods.
- `FINAL` methods/classes cannot be redefined/inherited.
- `super->method( )` calls the superclass implementation.

## Abstract classes and methods

An **abstract class** cannot be instantiated; it exists to be inherited. An **abstract method** has no implementation in the abstract class; every concrete subclass must implement it.

```abap
CLASS lcl_shape DEFINITION ABSTRACT.
  PUBLIC SECTION.
    METHODS area     ABSTRACT RETURNING VALUE(rv) TYPE decfloat34.
    METHODS describe RETURNING VALUE(rv) TYPE string.     " concrete method
ENDCLASS.

CLASS lcl_shape IMPLEMENTATION.
  METHOD describe.
    rv = |{ cl_abap_classdescr=>get_class_name( me ) } has area { area( ) }|.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_circle DEFINITION INHERITING FROM lcl_shape.
  PUBLIC SECTION.
    METHODS constructor IMPORTING iv_r TYPE decfloat34.
    METHODS area REDEFINITION.
  PRIVATE SECTION.
    DATA mv_r TYPE decfloat34.
ENDCLASS.

CLASS lcl_circle IMPLEMENTATION.
  METHOD constructor.
    super->constructor( ).
    mv_r = iv_r.
  ENDMETHOD.
  METHOD area.
    rv = '3.14159' * mv_r * mv_r.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_rect DEFINITION INHERITING FROM lcl_shape.
  PUBLIC SECTION.
    METHODS constructor IMPORTING iv_w TYPE decfloat34 iv_h TYPE decfloat34.
    METHODS area REDEFINITION.
  PRIVATE SECTION.
    DATA: mv_w TYPE decfloat34, mv_h TYPE decfloat34.
ENDCLASS.

CLASS lcl_rect IMPLEMENTATION.
  METHOD constructor.
    super->constructor( ).
    mv_w = iv_w. mv_h = iv_h.
  ENDMETHOD.
  METHOD area.
    rv = mv_w * mv_h.
  ENDMETHOD.
ENDCLASS.
```

## Abstract class vs. interface (classic interview question)

| Abstract class | Interface |
|---|---|
| Can contain implemented methods **and** abstract ones | Only declarations (no implementation) – except DEFAULT behaviour in newer releases |
| Can have instance attributes with state, constructors | Attributes are possible but discouraged; no constructor |
| A class inherits from **one** abstract class | A class can implement **many** interfaces |
| Models an "is-a" relationship with shared code | Models a "can-do" capability / contract |
| Has visibility sections | All components are public |

:::lab Lab 5 – Employee hierarchy
Build abstract `LCL_EMPLOYEE` (name, abstract method `calculate_salary`, concrete method `print_payslip` that writes name + salary). Subclasses: `LCL_FULLTIME` (monthly salary), `LCL_CONTRACTOR` (hours × rate), `LCL_MANAGER` inheriting from `LCL_FULLTIME` adding a bonus (redefine `calculate_salary` and use `super->`). Put all employees in one internal table of `REF TO lcl_employee` and loop to print payslips.
:::

:::solution Lab 5
```abap
CLASS lcl_employee DEFINITION ABSTRACT.
  PUBLIC SECTION.
    METHODS constructor IMPORTING iv_name TYPE string.
    METHODS calculate_salary ABSTRACT RETURNING VALUE(rv) TYPE decfloat34.
    METHODS print_payslip.
  PROTECTED SECTION.
    DATA mv_name TYPE string.
ENDCLASS.
CLASS lcl_employee IMPLEMENTATION.
  METHOD constructor. mv_name = iv_name. ENDMETHOD.
  METHOD print_payslip.
    WRITE: / mv_name, calculate_salary( ).
  ENDMETHOD.
ENDCLASS.

CLASS lcl_fulltime DEFINITION INHERITING FROM lcl_employee.
  PUBLIC SECTION.
    METHODS constructor IMPORTING iv_name TYPE string iv_monthly TYPE decfloat34.
    METHODS calculate_salary REDEFINITION.
  PROTECTED SECTION.
    DATA mv_monthly TYPE decfloat34.
ENDCLASS.
CLASS lcl_fulltime IMPLEMENTATION.
  METHOD constructor.
    super->constructor( iv_name ).
    mv_monthly = iv_monthly.
  ENDMETHOD.
  METHOD calculate_salary. rv = mv_monthly. ENDMETHOD.
ENDCLASS.

CLASS lcl_contractor DEFINITION INHERITING FROM lcl_employee.
  PUBLIC SECTION.
    METHODS constructor IMPORTING iv_name TYPE string
                                  iv_hours TYPE i iv_rate TYPE decfloat34.
    METHODS calculate_salary REDEFINITION.
  PRIVATE SECTION.
    DATA: mv_hours TYPE i, mv_rate TYPE decfloat34.
ENDCLASS.
CLASS lcl_contractor IMPLEMENTATION.
  METHOD constructor.
    super->constructor( iv_name ).
    mv_hours = iv_hours. mv_rate = iv_rate.
  ENDMETHOD.
  METHOD calculate_salary. rv = mv_hours * mv_rate. ENDMETHOD.
ENDCLASS.

CLASS lcl_manager DEFINITION INHERITING FROM lcl_fulltime.
  PUBLIC SECTION.
    METHODS constructor IMPORTING iv_name TYPE string
                                  iv_monthly TYPE decfloat34 iv_bonus TYPE decfloat34.
    METHODS calculate_salary REDEFINITION.
  PRIVATE SECTION.
    DATA mv_bonus TYPE decfloat34.
ENDCLASS.
CLASS lcl_manager IMPLEMENTATION.
  METHOD constructor.
    super->constructor( iv_name = iv_name iv_monthly = iv_monthly ).
    mv_bonus = iv_bonus.
  ENDMETHOD.
  METHOD calculate_salary.
    rv = super->calculate_salary( ) + mv_bonus.
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  DATA lt_staff TYPE STANDARD TABLE OF REF TO lcl_employee WITH EMPTY KEY.
  lt_staff = VALUE #( ( NEW lcl_fulltime( iv_name = 'Ali'  iv_monthly = 10000 ) )
                      ( NEW lcl_contractor( iv_name = 'Sara' iv_hours = 120 iv_rate = 150 ) )
                      ( NEW lcl_manager( iv_name = 'Omar' iv_monthly = 20000 iv_bonus = 5000 ) ) ).
  LOOP AT lt_staff INTO DATA(lo_emp).
    lo_emp->print_payslip( ).      " polymorphic call
  ENDLOOP.
```
:::

# 6. Polymorphism and Casting

**Polymorphism** means a reference of a general type (superclass or interface) can point to objects of many specific types, and a method call is dispatched to the implementation of the **actual (dynamic) type** at runtime.

- **Static type** – the type used in the declaration: `DATA lo_shape TYPE REF TO lcl_shape.`
- **Dynamic type** – the class of the object the reference points to at runtime (e.g. `LCL_CIRCLE`).

## Up-cast (narrowing cast) – always safe

Assign a subclass reference to a superclass (or interface) reference. Allowed with a normal `=`; checked at compile time.

```abap
DATA lo_shape  TYPE REF TO lcl_shape.
DATA lo_circle TYPE REF TO lcl_circle.

lo_circle = NEW #( iv_r = 2 ).
lo_shape  = lo_circle.             " up-cast: OK
WRITE / lo_shape->area( ).         " runs LCL_CIRCLE->AREA (dynamic binding)
```

## Down-cast (widening cast) – checked at runtime

Assign a general reference to a more specific one. You must use `?=` or `CAST #( )`. If the object is not of that type, the exception `CX_SY_MOVE_CAST_ERROR` is raised.

```abap
TRY.
    lo_circle ?= lo_shape.                    " classic syntax
    lo_circle = CAST lcl_circle( lo_shape ).  " modern syntax (7.40+)
  CATCH cx_sy_move_cast_error.
    WRITE / 'Not a circle'.
ENDTRY.

" Safer: test first (7.50+)
IF lo_shape IS INSTANCE OF lcl_circle.
  lo_circle = CAST #( lo_shape ).
ENDIF.

" Branch by type (7.50+)
CASE TYPE OF lo_shape.
  WHEN TYPE lcl_circle INTO DATA(lo_c).
    WRITE / 'Circle'.
  WHEN TYPE lcl_rect INTO DATA(lo_r).
    WRITE / 'Rectangle'.
  WHEN OTHERS.
    WRITE / 'Unknown shape'.
ENDCASE.
```

:::warn The naming trap
SAP documentation calls the up-cast a **narrowing cast** and the down-cast a **widening cast** (named after what happens to the set of components you can reach through the reference). In interviews, say "up-cast (narrowing, implicit, always safe)" and "down-cast (widening, explicit with `?=`/`CAST`, can raise `CX_SY_MOVE_CAST_ERROR`)" – then you are right either way.
:::

## Why polymorphism matters – the "no IF/CASE on type" rule

Bad (procedural thinking):

```abap
CASE lv_shape_type.
  WHEN 'C'. lv_area = '3.14' * lv_r * lv_r.
  WHEN 'R'. lv_area = lv_w * lv_h.
  " every new shape = change this code (violates Open/Closed principle)
ENDCASE.
```

Good (OO thinking): every shape knows its own area – adding `LCL_TRIANGLE` needs **no change** to existing code.

```abap
LOOP AT lt_shapes INTO DATA(lo_shape).
  lv_total = lv_total + lo_shape->area( ).
ENDLOOP.
```

:::lab Lab 6 – Payment methods
Abstract class `LCL_PAYMENT` with abstract method `pay( iv_amount ) RETURNING VALUE(rv_msg)`. Subclasses `LCL_CASH`, `LCL_CARD` (adds 2 % fee), `LCL_WALLET` (has an extra public method `get_cashback( )` returning 1 % of the last amount). Loop over a table of payments, call `pay( 1000 )` for each, and – only for wallets – also print the cashback using a down-cast.
:::

:::solution Lab 6
```abap
CLASS lcl_payment DEFINITION ABSTRACT.
  PUBLIC SECTION.
    METHODS pay ABSTRACT IMPORTING iv_amount TYPE decfloat34
                         RETURNING VALUE(rv_msg) TYPE string.
ENDCLASS.

CLASS lcl_cash DEFINITION INHERITING FROM lcl_payment.
  PUBLIC SECTION. METHODS pay REDEFINITION.
ENDCLASS.
CLASS lcl_cash IMPLEMENTATION.
  METHOD pay. rv_msg = |Cash paid: { iv_amount }|. ENDMETHOD.
ENDCLASS.

CLASS lcl_card DEFINITION INHERITING FROM lcl_payment.
  PUBLIC SECTION. METHODS pay REDEFINITION.
ENDCLASS.
CLASS lcl_card IMPLEMENTATION.
  METHOD pay. rv_msg = |Card charged: { iv_amount * '1.02' }|. ENDMETHOD.
ENDCLASS.

CLASS lcl_wallet DEFINITION INHERITING FROM lcl_payment.
  PUBLIC SECTION.
    METHODS pay REDEFINITION.
    METHODS get_cashback RETURNING VALUE(rv) TYPE decfloat34.
  PRIVATE SECTION.
    DATA mv_last TYPE decfloat34.
ENDCLASS.
CLASS lcl_wallet IMPLEMENTATION.
  METHOD pay.
    mv_last = iv_amount.
    rv_msg = |Wallet paid: { iv_amount }|.
  ENDMETHOD.
  METHOD get_cashback. rv = mv_last / 100. ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  DATA lt_pay TYPE STANDARD TABLE OF REF TO lcl_payment WITH EMPTY KEY.
  lt_pay = VALUE #( ( NEW lcl_cash( ) ) ( NEW lcl_card( ) ) ( NEW lcl_wallet( ) ) ).
  LOOP AT lt_pay INTO DATA(lo_pay).
    WRITE / lo_pay->pay( 1000 ).
    IF lo_pay IS INSTANCE OF lcl_wallet.
      WRITE: / '  cashback:', CAST lcl_wallet( lo_pay )->get_cashback( ).
    ENDIF.
  ENDLOOP.
```
:::
