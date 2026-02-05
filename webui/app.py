"""
Flask application factory for Comic Upscale Admin UI.
Runs on port 5800.
"""

import os
from flask import Flask
from flask_login import LoginManager
from webui.models import db, User, init_db

# Database path
DATABASE_PATH = os.environ.get('DATABASE_PATH', '/app/data/db/upscale.db')
SECRET_KEY = os.environ.get('FLASK_SECRET_KEY', 'dev-secret-key-change-in-prod')


def create_app():
    """Create and configure Flask application."""
    app = Flask(__name__)
    
    # Configuration
    app.config['SECRET_KEY'] = SECRET_KEY
    app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{DATABASE_PATH}'
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {
        'pool_pre_ping': True,
        'pool_recycle': 300
    }
    
    # Initialize database
    init_db(app)
    
    # Initialize Flask-Login
    login_manager = LoginManager()
    login_manager.init_app(app)
    login_manager.login_view = 'login'
    
    @login_manager.user_loader
    def load_user(user_id):
        return User.query.get(int(user_id))
    
    # Register blueprints/routes
    from webui.routes import bp
    app.register_blueprint(bp)
    
    return app
