# Station 10: Environments & CI/CD

## 1. Objective

Enable fast, reliable, and reversible deployments.

## 2. Inputs

- Infrastructure choices.
- Codebase structure.

## 3. Trigger

Setting up the build pipeline or release process.

## 4. The "How-To"

### Environments

- Setup Local, Dev, Staging (prod-like), and Prod.

### Config

- Validate env vars at startup.
- Separate secrets per environment (e.g., Stripe keys).

### CI Gates

- Run Lint, Unit Tests, API Contract checks, and Security scans on every PR.

### Deployment

- Support rollback.
- Use "Expand/Contract" pattern for DB migrations (never breaking changes in code deploy).

### Release

- Use checklists (migrations, feature flags, monitoring).

## 5. Gate Criteria

- [ ] Environments Spec defined.
- [ ] CI Pipeline Spec defined.
- [ ] Migration Playbook (Expand/Contract) exists.
- [ ] Release Checklist exists.
