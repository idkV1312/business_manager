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

## Default admin

- Email: `admin@studio.com`
- Password: `Admin12345!`

Admin registration via `/auth/register` is disabled.
Employees register as `performer`, then admin approves them and assigns a work point.

## Production notes

- Create `.env` from `.env.example` and set strong values for `SECRET_KEY` and `DEFAULT_ADMIN_PASSWORD`.
- Change CORS origins in `app/main.py`.
- Move SQLite to Postgres for production hosting.
