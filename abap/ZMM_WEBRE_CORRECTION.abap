*&---------------------------------------------------------------------*
*& Report ZMM_WEBRE_CORRECTION
*&---------------------------------------------------------------------*
*& Sets "GR-based invoice verification" (EKPO-WEBRE) on PO items that
*& already have goods receipts / invoices, and back-fills the GR
*& reference fields that GR-based IV relies on:
*&   EKBE           : LFGJA / LFBNR / LFPOS
*&   MSEG / MATDOC  : LFBJA / LFBNR / LFPOS  (MATDOC on S/4HANA)
*&   RSEG           : LFGJA / LFBNR / LFPOS
*&
*& Background: SAP note 457511 and the SAP incident reply. This is a
*& direct table correction outside SAP standard. Run it in test mode
*& first, in a QA system with a copy of production data, and only with
*& sign-off from an MM consultant.
*&
*& The correction is all-or-nothing per PO item: if any document of
*& the item cannot be linked to a unique original GR, nothing is
*& changed for that item and it is reported with status MANUAL.
*&
*& Prerequisite: transparent table ZMM_WEBRE_BKP (see
*& ZMM_WEBRE_CORRECTION.md) - before images of every changed line.
*&---------------------------------------------------------------------*
REPORT zmm_webre_correction.

TABLES ekpo.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME.
SELECT-OPTIONS: s_ebeln FOR ekpo-ebeln OBLIGATORY,
                s_ebelp FOR ekpo-ebelp.
PARAMETERS      p_test AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b1.

*----------------------------------------------------------------------*
CLASS lcl_webre_corr DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS constructor IMPORTING iv_test TYPE abap_bool.
    METHODS run.

  PRIVATE SECTION.
    TYPES ty_qty TYPE p LENGTH 13 DECIMALS 3.

    TYPES: BEGIN OF ty_item,
             ebeln TYPE ekpo-ebeln,
             ebelp TYPE ekpo-ebelp,
             webre TYPE ekpo-webre,
             wepos TYPE ekpo-wepos,
             vrtkz TYPE ekpo-vrtkz,
             pstyp TYPE ekpo-pstyp,
           END OF ty_item,
           tt_item TYPE STANDARD TABLE OF ty_item WITH DEFAULT KEY.

    " Reference to the original goods receipt
    TYPES: BEGIN OF ty_ref,
             lfgja TYPE ekbe-lfgja,
             lfbnr TYPE ekbe-lfbnr,
             lfpos TYPE ekbe-lfpos,
           END OF ty_ref.

    " One PO history line (EKBE) with current and derived reference
    TYPES: BEGIN OF ty_hist,
             vgabe TYPE ekbe-vgabe,
             gjahr TYPE ekbe-gjahr,
             belnr TYPE ekbe-belnr,
             buzei TYPE ekbe-buzei,
             budat TYPE ekbe-budat,
             bwart TYPE ekbe-bwart,
             shkzg TYPE ekbe-shkzg,
             menge TYPE ekbe-menge,
             old   TYPE ty_ref,
             new   TYPE ty_ref,
             done  TYPE abap_bool,
           END OF ty_hist,
           tt_hist TYPE STANDARD TABLE OF ty_hist WITH DEFAULT KEY.

    " Quantity received and not yet invoiced per original GR
    TYPES: BEGIN OF ty_bal,
             ref  TYPE ty_ref,
             open TYPE ty_qty,
           END OF ty_bal,
           tt_bal TYPE STANDARD TABLE OF ty_bal WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_log,
             ebeln     TYPE ekpo-ebeln,
             ebelp     TYPE ekpo-ebelp,
             vgabe     TYPE ekbe-vgabe,
             belnr     TYPE ekbe-belnr,
             gjahr     TYPE ekbe-gjahr,
             buzei     TYPE ekbe-buzei,
             bwart     TYPE ekbe-bwart,
             shkzg     TYPE ekbe-shkzg,
             menge     TYPE ekbe-menge,
             old_lfbnr TYPE ekbe-lfbnr,
             old_lfgja TYPE ekbe-lfgja,
             old_lfpos TYPE ekbe-lfpos,
             new_lfbnr TYPE ekbe-lfbnr,
             new_lfgja TYPE ekbe-lfgja,
             new_lfpos TYPE ekbe-lfpos,
             status    TYPE char10,
             message   TYPE char255,
           END OF ty_log.

    DATA: mv_test TYPE abap_bool,
          mv_s4   TYPE abap_bool,
          mt_log  TYPE STANDARD TABLE OF ty_log WITH DEFAULT KEY.

    METHODS process_item IMPORTING is_item TYPE ty_item.
    METHODS load_history IMPORTING is_item        TYPE ty_item
                         RETURNING VALUE(rt_hist) TYPE tt_hist.
    METHODS check_item IMPORTING is_item       TYPE ty_item
                                 it_hist       TYPE tt_hist
                       RETURNING VALUE(rv_msg) TYPE string.
    METHODS derive_gr EXPORTING ev_msg  TYPE string
                      CHANGING  ct_hist TYPE tt_hist.
    METHODS derive_ir EXPORTING ev_msg  TYPE string
                      CHANGING  ct_hist TYPE tt_hist.
    METHODS check_balance IMPORTING it_hist       TYPE tt_hist
                          RETURNING VALUE(rv_msg) TYPE string.
    METHODS update_item IMPORTING is_item       TYPE ty_item
                                  it_hist       TYPE tt_hist
                        RETURNING VALUE(rv_msg) TYPE string.
    METHODS add_bal IMPORTING is_ref TYPE ty_ref
                              iv_qty TYPE ty_qty
                    CHANGING  ct_bal TYPE tt_bal.
    METHODS log_item IMPORTING is_item   TYPE ty_item
                               it_hist   TYPE tt_hist
                               iv_status TYPE char10
                               iv_msg    TYPE string.
    METHODS display.
    METHODS set_text IMPORTING io_cols TYPE REF TO cl_salv_columns_table
                               iv_name TYPE lvc_fname
                               iv_text TYPE string.
