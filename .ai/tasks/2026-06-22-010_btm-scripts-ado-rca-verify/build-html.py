#!/usr/bin/env python3
"""Build a self-contained HTML from a markdown RCA, rendering mermaid diagrams.

Strategy: extract ```mermaid fences BEFORE pandoc (so pandoc never HTML-escapes the
arrows), try to pre-render each to inline SVG with mmdc; fall back to a <div class="mermaid">
+ mermaid.js CDN if mmdc is unavailable. Then pandoc the rest and splice the diagrams back.
"""
import re, subprocess, sys, tempfile, os, html

SRC, OUT = sys.argv[1], sys.argv[2]
md = open(SRC, encoding="utf-8").read()

fence = re.compile(r"```mermaid\n(.*?)\n```", re.DOTALL)
blocks = fence.findall(md)
placeholders = []
used_cdn = False

def try_mmdc(diagram, idx):
    """Return inline SVG string or None."""
    try:
        with tempfile.TemporaryDirectory() as d:
            mmd = os.path.join(d, f"d{idx}.mmd"); svg = os.path.join(d, f"d{idx}.svg")
            open(mmd, "w").write(diagram)
            r = subprocess.run(["mmdc", "-i", mmd, "-o", svg, "-b", "transparent"],
                               capture_output=True, timeout=60)
            if r.returncode == 0 and os.path.exists(svg) and os.path.getsize(svg) > 0:
                return open(svg, encoding="utf-8").read()
    except Exception:
        return None
    return None

def repl(m):
    global used_cdn
    idx = len(placeholders)
    diagram = m.group(1)
    svg = try_mmdc(diagram, idx)
    if svg:
        rep = f'<div class="diagram">{svg}</div>'
    else:
        used_cdn = True
        rep = f'<div class="mermaid">{html.escape(diagram)}</div>'
    token = f"@@MERMAID_{idx}@@"
    placeholders.append(rep)
    return token

md_tok = fence.sub(repl, md)

# pandoc the markdown (with tokens) to an HTML fragment.
p = subprocess.run(["pandoc", "-f", "gfm", "-t", "html5", "--no-highlight"],
                   input=md_tok, capture_output=True, text=True)
if p.returncode != 0:
    sys.stderr.write(p.stderr); sys.exit(1)
body = p.stdout
for i, rep in enumerate(placeholders):
    body = body.replace(f"<p>@@MERMAID_{i}@@</p>", rep).replace(f"@@MERMAID_{i}@@", rep)

cdn = ('<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>'
       '<script>mermaid.initialize({startOnLoad:true,theme:"neutral"});</script>') if used_cdn else ""

doc = f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Holistic RCA — BTM PR auto-tagging</title>
<style>
  :root {{ --ink:#1a1a2e; --mut:#5a5a72; --line:#e2e2ee; --accent:#7c3aed; --code:#0f172a; }}
  body {{ font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
         line-height:1.62; color:var(--ink); max-width:980px; margin:0 auto; padding:2.5rem 1.4rem; }}
  h1,h2,h3 {{ line-height:1.25; margin-top:2rem; }}
  h1 {{ border-bottom:3px solid var(--accent); padding-bottom:.4rem; }}
  h2 {{ border-bottom:1px solid var(--line); padding-bottom:.3rem; color:#26204d; }}
  code {{ background:#f3f3fb; padding:.12em .35em; border-radius:4px; font-size:.88em; }}
  pre {{ background:var(--code); color:#e2e8f0; padding:1rem; border-radius:8px; overflow:auto; font-size:.84rem; }}
  pre code {{ background:none; color:inherit; padding:0; }}
  table {{ border-collapse:collapse; width:100%; margin:1rem 0; font-size:.92rem; }}
  th,td {{ border:1px solid var(--line); padding:.5rem .65rem; text-align:left; vertical-align:top; }}
  th {{ background:#f7f7fc; }}
  blockquote {{ border-left:4px solid var(--accent); margin:1rem 0; padding:.4rem 1rem; background:#faf8ff; color:var(--mut); }}
  .diagram, .mermaid {{ margin:1.2rem 0; padding:1rem; background:#fafaff; border:1px solid var(--line); border-radius:8px; text-align:center; overflow:auto; }}
  .diagram svg {{ max-width:100%; height:auto; }}
  a {{ color:var(--accent); }}
</style></head>
<body>
{body}
{cdn}
</body></html>
"""
open(OUT, "w", encoding="utf-8").write(doc)
print(f"WROTE {OUT} ({len(doc)} bytes); diagrams={len(placeholders)}; mode={'CDN-fallback' if used_cdn else 'inline-SVG'}")
