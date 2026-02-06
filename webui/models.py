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


# Upscale presets
PRESETS = {
    'art': {
        'model': 'RealESRGAN_x4plus',
        'scale': 4,
        'tile': 400,
        'face_enhance': False,
        'denoising': 0
    },
    'drawing': {
        'model': 'RealESRGAN_x4plus_anime',
        'scale': 4,
        'tile': 400,
        'face_enhance': False,
        'denoising': 0
    },
    'photo': {
        'model': 'RealESRGAN_x4plus',
        'scale': 4,
        'tile': 400,
        'face_enhance': True,
        'denoising': 0.2
    }
}

# Available models
AVAILABLE_MODELS = [
    ('RealESRGAN_x4plus', 'Real-ESRGAN 4x (General)'),
    ('RealESRGAN_x4plus_anime', 'Real-ESRGAN 4x (Anime)'),
    ('realesr-general-x4v3', 'Real-ESRGAN General 4x (Light)'),
    ('RealESRGAN_x2plus', 'Real-ESRGAN 2x'),
]


class ImageJob(db.Model):
    """Tracks each image upscaling job."""
    id = db.Column(db.Integer, primary_key=True)
    filename = db.Column(db.String(255), nullable=False)
    original_path = db.Column(db.String(512), nullable=False)
    output_path = db.Column(db.String(512), nullable=True)
    
    # Upscale parameters
    scale_factor = db.Column(db.Float, nullable=False, default=4)
    model_name = db.Column(db.String(50), nullable=False, default='RealESRGAN_x4plus')
    tile_size = db.Column(db.Integer, nullable=False, default=400)
    face_enhance = db.Column(db.Boolean, default=False)
    denoising_level = db.Column(db.Float, default=0)
    preset = db.Column(db.String(20), default='art')  # art, drawing, photo
    
    # Status tracking
    status = db.Column(db.String(20), nullable=False, default='pending')
    progress_percent = db.Column(db.Integer, default=0)
    error_message = db.Column(db.Text, nullable=True)
    
    # Timestamps
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
            'model': self.model_name,
            'face_enhance': self.face_enhance,
            'preset': self.preset,
            'error': self.error_message,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'completed_at': self.completed_at.isoformat() if self.completed_at else None
        }


def init_db(app):
    """Initialize database with app context."""
    if app.extensions.get('sqlalchemy'):
        return  # Already initialized
    db.init_app(app)
    with app.app_context():
        db.create_all()
        # Create default admin user if not exists
        if not User.query.first():
            admin = User(username='admin')
            admin.set_password(os.environ.get('ADMIN_PASSWORD', 'admin123'))
            db.session.add(admin)
            db.session.commit()
