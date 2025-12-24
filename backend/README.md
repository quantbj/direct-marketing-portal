# Backend

FastAPI backend for Direct Marketing Contracts portal.

## Setup

```bash
pip install -r requirements-dev.txt
```

## Run

```bash
uvicorn app.main:app --reload
```

## Test

```bash
pytest -q
```

## Lint

```bash
ruff check .
ruff format --check .
```

## Format

```bash
ruff format .
```
