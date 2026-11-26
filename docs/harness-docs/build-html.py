#!/usr/bin/env python3
"""Build docs/how-it-works.html from docs/harness-docs/ai-dev-harness.md.

    python docs/harness-docs/build-html.py          # write the page
    python docs/harness-docs/build-html.py --check  # exit 1 if the page is out of date

The Markdown guide is the source; never edit the HTML by hand. The page borrows its stylesheet
from docs/standards.html so the three HTML pages look alike. Standard library only.
"""
import html
import os
import re
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DOCS = os.path.dirname(HERE)
REPO = os.path.dirname(DOCS)
SRC = os.path.join(HERE, 'ai-dev-harness.md')
OUT = os.path.join(DOCS, 'how-it-works.html')
STYLE_FROM = os.path.join(DOCS, 'standards.html')
REPO_URL = 'https://github.com/absjabed/ai-dev-harness'
BRANCH = 'main'

EXTRA_CSS = """
/* how-it-works.html: generated from docs/harness-docs/ai-dev-harness.md */
main table{display:table;table-layout:auto}
main th:nth-child(n){width:auto}
main table td:first-child{white-space:normal}
figure.diagram{margin:1.2rem 0 1.6rem}
figure.diagram a{display:block;border:1px solid var(--border);border-radius:12px;background:#fff;padding:10px;box-shadow:var(--shadow)}
figure.diagram img{display:block;width:100%;height:auto}
figure.diagram figcaption{font-size:.8rem;color:var(--muted);margin-top:.45rem}
main h2 .num{color:var(--muted);font-weight:500;margin-right:.35rem}
@media(max-width:600px){main table{display:block;overflow-x:auto}}
"""


def slug(text):
    """GitHub's heading anchor: lower case, punctuation dropped, spaces to hyphens."""
    t = re.sub(r'<[^>]+>', '', text).lower()
    t = re.sub(r'[^\w\- ]', '', t)
    return t.replace(' ', '-')


def href_for(target):
    """Map a link in the Markdown (relative to docs/harness-docs/) to one that works from docs/."""
    if re.match(r'^[a-z]+:', target) or target.startswith('#'):
        return target
    path, _, frag = target.partition('#')
    full = os.path.normpath(os.path.join(HERE, path))
    rel = os.path.relpath(full, REPO).replace(os.sep, '/')
    if rel == 'docs/harness-docs/ai-dev-harness.md':
        return '#' + frag if frag else '#top'
    if rel.startswith('docs/') and rel.endswith(('.html', '.png', '.drawio')):
        out = rel[len('docs/'):]
    else:
        kind = 'tree' if os.path.isdir(full) else 'blob'
        out = f'{REPO_URL}/{kind}/{BRANCH}/{rel}'
    return out + ('#' + frag if frag else '')


def png_size(rel):
    """Width and height from a PNG's header, so the page keeps its layout while images load."""
    with open(os.path.join(DOCS, rel), 'rb') as f:
        head = f.read(24)
    return struct.unpack('>II', head[16:24])


def inline(text):
    keep = []

    def stash(s):
        keep.append(s)
        return f'\x00{len(keep) - 1}\x00'

    def link(m):
        return stash(f'<a href="{html.escape(href_for(m.group(2)))}">{inline(m.group(1))}</a>')

    text = re.sub(r'\[((?:[^\[\]`]|`[^`]*`)+)\]\(([^)\s]+)\)', link, text)
    text = re.sub(r'`([^`]+)`', lambda m: stash(f'<code>{html.escape(m.group(1), quote=False)}</code>'), text)
    text = html.escape(text, quote=False)
    text = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', text)
    text = re.sub(r'(?<![\w*])\*([^*\s][^*]*?)\*(?![\w*])', r'<em>\1</em>', text)
    while '\x00' in text:
        text = re.sub(r'\x00(\d+)\x00', lambda m: keep[int(m.group(1))], text)
    return text


def cells(row):
    row = row.strip().strip('|')
    parts = re.split(r'(?<!\\)\|', row)
    return [inline(p.strip().replace('\\|', '|')) for p in parts]


