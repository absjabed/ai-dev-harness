#!/usr/bin/env python3
"""Convert a release document (e.g. a deployment guide) from Markdown to .docx.

The Markdown file is the single source of truth. The .docx this produces is a build
artifact: regenerate it after every edit to the Markdown, never hand-edit it in Word
(a .docx cannot be diffed in git, so a manual edit is invisible to review and is lost
on the next regeneration).

Usage:
    python .claude/scripts/md-to-docx.py docs/release/1.4/deployment-guide-1.4.md
    python .claude/scripts/md-to-docx.py <input.md> -o <output.docx>
    python .claude/scripts/md-to-docx.py <input.md> --org "Acme Corp" --color "#2D6CDF"

--org and --color come from .ai/config/branding.md (company name, primary colour). Both are
optional: without --org the byline omits the organisation; without --color a neutral blue is used.

Requires: python-docx, markdown-it-py.
"""

from __future__ import annotations

import argparse
import re
import sys
from datetime import date
from pathlib import Path

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.opc.constants import RELATIONSHIP_TYPE as RT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Emu, Pt, RGBColor
from markdown_it import MarkdownIt

# --- House style -------------------------------------------------------------------
# Accent colour: headings, the title, callout rules and table header fill. Defaults to a
# neutral blue; set_accent() overrides it from --color (PRIMARY_COLOR in branding.md).
DEFAULT_ACCENT = "2D6CDF"
ACCENT = DEFAULT_ACCENT
ACCENT_RGB = RGBColor.from_string(DEFAULT_ACCENT)
CALLOUT_FILL = "EAF0FC"  # light tint of ACCENT, for blockquote callouts
CODE_FILL = "F4F5F7"  # neutral grey, for fenced code blocks
RULE_GREY = "BFC4C9"
TEXT_GREY = RGBColor(0x53, 0x5A, 0x60)

BODY_FONT = "Calibri"
CODE_FONT = "Consolas"
BODY_SIZE = Pt(10.5)
CODE_SIZE = Pt(9)

# Indent per nesting level, matched to Word's built-in List Bullet styles.
INDENT_STEP = Cm(0.63)

CHECKED_BOX = "☑"  # ☑
UNCHECKED_BOX = "☐"  # ☐
BULLETS = ("•", "◦", "▪")  # • ◦ ▪

# `- [ ] text` / `- [x] text` at the start of a list item's inline content.
TASK_ITEM_RE = re.compile(r"^\[([ xX])\]\s+")
# Headings that should start a new page in a printed guide.
PAGE_BREAK_HEADING_RE = re.compile(r"^appendi(x|xes|ces)\b", re.IGNORECASE)

# Child order of <w:pPr> per the OOXML schema (CT_PPr). Elements must be inserted in
# this order or Word may reject the file.
_PPR_ORDER = (
    "w:pStyle", "w:keepNext", "w:keepLines", "w:pageBreakBefore", "w:framePr",
    "w:widowControl", "w:numPr", "w:suppressLineNumbers", "w:pBdr", "w:shd", "w:tabs",
    "w:suppressAutoHyphens", "w:kinsoku", "w:wordWrap", "w:overflowPunct",
    "w:topLinePunct", "w:autoSpaceDE", "w:autoSpaceDN", "w:bidi", "w:adjustRightInd",
    "w:snapToGrid", "w:spacing", "w:ind", "w:contextualSpacing", "w:mirrorIndents",
    "w:suppressOverlap", "w:jc", "w:textDirection", "w:textAlignment",
    "w:textboxTightWrap", "w:outlineLvl", "w:divId", "w:cnfStyle", "w:rPr",
    "w:sectPr", "w:pPrChange",
)
# Child order of <w:tcPr> per the OOXML schema (CT_TcPr).
_TCPR_ORDER = (
    "w:cnfStyle", "w:tcW", "w:gridSpan", "w:hMerge", "w:vMerge", "w:tcBorders",
    "w:shd", "w:noWrap", "w:tcMar", "w:textDirection", "w:tcFitText", "w:vAlign",
    "w:hideMark",
)


# --- Low-level OOXML helpers -------------------------------------------------------

