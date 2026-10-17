// Builds the summary deck: ABAP Objects & OData (structured deck, pptxgenjs).
// Usage: NODE_PATH=<dir with pptxgenjs> node build_pptx.js <out.pptx> <apply_theme.js path>
const pptxgen = require("pptxgenjs");
const { applyTheme } = require(process.argv[3]);
const OUT = process.argv[2];

const THEME = {
  name: "SAP Study",
  headFontFace: "Cambria",
  bodyFontFace: "Calibri",
  colors: {
    dk1: "1B2430", lt1: "FFFFFF", dk2: "0A2540", lt2: "EEF2F7",
    accent1: "0B5394", accent2: "F0AB00", accent3: "1E7B3A",
    accent4: "B4540A", accent5: "5B3FA3", accent6: "5F6B7A",
    hlink: "0B5394", folHlink: "5B3FA3",
  },
};

const pres = new pptxgen();
pres.layout = "LAYOUT_WIDE"; // 13.33 x 7.5
pres.title = "ABAP Objects & OData - Summary";
pres.author = "SAP Study Session";
pres.theme = { headFontFace: THEME.headFontFace, bodyFontFace: THEME.bodyFontFace };
const C = pres.SchemeColor;
const W = 13.333;
const MONO = "Courier New";

// ---------- layouts ----------
pres.defineSlideMaster({
  title: "TITLE_DARK",
  background: { color: C.text2 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.8, y: 2.3, w: 9.5, h: 1.8,
      fontSize: 48, bold: true, color: C.background1, valign: "bottom", margin: 0 }, text: "" } },
    { placeholder: { options: { name: "body", type: "body", x: 0.8, y: 4.3, w: 9.5, h: 1.2,
      fontSize: 20, color: C.background2, valign: "top", margin: 0 }, text: "" } },
  ],
});
pres.defineSlideMaster({
  title: "SECTION_DARK",
  background: { color: C.text2 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 2.3, y: 2.6, w: 10, h: 1.3,
      fontSize: 40, bold: true, color: C.background1, valign: "middle", margin: 0 }, text: "" } },
    { placeholder: { options: { name: "body", type: "body", x: 2.3, y: 3.9, w: 10, h: 1.2,
      fontSize: 18, color: C.background2, valign: "top", margin: 0 }, text: "" } },
  ],
  slideNumber: { x: 12.4, y: 6.95, w: 0.6, h: 0.3, fontSize: 10, color: C.background2 },
});
pres.defineSlideMaster({
  title: "CONTENT",
  background: { color: C.background1 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.6, y: 0.35, w: 12.1, h: 0.85,
      fontSize: 32, bold: true, color: C.text2, valign: "middle", margin: 0 }, text: "" } },
    { text: { text: "ABAP Objects & OData — Summary", options: { x: 0.6, y: 6.95, w: 6, h: 0.3,
      fontSize: 10, color: C.accent6, margin: 0 } } },
  ],
  slideNumber: { x: 12.4, y: 6.95, w: 0.6, h: 0.3, fontSize: 10, color: C.accent6 },
});

// ---------- helpers ----------
let n = 0;
const oname = (p) => `${p}_${++n}`;

function content(title, section) {
  const s = pres.addSlide({ masterName: "CONTENT", sectionTitle: section });
  s.addText(title, { placeholder: "title" });
  return s;
}

function badge(s, x, y, label, color, d = 0.5) {
  s.addShape(pres.shapes.OVAL, { x, y, w: d, h: d, fill: { color }, line: { color },
    objectName: oname("badge") });
  s.addText(label, { x, y, w: d, h: d, fontSize: d > 0.45 ? 16 : 12, bold: true,
    color: C.background1, align: "center", valign: "middle", margin: 0, isTextBox: true,
    objectName: oname("badgeText") });
}

// card: tinted rounded box with badge, heading and body text
function card(s, x, y, w, h, head, body, color, label) {
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w, h, rectRadius: 0.08,
    fill: { color: C.background2 }, line: { color: C.background2 }, objectName: oname("card") });
  let tx = x + 0.2;
  if (label) { badge(s, x + 0.2, y + 0.2, label, color, 0.45); tx = x + 0.8; }
  s.addText(head, { x: tx, y: y + 0.18, w: x + w - tx - 0.15, h: 0.5, fontSize: 17, bold: true,
    color: C.text2, valign: "middle", margin: 0, isTextBox: true, objectName: oname("cardHead") });
  s.addText(body, { x: x + 0.2, y: y + 0.78, w: w - 0.4, h: h - 0.9, fontSize: 15,
    color: C.text1, valign: "top", margin: 0, isTextBox: true, paraSpaceAfter: 4,
    objectName: oname("cardBody") });
}

function code(s, x, y, w, h, text, fontSize = 12) {
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w, h, rectRadius: 0.06,
    fill: { color: C.text2 }, line: { color: C.text2 }, objectName: oname("codeBg") });
  s.addText(text, { x: x + 0.2, y: y + 0.12, w: w - 0.4, h: h - 0.24, fontFace: MONO,
    fontSize, color: C.background1, valign: "top", margin: 0, isTextBox: true,
    objectName: oname("code") });
}

function bullets(s, x, y, w, h, items, fontSize = 15) {
  s.addText(items.map((t, i) => {
    const runs = typeof t === "string" ? { text: t } : t;
    return { text: runs.text, options: { bullet: true, bold: runs.bold, breakLine: i < items.length - 1 } };
  }), { x, y, w, h, fontSize, color: C.text1, valign: "top", paraSpaceAfter: 7, margin: 0,
    isTextBox: true, objectName: oname("bullets") });
}

