# Flow: [Flow name] — @US-[ID], @US-[ID]…

> Rename to `<flow>.md`. One Mermaid diagram per significant user journey. Tag decision branches with the scenario they exercise.

## User journey (Mermaid)

```mermaid
flowchart TD
    Start[ [entry point] ] --> Step1[ [user action] ]
    Step1 --> Q{ [decision?] }
    Q -->|happy @US-[ID]-S01| Done[ [observable outcome] ]
    Q -->|edge/failure @US-[ID]-Snn| Err[ [error state] ]
    %% [ … extend with the real steps; keep it the journey, not the UI layout … ]
```

## Notes
- [ Any cross-tier behavior worth calling out: redirect, token refresh, optimistic update + rollback, persistence-after-reload that `/verify` will assert ]