def _insert_ordered(parent, element, order: tuple[str, ...]) -> None:
    """Insert `element` into `parent` at its schema-mandated position."""
    tag = element.tag.split("}")[-1]
    want = order.index(f"w:{tag}")
    for existing in parent:
        existing_tag = existing.tag.split("}")[-1]
        key = f"w:{existing_tag}"
        if key in order and order.index(key) > want:
            existing.addprevious(element)
            return
    parent.append(element)


def _shade(properties, fill: str, order: tuple[str, ...]) -> None:
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), fill)
    _insert_ordered(properties, shd, order)


def shade_paragraph(paragraph, fill: str) -> None:
    _shade(paragraph._p.get_or_add_pPr(), fill, _PPR_ORDER)


def shade_cell(cell, fill: str) -> None:
    _shade(cell._tc.get_or_add_tcPr(), fill, _TCPR_ORDER)


def set_paragraph_borders(paragraph, edges: dict[str, tuple[str, int]]) -> None:
    """Apply borders to a paragraph. `edges` maps edge name -> (hex colour, eighth-pt size)."""
    border = OxmlElement("w:pBdr")
    for edge in ("top", "left", "bottom", "right"):
        if edge not in edges:
            continue
        colour, size = edges[edge]
        element = OxmlElement(f"w:{edge}")
        element.set(qn("w:val"), "single")
        element.set(qn("w:sz"), str(size))
        element.set(qn("w:space"), "4")
        element.set(qn("w:color"), colour)
        border.append(element)
    _insert_ordered(paragraph._p.get_or_add_pPr(), border, _PPR_ORDER)


def set_cell_borders(cell, edges: dict[str, tuple[str, int]]) -> None:
    borders = OxmlElement("w:tcBorders")
    for edge in ("top", "left", "bottom", "right"):
        if edge not in edges:
            continue
        colour, size = edges[edge]
        element = OxmlElement(f"w:{edge}")
        element.set(qn("w:val"), "single")
        element.set(qn("w:sz"), str(size))
        element.set(qn("w:space"), "0")
        element.set(qn("w:color"), colour)
        borders.append(element)
    _insert_ordered(cell._tc.get_or_add_tcPr(), borders, _TCPR_ORDER)


def set_cell_margins(cell, *, top: int, start: int, bottom: int, end: int) -> None:
    """Set cell padding, in twentieths of a point."""
    margins = OxmlElement("w:tcMar")
    for name, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        margins.append(_margin_element(name, value))
    _insert_ordered(cell._tc.get_or_add_tcPr(), margins, _TCPR_ORDER)


def _margin_element(name: str, value: int):
    element = OxmlElement(f"w:{name}")
    element.set(qn("w:w"), str(value))
    element.set(qn("w:type"), "dxa")
    return element


def repeat_header_row(row) -> None:
    """Mark a table row as a header row, so Word repeats it across page breaks."""
    properties = row._tr.get_or_add_trPr()
    header = OxmlElement("w:tblHeader")
    header.set(qn("w:val"), "true")
    properties.append(header)


def add_field(paragraph, instruction: str, *, dirty: bool = False):
    """Append a Word field code (TOC, PAGE, NUMPAGES, ...) to a paragraph."""
    run = paragraph.add_run()
    begin = OxmlElement("w:fldChar")
    begin.set(qn("w:fldCharType"), "begin")
    if dirty:
        # Tells Word the field result is stale, so it offers to rebuild on open.
        begin.set(qn("w:dirty"), "true")
    instruction_element = OxmlElement("w:instrText")
    instruction_element.set(qn("xml:space"), "preserve")
    instruction_element.text = instruction
    separate = OxmlElement("w:fldChar")
    separate.set(qn("w:fldCharType"), "separate")
    end = OxmlElement("w:fldChar")
    end.set(qn("w:fldCharType"), "end")
    for element in (begin, instruction_element, separate, end):
        run._r.append(element)
    return run


def add_hyperlink(paragraph, url: str, runs: list[tuple[str, dict]]) -> None:
    """Append an external hyperlink built from (text, formatting) pairs."""
    relationship_id = paragraph.part.relate_to(url, RT.HYPERLINK, is_external=True)
    link = OxmlElement("w:hyperlink")
    link.set(qn("r:id"), relationship_id)
    for text, formatting in runs:
        run = paragraph.add_run(text)
        apply_formatting(run, {**formatting, "link": True})
        link.append(run._r)
    paragraph._p.append(link)


