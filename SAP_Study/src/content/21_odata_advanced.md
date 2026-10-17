# 17. Query Options in Depth

System query options start with `$` and are passed in the URL. The table shows what the framework does for you and what **you** must implement in the DPC_EXT (SEGW services). For CDS/RAP-based services the SADL framework handles all of them automatically.

| Option | Example | Meaning | Who handles it in SEGW? |
|---|---|---|---|
| `$filter` | `$filter=Customer eq '100001' and NetAmount gt 500` | Restrict rows | **You** (use `get_osql_where_clause_convert` or `it_filter_select_options`) |
| `$orderby` | `$orderby=NetAmount desc,OrderId` | Sort | **You** (`it_order` / helper `orderby`) |
| `$top` / `$skip` | `$top=20&$skip=40` | Paging | **You** (`is_paging` / helper `paging` / DB `OFFSET`) |
| `$select` | `$select=OrderId,Customer` | Only these fields in response | Framework trims output; you *may* optimise the SELECT with `get_select_with_mandtry_fields( )` |
| `$expand` | `$expand=ToItems,ToCustomer` | Include related entities | Framework (calls navigation GET_ENTITYSET per row) or **you** (GET_EXPANDED_ENTITYSET for performance) |
| `$inlinecount` (V2) | `$inlinecount=allpages` | Total count in response (`__count`) | **You** set `es_response_context-inlinecount` |
| `/$count` | `OrderSet/$count?$filter=...` | Only the number | Framework counts GET_ENTITYSET result (or you optimise) |
| `$format` | `$format=json` | Response format | Framework |
| `search` (V2 SAP) / `$search` (V4) | `search=cairo` | Free text search | **You** (`io_tech_request_context->get_search_string( )`) |
| `$skiptoken` | server-driven paging | Next page token | You (`es_response_context-skiptoken`) |

## $filter operators

| Operator | Meaning | Example |
|---|---|---|
| `eq` / `ne` | equal / not equal | `Status eq 'A'` |
| `gt` `ge` `lt` `le` | comparisons | `NetAmount ge 1000` |
| `and` / `or` / `not` | logical | `City eq 'Cairo' or City eq 'Giza'` |
| `substringof` (V2) / `contains` (V4) | text contains | `substringof('Ali',Name)` |
| `startswith` / `endswith` | text prefix/suffix | `startswith(Name,'A')` |
| Date (V2) | datetime literal | `CreatedOn ge datetime'2026-01-01T00:00:00'` |

## Reading the filter manually (select-options)

```abap
METHOD orderset_get_entityset.
  DATA: lr_kunnr TYPE RANGE OF kunnr,
        lr_erdat TYPE RANGE OF erdat.

  " technical (ABAP) property names via the tech request context
  DATA(lo_filter) = io_tech_request_context->get_filter( ).
  LOOP AT lo_filter->get_filter_select_options( ) INTO DATA(ls_so).
    CASE ls_so-property.
      WHEN 'KUNNR'.
        lr_kunnr = CORRESPONDING #( ls_so-select_options ).
      WHEN 'ERDAT'.
        lr_erdat = CORRESPONDING #( ls_so-select_options ).
    ENDCASE.
  ENDLOOP.

  " paging pushed to the DB
  DATA(lv_top)  = CONV i( io_tech_request_context->get_top( ) ).
  DATA(lv_skip) = CONV i( io_tech_request_context->get_skip( ) ).
  IF lv_top IS INITIAL.
    lv_top = 1000.                     " protect the system
  ENDIF.

  SELECT vbeln, erdat, kunnr, netwr, waerk
    FROM vbak
    WHERE kunnr IN @lr_kunnr AND erdat IN @lr_erdat
    ORDER BY vbeln
    INTO CORRESPONDING FIELDS OF TABLE @et_entityset
    UP TO @lv_top ROWS OFFSET @lv_skip.

  IF io_tech_request_context->has_inlinecount( ) = abap_true.
    SELECT COUNT(*) FROM vbak
      WHERE kunnr IN @lr_kunnr AND erdat IN @lr_erdat
      INTO @DATA(lv_count).
    es_response_context-inlinecount = lv_count.
  ENDIF.
ENDMETHOD.
```

