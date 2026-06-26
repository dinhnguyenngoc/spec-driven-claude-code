# System Context (C4 L1) — [Product Name]

> Whole-product boundary + external actors + all first-party services. ASCII per [`../../references/ascii-diagram-guide.md`](../../references/ascii-diagram-guide.md).

```text
                         ┌──────────────────────────────────────────────┐
   [actor: End user] ──▶ │  [Product Name]                             │
   [actor: Admin]    ──▶ │   [Gateway] ─▶ [service A] [service B] …     │
                         │                   │           │              │
                         │              [data store] [message bus]      │
                         └──────────────────────────────────────────────┘
                                          │
                          [external system: payment provider / email / SSO / …]
```

- **Actors:** [who uses the product]
- **External systems:** [3rd-party deps the system integrates with]
