#!/usr/bin/env python3
"""
Comic Upscale - Async Upscaling Engine
Uses Real-ESRGAN to upscale images with SQLite tracking.

Usage:
    python upscale.py --input /path/to/input --output /path/to/output --scale 2.5 --workers 4

Available Models:
    - RealESRGAN_x4plus          # General photos (4x)
    - RealESRGAN_x4plus_anime    # Anime/comics (4x) - RECOMMENDED for comics
    - RealESRGAN_x4plus_anime_6B # Lightweight anime (4x)
    - RealESRNet_x4plus          # Basic (no restoration)
    - RealESRGAN_x2plus          # General photos (2x)
    - realesr-general-x4v3       # Tiny general model (4x)
    - realesrgan-x2plus          # 2x scaling model

Denoising (--dn 0-1): Higher = more denoising, less detail
"""

import argparse
import asyncio
import logging
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path
from threading import Lock

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Configure logging
LOG_DIR = '/workspace/data/logs'
os.makedirs(LOG_DIR, exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'{LOG_DIR}/upscale.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


# Supported models with descriptions
AVAILABLE_MODELS = {
    'RealESRGAN_x4plus': {
        'desc': 'General photos (4x) - High quality',
        'vram': '~5 GB',
        'best_for': 'Photos, realistic images'
    },
    'RealESRGAN_x4plus_anime': {
        'desc': 'Anime/Comics (4x) - BEST FOR COMICS',
        'vram': '~4 GB',
        'best_for': 'Anime, comics, cartoons'
    },
    'RealESRGAN_x4plus_anime_6B': {
        'desc': 'Lightweight anime (4x) - Faster',
        'vram': '~3 GB',
        'best_for': 'Low-resource anime upscaling'
    },
    'RealESRNet_x4plus': {
        'desc': 'Basic upscaling (4x) - No restoration',
        'vram': '~4 GB',
        'best_for': 'Simple upscaling only'
    },
    'RealESRGAN_x2plus': {
        'desc': 'General photos (2x)',
        'vram': '~4 GB',
        'best_for': '2x upscaling needed'
    },
    'realesr-general-x4v3': {
        'desc': 'Tiny general model (4x) - Low VRAM',
        'vram': '~2 GB',
        'best_for': 'Low VRAM, general scenes'
    },
    'realesrgan-x2plus': {
        'desc': '2x model variant',
        'vram': '~3 GB',
        'best_for': '2x upscaling'
    },
}


def print_available_models():
    """Print available models with descriptions."""
    print("\n📦 Available Real-ESRGAN Models:")
    print("-" * 60)
    for model, info in AVAILABLE_MODELS.items():
        print(f"  {model:30s} | {info['vram']:8s} | {info['desc']}")
    print("-" * 60)
    print("🎯 RECOMMENDED for comics: RealESRGAN_x4plus_anime")
    print()


class UpscaleEngine:
    """Async upscaling engine with Real-ESRGAN."""
    
    def __init__(self, scale: float = 2.5, workers: int = 4, 
                 model_name: str = 'RealESRGAN_x4plus',
                 denoise_strength: float = 0.0):
        self.scale = scale
        self.workers = workers
        self.model_name = model_name
        self.denoise_strength = denoise_strength
        self.executor = ThreadPoolExecutor(max_workers=workers)
        self.queue = asyncio.Queue()
        self.processing_count = 0
        self.processing_lock = Lock()
        self._model = None
        
        logger.info(f"Initialized UpscaleEngine: scale={scale}, workers={workers}, model={model_name}, dn={denoise_strength}")
    
    def load_model(self):
        """Load Real-ESRGAN model."""
        try:
            from realesrgan import RealESRGANer
            
            logger.info(f"Loading Real-ESRGAN model: {self.model_name}...")
            
            # Check if model is known
            if self.model_name not in AVAILABLE_MODELS:
                logger.warning(f"Unknown model: {self.model_name}")
            
            # Handle scale override for 2x models
            effective_scale = self.scale
            if self.model_name in ['RealESRGAN_x2plus', 'realesrgan-x2plus']:
                effective_scale = 2  # These are fixed 2x models
            
            self._model = RealESRGANer(
                scale=effective_scale,
                model_path=None,
                model=self.model_name,
                device='cuda'
            )
            
            # Apply denoising if specified (for supported models)
            if hasattr(self._model, 'set_denoise_strength'):
                self._model.set_denoise_strength(self.denoise_strength)
                logger.info(f"Denoising strength: {self.denoise_strength}")
            
            logger.info("Model loaded successfully!")
            return True
        except Exception as e:
            logger.error(f"Failed to load model: {e}")
            logger.info("Tip: Model files are downloaded automatically on first run")
            return False
    
    async def upscale_single(self, job_id: int, input_path: str, output_path: str):
        """Upscale a single image."""
        loop = asyncio.get_event_loop()
        
        try:
            # Run in thread pool (GPU work)
            result = await loop.run_in_executor(
                self.executor,
                self._process_image,
                input_path,
                output_path
            )
            return result
        except Exception as e:
            logger.error(f"Error processing {input_path}: {e}")
            return {'success': False, 'error': str(e)}
    
    def _process_image(self, input_path: str, output_path: str) -> dict:
        """Process image (runs in thread pool)."""
        try:
            from PIL import Image
            
            # Load image
            image = Image.open(input_path).convert('RGB')
            logger.info(f"Processing: {os.path.basename(input_path)} ({image.size})")
            
            # Upscale
            output = self._model.predict(image)
            
            # Save output
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            output.save(output_path, 'PNG', quality=95)
            
            output_size = os.path.getsize(output_path) / (1024 * 1024)
            logger.info(f"Completed: {os.path.basename(input_path)} → {output.size}, {output_size:.2f} MB")
            
            return {
                'success': True,
                'output_path': output_path,
                'output_size': output_size
            }
        except Exception as e:
            logger.error(f"Processing error: {e}")
            return {'success': False, 'error': str(e)}
    
    async def worker(self, db_session, ImageJob):
        """Worker process that takes jobs from queue."""
        while True:
            job = await self.queue.get()
            
            try:
                # Update status to processing
                job_obj = db_session.query(ImageJob).get(job['id'])
                if job_obj:
                    job_obj.status = 'processing'
                    job_obj.started_at = datetime.utcnow()
                    db_session.commit()
                
                # Process image
                result = await self.upscale_single(
                    job['id'],
                    job['input_path'],
                    job['output_path']
                )
                
                # Update database
                if db_session.query(ImageJob).get(job['id']):
                    job_obj = db_session.query(ImageJob).get(job['id'])
                    if result['success']:
                        job_obj.status = 'completed'
                        job_obj.progress_percent = 100
                        job_obj.output_path = result['output_path']
                        job_obj.completed_at = datetime.utcnow()
                    else:
                        job_obj.status = 'failed'
                        job_obj.error_message = result['error']
                    db_session.commit()
                
            except Exception as e:
                logger.error(f"Worker error for job {job['id']}: {e}")
                db_session.rollback()
            
            finally:
                with self.processing_lock:
                    self.processing_count -= 1
                self.queue.task_done()
    
    async def run_queue(self, jobs, db_session, ImageJob):
        """Run all jobs from the queue."""
        # Start workers
        workers = []
        for _ in range(self.workers):
            worker_task = asyncio.create_task(self.worker(db_session, ImageJob))
            workers.append(worker_task)
        
        # Add all jobs to queue
        for job in jobs:
            await self.queue.put(job)
            with self.processing_lock:
                self.processing_count += 1
        
        # Wait for all jobs to complete
        await self.queue.join()
        
        # Cancel workers
        for w in workers:
            w.cancel()
        
        logger.info("All jobs completed!")


def scan_images(input_dir: str, output_dir: str, scale: float) -> list:
    """Scan input directory for images and return job list."""
    jobs = []
    supported_extensions = {'.png', '.jpg', '.jpeg', '.jfif', '.bmp', '.tiff', '.webp'}
    
    input_path = Path(input_dir)
    if not input_path.exists():
        logger.error(f"Input directory does not exist: {input_dir}")
        return []
    
    for img_path in input_path.iterdir():
        if img_path.suffix.lower() in supported_extensions:
            filename = img_path.name
            output_filename = f"upscale_{scale}x_{img_path.stem}.png"
            output_path = os.path.join(output_dir, output_filename)
            
            jobs.append({
                'filename': filename,
                'input_path': str(img_path),
                'output_path': output_path,
                'scale_factor': scale
            })
    
    logger.info(f"Found {len(jobs)} images to process")
    return jobs


async def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Comic Upscale - Async Upscaling Engine',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=print_available_models() or ''
    )
    parser.add_argument('--input', '-i', required=True, help='Input directory')
    parser.add_argument('--output', '-o', required=True, help='Output directory')
    parser.add_argument('--scale', '-s', type=float, default=2.5, 
                        help='Scale factor (0.5-4, default: 2.5)')
    parser.add_argument('--workers', '-w', type=int, default=4, 
                        help='Number of worker threads (default: 4)')
    parser.add_argument('--model', '-m', default='RealESRGAN_x4plus_anime', 
                        help='Model name (default: RealESRGAN_x4plus_anime)')
    parser.add_argument('--dn', type=float, default=0.0,
                        help='Denoising strength 0-1 (default: 0, no denoising)')
    parser.add_argument('--db', '-d', default='/workspace/data/db/upscale.db', 
                        help='Database path')
    parser.add_argument('--list-models', action='store_true',
                        help='List available models and exit')
    
    args = parser.parse_args()
    
    if args.list_models:
        print_available_models()
        return
    
    logger.info(f"=== Comic Upscale Started ===")
    logger.info(f"Input: {args.input}")
    logger.info(f"Output: {args.output}")
    logger.info(f"Scale: {args.scale}x")
    logger.info(f"Workers: {args.workers}")
    logger.info(f"Model: {args.model}")
    logger.info(f"Denoising: {args.dn}")
    
    # Import Flask app for database access
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'webui'))
    from webui.app import create_app
    from webui.models import db, ImageJob, init_db
    
    app = create_app()
    
    # Scan images
    jobs = scan_images(args.input, args.output, args.scale)
    
    if not jobs:
        logger.warning("No images found in input directory!")
        return
    
    # Create database jobs
    with app.app_context():
        init_db(app)
        
        # Clear old pending jobs
        ImageJob.query.filter_by(status='pending').delete()
        ImageJob.query.filter_by(status='processing').delete()
        
        # Create new job entries
        db_jobs = []
        for job in jobs:
            db_job = ImageJob(
                filename=job['filename'],
                original_path=job['input_path'],
                output_path=job['output_path'],
                scale_factor=job['scale_factor'],
                status='pending',
                progress_percent=0
            )
            db.session.add(db_job)
            db.session.flush()
            job['id'] = db_job.id
            db_jobs.append(db_job)
        
        db.session.commit()
        logger.info(f"Created {len(db_jobs)} database entries")
        
        # Initialize upscaling engine
        engine = UpscaleEngine(
            scale=args.scale, 
            workers=args.workers, 
            model_name=args.model,
            denoise_strength=args.dn
        )
        
        if not engine.load_model():
            logger.error("Failed to load model, exiting!")
            return
        
        # Start watching for idle
        idle_task = asyncio.create_task(idle_watchdog(engine, args.db))
        
        # Run upscaling
        start_time = time.time()
        await engine.run_queue(jobs, db.session, ImageJob)
        elapsed = time.time() - start_time
        
        # Cancel idle watchdog
        idle_task.cancel()
        
        # Final stats
        completed = ImageJob.query.filter_by(status='completed').count()
        failed = ImageJob.query.filter_by(status='failed').count()
        
        logger.info(f"=== Upscaling Complete ===")
        logger.info(f"Completed: {completed}")
        logger.info(f"Failed: {failed}")
        logger.info(f"Time elapsed: {elapsed:.2f} seconds")
        if len(jobs) > 0:
            logger.info(f"Average time per image: {elapsed/len(jobs):.2f} seconds")


