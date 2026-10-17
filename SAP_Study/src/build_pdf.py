"""Build the detailed study-guide PDF from the markdown-like content files.

Markup supported in content/*.md:
  @part <title> | <subtitle>   -> full-page part divider
  # / ## / ###                 -> chapter / section / subsection
  - item / 1. item             -> bullets / numbered list
  ```abap ... ```              -> code block (syntax highlighted)
  :::note|tip|warn|lab|solution [title] ... :::  -> callout box
  | a | b |                    -> table (first row = header)
  Q: ... / A: ...              -> interview question / answer
  **bold**, `code`, *italic*   -> inline formatting
"""
import re
import sys
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (BaseDocTemplate, CondPageBreak, Frame, KeepTogether,
                                NextPageTemplate, PageBreak, PageTemplate, Paragraph,
                                Spacer, Table, TableStyle)
from reportlab.platypus.tableofcontents import TableOfContents

FONT_DIR = "/usr/share/fonts/truetype/dejavu/"
LIB_DIR = "/usr/share/fonts/truetype/liberation/"
pdfmetrics.registerFont(TTFont("Sans", LIB_DIR + "LiberationSans-Regular.ttf"))
pdfmetrics.registerFont(TTFont("Sans-Bold", LIB_DIR + "LiberationSans-Bold.ttf"))
pdfmetrics.registerFont(TTFont("Sans-Oblique", LIB_DIR + "LiberationSans-Italic.ttf"))
pdfmetrics.registerFont(TTFont("Sans-BoldOblique", LIB_DIR + "LiberationSans-BoldItalic.ttf"))
pdfmetrics.registerFont(TTFont("Mono-Oblique", FONT_DIR + "DejaVuSansMono-Oblique.ttf"))
pdfmetrics.registerFont(TTFont("Mono", FONT_DIR + "DejaVuSansMono.ttf"))
pdfmetrics.registerFont(TTFont("Mono-Bold", FONT_DIR + "DejaVuSansMono-Bold.ttf"))
pdfmetrics.registerFontFamily("Sans", normal="Sans", bold="Sans-Bold",
                              italic="Sans-Oblique", boldItalic="Sans-BoldOblique")
pdfmetrics.registerFontFamily("Mono", normal="Mono", bold="Mono-Bold",
                              italic="Mono-Oblique", boldItalic="Mono-Bold")

INK = colors.HexColor("#1B2430")
PRIMARY = colors.HexColor("#0B5394")      # SAP-ish deep blue
ACCENT = colors.HexColor("#F0AB00")       # SAP gold
MUTED = colors.HexColor("#5F6B7A")
CODE_BG = colors.HexColor("#F4F6F9")
CODE_BORDER = colors.HexColor("#D5DCE5")

CALLOUTS = {
    "note": ("Note", colors.HexColor("#EAF2FB"), PRIMARY),
    "tip": ("Tip", colors.HexColor("#EAF7EE"), colors.HexColor("#1E7B3A")),
    "warn": ("Watch out", colors.HexColor("#FDF1E6"), colors.HexColor("#B4540A")),
    "lab": ("Practical Lab", colors.HexColor("#FFF7E0"), colors.HexColor("#8A6100")),
    "solution": ("Solution", colors.HexColor("#F1EEFA"), colors.HexColor("#5B3FA3")),
}

S = {}
S["body"] = ParagraphStyle("body", fontName="Sans", fontSize=9.6, leading=14.2,
                           textColor=INK, spaceAfter=6)
S["h1"] = ParagraphStyle("h1", fontName="Sans-Bold", fontSize=20, leading=25,
                         textColor=PRIMARY, spaceBefore=4, spaceAfter=12)
S["h2"] = ParagraphStyle("h2", fontName="Sans-Bold", fontSize=14, leading=18,
                         textColor=INK, spaceBefore=12, spaceAfter=6)
S["h3"] = ParagraphStyle("h3", fontName="Sans-Bold", fontSize=11.2, leading=15,
                         textColor=PRIMARY, spaceBefore=8, spaceAfter=4)
