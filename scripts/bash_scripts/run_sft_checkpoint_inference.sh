#!/bin/bash

# Script to run inference for all SFT checkpoints on all tasks
# Processes all checkpoints for each task with GPU resource management
# Author: MindCube Team
# Usage: bash scripts/bash_scripts/run_sft_checkpoint_inference.sh

echo "🚀 Starting SFT checkpoint inference for all tasks..."
echo "📅 Start time: $(date)"

# Configuration
MODEL_TYPE="qwen2.5vl"
INPUT_DIR="./data/prompts/general"
OUTPUT_DIR="./data/results/sft"
LOG_DIR="./logs/sft_inference"
CHECKPOINT_BASE_DIR="./checkpoints/sft"
MAX_CONCURRENT_TASKS=2  # Maximum 2 tasks per GPU

# All tasks (based on available data)
TASKS=(
    "raw_qa"
    "aug_cgmap_out"
    "plain_cgmap_out"
    "ff_rsn"
    "aug_cgmap_ffr_out"
)

# Create necessary directories
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${LOG_DIR}"

echo "📁 Input directory: ${INPUT_DIR}"
echo "📁 Output directory: ${OUTPUT_DIR}"
echo "📁 Log directory: ${LOG_DIR}"
echo "📁 Checkpoint base directory: ${CHECKPOINT_BASE_DIR}"
echo "🎯 Model type: ${MODEL_TYPE}"
echo "📋 Tasks to process: ${#TASKS[@]} tasks"
echo "🔧 Max concurrent tasks: ${MAX_CONCURRENT_TASKS}"

# Display task list
for task in "${TASKS[@]}"; do
    echo "  - ${task}"
done

echo ""

# Function to get running inference jobs count
get_running_jobs() {
    ps aux | grep "scripts/run_inference.py" | grep -v grep | wc -l
}

# Function to wait for available GPU slot
wait_for_gpu_slot() {
    while [ $(get_running_jobs) -ge ${MAX_CONCURRENT_TASKS} ]; do
        echo "⏳ Maximum concurrent tasks (${MAX_CONCURRENT_TASKS}) reached. Waiting for available slot..."
        sleep 30
    done
}

# Function to run inference for a single checkpoint
run_checkpoint_inference() {
    local task_name=$1
    local checkpoint_path=$2
    local checkpoint_id=$3
    local gpu_id=$4
    
    local input_file="${INPUT_DIR}/MindCube_tinybench_${task_name}.jsonl"
    local output_subdir="${OUTPUT_DIR}/${task_name}"
    local log_file="${LOG_DIR}/inference_${task_name}_${checkpoint_id}_gpu${gpu_id}.log"
    
    # Create task-specific output directory
    mkdir -p "${output_subdir}"
    
    echo "🔧 [GPU ${gpu_id}] Starting inference for ${task_name} checkpoint-${checkpoint_id}"
    echo "📝 [GPU ${gpu_id}] Input file: ${input_file}"
    echo "📋 [GPU ${gpu_id}] Checkpoint: ${checkpoint_path}"
    echo "📤 [GPU ${gpu_id}] Output directory: ${output_subdir}"
    echo "📋 [GPU ${gpu_id}] Log file: ${log_file}"
    
    # Check if input file exists
    if [ ! -f "${input_file}" ]; then
        echo "❌ [GPU ${gpu_id}] Error: Input file not found: ${input_file}"
        return 1
    fi
    
    # Check if checkpoint exists
    if [ ! -d "${checkpoint_path}" ]; then
        echo "❌ [GPU ${gpu_id}] Error: Checkpoint not found: ${checkpoint_path}"
        return 1
    fi
    
    # Run inference with nohup in background
    nohup env CUDA_VISIBLE_DEVICES=${gpu_id} python scripts/run_inference.py \
        --model-type "${MODEL_TYPE}" \
        --model-path "${checkpoint_path}" \
        --input-file "${input_file}" \
        --output-dir "${output_subdir}" \
        > "${log_file}" 2>&1 &
    
    local pid=$!
    echo "✅ [GPU ${gpu_id}] Task ${task_name}_${checkpoint_id} started with PID: ${pid}"
    
    # Save PID for monitoring
    echo "${pid}" > "${LOG_DIR}/pid_${task_name}_${checkpoint_id}_gpu${gpu_id}.txt"
    
    return 0
}

# Function to get available GPU
get_available_gpu() {
    # Simple round-robin assignment based on current job count
    local job_count=$(get_running_jobs)
    echo $((job_count % 4))  # Assuming 4 GPUs available (0-3)
}

# Main processing loop
echo "🎬 Starting checkpoint inference for all tasks..."
echo ""

total_jobs=0
successful_jobs=0
failed_jobs=0

