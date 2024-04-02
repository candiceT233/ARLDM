#!/bin/bash
#SBATCH --job-name=flintstones_hdf5-r-100
#SBATCH --partition=slurm
#SBATCH --time=01:30:00
#SBATCH -N 1
#SBATCH --ntasks=10
#SBATCH --ntasks-per-node=10
#SBATCH --output=./R_%x.out
#SBATCH --error=./R_%x.err

hostname; date



export CHUNK_NUM=10
dataset_name="flintstones" # vistsis flintstones pororo
disk="ssd"
# input_path="/qfs/projects/oddite/$USER/ARLDM/input_data"
# output_path="/qfs/projects/oddite/$USER/ARLDM/output_data"
input_path="/mnt/$disk/$USER/ARLDM/input_data"
output_path="/mnt/$disk/$USER/ARLDM/output_data"
mkdir -p $output_path



TEST_NAME="ARLDM_${dataset_name}_${CHUNK_NUM}_${disk}"

## Setup DaYu Tracker
schema_file_path="`pwd`"/$TEST_NAME
mkdir -p $schema_file_path
# clean up the schema files
rm -rf $schema_file_path/*vfd_data_stat.json
rm -rf $schema_file_path/*vol_data_stat.json
TRACKER_PRELOAD_DIR=/mnt/common/$USER/scripts/scspkg/packages/dayu_tracker/lib
TRACKER_VFD_PAGE_SIZE=16384 # 8192 16384 32768 65536 131072 262144 524288 1048576
echo "TRACKER_PRELOAD_DIR : `ls -l $TRACKER_PRELOAD_DIR/*`"
export HDF5_USE_FILE_LOCKING='FALSE'

# set -x
# export HDF5_VOL_CONNECTOR="tracker under_vol=0;under_info={};path=${schema_file_path};level=2;format="
# export HDF5_PLUGIN_PATH="$TRACKER_PRELOAD_DIR/vfd:$TRACKER_PRELOAD_DIR/vol:$HDF5_PLUGIN_PATH"
# export HDF5_DRIVER="hdf5_tracker_vfd"
# export HDF5_DRIVER_CONFIG="${schema_file_path};${TRACKER_VFD_PAGE_SIZE}"
# set +x

LOG_FILE="$schema_file_path/${dataset_name}_hdf5-${CHUNK_NUM}.log"


PREP_TASK_NAME () {
    TASK_NAME=$1
    export CURR_TASK=$TASK_NAME
    export WORKFLOW_NAME="arldm_${dataset_name}"
    export PATH_FOR_TASK_FILES="/tmp/$USER/$WORKFLOW_NAME"
    mkdir -p $PATH_FOR_TASK_FILES
    > $PATH_FOR_TASK_FILES/${WORKFLOW_NAME}_vfd.curr_task # clear the file
    > $PATH_FOR_TASK_FILES/${WORKFLOW_NAME}_vol.curr_task # clear the file

    echo -n "$TASK_NAME" > $PATH_FOR_TASK_FILES/${WORKFLOW_NAME}_vfd.curr_task
    echo -n "$TASK_NAME" > $PATH_FOR_TASK_FILES/${WORKFLOW_NAME}_vol.curr_task
}

SAVE_H5_CONTIG (){
    sudo drop_caches
    


    PREP_TASK_NAME "save_h5"

    # vist_hdf5.py # vist_hdf5_chunk.py
    # flintstones_hdf5.py # flintstones_hdf5_chunk.py

    if [ "$dataset_name" == "vistsis" ]; then

        # HDF5_VOL_CONNECTOR="tracker under_vol=0;under_info={};path=${schema_file_path};level=2;format=" \
        # HDF5_PLUGIN_PATH="$TRACKER_PRELOAD_DIR/vol:$TRACKER_PRELOAD_DIR/vfd:$HDF5_PLUGIN_PATH" \
        # HDF5_DRIVER=hdf5_tracker_vfd \
        # HDF5_DRIVER_CONFIG="${schema_file_path};${TRACKER_VFD_PAGE_SIZE}" \
        python data_script/vist_hdf5.py --sis_json_dir $input_path/vistsis \
            --dii_json_dir $input_path/vistdii \
            --img_dir $input_path/visit_img \
            --save_path $output_path/${dataset_name}_out.h5
    else

        set -x
        HDF5_VOL_CONNECTOR="tracker under_vol=0;under_info={};path=${schema_file_path};level=2;format=" \
        HDF5_PLUGIN_PATH="$TRACKER_PRELOAD_DIR/vol:$TRACKER_PRELOAD_DIR/vfd:$HDF5_PLUGIN_PATH" \
        HDF5_DRIVER=hdf5_tracker_vfd \
        HDF5_DRIVER_CONFIG="${schema_file_path};${TRACKER_VFD_PAGE_SIZE}" \
        python data_script/${dataset_name}_hdf5.py --data_dir $input_path/${dataset_name} \
            --save_path $output_path/${dataset_name}_out.h5
        set +x
    fi
}

SAVE_H5_CHUNK (){

    PREP_TASK_NAME "save_h5_chunked"

    # vist_hdf5.py # vist_hdf5_chunk.py
    # flintstones_hdf5.py # flintstones_hdf5_chunk.py

    if [ "$dataset_name" == "vistsis" ]; then

        # HDF5_VOL_CONNECTOR="tracker under_vol=0;under_info={};path=$schema_file_path;level=2;format=" \
        # HDF5_PLUGIN_PATH="$TRACKER_PRELOAD_DIR/vol:$TRACKER_PRELOAD_DIR/vfd" \
        # HDF5_DRIVER=hdf5_tracker_vfd \
        # HDF5_DRIVER_CONFIG="${schema_file_path};${TRACKER_VFD_PAGE_SIZE}" \
        python data_script/vist_hdf5_chunk.py --sis_json_dir $input_path/vistsis \
            --dii_json_dir $input_path/vistdii \
            --img_dir $input_path/visit_img \
            --save_path $output_path/${dataset_name}_out_chunked.h5
    else

        set -x
        HDF5_VOL_CONNECTOR="tracker under_vol=0;under_info={};path=$schema_file_path;level=2;format=" \
        HDF5_PLUGIN_PATH="$TRACKER_PRELOAD_DIR/vol:$TRACKER_PRELOAD_DIR/vfd" \
        HDF5_DRIVER=hdf5_tracker_vfd \
        HDF5_DRIVER_CONFIG="${schema_file_path};${TRACKER_VFD_PAGE_SIZE}" \
        python data_script/${dataset_name}_hdf5_chunk.py \
            --data_dir $input_path/${dataset_name} \
            --save_path $output_path/${dataset_name}_out_chunked.h5
        set +x
    fi
}


LOAD_DATA () {
    sudo /sbin/sysctl vm.drop_caches=3
    python main.py
    echo -e "\nLoad data done...\n"
}

echo "Chunk Num: $CHUNK_NUM"

eval "$(~/miniconda3/bin/conda shell.bash hook)" # conda init bash
source activate arldm_copy

# Clean up
rm -rf $output_path/${dataset_name}_out.h5
rm -rf $output_path/${dataset_name}_out_chunked.h5
sudo drop_caches

start_time=$SECONDS
SAVE_H5_CONTIG 2>&1 | tee $LOG_FILE
wait
duration=$(($SECONDS - $start_time))
echo "SAVE_H5_CONTIG done... $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)." | tee -a $LOG_FILE

sudo drop_caches
start_time=$SECONDS
SAVE_H5_CHUNK 2>&1 | tee -a $LOG_FILE
duration=$(($SECONDS - $start_time))
echo "SAVE_H5_CHUNK done... $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed ($duration secs)." | tee -a $LOG_FILE

# LOAD_DATA

total_duration=$(($SECONDS - $start_time))
echo "All done... $(($total_duration / 60)) minutes and $(($total_duration % 60)) seconds elapsed ($total_duration secs)." | tee -a $LOG_FILE

hostname; date