def set_table_width(table, width) -> None:
    """Pin the table's overall width, in EMU."""
    element = OxmlElement("w:tblW")
    element.set(qn("w:w"), str(int(width.twips)))
    element.set(qn("w:type"), "dxa")
    properties = table._tbl.tblPr
    for existing in properties.findall(qn("w:tblW")):
        properties.remove(existing)
    layout = properties.find(qn("w:tblLayout"))
    if layout is not None:
        layout.addprevious(element)
    else:
        properties.append(element)


def column_weights(rows: list[list[tuple]]) -> list[int]:
    """Weight each column by how much text it holds.

    python-docx gives every column the same width, and Word's own autofit weights a
    column by its longest line — which lets a verbose *header* squeeze the column's
    data (e.g. an environment matrix's short "Env" column wrapping under a long
    "Infrastructure (platform-infra)" header). So a header's influence is capped, a long body
    cell's is capped too, and every column keeps a floor.
    """
    header, body = rows[0], rows[1:]
    weights = []
    for column in range(len(header)):
        header_length = len(plain_text(header[column][0]))
        body_length = max(
            (len(plain_text(row[column][0])) for row in body if column < len(row)),
            default=0,
        )
        weights.append(max(min(body_length, 48), min(header_length, 12), 6))
    return weights


def distribute_column_widths(table, rows: list[list[tuple]], total) -> None:
    """Lay the table out at a fixed width, apportioned by `column_weights`."""
    weights = column_weights(rows)
    minimum = Cm(1.5)
    total_weight = sum(weights)
    widths = [int(total * weight / total_weight) for weight in weights]

    # Lift any starved column to the floor, taking the difference from the columns that
    # can spare it, so the row still sums to the text width.
    deficit = sum(minimum - width for width in widths if width < minimum)
    if deficit:
        spare = [index for index, width in enumerate(widths) if width > minimum]
        spare_total = sum(widths[index] - minimum for index in spare) or 1
        for index in spare:
            widths[index] -= int(deficit * (widths[index] - minimum) / spare_total)
        widths = [max(width, minimum) for width in widths]

    table.autofit = False
    set_table_width(table, Emu(sum(widths)))
    for index, width in enumerate(widths):
        table.columns[index].width = width
        for cell in table.columns[index].cells:
            cell.width = width


def apply_formatting(run, formatting: dict) -> None:
    run.bold = bool(formatting.get("bold")) or None
    run.italic = bool(formatting.get("italic")) or None
    if formatting.get("strike"):
        run.font.strike = True
    if formatting.get("code"):
        run.font.name = CODE_FONT
        # Sized relative to the surrounding text, so inline code inside a heading
        # stays heading-sized instead of shrinking to body-code size.
        run.font.size = formatting.get("code_size") or CODE_SIZE
    if formatting.get("link"):
        run.font.color.rgb = ACCENT_RGB
        run.font.underline = True


# --- Document setup ----------------------------------------------------------------

def configure_styles(document: Document) -> None:
    normal = document.styles["Normal"]
    normal.font.name = BODY_FONT
    normal.font.size = BODY_SIZE
    normal.paragraph_format.space_after = Pt(6)
    normal.paragraph_format.line_spacing = 1.1

    for level, size in ((1, 18), (2, 14), (3, 12), (4, 11)):
        style = document.styles[f"Heading {level}"]
        style.font.name = BODY_FONT
        style.font.size = Pt(size)
        style.font.bold = True
        style.font.color.rgb = ACCENT_RGB
        style.paragraph_format.space_before = Pt(16 if level <= 2 else 10)
        style.paragraph_format.space_after = Pt(4)
        style.paragraph_format.keep_with_next = True

    title = document.styles["Title"]
    title.font.name = BODY_FONT
    title.font.size = Pt(26)
    title.font.bold = True
    title.font.color.rgb = ACCENT_RGB


def configure_page(document: Document) -> None:
    section = document.sections[0]
    section.page_width = Cm(21.0)  # A4
    section.page_height = Cm(29.7)
    section.top_margin = Cm(2.2)
    section.bottom_margin = Cm(2.0)
    section.left_margin = Cm(2.2)
    section.right_margin = Cm(2.0)


def content_width(document: Document):
    section = document.sections[0]
    return section.page_width - section.left_margin - section.right_margin