def convert(md):
    lines = md.split('\n')
    body, nav, title, lede = [], [], '', ''
    i, para = 0, []

    def flush():
        nonlocal lede
        if para:
            text = inline(' '.join(s.strip() for s in para))
            if not lede and title and not nav:
                lede = text
            else:
                body.append(f'<p>{text}</p>')
            para.clear()

    while i < len(lines):
        line = lines[i]
        s = line.strip()
        if s.startswith('```'):
            flush()
            lang = s[3:].strip()
            code = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith('```'):
                code.append(lines[i])
                i += 1
            cls = f' class="language-{lang}"' if lang else ''
            body.append(f'<pre><code{cls}>{html.escape(chr(10).join(code), quote=False)}</code></pre>')
        elif s.startswith('# '):
            flush()
            title = s[2:].strip()
        elif s.startswith('## '):
            flush()
            text = s[3:].strip()
            if text == 'Contents':  # the sidebar replaces the Markdown's own contents list
                i += 1
                while i < len(lines) and not lines[i].startswith('## ') and lines[i].strip() != '---':
                    i += 1
                continue
            anchor = slug(text)
            label = inline(text)
            m = re.match(r'^(\d+)\.\s+(.*)$', label)
            heading = f'<span class="num">{m.group(1)}.</span>{m.group(2)}' if m else label
            nav.append((anchor, re.sub(r'<[^>]+>', '', m.group(2) if m else label)))
            body.append(f'<h2 id="{anchor}">{heading}</h2>')
        elif s.startswith('### '):
            flush()
            body.append(f'<h3 id="{slug(s[4:])}">{inline(s[4:])}</h3>')
        elif s == '---':
            flush()
        elif re.match(r'^!\[[^\]]*\]\([^)]+\)$', s):
            flush()
            alt, src = re.match(r'^!\[([^\]]*)\]\(([^)]+)\)$', s).groups()
            src = href_for(src)
            w, h = png_size(src)
            body.append(f'<figure class="diagram"><a href="{html.escape(src)}" title="Open full size">'
                        f'<img src="{html.escape(src)}" alt="{html.escape(alt)}" width="{w}" height="{h}" loading="lazy"></a>'
                        f'<figcaption>Click the diagram to open it full size.</figcaption></figure>')
        elif s.startswith('|'):
            flush()
            rows = []
            while i < len(lines) and lines[i].strip().startswith('|'):
                rows.append(lines[i])
                i += 1
            head, rest = cells(rows[0]), rows[2:]
            out = ['<table><thead><tr>' + ''.join(f'<th>{c}</th>' for c in head) + '</tr></thead><tbody>']
            for r in rest:
                out.append('<tr>' + ''.join(f'<td>{c}</td>' for c in cells(r)) + '</tr>')
            body.append('\n'.join(out) + '</tbody></table>')
            continue
        elif re.match(r'^(- |\d+\. )', s) and not line.startswith(' '):
            flush()
            ordered = bool(re.match(r'^\d+\. ', s))
            items = []
            while i < len(lines):
                cur = lines[i]
                if re.match(r'^(- |\d+\. )', cur):
                    items.append([re.sub(r'^(- |\d+\. )', '', cur)])
                elif cur.startswith(' ') and cur.strip() and items:
                    items[-1].append(cur.strip())
                else:
                    break
                i += 1
            tag = 'ol' if ordered else 'ul'
            body.append(f'<{tag}>' + ''.join(f'<li>{inline(" ".join(it))}</li>' for it in items) + f'</{tag}>')
            continue
        elif not s:
            flush()
        else:
            para.append(line)
        i += 1
    flush()
    return title, lede, nav, '\n'.join(body)


def page(title, lede, nav, body, style, mark):
    nav_html = '\n'.join(f'  <a href="#{a}">{t}</a>' for a, t in nav)
    return f'''<!DOCTYPE html>
<!-- Generated by docs/harness-docs/build-html.py from docs/harness-docs/ai-dev-harness.md. Do not edit by hand. -->
<html lang="en" data-theme="auto">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>How the Harness Works</title>
<meta name="description" content="How the AI Dev Harness agent system fits together, with a diagram for each part.">
{mark['icon']}
<style>{style}{EXTRA_CSS}</style>
</head>
<body>
<div class="layout">
<nav>
  <div class="brand">
{mark['svg']}
    <div><strong>AI Dev Harness</strong><span>How it works</span></div>
  </div>
  <a class="back" href="index.html">&larr; Back to the guide</a>
  <h2>Sections</h2>
{nav_html}
</nav>

<main id="top">
<h1>{inline(title)}</h1>
<p class="lede">{lede}</p>
{body}
<footer>
<p>Generated from <a href="{REPO_URL}/blob/{BRANCH}/docs/harness-docs/ai-dev-harness.md"><code>docs/harness-docs/ai-dev-harness.md</code></a>
by <code>docs/harness-docs/build-html.py</code>. Edit the Markdown, then re-run the script. The diagrams'
editable source is <a href="harness-docs/diagrams/ai-dev-harness/ai-dev-harness.drawio"><code>ai-dev-harness.drawio</code></a>.</p>
</footer>
</main>
</div>
</body>
</html>
'''


def main():
    std = open(STYLE_FROM, encoding='utf-8').read()
    style = re.search(r'<style>(.*?)</style>', std, re.S)
    icon = re.search(r'<link rel="icon"[^>]*>', std)
    svg = re.search(r'    <div class="mark".*?</div>\n', std, re.S)
    if not (style and icon and svg):
        sys.exit('build-html: could not find the stylesheet, icon or brand mark in standards.html')
    title, lede, nav, body = convert(open(SRC, encoding='utf-8').read())
    out = page(title, lede, nav, body, style.group(1), {'icon': icon.group(0), 'svg': svg.group(0).rstrip('\n')})
    if '--check' in sys.argv:
        current = open(OUT, encoding='utf-8').read() if os.path.exists(OUT) else ''
        if current != out:
            sys.exit('build-html: docs/how-it-works.html is out of date; run python docs/harness-docs/build-html.py')
        print('build-html: up to date')
        return
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write(out)
    print(f'build-html: wrote {os.path.relpath(OUT, REPO)} ({len(nav)} sections)')


if __name__ == '__main__':
    main()
