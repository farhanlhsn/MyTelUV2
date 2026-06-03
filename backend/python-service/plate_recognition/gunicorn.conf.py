# Gunicorn configuration file for Plate Recognition API Concurrency
import os

bind = "0.0.0.0:5001"
workers = int(os.getenv("GUNICORN_WORKERS", "2"))
worker_class = "gthread"
threads = int(os.getenv("GUNICORN_THREADS", "4"))
timeout = 120
keepalive = 2
loglevel = "info"
accesslog = "-"
errorlog = "-"
