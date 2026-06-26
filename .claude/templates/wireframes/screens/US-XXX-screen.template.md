# Wireframe: [Screen name] — @US-[ID], @US-[ID]…

> Rename file to `US-<ids>-<slug>.md`. Use real UI copy, not Lorem ipsum.

## Layout ([desktop / default])

```text
┌──────────────────────────────────────────────┐
│ [ ASCII layout — header / main / actions ]    │
│                                                │
│  [ … draw the real regions & controls … ]     │
│                                                │
└──────────────────────────────────────────────┘
```

## States (each tagged with its scenario id)

| State | Scenario | What the user sees |
|---|---|---|
| Default / happy | @US-[ID]-S01 | [ … ] |
| Empty | @US-[ID]-Snn | [ "no data yet" + primary CTA ] |
| Loading | — | [ skeleton / spinner ] |
| Error | @US-[ID]-Snn | [ message + retry ] |
| No-result (filtered) | @US-[ID]-Snn | [ "nothing matches" + clear filters ] |

## Responsive (mobile)
- [ how the layout reflows < breakpoint: stacking, collapse, FAB, touch targets ≥ 44px ]

## A11y
- [ labels / roles / aria-label for icon buttons / focus order / contrast ]

## Mapping → control → scenario
| UI region | Control (role / accessible-name) | Behavior | Scenario |
|---|---|---|---|
| [ region ] | `[role "name"]` | [ what happens on interaction ] | @US-[ID]-Snn |
