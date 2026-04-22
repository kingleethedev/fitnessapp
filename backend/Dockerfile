# Use lightweight Python image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy Django project
COPY backend/ .

# Create required directories
RUN mkdir -p /app/staticfiles /app/media

# Expose port
EXPOSE 8000

# Start server (runs migrations + static files safely)
CMD ["sh", "-c", "python manage.py migrate && python manage.py collectstatic --noinput && gunicorn fitness_backend.wsgi:application --bind 0.0.0.0:8000"]