S["bullet"] = ParagraphStyle("bullet", parent=S["body"], leftIndent=14,
                             bulletIndent=4, spaceAfter=2.5)
S["code"] = ParagraphStyle("code", fontName="Mono", fontSize=8, leading=10.4,
                           textColor=INK)
S["code_in"] = ParagraphStyle("code_in", parent=S["code"], backColor=colors.white,
                              leftIndent=4, borderPadding=(0, 4, 0, 4))
S["cell"] = ParagraphStyle("cell", parent=S["body"], fontSize=8.6, leading=11.5,
                           spaceAfter=0)
S["cellh"] = ParagraphStyle("cellh", parent=S["cell"], fontName="Sans-Bold",
                            textColor=colors.white)
S["q"] = ParagraphStyle("q", parent=S["body"], fontName="Sans-Bold", textColor=PRIMARY,
                        spaceBefore=6, spaceAfter=2)
S["a"] = ParagraphStyle("a", parent=S["body"], leftIndent=12)
S["toc1"] = ParagraphStyle("toc1", fontName="Sans-Bold", fontSize=10.5, leading=16,
                           textColor=INK, leftIndent=0)
S["toc2"] = ParagraphStyle("toc2", fontName="Sans", fontSize=9.3, leading=13,
                           textColor=MUTED, leftIndent=16)

ABAP_KEYWORDS = """
ABSTRACT ADD ALIASES AND APPEND ASSIGN AS ASSIGNING AT AUTHORITY-CHECK BEGIN BINARY BY
CALL CASE CAST CATCH CHANGING CHECK CLASS CLASS-DATA CLASS-EVENTS CLASS-METHODS CLEANUP
CLEAR COMMIT COND CONSTANTS CONV CORRESPONDING CREATE DATA DEFAULT DEFERRED DEFINE
DEFINITION DELETE DESCENDING DO ELSE ELSEIF END END-OF-SELECTION ENDCASE ENDCLASS ENDDO
ENDFORM ENDIF ENDINTERFACE ENDLOOP ENDMETHOD ENDMODULE ENDSELECT ENDTRY ENDWHILE EVENTS
EXCEPTIONS EXIT EXPORTING EXPORTS FIELD-SYMBOL FIELD-SYMBOLS FINAL FIELDS FOR FORM FRIENDS
FROM FUNCTION GLOBAL GROUP HANDLER IF IMPLEMENTATION IMPORTING IN INHERITING INITIAL
INNER INSERT INSTANCE INTERFACE INTERFACES INTO IS JOIN KEY LEFT LIKE LINE LOOP
METHOD METHODS MODIFY MOVE-CORRESPONDING NEW NOT OF OPTIONAL OR ORDER OTHERS OUTER
PARAMETERS PRIVATE PROTECTED PUBLIC RAISE RAISING READ READ-ONLY REDEFINITION REDUCE
REF REFERENCE REPORT RESUME RETRY RETURN RETURNING ROLLBACK SECTION SELECT SET SINGLE
SORT START-OF-SELECTION STATIC STRUCTURE SUPER SWITCH TABLE TABLES TESTING THEN TO TRY
TYPE TYPES UNIQUE UP UPDATE USING VALUE WHEN WHERE WHILE WITH WORK ENDINTERFACE
DURATION RISK LEVEL HARMLESS SHORT ASSERT ENDENUM LOCAL EVENT ENTITY ENTITIES
MODIFY FIELDS RESULT FAILED REPORTED MAPPED ACTION ACTIONS DETERMINATION VALIDATION
ON SAVE LOCK ETAG MASTER AUTHORIZATION MANAGED UNMANAGED DRAFT ASSOCIATION COMPOSITION
PROJECTION DEFINE ROOT VIEW PARENT EXPOSE PROVIDER CONTRACT TRANSACTIONAL_QUERY USE
""".split()
KW_RE = re.compile(r"\b(" + "|".join(sorted(set(ABAP_KEYWORDS), key=len, reverse=True))
                   + r")\b")