:::warn Filter that cannot be converted
Complex filters (`or` across different fields, functions like `substringof`) do not appear in `get_filter_select_options( )` – the table is empty but the filter string is filled. Either use `get_osql_where_clause_convert( )` (handles most cases) or parse `iv_filter_string`. Never silently ignore a filter – the user would see wrong data.
:::

# 18. Associations, Navigation and $expand

## Modelling a header–item relationship in SEGW

1. Create entity types `Order` (key `OrderId`) and `OrderItem` (keys `OrderId`, `ItemNo`) with sets `OrderSet`, `OrderItemSet`.
2. Right-click *Associations* → *Create*: name `Order_Items`, principal `Order` cardinality **1**, dependent `OrderItem` cardinality **M** (0..n), create navigation property `ToItems` in Order (and optionally `ToOrder` in OrderItem).
3. *Referential constraint*: principal key `OrderId` ↔ dependent property `OrderId`.
4. Generate runtime objects. The association set is created automatically.

Now these URLs work:

```text
GET .../OrderSet('4711')/ToItems                -> items of one order
GET .../OrderSet('4711')?$expand=ToItems        -> order + its items in one call
GET .../OrderSet?$expand=ToItems&$top=10        -> 10 orders, each with items
GET .../OrderItemSet(OrderId='4711',ItemNo='10')/ToOrder
```

## Implementing navigation – ORDERITEMSET_GET_ENTITYSET

When called via navigation (`OrderSet('4711')/ToItems`), the **item** entity set method is executed with the source entity's key available.

```abap
METHOD orderitemset_get_entityset.
  DATA ls_order_key TYPE zcl_zsales_mpc=>ts_order.
  DATA lr_vbeln     TYPE RANGE OF vbeln.

  " called through navigation from Order?
  IF io_tech_request_context->get_source_entity_type_name( )
       = zcl_zsales_mpc=>gc_order.
    io_tech_request_context->get_converted_source_keys(
      IMPORTING es_key_values = ls_order_key ).
    lr_vbeln = VALUE #( ( sign = 'I' option = 'EQ' low = ls_order_key-vbeln ) ).
  ENDIF.

  SELECT vbeln, posnr, matnr, kwmeng, netwr
    FROM vbap
    WHERE vbeln IN @lr_vbeln
    INTO CORRESPONDING FIELDS OF TABLE @et_entityset.
ENDMETHOD.
```

## $expand: default behaviour vs. GET_EXPANDED_ENTITYSET

By default, for `OrderSet?$expand=ToItems` the framework calls `ORDERSET_GET_ENTITYSET` once and then `ORDERITEMSET_GET_ENTITYSET` **once per order** (N+1 problem → slow). For performance, redefine `/IWBEP/IF_MGW_APPL_SRV_RUNTIME~GET_EXPANDED_ENTITYSET` (and `GET_EXPANDED_ENTITY` for single entity) and read everything with two SELECTs:

```abap
METHOD /iwbep/if_mgw_appl_srv_runtime~get_expanded_entityset.
  " deep structure: order fields + table of items named like the nav property
  TYPES: BEGIN OF ty_order_deep.
           INCLUDE TYPE zcl_zsales_mpc=>ts_order.
  TYPES:   toitems TYPE zcl_zsales_mpc=>tt_orderitem,
         END OF ty_order_deep,
         tt_order_deep TYPE STANDARD TABLE OF ty_order_deep WITH EMPTY KEY.
  DATA lt_deep TYPE tt_order_deep.

  CASE iv_entity_set_name.
    WHEN 'OrderSet'.
      DATA(lt_expand) = io_tech_request_context->get_expand( ).    " e.g. 'TOITEMS'
      SELECT vbeln, erdat, kunnr, netwr, waerk FROM vbak
        INTO CORRESPONDING FIELDS OF TABLE @lt_deep UP TO 100 ROWS.

      IF lt_deep IS NOT INITIAL AND lt_expand CS 'TOITEMS'.
        SELECT vbeln, posnr, matnr, kwmeng, netwr FROM vbap
          FOR ALL ENTRIES IN @lt_deep WHERE vbeln = @lt_deep-vbeln
          INTO TABLE @DATA(lt_items).
        LOOP AT lt_deep ASSIGNING FIELD-SYMBOL(<ls_deep>).
          <ls_deep>-toitems = VALUE #( FOR ls_it IN lt_items WHERE ( vbeln = <ls_deep>-vbeln )
                                       ( CORRESPONDING #( ls_it ) ) ).
        ENDLOOP.
        " tell the framework that we already handled the expand
        APPEND 'TOITEMS' TO et_expanded_tech_clauses.
      ENDIF.

      copy_data_to_ref( EXPORTING is_data = lt_deep
                        CHANGING  cr_data = er_entityset ).
    WHEN OTHERS.
      super->/iwbep/if_mgw_appl_srv_runtime~get_expanded_entityset(
        EXPORTING iv_entity_name = iv_entity_name iv_entity_set_name = iv_entity_set_name
                  iv_source_name = iv_source_name it_filter_select_options = it_filter_select_options
                  it_order = it_order is_paging = is_paging it_navigation_path = it_navigation_path
                  it_key_tab = it_key_tab iv_filter_string = iv_filter_string
                  iv_search_string = iv_search_string io_expand = io_expand
                  io_tech_request_context = io_tech_request_context
        IMPORTING er_entityset = er_entityset
                  et_expanded_clauses = et_expanded_clauses
                  et_expanded_tech_clauses = et_expanded_tech_clauses
                  es_response_context = es_response_context ).
  ENDCASE.
ENDMETHOD.
```

:::warn Deep structure names
The component holding the child table must have the **same name as the navigation property** (in technical/ABAP form, upper case `TOITEMS`), otherwise the framework cannot map it and returns empty `results`.
:::

# 19. Deep Insert, $batch, Function Imports, Media and ETags

## Deep insert – create header and items in one POST

```text
POST .../OrderSet
{ "Customer": "100001", "Currency": "EGP",
  "ToItems": [ { "ItemNo": "10", "Material": "MAT-01", "Quantity": "2" },
               { "ItemNo": "20", "Material": "MAT-02", "Quantity": "5" } ] }
```

Redefine `/IWBEP/IF_MGW_APPL_SRV_RUNTIME~CREATE_DEEP_ENTITY`:

```abap
METHOD /iwbep/if_mgw_appl_srv_runtime~create_deep_entity.
  TYPES: BEGIN OF ty_deep.
           INCLUDE TYPE zcl_zsales_mpc=>ts_order.
  TYPES:   toitems TYPE zcl_zsales_mpc=>tt_orderitem,
         END OF ty_deep.
  DATA ls_deep TYPE ty_deep.

  CASE iv_entity_set_name.
    WHEN 'OrderSet'.
      io_data_provider->read_entry_data( IMPORTING es_data = ls_deep ).

      " map to BAPI structures and create the order
      DATA: lt_items_in TYPE STANDARD TABLE OF bapisditm,
            lt_partners TYPE STANDARD TABLE OF bapiparnr,
            lt_return   TYPE STANDARD TABLE OF bapiret2.
      lt_items_in = VALUE #( FOR i IN ls_deep-toitems
                             ( itm_number = i-posnr material = i-matnr
                               target_qty = i-kwmeng ) ).
      lt_partners = VALUE #( ( partn_role = 'AG' partn_numb = ls_deep-kunnr ) ).

      CALL FUNCTION 'BAPI_SALESORDER_CREATEFROMDAT2'
        EXPORTING order_header_in = VALUE bapisdhd1( doc_type   = 'OR'
                                                     sales_org  = '1000'
                                                     distr_chan = '10'
                                                     division   = '00' )
        IMPORTING salesdocument   = ls_deep-vbeln
        TABLES    return          = lt_return
                  order_items_in  = lt_items_in
                  order_partners  = lt_partners.
      IF line_exists( lt_return[ type = 'E' ] ) OR line_exists( lt_return[ type = 'A' ] ).
        CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
        DATA(lo_msg) = mo_context->get_message_container( ).
        lo_msg->add_messages_from_bapi( it_bapi_messages = lt_return ).
        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING message_container = lo_msg.
      ENDIF.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = abap_true.

      copy_data_to_ref( EXPORTING is_data = ls_deep CHANGING cr_data = er_deep_entity ).
  ENDCASE.
ENDMETHOD.
```

