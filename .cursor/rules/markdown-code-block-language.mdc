---
title: "Markdown Code Block Language Specification"
description: "Enforce language specification for all fenced code blocks in markdown files"
globs: ["**/*.md", "**/*.markdown"]
alwaysApply: true
---

# Markdown Code Block Language Specification

## Description

This rule enforces mandatory language specification for all fenced code blocks in markdown files. Every code block MUST include an explicit language identifier to enable proper syntax highlighting and improve documentation clarity.

**Primary Focus**: Code block language specification compliance

## Rule

**MANDATORY REQUIREMENTS:**

1. **Language Specification**
   - MUST: Specify language for all fenced code blocks: ` ```javascript `, ` ```bash `, ` ```python `
   - PROHIBITED: Generic ` ``` ` without language identifier
   - Special Cases: Use ` ```markdown ` for markdown examples, ` ```text ` for plain text

2. **Supported Languages** (Common)
   - Programming: `javascript`, `typescript`, `python`, `go`, `rust`, `java`, `c`, `cpp`
   - Shell: `bash`, `sh`, `zsh`, `powershell`
   - Markup: `html`, `css`, `xml`, `yaml`, `json`, `markdown`
   - Other: `sql`, `dockerfile`, `makefile`, `text`

3. **Validation Scope**
   - Applies to ALL markdown files repository-wide
   - No exceptions for code blocks in any context
   - Includes nested code blocks in lists or quotes

## Implementation

- Auto-suggest language identifiers during code block creation
- Real-time highlighting of generic code blocks (violations)
- Quick-fix suggestions based on code content analysis
- Batch scanning for non-compliant code blocks

## Benefits

1. **Syntax Highlighting**: Enables proper code rendering in viewers/editors
2. **Clarity**: Language identifier makes code purpose explicit
3. **Tooling Support**: Many tools rely on language tags for processing
4. **Consistency**: Uniform standard across all documentation

## Examples

### ✅ Correct Code Blocks

` ``markdown
# JavaScript Example
` ``javascript
function greet(name) {
  console.log(`Hello, ${name}!`);
}
` ``

# Shell Script Example
` ``bash
#!/bin/bash
echo "Hello, World!"
` ``

# Plain Text Example
` ``text
This is plain text without syntax highlighting
` ``
` ``

### ❌ Incorrect Code Blocks

` ``markdown
# No Language Specified (VIOLATION)
` ``
function noLanguage() {
  return "This will fail validation";
}
` ``

# Content suggests language but not specified (VIOLATION)
` ``
#!/bin/bash
echo "Language identifier missing"
` ``
` ``

## Related Rules

- [markdown-code-block-indentation.md](./markdown-code-block-indentation.md) - Code block indentation in lists
- [markdown-spacing.md](./markdown-spacing.md) - Spacing around code blocks
- [markdown-formatting.md](./markdown-formatting.md) - Original combined rule (DEPRECATED)

## Pipeline Position

**Prerequisites**: None (foundational formatting rule)

**Input Assumptions**:
- Markdown file exists
- Contains fenced code blocks

**Output Guarantees**:
- All code blocks have explicit language identifiers
- Syntax highlighting enabled in all viewers

**Next Steps**:
- [markdown-spacing.md](./markdown-spacing.md) - Apply spacing standards around code blocks
