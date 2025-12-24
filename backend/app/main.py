from fastapi import FastAPI

app = FastAPI(title="Direct Marketing Contracts API")

@app.get("/health")
def health():
    return {"ok": True}
