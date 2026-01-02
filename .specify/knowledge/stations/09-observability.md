# Station 09: Observability & Runbooks

## 1. Objective

Detect issues before users and debug production problems quickly.

## 2. Inputs

- API standards.
- Architecture decisions.

## 3. Trigger

Setting up logging, monitoring, or operational procedures.

## 4. The "How-To"

### Logging

- Use structured JSON.
- Include `requestId`, `tenantId`, `userId`, `error.code` in every log.

### PII Policy

- Never log raw secrets or passwords.
- Mask sensitive fields.

### Metrics

- Track:
  - **HTTP**: latency/errors.
  - **Jobs**: queue depth/failures.
  - **Billing**: webhook failures.
  - **Limits**: blocks.

### Alerting

- Define **SEV1** (outage/security) and **SEV2** (degradation) triggers.

### Runbooks

- Create guides for top failures (Auth outage, Webhook failure, Database performance).

## 5. Gate Criteria

- [ ] Logging Standard defined (fields + PII rules).
- [ ] Metrics Catalog exists.
- [ ] Alert Policy (SEV levels) defined.
- [ ] MVP Runbooks exist for top failure modes.
