# REQ1 changes on the NEW (OOP) YSDA / YSDAX code

The OOP conversion (`YSDA/new`, `YSDAX/new`) is the old logic only – **it contains no REQ1 change yet**.
This file lists the REQ1 changes for the new code. They are the same changes as C1–C7 / D1–D6 in
`03_changed_objects/CHANGES_TO_EXISTING_OBJECTS.md` (which are written for the old includes).

All REQ1 changes are in the include **`_C01`** (class implementations) only. `_TOP`, `_M01`, the main program,
screens and GUI status need **no** REQ1 change. Every changed line is marked `REQ1`.

For checking: `YSDA/new_with_REQ1/YSP_MTOSO_APPROVE_C01.abap` and `YSDAX/new_with_REQ1/YSP_MTOSO_APPROVE_CX_C01.abap`
show the `_C01` include with all changes already applied (compare them with the `new` version).

## Which version to use

| Your situation | Apply |
|---|---|
| You keep the old YSDA / YSDAX code | C1–C7 and D1–D6 in `CHANGES_TO_EXISTING_OBJECTS.md` |
| You install the OOP conversion first | the conversion (`README.md`) and then the changes below (N1–N7, X1–X6) |

Do **not** apply both.

## Summary – what REQ1 changes in YSDA / YSDAX

| YSDA | YSDAX | Method | What |
|---|---|---|---|
| N1 | X1 | `LOAD_ROWS` | lines approved by SD + FI are hidden (they stay CN during the credit workflow) |
| N2 | X2 | `APPROVE` | each selected row starts clean (tables, flags, log note) |
| N3 | – | `APPROVE` (FI branch) | FI approval alone no longer sets CN → CP (YSDAX never did) |
| N4 + N5 | X3 + X4 | `APPROVE` (both approved) | release cycle decides: CN → CP now, or credit workflow (started automatically) |
| N6 | X5 | `REJECT` | each selected row starts clean |
| N7 | X6 | `REJECT` | release cycle is told – last open line → credit workflow starts |

## YSDA – include `YSP_MTOSO_APPROVE_C01`

### N1 – INSERT AFTER (method `LOAD_ROWS`, = C1)

Lines already approved by SD and FI are not shown again (they stay CN while the credit workflow runs).

**Find:**
```abap
    LOOP AT lt_db INTO DATA(ls_db).
```

**Result (the find text + the new lines):**
```abap
    LOOP AT lt_db INTO DATA(ls_db).
      " REQ1: line already approved by SD and FI - it stays CN while the
      "       credit workflow runs, but must not be shown again
      SELECT SINGLE @abap_true FROM zsoapproval
        WHERE vbeln      = @ls_db-so_num
          AND posnr      = @ls_db-posnr
          AND sd_approve = @abap_true
          AND fi_approve = @abap_true
        INTO @DATA(lv_rel_approved).
      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.
```

### N2 – INSERT AFTER the READ TABLE line (method `APPROVE`, = C2)

Every selected row starts with empty BAPI tables, flags and log note (fixes old behaviour 1, 3, 4).

**Find:**
```abap
      READ TABLE mt_out INTO ls_row INDEX ls_index-index.

      " T00002246: the approver role (SD / FI) depends on the plant
```

**Result (the find text + the new lines):**
```abap
      READ TABLE mt_out INTO ls_row INDEX ls_index-index.

      " REQ1: every selected row starts clean (the tables kept the lines of
      "       the previous row and sent them again)
      CLEAR: lt_item_in, lt_item_inx, lt_schdl, lt_schdlx, lt_return,
             ms_log, mv_sd_approve, mv_fi_approve.

      " T00002246: the approver role (SD / FI) depends on the plant
```

### N3 – REPLACE (method `APPROVE, WHEN 'FI'`, = C3 + C4)

FI approval alone no longer sets CN -> CP. The Z8 rejection reason is still removed.

**Find:**
```abap
              add_cp_schedule_lines( EXPORTING is_row    = ls_row
                                     CHANGING  ct_schdl  = lt_schdl
                                               ct_schdlx = lt_schdlx ).

              CALL FUNCTION 'BAPI_SALESORDER_CHANGE' "#EC CI_USAGE_OK[2438131]
                EXPORTING
                  salesdocument    = ls_row-so_num
                  order_header_inx = ls_header_inx
                TABLES
                  return           = lt_return
                  order_item_in    = lt_item_in
                  order_item_inx   = lt_item_inx
                  schedule_lines   = lt_schdl
                  schedule_linesx  = lt_schdlx.
```

