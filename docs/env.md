# Environment variables

## Backend
- `DATABASE_URL=postgresql+psycopg://app:app@localhost:5432/app` - PostgreSQL connection URL
- `STORAGE_ROOT=storage` - Root directory for file storage (contracts, PDFs), relative to backend directory
- `ESIGN_WEBHOOK_SECRET` - Secret key for validating e-signature webhook requests (required for production; tests use "testsecret")

## Frontend
- (none yet)