def add_footer(document: Document, label: str) -> None:
    paragraph = document.sections[0].footer.paragraphs[0]
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = paragraph.add_run(f"{label}   |   Page ")
    run.font.size = Pt(8)
    run.font.color.rgb = TEXT_GREY
    page = add_field(paragraph, " PAGE ")
    page.font.size = Pt(8)
    page.font.color.rgb = TEXT_GREY
    run = paragraph.add_run(" of ")
    run.font.size = Pt(8)
    run.font.color.rgb = TEXT_GREY
    total = add_field(paragraph, " NUMPAGES ")
    total.font.size = Pt(8)
    total.font.color.rgb = TEXT_GREY


def display_path(source: Path) -> str:
    """The source path as a reader should see it: relative to the repo where possible."""
    try:
        return source.resolve().relative_to(Path.cwd()).as_posix()
    except ValueError:
        return source.name


def add_title_block(
    document: Document, title: str, source: Path, generated_on: str, org: str | None
) -> None:
    heading = document.add_paragraph(title, style="Title")
    heading.paragraph_format.space_after = Pt(2)

    byline = document.add_paragraph()
    parts = [org] if org else []
    parts += ["Deployment documentation", generated_on]
    run = byline.add_run("  ·  ".join(parts))
    run.font.size = Pt(10)
    run.font.color.rgb = TEXT_GREY
    byline.paragraph_format.space_after = Pt(14)
    set_paragraph_borders(byline, {"bottom": (RULE_GREY, 6)})

    notice = document.add_paragraph()
    run = notice.add_run(
        "Generated document — do not edit. "
        f"This file is produced from {display_path(source)} by .claude/scripts/md-to-docx.py. "
        "Edit the Markdown source and regenerate; changes made here are not tracked in "
        "git and are lost on the next build."
    )
    run.font.size = Pt(9)
    run.italic = True
    shade_paragraph(notice, CALLOUT_FILL)
    set_paragraph_borders(notice, {"left": (ACCENT, 18)})
    notice.paragraph_format.left_indent = Cm(0.3)
    notice.paragraph_format.space_before = Pt(4)
    notice.paragraph_format.space_after = Pt(18)


def add_table_of_contents(document: Document) -> None:
    heading = document.add_paragraph("Contents")
    run = heading.runs[0]
    run.font.size = Pt(14)
    run.font.bold = True
    run.font.color.rgb = ACCENT_RGB
    heading.paragraph_format.space_after = Pt(6)

    # The dirty flag makes Word build the contents list when the file is opened, so no
    # "update this field" instruction is needed for the reader.
    placeholder = document.add_paragraph()
    add_field(placeholder, r' TOC \o "1-3" \h \z \u ', dirty=True)


# --- Markdown -> docx renderer -----------------------------------------------------

