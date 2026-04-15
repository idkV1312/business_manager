# business_manager

Flutter клиент + FastAPI backend для:
- пользователей и админов,
- создания событий админом,
- записи пользователя на событие,
- чата по событию.

## 1) Запуск backend

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

Swagger: `http://127.0.0.1:8000/docs`

## 2) Запуск Flutter

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Для Android-эмулятора обычно нужен:
`--dart-define=API_BASE_URL=http://10.0.2.2:8000`

## Что реализовано

- Аутентификация: `register/login` с ролями `user/admin`.
- Админ:
  - добавляет исполнителей,
  - создает события (описание, категория, исполнители).
- Пользователь:
  - видит события,
  - записывается на сеанс.
- Чат:
  - сообщения по событию через REST,
  - backend также поддерживает WebSocket (`/ws/events/{event_id}/chat?token=...`).

## Перед продакшен-хостингом

- Заменить `SECRET_KEY` в `backend/app/auth.py`.
- Ограничить CORS (`allow_origins`) в `backend/app/main.py`.
- Перейти с SQLite на Postgres.
