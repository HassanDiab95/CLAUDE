# 1. Short answer

Investigation of the **current** programs as they are today (without the REQ1 changes):
YSDA = module pool `YSP_MTOSO_APPROVE`, YSDAX = module pool `YSP_MTOSO_APPROVE_CX`.

| Question | YSDA | YSDAX |
|---|---|---|
| Is there a sequence between the SD and the FI approver? | **No.** Both see the same lines and can approve in any order, at any time. | **No.** Same. |
| Does each approver see only "his" lines? | **No.** Same list for SD and FI; the role decides only what the Approve button writes. | **No.** Same. |
| Does the FI approval change CN → CP even if SD has **not** approved? | **YES.** FI approval alone converts the line CN → CP immediately (and removes the Z8 rejection). | **NO.** CN → CP only when **both** SD and FI have approved, whoever is last. |
| Does the SD approval alone change CN? | No. | No. |
| When does the line leave the list? | As soon as it is CP (after the FI approval) or rejected. | When it is CP (after both approvals) or rejected, or when sales order stock exists. |
| Consequence | If FI approves first, the line goes to production and leaves the list, so **SD can never approve it any more** – the SD approval is effectively bypassed. | Both approvals are really required. |


# 2. Who is an approver

Both programs use the same rule (FORM `APPROVE_FUN` and `REJECT_FUN`):

| Item | Rule |
|---|---|
| Table | `ZAPPROVEUSER` |
| Key read | `USER_NAME = SY-UNAME` and `BUKRS = <plant entered on the selection screen>` |
| Role | field `ZPOSNUM`: `SD` = sales approver, `FI` = finance approver |
| Not in the table | Approve: warning "You are not Authorized to Approve" + log `not Authorized` in `YSP_MTOSO_LOG`. Reject: info "No Authorization For reject this order". |
| Start of the transaction | `AUTHORITY-CHECK OBJECT 'M_MSEG_WWA' ID 'WERKS' FIELD <plant>` (FORM `EXECUTE`) |

Note: `ZAPPROVEUSER-BUKRS` and `ZSOAPPROVAL-BUKRS` hold the **plant**, not the company code
(the selection screen field is labelled "Plant").


# 3. Filtration – which lines are shown

FORM `SCREEN_START` (YSDA include `YSP_MTOSO_APPROVE_SCREEN_STF01`, YSDAX include `YSP_MTOSO_APP_SCREEN_STF01_CX`).
The list is built once per screen display; after Approve / Reject it is built again.

| Filter | YSDA | YSDAX |
|---|---|---|
| Selection screen | Plant, From date, To date | Plant, From date, To date |
| Plant | `VBAP-WERKS = plant` | `VBAP-WERKS = plant` |
| Document date | `VBAK-AUDAT` between From and To | `VBAK-AUDAT` between From and To |
| Document category | `VBAK-VBTYP = 'C'` (order) or `'I'` (order w/o charge) | same |
| Schedule line category | `VBEP-ETTYP = 'CN'` | same |
| Item category | plant 1200/1202 → `ZTAW`; plant 1500/1501 → `ZTAC`; always also `ZFRE`. Other plants → only `ZFRE`. | plant 1600 → `YZTC`, `YFRE`. Other plants → **all** item categories (empty range). |
| Order type | not filtered | plant 1400 → `ZEM`, `ZMT`, `ZOR`, `ZFC`. Other plants → **all** order types. |
| Rejection | `ABGRU = ' '` or `ABGRU = 'Z8'` (rejected 63 lines disappear, Z8 lines stay) | `VBAP-ABSTA <> 'C'` (any fully rejected line disappears) |
| Sales order stock | not checked | lines **with** stock in `MSKA` are **not shown** |
| Duplicates | one row per item (several CN schedule lines are merged) | same |
| Role of the user | **not** used – SD and FI see the same lines | same |
| Approval status | **not** used – a line with SD = Approved and FI = Not approved is still shown | same |


# 4. What happens while the list is built (automatic decisions)

For every line, in FORM `SCREEN_START`:

## 4.1 Cost, profit and credit check

| Step | YSDA | YSDAX |
|---|---|---|
| Total cost | `VBAP-WAVWR` + conditions `ZBPC` + `ZOVC` (`PRCD_ELEMENTS`) | same |
| Profit | `VBAP-NETWR` − total cost | same (plus contribution profit from KEKO/KEPH, display only) |
| Profit status | cost = 0 → **COST ERROR**; profit < 0 → **Loss**; else **Profit** | same |
| FI proposal from profit | COST ERROR or Loss → "Not Approved"; Profit → "Approved" | same |
| Credit limit | `UKMBP_CMS_SGM-CREDIT_LIMIT` of the customer (first segment found) | same |
| Exposure | `UKM_COMMTS_BUPA_DISPLAY`, segment `WFICS` | segment `CPXCS` |
| Credit result | no limit → "Not related to Credit Management"; limit < exposure → **Exceed the limit** and FI proposal → "Not Approved" | same |

