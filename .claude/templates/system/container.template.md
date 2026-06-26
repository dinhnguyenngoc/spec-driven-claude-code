# Container Diagram (C4 L2) — [Product Name]

> All services + shared infra (gateway, message bus, shared stores) + edges synthesized from each service's §Service Contracts. Edge = `consumer ──contract-id──▶ provider`. Flag `⚠️ dangling` when a `Consumes` row has no matching `Exposes`.

```text
[order-service] ──payment.charge (REST)──▶ [payment-service]
[order-service] ──inventory.reserve (Event)──▶ [inventory-service]   (inferred)
[notification-service] ──order.created (Event)◀── [order-service]
⚠️ dangling: [order-service] consumes shipping.book — no provider found
```

## Edges (call-graph)

| Consumer | Contract id | Type (REST/Event) | Provider | Status |
|----------|-------------|-------------------|----------|--------|
| [order-service] | [payment.charge] | REST | [payment-service] | ✅ matched |
| [order-service] | [shipping.book] | REST | — | ⚠️ dangling |

> `contract-id` is the join key — a consumer's id must match the provider's exposed id **exactly**.
