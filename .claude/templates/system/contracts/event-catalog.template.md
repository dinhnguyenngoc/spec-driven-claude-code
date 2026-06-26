# Event / Contract Catalog — [Product Name]

> Inter-service contracts, cross-service index. REST contracts also live in each service's `openapi.yaml`; this catalog is the **cross-service** view. `contract-id` is the join key for the call-graph (must match between producer & consumers exactly).

## Events (pub/sub)

| Contract id | Topic / Schema | Producer | Consumers |
|-------------|----------------|----------|-----------|
| [order.created] | [order.events / OrderCreated] | [order-service] | [inventory-service, notification-service] |

## REST (cross-service)

| Contract id | Method / Path | Provider | Consumers |
|-------------|---------------|----------|-----------|
| [payment.charge] | [POST /api/v1/charges] | [payment-service] | [order-service] |
