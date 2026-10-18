# Fix 03 — `ADD_ITEM` must refuse a closed log

**Status: NOT APPLIED in this package.** `ZCL_WF_LOG_EX`, `ZCL_WF_LOG_OD` and
`ZCL_WF_LOG_CL` were never shared in the session, so the change could not be
made for you. Apply it by hand in all three classes.

## Why

On 04.10.2026 logs 1612 (EX) and 1815 (OD) were set to status `K` (Killed)
at 19:55:16, and still collected `MAIL` (19:55:17) and two `APPR` rows on
05.10. `ADD_ITEM` appends without ever looking at the header status, so a
closed log keeps growing and the report shows a killed workflow that is
being approved.

Fixes 01, 02 and 04 stop the wrong log from being closed in the first place.
This fix is the last line of defence: even if a log is closed for a genuine
reason, nothing may be written to it afterwards.

## Change — `ZCL_WF_LOG_EX->ADD_ITEM`

Insert at the very top of the method, before the `SEQNR` is determined and
before the `INSERT` into `ZWF_LOG_EX_I`:

```abap
*--- Begin of Enhancement | Hassan Diab | 19.10.2026 | closed log -----
*   A log that is no longer In Process must not receive further rows.
*   RELS is the exception: the release row is written after FINISH has
*   already set the header to Approved.
    SELECT SINGLE STATUS FROM ZWF_LOG_EX_H
      WHERE LOG_ID = @IV_LOG_ID
      INTO @DATA(LV_HDR_STATUS).

    IF SY-SUBRC <> 0.
      RETURN.
    ENDIF.

    IF LV_HDR_STATUS <> GC_STATUS-IN_PROCESS
   AND IV_ACTION     <> GC_ACTION-RELEASE.
      RETURN.
    ENDIF.
*--- End of Enhancement -----------------------------------------------
```

## The same change in the other two classes

| Class            | Header table     | Item table       |
|------------------|------------------|------------------|
| `ZCL_WF_LOG_EX`  | `ZWF_LOG_EX_H`   | `ZWF_LOG_EX_I`   |
| `ZCL_WF_LOG_OD`  | `ZWF_LOG_OD_H`   | `ZWF_LOG_OD_I`   |
| `ZCL_WF_LOG_CL`  | `ZWF_LOG_CL_H`   | `ZWF_LOG_CL_I`   |

## Verify before you transport

Check the call order inside `ADD_ITEM` / `FINISH` for every closing action.
In the current code `CANCEL_SO`, `REJECT_IN_LOOP` and `CLOSE_OPEN_LOGS` all
call `ADD_ITEM` **first** and `FINISH` **second**, so the row is written
while the header is still `I` and the guard does not block them. Only
`RELEASE_SO` writes after a `FINISH` in some paths, which is why `RELS` is
exempted above.

If any of your own call sites write after `FINISH`, add that action to the
exemption or move the `ADD_ITEM` call before the `FINISH`.
