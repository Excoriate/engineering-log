#!/usr/bin/env python3
"""Render a Markdown doc to a self-contained, styled HTML file with working Mermaid.

Usage: render-html.py <input.md> <output.html> "<Title>"

Strategy: pull ```mermaid fences out before pandoc (so pandoc doesn't wrap them in
<pre><code>), convert the rest with pandoc (gfm: tables, code, headings), then
re-inject each mermaid block as <pre class="mermaid">ESCAPED</pre> and wrap in an
HTML shell with embedded CSS + the Mermaid CDN.
"""
import re, sys, subprocess, html, pathlib

src, out, title = sys.argv[1], sys.argv[2], sys.argv[3]
md = pathlib.Path(src).read_text(encoding="utf-8")

# 1. extract mermaid fences -> sentinels
mer = []
def grab(m):
    mer.append(m.group(1))
    return f"\n\nMERMAIDPLACEHOLDER{len(mer)-1}MERMAIDPLACEHOLDER\n\n"
md = re.sub(r"```mermaid\n(.*?)```", grab, md, flags=re.DOTALL)

# 2. pandoc convert the rest (gfm input -> html5 fragment)
frag = subprocess.run(
    ["pandoc", "--from", "gfm", "--to", "html5", "--wrap=none"],
    input=md, capture_output=True, text=True, check=True).stdout

# 3. re-inject mermaid as <pre class="mermaid">escaped</pre>
def put(m):
    i = int(m.group(1))
    return f'<pre class="mermaid">{html.escape(mer[i])}</pre>'
frag = re.sub(r"<p>MERMAIDPLACEHOLDER(\d+)MERMAIDPLACEHOLDER</p>", put, frag)
frag = re.sub(r"MERMAIDPLACEHOLDER(\d+)MERMAIDPLACEHOLDER", put, frag)  # bare fallback

CSS = """
:root{--fg:#1f2328;--muted:#656d76;--bg:#fff;--line:#d0d7de;--accent:#0969da;
--code-bg:#f6f8fa;--ok:#1a7f37;--bad:#cf222e;--warn:#9a6700;--warnbg:#fff8c5;}
*{box-sizing:border-box}
body{margin:0;background:#f6f8fa;color:var(--fg);
font:16px/1.65 -apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;}
.wrap{max-width:960px;margin:0 auto;background:var(--bg);padding:48px 56px;
box-shadow:0 0 0 1px var(--line);min-height:100vh;}
h1,h2,h3,h4{line-height:1.25;font-weight:600;margin-top:1.6em;margin-bottom:.5em;}
h1{font-size:2em;border-bottom:2px solid var(--line);padding-bottom:.3em;margin-top:0}
h2{font-size:1.5em;border-bottom:1px solid var(--line);padding-bottom:.25em}
h3{font-size:1.2em} h4{font-size:1.02em;color:var(--muted)}
a{color:var(--accent);text-decoration:none} a:hover{text-decoration:underline}
p,li{margin:.5em 0}
code{font-family:ui-monospace,SFMono-Regular,"SF Mono",Menlo,Consolas,monospace;
font-size:.88em;background:var(--code-bg);padding:.15em .4em;border-radius:6px;}
pre{background:var(--code-bg);border:1px solid var(--line);border-radius:8px;
padding:14px 16px;overflow:auto;font-size:.85em;line-height:1.5;}
pre code{background:none;padding:0;font-size:1em}
pre.mermaid{background:#fbfdff;text-align:center;border-color:#cfe3ff}
table{border-collapse:collapse;width:100%;margin:1em 0;font-size:.92em;display:block;overflow-x:auto}
th,td{border:1px solid var(--line);padding:7px 11px;text-align:left;vertical-align:top}
th{background:var(--code-bg);font-weight:600}
tr:nth-child(2n) td{background:#fbfcfd}
blockquote{margin:1em 0;padding:.4em 1em;color:var(--fg);
border-left:4px solid var(--warn);background:var(--warnbg);border-radius:0 6px 6px 0;}
blockquote p{margin:.35em 0}
hr{border:none;border-top:1px solid var(--line);margin:2em 0}
.meta{color:var(--muted);font-size:.85em;margin-top:6px}
strong{font-weight:600}
ul,ol{padding-left:1.6em}
"""

doc = f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)}</title>
<style>{CSS}</style>
<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
<script>document.addEventListener("DOMContentLoaded",function(){{
  if(window.mermaid){{mermaid.initialize({{startOnLoad:true,theme:"default",securityLevel:"loose",flowchart:{{useMaxWidth:true,htmlLabels:true}}}});}}
}});</script>
</head><body><div class="wrap">
{frag}
</div></body></html>"""

pathlib.Path(out).write_text(doc, encoding="utf-8")
print(f"wrote {out} ({len(doc)} bytes, {len(mer)} mermaid diagrams)")