KW_SPLIT = re.compile(r"(\b(?:" + "|".join(sorted(set(ABAP_KEYWORDS), key=len, reverse=True))
                      + r")\b)")


def esc(text):
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def inline(text):
    """Convert **bold**, `code`, *italic* to reportlab markup (input is raw text)."""
    parts = re.split(r"(`[^`]+`)", text)
    out = []
    for part in parts:
        if part.startswith("`") and part.endswith("`") and len(part) > 1:
            out.append('<font name="Mono" size="8.6" color="#9C2A00">%s</font>'
                       % esc(part[1:-1]))
        else:
            p = esc(part)
            p = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", p)
            p = re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])", r"<i>\1</i>", p)
            out.append(p)
    return "".join(out)


def _nb(text):
    return esc(text).replace(" ", "&nbsp;")


def highlight_line(line, lang):
    """Return reportlab markup for one code line, keeping indentation."""
    stripped = line.lstrip()
    grey = '<font color="#6A737D"><i>%s</i></font>'
    if lang not in ("abap", "cds"):
        return _nb(line) or "&nbsp;"
    if line.startswith("*") or stripped.startswith('"') or stripped.startswith("//"):
        return grey % _nb(line)
    comment = ""
    m = re.search(r'(\s"|\s//)[^\'`|]*$', line)
    if m:
        comment, line = line[m.start():], line[:m.start()]
    segs = re.split(r"('[^']*'|`[^`]*`|\|[^|]*\|)", line)
    html = []
    for seg in segs:
        if not seg:
            continue
        if seg[0] in "'`|" and len(seg) > 1 and seg[-1] == seg[0]:
            html.append('<font color="#0A7C2F">%s</font>' % _nb(seg))
        else:
            for tok in KW_SPLIT.split(seg):
                if not tok:
                    continue
                if KW_RE.fullmatch(tok):
                    html.append('<font color="#0B3D91"><b>%s</b></font>' % _nb(tok))
                else:
                    html.append(_nb(tok))
    out = "".join(html)
    if comment:
        out += grey % _nb(comment)
    return out or "&nbsp;"


def code_block(lines, lang, width):
    rows = [[Paragraph(highlight_line(l.rstrip("\n"), lang), S["code"])] for l in lines]
    t = Table(rows, colWidths=[width], splitByRow=1)
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), CODE_BG),
        ("BOX", (0, 0), (-1, -1), 0.6, CODE_BORDER),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 0.4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 0.4),
        ("TOPPADDING", (0, 0), (-1, 0), 5),
        ("BOTTOMPADDING", (0, -1), (-1, -1), 5),
    ]))
    return [Spacer(1, 2), t, Spacer(1, 8)]


def table_block(rows, width):
    ncols = len(rows[0])
    data = []
    for i, r in enumerate(rows):
        r = (r + [""] * ncols)[:ncols]
        st = S["cellh"] if i == 0 else S["cell"]
        data.append([Paragraph(inline(c), st) for c in r])
    # weight columns by content length
    lens = [max(len(r[c]) if c < len(r) else 0 for r in rows) for c in range(ncols)]
    lens = [min(max(l, 12), 60) for l in lens]
    tot = sum(lens)
    widths = [width * l / tot for l in lens]
    t = Table(data, colWidths=widths, repeatRows=1)
    style = [
        ("BACKGROUND", (0, 0), (-1, 0), PRIMARY),
        ("GRID", (0, 0), (-1, -1), 0.4, CODE_BORDER),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]
    for i in range(1, len(data)):
        if i % 2 == 0:
            style.append(("BACKGROUND", (0, i), (-1, i), colors.HexColor("#F7F9FC")))
    t.setStyle(TableStyle(style))
    return [Spacer(1, 2), t, Spacer(1, 8)]


