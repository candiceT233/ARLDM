#!/bin/bash
#SBATCH --job-name=flintstones_train
#SBATCH --partition=short
#SBATCH --time=00:30:00
#SBATCH -N 1
#SBATCH --ntasks-per-node=2
#SBATCH --output=./%x_R.out
#SBATCH --error=./%x_R.err

# -p a100_80_shared
# --mem=0
# --gres=gpu:8 -gres=gpu:1
# --account=chess

JOB_NAME=$(echo `scontrol show job $SLURM_JOB_ID | grep JobName` | grep -oP 'JobName=\K.*')
# JOB_NAME="flintstones_train"
echo "Job Name: $JOB_NAME"
# echo -e "network devices on node:\n $(ucx_info -d | grep Device)"

## Prepare Slurm Host Names and IPs
NODE_NAMES=`echo $SLURM_JOB_NODELIST|scontrol show hostnames`

hostlist=$(echo "$NODE_NAMES" | tr '\n' ',')
echo "hostlist: $hostlist"

rm -rf ./host_ip
touch ./host_ip
host_arr=()
for node in $NODE_NAMES
do
    host_arr+=("$node")
    nost_ip=`getent hosts "$node.ibnet" | awk '{ print $1 }'`
    echo "$nost_ip" >> ./host_ip
done

cat ./host_ip
ib_hostlist=$(cat ./host_ip | xargs | sed -e 's/ /,/g')
echo "ib_hostlist: $ib_hostlist"


# Base path variables
FS_PREFIX="/qfs/projects/oddite/$USER" # NFS
# FS_PREFIX="/rcfs/projects/chess/$USER" # PFS
EXPERIMENT_PATH="$FS_PREFIX/ARLDM/output_data"
ARLDM_SCRIPTS="$HOME/scripts/vlen_workflow/ARLDM"
mkdir -p $EXPERIMENT_PATH

# Config file variables
TEST_MODE="train" # train sample
CKPT_DIR="$FS_PREFIX/ARLDM/save_ckpt"
TEST_NAME="$JOB_NAME"
DATASET="flintstones" # pororo flintstones vistsis vistdii
SAMPLE_OUT_DIR="$EXPERIMENT_PATH/sample_out_$TEST_NAME"
mkdir -p $SAMPLE_OUT_DIR
mkdir -p $CKPT_DIR

# Config files
config_template="$ARLDM_SCRIPTS/config_template.yaml"
config_file="$ARLDM_SCRIPTS/config.yaml"

PREPARE_CONFIGS () {

    sed 's#MODE#'"${TEST_MODE}"'#g;s#CKPT_DIR#'"${CKPT_DIR}"'#g;s#TEST_NAME#'"${TEST_NAME}"'#g' "${config_template}" > "${config_file}"

    # Compare the dataset variable with different values
    if [ "$DATASET" == "flintstones" ]; then
        echo "The dataset is Flintstones."
        HDF5_NAME="$FS_PREFIX/ARLDM/output_data/flintstones_out.h5"
        DSET_VAR="FLINTSTONES_HDF5"

    elif [ "$DATASET" == "pororo" ]; then
        echo "The dataset is Pororo."
        HDF5_NAME="$FS_PREFIX/ARLDM/output_data/pororo_out.h5"
        DSET_VAR="PORORO_HDF5"

    elif [ "$DATASET" == "vistsis" ]; then
        echo "The dataset is Vistsis."
        HDF5_NAME="$FS_PREFIX/ARLDM/output_data/vistsis_out.h5"
        DSET_VAR="VISTSIS_HDF5"

    elif [ "$DATASET" == "vistdii" ]; then
        echo "The dataset is Vistdii."
        HDF5_NAME="$FS_PREFIX/ARLDM/output_data/vistsis_out.h5"
        DSET_VAR="VISTDII_HDF5"
    else
        echo "Unknown dataset."
        exit 1
    fi

    # sed -i 's#WORKERS#'${SLURM_NTASKS}#'g' "${config_file}"
    sed -i 's#WORKERS#1#g' "${config_file}"
    sed -i 's#DATASET#'${DATASET}#'g' "${config_file}"
    sed -i 's#'${DSET_VAR}'#'${HDF5_NAME}'#g' "${config_file}"
    sed -i 's#SAMPLE_OUT_DIR#'${SAMPLE_OUT_DIR}'#g' "${config_file}"

}

RUN_TRAIN () {

    echo "Running training ..."

    # # GPU variables
    # # a100 enp226s0 ib1
    # # dlt enp1s0f0 ib0

    # module load cuda/10.0.130 # module load cuda/11.7 #cuda/10.0.130
    # export NCCL_DEBUG=INFO # debugging flags (optional)
    # export NCCL_IGNORE_DISABLED_P2P=1
    # export PL_TORCH_DISTRIBUTED_BACKEND=nccl
    # export PYTHONFAULTHANDLER=1
    # export NCCL_P2P_DISABLE=1
    # export NCCL_P2P_LEVEL=SYS
    # export OMP_NUM_THREADS=1
    # export fine_use_gpu=True
    # export NCCL_SOCKET_IFNAME="ib1"
    # export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:256,garbage_collection_threshold:0.5
    # nvidia-smi

    export HYDRA_FULL_ERROR=1

    echo cd $ARLDM_SCRIPTS
    cd $ARLDM_SCRIPTS


    srun -n1 --oversubscribe python main.py &> "$ARLDM_SCRIPTS/$JOB_NAME.log"

    echo "python main.py has exited"
}


hostname; date

srun -n$SLURM_JOB_NUM_NODES -w $hostlist --oversubscribe sudo /sbin/sysctl vm.drop_caches=3

source activate arldm

# srun -n1 -N1 $( MON_MEM ) &
# source ./load_hermes_deps.sh
# source ./env_var.sh

PREPARE_CONFIGS

start_time=$(($(date +%s%N)/1000000))

RUN_TRAIN

duration=$(( $(date +%s%N)/1000000 - $start_time))
echo "TRAINING done... $duration milliseconds elapsed."

hostname; date
sacct -j $SLURM_JOB_ID --format="JobID,JobName,Partition,CPUTime,AllocCPUS,State,ExitCode,MaxRSS,MaxVMSize"

# echo ""
# ls -l $EXPERIMENT_PATH/*/*

# https://github.com/huggingface/accelerate/issues/1489