## 4.2 First display of a line → automatic FI approval

`ZSOAPPROVAL` is read with order + item:

| Situation | What the program does |
|---|---|
| **No row yet** (first time the line is shown) | inserts a row: `SD_APPROVE` = blank, `FI_APPROVE` = **'X' if the FI proposal is "Approved"** (profit OK and credit OK). → **FI is approved automatically**, FI never has to act. |
| Row exists | the screen shows `SD_APPROVE` / `FI_APPROVE` from the table. The cost / profit / credit result **no longer changes the FI flag** – the automatic decision is taken only once, at the first display. |

## 4.3 YSDA only – automatic Z8 rejection

After the list is built, **every line whose FI approval is "Not Approved"** gets rejection reason **Z8** through
`BAPI_SALESORDER_CHANGE` + commit – **every time the list is displayed** (one order save per line, each save
raises BUS2032 CHANGED). Z8 lines stay in the list (filter `ABGRU = 'Z8'`). YSDAX has no Z8 logic.


# 5. Approve button – operation per role

## 5.1 YSDA – FORM `APPROVE_FUN` (include `YSP_MTOSO_APPROVE_APPROVE_FF01`)

For every selected line:

| Role | Operation | Effect on CN |
|---|---|---|
| **SD** | `ZSOAPPROVAL-SD_APPROVE = 'X'`, SD date/time, commit. Only if the row exists. | **none** |
| **FI** | `ZSOAPPROVAL-FI_APPROVE = 'X'`, FI date/time, commit, then **`BAPI_SALESORDER_CHANGE`**: rejection reason cleared (Z8 removed) **and every schedule line of the item set to `CP`**, commit. | **CN → CP immediately, whatever SD did** |

Then, for both roles: `ZSOAPPROVAL` is read again; **if SD and FI are both 'X'** → `BAPI_SALESORDER_CHANGE` sets
every schedule line (WMENG > 0) to `CP`, commit, log `APPROVAL` in `YSP_MTOSO_LOG`.

## 5.2 YSDAX – FORM `APPROVE_FUN` (include `YSP_MTOSO_APPROVE_FF01_CX`)

| Role | Operation | Effect on CN |
|---|---|---|
| **SD** | `SD_APPROVE = 'X'`, date/time, commit | none |
| **FI** | `FI_APPROVE = 'X'`, date/time, commit (no BAPI) | none |

Then: **if SD and FI are both 'X'** → schedule lines `CP`, commit, log `APPROVAL`. Whoever approves last triggers CN → CP.

## 5.3 Reject button – both programs (FORM `REJECT_FUN`)

Any user in `ZAPPROVEUSER` for the plant (SD **or** FI – the role is not checked) → rejection reason **63** on the
selected lines, commit, log `REJECT`. The schedule line stays **CN**; the line leaves the list.
`ZSOAPPROVAL` is not changed (flags given before stay).


# 6. All conditions – result on the CN flag

## 6.1 YSDA

| # | Condition at first display | Actions (in this order) | Schedule line | In the list afterwards | SD flag | FI flag |
|---|---|---|---|---|---|---|
| A1 | Profit OK + credit OK → **FI auto-approved** | SD approves | **CN → CP** (at SD approval, both X) | no | X | X (auto) |
| A2 | FI auto-approved | **FI user approves** (before SD) | **CN → CP** (FI branch) | no | blank – SD never approves | X |
| A3 | FI auto-approved | nobody acts | CN | yes | blank | X |
| B1 | Loss / cost error / credit exceeded → **FI not approved, Z8 set** | **FI approves first** | **CN → CP**, Z8 removed | **no** | **blank – SD can no longer see the line** | X |
| B2 | FI not approved, Z8 | SD approves, then FI approves | CN after SD; **CN → CP** at FI | yes after SD, no after FI | X | X |
| B3 | FI not approved, Z8 | SD approves, FI never | **CN**, Z8 stays (set again at every display) | yes | X | blank |
| B4 | FI not approved, Z8 | nobody acts | CN, Z8 | yes | blank | blank |
| C1 | any | SD or FI user rejects | **CN** (line rejected 63) | no | unchanged | unchanged |
| C2 | any | SD approved before, then reject | CN, rejected 63 | no | X | unchanged |

