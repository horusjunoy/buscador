FROM python:3.12-slim-bookworm@sha256:d50fb7611f86d04a3b0471b46d7557818d88983fc3136726336b2a4c657aa30b
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 APP_ENV=local
COPY backend/requirements.txt /app/backend/requirements.txt
RUN python -m pip install --no-cache-dir -r backend/requirements.txt
RUN groupadd --gid 11000 buscador && useradd --uid 11000 --gid 11000 --no-create-home buscador
COPY backend /app/backend
COPY scripts/migrate.py /app/scripts/migrate.py
COPY dist/web /app/dist/web
USER 11000:11000
EXPOSE 8765
CMD ["python", "-m", "uvicorn", "backend.app.main:app", "--host", "0.0.0.0", "--port", "8765", "--no-access-log"]
