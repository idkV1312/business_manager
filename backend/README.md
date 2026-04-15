# Backend (FastAPI)

## Run locally

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

API docs: http://127.0.0.1:8000/docs

## Production notes

- Replace `SECRET_KEY` in `app/auth.py`.
- Change CORS origins in `app/main.py`.
- Move SQLite to Postgres for production hosting.
