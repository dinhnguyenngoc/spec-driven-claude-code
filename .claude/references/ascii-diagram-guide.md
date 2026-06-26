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
