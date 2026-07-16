# ASCII Diagram Guide

> Standards for drawing ASCII art diagrams in Markdown documents for architecture diagrams and wireframes.

## Why ASCII art?

- Renders directly in any editor/IDE
- No Mermaid/PlantUML plugin required
- Easy to copy-paste
- Version-control friendly

---

## Basic characters

```
Lines:     ─ │ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼
Arrows:    → ← ↑ ↓ ▶ ◀ ▲ ▼ ► ◄
Double:    ═ ║ ╔ ╗ ╚ ╝ ╠ ╣ ╦ ╩ ╬
```

---

## 1. System Context Diagram

```
                         ┌──────────┐
                         │  Actor   │
                         └────┬─────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │     System      │
                    └────────┬────────┘
                             │
                             ▼
                   ┌──────────────────┐
                   │ External System  │
                   └──────────────────┘
```

---

## 2. Container Diagram

```
┌─────────────────────────────────────────────────┐
│                 System Boundary                  │
│  ┌───────────┐    ┌───────────┐    ┌─────────┐ │
│  │ Container │───▶│ Container │───▶│   DB    │ │
│  │     A     │    │     B     │    │         │ │
│  └───────────┘    └───────────┘    └─────────┘ │
└─────────────────────────────────────────────────┘
```

---

## 3. Component Diagram (Layered)

```
┌─────────────────────────────────────────────────┐
│  LAYER 1                                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │ Component│  │ Component│  │ Component│      │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘      │
└───────┼─────────────┼─────────────┼────────────┘
        │             │             │
        ▼             ▼             ▼
┌─────────────────────────────────────────────────┐
│  LAYER 2                                        │
│  ┌──────────┐  ┌──────────┐                    │
│  │ Component│  │ Component│                    │
│  └────┬─────┘  └────┬─────┘                    │
└───────┼─────────────┼──────────────────────────┘
        │             │
        └──────┬──────┘
               ▼
        ┌─────────────┐
        │  Database   │
        └─────────────┘
```

---

## 4. Sequence Diagram

```
┌────────┐      ┌────────┐      ┌────────┐
│ Client │      │ Server │      │   DB   │
└───┬────┘      └───┬────┘      └───┬────┘
    │               │               │
    │  1. Request   │               │
    │──────────────▶│               │
    │               │  2. Query     │
    │               │──────────────▶│
    │               │               │
    │               │  3. Result    │
    │               │◀──────────────│
    │  4. Response  │               │
    │◀──────────────│               │
    │               │               │
```

---

## 5. Flow Diagram

```
    ┌─────────┐
    │  Start  │
    └────┬────┘
         │
         ▼
    ┌─────────┐     Yes     ┌─────────┐
    │Condition│────────────▶│ Action  │
    └────┬────┘             └────┬────┘
         │ No                    │
         ▼                       │
    ┌─────────┐                  │
    │ Default │                  │
    └────┬────┘                  │
         │                       │
         └───────────┬───────────┘
                     ▼
                ┌─────────┐
                │   End   │
                └─────────┘
```

---

## 6. Data Flow / Pipeline

```
┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐
│ Input  │───▶│Process │───▶│Process │───▶│ Output │
│        │    │   A    │    │   B    │    │        │
└────────┘    └────────┘    └────────┘    └────────┘
```

---

## 7. Entity Relationship

```
┌──────────────┐       ┌──────────────┐
│   Entity A   │       │   Entity B   │
├──────────────┤       ├──────────────┤
│ PK: id       │──1:N──│ PK: id       │
│ field1       │       │ FK: a_id     │
│ field2       │       │ field1       │
└──────────────┘       └──────────────┘
```

---

## 8. UI Wireframe (screen)

> Used by `/spec` Phase 2.5 (`specs/wireframes/screens/US-*.md`). Intent-level: regions + controls + real UI copy — no pixels, no tokens (those are `/arch`).

```
┌──────────────────────────────────────────────┐
│ ◀ Back        Orders                 [+ New] │  ← header: title + primary action
├──────────────────────────────────────────────┤
│ [Search orders…          ]  [Status ▾]       │  ← toolbar: search + filter
├──────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐ │
│ │ #1042 · John Smith        [View] [Delete]│ │  ← list row (repeats)
│ │ 2026-07-01 · PAID                        │ │
│ └──────────────────────────────────────────┘ │
│                                              │
│ Email *                                      │
│ ┌──────────────────────────────────────────┐ │
│ │ user@example.com                         │ │  ← text input (filled)
│ └──────────────────────────────────────────┘ │
│ ⚠ Invalid email format                       │  ← inline error under field
│                                              │
│              [ Cancel ]  [ Save ]            │  ← footer: ghost + primary
└──────────────────────────────────────────────┘
```

**Control conventions:**

| Control | Notation |
|---------|----------|
| Button | `[Label]` — primary last in a row; ghost/secondary in `[ Spaced ]` or noted |
| Text input | boxed row (`┌─┐│…│└─┘`) or `[placeholder…]` inline |
| Dropdown / select | `[Label ▾]` |
| Checkbox / radio | `[x] label` · `( ) option` |
| Back / breadcrumb | `◀ Back` |
| Required field | `*` after the label |
| Annotation | `←` note outside the right edge (or a numbered legend below) |

Draw one frame per screen; a separate frame per state only when the **layout** differs — otherwise the States table in the screen template carries it.

---

## Tips

1. **Alignment**: Use a monospace font and ensure columns line up
2. **Spacing**: Leave 1–2 blank lines between sections
3. **Width**: Keep diagrams within 80–100 characters to avoid wrapping
4. **Labels**: Keep labels short and inside the box
5. **Arrows**: Use `───▶` for flow, `───` for association

---

## Box Templates

```
Simple:     ┌─────────┐
            │  Label  │
            └─────────┘

With header:┌─────────────┐
            │   HEADER    │
            ├─────────────┤
            │  Content    │
            └─────────────┘

Database:   ┌─────────┐
            │   DB    │
            │  ┌───┐  │
            │  │   │  │
            │  └───┘  │
            └─────────┘

Cylinder:      ╭─────╮
            ┌──┤     ├──┐
            │  ╰─────╯  │
            │    DB     │
            └───────────┘
```
