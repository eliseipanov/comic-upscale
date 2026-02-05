# wsgi.py - WSGI entry point for Gunicorn
# Usage: gunicorn --bind 0.0.0.0:5800 wsgi:app

from webui.app import create_app

app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5800)