def callout_block(kind, title, inner_flowables, width):
    label, bg, fg = CALLOUTS[kind]
    head = Paragraph('<font color="%s"><b>%s%s</b></font>'
                     % (fg.hexval().replace("0x", "#"), label,
                        (": " + esc(title)) if title else ""), S["body"])
    while inner_flowables and isinstance(inner_flowables[-1], Spacer):
        inner_flowables = inner_flowables[:-1]
    rows = [[head]] + [[f] for f in inner_flowables]
    t = Table(rows, colWidths=[width], splitByRow=1)
    code_rows = [("TOPPADDING", (0, i + 1), (0, i + 1), 0)
                 for i, f in enumerate(inner_flowables)
                 if isinstance(f, Paragraph) and f.style.name == "code_in"]
    code_rows += [("BOTTOMPADDING", (0, i + 1), (0, i + 1), 0)
                  for i, f in enumerate(inner_flowables)
                  if isinstance(f, Paragraph) and f.style.name == "code_in"
                  and i + 1 < len(inner_flowables)]
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), bg),
        ("LINEBEFORE", (0, 0), (0, -1), 3, fg),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 1),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 1),
        ("TOPPADDING", (0, 0), (-1, 0), 6),
        ("BOTTOMPADDING", (0, -1), (-1, -1), 6),
    ]))
    t.setStyle(TableStyle(code_rows))
    return [Spacer(1, 3), t, Spacer(1, 9)]


class PartDivider(PageBreak):
    pass


def parse(text, width):
    """Parse content text into flowables."""
    flow = []
    lines = text.split("\n")
    i = 0
    para = []

    def flush_para(target):
        if para:
            target.append(Paragraph(inline(" ".join(para)), S["body"]))
            para.clear()

    def parse_simple(block_lines, inner_width):
        """Parse inside callouts: paragraphs, bullets, code."""
        out, buf = [], []
        j = 0
        while j < len(block_lines):
            ln = block_lines[j]
            if ln.startswith("```"):
                if buf:
                    out.append(Paragraph(inline(" ".join(buf)), S["body"])); buf = []
                lang = ln[3:].strip() or "text"
                code = []
                j += 1
                while not block_lines[j].startswith("```"):
                    code.append(block_lines[j]); j += 1
                out.append(Spacer(1, 2))
                for c in code:
                    out.append(Paragraph(highlight_line(c, lang), S["code_in"]))
                out.append(Spacer(1, 4))
            elif re.match(r"^\s*(- |\d+\. )", ln):
                if buf:
                    out.append(Paragraph(inline(" ".join(buf)), S["body"])); buf = []
                m = re.match(r"^\s*(- |(\d+)\. )(.*)", ln)
                bullet = "•" if m.group(1) == "- " else m.group(2) + "."
                out.append(Paragraph(inline(m.group(3)), S["bullet"], bulletText=bullet))
            elif not ln.strip():
                if buf:
                    out.append(Paragraph(inline(" ".join(buf)), S["body"])); buf = []
            else:
                buf.append(ln.strip())
            j += 1
        if buf:
            out.append(Paragraph(inline(" ".join(buf)), S["body"]))
        return out

    while i < len(lines):
        line = lines[i]
        if line.startswith("@part "):
            flush_para(flow)
            title, _, sub = line[6:].partition("|")
            flow.append(("PART", title.strip(), sub.strip()))
        elif line.startswith("### "):
            flush_para(flow)
            flow.append(CondPageBreak(60 * mm))
            flow.append(Paragraph(inline(line[4:]), S["h3"]))
        elif line.startswith("## "):
            flush_para(flow)
            flow.append(CondPageBreak(70 * mm))
            p = Paragraph(inline(line[3:]), S["h2"])
            p._toc_level = 1
            flow.append(p)
        elif line.startswith("# "):
            flush_para(flow)
            flow.append(PageBreak())
            p = Paragraph(inline(line[2:]), S["h1"])
            p._toc_level = 0
            flow.append(p)
        elif line.startswith("```"):
            flush_para(flow)
            lang = line[3:].strip() or "text"
            code = []
            i += 1
            while not lines[i].startswith("```"):
                code.append(lines[i]); i += 1
            flow.extend(code_block(code, lang, width))
        elif line.startswith(":::"):
            flush_para(flow)
            m = re.match(r":::(\w+)\s*(.*)", line)
            kind, title = m.group(1), m.group(2).strip()
            block = []
            i += 1
            while not lines[i].startswith(":::"):
                block.append(lines[i]); i += 1
            inner = parse_simple(block, width - 20)
            flow.extend(callout_block(kind, title, inner, width))
        elif line.startswith("|"):
            flush_para(flow)
            rows = []
            while i < len(lines) and lines[i].startswith("|"):
                cells = [c.strip() for c in lines[i].strip().strip("|").split("|")]
                if not all(re.fullmatch(r":?-{2,}:?", c) for c in cells):
                    rows.append(cells)
                i += 1
            flow.extend(table_block(rows, width))
            continue
        elif line.startswith("Q: "):
            flush_para(flow)
            q = Paragraph(inline(line[3:]), S["q"])
            ans = []
            i += 1
            while i < len(lines) and lines[i].strip() and not lines[i].startswith("Q: "):
                ans.append(lines[i][3:] if lines[i].startswith("A: ") else lines[i].strip())
                i += 1
            flow.append(KeepTogether([q, Paragraph(inline(" ".join(ans)), S["a"])]))
            continue
        elif re.match(r"^\s*(- |\d+\. )", line):
            flush_para(flow)
            m = re.match(r"^(\s*)(- |(\d+)\. )(.*)", line)
            bullet = "•" if m.group(2) == "- " else m.group(3) + "."
            st = S["bullet"]
            if m.group(1):
                st = ParagraphStyle("b2", parent=S["bullet"], leftIndent=28, bulletIndent=18)
                bullet = "–" if bullet == "•" else bullet
            flow.append(Paragraph(inline(m.group(4)), st, bulletText=bullet))
        elif not line.strip():
            flush_para(flow)
        else:
            para.append(line.strip())
        i += 1
    flush_para(flow)
    return flow