**Result YSDA:** the FI approval is the switch for production. SD approval only matters when FI was approved
automatically (A1). In A2 and B1 the line goes to production **without any SD approval**.

## 6.2 YSDAX

| # | Condition at first display | Actions | Schedule line | In the list afterwards | SD flag | FI flag |
|---|---|---|---|---|---|---|
| A1 | FI auto-approved | SD approves | **CN → CP** | no | X | X (auto) |
| A2 | FI auto-approved | FI user approves (again) | CN (SD missing) | yes | blank | X |
| B1 | FI not approved | FI approves first | **CN** | yes | blank | X |
| B2 | FI not approved | then SD approves | **CN → CP** | no | X | X |
| B3 | FI not approved | SD approves first, then FI | CN after SD; **CN → CP** at FI | no | X | X |
| B4 | FI not approved | only one of them approves | CN | yes | one X | one X |
| C1 | any | SD or FI user rejects | CN (line rejected 63, `ABSTA = C`) | no | unchanged | unchanged |
| D1 | any | sales order stock exists for the line | unchanged | **no** (filtered out) | – | – |

**Result YSDAX:** order does not matter; CN → CP only when both are approved.

## 6.3 Side by side

| | YSDA | YSDAX |
|---|---|---|
| SD approval alone | no effect on CN | no effect on CN |
| FI approval alone | **CN → CP** | no effect on CN |
| Both approved | CN → CP (already done by FI if FI was manual) | CN → CP |
| Reject | 63, stays CN | 63, stays CN |
| Automatic FI approval | yes (profit + credit OK, first display) | yes (same) |
| Automatic rejection | Z8 for "FI not approved", every display | none |


# 7. Other findings

| # | Finding | Program | Impact |
|---|---|---|---|
| 1 | FI approval sets CP alone, before / without SD | YSDA | SD approval bypassed (conditions A2, B1) |
| 2 | After CP the line leaves the list, so SD cannot approve later | YSDA | `SD_APPROVE` stays blank, no `APPROVAL` log for these lines |
| 3 | BAPI tables are header-line tables that are **not cleared per selected line** (`ORDER_ITEM_IN`, `ORDER_ITEM_INX`, `LT_SCHDL`, `LT_SCHDLX`) | YSDA + YSDAX | with several lines selected, the 2nd BAPI call also sends the lines of the 1st call (wrong item numbers for another order → errors, or the same item changed twice) |
| 4 | `SD_APPROVE` / `FI_APPROVE` are global and read with `SELECT SINGLE` – if no row is found the values of the previous line remain | YSDA + YSDAX | low risk (the row is created at display), but a line could be released with another line's flags |
| 5 | Automatic FI decision only at the first display | YSDA + YSDAX | later price / cost / credit changes do not change the FI flag |
| 6 | Z8 is set again for every not-approved line at every display | YSDA | one order save per line and display; many BUS2032 CHANGED events (credit workflow check) |
| 7 | Credit limit read without credit segment, exposure read for WFICS / CPXCS | YSDA + YSDAX | limit and exposure can come from different segments |
| 8 | Reject does not check the role and does not reset approval flags | YSDA + YSDAX | an SD user can reject a line FI approved and vice versa |
| 9 | BAPI results are not checked in the FI branch | YSDA | a failed CN → CP is not reported |
| 10 | `ZSOAPPROVAL-BUKRS` = plant, but VA02 check `ZSD_CHECK_APPROVAL` reads it with the company code | YSDA + YSDAX | plants 1202 / 1501: VA02 always says "not yet approved" |
| 11 | Unauthorized approver gets a **warning** (type W) in PAI | YSDA + YSDAX | processing of the remaining selected lines may stop at the message – to be tested |


# 8. Relation to the REQ1 changes

| REQ1 change | Effect on the behaviour above |
|---|---|
| C3 + C4 (YSDA, FI branch) | FI approval no longer sets CP. YSDA then behaves like YSDAX: **CN → CP only when SD and FI are both approved** (finding 1 and 2 solved). |
| C2, C6 / D2, D3, D5 | BAPI tables and approval flags cleared per selected line (findings 3 and 4 solved). |
| C5 / D3 | When both are approved: release cycle decides – CN → CP at once (no credit block) or after the credit workflow. |
| C1 / D1 | Approved lines are hidden even while they stay CN for the credit approval. |
| B6 | VA02 check reads the approval without BUKRS (finding 10 solved). |

Not covered by REQ1 (decision needed): automatic FI approval at first display (5), repeated Z8 (6),
credit limit segment (7), reject role check (8).
