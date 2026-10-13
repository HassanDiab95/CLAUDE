# ZMM_WEBRE_CORRECTION – set GR-based IV on POs with existing history

Correction report for the case described in the SAP incident reply / SAP note 457511:
PO items were posted **without** "GR-based IV" (EKPO-WEBRE), and the indicator must now be
set even though goods receipts and invoices already exist.

> This is a direct table update outside SAP standard. SAP will not support it.
> It must be reviewed by an MM consultant, tested in QA on a copy of production
> data, and run in production only with business and audit sign-off.

## What the report changes

For each selected PO item with `EKPO-WEBRE = ' '`:

| Table | Fields | Value |
|---|---|---|
| EKBE (all GR/IR lines) | LFGJA, LFBNR, LFPOS | year / number / item of the original GR |
| MSEG (ECC) or MATDOC (S/4HANA) | LFBJA, LFBNR, LFPOS | same as EKBE |
| RSEG (invoices, subsequent debits) | LFGJA, LFBNR, LFPOS | same as EKBE |
| EKPO | WEBRE | `X` |

S/4HANA is detected automatically (table MATDOC exists → MATDOC is updated; MSEG is only read).

## How references are derived

1. **Original GR (101)** → references itself.
2. **Cancellations (102, 123, …)** → reference of the document in MSEG-SMBLN/SJAHR/SMBLP.
3. **Return/reversal without document reference** → linked only if the item has exactly **one** original GR.
4. **Invoices**
   - Item has one GR → all invoices, credit memos and subsequent debits get that GR.
   - Item has several GRs →
     - an invoice reversal (MR8M, linked through RBKP-STBLG) gets the same reference as the invoice it reverses;
     - every other invoice is assigned FIFO to the first GR whose open (not yet invoiced) quantity **exactly** matches the invoice quantity.
5. **Final check:** for each GR, the invoiced quantity must not be more than the received quantity.

**All or nothing per item.** If any line can't be derived unambiguously, the item is reported as
`MANUAL` and nothing is changed for it.

### Items always left for manual correction
- no GR indicator (WEPOS), multiple account assignment (VRTKZ), service items (PSTYP 9)
- movement types other than 101/102/122/123 (e.g. 103/105 blocked stock)
- PO history categories other than GR (1), IR (2), subsequent debit (3)
- delivery costs (EKBZ), archived/compressed history (EKBEH)
- invoices that are parked/held (RBKP-RBSTAT not 5 posted / 2 deleted)
- partial invoices or invoices covering several GRs (no exact quantity match)

## Safety features
- Test mode by default (ALV simulation of old → new references); update run asks for confirmation.
- Authorization check M_BEST_BSA (ACTVT 02).
- PO lock (EMEKKOE). Under the lock the report checks again that WEBRE and the number of EKBE lines haven't changed.
- MSEG/MATDOC/RSEG lines are only overwritten if they still hold the EKBE value (or already the target value). Otherwise the item is rolled back.
- One LUW per PO item: COMMIT if everything succeeded, ROLLBACK otherwise.
- Before images of every changed line are written to **ZMM_WEBRE_BKP**.

## Prerequisite: table ZMM_WEBRE_BKP (SE11)

Delivery class A, no buffering, size category 0.

| Field | Key | Typed like |
|---|---|---|
| MANDT | X | MANDT |
| EBELN | X | EKBE-EBELN |
| EBELP | X | EKBE-EBELP |
| VGABE | X | EKBE-VGABE |
| GJAHR | X | EKBE-GJAHR |
| BELNR | X | EKBE-BELNR |
| BUZEI | X | EKBE-BUZEI |
| RUN_TS | X | TIMESTAMPL |
| UNAME | | SYUNAME |
| OLD_LFGJA | | EKBE-LFGJA |
| OLD_LFBNR | | EKBE-LFBNR |
| OLD_LFPOS | | EKBE-LFPOS |
| NEW_LFGJA | | EKBE-LFGJA |
| NEW_LFBNR | | EKBE-LFBNR |
| NEW_LFPOS | | EKBE-LFPOS |

To undo a run, write OLD_* back to EKBE, MSEG/MATDOC and RSEG for the backed-up keys.
Then reset EKPO-WEBRE to blank for the affected items.

## Recommended procedure
1. Create ZMM_WEBRE_BKP and the report in DEV, then transport to QA.
2. In QA (with a recent copy of production data), run in **test mode** for the affected POs. Review every `SIMULATED` and `MANUAL` line with the MM consultant.
3. Run the update in QA, then verify per item:
   - ME23N → PO history shows the GR reference on GRs and invoices.
   - MIRO (simulate only) → invoice proposal per GR, with correct open quantities.
   - MR11 (test run) and MB5S → GR/IR balances unchanged and plausible.
   - MIGO return (122) with reference to a corrected GR → simulate only.
4. Handle `MANUAL` items by reversing and reposting, or by closing the item and creating a new PO line with GR-based IV.
5. Run in production in test mode, compare with the QA result, then do the update run and keep the ALV output as evidence.
6. Stop the problem coming back: default GR-based IV in the vendor master and make the field mandatory (field selection or BAdI ME_PROCESS_PO_CUST).
