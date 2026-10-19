# 1. Purpose

YSDA and YSDAX are the approval cockpits for **make-to-order production lines**. A sales order line that
has to be produced is created with schedule line category **CN** (production blocked). Before production
may start, every line must be checked for **cost / profit** and **customer credit**, and approved by two
people: one from **Sales (SD)** and one from **Finance (FI)**. Only then is the line released to
production (schedule line **CN → CP**).

| | YSDA | YSDAX |
|---|---|---|
| Program | `YSP_MTOSO_APPROVE` | `YSP_MTOSO_APPROVE_CX` |
| Plants | 1200, 1202, 1500, 1501 | 1600, 1400 |
| Credit segment | `WFICS` | `CPXCS` |
| Automatic rejection Z8 | **yes** | no |
| Contribution profit (variable cost from product costing) | no | **yes** (display only) |
| Lines that already have sales order stock | shown | **hidden** |
| Extra columns | weights, quantities, subtotals, pipe / paper characteristics, price per MT, gross margin %, overdue, payment terms | – |

Both programs are built the same way (OOP, includes TOP / C01 / M01) and use the same tables:

| Table | Use |
|---|---|
| `ZSOAPPROVAL` | One row per order line: `SD_APPROVE`, `FI_APPROVE` (X = approved) with date and time of each approval |
| `ZAPPROVEUSER` | Who may approve: user + plant → position `SD` or `FI` |
| `YSP_MTOSO_LOG` | Log of every approval, rejection and "not authorized" attempt |
| `ZSD_SO_REL_H` / `_I` / `_LOG` | Release cycle (REQ1): status of the order and of each production line, called from YSDA/YSDAX after every decision |

# 2. How the program works – step by step

## 2.1 Selection screen

| Field | Meaning |
|---|---|
| Plant (`BUKRS`) | Plant of the order line (`VBAP-WERKS`) |
| Date from / to | Document date of the order (`VBAK-AUDAT`) |

The user needs authorization object `M_MSEG_WWA` for the plant; otherwise "You Dont have authorization"
and the list does not open.

## 2.2 Which lines are shown

A line is shown when **all** conditions are true:

| Condition | YSDA | YSDAX |
|---|---|---|
| Plant = selection plant | yes | yes |
| Schedule line category | `CN` | `CN` |
| Item category | 1200 / 1202: `ZTAW` or `ZFRE`; 1500 / 1501: `ZTAC` or `ZFRE` | 1600: `YZTC` or `YFRE`; 1400: any |
| Order type | any | 1400: `ZEM`, `ZMT`, `ZOR`, `ZFC`; 1600: any |
| Rejection | not rejected, **or** rejected with `Z8` (automatic rejection, see 3.3) | item not fully rejected (`ABSTA <> C`) |
| Document | sales order or free-of-charge order (`VBTYP` C / I) | same |
| Document date | in the selected range | same |
| Already approved by SD **and** FI in `ZSOAPPROVAL` | **hidden** (REQ1) | **hidden** (REQ1) |
| Sales order stock exists (`MSKA`) | – | **hidden** |

Hiding the fully approved lines (REQ1) is needed because a line of a credit-blocked order stays on CN
after approval until the credit workflow ends; without this rule it would come back into the list.

## 2.3 What is calculated for each line

**Cost and profit**

- Total cost = cost of the line (`VBAP-WAVWR`) + conditions `ZBPC` and `ZOVC` of the line.
- Profit = net value of the line − total cost.
- YSDAX also shows the **contribution profit** = net value − variable cost (`KEPH-KST001…KST004` of the
  product cost estimate). It is only displayed; the decision uses the normal profit.

**Profit status**

| Situation | Profit status | Colour |
|---|---|---|
| Total cost = 0 | **COST ERROR** | red |
| Profit < 0 | **Loss** | red |
| Profit ≥ 0 | **Profit** | – |

**Credit status** (customer credit limit from `UKMBP_CMS_SGM`, exposure from `UKM_COMMTS_BUPA_DISPLAY`
for the segment of the program)

| Situation | Credit status | Colour |
|---|---|---|
| Customer has no credit segment | Not related to Credit Managment | yellow |
| Exposure > credit limit | **Exceed the limit** | red |
| Exposure ≤ credit limit | Did not Exceed | – |

## 2.4 The automatic FI decision

