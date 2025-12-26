# Environment variables

## Backend
- `DATABASE_URL=postgresql+psycopg://app:app@localhost:5432/app` - PostgreSQL connection URL
- `STORAGE_ROOT=storage` - Root directory for file storage (contracts, PDFs), relative to backend directory
- `ESIGN_PROVIDER=stub` - E-signature provider (currently only "stub" is supported)
- `ESIGN_WEBHOOK_SECRET` - Secret key for HMAC webhook signature verification (required for webhook security)
- `ESIGN_SKIP_WEBHOOK_SIGNATURE=false` - Set to "true" to skip webhook signature verification (only for testing)

## Frontend
- (none yet)
