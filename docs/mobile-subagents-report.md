# Mobile Development Subagents Report

## Executive Summary

Created **146+ comprehensive subagent files** covering the complete mobile application development lifecycle across **14 categories** and **140+ subcategories**.

## File Structure

```
.specify/subagents/mobile/
├── 01-discovery/          (8 files)  - Discovery & Strategy
├── 02-requirements/       (8 files)  - Requirements & Planning
├── 03-ux-ui/              (11 files) - UX/UI Design
├── 04-architecture/       (12 files) - Architecture & Technical Design
├── 05-backend/            (12 files) - Backend Development
├── 06-frontend-mobile/    (18 files) - Frontend / Mobile Development
├── 07-security/           (12 files) - Security
├── 08-testing/            (14 files) - Testing
├── 09-devops/             (11 files) - DevOps & CI/CD
├── 10-analytics/          (9 files)  - Analytics & Monitoring
├── 11-app-store/          (11 files) - App Store Preparation & Launch
├── 12-maintenance/        (14 files) - Post-Launch & Maintenance
├── 13-legal/              (9 files)  - Legal & Compliance
└── 14-documentation/      (7 files)  - Documentation
```

## Category Breakdown

### 1. Discovery & Strategy (8 subagents)
| File | Specialist Area |
|------|-----------------|
| `market-research.md` | Market research and competitor analysis |
| `target-audience.md` | Target audience definition and personas |
| `problem-solution-fit.md` | Problem validation, Mom Test methodology |
| `business-model.md` | Monetization strategies, unit economics |
| `platform-choice.md` | iOS vs Android vs cross-platform decisions |
| `mvp-scope.md` | MVP scope definition, MoSCoW prioritization |
| `budget-timeline.md` | Cost estimation, team composition |
| `success-metrics.md` | KPI definition, AARRR framework |

### 2. Requirements & Planning (8 subagents)
| File | Specialist Area |
|------|-----------------|
| `functional-requirements.md` | User stories, acceptance criteria, BDD |
| `non-functional-requirements.md` | Performance, scalability, availability SLAs |
| `technical-feasibility.md` | Platform capability assessment, POC planning |
| `tech-stack-selection.md` | Framework comparison, native vs cross-platform |
| `third-party-services.md` | SDK evaluation, service comparison |
| `project-management.md` | Agile/Scrum, sprint planning, ceremonies |
| `team-composition.md` | Role definitions, hiring recommendations |
| `risk-assessment.md` | Technical and timeline risk mitigation |

### 3. UX/UI Design (11 subagents)
| File | Specialist Area |
|------|-----------------|
| `information-architecture.md` | Navigation structure, user flows |
| `wireframing.md` | Low-fidelity wireframes |
| `prototyping.md` | Interactive prototypes |
| `visual-design-system.md` | Design tokens, component library |
| `platform-guidelines.md` | iOS HIG, Material Design compliance |
| `accessibility-design.md` | WCAG, VoiceOver/TalkBack |
| `micro-interactions.md` | Animations, feedback patterns |
| `dark-mode-theming.md` | Theme system, color adaptation |
| `responsive-layouts.md` | Screen size adaptation, safe areas |
| `usability-testing.md` | User testing, test scripts |
| `design-handoff.md` | Developer handoff, Figma/Zeplin |

### 4. Architecture & Technical Design (12 subagents)
| File | Specialist Area |
|------|-----------------|
| `system-architecture.md` | Client-server, microservices design |
| `api-design.md` | REST/GraphQL, OpenAPI |
| `database-schema.md` | SQL vs NoSQL, schema design |
| `auth-strategy.md` | OAuth2, JWT, MFA, biometrics |
| `state-management.md` | Redux, BLoC, Provider patterns |
| `caching-strategy.md` | Local DB, CDN, in-memory |
| `offline-architecture.md` | Offline-first, data sync |
| `push-architecture.md` | APNs, FCM implementation |
| `realtime-communication.md` | WebSockets, SSE |
| `file-storage.md` | Cloud storage, CDN for media |
| `error-logging.md` | Error handling, logging architecture |
| `code-architecture.md` | MVVM, Clean Architecture, MVI |