**Change to:**
```abap
              " REQ1: FI approval alone does not release production (CN stays);
              "       only the Z8 rejection is removed
              CALL FUNCTION 'BAPI_SALESORDER_CHANGE' "#EC CI_USAGE_OK[2438131]
                EXPORTING
                  salesdocument    = ls_row-so_num
                  order_header_inx = ls_header_inx
                TABLES
                  return           = lt_return
                  order_item_in    = lt_item_in
                  order_item_inx   = lt_item_inx.
```

### N4 – INSERT AFTER (method `APPROVE`, = C5)

Both approvals done: for an order of the release cycle the class decides (CN -> CP now, or the credit workflow starts / waits). The old CP logic runs only for orders outside the cycle.

**Find:**
```abap
      IF mv_sd_approve = abap_true AND mv_fi_approve = abap_true.
```

**Result (the find text + the new lines):**
```abap
      IF mv_sd_approve = abap_true AND mv_fi_approve = abap_true.

        " REQ1: order of the release cycle -> the cycle decides
        "       (this line CN -> CP now, or after the credit workflow)
        DATA(lo_release) = NEW zcl_sd_so_release( ).
        IF lo_release->on_item_decision( ls_row-so_num ) = abap_true.
          ms_log-note = lo_release->get_item_status_text( iv_vbeln = ls_row-so_num
                                                          iv_posnr = ls_row-posnr ).
          MESSAGE |{ ls_row-so_num ALPHA = OUT }/{ ls_row-posnr ALPHA = OUT }: { ms_log-note }| TYPE 'S'.
        ELSE.
        " order not in the release cycle: old logic below
```

### N5 – INSERT AFTER (method `APPROVE`, = C5 (end))

Closes the IF of the previous change. The log row APPROVAL is written in both cases.

**Find:**
```abap
        LOOP AT lt_return INTO DATA(ls_return) WHERE id = 'V1'.
          MESSAGE ls_return-message(100) TYPE 'I'.
          ms_log-note = ls_return-message(100).
        ENDLOOP.
```

**Result (the find text + the new lines):**
```abap
        LOOP AT lt_return INTO DATA(ls_return) WHERE id = 'V1'.
          MESSAGE ls_return-message(100) TYPE 'I'.
          ms_log-note = ls_return-message(100).
        ENDLOOP.
        ENDIF.                                                 " REQ1
```

### N6 – INSERT AFTER the READ TABLE line (method `REJECT`, = C6)

Every selected row starts with empty BAPI tables and log note.

**Find:**
```abap
      READ TABLE mt_out INTO ls_row INDEX ls_index-index.

      APPEND VALUE #( itm_number = ls_row-posnr
                      reason_rej = gc_rej_manual ) TO lt_item_in.
```

**Result (the find text + the new lines):**
```abap
      READ TABLE mt_out INTO ls_row INDEX ls_index-index.

      " REQ1: every selected row starts clean
      CLEAR: lt_item_in, lt_item_inx, lt_return, ms_log.

      APPEND VALUE #( itm_number = ls_row-posnr
                      reason_rej = gc_rej_manual ) TO lt_item_in.
```

### N7 – INSERT AFTER (method `REJECT`, = C7)

The release cycle is told about the rejection (last open line -> credit workflow starts automatically).

**Find:**
```abap
      LOOP AT lt_return INTO DATA(ls_return).
        MESSAGE ls_return-message(100) TYPE 'I'.
        ms_log-note = ls_return-message(100).
      ENDLOOP.
```

**Result (the find text + the new lines):**
```abap
      LOOP AT lt_return INTO DATA(ls_return).
        MESSAGE ls_return-message(100) TYPE 'I'.
        ms_log-note = ls_return-message(100).
      ENDLOOP.

      " REQ1: line rejected - if it was the last open line of a blocked
      "       order, the credit workflow starts for the approved lines
      NEW zcl_sd_so_release( )->on_item_decision( ls_row-so_num ).
```

## YSDAX – include `YSP_MTOSO_APPROVE_CX_C01`

### X1 – INSERT AFTER (method `LOAD_ROWS`, = D1)

Lines already approved by SD and FI are not shown again (they stay CN while the credit workflow runs).

**Find:**
```abap
    LOOP AT lt_db INTO DATA(ls_db).
```

**Result (the find text + the new lines):**
```abap
    LOOP AT lt_db INTO DATA(ls_db).
      " REQ1: line already approved by SD and FI - it stays CN while the
      "       credit workflow runs, but must not be shown again
      SELECT SINGLE @abap_true FROM zsoapproval
        WHERE vbeln      = @ls_db-so_num
          AND posnr      = @ls_db-posnr
          AND sd_approve = @abap_true
          AND fi_approve = @abap_true
        INTO @DATA(lv_rel_approved).
      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.
```