async def idle_watchdog(engine, db_path, idle_threshold: int = 300, gpu_threshold: float = 5.0):
    """
    Watch GPU utilization and stop when idle.
    Args:
        idle_threshold: seconds of low GPU usage before stopping
        gpu_threshold: GPU utilization threshold (percentage)
    """
    logger.info(f"Idle watchdog started (threshold: {idle_threshold}s < {gpu_threshold}% GPU)")
    
    while True:
        await asyncio.sleep(30)  # Check every 30 seconds
        
        # Get GPU utilization
        try:
            import subprocess
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=utilization.gpu', '--format=csv,noheader,nounits'],
                capture_output=True,
                text=True,
                timeout=10
            )
            gpu_percent = float(result.stdout.strip().split('\n')[0])
        except Exception as e:
            logger.warning(f"Could not get GPU stats: {e}")
            continue
        
        queue_empty = engine.queue.empty()
        processing = engine.processing_count
        
        logger.debug(f"GPU: {gpu_percent}%, Queue: {queue_empty}, Processing: {processing}")
        
        if gpu_percent < gpu_threshold and queue_empty and processing == 0:
            logger.info(f"GPU idle detected ({gpu_percent}%), waiting for threshold...")
            await asyncio.sleep(idle_threshold)
            
            # Check again
            try:
                result = subprocess.run(
                    ['nvidia-smi', '--query-gpu=utilization.gpu', '--format=csv,noheader,nounits'],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                gpu_percent = float(result.stdout.strip().split('\n')[0])
            except:
                continue
            
            if gpu_percent < gpu_threshold and engine.queue.empty() and engine.processing_count == 0:
                logger.info("Still idle, initiating shutdown...")
                break
    
    logger.info("Idle watchdog: Shutting down...")


if __name__ == '__main__':
    asyncio.run(main())