### 5. Backend Development (12 subagents)
| File | Specialist Area |
|------|-----------------|
| `server-setup.md` | Server configuration |
| `api-development.md` | Endpoint development |
| `database-implementation.md` | Migrations, queries |
| `user-auth.md` | Authentication, session management |
| `access-control.md` | RBAC implementation |
| `file-handling.md` | Upload/download |
| `background-jobs.md` | Task queues |
| `rate-limiting.md` | Throttling |
| `webhooks.md` | Event-driven integrations |
| `admin-panel.md` | Admin dashboard |
| `notification-service.md` | Email/SMS |
| `search-functionality.md` | Elasticsearch, Algolia |

### 6. Frontend / Mobile Development (18 subagents)
| File | Specialist Area |
|------|-----------------|
| `project-scaffolding.md` | Project setup, folder structure |
| `navigation-routing.md` | NavigationStack, NavGraph |
| `ui-components.md` | Reusable component library |
| `api-integration.md` | HTTP client, interceptors |
| `local-storage.md` | SQLite, Realm, Core Data, Room |
| `state-implementation.md` | State management |
| `form-handling.md` | Input validation |
| `image-handling.md` | Loading, caching, optimization |
| `deep-linking.md` | Universal links |
| `push-handling.md` | Notification handling |
| `iap-integration.md` | In-app purchases |
| `social-login.md` | Apple, Google, Facebook login |
| `device-features.md` | Camera, location, sensors |
| `internationalization.md` | i18n, l10n |
| `rtl-support.md` | RTL language support |
| `animations.md` | Transitions, Lottie |
| `onboarding.md` | Onboarding flows |
| `state-screens.md` | Error/empty/loading states |

### 7. Security (12 subagents)
| File | Specialist Area |
|------|-----------------|
| `secure-storage.md` | Encryption at rest, Keychain/Keystore |
| `secure-communication.md` | TLS/SSL, certificate pinning |
| `input-sanitization.md` | Injection prevention |
| `secrets-management.md` | API key management |
| `code-obfuscation.md` | Tamper detection |
| `jailbreak-detection.md` | Root detection |
| `session-management.md` | Token expiration |
| `privacy-compliance.md` | GDPR, CCPA implementation |
| `penetration-testing.md` | Security testing |
| `vulnerability-scanning.md` | OWASP Mobile Top 10 |
| `secure-backup.md` | Data export security |
| `biometric-security.md` | Face ID, fingerprint security |

### 8. Testing (14 subagents)
| File | Specialist Area |
|------|-----------------|
| `unit-testing.md` | Business logic testing |
| `widget-testing.md` | Component testing |
| `integration-testing.md` | API + UI integration |
| `e2e-testing.md` | Appium, Detox, Maestro |
| `api-testing.md` | Postman, contract tests |
| `performance-testing.md` | Load testing |
| `security-testing.md` | Security testing |
| `usability-testing.md` | User testing |
| `accessibility-testing.md` | Screen reader testing |
| `device-compatibility.md` | Device matrix testing |
| `network-condition.md` | Offline, slow network |
| `regression-testing.md` | Test suite maintenance |
| `beta-testing.md` | TestFlight, Firebase distribution |
| `edge-case-testing.md` | Boundary conditions |

### 9. DevOps & CI/CD (11 subagents)
| File | Specialist Area |
|------|-----------------|
| `version-control.md` | Git, branching strategy |
| `ci-cd-pipeline.md` | GitHub Actions, Fastlane |
| `automated-build-test.md` | Build automation |
| `code-signing.md` | Provisioning profiles |
| `environment-management.md` | Dev, staging, production |
| `infrastructure-code.md` | Terraform, CloudFormation |
| `containerization.md` | Docker for backend |
| `auto-scaling.md` | Load balancing |
| `database-backup.md` | Disaster recovery |
| `feature-flags.md` | LaunchDarkly, Remote Config |
| `secret-management.md` | Vault, AWS Secrets Manager |