class GuideDoc(BaseDocTemplate):
    def __init__(self, path, **kw):
        super().__init__(path, pagesize=A4, leftMargin=20 * mm, rightMargin=20 * mm,
                         topMargin=20 * mm, bottomMargin=18 * mm, **kw)
        fr = Frame(self.leftMargin, self.bottomMargin, self.width, self.height, id="f")
        self.addPageTemplates([
            PageTemplate("cover", [fr], onPage=self.draw_cover),
            PageTemplate("part", [fr], onPage=self.draw_part),
            PageTemplate("body", [fr], onPage=self.draw_body),
        ])
        self.current_part = ""
        self.part_info = {}

    def beforeDocument(self):
        self.current_part = ""

    def afterFlowable(self, f):
        if isinstance(f, Paragraph) and hasattr(f, "_toc_level"):
            lvl = f._toc_level
            text = f.getPlainText()
            key = "h%d_%d" % (lvl, id(f))
            self.canv.bookmarkPage(key)
            self.canv.addOutlineEntry(text, key, level=lvl + (1 if self.current_part else 0),
                                    closed=lvl > 0)
            self.notify("TOCEntry", (lvl, text, self.page, key))
        if isinstance(f, PartMarker):
            self.current_part = f.title
            key = "part_%d" % id(f)
            self.canv.bookmarkPage(key)
            self.canv.addOutlineEntry(f.title, key, level=0, closed=False)

    def draw_cover(self, c, doc):
        w, h = A4
        c.saveState()
        c.setFillColor(colors.HexColor("#0A2540"))
        c.rect(0, 0, w, h, fill=1, stroke=0)
        c.setFillColor(colors.HexColor("#0B5394"))
        c.circle(w - 30 * mm, h - 40 * mm, 70 * mm, fill=1, stroke=0)
        c.setFillColor(ACCENT)
        c.circle(w - 60 * mm, h - 110 * mm, 18 * mm, fill=1, stroke=0)
        c.setFillColor(colors.white)
        c.setFont("Sans-Bold", 13)
        c.drawString(22 * mm, h - 40 * mm, "SAP DEVELOPMENT STUDY GUIDE")
        c.setFont("Sans-Bold", 38)
        c.drawString(22 * mm, h - 150 * mm, "ABAP Objects")
        c.setFillColor(ACCENT)
        c.drawString(22 * mm, h - 166 * mm, "& OData")
        c.setFillColor(colors.HexColor("#C9D6E8"))
        c.setFont("Sans", 13)
        c.drawString(22 * mm, h - 182 * mm, "From beginner to advanced — concepts, code,")
        c.drawString(22 * mm, h - 189 * mm, "practical labs and interview preparation")
        c.setFont("Sans", 10)
        c.drawString(22 * mm, 30 * mm, "Part I  ABAP Objects (OO ABAP)     Part II  OData & SAP Gateway / RAP")
        c.drawString(22 * mm, 24 * mm, "Part III  Interview Questions        Part IV  Capstone Projects & Cheat Sheets")
        c.restoreState()

    def draw_part(self, c, doc):
        w, h = A4
        c.saveState()
        c.setFillColor(colors.HexColor("#0A2540"))
        c.rect(0, 0, w, h, fill=1, stroke=0)
        info = self.part_info.get(self.page, ("", ""))
        c.setFillColor(ACCENT)
        c.circle(30 * mm, h - 60 * mm, 9 * mm, fill=1, stroke=0)
        c.setFillColor(colors.white)
        c.setFont("Sans-Bold", 30)
        c.drawString(22 * mm, h / 2 + 10 * mm, info[0])
        c.setFillColor(colors.HexColor("#C9D6E8"))
        c.setFont("Sans", 13)
        y = h / 2 - 4 * mm
        for ln in info[1].split(" / "):
            c.drawString(22 * mm, y, ln)
            y -= 7 * mm
        c.restoreState()

    def draw_body(self, c, doc):
        w, h = A4
        c.saveState()
        c.setFont("Sans", 7.8)
        c.setFillColor(MUTED)
        c.drawString(20 * mm, h - 12 * mm, "ABAP Objects & OData — Study Guide")
        c.drawRightString(w - 20 * mm, h - 12 * mm, self.current_part)
        c.setStrokeColor(CODE_BORDER)
        c.setLineWidth(0.5)
        c.line(20 * mm, h - 14 * mm, w - 20 * mm, h - 14 * mm)
        c.drawCentredString(w / 2, 10 * mm, str(doc.page))
        c.restoreState()


