"""
SQLAlchemy models for Comic Upscale application.
Database: SQLite at /workspace/data/db/upscale.db
"""

import os
from datetime import datetime
from flask_sqlalchemy import SQLAlchemy
from flask_login import UserMixin
from werkzeug.security import generate_password_hash, check_password_hash

db = SQLAlchemy()


class User(UserMixin, db.Model):
    """Admin user for Flask Login."""
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(128), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def set_password(self, password):
        """Hash and set password."""
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        """Verify password hash."""
        return check_password_hash(self.password_hash, password)

    @staticmethod
    def get_by_username(username):
        """Get user by username."""
        return User.query.filter_by(username=username).first()


class ImageJob(db.Model):
    """Tracks each image upscaling job."""
    id = db.Column(db.Integer, primary_key=True)
    filename = db.Column(db.String(255), nullable=False)
    original_path = db.Column(db.String(512), nullable=False)
    output_path = db.Column(db.String(512), nullable=True)
    scale_factor = db.Column(db.Float, nullable=False, default=2.5)
    status = db.Column(db.String(20), nullable=False, default='pending')
    # Status values: pending, processing, completed, failed
    error_message = db.Column(db.Text, nullable=True)
    progress_percent = db.Column(db.Integer, default=0)
    started_at = db.Column(db.DateTime, nullable=True)
    completed_at = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        """Convert to dictionary for JSON responses."""
        return {
            'id': self.id,
            'filename': self.filename,
            'status': self.status,
            'progress': self.progress_percent,
            'scale_factor': self.scale_factor,
            'error': self.error_message,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'completed_at': self.completed_at.isoformat() if self.completed_at else None
        }


def init_db(app):
    """Initialize database with app context."""
    db.init_app(app)
    with app.app_context():
        db.create_all()
        # Create default admin user if not exists
        if not User.query.first():
            admin = User(username='admin')
            admin.set_password(os.environ.get('ADMIN_PASSWORD', 'admin123'))
            db.session.add(admin)
            db.session.commit()
