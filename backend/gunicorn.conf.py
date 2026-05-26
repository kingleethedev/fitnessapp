import multiprocessing
import os

# Gunicorn configuration file
bind = "0.0.0.0:8000"
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "sync"
worker_connections = 1000
timeout = 30
keepalive = 2
max_requests = 1000
max_requests_jitter = 50

# Logging
accesslog = "logs/gunicorn_access.log"
errorlog = "logs/gunicorn_error.log"
loglevel = "info"

# Process naming
proc_name = "fitness_backend"

# Daemonize (for production)
daemon = False

# Reload on code change (development only)
reload = os.getenv('DEBUG', 'False') == 'True'