"""Storyboard for the 'OO ABAP explained' video.

Each scene is an HTML body; elements with class="s<N>" appear from step N on.
Each step has narration text ("say"), spoken while that step is on screen.
"""

SCENES = [
    {
        "html": """
<div class="title-wrap">
  <div class="kicker s0">SAP ABAP DEVELOPMENT</div>
  <h1 class="big s0">Object-Oriented ABAP</h1>
  <div class="sub s0">The core ideas in a few minutes</div>
  <div class="chips s1">
    <span>Classes</span><span>Objects</span><span>Encapsulation</span><span>Inheritance</span>
    <span>Polymorphism</span><span>Interfaces</span><span>Events</span><span>Exceptions</span>
  </div>
</div>""",
        "dark": True,
        "steps": [
            "Welcome! In this short video you will learn object oriented ABAP, also called ABAP Objects.",
            "We will cover classes and objects, encapsulation, inheritance, polymorphism, interfaces, events and exceptions, with real ABAP code.",
        ],
    },
    {
        "html": """
<h2>Why object-oriented ABAP?</h2>
<div class="cols">
  <div class="card s0"><h3>Procedural ABAP</h3>
    <ul><li>Reports, FORM routines, function modules</li><li>Global data shared by everything</li>
    <li>Hard to extend and to test</li></ul></div>
  <div class="card accent s1"><h3>ABAP Objects</h3>
    <ul><li>Data and logic live together in objects</li><li>Reuse through inheritance and interfaces</li>
    <li>Easy to extend, easy to unit test</li></ul></div>
</div>
<div class="banner s2">BAdIs · SALV · OData DPC classes · RAP · ABAP Unit — all built on OO</div>""",
        "steps": [
            "Classic ABAP is procedural: reports, form routines and function modules that share global data. That gets hard to extend and hard to test.",
            "ABAP Objects keeps data and the logic that works on it together, inside objects. You reuse code through inheritance and interfaces, and you can test each piece on its own.",
            "And it is not optional: BAdIs, ALV, OData services and the RAP model are all object oriented.",
        ],
    },
    {
        "html": """
<h2>Class vs. object</h2>
<div class="cols">
  <div class="blueprint s0"><div class="tag">CLASS = blueprint</div>
    <pre class="code">CLASS lcl_car DEFINITION.
  PUBLIC SECTION.
    DATA mv_color TYPE string.
    METHODS drive.
ENDCLASS.</pre></div>
  <div class="objects s1"><div class="tag">OBJECTS = instances</div>
    <div class="objrow"><div class="obj">lo_car1<br><b>color = red</b></div>
    <div class="obj">lo_car2<br><b>color = blue</b></div></div>
    <pre class="code small">DATA(lo_car1) = NEW lcl_car( ).
DATA(lo_car2) = NEW lcl_car( ).</pre></div>
</div>""",
        "steps": [
            "A class is the blueprint. It defines attributes, which hold data, and methods, which define behaviour.",
            "An object is a real instance of that class, created at runtime with the NEW operator. Each object has its own values: one car is red, the other is blue, but both come from the same class.",
        ],
    },
    {
        "html": """
<h2>Definition and implementation</h2>
<pre class="code wide s0">CLASS lcl_account DEFINITION.
  PUBLIC SECTION.                          <span class="hl s1">" API: everyone can call</span>
    METHODS deposit     IMPORTING iv_amount TYPE p.
    METHODS get_balance RETURNING VALUE(rv) TYPE decfloat34.
  PRIVATE SECTION.                         <span class="hl s1">" hidden state</span>
    DATA mv_balance TYPE decfloat34.
ENDCLASS.

CLASS lcl_account IMPLEMENTATION.
  METHOD deposit.
    mv_balance = mv_balance + iv_amount.
  ENDMETHOD.
  METHOD get_balance.
    rv = mv_balance.
  ENDMETHOD.
ENDCLASS.</pre>
<div class="banner tight s2">-&gt; for instance members &nbsp;·&nbsp; =&gt; for static members &nbsp;·&nbsp; lo_acc-&gt;deposit( 500 ).</div>""",
        "steps": [
            "Every ABAP class has two parts. The definition declares what the class has. The implementation contains the code of each method.",
            "The public section is the interface others may use. The private section hides the internal state. Nobody outside can change the balance directly. That is encapsulation.",
            "You call instance methods with the arrow, and static members, which belong to the class itself, with the fat arrow.",
        ],
    },
    {
        "html": """
<h2>Constructors</h2>
<div class="cols">
  <pre class="code s0">METHODS constructor
  IMPORTING iv_owner TYPE string.

METHOD constructor.
  mv_owner = iv_owner.
ENDMETHOD.

DATA(lo_acc) = NEW lcl_account( 'Hassan' ).</pre>
  <div class="stack">
    <div class="card s0"><h3>constructor</h3><p>Runs once for every new object.<br>Initialises its state.</p></div>
    <div class="card accent s1"><h3>class_constructor</h3><p>Runs once per class, before first use.<br>No parameters.</p></div>
  </div>
</div>""",
        "steps": [
            "A constructor is a special method that runs automatically when an object is created. Use it to give every object a valid starting state.",
            "There is also a static constructor, called class constructor. It runs only once per class, before the class is first used, and is handy for reading configuration.",
        ],
    },
    {
        "html": """
<h2>Inheritance</h2>
<div class="tree s0">
  <div class="node top">lcl_vehicle<br><small>describe( ) · get_wheels( )</small></div>
  <div class="branches"><div class="node">lcl_car</div><div class="node accentnode">lcl_truck<br><small>REDEFINITION</small></div></div>
</div>
<pre class="code wide s1">CLASS lcl_truck DEFINITION INHERITING FROM lcl_vehicle.
  PUBLIC SECTION.
    METHODS get_wheels REDEFINITION.
ENDCLASS.

METHOD get_wheels.
  rv = 18.            <span class="hl">" super-&gt;get_wheels( ) would call the parent version</span>
ENDMETHOD.</pre>""",
        "steps": [
            "Inheritance lets a subclass reuse everything from its superclass. A car and a truck both inherit from vehicle.",
            "The subclass can redefine a method to change its behaviour, and still call the parent version with super. ABAP supports single inheritance: one direct superclass per class.",
        ],
    },
    {
        "html": """
<h2>Polymorphism</h2>
<pre class="code wide s0">DATA lt_shapes TYPE STANDARD TABLE OF REF TO lcl_shape WITH EMPTY KEY.
lt_shapes = VALUE #( ( NEW lcl_circle( 2 ) ) ( NEW lcl_square( 3 ) ) ).

LOOP AT lt_shapes INTO DATA(lo_shape).
  lv_total = lv_total + lo_shape-&gt;area( ).   <span class="hl">" circle or square? decided at runtime</span>
ENDLOOP.</pre>
<div class="cols s1">
  <div class="card"><h3>Up-cast</h3><p>lo_shape = lo_circle.<br>Implicit and always safe.</p></div>
  <div class="card accent"><h3>Down-cast</h3><p>lo_circle ?= lo_shape.<br>Checked at runtime (CX_SY_MOVE_CAST_ERROR).</p></div>
</div>""",
        "steps": [
            "Polymorphism means one call, many behaviours. We keep circles and squares in one table of shape references and simply call area. Each object runs its own version, decided at runtime. No case statement on the type is needed.",
            "Assigning a subclass to a superclass reference is an up-cast, and it is always safe. Going the other way is a down-cast, written with question mark equals, and it is checked at runtime.",
        ],
    },
    {
        "html": """
<h2>Interfaces</h2>
<div class="cols">
  <pre class="code s0">INTERFACE lif_notifier.
  METHODS send IMPORTING iv_text TYPE string.
ENDINTERFACE.

CLASS lcl_email DEFINITION.
  PUBLIC SECTION.
    INTERFACES lif_notifier.
ENDCLASS.</pre>
  <div class="stack s1">
    <div class="card"><h3>A contract</h3><p>Only method signatures — every implementing class decides how.</p></div>
    <div class="card accent"><h3>Loose coupling</h3><p>Code depends on REF TO lif_notifier, so e-mail, SMS or a test fake can be swapped in.</p></div>
  </div>
</div>""",
        "steps": [
            "An interface is a pure contract: a list of methods without implementation. A class that implements it promises to provide all those methods. A class can implement many interfaces.",
            "Because your code only depends on the interface, you can swap the real e-mail sender for an SMS sender, or for a fake object in a unit test. This is the basis of BAdIs and testable code.",
        ],
    },
    {
        "html": """
<h2>Events in four steps</h2>
<div class="steps4">
  <div class="card s0"><div class="num">1</div><h3>Declare</h3><p>EVENTS low_stock.</p></div>
  <div class="card s0"><div class="num">2</div><h3>Raise</h3><p>RAISE EVENT low_stock.</p></div>
  <div class="card s1"><div class="num">3</div><h3>Handle</h3><p>METHODS on_low FOR EVENT low_stock OF lcl_stock.</p></div>
  <div class="card s1"><div class="num">4</div><h3>Register</h3><p>SET HANDLER lo_h-&gt;on_low FOR lo_stock.</p></div>
</div>
<div class="banner s2">Used every day in ALV: double_click, toolbar, user_command</div>""",
        "steps": [
            "Events let an object announce that something happened, without knowing who is listening. First you declare the event, then you raise it in a method.",
            "Another class defines a handler method for that event, and registers it at runtime with SET HANDLER.",
            "You will use this all the time with ALV grids, for example to react to a double click.",
        ],
    },
    {
        "html": """
<h2>Class-based exceptions</h2>
<div class="cols">
  <pre class="code s0">TRY.
    lo_repo-&gt;get_order( lv_id ).
  CATCH zcx_order_error INTO DATA(lx).
    MESSAGE lx TYPE 'I'.
  CLEANUP.
    " restore state if it propagates
ENDTRY.</pre>
  <div class="stack s1">
    <div class="card"><h3>CX_STATIC_CHECK</h3><p>Expected business errors — must be handled or declared.</p></div>
    <div class="card"><h3>CX_DYNAMIC_CHECK</h3><p>Errors the caller can prevent, like dividing by zero.</p></div>
    <div class="card accent"><h3>CX_NO_CHECK</h3><p>Fatal problems that can happen anywhere.</p></div>
  </div>
</div>""",
        "steps": [
            "Modern ABAP handles errors with exception classes. You wrap the call in try, catch the exception object, and read its text.",
            "There are three families: static check for expected business errors, dynamic check for errors the caller can prevent, and no check for fatal problems.",
        ],
    },
    {
        "html": """
<div class="title-wrap">
  <h1 class="big s0" style="font-size:90px">Recap</h1>
  <div class="recap s0">
    <div><b>Class</b> blueprint · <b>Object</b> instance</div>
    <div><b>Encapsulation</b> private data, public methods</div>
    <div><b>Inheritance</b> reuse + REDEFINITION</div>
    <div><b>Polymorphism</b> one call, many behaviours</div>
    <div><b>Interfaces</b> contracts, loose coupling</div>
    <div><b>Events &amp; exceptions</b> communicate and fail safely</div>
  </div>
  <div class="sub s1">Next: practise with the labs in the study guide</div>
</div>""",
        "dark": True,
        "cls": "nocircle",
        "steps": [
            "To recap: a class is the blueprint and an object is the instance. Encapsulation protects data. Inheritance reuses code. Polymorphism gives one call many behaviours. Interfaces define contracts. Events and exceptions let objects communicate and fail safely.",
            "Now open the study guide and practise every concept with the labs. Thanks for watching!",
        ],
    },
]
