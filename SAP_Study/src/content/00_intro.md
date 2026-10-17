# How to Use This Guide

This guide takes you from **zero to advanced** in two of the most important skills of a modern SAP developer: **ABAP Objects (OO ABAP)** and **OData services** (SAP Gateway / SEGW, CDS-based services and RAP). Each chapter follows the same rhythm:

1. **Concept** – what it is and why it exists, in plain words.
2. **Syntax & example** – real ABAP code you can paste into SE38/SE24/ADT (Eclipse).
3. **Watch-outs** – the traps that cost developers hours (and interviewers love to ask).
4. **Practical Lab** – a small task for you to build yourself, followed by a model **Solution**.

At the end you will find **Part III – Interview Questions** (grouped Beginner → Intermediate → Advanced, each with a model answer) and **Part IV – Capstone projects** that combine everything into one realistic scenario, plus cheat sheets for quick revision before an interview.

## Suggested study plan (6 weeks)

| Week | Topic | Output you should have |
|---|---|---|
| 1 | Ch. 1–4: classes, objects, methods, constructors, encapsulation | 3 local classes in a report, all labs done |
| 2 | Ch. 5–8: inheritance, polymorphism, interfaces, events | A small class hierarchy + interface-based design |
| 3 | Ch. 9–12: exceptions, design patterns, ABAP Unit, modern syntax, SALV | OO report with SALV + unit tests |
| 4 | Ch. 13–16: REST/OData basics, Gateway architecture, SEGW, CRUD | Working OData service with GET/POST/PUT/DELETE |
| 5 | Ch. 17–20: query options, navigation/$expand, deep insert, $batch, function imports, media | Header–Item service with deep insert |
| 6 | Ch. 21–23: CDS-based OData, RAP, consumption, performance; Part III & IV | RAP business object + revise interview questions |

## Systems & tools you need

- An SAP system with developer access: company sandbox, **SAP BTP ABAP Environment (trial)**, or an **ABAP Platform Developer Edition** (Docker image).
- **SAP GUI** (SE24, SE80, SE38, SEGW, /IWFND/MAINT_SERVICE) and **Eclipse + ABAP Development Tools (ADT)** – mandatory for CDS and RAP.
- An HTTP tool for testing: **/IWFND/GW_CLIENT** (in SAP GUI) and/or **Postman**.

:::tip How to get the most from the labs
Type the code yourself instead of copy-pasting. Then break it on purpose (remove a `RAISING`, change a visibility section, call a private method) and read the syntax error. Understanding *why* the compiler complains is exactly what interviewers check.
:::

## Naming conventions used in this guide

| Object | Prefix / pattern | Example |
|---|---|---|
| Global class / interface | `ZCL_` / `ZIF_` | `ZCL_SALES_ORDER`, `ZIF_PRINTABLE` |
| Local class / interface | `LCL_` / `LIF_` | `LCL_CALCULATOR` |
| Exception class | `ZCX_` / `LCX_` | `ZCX_ORDER_NOT_FOUND` |
| Instance attribute | `mv_` (value), `ms_` (structure), `mt_` (table), `mo_` (object) | `mv_order_id`, `mt_items` |
| Static attribute | `gv_`, `gt_`, `go_` (or `sv_`) | `go_instance` |
| Method parameter | `iv_ ev_ cv_ rv_` (+ `s/t/o`) | `iv_matnr`, `rt_items`, `ro_order` |
| Local variable | `lv_ ls_ lt_ lo_` | `lt_orders` |

:::note Clean ABAP
SAP's official *Clean ABAP* style guide recommends dropping most Hungarian prefixes in new code (e.g. `order_id` instead of `mv_order_id`). Many companies still use prefixes, so this guide keeps them for readability – but know both styles for interviews.
:::
