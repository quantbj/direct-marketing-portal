# Project goal
Build a web app (frontend + backend) that lets customers close direct marketing contracts.

# Tech stack
- Backend: Python 3.12, FastAPI, SQLAlchemy, Alembic, PostgreSQL
- Frontend: Next.js (TypeScript)
- Testing: pytest (backend), Playwright or Vitest (frontend)

# Quality gates (must pass in CI)
Backend:
- ruff check .
- ruff format --check .
- mypy backend (if configured)
- pytest -q

Frontend:
- pnpm lint
- pnpm test (if present)
- pnpm build

# PR rules
- Keep PRs small (<400 LOC changed) unless explicitly requested.
- Always add/adjust tests for behavior changes.
- Update OpenAPI schema when API changes.
- Never add secrets; use env vars and document required variables in /docs/env.md

# Domain constraints
- Treat consent (marketing opt-in) separate from contract acceptance.
- Store auditable events (timestamps, doc versions, identifiers) in the DB.
