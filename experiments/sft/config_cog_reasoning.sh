#!/bin/bash

# ==============================================================================
# Cognitive Reasoning Task Configuration
# Configuration for cognitive reasoning fine-tuning task
# ==============================================================================

# Task-specific configuration
TASK_NAME="cog_reasoning"
DATASET_NAME="cog_reasoning"

# Model configuration
MODEL_NAME="Qwen/Qwen2.5-VL-3B-Instruct"

# Training hyperparameters
LEARNING_RATE=1e-5
NUM_EPOCHS=3

# Output configuration
OUTPUT_BASE_DIR="experiments/sft/results"
RUN_NAME="qwen2vl-${TASK_NAME}_sft"

# Additional training arguments
MAX_PIXELS=90000
MIN_PIXELS=784
MODEL_MAX_LENGTH=8192
SAVE_STEPS=5
SAVE_TOTAL_LIMIT=12

echo "Task configuration loaded: ${TASK_NAME}"

# ==============================================================================
# Task Description:
# ==============================================================================
# Cognitive Reasoning task focuses on developing structured reasoning
# capabilities for visual understanding. This is a legacy task configuration
# that may be replaced by more specific cognitive mapping tasks.
# ============================================================================== 