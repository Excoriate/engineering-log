#!/usr/bin/env python3
"""Render two FBE-Duncan Markdown docs to self-contained HTML by cloning the
golden-precedent template EXACTLY. The precedent is a self-rendering document:
the raw Markdown lives verbatim in <script type="text/markdown" id="md-source">
and an embedded JS parser renders it client-side. So a faithful render = splice
each target MD verbatim into a byte-identical copy of the precedent shell,
changing only: <title>, the doc-header meta block, the #md-source body, and the
localStorage theme key. Style/parser/mermaid-CDN/theme-toggle/TOC stay identical.
"""

import re
import sys

BASE = "/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_june"
PRECEDENT = f"{BASE}/2026_06_15_rootly_alert_gurobi-cosmos-normalized-ru-consumption-a/rca.html"
FOLDER = f"{BASE}/2026_02_22_003_feature_flags_fbe_duncan"


def read(path):
    with open(path, "r", encoding="utf-8") as fh:
        return fh.read()


def write(path, content):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(content)


def first_h1(md_body):
    for line in md_body.splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return ""


def front_field(md, key):
    m = re.search(rf"^{re.escape(key)}:\s*(.+)$", md, re.MULTILINE)
    if not m:
        return ""
    return m.group(1).strip().strip('"')


def esc_html(s):
    return (s.replace("&", "&amp;").replace("<", "&lt;")
             .replace(">", "&gt;").replace('"', "&quot;"))


def build(template, md_raw, out_title, theme_key):
    # --- frontmatter (for the rendered doc-header meta block) ---
    status = front_field(md_raw, "status")
    timestamp = front_field(md_raw, "timestamp")
    task_id = front_field(md_raw, "task_id")
    category = front_field(md_raw, "category")

    # body after frontmatter (the parser also strips this client-side; we
    # embed the WHOLE raw MD verbatim incl. frontmatter, identical to the
    # precedent, which keeps its own frontmatter inside #md-source).
    body_after_fm = re.sub(r"^---\n.*?\n---\n", "", md_raw, count=1, flags=re.DOTALL)
    h1 = first_h1(body_after_fm)

    html = template

    # 1) <title>
    html = re.sub(r"<title>.*?</title>",
                  "<title>" + esc_html(out_title) + "</title>",
                  html, count=1, flags=re.DOTALL)

    # 2) doc-header block (title H1 + status pill + timestamp + task + category)
    new_header = (
        '<header class="doc-header">\n'
        '        <h1>' + esc_html(h1) + '</h1>\n'
        '        <div class="doc-meta">\n'
        '          <span class="status-pill">' + esc_html(status) + '</span>\n'
        '          <span class="meta-item">&#128197; <code>' + esc_html(timestamp) + '</code></span>\n'
        '          <span class="meta-item">task <code>' + esc_html(task_id) + '</code></span>\n'
        '          <span class="meta-item">' + esc_html(category) + '</span>\n'
        '        </div>\n'
        '      </header>'
    )
    html = re.sub(r'<header class="doc-header">.*?</header>',
                  lambda _m: new_header, html, count=1, flags=re.DOTALL)

    # 3) #md-source body — embed the raw MD VERBATIM, only repointing the
    #    sibling cross-links .md -> .html (mandate explicitly permits this).
    md_for_embed = md_raw.replace("(./how-to-fix.md)", "(./how-to-fix.html)")
    md_for_embed = md_for_embed.replace("(./rca.md)", "(./rca.html)")
    # safety: a literal </script in the MD would close the tag early.
    assert re.search(r"</script", md_for_embed, re.IGNORECASE) is None, "MD contains </script"

    def repl_src(_m):
        return ('<script type="text/markdown" id="md-source">'
                + md_for_embed + '</script>')

    html, n = re.subn(
        r'<script type="text/markdown" id="md-source">.*?</script>',
        repl_src, html, count=1, flags=re.DOTALL)
    assert n == 1, "md-source script not found/replaced"

    # 4) localStorage theme key — keep behavior identical but namespace per doc
    html = html.replace('"rca-theme"', '"' + theme_key + '"')

    return html


def main():
    template = read(PRECEDENT)

    rca_md = read(f"{FOLDER}/rca.md")
    htf_md = read(f"{FOLDER}/how-to-fix.md")

    rca_html = build(template, rca_md,
                     first_h1(re.sub(r"^---\n.*?\n---\n", "", rca_md, count=1, flags=re.DOTALL)),
                     "fbe-duncan-rca-theme")
    htf_html = build(template, htf_md,
                     first_h1(re.sub(r"^---\n.*?\n---\n", "", htf_md, count=1, flags=re.DOTALL)),
                     "fbe-duncan-htf-theme")

    write(f"{FOLDER}/rca.html", rca_html)
    write(f"{FOLDER}/how-to-fix.html", htf_html)
    print("WROTE rca.html and how-to-fix.html")


if __name__ == "__main__":
    main()