### 10. Analytics & Monitoring (9 subagents)
| File | Specialist Area |
|------|-----------------|
| `crash-reporting.md` | Sentry, Crashlytics |
| `apm.md` | Application Performance Monitoring |
| `user-analytics.md` | Mixpanel, Amplitude |
| `funnel-tracking.md` | Conversion tracking |
| `session-recording.md` | UXCam, heatmaps |
| `server-monitoring.md` | Datadog, Grafana |
| `log-aggregation.md` | ELK stack |
| `uptime-monitoring.md` | Uptime checks |
| `custom-events.md` | KPI-aligned tracking |

### 11. App Store Preparation & Launch (11 subagents)
| File | Specialist Area |
|------|-----------------|
| `aso-optimization.md` | ASO, keywords, rankings |
| `screenshots-videos.md` | Store assets |
| `app-icon.md` | Icon design, adaptive icons |
| `privacy-terms.md` | Legal documents |
| `guidelines-compliance.md` | App Store/Play Store rules |
| `content-rating.md` | IARC, age ratings |
| `review-preparation.md` | Demo accounts, notes |
| `staged-rollout.md` | Phased release |
| `launch-marketing.md` | Product Hunt, press |
| `landing-page.md` | Website, smart banners |
| `submission-process.md` | App Store Connect, Play Console |

### 12. Post-Launch & Maintenance (14 subagents)
| File | Specialist Area |
|------|-----------------|
| `user-feedback.md` | Review monitoring, NPS |
| `bug-triage.md` | Hotfix procedures |
| `dependency-updates.md` | Library updates |
| `os-compatibility.md` | New iOS/Android support |
| `performance-optimization.md` | Profiling, optimization |
| `feature-roadmap.md` | RICE prioritization |
| `ab-testing.md` | Experiment framework |
| `app-size-optimization.md` | Binary size reduction |
| `technical-debt.md` | Debt management |
| `database-maintenance.md` | Migrations, optimization |
| `api-versioning.md` | Deprecation strategy |
| `security-audits.md` | Regular security reviews |
| `billing-management.md` | Subscription lifecycle |
| `customer-support.md` | Zendesk, Intercom |

### 13. Legal & Compliance (9 subagents)
| File | Specialist Area |
|------|-----------------|
| `terms-privacy.md` | Terms of Service, Privacy Policy |
| `gdpr-ccpa.md` | Data protection compliance |
| `cookie-consent.md` | ATT, tracking consent |
| `open-source-licenses.md` | License compliance |
| `intellectual-property.md` | Trademarks, patents |
| `accessibility-compliance.md` | WCAG, ADA |
| `age-gating.md` | COPPA compliance |
| `export-control.md` | Encryption export rules |
| `data-retention.md` | Deletion policies |

### 14. Documentation (7 subagents)
| File | Specialist Area |
|------|-----------------|
| `architecture-docs.md` | C4 diagrams, ADRs |
| `api-docs.md` | OpenAPI, Swagger |
| `code-docs.md` | Inline comments, docstrings |
| `developer-onboarding.md` | Setup guides |
| `runbook.md` | Operations, incident response |
| `help-center.md` | User-facing FAQ |
| `release-notes.md` | Changelogs |

## Subagent Structure

Each subagent file includes:

1. **YAML Frontmatter**
   - `name`: Unique identifier
   - `platform`: mobile
   - `description`: What the subagent specializes in
   - `model`: opus (for complex tasks)
   - `category`: mobile/{category}

2. **Core Competencies** - What the subagent knows

3. **Key Concepts** - Domain knowledge with tables, code examples

4. **Deliverables** - What the subagent produces

5. **Gate Criteria** - Checklist for completion

## Usage

These subagents are designed to be invoked by the Atomic Spec system during mobile app development tasks. They provide:

- **Specialized expertise** for each subcategory
- **Platform-aware guidance** (iOS, Android, cross-platform)
- **Industry best practices** with specific tools and patterns
- **Checklists and templates** for consistent quality

## Statistics

| Metric | Value |
|--------|-------|
| Total Categories | 14 |
| Total Subcategories | 140+ |
| Total Subagent Files | 146+ |
| Platforms Covered | iOS, Android, React Native, Flutter |
| Lifecycle Phases | Discovery → Launch → Maintenance |

---

*Generated by Atomic Spec - Mobile Extension*
