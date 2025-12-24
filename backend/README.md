# Backend - Direct Marketing Contracts API

FastAPI backend for the Direct Marketing Contracts portal.

## Prerequisites

- Python 3.12
- pip

## Setup

```bash
pip install -r requirements-dev.txt
```

## Run the server

```bash
uvicorn app.main:app --reload
```

The API will be available at http://localhost:8000

## Run tests

```bash
pytest -q
```

## Linting and formatting

```bash
# Check code quality
ruff check .

# Check formatting
ruff format --check .

# Format code
ruff format .
```

## API Documentation

Once the server is running, visit:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