class PartMarker(Spacer):
    def __init__(self, title, sub):
        super().__init__(1, 1)
        self.title, self.sub = title, sub

    def drawOn(self, canvas, x, y, _sW=0):
        doc = canvas._doctemplate
        doc.part_info[canvas.getPageNumber()] = (self.title, self.sub)
        super().drawOn(canvas, x, y, _sW)


def build(content_dir, out_path):
    doc = GuideDoc(out_path, title="ABAP Objects & OData — Study Guide",
                   author="SAP Study Session", subject="ABAP OO and OData")
    width = doc.width
    story = [NextPageTemplate("body"), PageBreak()]
    toc = TableOfContents()
    toc.levelStyles = [S["toc1"], S["toc2"]]
    toc.dotsMinLevel = 0
    story.append(Paragraph("Contents", S["h1"]))
    story.append(toc)
    for path in sorted(Path(content_dir).glob("*.md")):
        for f in parse(path.read_text(encoding="utf-8"), width):
            if isinstance(f, tuple) and f[0] == "PART":
                story += [NextPageTemplate("part"), PageBreak(), PartMarker(f[1], f[2]),
                          NextPageTemplate("body")]
            else:
                story.append(f)
    # remove PageBreak directly following a part marker (chapter after divider)
    cleaned = []
    for idx, f in enumerate(story):
        if (isinstance(f, PageBreak) and idx >= 2 and isinstance(story[idx - 1],
                                                                  NextPageTemplate)
                and isinstance(story[idx - 2], PartMarker)):
            cleaned.append(f)  # needed: moves off divider page
            continue
        cleaned.append(f)
    doc.multiBuild(cleaned)


if __name__ == "__main__":
    build(sys.argv[1], sys.argv[2])
