"""
Flask routes for Comic Upscale Admin UI.
Routes: /login, /, /upload, /download/<id>, /api/status
"""

import os
import uuid
from flask import Blueprint, render_template, request, redirect, url_for, flash, send_file, jsonify
from flask_login import login_user, logout_user, login_required, current_user
from webui.models import db, ImageJob, User, AVAILABLE_MODELS, PRESETS
from datetime import datetime

bp = Blueprint('routes', __name__)

OUTPUT_DIR = os.environ.get('OUTPUT_DIR', '/workspace/data/output')
INPUT_DIR = os.environ.get('INPUT_DIR', '/workspace/data/input')


@bp.route('/login', methods=['GET', 'POST'])
def login():
    """Admin login page."""
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
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
    
    return render_template('dashboard.html', stats=stats, jobs=recent_jobs, presets=PRESETS)


@bp.route('/upload', methods=['GET', 'POST'])
@login_required
def upload():
    """Upload page with parameters."""
    if request.method == 'POST':
        # Get parameters
        preset = request.form.get('preset', 'art')
        custom = request.form.get('custom') == 'on'
        
        if custom:
            # Custom parameters
            scale = float(request.form.get('scale', 4))
            model = request.form.get('model', 'RealESRGAN_x4plus')
            tile = int(request.form.get('tile', 400))
            face_enhance = request.form.get('face_enhance') == 'on'
            denoising = float(request.form.get('denoising', 0))
        else:
            # Use preset
            preset_config = PRESETS.get(preset, PRESETS['art'])
            scale = preset_config['scale']
            model = preset_config['model']
            tile = preset_config['tile']
            face_enhance = preset_config['face_enhance']
            denoising = preset_config['denoising']
        
        # Handle file uploads
        files = request.files.getlist('images')
        if not files or all(f.filename == '' for f in files):
            flash('No files selected', 'error')
            return redirect(url_for('routes.upload'))
        
        # Ensure input directory exists
        os.makedirs(INPUT_DIR, exist_ok=True)
        
        jobs_created = 0
        for file in files:
            if file.filename:
                # Save file
                filename = f"{uuid.uuid4().hex[:8]}_{file.filename}"
                filepath = os.path.join(INPUT_DIR, filename)
                file.save(filepath)
                
                # Create job
                job = ImageJob(
                    filename=file.filename,
                    original_path=filepath,
                    scale_factor=scale,
                    model_name=model,
                    tile_size=tile,
                    face_enhance=face_enhance,
                    denoising_level=denoising,
                    preset=preset if not custom else 'custom',
                    status='pending'
                )
                db.session.add(job)
                jobs_created += 1
        
        db.session.commit()
        flash(f'Created {jobs_created} job(s) with preset: {preset}', 'success')
        return redirect(url_for('routes.dashboard'))
    
    return render_template('upload.html', presets=PRESETS, models=AVAILABLE_MODELS)


@bp.route('/upload/preset/<preset_name>')
@login_required
def upload_preset(preset_name):
    """Quick upload with preset."""
    if preset_name not in PRESETS:
        flash(f'Unknown preset: {preset_name}', 'error')
        return redirect(url_for('routes.upload'))
    
    return render_template('upload.html', presets=PRESETS, models=AVAILABLE_MODELS, selected_preset=preset_name)


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


@bp.route('/job/<int:job_id>')
@login_required
def job_detail(job_id):
    """Job detail page."""
    job = ImageJob.query.get_or_404(job_id)
    return render_template('job_detail.html', job=job)


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
    processing = ImageJob.query.filter_by(status='processing').count()
    
    return jsonify({
        'total': total,
        'completed': completed,
        'failed': failed,
        'processing': processing,
        'progress': int((completed / total) * 100) if total > 0 else 0
    })


@bp.route('/api/presets')
@login_required
def api_presets():
    """JSON API for presets."""
    return jsonify({
        'presets': PRESETS,
        'models': AVAILABLE_MODELS
    })


@bp.route('/health')
def health():
    """Health check endpoint (no auth required)."""
    return {'status': 'healthy', 'timestamp': datetime.utcnow().isoformat()}