class DocxRenderer:
    """Walks a markdown-it token stream and writes it into a python-docx container."""

    def __init__(self, document: Document, source_dir: Path, heading_shift: int):
        self.document = document
        self.source_dir = source_dir
        self.heading_shift = heading_shift
        self.max_width = content_width(document)
        self.warnings: list[str] = []
        # Rendering target: the document body, or a table cell for callout content.
        self.container = document
        self.list_stack: list[dict] = []
        self.pending_break = False

    # -- container helpers ---------------------------------------------------------

    def new_paragraph(self, style: str | None = None):
        paragraph = (
            self.container.add_paragraph(style=style)
            if style
            else self.container.add_paragraph()
        )
        if self.pending_break and self.container is self.document:
            paragraph.paragraph_format.page_break_before = True
            self.pending_break = False
        return paragraph

    def indent(self, paragraph, levels: int, hanging: bool = False) -> None:
        paragraph.paragraph_format.left_indent = INDENT_STEP * levels
        if hanging:
            paragraph.paragraph_format.first_line_indent = -INDENT_STEP

    # -- entry point ---------------------------------------------------------------

    def render(self, tokens: list) -> None:
        index = 0
        while index < len(tokens):
            index = self.render_token(tokens, index)

    def render_token(self, tokens: list, index: int) -> int:
        token = tokens[index]
        handler = getattr(self, f"do_{token.type}", None)
        advanced = handler(tokens, index) if handler is not None else index + 1
        # Every handler consumes its whole construct; this guards a malformed stream
        # from stalling the walk.
        return max(advanced, index + 1)

    def render_block_until(self, tokens: list, index: int, closing: str) -> int:
        """Render tokens up to `closing`, which must be the matching close token.

        No nesting depth is tracked: each block handler consumes its own construct in
        full, so this loop only ever sees tokens at the current level.
        """
        while index < len(tokens):
            token = tokens[index]
            if token.type == closing:
                return index + 1
            if token.nesting == -1:
                # An unexpected close means the stream is not what we assumed — stop
                # here rather than absorbing the rest of the document.
                return index
            index = self.render_token(tokens, index)
        return index

    # -- block handlers ------------------------------------------------------------

    def do_heading_open(self, tokens: list, index: int) -> int:
        level = int(tokens[index].tag[1])
        inline = tokens[index + 1]
        text = plain_text(inline)
        if PAGE_BREAK_HEADING_RE.match(text.strip()):
            self.pending_break = True
        style_level = min(max(level - self.heading_shift, 1), 4)
        paragraph = self.new_paragraph(style=f"Heading {style_level}")
        self.write_inline(paragraph, inline)
        return index + 3  # heading_open, inline, heading_close

    def do_paragraph_open(self, tokens: list, index: int) -> int:
        inline = tokens[index + 1]
        levels = len(self.list_stack)
        if self.list_stack and self.list_stack[-1]["first_paragraph"]:
            # First paragraph of a list item carries the bullet/number/checkbox.
            return self.write_list_item_paragraph(inline, index)
        paragraph = self.new_paragraph()
        if levels:
            self.indent(paragraph, levels)
        self.write_inline(paragraph, inline)
        return index + 3  # paragraph_open, inline, paragraph_close

    def write_list_item_paragraph(self, inline, index: int) -> int:
        entry = self.list_stack[-1]
        entry["first_paragraph"] = False
        levels = len(self.list_stack)
        marker, is_task = self.item_marker(entry, inline)
        paragraph = self.new_paragraph()
        self.indent(paragraph, levels, hanging=True)
        prefix = paragraph.add_run(marker)
        if is_task:
            prefix.font.size = Pt(12)
        self.write_inline(paragraph, inline)
        return index + 3

    def item_marker(self, entry: dict, inline) -> tuple[str, bool]:
        """Return the item's prefix text, and whether it is a task-list checkbox.

        Literal markers are used rather than Word's automatic numbering: Word shares one
        numbering definition per style, so consecutive `List Number` lists continue
        counting instead of restarting, which would renumber the guide's steps.
        """
        task = self.strip_task_marker(inline)
        if task is not None:
            return f"{CHECKED_BOX if task else UNCHECKED_BOX}\t", True
        if entry["ordered"]:
            number = entry["next_number"]
            entry["next_number"] += 1
            return f"{number}.\t", False
        depth = min(len(self.list_stack) - 1, len(BULLETS) - 1)
        return f"{BULLETS[depth]}\t", False

    @staticmethod
    def strip_task_marker(inline) -> bool | None:
        """If the inline content starts with `[ ]`/`[x]`, remove it and report the state."""
        match = TASK_ITEM_RE.match(inline.content)
        if match is None:
            return None
        children = inline.children or []
        for child in children:
            if child.type == "text":
                stripped = TASK_ITEM_RE.match(child.content)
                if stripped is None:
                    return None
                child.content = child.content[stripped.end():]
                return match.group(1).lower() == "x"
        return None

    def do_bullet_list_open(self, tokens: list, index: int) -> int:
        return self.render_list(tokens, index, ordered=False)

    def do_ordered_list_open(self, tokens: list, index: int) -> int:
        return self.render_list(tokens, index, ordered=True)

    def render_list(self, tokens: list, index: int, ordered: bool) -> int:
        start = tokens[index].attrGet("start")
        self.list_stack.append(
            {
                "ordered": ordered,
                "next_number": int(start) if start else 1,
                "first_paragraph": False,
            }
        )
        closing = "ordered_list_close" if ordered else "bullet_list_close"
        index = self.render_block_until(tokens, index + 1, closing)
        self.list_stack.pop()
        return index

    def do_list_item_open(self, tokens: list, index: int) -> int:
        self.list_stack[-1]["first_paragraph"] = True
        index = self.render_block_until(tokens, index + 1, "list_item_close")
        self.list_stack[-1]["first_paragraph"] = False
        return index

    def do_blockquote_open(self, tokens: list, index: int) -> int:
        """Render a blockquote as a shaded, accent-bordered single-cell box."""
        table = self.container.add_table(rows=1, cols=1)
        table.alignment = WD_TABLE_ALIGNMENT.LEFT
        indent_levels = len(self.list_stack)
        table.autofit = False
        cell = table.cell(0, 0)
        cell.width = self.max_width - INDENT_STEP * indent_levels
        shade_cell(cell, CALLOUT_FILL)
        set_cell_borders(
            cell,
            {
                "left": (ACCENT, 18),
                "top": (CALLOUT_FILL, 4),
                "bottom": (CALLOUT_FILL, 4),
                "right": (CALLOUT_FILL, 4),
            },
        )
        set_cell_margins(cell, top=100, start=160, bottom=100, end=120)

        outer_container, outer_stack, outer_break = (
            self.container,
            self.list_stack,
            self.pending_break,
        )
        self.container, self.list_stack, self.pending_break = cell, [], False
        index = self.render_block_until(tokens, index + 1, "blockquote_close")
        self.container, self.list_stack, self.pending_break = (
            outer_container,
            outer_stack,
            outer_break,
        )

        drop_leading_empty_paragraph(cell)
        for paragraph in cell.paragraphs:
            paragraph.paragraph_format.space_after = Pt(2)
        spacer = self.new_paragraph()
        spacer.paragraph_format.space_after = Pt(0)
        spacer.paragraph_format.line_spacing = 1
        for run in spacer.runs:
            run.font.size = Pt(4)
        return index

    def do_fence(self, tokens: list, index: int) -> int:
        self.write_code_block(tokens[index].content)
        return index + 1

    def do_code_block(self, tokens: list, index: int) -> int:
        self.write_code_block(tokens[index].content)
        return index + 1

    def write_code_block(self, content: str) -> None:
        lines = content.rstrip("\n").split("\n") or [""]
        levels = len(self.list_stack)
        paragraph = self.new_paragraph()
        self.indent(paragraph, levels)
        paragraph.paragraph_format.right_indent = Cm(0.1)
        paragraph.paragraph_format.space_before = Pt(4)
        paragraph.paragraph_format.space_after = Pt(8)
        paragraph.paragraph_format.line_spacing = 1
        shade_paragraph(paragraph, CODE_FILL)
        set_paragraph_borders(
            paragraph,
            {edge: (RULE_GREY, 4) for edge in ("top", "left", "bottom", "right")},
        )
        for position, line in enumerate(lines):
            run = paragraph.add_run(line)
            run.font.name = CODE_FONT
            run.font.size = CODE_SIZE
            if position < len(lines) - 1:
                run.add_break(WD_BREAK.LINE)

    def do_hr(self, tokens: list, index: int) -> int:
        paragraph = self.new_paragraph()
        paragraph.paragraph_format.space_before = Pt(6)
        paragraph.paragraph_format.space_after = Pt(10)
        set_paragraph_borders(paragraph, {"bottom": (RULE_GREY, 6)})
        return index + 1

    def do_table_open(self, tokens: list, index: int) -> int:
        rows, index = collect_table(tokens, index)
        if not rows:
            return index
        header, body = rows[0], rows[1:]
        # _Cell.add_table() takes no `style` argument, unlike Document.add_table(),
        # so the style is assigned after creation to work in either container.
        table = self.container.add_table(rows=0, cols=len(header))
        table.style = "Table Grid"
        table.alignment = WD_TABLE_ALIGNMENT.LEFT

        header_row = table.add_row()
        for cell, (inline, alignment) in zip(header_row.cells, header):
            shade_cell(cell, ACCENT)
            paragraph = cell.paragraphs[0]
            paragraph.alignment = alignment
            paragraph.paragraph_format.space_after = Pt(2)
            self.write_inline(paragraph, inline, bold=True, colour=header_text_colour())
        repeat_header_row(header_row)

        for source_row in body:
            row = table.add_row()
            for cell, (inline, alignment) in zip(row.cells, source_row):
                paragraph = cell.paragraphs[0]
                paragraph.alignment = alignment
                paragraph.paragraph_format.space_after = Pt(2)
                self.write_inline(paragraph, inline)

        available = self.max_width - INDENT_STEP * len(self.list_stack)
        distribute_column_widths(table, rows, available)
        spacer = self.new_paragraph()
        spacer.paragraph_format.space_after = Pt(0)
        for run in spacer.runs:
            run.font.size = Pt(4)
        return index

    # -- inline rendering ----------------------------------------------------------

    def write_inline(self, paragraph, inline, *, bold: bool = False, colour=None) -> None:
        base_size = paragraph.style.font.size or BODY_SIZE
        formatting = {"bold": bold, "code_size": Pt(round(base_size.pt * 0.92, 1))}
        stack: list[dict] = [formatting]
        link_url: str | None = None
        link_runs: list[tuple[str, dict]] = []

        for child in inline.children or []:
            current = stack[-1]
            if child.type == "text":
                self.emit(paragraph, child.content, current, colour, link_url, link_runs)
            elif child.type == "code_inline":
                self.emit(
                    paragraph, child.content, {**current, "code": True}, colour,
                    link_url, link_runs,
                )
            elif child.type == "softbreak":
                self.emit(paragraph, " ", current, colour, link_url, link_runs)
            elif child.type == "hardbreak":
                if link_url is None:
                    paragraph.add_run().add_break(WD_BREAK.LINE)
            elif child.type == "strong_open":
                stack.append({**current, "bold": True})
            elif child.type == "em_open":
                stack.append({**current, "italic": True})
            elif child.type == "s_open":
                stack.append({**current, "strike": True})
            elif child.type in ("strong_close", "em_close", "s_close"):
                if len(stack) > 1:
                    stack.pop()
            elif child.type == "link_open":
                link_url = child.attrGet("href")
                link_runs = []
            elif child.type == "link_close":
                if link_url:
                    if link_runs:
                        add_hyperlink(paragraph, link_url, link_runs)
                    else:
                        add_hyperlink(paragraph, link_url, [(link_url, current)])
                link_url, link_runs = None, []
            elif child.type == "image":
                self.write_image(child)

    def emit(self, paragraph, text: str, formatting: dict, colour, link_url, link_runs) -> None:
        if not text:
            return
        if link_url is not None:
            link_runs.append((text, formatting))
            return
        run = paragraph.add_run(text)
        apply_formatting(run, formatting)
        if colour is not None:
            run.font.color.rgb = colour

    def write_image(self, token) -> None:
        source = token.attrGet("src") or ""
        alt = plain_text(token).strip()
        path = (self.source_dir / source).resolve()
        paragraph = self.new_paragraph()
        paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
        if not path.is_file():
            self.warnings.append(f"image not found, skipped: {source}")
            run = paragraph.add_run(f"[missing image: {source}]")
            run.italic = True
            run.font.color.rgb = TEXT_GREY
            return
        run = paragraph.add_run()
        picture = run.add_picture(str(path))
        if picture.width > self.max_width:
            scale = self.max_width / picture.width
            picture.width = self.max_width
            picture.height = int(picture.height * scale)
        if alt:
            caption = self.new_paragraph()
            caption.alignment = WD_ALIGN_PARAGRAPH.CENTER
            caption_run = caption.add_run(alt)
            caption_run.font.size = Pt(9)
            caption_run.italic = True
            caption_run.font.color.rgb = TEXT_GREY


