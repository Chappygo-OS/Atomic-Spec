# Security Policy

Thanks for helping make Atomic Spec safe for everyone.

## Reporting Security Issues

If you believe you have found a security vulnerability in this repository, please report it through coordinated disclosure.

**Please do not report security vulnerabilities through public GitHub issues, discussions, or pull requests.**

Instead, please open a **private security advisory** via GitHub:

1. Go to the [Security tab](https://github.com/Airchitekt/atomic-spec/security) of the Atomic Spec repository
2. Click **Report a vulnerability**
3. Fill in the advisory with details

If GitHub's private advisory flow is unavailable to you, you may alternatively open a minimal GitHub issue titled "Security contact request" (without sensitive details) and a maintainer will follow up privately.

Please include as much of the information listed below as you can to help us triage and resolve the issue:

- The type of issue (e.g., command injection, path traversal, prompt injection via templates, exposed secret, etc.)
- Full paths of source file(s) related to the manifestation of the issue
- The location of the affected source code (tag/branch/commit or direct URL)
- Any special configuration required to reproduce the issue
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue, including how an attacker might exploit it

## Scope Notes

Atomic Spec is a **governance framework distributed as templates, prompts, and a thin Python CLI**. It does not run as a hosted service. Typical security concerns for this project include:

- **Command injection** in `scripts/bash/*.sh` or `scripts/powershell/*.ps1`
- **Path traversal** in template installers (`init-project.sh`, `init-project.ps1`)
- **Prompt injection** in command templates that instruct consumer AI agents
- **Supply chain risks** in the published Python CLI distribution

Issues in consumer projects generated *by* Atomic Spec are out of scope — they should be reported to those projects directly.
