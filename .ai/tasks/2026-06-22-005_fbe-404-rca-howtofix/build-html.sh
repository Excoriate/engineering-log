#!/usr/bin/env bash
# build-html.sh <input.md> <output.html> "<title>"
# Renders ```mermaid blocks to inline SVG (via mmdc) then pandoc -> self-contained styled HTML.
# POSIX/bash 3.2-safe; no flock/mapfile.
set -eu

IN="${1:?input.md}"; OUT="${2:?output.html}"; TITLE="${3:-Document}"
TMPDIR_R="$(mktemp -d "${TMPDIR:-/tmp}/rcahtml.XXXXXX")"
PRE="$TMPDIR_R/pre.md"

# 1) Pre-render mermaid fences -> inline SVG (python splits blocks; mmdc renders each).
python3 - "$IN" "$PRE" "$TMPDIR_R" <<'PY'
import sys, re, subprocess, os, pathlib
src, dst, tmp = sys.argv[1], sys.argv[2], sys.argv[3]
text = pathlib.Path(src).read_text()
pat = re.compile(r"```mermaid\n(.*?)\n```", re.DOTALL)
def render(m, _c=[0]):
    _c[0]+=1; i=_c[0]
    mmd=os.path.join(tmp,f"d{i}.mmd"); svg=os.path.join(tmp,f"d{i}.svg")
    pathlib.Path(mmd).write_text(m.group(1)+"\n")
    try:
        subprocess.run(["mmdc","-i",mmd,"-o",svg,"-b","transparent"],check=True,
                       capture_output=True,timeout=120)
        s=pathlib.Path(svg).read_text()
        s=re.sub(r'<\?xml[^>]*\?>','',s).strip()
        return f'\n<figure class="diagram">{s}</figure>\n'
    except Exception as e:
        return f'\n<pre class="mermaid">\n{m.group(1)}\n</pre>\n'  # fallback: leave for CDN
out=pat.sub(render,text)
pathlib.Path(dst).write_text(out)
print(f"mermaid blocks rendered: {render.__defaults__[0][0]}")
PY

# 2) CSS theme (clean, print-friendly, engineering-doc register).
CSS="$TMPDIR_R/theme.css"
cat > "$CSS" <<'CSS'
:root{--fg:#1b1f24;--muted:#5b6570;--bg:#ffffff;--accent:#0b6bcb;--line:#e2e6ea;--code-bg:#f5f7f9;--warn:#b54708}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%}
body{color:var(--fg);background:var(--bg);font:16px/1.62 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;max-width:920px;margin:0 auto;padding:2.4rem 1.5rem 6rem}
h1,h2,h3,h4{line-height:1.25;font-weight:650;margin:2.1em 0 .6em}
h1{font-size:1.95rem;margin-top:0;border-bottom:2px solid var(--line);padding-bottom:.35em}
h2{font-size:1.4rem;border-bottom:1px solid var(--line);padding-bottom:.25em}
h3{font-size:1.13rem}
h4{font-size:1rem;color:var(--muted)}
a{color:var(--accent);text-decoration:none}a:hover{text-decoration:underline}
p,li{margin:.5em 0}
code{background:var(--code-bg);padding:.12em .38em;border-radius:4px;font:.86em/1.5 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}
pre{background:var(--code-bg);border:1px solid var(--line);border-radius:8px;padding:1rem 1.1rem;overflow:auto;font:.84rem/1.5 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}
pre code{background:none;padding:0}
table{border-collapse:collapse;width:100%;margin:1.1em 0;font-size:.92rem;display:block;overflow-x:auto}
th,td{border:1px solid var(--line);padding:.5em .7em;text-align:left;vertical-align:top}
th{background:var(--code-bg);font-weight:650}
tr:nth-child(even) td{background:#fafbfc}
blockquote{margin:1em 0;padding:.4em 1.1em;border-left:4px solid var(--accent);background:#f3f8fe;color:#27313b;border-radius:0 6px 6px 0}
figure.diagram{margin:1.4em 0;padding:1.1em;border:1px solid var(--line);border-radius:8px;background:#fcfdfe;text-align:center;overflow-x:auto}
figure.diagram svg{max-width:100%;height:auto}
hr{border:0;border-top:1px solid var(--line);margin:2.2em 0}
.subtitle{color:var(--muted);font-size:.9rem;margin-top:-.3em}
@media print{body{max-width:none}pre,table,figure{page-break-inside:avoid}a{color:var(--fg)}}
CSS

# 3) pandoc -> standalone, resources embedded.
pandoc "$PRE" \
  --standalone --embed-resources --from gfm+raw_html --to html5 \
  --metadata title="$TITLE" \
  --css "$CSS" \
  -o "$OUT"

echo "built: $OUT ($(wc -c < "$OUT") bytes)"
rm -rf "$TMPDIR_R"