# --- Token-stream utilities --------------------------------------------------------

ALIGNMENTS = {
    "text-align:center": WD_ALIGN_PARAGRAPH.CENTER,
    "text-align:right": WD_ALIGN_PARAGRAPH.RIGHT,
    "text-align:left": WD_ALIGN_PARAGRAPH.LEFT,
}


def collect_table(tokens: list, index: int) -> tuple[list[list[tuple]], int]:
    """Collect a table's cells as rows of (inline token, alignment), returning the end index."""
    rows: list[list[tuple]] = []
    current: list[tuple] | None = None
    index += 1
    while index < len(tokens):
        token = tokens[index]
        if token.type == "table_close":
            return rows, index + 1
        if token.type == "tr_open":
            current = []
        elif token.type == "tr_close":
            if current is not None:
                rows.append(current)
            current = None
        elif token.type in ("th_open", "td_open"):
            style = token.attrGet("style") or ""
            alignment = ALIGNMENTS.get(style.replace(" ", ""), None)
            inline = tokens[index + 1] if tokens[index + 1].type == "inline" else None
            if current is not None:
                current.append((inline, alignment))
        index += 1
    return rows, index


def plain_text(inline) -> str:
    if inline is None:
        return ""
    if not inline.children:
        return inline.content
    return "".join(
        child.content
        for child in inline.children
        if child.type in ("text", "code_inline")
    )


