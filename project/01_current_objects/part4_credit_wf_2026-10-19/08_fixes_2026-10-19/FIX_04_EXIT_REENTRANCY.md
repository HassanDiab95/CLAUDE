# Fix 04 — MV45AFZZ must not fire twice for the same document

**Status: APPLIED** in `07_enhancements/MV45AFZZ_USEREXIT_SAVE_DOCUMENT.abap`.

## Problem

`USEREXIT_SAVE_DOCUMENT` fires on every save. YSDA saves the order twice
in one transaction. On the second save the `ZSD_WF_SO` row inserted by
the first save's workflow made `IS_ORDER_LOCKED` return true, so the kill
ran against a run that had just started.

Also removed: `BREAK SNAG_HASSAN.` — a hard breakpoint in a production
user exit. It stops the save in dialog and can dump in a background or
update work process.

## Change

```abap
  STATICS LT_DONE TYPE SORTED TABLE OF VBELN_VA WITH UNIQUE DEFAULT KEY.

  CHECK ( T180-TRTYP = 'V' AND T180-TCODE = 'VA02' )
     AND VBAK-VBELN IS NOT INITIAL.

  READ TABLE LT_DONE TRANSPORTING NO FIELDS
       WITH KEY TABLE_LINE = VBAK-VBELN.
  CHECK SY-SUBRC <> 0.

  DATA(LO_CREDIT) = NEW ZCL_WF_SD_CREDIT( ).
  CHECK LO_CREDIT->IS_ORDER_LOCKED( VBAK-VBELN ) = ABAP_TRUE.

  INSERT VBAK-VBELN INTO TABLE LT_DONE.
```

## Why Fix 01 is still needed

`STATICS` lives in the roll area. If the two saves land in different work
processes, or the Z program splits them into separate LUWs, the flag is
gone. Fix 01 holds in every case. Keep both.

## Note on T180-TCODE

`T180-TCODE = 'VA02'` is the internal SD processing transaction and stays
`VA02` even when the user runs the Z transaction YSDA — that is why the
log note reads "changed in YSDA" while this check passes. If a Z program
ever sets a different `T180-TCODE`, the kill silently stops firing. If
that happens, fall back to `T180-TRTYP = 'V'` alone.
