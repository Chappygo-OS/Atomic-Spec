# Station 03: User Flows & Information Architecture

## 1. Objective

Define navigation, states, and transitions to prevent frontend/backend rework.

## 2. Inputs

- ICP/JTBD.
- Wedge.
- PRD.
- Metrics Draft.

## 3. Trigger

When designing the UI/UX or defining frontend state logic.

## 4. The "How-To"

### IA Definition

- Define primary/secondary navigation.
- Define settings area (User vs Org).
- Define tenant switching logic.

### Flow Types

- Map **Activation** (signup to value).
- Map **Core value loop**.
- Map **Collaboration** (invites).
- Map **Billing** and **Limits** flows.

### Edge State Checklist

For every step, define behavior for:

- **RBAC**: Forbidden states.
- **Tenant mismatch**.
- **Limit hit**: Warning vs block.
- **Billing state**: Trial end/payment failed.
- **Empty state**.
- **Error/Loading states**.

### Limit/Billing Policy

- Explicitly define UI behavior for "Limit Hit" (e.g., modal vs banner).
- Explicitly define UI behavior for "Payment Failed" (grace period vs lock).

## 5. Gate Criteria

- [ ] IA includes core workflow and admin surfaces.
- [ ] Activation flow leads to the activation event.
- [ ] Core wedge flow covers all explicit edge states (RBAC, Limits, Billing).
- [ ] Screen/State inventory exists for MVP screens.