def drop_leading_empty_paragraph(cell) -> None:
    """Remove the empty paragraph python-docx creates with every new cell."""
    paragraphs = cell.paragraphs
    if len(paragraphs) > 1 and not paragraphs[0].runs:
        element = paragraphs[0]._p
        element.getparent().remove(element)


def document_title(tokens: list, fallback: str) -> tuple[str, int, list]:
    """Pick the document title.

    A single leading level-1 heading becomes the Word title and is removed from the body;
    the remaining heading levels then shift up by one so the contents list starts at
    level 1. Any other shape keeps every heading in the body and titles from the filename.
    """
    level_one = [t for t in tokens if t.type == "heading_open" and t.tag == "h1"]
    if len(level_one) == 1 and tokens and tokens[0].type == "heading_open" and tokens[0].tag == "h1":
        return plain_text(tokens[1]).strip(), 1, tokens[3:]
    return fallback, 0, tokens


# --- CLI ---------------------------------------------------------------------------

HEX_COLOR_RE = re.compile(r"^#?([0-9A-Fa-f]{6})$")


def header_text_colour() -> RGBColor:
    """White on a dark accent, near-black on a light one, so table headers stay readable."""
    r, g, b = (int(ACCENT[i : i + 2], 16) for i in (0, 2, 4))
    luminance = 0.299 * r + 0.587 * g + 0.114 * b
    return RGBColor(0x1F, 0x23, 0x28) if luminance > 160 else RGBColor(0xFF, 0xFF, 0xFF)


