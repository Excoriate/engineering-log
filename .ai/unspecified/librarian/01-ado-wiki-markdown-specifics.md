---
task_id: unspecified
agent: librarian
timestamp: 2026-03-23T00:00:00Z
status: complete

summary: |
  Azure DevOps Wiki markdown rendering specifics researched from official Microsoft docs.
  Covers cross-reference format, emoji support, .order files, section landing pages,
  filename-to-title mapping, blockquotes, tables, and code blocks. Key differences
  from standard GitHub-Flavored Markdown documented.
---

# Azure DevOps Wiki Markdown Specifics

## Key Findings

- **Cross-references**: Wiki links use `/Page-Name` path format (no `.md` extension), not relative `./file.md` paths
- **Emoji**: ADO wiki uses `:name:` shortcode syntax only; Unicode emoji rendering is OS/browser-dependent, not guaranteed by ADO itself
- **Order files**: `.order` files confirmed; plain text, one page name per line, no `.md` extension
- **Landing pages**: A page with subpages requires a matching `.md` file AND folder with identical name
- **Filename to title**: Hyphens in filenames become spaces in titles; underscores are NOT converted
- **Code blocks**: Fenced code blocks with language tags render with syntax highlighting via highlight.js
- **Tables**: GFM tables supported; line breaks within cells require `<br/>` tag (wiki only)

Research from official Microsoft documentation. Focus: what differs from standard GitHub-Flavored Markdown (GFM).

Sources:
- https://learn.microsoft.com/azure/devops/project/wiki/markdown-guidance
- https://learn.microsoft.com/azure/devops/project/wiki/wiki-file-structure
- https://learn.microsoft.com/azure/devops/project/wiki/publish-repo-to-wiki
- https://learn.microsoft.com/azure/devops/project/wiki/wiki-update-offline

---

## 1. Cross-Reference Format (Page Links)

**DIFFERENT from GFM.** Wiki pages link to each other using path-based references WITHOUT `.md` extensions.

### Same folder
```md
[Display text](/Page-Name)
```

### Parent/child (subfolder pages)
```md
[Display text](/parent-page/child-page)
```

### Cross-page anchor links
```md
[Display text](/Page-Name#section-anchor)
```

### Full example from docs
```md
Welcome to the Wiki!

- [Get Started](/get-started-page)
- [Contribute content](/get-started-page#contribute)
- [Send Feedback](/contact-page#send-feedback)
```

### Key rules
- Links use **absolute wiki paths** starting with `/` (from wiki root), NOT relative `./file.md` paths
- Page names in links use the **filename** (with hyphens), NOT the display title (with spaces)
- No `.md` extension in wiki links
- Anchor IDs: spaces become hyphens, uppercase becomes lowercase, special chars (`:`, `"`, `?`, `@`, `#`) become hyphens
- Broken links render in **red with a broken-link icon** (visual indicator in wiki)
- When moving/renaming pages, ADO prompts to fix affected links automatically

### Linking to source control files (different context)
- Welcome page relative links: relative to repo root (`./page-2.md` with `.md` extension)
- This is NOT the same as wiki-to-wiki page links

---

## 2. Emoji Support

**DIFFERENT from GFM.** ADO wiki uses `:name:` shortcode syntax, NOT raw Unicode emoji.