function table(s, x, y, w, rows, colW, fontSize = 13) {
  const data = rows.map((r, i) => r.map((c) => ({
    text: c,
    options: i === 0
      ? { bold: true, color: C.background1, fill: { color: C.accent1 } }
      : { color: C.text1, fill: { color: i % 2 === 0 ? C.background2 : C.background1 } },
  })));
  s.addTable(data, { x, y, w, colW, fontSize, border: { type: "solid", pt: 0.5, color: "D5DCE5" },
    margin: [0.05, 0.1, 0.05, 0.1], valign: "middle", objectName: oname("table") });
}

function note(s, x, y, w, h, text, color = C.accent2) {
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w, h, rectRadius: 0.08,
    fill: { color, transparency: 85 }, line: { color, width: 1 }, objectName: oname("noteBg") });
  s.addText(text, { x: x + 0.2, y, w: w - 0.4, h, fontSize: 14, color: C.text1,
    valign: "middle", margin: 0, isTextBox: true, objectName: oname("note") });
}

function section(title, sub, num) {
  pres.addSection({ title });
  const s = pres.addSlide({ masterName: "SECTION_DARK", sectionTitle: title });
  s.addShape(pres.shapes.OVAL, { x: 0.8, y: 2.75, w: 1.0, h: 1.0, fill: { color: C.accent2 },
    line: { color: C.accent2 }, objectName: oname("sectionBadge") });
  s.addText(num, { x: 0.8, y: 2.75, w: 1.0, h: 1.0, fontSize: 30, bold: true, color: C.text2,
    align: "center", valign: "middle", margin: 0, isTextBox: true, objectName: oname("sectionNum") });
  s.addText(title, { placeholder: "title" });
  s.addText(sub, { placeholder: "body" });
  return title;
}

// =====================================================================
// Title
pres.addSection({ title: "Introduction" });
let s = pres.addSlide({ masterName: "TITLE_DARK", sectionTitle: "Introduction" });
s.addShape(pres.shapes.OVAL, { x: 9.6, y: -1.6, w: 5.6, h: 5.6, fill: { color: C.accent1 },
  line: { color: C.accent1 }, objectName: "decoCircle" });
s.addShape(pres.shapes.OVAL, { x: 10.3, y: 4.2, w: 1.3, h: 1.3, fill: { color: C.accent2 },
  line: { color: C.accent2 }, objectName: "decoDot" });
s.addText("ABAP Objects & OData", { placeholder: "title" });
s.addText("Summary deck — from beginner to advanced: concepts, code, practice and interview prep",
  { placeholder: "body" });
s.addNotes("Companion summary of the detailed PDF study guide. Each slide maps to a chapter in the PDF.");

// Agenda
s = content("Roadmap: four parts, six weeks", "Introduction");
const parts = [
  ["1", "ABAP Objects", "Classes, inheritance, interfaces, events, exceptions, patterns, unit tests", C.accent1],
  ["2", "OData & Gateway", "REST, EDM, SEGW, CRUD, query options, $expand, deep insert, $batch", C.accent3],
  ["3", "CDS & RAP", "CDS-based services, RAP layers, EML, OData V4", C.accent5],
  ["4", "Interview & practice", "Top questions, labs per concept, capstone project", C.accent4],
];
parts.forEach((p, i) => card(s, 0.6 + i * 3.08, 1.55, 2.88, 3.2, p[1], p[2], p[3], p[0]));
note(s, 0.6, 5.2, 12.1, 1.2,
  "Rhythm for every topic: Concept → Syntax & example → Watch-outs → Practical lab with solution. The PDF holds the full detail; this deck is your revision sheet.");

// =====================================================================
let SEC = section("ABAP Objects", "Classes · Inheritance · Polymorphism · Interfaces · Events · Exceptions · Patterns · Unit tests", "1");

// Why OO
s = content("Why OO ABAP? The four pillars", SEC);
[["E", "Encapsulation", "Objects hide their data; changes go through methods that protect the rules."],
 ["A", "Abstraction", "Use what an object does, not how: lo_printer->print( )."],
 ["I", "Inheritance", "A subclass reuses and specialises its superclass (ZCL_TRUCK → ZCL_VEHICLE)."],
 ["P", "Polymorphism", "One call, many behaviours – resolved at runtime by the real object type."]]
  .forEach((p, i) => card(s, 0.6 + (i % 2) * 4.0, 1.5 + Math.floor(i / 2) * 2.45, 3.8, 2.25, p[1], p[2], C.accent1, p[0]));
s.addText("Everything new in SAP is OO", { x: 8.9, y: 1.5, w: 3.8, h: 0.5, fontSize: 18, bold: true,
  color: C.text2, margin: 0, isTextBox: true, objectName: "whyHead" });
bullets(s, 8.9, 2.1, 3.8, 4.3, ["BAdIs and enhancement spots", "SALV / ALV grid events",
  "Gateway DPC & MPC classes", "RAP behavior pools", "AMDP, Workflow, ABAP Unit"]);

// Class anatomy
s = content("Anatomy of a class", SEC);
code(s, 0.6, 1.45, 7.4, 5.25,
`CLASS lcl_account DEFINITION.
  PUBLIC SECTION.
    METHODS constructor IMPORTING iv_owner TYPE string.
    METHODS deposit IMPORTING iv_amount TYPE p.
    METHODS get_balance
      RETURNING VALUE(rv) TYPE decfloat34.
    CLASS-DATA gv_count TYPE i READ-ONLY.
  PRIVATE SECTION.
    DATA mv_balance TYPE decfloat34.
ENDCLASS.

CLASS lcl_account IMPLEMENTATION.
  METHOD deposit.
    mv_balance += iv_amount.
  ENDMETHOD.
  ...
ENDCLASS.

DATA(lo) = NEW lcl_account( 'Hassan' ).
lo->deposit( 500 ).          " instance: ->
WRITE lcl_account=>gv_count. " static:   =>`, 12);
table(s, 8.3, 1.45, 4.4, [
  ["Section", "Visible to"],
  ["PUBLIC", "Everyone"],
  ["PROTECTED", "Class + subclasses"],
  ["PRIVATE", "Class (+ friends)"],
], [1.6, 2.8], 13);
bullets(s, 8.3, 3.55, 4.4, 3.1, [
  "Order is fixed: PUBLIC → PROTECTED → PRIVATE",
  "RETURNING = functional method, usable in expressions",
  "Static members: CLASS-DATA / CLASS-METHODS, no me",
  "IS BOUND before using a reference that may be initial",
], 14);

