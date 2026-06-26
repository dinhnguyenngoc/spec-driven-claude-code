# Cross-Repo Traceability — [Product Name]

> System scenarios `@SYS-US` → participating service scenarios `{service:@US}`. **No silent drops:** every `@SYS-US` accounts for each participating service; orphan steps flagged. Service-local features (not part of any cross-service journey) are listed separately — that is fine, not a gap.

| @SYS-US | Journey | Participating service:@US | Status |
|---------|---------|---------------------------|--------|
| [@SYS-US-007] | [Checkout] | [order:@US-012, payment:@US-005, inventory:@US-009] | ✅ complete |
| [@SYS-US-008] | [Refund] | [order:@US-014, payment:@US-006] | ⚠️ orphan step (no inventory @US mapped) |

## Service-local (not part of any @SYS-US)

| Service | @US | Note |
|---------|-----|------|
| [order-service] | [@US-020] | [admin export — service-local] |
