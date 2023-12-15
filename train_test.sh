#!/bin/bash
#SBATCH --job-name=base_flintstones_train
#SBATCH --partition=short
#SBATCH --time=01:30:00
#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --output=./base_%x_R.out
#SBATCH --error=./base_%x_R.err

# -p a100_80_shared
# --mem=0
# --gres=gpu:8 -gres=gpu:1
# --account=chess

JOB_NAME=$(echo `scontrol show job $SLURM_JOB_ID | grep JobName` | grep -oP 'JobName=\K.*')
echo "Job Name: $JOB_NAME"

echo -e "network devices on node:\n $(ucx_info -d | grep Device)"

killall python

source activate arldm

module load cuda/10.0.130
# module load cuda/11.7 #cuda/10.0.130
export NCCL_DEBUG=INFO # debugging flags (optional)
export NCCL_IGNORE_DISABLED_P2P=1
export PL_TORCH_DISTRIBUTED_BACKEND=nccl
# export MASTER_ADDR=localhost
# echo "MASTER_ADDR: $MASTER_ADDR"

# export PYTHONFAULTHANDLER=1
export NCCL_P2P_DISABLE=1
# export NCCL_P2P_LEVEL=SYS
# export OMP_NUM_THREADS=1
# nvidia-smi

# export fine_use_gpu=True
# export NCCL_SOCKET_IFNAME="ib1"
# a100 enp226s0 ib1
# dlt enp1s0f0 ib0

export HYDRA_FULL_ERROR=1
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:256,garbage_collection_threshold:0.5
SCRIPT_DIR=/people/tang584/scripts/vlen_workflow/ARLDM

hostname; date

echo cd $SCRIPT_DIR
cd $SCRIPT_DIR



# python -m torch.distributed.launch --nproc_per_node=$SLURM_NTASKS main.py --rdzv-backend=c10d --rdzv-endpoint=localhost:0 &> "$SCRIPT_DIR/$JOB_NAME.log"
# torchrun --nproc_per_node=$SLURM_NTASKS main.py &> "$SCRIPT_DIR/$JOB_NAME.log"
# PYTORCH_CUDA_ALLOC_CONF=garbage_collection_threshold:0.5,max_split_size_mb:512 \

# Start the first program in the background
# PYTORCH_CUDA_ALLOC_CONF=garbage_collection_threshold:0.6,max_split_size_mb:512 srun --ntasks=$SLURM_NTASKS --exclusive python main.py &> "$SCRIPT_DIR/$JOB_NAME.log"


# srun python main_fp16.py &> "$SCRIPT_DIR/$JOB_NAME.log"

start_time=$(($(date +%s%N)/1000000))

srun python main.py &> "$SCRIPT_DIR/$JOB_NAME.log"

duration=$(( $(date +%s%N)/1000000 - $start_time))
echo "TRAINING done... $duration milliseconds elapsed."

# Run the second command (nvidia-smi)
echo "python main.py has exited"
nvidia-smi

hostname; date
sacct -j $SLURM_JOB_ID -o jobid,submit,start,end,state

# https://github.com/huggingface/accelerate/issues/1489