// Constructors
s = content("Constructors: instance vs. static", SEC);
card(s, 0.6, 1.5, 5.9, 2.6, "constructor (instance)",
  "Runs once per object on NEW / CREATE OBJECT. IMPORTING parameters + exceptions only. Subclass must call super->constructor( ) first.", C.accent1, "1");
card(s, 6.8, 1.5, 5.9, 2.6, "class_constructor (static)",
  "Runs once per class per internal session, before first access. No parameters. Use for buffers / customizing reads.", C.accent3, "2");
s.addText("Creating a subclass object", { x: 0.6, y: 4.35, w: 12, h: 0.45, fontSize: 18, bold: true,
  color: C.text2, margin: 0, isTextBox: true, objectName: "ctorFlowHead" });
["Parent static", "Child static", "Child ctor → super->constructor( )", "Parent instance", "Rest of child ctor"]
  .forEach((t, i) => {
    const x = 0.6 + i * 2.48;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y: 4.95, w: 2.2, h: 1.0, rectRadius: 0.08,
      fill: { color: i < 2 ? C.accent3 : C.accent1 }, line: { color: i < 2 ? C.accent3 : C.accent1 },
      objectName: oname("flowBox") });
    s.addText(t, { x: x + 0.08, y: 4.95, w: 2.04, h: 1.0, fontSize: 13, bold: true, color: C.background1,
      align: "center", valign: "middle", margin: 0, isTextBox: true, objectName: oname("flowText") });
    if (i < 4) s.addText("›", { x: x + 2.2, y: 4.95, w: 0.28, h: 1.0, fontSize: 24, bold: true,
      color: C.accent6, align: "center", valign: "middle", margin: 0, isTextBox: true, objectName: oname("arrow") });
  });
s.addText("Watch out: a superclass constructor that calls a redefined method runs the SUPERCLASS version.",
  { x: 0.6, y: 6.15, w: 12.1, h: 0.45, fontSize: 14, italic: true, color: C.accent4, margin: 0,
    isTextBox: true, objectName: "ctorWarn" });

// Inheritance
s = content("Inheritance & redefinition", SEC);
code(s, 0.6, 1.45, 6.6, 4.4,
`CLASS lcl_truck DEFINITION
  INHERITING FROM lcl_vehicle.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_plate TYPE string
                iv_load  TYPE i.
    METHODS describe REDEFINITION.
ENDCLASS.

METHOD describe.
  rv = super->describe( )
       && | load { mv_load } t|.
ENDMETHOD.`, 13);
bullets(s, 7.6, 1.45, 5.1, 4.4, [
  { text: "Single inheritance only; root class is OBJECT", bold: false },
  "Redefine public/protected INSTANCE methods – same signature",
  "Cannot redefine: static methods, constructors, private or FINAL methods",
  "ABSTRACT class: no instances; ABSTRACT method: subclass must implement",
  "FINAL class: no subclasses",
  "super->m( ) reuses the parent logic",
], 15);
note(s, 0.6, 6.05, 12.1, 0.65, "Late binding: a superclass method calling get_wheels( ) runs the truck's redefinition when the object is a truck.");

// Polymorphism & casting
s = content("Polymorphism & casting", SEC);
card(s, 0.6, 1.5, 3.9, 2.4, "Up-cast (narrowing)",
  "lo_shape = lo_circle.\nImplicit, always safe, checked at compile time.", C.accent3, "↑");
card(s, 4.72, 1.5, 3.9, 2.4, "Down-cast (widening)",
  "lo_circle ?= lo_shape.\nCAST lcl_circle( lo ). Runtime check → CX_SY_MOVE_CAST_ERROR.", C.accent4, "↓");
card(s, 8.84, 1.5, 3.9, 2.4, "Check before cast",
  "IS INSTANCE OF lcl_circle\nCASE TYPE OF … WHEN TYPE … INTO DATA(lo).", C.accent1, "?");
code(s, 0.6, 4.15, 7.0, 2.5,
`" no CASE on type - every shape knows its area
LOOP AT lt_shapes INTO DATA(lo_shape).
  lv_total += lo_shape->area( ).
ENDLOOP.`, 13);
bullets(s, 7.9, 4.2, 4.8, 2.5, [
  "Static type = declared type (what you may call)",
  "Dynamic type = real object (which code runs)",
  "New subclass ⇒ no change to existing loop (Open/Closed)",
], 14);

// Abstract vs interface
s = content("Abstract class vs. interface", SEC);
table(s, 0.6, 1.5, 12.1, [
  ["", "Abstract class", "Interface"],
  ["Implementation", "Concrete + abstract methods", "Declarations only (DEFAULT IGNORE/FAIL in new releases)"],
  ["State", "Attributes, constructors", "Constants/types; attributes discouraged; no constructor"],
  ["How many per class", "One superclass", "Many interfaces"],
  ["Relationship", "\"is-a\" family with shared code", "\"can-do\" contract, loose coupling"],
  ["Visibility", "PUBLIC / PROTECTED / PRIVATE", "Everything public; access via intf~comp or ALIASES"],
], [2.6, 4.5, 5.0], 17);
note(s, 0.6, 5.3, 12.1, 1.1, "Interview tip: combine them – an interface defines the contract (ZIF_PAYMENT), an abstract base class implements the shared part, concrete classes add the specifics.");

