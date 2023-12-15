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

set -x

export CHUNK_NUM=100

LOG_FILE="./flintstones_hdf5-$CHUNK_NUM.log"

echo "Chunk Num: $CHUNK_NUM"
source activate arldm

SAVE_H5 (){
    sudo /sbin/sysctl vm.drop_caches=3
    
    rm -rf /qfs/projects/oddite/tang584/ARLDM/output_data/flintstones_out.h5

    python data_script/flintstones_hdf5.py \
        --data_dir /qfs/projects/oddite/tang584/ARLDM/input_data/flintstones_data \
        --save_path /qfs/projects/oddite/tang584/ARLDM/output_data/flintstones_out.h5
    echo -e "\nPreprocessing done...\n"
}


LOAD_DATA () {
    sudo /sbin/sysctl vm.drop_caches=3
    python main.py
    echo -e "\nLoad data done...\n"
}

SAVE_H5

LOAD_DATA

hostname; date