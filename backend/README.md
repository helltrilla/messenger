# 🖥️ Standalone Messenger Backend Server (FastAPI + WebSockets + Docker)

Автономный сервер бэкенда для мессенджера Telegram 2.0. Может запускаться независимо на любом сервере/VPS через Docker или локально.

---

## 🚀 Запуск в Docker (1 команда)

```bash
cd backend
docker compose up -d --build
```

Сервер запустится на `http://localhost:8000`:
- **Swagger Документация API**: [http://localhost:8000/docs](http://localhost:8000/docs)
- **ReDoc Документация API**: [http://localhost:8000/redoc](http://localhost:8000/redoc)
- **WebSocket для переписки**: `ws://localhost:8000/ws/{user_id}`
- **PostgreSQL**: `localhost:5432`
- **Redis**: `localhost:6379`

---

## 🛠️ Локальный запуск без Docker

Требуется Python 3.9+:

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```