def set_accent(color: str) -> None:
    """Point the accent colour (and its callout tint) at a #RRGGBB value."""
    global ACCENT, ACCENT_RGB, CALLOUT_FILL
    hex_value = HEX_COLOR_RE.match(color).group(1).upper()
    ACCENT = hex_value
    ACCENT_RGB = RGBColor.from_string(hex_value)
    channels = (int(hex_value[i : i + 2], 16) for i in (0, 2, 4))
    # 90% white, 10% accent: light enough for body text on top.
    CALLOUT_FILL = "".join(f"{round(255 - (255 - c) * 0.1):02X}" for c in channels)


def convert(source: Path, destination: Path, org: str | None = None) -> list[str]:
    markdown = MarkdownIt("commonmark").enable("table").enable("strikethrough")
    text = source.read_text(encoding="utf-8")
    tokens = markdown.parse(text)

    fallback = source.stem.replace("-", " ").replace("_", " ").strip().title()
    title, shift, body_tokens = document_title(tokens, fallback)

    document = Document()
    configure_page(document)
    configure_styles(document)
    add_footer(document, title)
    add_title_block(document, title, source, date.today().isoformat(), org)
    add_table_of_contents(document)
    document.add_section(WD_SECTION.NEW_PAGE)

    renderer = DocxRenderer(document, source.parent, shift)
    renderer.render(body_tokens)

    destination.parent.mkdir(parents=True, exist_ok=True)
    document.save(str(destination))
    return renderer.warnings


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Convert a release Markdown document to .docx.",
    )
    parser.add_argument("input", type=Path, help="path to the Markdown file")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="output .docx path (default: the input path with a .docx suffix)",
    )
    parser.add_argument("--org", help="organisation name for the title-page byline")
    parser.add_argument(
        "--color",
        help=f"accent colour as #RRGGBB (default: #{DEFAULT_ACCENT})",
    )
    parser.add_argument("-q", "--quiet", action="store_true", help="suppress progress output")
    arguments = parser.parse_args(argv)

    source: Path = arguments.input
    if not source.is_file():
        parser.error(f"input file not found: {source}")
    if source.suffix.lower() not in (".md", ".markdown"):
        parser.error(f"expected a Markdown file, got: {source.name}")

    if arguments.color:
        if not HEX_COLOR_RE.match(arguments.color):
            parser.error(f"--color must be #RRGGBB, got: {arguments.color}")
        set_accent(arguments.color)

    destination: Path = arguments.output or source.with_suffix(".docx")
    warnings = convert(source, destination, arguments.org)

    for warning in warnings:
        print(f"warning: {warning}", file=sys.stderr)
    if not arguments.quiet:
        print(f"{source} -> {destination}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