:::note COMMIT inside Gateway
Inside a `$batch` changeset you must **not** commit (the framework commits at the end). Outside `$batch`, single CRUD calls can commit (as above). For clean code, check `mo_context`/use the changeset methods or move the commit to `changeset_end`.
:::

## $batch – many operations in one HTTP request

UI5 sends `$batch` by default (ODataModel V2). It contains **query parts** (GETs) and **changesets** (groups of POST/PUT/DELETE executed as one logical unit of work: all or nothing).

```text
POST .../$batch
Content-Type: multipart/mixed; boundary=batch_1

--batch_1
Content-Type: application/http

GET OrderSet('4711') HTTP/1.1

--batch_1
Content-Type: multipart/mixed; boundary=changeset_1

--changeset_1
Content-Type: application/http

PUT OrderSet('4711') HTTP/1.1
Content-Type: application/json

{"Customer":"100002"}
--changeset_1--
--batch_1--
```

In the DPC_EXT redefine:

- `/IWBEP/IF_MGW_APPL_SRV_RUNTIME~CHANGESET_BEGIN` – decide if you support several operations in one changeset (set `cv_defer_mode = abap_true` to collect them).
- `~CHANGESET_PROCESS` – (defer mode) process all operations of the changeset together, e.g. one BAPI call for many items.
- `~CHANGESET_END` – `COMMIT WORK` once for the changeset.

```abap
METHOD /iwbep/if_mgw_appl_srv_runtime~changeset_begin.
  " allow more than one operation per changeset (default: only 1)
  LOOP AT it_operation_info TRANSPORTING NO FIELDS
       WHERE entity_set <> 'OrderSet' AND entity_set <> 'OrderItemSet'.
    RAISE EXCEPTION TYPE /iwbep/cx_mgw_tech_exception
      EXPORTING textid = /iwbep/cx_mgw_tech_exception=>changeset_not_supported.
  ENDLOOP.
ENDMETHOD.

METHOD /iwbep/if_mgw_appl_srv_runtime~changeset_end.
  COMMIT WORK.
ENDMETHOD.
```

## Function imports (custom operations)

Use when the operation is not CRUD: *release order*, *calculate price*, *get dashboard KPIs*.

1. SEGW → *Function Imports* → *Create* `ReleaseOrder`; return type kind *Entity Type* `Order` (cardinality 1) or Complex Type; HTTP method **POST** (changes data) or **GET** (read); add parameters `OrderId` (Edm.String).
2. Generate, then redefine `/IWBEP/IF_MGW_APPL_SRV_RUNTIME~EXECUTE_ACTION`:

```abap
METHOD /iwbep/if_mgw_appl_srv_runtime~execute_action.
  DATA ls_order TYPE zcl_zsales_mpc=>ts_order.

  CASE iv_action_name.
    WHEN 'ReleaseOrder'.
      DATA(ls_param) = VALUE /iwbep/s_mgw_name_value_pair(
                         it_parameter[ name = 'OrderId' ] OPTIONAL ).
      IF ls_param IS INITIAL.
        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING message = 'OrderId is required'.
      ENDIF.
      ls_order-vbeln = |{ ls_param-value ALPHA = IN }|.
      " ... release logic (BAPI / API class) ...
      SELECT SINGLE vbeln, erdat, kunnr, netwr, waerk FROM vbak
        WHERE vbeln = @ls_order-vbeln INTO CORRESPONDING FIELDS OF @ls_order.
      copy_data_to_ref( EXPORTING is_data = ls_order CHANGING cr_data = er_data ).
  ENDCASE.
ENDMETHOD.
```

```text
POST .../ReleaseOrder?OrderId='4711'
```

## Media / streams (files, images, PDFs)

1. Mark the entity type as **Media** (checkbox *Media* in SEGW) – e.g. `Attachment` with key `DocId`.
2. In `MPC_EXT->DEFINE` set the MIME type property: `lo_entity->get_property( 'MimeType' )->set_as_content_type( ).`
3. Redefine `GET_STREAM` (download: `GET .../AttachmentSet('1')/$value`) and `CREATE_STREAM` (upload: POST with binary body + header `slug` for the file name).

```abap
METHOD /iwbep/if_mgw_appl_srv_runtime~get_stream.
  DATA ls_stream TYPE /iwbep/if_mgw_appl_types=>ty_s_media_resource. " value, mime_type
  DATA ls_key    TYPE zcl_zsales_mpc=>ts_attachment.
  io_tech_request_context->get_converted_keys( IMPORTING es_key_values = ls_key ).
  SELECT SINGLE content, mime_type FROM zattach WHERE doc_id = @ls_key-doc_id
    INTO (@ls_stream-value, @ls_stream-mime_type).
  copy_data_to_ref( EXPORTING is_data = ls_stream CHANGING cr_data = er_stream ).
ENDMETHOD.

METHOD /iwbep/if_mgw_appl_srv_runtime~create_stream.
  DATA ls_attach TYPE zattach.
  TRY.
      ls_attach-doc_id = cl_system_uuid=>create_uuid_c32_static( ).
    CATCH cx_uuid_error INTO DATA(lx_uuid).
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_tech_exception EXPORTING previous = lx_uuid.
  ENDTRY.
  ls_attach-file_name = iv_slug.                   " header 'slug'
  ls_attach-mime_type = is_media_resource-mime_type.
  ls_attach-content   = is_media_resource-value.
  INSERT zattach FROM @ls_attach.
  DATA(ls_entity) = CORRESPONDING zcl_zsales_mpc=>ts_attachment( ls_attach ).
  copy_data_to_ref( EXPORTING is_data = ls_entity CHANGING cr_data = er_entity ).
ENDMETHOD.
```

PDF forms (Adobe/SmartForms) for Fiori apps are typically delivered this way: generate the PDF as XSTRING in `GET_STREAM` and return `application/pdf`.

## ETags – optimistic concurrency

An **ETag** is a version stamp (e.g. last-changed timestamp). The client sends it back in the `If-Match` header on PUT/DELETE; if the server's current value differs, the update is rejected with **412 Precondition Failed** – preventing "lost updates".

- In SEGW select the entity type → property `ChangedAt` → set as **ETag** (*Entity Type → Properties → ETag*).
- The framework compares `If-Match` with the value read by **GET_ENTITY** (so GET_ENTITY must return the current timestamp).
- UI5 handles ETags automatically.

## Soft state, caching and annotations (brief)