for task in "${TASKS[@]}"; do
    echo "📋 Processing task: ${task}"
    
    task_checkpoint_dir="${CHECKPOINT_BASE_DIR}/${task}"
    
    # Check if task checkpoint directory exists
    if [ ! -d "${task_checkpoint_dir}" ]; then
        echo "⚠️  Warning: No checkpoints found for task ${task} at ${task_checkpoint_dir}"
        continue
    fi
    
    # Find all checkpoint directories for this task
    checkpoints=($(find "${task_checkpoint_dir}" -name "checkpoint-*" -type d | sort -V))
    
    if [ ${#checkpoints[@]} -eq 0 ]; then
        echo "⚠️  Warning: No checkpoint-* directories found for task ${task}"
        continue
    fi
    
    echo "📁 Found ${#checkpoints[@]} checkpoints for task ${task}:"
    for ckpt in "${checkpoints[@]}"; do
        echo "  - $(basename ${ckpt})"
    done
    
    # Process each checkpoint
    for checkpoint_path in "${checkpoints[@]}"; do
        checkpoint_id=$(basename "${checkpoint_path}" | sed 's/checkpoint-//')
        
        # Wait for available GPU slot
        wait_for_gpu_slot
        
        # Get available GPU
        gpu_id=$(get_available_gpu)
        
        # Run inference for this checkpoint
        if run_checkpoint_inference "${task}" "${checkpoint_path}" "${checkpoint_id}" "${gpu_id}"; then
            ((successful_jobs++))
        else
            ((failed_jobs++))
        fi
        
        ((total_jobs++))
        
        # Small delay between job starts to avoid resource conflicts
        sleep 5
    done
    
    echo "✅ All checkpoints for task ${task} have been queued"
    echo ""
done

echo "🎯 All checkpoint inference jobs have been launched!"
echo "📊 Summary:"
echo "  - Total jobs launched: ${total_jobs}"
echo "  - Successful launches: ${successful_jobs}"
echo "  - Failed launches: ${failed_jobs}"
echo "  - Max concurrent tasks: ${MAX_CONCURRENT_TASKS}"
echo "  - Tasks processed: ${#TASKS[@]}"
echo "  - Input directory: ${INPUT_DIR}"
echo "  - Output directory: ${OUTPUT_DIR}"
echo "  - Log directory: ${LOG_DIR}"

echo ""
echo "📋 To monitor progress:"
echo "  # Check running processes:"
echo "  ps aux | grep run_inference.py"
echo ""
echo "  # Check total running jobs:"
echo "  ps aux | grep run_inference.py | grep -v grep | wc -l"
echo ""
echo "  # Check logs for specific task and checkpoint:"
echo "  tail -f ${LOG_DIR}/inference_<task_name>_<checkpoint_id>_gpu<gpu_id>.log"
echo ""
echo "  # Example: Check raw_qa checkpoint-5 log:"
echo "  tail -f ${LOG_DIR}/inference_raw_qa_5_gpu*.log"

echo ""
echo "📈 To check completion status:"
echo "  # Count completed results by task:"
echo "  for task in ${TASKS[@]}; do"
echo "    echo \"Task \$task: \$(ls ${OUTPUT_DIR}/\$task/*_responses.jsonl 2>/dev/null | wc -l) completed\""
echo "  done"
echo ""
echo "  # List all completed output files:"
echo "  find ${OUTPUT_DIR} -name '*_responses.jsonl' | sort"

echo ""
echo "🔍 To check specific task results:"
echo "  ls -la ${OUTPUT_DIR}/<task_name>/"
echo ""
echo "  # Example for raw_qa:"
echo "  ls -la ${OUTPUT_DIR}/raw_qa/"

echo ""
echo "⏰ Script started at: $(date)"
echo "🔄 All jobs are now running in background with nohup..."
echo "✅ Script execution completed. Check logs for progress updates."

# Optional: Create a monitoring script
cat > "${LOG_DIR}/monitor_progress.sh" << 'EOF'
#!/bin/bash
echo "📊 SFT Checkpoint Inference Progress Monitor"
echo "⏰ $(date)"
echo ""

echo "🔄 Currently running jobs:"
running_jobs=$(ps aux | grep "scripts/run_inference.py" | grep -v grep | wc -l)
echo "  Active inference processes: ${running_jobs}"

if [ ${running_jobs} -gt 0 ]; then
    echo ""
    echo "📋 Running processes:"
    ps aux | grep "scripts/run_inference.py" | grep -v grep | awk '{print "  PID: " $2 ", GPU: " $12 ", Started: " $9}'
fi

echo ""
echo "📈 Completion status by task:"
for task in raw_qa aug_cgmap_out plain_cgmap_out ff_rsn aug_cgmap_ffr_out; do
    completed=$(ls ./data/results/sft/${task}/*_responses.jsonl 2>/dev/null | wc -l)
    total_checkpoints=$(find ./checkpoints/sft/${task} -name "checkpoint-*" -type d 2>/dev/null | wc -l)
    echo "  ${task}: ${completed}/${total_checkpoints} checkpoints completed"
done

echo ""
echo "📁 Recent output files (last 10):"
find ./data/results/sft -name '*_responses.jsonl' -exec ls -lt {} + | head -10

EOF

chmod +x "${LOG_DIR}/monitor_progress.sh"
echo "📊 Created progress monitor script: ${LOG_DIR}/monitor_progress.sh"
echo "   Run: bash ${LOG_DIR}/monitor_progress.sh" 