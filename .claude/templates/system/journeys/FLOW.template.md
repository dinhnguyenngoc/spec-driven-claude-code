# Journey: [Flow name] — @SYS-US-[NNN]

> Cross-service end-to-end flow. Rename file to `<flow-slug>.md`.
> **inferred:** [`true` if reconstructed from async/event edges — REQUIRES human review · `false` if from synchronous REST edges]

## Sequence

```text
[End user] → order-service: POST /api/v1/orders          (@SYS-US-007 · order:@US-012)
order-service → payment-service: payment.charge (REST)    (order:@US-012 → payment:@US-005)
payment-service → order-service: charge result
order-service → inventory-service: inventory.reserve (Event)  [inferred — review]
```

## Participating services

| Service | @US | Step |
|---------|-----|------|
| [order-service] | [@US-012] | [create order] |
| [payment-service] | [@US-005] | [charge] |
| [inventory-service] | [@US-009] | [reserve stock] |