ENDCLASS.

*----------------------------------------------------------------------*
CLASS lcl_webre_corr IMPLEMENTATION.

  METHOD constructor.
    DATA lv_tabname TYPE dd02l-tabname.

    mv_test = iv_test.
    " S/4HANA: MSEG is a compatibility view, the data lives in MATDOC
    SELECT SINGLE tabname FROM dd02l INTO lv_tabname
      WHERE tabname  = 'MATDOC'
        AND as4local = 'A'.
    mv_s4 = boolc( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD run.
    DATA: lt_item   TYPE tt_item,
          ls_item   TYPE ty_item,
          lv_answer TYPE c LENGTH 1.

    AUTHORITY-CHECK OBJECT 'M_BEST_BSA'
      ID 'ACTVT' FIELD '02'
      ID 'BSART' DUMMY.
    IF sy-subrc <> 0.
      MESSAGE 'No authorization to change purchase orders (M_BEST_BSA)'
        TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    IF mv_test = abap_false.
      CALL FUNCTION 'POPUP_TO_CONFIRM'
        EXPORTING
          titlebar              = 'GR-based IV correction'
          text_question         = 'Update run: EKPO, EKBE, MSEG/MATDOC and RSEG will be changed directly. Continue?'
          text_button_1         = 'Update'
          text_button_2         = 'Cancel'
          default_button        = '2'
          display_cancel_button = abap_false
        IMPORTING
          answer                = lv_answer
        EXCEPTIONS
          OTHERS                = 1.
      IF sy-subrc <> 0 OR lv_answer <> '1'.
        RETURN.
      ENDIF.
    ENDIF.

    SELECT ebeln ebelp webre wepos vrtkz pstyp
      FROM ekpo
      INTO TABLE lt_item
      WHERE ebeln IN s_ebeln
        AND ebelp IN s_ebelp
        AND webre = space.

    LOOP AT lt_item INTO ls_item.
      process_item( ls_item ).
    ENDLOOP.

    display( ).
  ENDMETHOD.


  METHOD process_item.
    DATA: lt_hist TYPE tt_hist,
          lt_none TYPE tt_hist,
          lv_msg  TYPE string.

    lt_hist = load_history( is_item ).
    IF lt_hist IS INITIAL.
      log_item( is_item   = is_item
                it_hist   = lt_none
                iv_status = 'SKIPPED'
                iv_msg    = 'No PO history - set GR-based IV directly in ME22N' ).
      RETURN.
    ENDIF.

    lv_msg = check_item( is_item = is_item it_hist = lt_hist ).
    IF lv_msg IS INITIAL.
      derive_gr( IMPORTING ev_msg = lv_msg CHANGING ct_hist = lt_hist ).
    ENDIF.
    IF lv_msg IS INITIAL.
      derive_ir( IMPORTING ev_msg = lv_msg CHANGING ct_hist = lt_hist ).
    ENDIF.
    IF lv_msg IS INITIAL.
      lv_msg = check_balance( lt_hist ).
    ENDIF.

    IF lv_msg IS NOT INITIAL.
      log_item( is_item = is_item it_hist = lt_none iv_status = 'MANUAL' iv_msg = lv_msg ).
      RETURN.
    ENDIF.

    IF mv_test = abap_true.
      log_item( is_item   = is_item
                it_hist   = lt_hist
                iv_status = 'SIMULATED'
                iv_msg    = 'Test run - WEBRE would be set, no changes made' ).
      RETURN.
    ENDIF.

    lv_msg = update_item( is_item = is_item it_hist = lt_hist ).
    IF lv_msg IS INITIAL.
      log_item( is_item   = is_item
                it_hist   = lt_hist
                iv_status = 'UPDATED'
                iv_msg    = 'WEBRE set and GR references updated' ).
    ELSE.
      log_item( is_item = is_item it_hist = lt_none iv_status = 'ERROR' iv_msg = lv_msg ).
    ENDIF.
  ENDMETHOD.


  METHOD load_history.
    TYPES: BEGIN OF ty_ekbe,
             vgabe TYPE ekbe-vgabe,
             gjahr TYPE ekbe-gjahr,
             belnr TYPE ekbe-belnr,
             buzei TYPE ekbe-buzei,
             budat TYPE ekbe-budat,
             bwart TYPE ekbe-bwart,
             shkzg TYPE ekbe-shkzg,
             menge TYPE ekbe-menge,
             lfgja TYPE ekbe-lfgja,
             lfbnr TYPE ekbe-lfbnr,
             lfpos TYPE ekbe-lfpos,
           END OF ty_ekbe.
    DATA: lt_ekbe TYPE STANDARD TABLE OF ty_ekbe WITH DEFAULT KEY,
          ls_ekbe TYPE ty_ekbe,
          ls_hist TYPE ty_hist.

    SELECT vgabe gjahr belnr buzei budat bwart shkzg menge lfgja lfbnr lfpos
      FROM ekbe
      INTO TABLE lt_ekbe
      WHERE ebeln = is_item-ebeln
        AND ebelp = is_item-ebelp.

    LOOP AT lt_ekbe INTO ls_ekbe.
      CLEAR ls_hist.
      MOVE-CORRESPONDING ls_ekbe TO ls_hist.
      ls_hist-old-lfgja = ls_ekbe-lfgja.
      ls_hist-old-lfbnr = ls_ekbe-lfbnr.
      ls_hist-old-lfpos = ls_ekbe-lfpos.
      APPEND ls_hist TO rt_hist.
    ENDLOOP.

    " Chronological order drives the FIFO assignment of invoices to GRs
    SORT rt_hist BY vgabe budat gjahr belnr buzei.
  ENDMETHOD.


  METHOD check_item.
    DATA: ls_hist  TYPE ty_hist,
          lv_ebeln TYPE ekpo-ebeln,
          lv_belnr TYPE rseg-belnr.

    IF is_item-wepos IS INITIAL.
      rv_msg = 'Item has no goods receipt indicator (WEPOS)'.
      RETURN.
    ENDIF.
    IF is_item-vrtkz IS NOT INITIAL.
      rv_msg = 'Multiple account assignment - correct manually'.
      RETURN.
    ENDIF.
    IF is_item-pstyp = '9'.
      rv_msg = 'Service item - correct manually'.
      RETURN.
    ENDIF.

    LOOP AT it_hist INTO ls_hist.
      IF ls_hist-vgabe <> '1' AND ls_hist-vgabe <> '2' AND ls_hist-vgabe <> '3'.
        rv_msg = |PO history category { ls_hist-vgabe } not supported (document { ls_hist-belnr })|.
        RETURN.
      ENDIF.
      IF ls_hist-vgabe = '1'
         AND ls_hist-bwart <> '101' AND ls_hist-bwart <> '102'
         AND ls_hist-bwart <> '122' AND ls_hist-bwart <> '123'.
        rv_msg = |Movement type { ls_hist-bwart } not supported (document { ls_hist-belnr })|.
        RETURN.
      ENDIF.
    ENDLOOP.

    SELECT SINGLE ebeln FROM ekbz INTO lv_ebeln
      WHERE ebeln = is_item-ebeln
        AND ebelp = is_item-ebelp.
    IF sy-subrc = 0.
      rv_msg = 'Delivery costs (EKBZ) exist - correct manually'.
      RETURN.
    ENDIF.

    SELECT SINGLE ebeln FROM ekbeh INTO lv_ebeln
      WHERE ebeln = is_item-ebeln
        AND ebelp = is_item-ebelp.
    IF sy-subrc = 0.
      rv_msg = 'Archived/compressed PO history (EKBEH) exists - correct manually'.
      RETURN.
    ENDIF.

    " Parked/held invoices would later post without a GR reference
    SELECT SINGLE r~belnr
      FROM rseg AS r
      INNER JOIN rbkp AS k
        ON  k~belnr = r~belnr
        AND k~gjahr = r~gjahr
      INTO lv_belnr
      WHERE r~ebeln = is_item-ebeln
        AND r~ebelp = is_item-ebelp
        AND k~rbstat NOT IN ('2','5').
    IF sy-subrc = 0.
      rv_msg = |Invoice { lv_belnr } is not posted (parked/held) - post or delete it first|.
      RETURN.
    ENDIF.
  ENDMETHOD.


  METHOD derive_gr.
    TYPES: BEGIN OF ty_mseg,
             mblnr TYPE mseg-mblnr,
             mjahr TYPE mseg-mjahr,
             zeile TYPE mseg-zeile,
             smbln TYPE mseg-smbln,
             sjahr TYPE mseg-sjahr,
             smblp TYPE mseg-smblp,
           END OF ty_mseg.
    DATA: lt_gr       TYPE tt_hist,
          lt_mseg     TYPE STANDARD TABLE OF ty_mseg WITH DEFAULT KEY,
          ls_mseg     TYPE ty_mseg,
          lv_progress TYPE abap_bool,
          lv_orig_cnt TYPE i,
          ls_orig_ref TYPE ty_ref.
    FIELD-SYMBOLS: <h> TYPE ty_hist,
                   <o> TYPE ty_hist.

    CLEAR ev_msg.
    lt_gr = ct_hist.
    DELETE lt_gr WHERE vgabe <> '1'.
    IF lt_gr IS INITIAL.
      RETURN.
    ENDIF.

    SELECT mblnr mjahr zeile smbln sjahr smblp
      FROM mseg
      INTO TABLE lt_mseg
      FOR ALL ENTRIES IN lt_gr
      WHERE mblnr = lt_gr-belnr
        AND mjahr = lt_gr-gjahr
        AND zeile = lt_gr-buzei.

    " Pass 1: original receipts reference themselves
    LOOP AT ct_hist ASSIGNING <h> WHERE vgabe = '1'.
      IF <h>-old-lfbnr IS NOT INITIAL.
        <h>-new  = <h>-old.
        <h>-done = abap_true.
        CONTINUE.
      ENDIF.
      CLEAR ls_mseg.
      READ TABLE lt_mseg INTO ls_mseg
        WITH KEY mblnr = <h>-belnr mjahr = <h>-gjahr zeile = <h>-buzei.
      IF ls_mseg-smbln IS INITIAL AND <h>-shkzg = 'S' AND <h>-bwart = '101'.
        <h>-new-lfgja = <h>-gjahr.
        <h>-new-lfbnr = <h>-belnr.
        <h>-new-lfpos = <h>-buzei.
        <h>-done      = abap_true.
      ENDIF.
    ENDLOOP.

    " Pass 2: cancellations (102 / 123 ...) inherit the reference of the
    " document they cancel; repeat for cancellations of cancellations
    DO.
      lv_progress = abap_false.
      LOOP AT ct_hist ASSIGNING <h> WHERE vgabe = '1' AND done = abap_false.
        CLEAR ls_mseg.
        READ TABLE lt_mseg INTO ls_mseg
          WITH KEY mblnr = <h>-belnr mjahr = <h>-gjahr zeile = <h>-buzei.
        IF ls_mseg-smbln IS INITIAL.
          CONTINUE.
        ENDIF.
        READ TABLE ct_hist ASSIGNING <o>
          WITH KEY vgabe = '1'
                   gjahr = ls_mseg-sjahr
                   belnr = ls_mseg-smbln
                   buzei = ls_mseg-smblp
                   done  = abap_true.
        IF sy-subrc = 0.
          <h>-new     = <o>-new.
          <h>-done    = abap_true.
          lv_progress = abap_true.
        ENDIF.
      ENDLOOP.
      IF lv_progress = abap_false.
        EXIT.
      ENDIF.
    ENDDO.

    " Pass 3: returns/reversals without a document reference can only be
    " linked automatically when the item has exactly one original GR
    LOOP AT ct_hist ASSIGNING <o> WHERE vgabe = '1' AND done = abap_true.
      IF <o>-new-lfbnr = <o>-belnr AND <o>-new-lfgja = <o>-gjahr AND <o>-new-lfpos = <o>-buzei.
        lv_orig_cnt = lv_orig_cnt + 1.
        ls_orig_ref = <o>-new.
      ENDIF.
    ENDLOOP.

    LOOP AT ct_hist ASSIGNING <h> WHERE vgabe = '1' AND done = abap_false.
      IF lv_orig_cnt = 1.
        <h>-new  = ls_orig_ref.
        <h>-done = abap_true.
      ELSE.
        ev_msg = |GR { <h>-belnr }/{ <h>-gjahr } item { <h>-buzei } (mvt { <h>-bwart }) | &&
                 |cannot be linked to a unique original GR|.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD derive_ir.
    TYPES: BEGIN OF ty_rbkp,
             belnr TYPE rbkp-belnr,
             gjahr TYPE rbkp-gjahr,
             stblg TYPE rbkp-stblg,
             stjah TYPE rbkp-stjah,
           END OF ty_rbkp.
    DATA: lt_ir    TYPE tt_hist,
          lt_rbkp  TYPE STANDARD TABLE OF ty_rbkp WITH DEFAULT KEY,
          ls_rbkp  TYPE ty_rbkp,
          lt_bal   TYPE tt_bal,
          ls_bal   TYPE ty_bal,
          lv_belnr TYPE rbkp-belnr,
          lv_gjahr TYPE rbkp-gjahr,
          lv_qty   TYPE ty_qty.
    FIELD-SYMBOLS: <h> TYPE ty_hist,
                   <o> TYPE ty_hist,
                   <b> TYPE ty_bal.

    CLEAR ev_msg.
    lt_ir = ct_hist.
    DELETE lt_ir WHERE vgabe = '1'.
    IF lt_ir IS INITIAL.
      RETURN.
    ENDIF.

    " Received quantity per original GR, in posting-date order
    LOOP AT ct_hist ASSIGNING <h> WHERE vgabe = '1'.
      lv_qty = <h>-menge.
      IF <h>-shkzg = 'H'.
        lv_qty = - lv_qty.
      ENDIF.
      add_bal( EXPORTING is_ref = <h>-new iv_qty = lv_qty CHANGING ct_bal = lt_bal ).
    ENDLOOP.

    IF lt_bal IS INITIAL.
      ev_msg = 'Invoices exist but no goods receipt - correct manually'.
      RETURN.
    ENDIF.

    " Exactly one GR: every invoice/credit memo/subsequent debit belongs to it
    IF lines( lt_bal ) = 1.
      READ TABLE lt_bal INTO ls_bal INDEX 1.
      LOOP AT ct_hist ASSIGNING <h> WHERE vgabe <> '1'.
        IF <h>-old-lfbnr IS NOT INITIAL.
          <h>-new = <h>-old.
        ELSE.
          <h>-new = ls_bal-ref.
        ENDIF.
        <h>-done = abap_true.
      ENDLOOP.
      RETURN.
    ENDIF.

    SELECT belnr gjahr stblg stjah
      FROM rbkp
      INTO TABLE lt_rbkp
      FOR ALL ENTRIES IN lt_ir
      WHERE belnr = lt_ir-belnr
        AND gjahr = lt_ir-gjahr.

    " Several GRs: walk the invoices chronologically
    LOOP AT ct_hist ASSIGNING <h> WHERE vgabe <> '1'.
      " Invoice (S) consumes received quantity, credit/reversal (H) returns it;
      " subsequent debits/credits (VGABE 3) carry no quantity
      lv_qty = <h>-menge.
      IF <h>-shkzg = 'S'.
        lv_qty = - lv_qty.
      ENDIF.
      IF <h>-vgabe <> '2'.
        lv_qty = 0.
      ENDIF.

      IF <h>-old-lfbnr IS NOT INITIAL.
        <h>-new  = <h>-old.
        <h>-done = abap_true.
        add_bal( EXPORTING is_ref = <h>-new iv_qty = lv_qty CHANGING ct_bal = lt_bal ).
        CONTINUE.
      ENDIF.

      " Reversal pair (MR8M): use the reference of the partner document
      CLEAR: lv_belnr, lv_gjahr.
      READ TABLE lt_rbkp INTO ls_rbkp WITH KEY belnr = <h>-belnr gjahr = <h>-gjahr.
      IF sy-subrc = 0 AND ls_rbkp-stblg IS NOT INITIAL.
        lv_belnr = ls_rbkp-stblg.
        lv_gjahr = ls_rbkp-stjah.
      ELSE.
        READ TABLE lt_rbkp INTO ls_rbkp WITH KEY stblg = <h>-belnr stjah = <h>-gjahr.
        IF sy-subrc = 0.
          lv_belnr = ls_rbkp-belnr.
          lv_gjahr = ls_rbkp-gjahr.
        ENDIF.
      ENDIF.
      IF lv_belnr IS NOT INITIAL.
        READ TABLE ct_hist ASSIGNING <o>
          WITH KEY vgabe = <h>-vgabe
                   gjahr = lv_gjahr
                   belnr = lv_belnr
                   done  = abap_true.
        IF sy-subrc = 0.
          <h>-new  = <o>-new.
          <h>-done = abap_true.
          add_bal( EXPORTING is_ref = <h>-new iv_qty = lv_qty CHANGING ct_bal = lt_bal ).
          CONTINUE.
        ENDIF.
      ENDIF.

      " Invoice: first GR (FIFO) whose open quantity matches exactly
      IF <h>-vgabe = '2' AND <h>-shkzg = 'S'.
        LOOP AT lt_bal ASSIGNING <b> WHERE open = <h>-menge.
          <h>-new  = <b>-ref.
          <h>-done = abap_true.
          <b>-open = <b>-open - <h>-menge.
          EXIT.
        ENDLOOP.
      ENDIF.
    ENDLOOP.

    LOOP AT ct_hist ASSIGNING <h> WHERE vgabe <> '1' AND done = abap_false.
      ev_msg = |Invoice { <h>-belnr }/{ <h>-gjahr } item { <h>-buzei } | &&
               |cannot be assigned to a unique GR|.
      RETURN.
    ENDLOOP.
  ENDMETHOD.


  METHOD check_balance.
    " Independent check: per GR, invoiced quantity must not exceed the
    " received quantity (MIRO enforces this for GR-based IV)
    DATA: lt_bal  TYPE tt_bal,
          ls_bal  TYPE ty_bal,
          ls_hist TYPE ty_hist,
          lv_qty  TYPE ty_qty.

    LOOP AT it_hist INTO ls_hist WHERE vgabe = '1' OR vgabe = '2'.
      lv_qty = ls_hist-menge.
      IF ( ls_hist-vgabe = '1' AND ls_hist-shkzg = 'H' )
      OR ( ls_hist-vgabe = '2' AND ls_hist-shkzg = 'S' ).
        lv_qty = - lv_qty.
      ENDIF.
      add_bal( EXPORTING is_ref = ls_hist-new iv_qty = lv_qty CHANGING ct_bal = lt_bal ).
    ENDLOOP.

    LOOP AT lt_bal INTO ls_bal WHERE open < 0.
      rv_msg = |Invoiced quantity exceeds received quantity for GR | &&
               |{ ls_bal-ref-lfbnr }/{ ls_bal-ref-lfgja } item { ls_bal-ref-lfpos }|.
      RETURN.
    ENDLOOP.
  ENDMETHOD.


  METHOD update_item.
    DATA: lt_bkp   TYPE STANDARD TABLE OF zmm_webre_bkp WITH DEFAULT KEY,
          ls_bkp   TYPE zmm_webre_bkp,
          ls_hist  TYPE ty_hist,
          lv_tab   TYPE tabname,
          lv_buzei TYPE rseg-buzei,
          lv_webre TYPE ekpo-webre,
          lv_count TYPE i,
          lv_ts    TYPE timestampl.

    lv_tab = 'MSEG'.
    IF mv_s4 = abap_true.
      lv_tab = 'MATDOC'.
    ENDIF.
    GET TIME STAMP FIELD lv_ts.

    CALL FUNCTION 'ENQUEUE_EMEKKOE'
      EXPORTING
        ebeln          = is_item-ebeln
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.
    IF sy-subrc <> 0.
      rv_msg = |PO { is_item-ebeln } is locked by { sy-msgv1 }|.
      RETURN.
    ENDIF.

    " Re-check under lock that nothing changed since the analysis
    SELECT SINGLE webre FROM ekpo INTO lv_webre
      WHERE ebeln = is_item-ebeln
        AND ebelp = is_item-ebelp.
    SELECT COUNT(*) FROM ekbe INTO lv_count
      WHERE ebeln = is_item-ebeln
        AND ebelp = is_item-ebelp.
    IF lv_webre IS NOT INITIAL OR lv_count <> lines( it_hist ).
      rv_msg = 'PO item changed since analysis - run again'.
    ENDIF.

    LOOP AT it_hist INTO ls_hist.
      IF rv_msg IS NOT INITIAL.
        EXIT.
      ENDIF.
      IF ls_hist-new = ls_hist-old.
        CONTINUE.
      ENDIF.

      CLEAR ls_bkp.
      ls_bkp-ebeln     = is_item-ebeln.
      ls_bkp-ebelp     = is_item-ebelp.
      ls_bkp-vgabe     = ls_hist-vgabe.
      ls_bkp-gjahr     = ls_hist-gjahr.
      ls_bkp-belnr     = ls_hist-belnr.
      ls_bkp-buzei     = ls_hist-buzei.
      ls_bkp-run_ts    = lv_ts.
      ls_bkp-uname     = sy-uname.
      ls_bkp-old_lfgja = ls_hist-old-lfgja.
      ls_bkp-old_lfbnr = ls_hist-old-lfbnr.
      ls_bkp-old_lfpos = ls_hist-old-lfpos.
      ls_bkp-new_lfgja = ls_hist-new-lfgja.
      ls_bkp-new_lfbnr = ls_hist-new-lfbnr.
      ls_bkp-new_lfpos = ls_hist-new-lfpos.
      APPEND ls_bkp TO lt_bkp.

      UPDATE ekbe SET lfgja = ls_hist-new-lfgja
                      lfbnr = ls_hist-new-lfbnr
                      lfpos = ls_hist-new-lfpos
        WHERE ebeln = is_item-ebeln
          AND ebelp = is_item-ebelp
          AND vgabe = ls_hist-vgabe
          AND gjahr = ls_hist-gjahr
          AND belnr = ls_hist-belnr
          AND buzei = ls_hist-buzei.
      IF sy-subrc <> 0.
        rv_msg = |EKBE update failed for { ls_hist-belnr }/{ ls_hist-gjahr }/{ ls_hist-buzei }|.
        EXIT.
      ENDIF.

      " Only overwrite the document line if it still holds the EKBE value
      " (or already the target value); anything else needs a manual look
      IF ls_hist-vgabe = '1'.
        UPDATE (lv_tab) SET lfbja = ls_hist-new-lfgja
                            lfbnr = ls_hist-new-lfbnr
                            lfpos = ls_hist-new-lfpos
          WHERE mblnr = ls_hist-belnr
            AND mjahr = ls_hist-gjahr
            AND zeile = ls_hist-buzei
            AND ( lfbnr = ls_hist-old-lfbnr OR lfbnr = ls_hist-new-lfbnr ).
        IF sy-subrc <> 0.
          rv_msg = |{ lv_tab } { ls_hist-belnr }/{ ls_hist-gjahr }/{ ls_hist-buzei } | &&
                   |not found or holds a different reference than EKBE|.
          EXIT.
        ENDIF.
      ELSE.
        lv_buzei = ls_hist-buzei.
        UPDATE rseg SET lfgja = ls_hist-new-lfgja
                        lfbnr = ls_hist-new-lfbnr
                        lfpos = ls_hist-new-lfpos
          WHERE belnr = ls_hist-belnr
            AND gjahr = ls_hist-gjahr
            AND buzei = lv_buzei
            AND ( lfbnr = ls_hist-old-lfbnr OR lfbnr = ls_hist-new-lfbnr ).
        IF sy-subrc <> 0.
          rv_msg = |RSEG { ls_hist-belnr }/{ ls_hist-gjahr }/{ ls_hist-buzei } | &&
                   |not found or holds a different reference than EKBE|.
          EXIT.
        ENDIF.
      ENDIF.
    ENDLOOP.

    IF rv_msg IS INITIAL.
      UPDATE ekpo SET webre = 'X'
        WHERE ebeln = is_item-ebeln
          AND ebelp = is_item-ebelp
          AND webre = space.
      IF sy-subrc <> 0.
        rv_msg = 'EKPO update failed'.
      ENDIF.
    ENDIF.

    IF rv_msg IS INITIAL AND lt_bkp IS NOT INITIAL.
      INSERT zmm_webre_bkp FROM TABLE lt_bkp.
      IF sy-subrc <> 0.
        rv_msg = 'Backup table ZMM_WEBRE_BKP could not be written'.
      ENDIF.
    ENDIF.

    IF rv_msg IS INITIAL.
      COMMIT WORK AND WAIT.
    ELSE.
      ROLLBACK WORK.
    ENDIF.

    CALL FUNCTION 'DEQUEUE_EMEKKOE'
      EXPORTING
        ebeln = is_item-ebeln.
  ENDMETHOD.


  METHOD add_bal.
    FIELD-SYMBOLS <b> TYPE ty_bal.

    READ TABLE ct_bal ASSIGNING <b>
      WITH KEY ref-lfgja = is_ref-lfgja
               ref-lfbnr = is_ref-lfbnr
               ref-lfpos = is_ref-lfpos.
    IF sy-subrc <> 0.
      APPEND INITIAL LINE TO ct_bal ASSIGNING <b>.
      <b>-ref = is_ref.
    ENDIF.
    <b>-open = <b>-open + iv_qty.
  ENDMETHOD.


  METHOD log_item.
    DATA: ls_log  TYPE ty_log,
          ls_hist TYPE ty_hist.

    ls_log-ebeln   = is_item-ebeln.
    ls_log-ebelp   = is_item-ebelp.
    ls_log-status  = iv_status.
    ls_log-message = iv_msg.
    APPEND ls_log TO mt_log.

    LOOP AT it_hist INTO ls_hist.
      CLEAR ls_log.
      ls_log-ebeln     = is_item-ebeln.
      ls_log-ebelp     = is_item-ebelp.
      ls_log-vgabe     = ls_hist-vgabe.
      ls_log-belnr     = ls_hist-belnr.
      ls_log-gjahr     = ls_hist-gjahr.
      ls_log-buzei     = ls_hist-buzei.
      ls_log-bwart     = ls_hist-bwart.
      ls_log-shkzg     = ls_hist-shkzg.
      ls_log-menge     = ls_hist-menge.
      ls_log-old_lfbnr = ls_hist-old-lfbnr.
      ls_log-old_lfgja = ls_hist-old-lfgja.
      ls_log-old_lfpos = ls_hist-old-lfpos.
      ls_log-new_lfbnr = ls_hist-new-lfbnr.
      ls_log-new_lfgja = ls_hist-new-lfgja.
      ls_log-new_lfpos = ls_hist-new-lfpos.
      ls_log-status    = iv_status.
      IF ls_hist-new = ls_hist-old.
        ls_log-message = 'Reference unchanged'.
      ELSE.
        ls_log-message = 'Reference set'.
      ENDIF.
      APPEND ls_log TO mt_log.
    ENDLOOP.
  ENDMETHOD.


  METHOD display.
    DATA: lo_alv  TYPE REF TO cl_salv_table,
          lo_cols TYPE REF TO cl_salv_columns_table.

    IF mt_log IS INITIAL.
      MESSAGE 'No PO items without GR-based IV found for the selection' TYPE 'S'.
      RETURN.
    ENDIF.

    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = lo_alv
                                CHANGING  t_table      = mt_log ).
        lo_alv->get_functions( )->set_all( abap_true ).
        lo_cols = lo_alv->get_columns( ).
        lo_cols->set_optimize( abap_true ).
        set_text( io_cols = lo_cols iv_name = 'OLD_LFBNR' iv_text = 'Old ref. doc' ).
        set_text( io_cols = lo_cols iv_name = 'OLD_LFGJA' iv_text = 'Old ref. year' ).
        set_text( io_cols = lo_cols iv_name = 'OLD_LFPOS' iv_text = 'Old ref. item' ).
        set_text( io_cols = lo_cols iv_name = 'NEW_LFBNR' iv_text = 'New ref. doc' ).
        set_text( io_cols = lo_cols iv_name = 'NEW_LFGJA' iv_text = 'New ref. year' ).
        set_text( io_cols = lo_cols iv_name = 'NEW_LFPOS' iv_text = 'New ref. item' ).
        set_text( io_cols = lo_cols iv_name = 'STATUS'    iv_text = 'Status' ).
        set_text( io_cols = lo_cols iv_name = 'MESSAGE'   iv_text = 'Message' ).
        lo_alv->display( ).
      CATCH cx_salv_msg.
        MESSAGE 'ALV output could not be created' TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD set_text.
    DATA: lo_col TYPE REF TO cl_salv_column,
          lv_s   TYPE scrtext_s,
          lv_m   TYPE scrtext_m,
          lv_l   TYPE scrtext_l.

    lv_s = iv_text.
    lv_m = iv_text.
    lv_l = iv_text.
    TRY.
        lo_col = io_cols->get_column( iv_name ).
        lo_col->set_short_text( lv_s ).
        lo_col->set_medium_text( lv_m ).
        lo_col->set_long_text( lv_l ).
      CATCH cx_salv_not_found.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------------*
DATA go_corr TYPE REF TO lcl_webre_corr.

START-OF-SELECTION.
  CREATE OBJECT go_corr EXPORTING iv_test = p_test.
  go_corr->run( ).