// Interfaces + DI
s = content("Interfaces & dependency injection", SEC);
code(s, 0.6, 1.45, 7.2, 5.2,
`INTERFACE lif_notifier.
  METHODS send IMPORTING iv_to   TYPE string
                         iv_text TYPE string.
ENDINTERFACE.

CLASS lcl_order_service DEFINITION.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING io_notifier TYPE REF TO lif_notifier.
  PRIVATE SECTION.
    DATA mo_notifier TYPE REF TO lif_notifier.
ENDCLASS.

" production: real implementation
NEW lcl_order_service( NEW lcl_sms_notifier( ) ).
" unit test: inject a fake
NEW lcl_order_service( NEW ltd_fake_notifier( ) ).`, 12);
bullets(s, 8.1, 1.45, 4.6, 5.2, [
  "INTERFACES in PUBLIC SECTION; implement as METHOD lif~m",
  "Reference TYPE REF TO lif_x can hold any implementer",
  "Nested interfaces, ALIASES for short names",
  "Basis of BAdIs, SAP frameworks and RAP",
  "Depend on interfaces, inject implementations ⇒ testable code",
], 15);

// Events
s = content("Events in four steps", SEC);
[["1", "Declare", "EVENTS low_stock EXPORTING VALUE(ev_qty) TYPE i."],
 ["2", "Raise", "RAISE EVENT low_stock EXPORTING ev_qty = mv_qty."],
 ["3", "Handle", "METHODS on_low FOR EVENT low_stock OF lcl_stock IMPORTING ev_qty sender."],
 ["4", "Register", "SET HANDLER lo_h->on_low FOR lo_stock.  (FOR ALL INSTANCES / ACTIVATION abap_false)"]]
  .forEach((p, i) => card(s, 0.6 + i * 3.08, 1.5, 2.88, 3.3, p[1], p[2], C.accent5, p[0]));
bullets(s, 0.6, 5.1, 12.1, 1.6, [
  "Observer pattern built in · handlers run synchronously · implicit parameter sender",
  "Used everywhere in ALV: double_click, toolbar, user_command, hotspot_click (CL_GUI_ALV_GRID / CL_SALV_EVENTS_TABLE)",
], 15);

// Exceptions
s = content("Class-based exceptions", SEC);
table(s, 0.6, 1.5, 7.2, [
  ["Superclass", "Declared in RAISING?", "Use for"],
  ["CX_STATIC_CHECK", "Yes (compiler checks)", "Expected business errors"],
  ["CX_DYNAMIC_CHECK", "Checked at runtime", "Preventable errors (zero divide)"],
  ["CX_NO_CHECK", "Never", "Fatal / technical"],
], [2.4, 2.3, 2.5], 13);
code(s, 0.6, 3.6, 7.2, 3.05,
`TRY.
    lo_repo->get_order( lv_vbeln ).
  CATCH zcx_order_error INTO DATA(lx).
    MESSAGE lx TYPE 'I' DISPLAY LIKE 'E'.
  CLEANUP.
    " runs if exception propagates further
ENDTRY.
RAISE EXCEPTION NEW zcx_order_error(
  textid = zcx_order_error=>not_found previous = lx_sql ).`, 12);
bullets(s, 8.1, 1.5, 4.6, 5.2, [
  "All inherit from CX_ROOT: get_text( ), previous",
  "Catch specific classes before general ones",
  "RETRY re-runs TRY; RESUME continues after RAISE RESUMABLE",
  "Texts from SE91 via IF_T100_MESSAGE / IF_T100_DYN_MSG",
  "Chain technical errors with previous",
  "Never mix EXCEPTIONS and RAISING in one method",
], 14);

// Design patterns
s = content("Design patterns you should be able to sketch", SEC);
[["Singleton", "CREATE PRIVATE + static get_instance( ). One per internal session (logger, buffer)."],
 ["Factory", "Static create( iv_type ) returns REF TO interface; dynamic CREATE OBJECT TYPE (name)."],
 ["Strategy", "Interchangeable algorithms behind one interface (tax per country, discounts)."],
 ["Observer", "Native ABAP events: subject raises, observers SET HANDLER."],
 ["Decorator", "Wrap an interface implementation to add logging, caching, checks."],
 ["MVC / Facade / Repository", "Split model, view, controller; one simple API in front of BAPIs; DB access in one class."]]
  .forEach((p, i) => card(s, 0.6 + (i % 3) * 4.08, 1.5 + Math.floor(i / 3) * 2.6, 3.88, 2.4, p[0], p[1], C.accent1, String(i + 1)));

// ABAP Unit
s = content("ABAP Unit & test doubles", SEC);
code(s, 0.6, 1.45, 7.2, 5.2,
`CLASS ltc_calc DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_price_calc.
    METHODS setup.
    METHODS gross_14 FOR TESTING RAISING cx_static_check.
ENDCLASS.

CLASS ltc_calc IMPLEMENTATION.
  METHOD setup.
    mo_cut = NEW #( ).
  ENDMETHOD.
  METHOD gross_14.
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->net_to_gross( iv_net = 100 iv_vat = 14 )
      exp = 114 ).
  ENDMETHOD.
ENDCLASS.`, 11.5);
s.addText("Isolate dependencies", { x: 8.1, y: 1.45, w: 4.6, h: 0.45, fontSize: 18, bold: true,
  color: C.text2, margin: 0, isTextBox: true, objectName: "unitHead" });