### X2 – INSERT AFTER the READ TABLE line (method `APPROVE`, = D2 + first part of D3)

Every selected row starts with empty BAPI tables, flags and log note (fixes old behaviour 1, 3, 4).

**Find:**
```abap
      READ TABLE mt_out INTO ls_row INDEX ls_index-index.

      " T00002246: the approver role (SD / FI) depends on the plant
```

**Result (the find text + the new lines):**
```abap
      READ TABLE mt_out INTO ls_row INDEX ls_index-index.

      " REQ1: every selected row starts clean (the tables kept the lines of
      "       the previous row and sent them again)
      CLEAR: lt_schdl, lt_schdlx, lt_return,
             ms_log, mv_sd_approve, mv_fi_approve.

      " T00002246: the approver role (SD / FI) depends on the plant
```

### X3 – INSERT AFTER (method `APPROVE`, = D3)

Both approvals done: for an order of the release cycle the class decides (CN -> CP now, or the credit workflow starts / waits). The old CP logic runs only for orders outside the cycle.

**Find:**
```abap
      IF mv_sd_approve = abap_true AND mv_fi_approve = abap_true.
```

**Result (the find text + the new lines):**
```abap
      IF mv_sd_approve = abap_true AND mv_fi_approve = abap_true.

        " REQ1: order of the release cycle -> the cycle decides
        "       (this line CN -> CP now, or after the credit workflow)
        DATA(lo_release) = NEW zcl_sd_so_release( ).
        IF lo_release->on_item_decision( ls_row-so_num ) = abap_true.
          ms_log-note = lo_release->get_item_status_text( iv_vbeln = ls_row-so_num
                                                          iv_posnr = ls_row-posnr ).
          MESSAGE |{ ls_row-so_num ALPHA = OUT }/{ ls_row-posnr ALPHA = OUT }: { ms_log-note }| TYPE 'S'.
        ELSE.
        " order not in the release cycle: old logic below
```

### X4 – INSERT AFTER (method `APPROVE`, = D4)

Closes the IF of the previous change. The log row APPROVAL is written in both cases.

**Find:**
```abap
        LOOP AT lt_return INTO DATA(ls_return) WHERE id = 'V1'.
          MESSAGE ls_return-message(100) TYPE 'I'.
          ms_log-note = ls_return-message(100).
        ENDLOOP.
```

**Result (the find text + the new lines):**
```abap
        LOOP AT lt_return INTO DATA(ls_return) WHERE id = 'V1'.
          MESSAGE ls_return-message(100) TYPE 'I'.
          ms_log-note = ls_return-message(100).
        ENDLOOP.
        ENDIF.                                                 " REQ1
```

### X5 – INSERT AFTER the READ TABLE line (method `REJECT`, = D5)

Every selected row starts with empty BAPI tables and log note.

**Find:**
```abap
      READ TABLE mt_out INTO ls_row INDEX ls_index-index.

      APPEND VALUE #( itm_number = ls_row-posnr
                      reason_rej = gc_rej_manual ) TO lt_item_in.
```

**Result (the find text + the new lines):**
```abap
      READ TABLE mt_out INTO ls_row INDEX ls_index-index.

      " REQ1: every selected row starts clean
      CLEAR: lt_item_in, lt_item_inx, lt_return, ms_log.

      APPEND VALUE #( itm_number = ls_row-posnr
                      reason_rej = gc_rej_manual ) TO lt_item_in.
```

### X6 – INSERT AFTER (method `REJECT`, = D6)

The release cycle is told about the rejection (last open line -> credit workflow starts automatically).

**Find:**
```abap
      LOOP AT lt_return INTO DATA(ls_return).
        MESSAGE ls_return-message(100) TYPE 'I'.
        ms_log-note = ls_return-message(100).
      ENDLOOP.
```

**Result (the find text + the new lines):**
```abap
      LOOP AT lt_return INTO DATA(ls_return).
        MESSAGE ls_return-message(100) TYPE 'I'.
        ms_log-note = ls_return-message(100).
      ENDLOOP.

      " REQ1: line rejected - if it was the last open line of a blocked
      "       order, the credit workflow starts for the approved lines
      NEW zcl_sd_so_release( )->on_item_decision( ls_row-so_num ).
```

## After applying

1. Activate the `_C01` include.
2. Check: `ZCL_SD_SO_RELEASE` must exist and be active (step 4 of the implementation guide).
3. Run tests 1–8a and 21 of the implementation guide in YSDA and YSDAX.
