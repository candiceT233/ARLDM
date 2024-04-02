import argparse
import json
import os
import pickle

import cv2
import h5py
import numpy as np
from tqdm import tqdm

import time

import os
def get_chunk_shape():
    chunk_shape = os.getenv("CHUNK_NUM")
    if chunk_shape == None:
        print("CHUNK_NUM is not a valid integer, set to Auto")
        chunk_shape = True
    else:
        # chunk_shape = (int(chunk_shape),)
        # chunk_shape = (1,int(chunk_shape))
        chunk_shape = int(chunk_shape)
    
    print("Chunk shape:", chunk_shape)
    return chunk_shape

def main(args):
    splits = json.load(open(os.path.join(args.data_dir, 'train-val-test_split.json'), 'r'))
    train_ids, val_ids, test_ids = splits["train"], splits["val"], splits["test"]
    followings = pickle.load(open(os.path.join(args.data_dir, 'following_cache4.pkl'), 'rb'))
    annotations = json.load(open(os.path.join(args.data_dir, 'flintstones_annotations_v1-0.json')))
    descriptions = dict()
    for sample in annotations:
        descriptions[sample["globalID"]] = sample["description"]

    # Shorten train_ids, val_ids, and test_ids for testing purposes
    train_ids = train_ids[:4000]
    val_ids = val_ids[:400]
    test_ids = test_ids[:400]
    
    # Get the current time in seconds since the epoch (January 1, 1970)
    start_time_seconds = time.time()
    
    f = h5py.File(args.save_path, "w")
    for subset, ids in {'train': train_ids, 'val': val_ids, 'test': test_ids}.items():
        ids = [i for i in ids if i in followings and len(followings[i]) == 4]
        length = len(ids)

        group = f.create_group(subset)
        images = list()
        for i in range(5):
            # images.append(group.create_dataset('image{}'.format(i), (length,), dtype=h5py.vlen_dtype(np.dtype('uint8'))))
            images.append(group.create_dataset('image{}'.format(i), (length,), dtype=h5py.vlen_dtype(np.dtype('uint8')), chunks=get_chunk_shape()))
        text = group.create_dataset('text', (length,), dtype=h5py.string_dtype(encoding='utf-8'))
        for i, item in enumerate(tqdm(ids, leave=True, desc="saveh5")):
            globalIDs = [item] + followings[item]
            txt = list()
            for j, globalID in enumerate(globalIDs):
                img = np.load(os.path.join(args.data_dir, 'video_frames_sampled', '{}.npy'.format(globalID)))
                img = np.concatenate(img, axis=0).astype(np.uint8)
                img = cv2.imencode('.png', img)[1].tobytes()
                img = np.frombuffer(img, np.uint8)
                images[j][i] = img
                txt.append(descriptions[globalID])
            text[i] = '|'.join([t.replace('\n', '').replace('\t', '').strip() for t in txt])
    f.close()
    
    end_time_seconds = time.time()
    print("Start time:", start_time_seconds)
    print("End time:", end_time_seconds)
    # Calculate the time difference
    time_elapsed = end_time_seconds - start_time_seconds
    # Calculate minutes and seconds from the time difference
    minutes_elapsed = int(time_elapsed // 60)
    seconds_elapsed = int(time_elapsed % 60)
    print(f"Time elapsed: {time_elapsed:.2f} seconds ({minutes_elapsed} minutes and {seconds_elapsed} seconds)")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='arguments for flintstones hdf5 file saving')
    parser.add_argument('--data_dir', type=str, required=True, help='flintstones data directory')
    parser.add_argument('--save_path', type=str, required=True, help='path to save hdf5')
    args = parser.parse_args()
    main(args)