bullets(s, 8.1, 2.0, 4.6, 4.6, [
  "Interface + injected fake class",
  "CL_ABAP_TESTDOUBLE for interfaces",
  "CL_OSQL_TEST_ENVIRONMENT / CL_CDS_TEST_ENVIRONMENT for DB",
  "TEST-SEAM / TEST-INJECTION for legacy code",
  "Fixtures: class_setup, setup, teardown, class_teardown",
  "Run: Ctrl+Shift+F10 in ADT",
], 14);

// Modern ABAP & tools
s = content("Modern ABAP and real-world OO tools", SEC);
table(s, 0.6, 1.5, 6.8, [
  ["Feature", "Example"],
  ["Inline + NEW", "DATA(lo) = NEW zcl_x( ). "],
  ["VALUE / CORRESPONDING", "lt = VALUE #( ( id = 1 ) )"],
  ["COND / SWITCH", "COND #( WHEN a > 0 THEN 'P' ELSE 'N' )"],
  ["REDUCE / FOR", "REDUCE i( INIT s = 0 FOR w IN lt NEXT s = s + w )"],
  ["Table expressions", "lt[ id = 5 ]-name, line_exists( )"],
  ["String templates", "|Order { lv ALPHA = OUT }|"],
], [2.5, 4.3], 13);
[["SALV", "cl_salv_table=>factory, functions, aggregations, event double_click"],
 ["RTTS", "describe_by_name / CREATE DATA … TYPE HANDLE for generic tools"],
 ["BAdI", "SAP interface + your implementing class (SE18/SE19, GET/CALL BADI)"]]
  .forEach((p, i) => card(s, 7.7, 1.5 + i * 1.75, 5.0, 1.6, p[0], p[1], C.accent3));

// =====================================================================
SEC = section("OData & SAP Gateway", "REST · EDM · Gateway architecture · SEGW · CRUD · Query options · $expand · Deep insert · $batch", "2");

// REST mapping
s = content("REST verbs, OData URLs and DPC methods", SEC);
table(s, 0.6, 1.5, 8.0, [
  ["HTTP", "OData URL", "DPC_EXT method"],
  ["GET", "/OrderSet", "ORDERSET_GET_ENTITYSET"],
  ["GET", "/OrderSet('4711')", "ORDERSET_GET_ENTITY"],
  ["POST", "/OrderSet + body", "ORDERSET_CREATE_ENTITY"],
  ["PUT / PATCH", "/OrderSet('4711')", "ORDERSET_UPDATE_ENTITY"],
  ["DELETE", "/OrderSet('4711')", "ORDERSET_DELETE_ENTITY"],
  ["POST", "/ReleaseOrder?OrderId='1'", "EXECUTE_ACTION"],
], [1.6, 3.0, 3.4], 16);
s.addText("Status codes to know", { x: 9.0, y: 1.5, w: 3.7, h: 0.45, fontSize: 18, bold: true,
  color: C.text2, margin: 0, isTextBox: true, objectName: "statusHead" });
bullets(s, 9.0, 2.05, 3.7, 4.6, [
  "200 OK · 201 Created · 204 No Content",
  "400 business error",
  "403 CSRF / authorization",
  "404 not found / service inactive",
  "412 ETag mismatch",
  "500 dump · 501 not implemented",
], 15);

// EDM
s = content("OData building blocks (EDM)", SEC);
[["Entity type", "Structure with key: Order(OrderId, Customer, NetAmount)"],
 ["Entity set", "Collection addressed in URL: OrderSet"],
 ["Property", "Field with EDM type: Edm.String, Edm.Decimal, Edm.DateTime"],
 ["Association", "Relationship with cardinality: Order 1 : n Item"],
 ["Navigation", "Path through it: OrderSet('1')/ToItems"],
 ["Function import", "Custom operation (V4: action / function)"]]
  .forEach((p, i) => card(s, 0.6 + (i % 3) * 4.08, 1.5 + Math.floor(i / 3) * 2.05, 3.88, 1.85, p[0], p[1], C.accent3));
code(s, 0.6, 5.7, 12.1, 0.95,
`/sap/opu/odata/sap/ZSALES_SRV/   ·   /$metadata   ·   /OrderSet?$filter=Customer eq '100001'&$top=10&$format=json`, 12);

// Gateway architecture
s = content("SAP Gateway architecture", SEC);
const flow = [["Fiori / Postman", "HTTPS request", C.accent6], ["ICF + Hub (IWFND)", "Registry, alias, cache", C.accent1],
  ["Backend (IWBEP)", "MPC_EXT model", C.accent1], ["DPC_EXT", "Your ABAP logic", C.accent3], ["DB / BAPI / CDS", "Data", C.accent6]];
flow.forEach((f, i) => {
  const x = 0.6 + i * 2.48;
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y: 1.6, w: 2.2, h: 1.4, rectRadius: 0.08,
    fill: { color: f[2] }, line: { color: f[2] }, objectName: oname("gwBox") });
  s.addText([{ text: f[0], options: { bold: true, fontSize: 15, breakLine: true } },
    { text: f[1], options: { fontSize: 12 } }], { x: x + 0.08, y: 1.6, w: 2.04, h: 1.4,
    color: C.background1, align: "center", valign: "middle", margin: 0, isTextBox: true, objectName: oname("gwText") });
  if (i < 4) s.addText("›", { x: x + 2.2, y: 1.6, w: 0.28, h: 1.4, fontSize: 26, bold: true, color: C.accent6,
    align: "center", valign: "middle", margin: 0, isTextBox: true, objectName: oname("gwArrow") });
});
card(s, 0.6, 3.35, 5.9, 1.6, "Embedded deployment", "Hub and backend in one system – standard for S/4HANA, no RFC.", C.accent1);
card(s, 6.8, 3.35, 5.9, 1.6, "Hub deployment", "Separate frontend server (FLP + UI5) → trusted RFC → ECC/S4 backends via system alias.", C.accent1);
table(s, 0.6, 5.2, 12.1, [
  ["SEGW", "/IWFND/MAINT_SERVICE", "/IWFND/GW_CLIENT", "/IWFND/ERROR_LOG", "/IWBEP/ERROR_LOG", "*/CACHE_CLEANUP"],
  ["Build", "Register", "Test", "Hub errors", "Backend errors", "Metadata cache"],
], [1.6, 2.4, 2.1, 2.0, 2.0, 2.0], 13);

