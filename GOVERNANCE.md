# BYOB Hackathon Development Governance

This repository uses an issue-driven, milestone-by-milestone workflow so multiple humans and AI coding agents can work quickly without silently broadening scope or breaking the demo path.

## Roles

- **Product owner:** decides scope, priority, and whether a milestone is worth building.
- **Reviewer / architecture gate:** checks that implementation matches the issue, preserves previous behavior, and does not create avoidable security or architecture debt.
- **Coding agent / engineer:** implements only the approved issue scope and reports exactly what changed and how it was verified.
- **GitHub:** source of truth for requirements, branches, pull requests, commits, and review evidence.

## Golden rule

One milestone = one issue = one implementation branch = one pull request = one acceptance decision.

Do not bundle the next milestone into the current implementation, even if it looks convenient.

## Required workflow

1. **Open an issue**
   - State the user-visible objective.
   - Define the smallest implementation boundary.
   - List explicit non-goals.
   - Define acceptance criteria.
   - Define how to verify locally.

2. **Create a branch from current `main`**
   - Use `milestone/<number>-<short-name>` for product milestones.
   - Use `fix/<short-name>` for defects.
   - Use `chore/<short-name>` for repository/process work.

3. **Implement only the issue**
   - Preserve existing working behavior unless the issue explicitly changes it.
   - Do not add speculative infrastructure.
   - Do not redesign unrelated UI.
   - Do not add future milestone functionality early.
   - Never commit secrets, API keys, tokens, or credentials.

4. **Verify before requesting review**
   - Build succeeds.
   - Existing critical behavior still works.
   - New acceptance criteria are demonstrably satisfied.
   - Failure paths are bounded and understandable.
   - Security-sensitive behavior uses explicit allowlists/contracts rather than arbitrary execution where practical.

5. **Open a pull request**
   The PR must state:
   - linked issue;
   - files changed;
   - behavior added/changed;
   - non-goals preserved;
   - exact verification steps;
   - known limitations;
   - screenshots/video when the change is visual.

6. **Review gate**
   A milestone is accepted only when review confirms:
   - scope matches the issue;
   - no unrelated behavior was added;
   - previous accepted milestones remain intact;
   - acceptance criteria pass;
   - architecture remains compatible with the next planned milestone;
   - no obvious security regression was introduced.

7. **Merge only after acceptance**
   - Prefer squash merge for a clean hackathon history.
   - Close the linked issue when merged.
   - Start the next milestone from the newly accepted `main`.

## Hackathon critical path

The current target sequence is:

1. **Page Context** — current URL, title, bounded visible text, bounded interactive elements.
2. **Agent Request Boundary** — send user intent + page context to the model and receive a structured capability manifest.
3. **Capability Contract** — validate model output against a strict allowlisted schema.
4. **Safe Runtime** — translate approved capability primitives into page changes; no unrestricted model-generated JavaScript.
5. **Magic Moment** — request a feature and see it appear and work inside the current webpage.
6. **Persistence** — save a capability for a site/domain and restore it on revisit/reload.

Until Milestone 5 works end-to-end, unrelated platform work is lower priority.

## Change-control rules

### Allowed without reopening architecture
- Small implementation details within the current issue.
- Tests needed to prove the current milestone.
- Minimal refactors strictly required to support the current milestone safely.

### Requires a new issue or explicit scope decision
- New model/provider integrations.
- New permissions or browser privileges.
- Arbitrary code execution.
- Authentication/accounts.
- Cloud sync.
- Marketplace/community features.
- Multi-agent orchestration.
- Major UI redesign.
- New persistence architecture.

## Security baseline

For the hackathon build:

- Treat webpage content as untrusted input.
- Treat model output as untrusted input.
- Validate all generated capability manifests before execution.
- Prefer fixed primitives such as page read/find, UI panel/button/text/highlight, bounded storage, and agent query operations.
- Do not expose cookies, passwords, credentials, unrestricted filesystem access, unrestricted browser APIs, or unrestricted network access to generated capabilities.
- Do not execute arbitrary model-generated JavaScript as the normal capability path.

## Definition of done for BYOB MVP

On an ordinary webpage, a user can describe functionality that does not exist. BYOB understands enough of the current page to generate an approved capability, safely renders that capability into the page, allows the user to use it, and can preserve it for that site when requested.