The FI column is proposed automatically from profit and credit:

| Profit status | Credit status | FI proposal |
|---|---|---|
| Profit | Did not Exceed / not related | **Approved** |
| Profit | **Exceed the limit** | **Not Approved** |
| Loss | any | **Not Approved** |
| COST ERROR | any | **Not Approved** |

**When the proposal is stored:** the first time a line appears in YSDA/YSDAX it has no row in
`ZSOAPPROVAL` yet. The program creates the row now:

- `FI_APPROVE = X` when the FI proposal is **Approved**, otherwise empty;
- `SD_APPROVE` always empty (SD must always approve by hand).

From then on the **stored flags** decide what the list shows (SD / FI "Approved" or "Not Approved").
The proposal is not calculated again for that line, even if cost or credit change later.

## 2.5 Buttons

**Approve** (rows selected in the list). The user's position comes from `ZAPPROVEUSER` for the plant:

| Position | What happens |
|---|---|
| `SD` | `SD_APPROVE = X` with date / time in `ZSOAPPROVAL` |
| `FI` | `FI_APPROVE = X` with date / time. **YSDA only:** the rejection reason of the line is cleared (removes an automatic `Z8`) |
| not in `ZAPPROVEUSER` | Message "You are not Authorized to Approve", log entry `not Authorized`, nothing changes |

After each approval the program reads `ZSOAPPROVAL` again. **When SD and FI are both approved**, the line
goes to the release step (chapter 2.6), and the log gets an `APPROVAL` entry.

**Reject:** only for users in `ZAPPROVEUSER`. The line gets rejection reason **63** and stays on CN; it is
never produced. The release cycle is informed (the line counts as "decided – rejected"), log entry `REJECT`.

**Display:** opens the selected orders in VA03.

After Approve or Reject the list is loaded again.

## 2.6 Release to production after SD + FI approval (with REQ1)

YSDA/YSDAX call `ZCL_SD_SO_RELEASE->ON_ITEM_DECISION` for the order.

| Order | What happens to the approved line |
|---|---|
| **Not in the release cycle** (created before the go-live date `ZSD_SO_REL_START_DATE`, or not a production order) | As before REQ1: YSDA/YSDAX change the line **CN → CP** directly. Message of the BAPI is shown |
| In the release cycle, **no credit block** (`CMGST <> B`) | The line goes **CN → CP at once**, by itself, independent of the other lines |
| In the release cycle, **credit block** (`CMGST = B`: credit limit exceeded and/or overdue) | The line **stays CN**. When **every** production line of the order is decided (approved or rejected) and at least one is approved, the credit workflow **WS99000010** starts automatically |

Credit workflow result (orders with credit block):

| Credit workflow | Result |
|---|---|
| **Final approval** | Exactly the lines approved in YSDA/YSDAX go **CN → CP**. Lines rejected in YSDA/YSDAX stay CN |
| **Rejected** | No line is released. Every line is recorded as YSDA/YSDAX decided it, then the existing step `CANCEL_SO` cancels the order |
| All lines rejected in YSDA/YSDAX | No credit workflow starts |

The status of each line is shown as a message after the approval, e.g. "Approved – credit approval starts
when all items are decided", "Released to production (CP)", "Rejected in YSDA/YSDAX (reason 63) – stays CN".

# 3. Scenarios: order with profit and order with loss

## 3.1 Order line with profit, credit not exceeded

| Step | YSDA | YSDAX |
|---|---|---|
| 1. Line appears | Profit status **Profit**, FI **Approved** (stored in `ZSOAPPROVAL`), SD **Not Approved** | same |
| 2. FI user | nothing to do (already approved) | same |
| 3. SD user approves | SD + FI approved → release step | same |
| 4. No credit block | Line **CN → CP** at once; line disappears from the list | same |
| 4. Credit block on the order | Line stays CN and disappears from the list; workflow starts when all lines are decided; CP at final approval | same |

**Result:** only **one** manual approval (SD) is needed.

## 3.2 Order line with profit, but customer over the credit limit

| Step | YSDA | YSDAX |
|---|---|---|
| 1. Line appears | Profit **Profit**, credit **Exceed the limit**, FI **Not Approved**, SD **Not Approved** | same |
| 2. Automatic rejection | Line gets rejection reason **Z8** (stays in the list) | – (no automatic rejection) |
| 3. FI user approves | `FI_APPROVE = X`, **Z8 removed** | `FI_APPROVE = X` |
| 4. SD user approves | Both approved → release step (2.6) | same |

