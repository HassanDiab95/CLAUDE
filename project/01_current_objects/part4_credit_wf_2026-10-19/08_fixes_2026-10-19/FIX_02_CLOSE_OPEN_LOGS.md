# Fix 02 — CLOSE_OPEN_LOGS must not close a log born in this save

**Status: APPLIED** in `02_core_classes/ZCL_WF_SD_CREDIT.abap`.

## Problem

Both selects matched on `VBELN` + `STATUS = 'I'` with nothing to
distinguish the run being killed from a run that started moments ago in
the same transaction.

## Change

At the top of `CLOSE_OPEN_LOGS`:

```abap
    DATA LV_ON TYPE DATS.
    DATA LV_AT TYPE TIMS.

    LV_ON = SY-DATUM.
    LV_AT = SY-UZEIT.
```

and on both selects:

```abap
        AND NOT ( STARTED_ON = @LV_ON AND STARTED_AT >= @LV_AT )
```

## Limitation

Second granularity. Two runs started inside the same second on different
days are not an issue, but a genuine kill issued in the same second as a
legitimately older log would skip it. In practice the older log is at
least one second old, and Fix 01 already prevents the common case.
