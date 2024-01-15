#!/bin/bash
#SBATCH --job-name=tracker_flintstones_train
#SBATCH --nodelist=ares-comp-25
#SBATCH --time=00:30:00
#SBATCH -N 1
#SBATCH --ntasks-per-node=20
#SBATCH --output=./%x_R.out
#SBATCH --error=./%x_R.err
#SBATCH --exclusive



set -x

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
FS_PREFIX="/mnt/common/$USER/experiments" # NFS
# FS_PREFIX="/rcfs/projects/chess/$USER" # PFS
EXPERIMENT_PATH="$FS_PREFIX/ARLDM"
ARLDM_SCRIPTS="$HOME/scripts/hdf5_workflow/ARLDM"
mkdir -p $EXPERIMENT_PATH

# Config file variables
TEST_MODE="train" # train sample
CKPT_DIR="$FS_PREFIX/ARLDM/save_ckpt"
DATASET="vistdii" # pororo flintstones vistsis vistdii
WORKERS=1
# JOB_NAME=$(echo `scontrol show job $SLURM_JOB_ID | grep JobName` | grep -oP 'JobName=\K.*')
JOB_NAME="${DATASET}_train"
echo "Job Name: $JOB_NAME"
# # check if JOB_NAMe is empty
# if [ -z "$JOB_NAME" ]; then
#     JOB_NAME="tracker_flintstones_train"
# fi


TEST_NAME="$JOB_NAME"
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
    echo "Prepared config file: $config_file"

}

RUN_TRAIN () {

    echo "Running training ..."



    export WORKFLOW_NAME="arldm_test"
    export PATH_FOR_TASK_FILES="/tmp/$USER/$WORKFLOW_NAME"

    schema_file=data-stat-dl.yaml
    rm -rf ./*vfd-${schema_file}*
    rm -rf ./*vol-${schema_file}*
    TRACKER_VFD_PAGE_SIZE=65536

    echo "TRACKER_VFD_DIR = $TRACKER_SRC_DIR/vfd"
    
    # HDF5_VOL_CONNECTOR="under_vol=0;under_info={};path=${schema_file}" \

    

    # ## VOL
    # TRACKER_SRC_DIR=/mnt/common/mtang11/scripts/vol-tracker/build/src
    # VOL_NAME="tracker"
    # export HDF5_USE_FILE_LOCKING='FALSE' # TRUE FALSE BESTEFFORT
    # export HDF5_VOL_CONNECTOR="${VOL_NAME} under_vol=0;under_info={};path=${schema_file};level=2;format="
    # export HDF5_PLUGIN_PATH=$TRACKER_SRC_DIR/vol:$HDF5_PLUGIN_PATH
    # export HDF5_PLUGIN_PATH=$TRACKER_SRC_DIR/vfd:$TRACKER_SRC_DIR/vol:$HDF5_PLUGIN_PATH


    export HYDRA_FULL_ERROR=1

    echo cd $ARLDM_SCRIPTS
    cd $ARLDM_SCRIPTS


    # srun -n1 --oversubscribe python main.py &> "$ARLDM_SCRIPTS/$JOB_NAME.log"
    # conda run -v -n arldm python main.py
    conda run -n arldm python main.py 

    echo "python main.py has exited"
}


hostname; date

# srun -n$SLURM_JOB_NUM_NODES -w $hostlist --oversubscribe sudo /sbin/sysctl vm.drop_caches=3

# eval "$(conda shell.bash hook)"

# source activate arldm
source ./load_tracker_deps.sh

# srun -n1 -N1 $( MON_MEM ) &
# source ./load_hermes_deps.sh
# source ./env_var.sh

PREPARE_CONFIGS

start_time=$(($(date +%s%N)/1000000))

RUN_TRAIN 2>&1 | tee "$ARLDM_SCRIPTS/$JOB_NAME.log"

duration=$(( $(date +%s%N)/1000000 - $start_time))
echo "TRAINING done... $duration milliseconds elapsed." | tee -a "$ARLDM_SCRIPTS/$JOB_NAME.log"

hostname; date | tee -a "$ARLDM_SCRIPTS/$JOB_NAME.log"
sacct -j $SLURM_JOB_ID --format="JobID,JobName,Partition,CPUTime,AllocCPUS,State,ExitCode,MaxRSS,MaxVMSize"

# echo ""
# ls -l $EXPERIMENT_PATH/*/*

# https://github.com/huggingface/accelerate/issues/1489