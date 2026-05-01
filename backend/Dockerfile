FROM python:3.11-slim

WORKDIR /app

# Env variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install system deps
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Install Python deps
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy project
COPY backend/ .

# Create required dirs with proper permissions
RUN mkdir -p /app/staticfiles /app/media /app/logs && \
    chmod -R 755 /app/media

# Expose port
EXPOSE 8000

# Start server
CMD ["sh", "-c", "python manage.py migrate && python manage.py collectstatic --noinput && gunicorn fitness_backend.wsgi:application --bind 0.0.0.0:$PORT --workers 1 --threads 2"]