// SEGW steps
s = content("Your first service in SEGW", SEC);
["Create project", "Import DDIC / RFC / CDS", "Set key & set properties", "Generate runtime objects",
 "Register in MAINT_SERVICE", "Test in GW_CLIENT"].forEach((t, i) => {
  const y = 1.5 + i * 0.85;
  badge(s, 0.6, y + 0.07, String(i + 1), C.accent2, 0.55);
  s.addText(t, { x: 1.35, y, w: 4.4, h: 0.7, fontSize: 17, bold: true, color: C.text2, valign: "middle",
    margin: 0, isTextBox: true, objectName: oname("stepText") });
});
table(s, 6.1, 1.5, 6.6, [
  ["Generated", "Role", "Edit?"],
  ["ZCL_*_MPC", "Model (from SEGW)", "No"],
  ["ZCL_*_MPC_EXT", "Annotations / model tweaks", "Yes"],
  ["ZCL_*_DPC", "CRUD stubs → 501", "No"],
  ["ZCL_*_DPC_EXT", "Your business logic", "Yes"],
], [2.2, 3.2, 1.2], 14);
note(s, 6.1, 4.4, 6.6, 1.3, "Golden rule: base classes are regenerated on every Generate – put code only in the _EXT classes.", C.accent4);

// CRUD code
s = content("CRUD in the DPC_EXT", SEC);
code(s, 0.6, 1.45, 6.3, 5.2,
`METHOD orderset_get_entity.
  DATA ls_key TYPE zcl_zsales_mpc=>ts_order.
  io_tech_request_context->get_converted_keys(
    IMPORTING es_key_values = ls_key ).
  SELECT SINGLE vbeln, kunnr, netwr, waerk
    FROM vbak WHERE vbeln = @ls_key-vbeln
    INTO CORRESPONDING FIELDS OF @er_entity.
  IF sy-subrc <> 0.
    RAISE EXCEPTION TYPE
      /iwbep/cx_mgw_busi_exception
      EXPORTING textid =
        /iwbep/cx_mgw_busi_exception=>resource_not_found.
  ENDIF.
ENDMETHOD.`, 11.5);
code(s, 7.1, 1.45, 5.6, 2.6,
`METHOD orderset_create_entity.
  io_data_provider->read_entry_data(
    IMPORTING es_data = ls_order ).
  " validate, call API / BAPI
  er_entity = ls_order.   " -> 201
ENDMETHOD.`, 11.5);
bullets(s, 7.1, 4.3, 5.6, 2.4, [
  "Keys: get_converted_keys",
  "Body: io_data_provider->read_entry_data",
  "Errors: /IWBEP/CX_MGW_BUSI_EXCEPTION + message container",
  "Keep DPC thin – logic in your OO classes",
], 14);

// Query options
s = content("Query options – who does the work?", SEC);
table(s, 0.6, 1.5, 12.1, [
  ["Option", "Example", "SEGW implementation"],
  ["$filter", "Customer eq '100001' and NetAmount gt 500", "get_osql_where_clause_convert( ) / get_filter( )"],
  ["$orderby", "NetAmount desc", "it_order → ORDER BY / helper orderby"],
  ["$top / $skip", "$top=20&$skip=40", "get_top( ), get_skip( ) → UP TO n ROWS OFFSET m"],
  ["$inlinecount / $count", "$inlinecount=allpages", "SELECT COUNT(*) → es_response_context-inlinecount"],
  ["$select", "$select=OrderId,Customer", "Framework trims; optimise field list"],
  ["$expand", "$expand=ToItems", "Framework (N+1) or GET_EXPANDED_ENTITYSET"],
  ["search", "search=cairo", "get_search_string( )"],
], [2.4, 4.2, 5.5], 14);
note(s, 0.6, 5.95, 12.1, 0.75, "CDS / RAP services: SADL translates all of these to SQL automatically – no ABAP code for reads.", C.accent3);

// Navigation, expand, deep insert
s = content("Navigation, $expand and deep insert", SEC);
card(s, 0.6, 1.5, 3.9, 2.6, "Navigation", "OrderSet('4711')/ToItems\nItem method reads get_converted_source_keys( ).", C.accent1, "1");
card(s, 4.72, 1.5, 3.9, 2.6, "$expand", "Avoid N+1: redefine GET_EXPANDED_ENTITYSET, child component named like nav property, fill et_expanded_tech_clauses.", C.accent1, "2");
card(s, 8.84, 1.5, 3.9, 2.6, "Deep insert", "POST header + items in one JSON → CREATE_DEEP_ENTITY reads a deep structure.", C.accent1, "3");
code(s, 0.6, 4.35, 12.1, 2.3,
`POST .../OrderSet
{ "Customer": "100001", "Currency": "EGP",
  "ToItems": [ { "ItemNo": "10", "Material": "MAT-01", "Quantity": "2" },
               { "ItemNo": "20", "Material": "MAT-02", "Quantity": "5" } ] }`, 13);