### What works
- Shortcode format: `:smile:`, `:+1:`, `:angry:`, `:cry:`
- Supports most [GitHub emoji cheat sheet](https://github.com/ikatyang/emoji-cheat-sheet/) graphics
- Supported in: **Wiki** and **Pull Requests** only (NOT in dashboard widgets or Definition of Done)

### What does NOT work
- Custom GitHub emoji like `:bowtie:` are NOT supported
- The docs describe emoji as `:name:` shortcodes only; there is **no explicit mention of raw Unicode emoji** (like U+1F4CE) rendering

### Unicode emoji (raw characters like U+1F4CE U+1F4C4)
- **Not documented by Microsoft** as a supported feature
- Rendering depends on OS/browser font support, not ADO's markdown renderer
- The ADO markdown renderer converts `:name:` shortcodes to emoji graphics; raw Unicode characters are passed through as-is
- **Risk**: Raw Unicode emoji MAY render on modern browsers/OS but are not guaranteed by ADO. Shortcodes are the safe path.

### Escape emoji syntax
```md
\:smile:    <!-- renders as literal :smile: text -->
```

---

## 3. .order File

**Confirmed.** ADO wiki uses `.order` files to control page navigation order.

### Format
- Plain text file named `.order`
- One page name per line
- Page names match filenames **without** the `.md` extension
- **Case-sensitive** (must match filename case exactly)
- Required at root level AND in each subfolder

### Example
```
Welcome
Project-Overview
Get-Started
Submit-a-pull-request
team-contacts
```

### Behavior
- Without `.order`: pages display in alphabetical order (A-Z) by filename
- First entry in root `.order` = wiki home page
- Files not listed in `.order` are appended at end of alphabetical list
- Deleting `.order` reverts folder to alphabetical sequence (Git auto-creates new one)

### Important
- When a parent folder contains **only subfolders and no files**, the wiki displays the parent as blank. Always place at least one file (such as `.order` or a content file) in every parent folder.

---

## 4. Section Landing Pages (Folder/File Matching)

**YES, required.** A page that has subpages needs BOTH:
1. A markdown file (e.g., `Guides.md`)
2. A folder with the **identical name** (e.g., `Guides/`)

Both must be in the same parent folder.

### Structure example
```
/
|- Guides.md              <-- landing page content
|- Guides/                <-- folder for subpages
|  |- Getting-Started.md
|  |- Advanced-Topics.md
|  |- .order
|- .order
```

### From docs (verbatim)
> "If you want a page in your wiki to have subpages, you need a Markdown file and folder that have the same name. The file and folder must be in the same wiki folder."

### Wiki repo structure
```
1. A file for each Markdown page at root level
2. A .order file at root and in each subfolder
3. A subfolder for each wiki page that has subpages
4. A .attachments folder for all attachments
```

---

## 5. Filename to Title Mapping

**Hyphens become spaces. Underscores do NOT convert.**

### Rules
- `How-to-contribute.md` displays as **"How to contribute"**
- `Page-4.md` displays as **"Page 4"**
- `New-Home-Page.md` displays as **"New Home Page"**
- Titles are **case-sensitive** and must be **unique within their folder**
- Max path length: 235 characters (full qualified path including repo URL)

### Special characters in filenames
| Character | Allowed | Encoded as |
|-----------|---------|------------|
| Colon `:` | Yes | %3A |
| Angle brackets `< >` | Yes | Encoded |
| Asterisk `*` | Yes | %2A |
| Question mark `?` | Yes | %3F |
| Pipe `\|` | Yes | %7C |
| Hyphen `-` | Yes | %2D (also = space in title) |
| Double quote `"` | Yes | %22 |

### Prohibited in filenames
- Forward slash `/`, backslash `\`, hash `#`
- Period `.` at start or end
- Unicode control/surrogate characters
- **Spaces** (use hyphens instead)

---

## 6. Blockquotes with Emoji

**Blockquotes are supported in wiki.** Combined with emoji shortcodes, `> :paperclip: **text**` should render correctly.

### Standard blockquote syntax works
```md
> Single line blockquote

>> Nested blockquote
```

### Blockquote + emoji + bold
```md
> :paperclip: **Important reference material**
```

### Caveat
- If using raw Unicode emoji (`> U+1F4CE **text**`), rendering depends on browser/OS (see Section 2)
- Using shortcodes (`:paperclip:`) is the documented, guaranteed approach
- Blockquotes are supported in: Definition of Done, Markdown widget, PRs, README, **Wiki**

---

## 7. Tables

**GFM-style tables work in wiki.** One notable ADO-specific feature:

### Standard GFM table syntax supported
```md
| Column A | Column B | Column C |
|:---------|:--------:|---------:|
| Left     | Center   | Right    |
```

### ADO-specific differences from GFM
- **Line breaks within cells**: Use `<br/>` HTML tag. This works **in wiki only**, not in other ADO markdown contexts.
- **Pipe in cell text**: Escape with `\|`
- **Work items/PRs in tables**: Add a blank space before and after `#ID` mentions in table cells
- Column alignment via colons in separator row (same as GFM)

### No known rendering issues
- The official docs do not document any known rendering bugs with GFM tables in wiki
- Tables are supported in: Markdown widget, PRs, README, **Wiki** (NOT in Definition of Done)

---

## 8. Code Blocks

**Fenced code blocks with language tags render with syntax highlighting.** Uses [highlight.js](https://github.com/highlightjs/highlight.js/tree/stable-11/src/languages).

### Syntax
````md
```js
const count = records.length;
```

```csharp
Console.WriteLine("Hello, World!");
```
````

### Supported languages
- Any language supported by highlight.js (JavaScript `js`, C# `csharp`, Bash `bash`, HCL `hcl`, Python `python`, etc.)
- Language identifier is **not case-sensitive** per general guidance, but lowercase recommended
- Unsupported language tags: code renders without highlighting, tag becomes label in title bar

### Code highlighting support matrix
| Context | Syntax highlighting? |
|---------|---------------------|
| Wiki | YES |
| Pull Requests | YES |
| README | YES |
| Markdown Widget | **NO** (renders as plain preformatted text) |
| Definition of Done | **NO** |

### ADO-specific code features
- Four-space indent also converts to code block (same as standard markdown)
- Inline code with single backticks supported everywhere

---

## Summary: Key Differences from Standard GFM

| Feature | GFM (GitHub) | ADO Wiki |
|---------|-------------|----------|
| **Page links** | `[text](./file.md)` relative paths | `[text](/Page-Name)` absolute wiki paths, no `.md` |
| **Emoji** | Raw Unicode + `:shortcode:` | `:shortcode:` only documented; raw Unicode = browser-dependent |
| **Page ordering** | Alphabetical or sidebar config | `.order` file per folder |
| **Subpages** | Flat file structure | Requires matching `Name.md` + `Name/` folder pair |
| **Filename to title** | No automatic conversion | Hyphens `-` become spaces in display title |
| **Table cell line breaks** | `<br>` (varies) | `<br/>` supported in wiki only |
| **TOC** | No built-in | `[[_TOC_]]` syntax |
| **Subpage TOC** | No built-in | `[[_TOSP_]]` syntax |
| **Mermaid diagrams** | Supported | Supported (limited syntax; use `graph` not `flowchart`) |
| **YAML frontmatter** | Rendered as metadata | Rendered as metadata table (one-head, one-row) |
| **Image sizing** | Not standard | `![alt](path =WIDTHxHEIGHT)` syntax |
| **HTML tags** | Limited | `<font>`, `<span>`, `<video>`, `<u>` supported in wiki |
| **Math notation** | Varies | LaTeX format supported in wiki and PRs |
