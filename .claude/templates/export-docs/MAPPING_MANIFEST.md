<!--
  FILL-ONLY BOILERPLATE — copy this file to  .claude/local/doc-templates/mapping.md  and fill it for your company's documents.
  Consumed by /export-docs (see .claude/commands/export-docs.md — §Configuration, §Transform rules).
  One `## Target:` block per document type. Everything in .claude/local/ is user-owned (EXTENSION layer) — kit upgrades never touch it.
-->

# Mapping Manifest — /export-docs

## Target: <TARGET-NAME e.g. PRD>

- Template: .claude/local/doc-templates/<YOUR_TEMPLATE>.md
- Output: exports/<TARGET-NAME>.md
- Agent: Business Analyst | Systems Architect
- Audience: stakeholder | engineer   <!-- stakeholder → technical identifiers translated to business language; engineer → kept verbatim (export-docs.md §Fill-only discipline) -->
- Scope: repo (default) | system   <!-- system → runs at the workspace ROOT: sources = specs/system/ + architecture/system/, output = root exports/, per-repo IDs qualified by Service id (export-docs.md §System-scope ID qualification) -->
- Required inputs: <artifact path + condition — e.g. specs/SPEC.md (Status: Approved)>
- Placeholder patterns: "<pattern 1>", "<pattern 2>"   <!-- the residue-check greps these; list every placeholder style your template uses -->

| # | Template section | Source | Transform | On missing |
|---|------------------|--------|-----------|------------|
| 1 | <§heading in the template> | <artifact path §section> | verbatim \| restructure \| derive \| convert-diagram \| id-transform \| static | STOP \| N/A + reason \| [NEEDS <role/command>] \| skip-note |
| 2 | … | … | … | … |

<!--
  Transform enum (canonical definitions: commands/export-docs.md §Transform rules):
    verbatim         copy content, change only the framing
    restructure      same data, different table/column shape
    derive           computed from ≥ 2 sources (FR catalogue, link census, FMA table…)
    convert-diagram  ASCII/Mermaid-source → Mermaid, node & edge sets preserved 1:1
    id-transform     @US-XXX-Snn → company AC ID (1:1 stable rule)
    static           fixed content declared right here in the manifest row

  On-missing enum:
    STOP             required input — the export refuses to run without it
    N/A + reason     section rendered as `N/A — <one-line reason>`
    [NEEDS <x>]        human/command handoff marker, listed at the gate
    skip-note        section omitted with a one-line note (only if the template allows omission)
-->

## Target: <SECOND-TARGET e.g. SDD>

- Template: …
- Output: exports/…
- Agent: …
- Audience: stakeholder | engineer
- Scope: repo (default) | system
- Required inputs: …
- Placeholder patterns: …

| # | Template section | Source | Transform | On missing |
|---|------------------|--------|-----------|------------|
| 1 | … | … | … | … |
