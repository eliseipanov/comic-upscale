#!/bin/bash
# download_ready.sh - Download upscaled results from server as archive
# Creates tar.gz on server, downloads one file
# Usage: ./download_ready.sh [--clear-old]
# Options:
#   --clear-old    After download, prompt to clear remote data (requires YES confirmation)

set -e

# Source config
source config.sh

# Parse arguments
CLEAR_OLD=false
for arg in "$@"; do
    case $arg in
        --clear-old)
            CLEAR_OLD=true
            shift
            ;;
    esac
done

# Create local results directory with timestamp
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
LOCAL_RESULTS_DIR="results/${TIMESTAMP}"
LOCAL_ARCHIVE="${LOCAL_RESULTS_DIR}.tar.gz"
mkdir -p "results"

echo "============================================== Download Upscaled Images =============================================="
echo ""
echo "Server: $REMOTE_USER@$REMOTE_IP:$SSH_PORT"
echo "Output: $OUTPUT_DIR"
echo ""

# Create tar.gz archive on server
echo "Creating archive on server..."
ssh -o StrictHostKeyChecking=no -p $SSH_PORT "$REMOTE_USER@$REMOTE_IP" "cd $(dirname $OUTPUT_DIR) && tar -czf outputs.tar.gz -C $(basename $OUTPUT_DIR) ."
ARCHIVE_SIZE=$(ssh -o StrictHostKeyChecking=no -p $SSH_PORT "$REMOTE_USER@$REMOTE_IP" "du -h $OUTPUT_DIR/../outputs.tar.gz | cut -f1")
echo "Archive created: $ARCHIVE_SIZE"

# Download the archive
echo ""
echo "Downloading archive..."
scp -o StrictHostKeyChecking=no -P $SSH_PORT "$REMOTE_USER@$REMOTE_IP:$OUTPUT_DIR/../outputs.tar.gz" "$LOCAL_ARCHIVE"

# Extract archive
echo ""
echo "Extracting to $LOCAL_RESULTS_DIR..."
mkdir -p "$LOCAL_RESULTS_DIR"
tar -xzf "$LOCAL_ARCHIVE" -C "$LOCAL_RESULTS_DIR"

# Remove server archive
ssh -o StrictHostKeyChecking=no -p $SSH_PORT "$REMOTE_USER@$REMOTE_IP" "rm $OUTPUT_DIR/../outputs.tar.gz"

# Count files
COUNT=$(find "$LOCAL_RESULTS_DIR" -name "*.png" -type f | wc -l)
TOTAL_SIZE=$(du -sh "$LOCAL_RESULTS_DIR" | cut -f1)

echo ""
echo "============================================== Download Complete =============================================="
echo ""
echo "Extracted: $COUNT images"
echo "Total size: $TOTAL_SIZE"
echo "Location: $LOCAL_RESULTS_DIR"
echo ""
echo "Archive: $LOCAL_ARCHIVE (can be deleted)"

# Clear old data option
if [ "$CLEAR_OLD" = true ]; then
    echo ""
    echo "============================================== Clear Remote Data =============================================="
    echo ""
    echo "This will DELETE from server:"
    echo "  - Completed output files in: $OUTPUT_DIR"
    echo "  - Completed job entries from database"
    echo ""
    echo "PRESERVED:"
    echo "  - Directories (input/, output/, db/)"
    echo "  - Pending/processing jobs"
    echo ""
    echo "Type 'YES' to confirm clearing COMPLETED jobs only:"
    read -r CONFIRM
    
    if [ "$CONFIRM" = "YES" ]; then
        # Create remote cleanup script
        REMOTE_SCRIPT="/tmp/clear_completed_$$.sh"
        
        cat > "$REMOTE_SCRIPT" << 'REMOTE_EOF'
#!/bin/bash
cd /workspace
/workspace/venv/main/bin/python -c "
import os
from webui.app import create_app
from webui.models import db, ImageJob

app = create_app()
with app.app_context():
    # Get completed jobs
    jobs = ImageJob.query.filter_by(status='completed').all()
    count = len(jobs)
    
    # Remove output files
    for job in jobs:
        if job.output_path and os.path.exists(job.output_path):
            os.remove(job.output_path)
            print(f'Removed: {os.path.basename(job.output_path)}')
    
    # Delete from database
    for job in jobs:
        db.session.delete(job)
    db.session.commit()
    
    print(f'Deleted {count} completed jobs from database')
"
REMOTE_EOF
        
        echo ""
        echo "Clearing completed jobs from server..."
        
        COMPLETED_COUNT=$(ssh -o StrictHostKeyChecking=no -p $SSH_PORT "$REMOTE_USER@$REMOTE_IP" \
            "chmod +x /tmp/clear_completed_$$.sh && bash /tmp/clear_completed_$$.sh")
        
        rm -f "$REMOTE_SCRIPT"
        
        echo "  ✓ Cleared $COMPLETED_COUNT completed jobs"
        echo "  ✓ Removed output files"
        echo ""
        echo "Server ready for new batch!"
    else
        echo ""
        echo "Clear cancelled. All data preserved."
    fi
fi

echo ""
echo "Done!"