- **Soft state** – keeps the backend session alive between requests for a short time (redefine `/IWBEP/IF_MGW_SOST_SRV_RUNTIME~OPERATION_START/END`); useful for expensive buffers. Use carefully.
- **Annotations** – add UI semantics (labels, value helps, Fiori elements UI annotations) in `MPC_EXT->DEFINE` or via an annotation model (SEGW *Service with Vocabulary-Based Annotations*) – in modern development you put them in CDS metadata extensions instead.
- **Value help** – `sap:value-list` / `Common.ValueList` annotations pointing to a value-help entity set.

:::lab Lab 19 – Header/Item service with deep insert
Extend your service with entity `OrderItem` (VBAP: VBELN, POSNR, MATNR, KWMENG, NETWR), association `Order_Items` (1:n) with navigation `ToItems`. Implement: (a) items via navigation, (b) `GET_EXPANDED_ENTITYSET` for `$expand=ToItems`, (c) `CREATE_DEEP_ENTITY` that creates a custom header table `ZORD_H` and item table `ZORD_I` (no BAPI needed) and returns the new order number from a number range or `MAX+1`, (d) function import `GetOrderTotal` (GET, parameter OrderId, returns complex type `Total` with Amount and Currency).
:::

:::solution Lab 19 (key parts)
```abap
" (c) deep insert into custom tables
METHOD /iwbep/if_mgw_appl_srv_runtime~create_deep_entity.
  TYPES: BEGIN OF ty_deep.
           INCLUDE TYPE zcl_zorder_mpc=>ts_order.
  TYPES:   toitems TYPE zcl_zorder_mpc=>tt_orderitem,
         END OF ty_deep.
  DATA ls_deep TYPE ty_deep.

  io_data_provider->read_entry_data( IMPORTING es_data = ls_deep ).
  IF ls_deep-toitems IS INITIAL.
    RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
      EXPORTING message = 'An order needs at least one item'.
  ENDIF.

  SELECT MAX( vbeln ) FROM zord_h INTO @DATA(lv_last).
  DATA lv_num TYPE n LENGTH 10.
  lv_num = lv_last + 1.                    " keeps leading zeros
  ls_deep-vbeln = lv_num.
  ls_deep-netwr = REDUCE #( INIT s = CONV netwr_ap( 0 )
                            FOR i IN ls_deep-toitems NEXT s = s + i-netwr ).

  DATA(ls_head)  = CORRESPONDING zord_h( ls_deep ).
  DATA(lt_items) = VALUE zord_i_tt( FOR i IN ls_deep-toitems
                     ( CORRESPONDING #( i ) ) ).
  LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<i>).
    <i>-vbeln = ls_deep-vbeln.
    <i>-posnr = sy-tabix * 10.
  ENDLOOP.
  INSERT zord_h FROM @ls_head.
  INSERT zord_i FROM TABLE @lt_items.

  ls_deep-toitems = CORRESPONDING #( lt_items ).
  copy_data_to_ref( EXPORTING is_data = ls_deep CHANGING cr_data = er_deep_entity ).
ENDMETHOD.

" (d) function import returning a complex type
METHOD /iwbep/if_mgw_appl_srv_runtime~execute_action.
  DATA ls_total TYPE zcl_zorder_mpc=>ts_total.  " generated complex type (check name in MPC)
  IF iv_action_name = 'GetOrderTotal'.
    DATA(lv_id) = CONV vbeln( it_parameter[ name = 'OrderId' ]-value ).
    SELECT SINGLE netwr, waerk FROM zord_h WHERE vbeln = @lv_id
      INTO (@ls_total-amount, @ls_total-currency).
    copy_data_to_ref( EXPORTING is_data = ls_total CHANGING cr_data = er_data ).
  ENDIF.
ENDMETHOD.
```
```text
POST .../OrderSet
{"Customer":"100001","Currency":"EGP","ToItems":[{"Material":"M1","Quantity":"2","NetAmount":"100.00"}]}
GET  .../GetOrderTotal?OrderId='0000000001'
```
`zord_i_tt` is a table type of `ZORD_I` created in SE11 (or declare a local `TYPES ... TABLE OF zord_i`).
:::
