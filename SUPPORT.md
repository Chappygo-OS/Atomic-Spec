# Support

## How to file issues and get help

This project uses GitHub issues to track bugs and feature requests. Please search the existing issues before filing new issues to avoid duplicates. For new issues, file your bug or feature request as a new issue.

For help or questions about using this project, please:

- Open a [GitHub issue](https://github.com/Chappygo-OS/Atomic-Spec/issues/new) for bug reports, feature requests, or questions about the Atomic Traceability Model
- Check the [Atomic Traceability Model guide](./atomic-traceability-model.md) for the governance model and Spec-Driven Development foundations
- Review the [README](./README.md) for getting started instructions and the Atomic Traceability Model overview

## Project Status

**Atomic Spec** is under active development. It is a customized fork of [GitHub's Spec Kit](https://github.com/github/spec-kit) that implements the Atomic Traceability Model — a governance framework enforcing Constitutional Prime Directives, Knowledge Station Gates, and Context Pinning. We will do our best to respond to support, feature requests, and community questions in a timely manner.

## Support Policy

Support for this project is limited to the resources listed above.

## AI Agent Support Tiers

Atomic Spec ships template bundles for 17 AI coding agents, organized into two tiers. Issue triage is tier-aware:

- **Supported tier** (`claude`, `gemini`, `copilot`, `cursor-agent`, `windsurf`): bugs are triaged as standard issues. Regressions block releases. See README for the full list.
- **Experimental tier** (all other agents): command templates are installed into the agent's conventional folder; the Eight Prime Directives remain enforced because they are template-enforced, but agent-specific wiring has not been validated. Issues are labeled `experimental` and triaged best-effort. PRs that promote an agent from experimental to supported — including validation scripts, an entry in `init-project.{sh,ps1}`, and at least one end-to-end smoke run documented in the PR — are welcome.

Requesting a new agent? File an issue with the template tag `agent-request` describing the agent's command-discovery convention and a link to its CLI documentation.

## Release / Publish Recovery

If a tag push triggered `release.yml` successfully (GitHub Release was created with template zips) but the automatic `publish.yml` dispatch failed (PyPI was not updated), recover manually:

```bash
# Replace vX.Y.Z with the tag that was published on GitHub but is missing from PyPI
gh workflow run publish.yml \
  --repo Chappygo-OS/Atomic-Spec \
  --ref vX.Y.Z \
  -f target=pypi
```

The `publish.yml` workflow is idempotent at the PyPI level — if the version is already uploaded, PyPI will reject the duplicate and the run will fail harmlessly. Safe to re-run.

Manual TestPyPI dry-runs use the same pattern with `target=testpypi` against the `main` branch.
