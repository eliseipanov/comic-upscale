"""
Flask routes for Comic Upscale Admin UI.
Routes: /login, /, /download/<id>, /api/status
"""

import os
from flask import Blueprint, render_template, request, redirect, url_for, flash, send_file, jsonify
from flask_login import login_user, logout_user, login_required, current_user
from flask.models import db, ImageJob
from datetime import datetime

bp = Blueprint('routes', __name__)

OUTPUT_DIR = os.environ.get('OUTPUT_DIR', '/app/data/output')


@bp.route('/login', methods=['GET', 'POST'])
def login():
    """Admin login page."""
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        from flask.models import User
        user = User.get_by_username(username)
        
        if user and user.check_password(password):
            login_user(user)
            return redirect(url_for('routes.dashboard'))
        else:
            flash('Invalid credentials', 'error')
    
    return render_template('login.html')


@bp.route('/logout')
@login_required
def logout():
    """Logout user."""
    logout_user()
    return redirect(url_for('routes.login'))


@bp.route('/')
@login_required
def dashboard():
    """Main dashboard with job progress."""
    # Get job statistics
    total = ImageJob.query.count()
    pending = ImageJob.query.filter_by(status='pending').count()
    processing = ImageJob.query.filter_by(status='processing').count()
    completed = ImageJob.query.filter_by(status='completed').count()
    failed = ImageJob.query.filter_by(status='failed').count()
    
    # Recent jobs
    recent_jobs = ImageJob.query.order_by(ImageJob.created_at.desc()).limit(20).all()
    
    # Progress calculation
    progress = 0
    if total > 0:
        progress = int((completed / total) * 100)
    
    stats = {
        'total': total,
        'pending': pending,
        'processing': processing,
        'completed': completed,
        'failed': failed,
        'progress': progress
    }
    
    return render_template('dashboard.html', stats=stats, jobs=recent_jobs)


@bp.route('/download/<int:job_id>')
@login_required
def download(job_id):
    """Download upscaled image."""
    job = ImageJob.query.get_or_404(job_id)
    
    if job.status != 'completed' or not job.output_path:
        flash('File not ready', 'error')
        return redirect(url_for('routes.dashboard'))
    
    if not os.path.exists(job.output_path):
        flash('File not found on disk', 'error')
        return redirect(url_for('routes.dashboard'))
    
    return send_file(
        job.output_path,
        as_attachment=True,
        download_name=f"upscale_{job.scale_factor}x_{job.filename}"
    )


@bp.route('/api/status')
@login_required
def api_status():
    """JSON API for job status."""
    jobs = ImageJob.query.order_by(ImageJob.created_at.desc()).limit(50).all()
    return jsonify({
        'jobs': [job.to_dict() for job in jobs],
        'timestamp': datetime.utcnow().isoformat()
    })


@bp.route('/api/stats')
@login_required
def api_stats():
    """JSON API for statistics."""
    total = ImageJob.query.count()
    completed = ImageJob.query.filter_by(status='completed').count()
    failed = ImageJob.query.filter_by(status='failed').count()
    
    return jsonify({
        'total': total,
        'completed': completed,
        'failed': failed,
        'progress': int((completed / total) * 100) if total > 0 else 0
    })


@bp.route('/health')
def health():
    """Health check endpoint (no auth required)."""
    return {'status': 'healthy', 'timestamp': datetime.utcnow().isoformat()}