// batch / FI / media / etag
s = content("$batch, function imports, media, ETag", SEC);
[["$batch", "Many requests in one POST. Changeset = all-or-nothing LUW: CHANGESET_BEGIN / PROCESS / END (commit once)."],
 ["Function import", "Non-CRUD operation (ReleaseOrder). GET = read, POST = changes. Implement EXECUTE_ACTION."],
 ["Media", "Files & PDFs: media entity, GET_STREAM ($value) and CREATE_STREAM (slug header)."],
 ["ETag & CSRF", "If-Match → 412 on conflict. X-CSRF-Token: Fetch, then send on POST/PUT/DELETE."]]
  .forEach((p, i) => card(s, 0.6 + (i % 2) * 6.2, 1.5 + Math.floor(i / 2) * 2.6, 5.9, 2.4, p[0], p[1], C.accent5, String(i + 1)));

// =====================================================================
SEC = section("CDS-based OData & RAP", "SADL · @OData.publish · Reference data source · RAP layers · EML · OData V4", "3");

s = content("Exposing CDS views as OData", SEC);
table(s, 0.6, 1.5, 12.1, [
  ["Approach", "How", "Write logic", "Status"],
  ["@OData.publish: true", "Annotation in CDS → <VIEW>_CDS service", "BOPF only", "Legacy, still common"],
  ["SEGW Reference Data Source", "SEGW → Reference → Data Source (CDS)", "DPC_EXT", "Common with custom logic"],
  ["RAP service binding", "Service definition + binding V2/V4", "Behavior definition + pool", "Recommended"],
], [3.0, 4.0, 2.6, 2.5], 14);
bullets(s, 0.6, 3.75, 6.0, 2.9, [
  "Associations become navigation properties (to_Items)",
  "DCL (@AccessControl) = row-level authorization for free",
  "@UI annotations drive Fiori elements",
  "@Search.searchable enables free-text search",
], 15);
code(s, 6.9, 3.75, 5.8, 2.9,
`@OData.publish: true
define view ZC_SalesOrder
  as select from vbak
  association [0..*] to ZC_Item as _Items
    on $projection.SalesOrder = _Items.SalesOrder
{ key vbeln as SalesOrder,
      kunnr as SoldToParty,
      _Items }`, 12);

// RAP layers
s = content("RAP: the layers of a business object", SEC);
const rap = [["Database table", "ztravel_a with admin fields", C.accent6],
  ["CDS view entities", "define root view entity ZI_Travel (+ compositions)", C.accent1],
  ["Behavior definition", "create, update, delete, actions, validations, determinations, lock, etag, draft", C.accent1],
  ["Behavior pool", "ZBP_I_TRAVEL: handler & saver classes written in EML", C.accent3],
  ["Projection", "ZC_Travel + projection BDEF (use create; use action …)", C.accent5],
  ["Service definition + binding", "expose ZC_Travel → OData V4 UI / Web API → Publish → Preview", C.accent4]];
rap.forEach((r, i) => {
  const y = 1.45 + i * 0.88;
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.6, y, w: 3.4, h: 0.75, rectRadius: 0.08,
    fill: { color: r[2] }, line: { color: r[2] }, objectName: oname("rapBox") });
  s.addText(r[0], { x: 0.7, y, w: 3.2, h: 0.75, fontSize: 15, bold: true, color: C.background1, align: "center",
    valign: "middle", margin: 0, isTextBox: true, objectName: oname("rapName") });
  s.addText(r[1], { x: 4.25, y, w: 8.45, h: 0.75, fontSize: 15, color: C.text1, valign: "middle", margin: 0,
    isTextBox: true, objectName: oname("rapDesc") });
});

// RAP code / EML
s = content("Behavior definition & EML in practice", SEC);
code(s, 0.6, 1.45, 6.0, 5.2,
`managed implementation in class zbp_i_travel unique;
strict ( 2 );
define behavior for ZI_Travel alias Travel
persistent table ztravel_a
lock master
authorization master ( instance )
etag master LocalLastChangedAt
{
  create; update; delete;
  field ( numbering : managed, readonly ) TravelUUID;
  action acceptTravel result [1] $self;
  determination setInitialValues
    on modify { create; }
  validation validateDates
    on save { create; field BeginDate, EndDate; }
}`, 11);
code(s, 6.8, 1.45, 5.9, 3.0,
`MODIFY ENTITIES OF zi_travel IN LOCAL MODE
  ENTITY Travel UPDATE FIELDS ( Status )
  WITH VALUE #( FOR k IN keys
    ( %tky = k-%tky Status = 'A' ) ).

COMMIT ENTITIES.   " outside the BO`, 11);
bullets(s, 6.8, 4.65, 5.9, 2.0, [
  "Managed = framework does CRUD & save; unmanaged = you do",
  "failed / reported / mapped; %tky, %cid, %param",
  "with draft; for Fiori elements save-later",
], 14);

// SEGW vs RAP
s = content("SEGW vs. RAP – which one when?", SEC);
table(s, 0.6, 1.5, 12.1, [
  ["", "SEGW / Gateway", "RAP"],
  ["Model", "SEGW project, MPC/DPC classes", "CDS view entities + BDEF"],
  ["Queries", "Implemented by you (or RDS)", "SADL automatic"],
  ["Protocol", "Mainly OData V2", "OData V2 and V4, UI and Web API"],
  ["Transactions", "You: BAPIs, COMMIT, locks", "Buffer, locking, ETag, draft by framework"],
  ["Tooling", "SAP GUI", "ADT (Eclipse)"],
  ["Use it for", "ECC / older releases, special custom logic", "S/4HANA 1909+, BTP, Clean Core"],
], [2.2, 4.9, 5.0], 17);

// Consumption / performance / security
s = content("Consume, tune, secure, troubleshoot", SEC);
card(s, 0.6, 1.5, 5.9, 2.5, "Consume",
  "UI5 ODataModel (read/create/update/remove, auto CSRF + $batch) · Postman with X-CSRF-Token · ABAP: CL_HTTP_CLIENT + /UI2/CL_JSON or typed client proxy.", C.accent1, "1");