Because the customer is over the limit, the order normally also has a **credit block**, so the line stays
CN until the credit workflow WS99000010 approves the order.

**Result:** **two** manual approvals (FI and SD), then the credit workflow.

## 3.3 Order line with loss

| Step | YSDA | YSDAX |
|---|---|---|
| 1. Line appears | Profit status **Loss** (red), FI **Not Approved**, SD **Not Approved** | same |
| 2. Automatic rejection | Every time the list is loaded, the line gets rejection reason **Z8**. It stays in the list (Z8 is allowed in the selection) | – |
| 3a. FI accepts the loss and approves | `FI_APPROVE = X`, **Z8 removed** | `FI_APPROVE = X` |
| 4a. SD user approves | Both approved → release step (2.6): CP at once without credit block; with credit block CN until the workflow approves | same |
| 3b. Loss is not accepted → Reject | Rejection reason **63**, line stays CN, never produced; for the release cycle the line is "rejected" | same |
| 3c. Nobody acts | Line stays CN with Z8 (YSDA) and keeps showing in the list. For the release cycle it is still **open**, so a credit workflow of this order does **not** start | Line stays CN without rejection reason; same effect on the release cycle |

**Result:** a loss line is never produced without an explicit **FI approval** plus **SD approval**.

## 3.4 Order line with COST ERROR (total cost = 0)

Same as a loss line (3.3): FI **Not Approved**, automatic Z8 in YSDA. The cost must normally be corrected
(costing / conditions). Note: the FI flag stored at the first display is not recalculated after the cost is
corrected – FI approves the line by hand.

## 3.5 Order with several lines – profit and loss mixed

Example: line 10 profit, line 20 loss, line 30 profit, order with credit block.

| Action | Line 10 | Line 20 | Line 30 | Credit workflow |
|---|---|---|---|---|
| Lines appear | FI ✓ / SD ✗ | FI ✗ (Z8 in YSDA) / SD ✗ | FI ✓ / SD ✗ | – |
| SD approves 10 and 30 | approved, stays CN | open | approved, stays CN | waits – line 20 open |
| Line 20 rejected (63) | | rejected | | **starts now** (all lines decided) |
| Workflow final approval | **CN → CP** | stays CN | **CN → CP** | ends |
| *or* workflow rejected | not released | stays CN | not released | order cancelled by `CANCEL_SO` |

Without credit block lines 10 and 30 would each go CN → CP right after their SD approval.

# 4. Logs

| Log | Entries |
|---|---|
| `YSP_MTOSO_LOG` | `APPROVAL` (SD + FI both approved, with the BAPI or release-cycle message), `REJECT` (with BAPI message), `not Authorized` |
| `ZSD_SO_REL_LOG` | Every status change of the release cycle (decision, CN → CP, workflow start, credit approval / rejection) – report `ZSD_SO_REL_MONITOR` |
| Workflow log (EX / OD) | With the workflow changes: one `YSDA` row at the workflow start (which lines were approved / rejected in YSDA/YSDAX) and one `PROD` row at the end (which lines went CN → CP) |

# 5. Points to note

1. **FI proposal is stored once.** Profit and credit are checked only when the line first appears. If
   prices, cost or the credit situation change later, the stored FI flag is not updated.
2. **YSDA checks credit, and so does the credit workflow.** A profitable line of a customer over the limit
   needs FI approval in YSDA/YSDAX **and** the credit workflow afterwards. This is the existing design;
   change it only if the business wants the FI decision in YSDA/YSDAX to look at profit only.
3. **Automatic Z8 in YSDA saves the order once per line** and does not clear the BAPI tables between
   lines (`REJECT_FI_NOT_APPROVED`, logic kept as in the original program). With several "Not Approved"
   lines in one list, a later BAPI call also carries the item numbers of earlier lines, and every line is a
   separate save of the order (credit re-check, as in the `ZSD_MASS_CLOSING` incident). Worth a separate fix.
4. **YSDAX has no automatic rejection.** A loss line in YSDAX simply waits until FI approves or someone
   rejects it.
5. **Lines with sales order stock are hidden in YSDAX.** If such a line is still on CN, it cannot be
   approved there, and the release cycle waits for it.
