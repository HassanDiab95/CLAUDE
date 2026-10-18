# Fix 01 — no running work item, no kill

**Status: APPLIED** in `02_core_classes/ZCL_WF_SD_CREDIT.abap`.

## Problem

`KILL_RUNNING_WORKFLOW` ran `CLOSE_OPEN_LOGS` and
`DELETE FROM ZSD_WF_SO` unconditionally, even when `FIND_RUNNING`
returned an empty table. A second save in the same transaction then
closed the log of the workflow the first save had just started, and
removed the lock, while no work item was touched.

## Change — signature

```abap
    METHODS KILL_RUNNING_WORKFLOW
      IMPORTING
        !IV_VBELN        TYPE VBELN_VA
        !IV_REASON       TYPE STRING OPTIONAL
        !IV_FORCE        TYPE ABAP_BOOL DEFAULT ABAP_FALSE
      RETURNING
        VALUE(RV_KILLED) TYPE ABAP_BOOL .
```

## Change — implementation, after `ENDLOOP.`

```abap
    IF LT_WI IS INITIAL AND IV_FORCE = ABAP_FALSE.
      RETURN.
    ENDIF.
```

## Who passes IV_FORCE

Only `ZSD_WF_RESTART`, kill-only mode (`P_KILL`), where the whole point
is to clean up logs and the lock even when no work item is left. Every
other caller — the MV45AFZZ exit above all — uses the default.