card(s, 6.8, 1.5, 5.9, 2.5, "Performance",
  "Push filter/paging to DB · no SELECT * · fix N+1 $expand · max page size · sap-statistics=true, ST05, SAT.", C.accent3, "2");
card(s, 0.6, 4.2, 5.9, 2.5, "Security",
  "S_SERVICE in role · AUTHORITY-CHECK / DCL · CSRF on · validate input, no raw dynamic WHERE · HTTPS/SSO.", C.accent4, "3");
card(s, 6.8, 4.2, 5.9, 2.5, "Troubleshoot",
  "404 → MAINT_SERVICE/SICF · 403 → CSRF/SU53 · 500 → ST22 + ERROR_LOG (Replay) · old $metadata → cache cleanup.", C.accent5, "4");

// =====================================================================
SEC = section("Interview & Practice", "Top questions · Practical labs per concept · Capstone project", "4");

s = content("Top ABAP Objects interview questions", SEC);
const ooQ = [
  ["Class vs. object?", "Blueprint vs. runtime instance via NEW."],
  ["Abstract class vs. interface?", "Shared code + one parent vs. contract + many."],
  ["Up-cast vs. down-cast?", "Implicit & safe vs. ?=/CAST with runtime check."],
  ["What can't be redefined?", "Static methods, constructors, private, FINAL."],
  ["3 exception categories?", "STATIC_CHECK, DYNAMIC_CHECK, NO_CHECK."],
  ["CLEANUP vs. RETRY vs. RESUME?", "Restore state / rerun TRY / continue after raise."],
  ["Events – 4 steps?", "EVENTS, RAISE EVENT, FOR EVENT, SET HANDLER."],
  ["Patterns used?", "Singleton, Factory, Strategy, Observer, MVC."],
];
ooQ.forEach((q, i) => {
  const x = 0.6 + (i % 2) * 6.2, y = 1.5 + Math.floor(i / 2) * 1.3;
  badge(s, x, y + 0.1, "Q", C.accent1, 0.45);
  s.addText([{ text: q[0], options: { bold: true, color: C.text2, breakLine: true } },
    { text: q[1], options: { color: C.text1 } }], { x: x + 0.6, y, w: 5.4, h: 1.15, fontSize: 15,
    valign: "top", margin: 0, isTextBox: true, objectName: oname("qa") });
});

s = content("Top OData interview questions", SEC);
const odQ = [
  ["MPC vs. DPC? Which to edit?", "Model vs. data; only _EXT classes."],
  ["How do you implement $filter / paging?", "where_clause_convert / get_top + OFFSET on DB."],
  ["$expand vs. navigation?", "Parent + children inline vs. children only."],
  ["Deep insert vs. $batch?", "One nested POST vs. many requests / changesets."],
  ["CSRF token?", "Fetch on GET, send on modifying calls; else 403."],
  ["ETag?", "Optimistic lock; If-Match → 412."],
  ["Hub vs. embedded?", "Separate FES + RFC vs. same system."],
  ["SEGW vs. RAP?", "Manual V2 vs. CDS + BDEF, V4, managed transactions."],
];
odQ.forEach((q, i) => {
  const x = 0.6 + (i % 2) * 6.2, y = 1.5 + Math.floor(i / 2) * 1.3;
  badge(s, x, y + 0.1, "Q", C.accent3, 0.45);
  s.addText([{ text: q[0], options: { bold: true, color: C.text2, breakLine: true } },
    { text: q[1], options: { color: C.text1 } }], { x: x + 0.6, y, w: 5.4, h: 1.15, fontSize: 15,
    valign: "top", margin: 0, isTextBox: true, objectName: oname("qa") });
});

// Labs roadmap
s = content("Practical labs – one per concept", SEC);
table(s, 0.6, 1.5, 12.1, [
  ["Concept", "Lab (solution in PDF)", "Concept", "Lab (solution in PDF)"],
  ["Classes", "LCL_STUDENT with grades & average", "OData basics", "Query Northwind with $filter/$expand"],
  ["Constructors", "Predict constructor order", "SEGW CRUD", "ZSTUDENT_SRV with all 5 operations"],
  ["Encapsulation", "Temperature with factory", "Navigation/deep insert", "Order + items, function import"],
  ["Inheritance", "Employee payroll hierarchy", "CDS OData", "ZC_Student with @OData.publish"],
  ["Polymorphism", "Payment methods + down-cast", "RAP", "Managed student BO, V4 binding"],
  ["Interfaces/Events", "Storage decorator, order observer", "Troubleshooting", "Error log, statistics, SU53"],
  ["Exceptions/Patterns/Unit", "Safe calc, discount engine + tests", "Capstone", "Leave requests: OO + OData end-to-end"],
], [2.3, 3.8, 2.3, 3.7], 15);

// Closing
s = pres.addSlide({ masterName: "SECTION_DARK", sectionTitle: SEC });
s.addShape(pres.shapes.OVAL, { x: 0.8, y: 2.75, w: 1.0, h: 1.0, fill: { color: C.accent2 },
  line: { color: C.accent2 }, objectName: "closeBadge" });
s.addText("✓", { x: 0.8, y: 2.75, w: 1.0, h: 1.0, fontSize: 30, bold: true, color: C.text2,
  align: "center", valign: "middle", margin: 0, isTextBox: true, objectName: "closeTick" });
s.addText("Next steps", { placeholder: "title" });
s.addText("Do every lab in the PDF · build the Leave Request capstone · rebuild it in RAP · revise Part III before each interview",
  { placeholder: "body" });

(async () => {
  await pres.writeFile({ fileName: OUT });
  await applyTheme(OUT, THEME);
  console.log("written", OUT);
})();
