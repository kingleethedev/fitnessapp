# Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV DJANGO_SETTINGS_MODULE fitness_backend.settings

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy project
COPY . .

# Create necessary directories
RUN mkdir -p /app/staticfiles /app/media /app/logs

# Collect static files
RUN python manage.py collectstatic --noinput

# Run migrations
RUN python manage.py migrate

# Create superuser for admin (optional - use environment variables)
RUN echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.filter(email='admin@fitnessapp.com').exists() or User.objects.create_superuser('admin', 'admin@fitnessapp.com', 'admin123')" | python manage.py shell || true

EXPOSE 8000

# Run with gunicorn
CMD ["gunicorn", "fitness_backend.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "4", "--threads", "2"]