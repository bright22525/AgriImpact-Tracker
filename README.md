
# AgriImpact Tracker

Transparent NGO & Project Impact Management on Stacks Blockchain

## Overview

AgriImpact Tracker is a Clarity smart contract designed to:
- Register NGOs
- Manage projects and milestones
- Collect and track donations
- Verify project milestones
- Release funds securely and transparently

## Features

- **NGO Registration:** NGOs can register and provide metadata.
- **Project Management:** NGOs can create projects with funding goals.
- **Milestone Tracking:** Projects can define milestones for staged funding.
- **Donation System:** Anyone can donate to projects.
- **Milestone Verification:** Authorized verifiers can verify milestones.
- **Fund Release:** Funds are released upon milestone verification.
- **Admin Controls:** Owner can verify NGOs and manage verifiers.
- **Event Logging:** Emits events for off-chain indexing and transparency.

## Data Structures

- **NGOs:** Stores NGO details, wallet, verification status, and metadata.
- **Projects:** Tracks project info, funding goals, and status.
- **Milestones:** Defines project milestones, amounts, and verification.
- **Donations:** Records donations with donor, amount, and timestamp.
- **Verifiers:** Registry of authorized milestone verifiers.

## Key Functions

- `register-ngo(name, metadata)` — Register a new NGO.
- `create-project(ngo-id, title, description, goal)` — NGO creates a project.
- `donate(project-id, amount)` — Donate to a project.
- `create-milestone(project-id, title, description, amount)` — NGO adds a milestone.
- `verify-milestone(milestone-id)` — Verifier verifies a milestone.
- `release-funds(milestone-id)` — Owner or verifier releases funds for a verified milestone.
- `set-verifier(addr, allow)` — Owner manages verifiers.
- `verify-ngo(ngo-id)` — Owner verifies an NGO.

## Read-Only Views

- `get-ngo(ngo-id)`
- `get-project(project-id)`
- `get-milestone(milestone-id)`
- `get-donation(donation-id)`
- `get-verifier-status(addr)`
- `get-ngo-count`
- `get-project-count`
- `get-donation-count`
- `get-milestone-count`

## Events

- `ngo-registered`
- `ngo-verified`
- `project-created`
- `donation-received`
- `milestone-created`
- `milestone-verified`
- `funds-released`

## Usage

1. **Deploy the contract** using Clarinet or Stacks CLI.
2. **Register NGOs** via `register-ngo`.
3. **Create projects and milestones** as an NGO.
4. **Donate** to projects.
5. **Verify milestones** as an authorized verifier.
6. **Release funds** for verified milestones.

## Development

- Contract: AgriImpact-Tracker.clar
- Tests: AgriImpact-Tracker.test.ts
- Config: Clarinet.toml, package.json

## License

MIT License
