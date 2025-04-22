# Copyright (c) 2021 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright (c) Facebook, Inc. and its affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#
# Description: generate inputs and targets for the dlrm benchmark
# The inpts and outputs are generated according to the following three option(s)
# 1) random distribution
# 2) synthetic distribution, based on unique accesses and distances between them
#    i) R. Hassan, A. Harris, N. Topham and A. Efthymiou "Synthetic Trace-Driven
#    Simulation of Cache Memory", IEEE AINAM'07
# 3) public data set
#    i)  Criteo Kaggle Display Advertising Challenge Dataset
#    https://labs.criteo.com/2014/02/kaggle-display-advertising-challenge-dataset
#    ii) Criteo Terabyte Dataset
#    https://labs.criteo.com/2013/12/download-terabyte-click-logs
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#


from __future__ import absolute_import, division, print_function, unicode_literals

import os
from os import path
from multiprocessing import Process, Manager, Pool
import sys
import argparse
import numpy as np
import pickle


def processCriteoAdData(d_path, d_file, npzfile, i, pre_comp_counts, dict_files):
    # Process Kaggle Display Advertising Challenge or Terabyte Dataset
    # by converting unicode strings in X_cat to integers and
    # converting negative integer values in X_int.
    #
    # Loads data in the form "{kaggle|terabyte}_day_i.npz" where i is the day.
    #
    # Inputs:
    #   d_path (str): path for {kaggle|terabyte}_day_i.npz files
    #   i (int): splits in the dataset (typically 0 to 7 or 0 to 24)

    # process data if not all files exist
    filename_i = npzfile + "_{0}_processed.npz".format(i)

    if path.exists(filename_i):
        print("Using existing " + filename_i, end="\n")
    else:
        print("Not existing " + filename_i)
        with np.load(npzfile + "_{0}.npz".format(i)) as data:
            # categorical features
            # Approach 2a: using pre-computed dictionaries
            X_cat_t = np.zeros(data["X_cat_t"].shape)
            for j in range(26):
                dict_file = dict_files[j]
                with open(dict_file, 'rb') as f:
                    convertDict = pickle.load(f)
                for k, x in enumerate(data["X_cat_t"][j, :]):
                    X_cat_t[j, k] = convertDict[x]
            # continuous features
            X_int = data["X_int"]
            X_int[X_int < 0] = 0
            # targets
            y = data["y"]

        np.savez_compressed(
            filename_i,
            # X_cat = X_cat,
            X_cat=np.transpose(X_cat_t),  # transpose of the data
            X_int=X_int,
            y=y
        )
        print("Processed " + filename_i, end="\n")
    # sanity check (applicable only if counts have been pre-computed & are re-computed)
    # for j in range(26):
    #    if pre_comp_counts[j] != counts[j]:
    #        sys.exit("ERROR: Sanity check on counts has failed")
    # print("\nSanity check on counts passed")

    return


# process a file worth of data and reinitialize data
# note that a file main contain a single or multiple splits
def process_one_file(
        datfile,
        npzfile,
        split,
        num_data_in_split,
        dataset_multiprocessing,
        convertDictsDay=None,
        convertDictsDay_day=None,
        resultDay=None
):
    if dataset_multiprocessing:
        convertDicts_day = {_:{} for _ in range(26)}
    
    y = np.zeros(num_data_in_split, dtype="i4")  # 4 byte int
    X_int = np.zeros((num_data_in_split, 13), dtype="i4")  # 4 byte int
    X_cat = np.zeros((num_data_in_split, 26), dtype="i4")  # 4 byte int
    if sub_sample_rate == 0.0:
        rand_u = 1.0
    else:
        rand_u = np.random.uniform(low=0.0, high=1.0, size=num_data_in_split)

    i = 0
    percent = 0
    
    with open(str(datfile)) as f:
        lines = f.readlines()
    
    for k, line in enumerate(lines):
        # process a line (data point)
        line = line.split('\t')
        # set missing values to zero
        for j in range(len(line)):
            if (line[j] == '') or (line[j] == '\n'):
                line[j] = '0'
        # sub-sample data by dropping zero targets, if needed
        target = np.int32(line[0])
        if target == 0 and \
            (rand_u if sub_sample_rate == 0.0 else rand_u[k]) < sub_sample_rate:
            continue

        y[i] = target
        X_int[i] = np.array(line[1:14], dtype=np.int32)
        if max_ind_range > 0:
            X_cat[i] = np.array(
                list(map(lambda x: int(x, 16) % max_ind_range, line[14:])),
                dtype=np.int32
            )
        else:
            X_cat[i] = np.array(
                list(map(lambda x: int(x, 16), line[14:])),
                dtype=np.int32
            )

        # count uniques
        if dataset_multiprocessing:
            for j in range(26):
                convertDicts_day[j][X_cat[i][j]] = 1
            # debug prints
            if float(i)/num_data_in_split*100 > percent+1:
                percent = int(float(i)/num_data_in_split*100)
                print(
                    "Load %d/%d (%d%%) Split: %d  Label True: %d  Stored: %d"
                    % (
                        i,
                        num_data_in_split,
                        percent,
                        split,
                        target,
                        y[i],
                    ),
                    end="\n",
                )
        else:
            for j in range(26):
                convertDicts[j][X_cat[i][j]] = 1
            # debug prints
            print(
                "Load %d/%d  Split: %d  Label True: %d  Stored: %d"
                % (
                    i,
                    num_data_in_split,
                    split,
                    target,
                    y[i],
                ),
                end="\r",
            )
        i += 1
    
    del lines

    # store parsed
    filename_s = npzfile + "_{0}.npz".format(split)
    if path.exists(filename_s):
        print("\nSkip existing " + filename_s)
    else:
        np.savez_compressed(
            filename_s,
            X_int=X_int[0:i, :],
            X_cat_t=np.transpose(X_cat[0:i, :]),  # transpose of the data
            y=y[0:i]
        )
        print("\nSaved " + npzfile + "_{0}.npz!".format(split))

    if dataset_multiprocessing:
        resultDay[split] = i
        convertDictsDay_day.update(convertDicts_day)
        convertDictsDay[split] = convertDictsDay_day
        return
    else:
        return i


def shuffle_one_file(idx, npzfile, days, randomize, total_per_file, bucket_sizes):
    filename_i = npzfile + "_{0}_processed.npz".format(idx)
    # debug prints
    print("Reordering (1st pass) " + filename_i)

    with np.load(filename_i) as data:
        y = data["y"]
    size = len(y)
    # sanity check
    if total_per_file[idx] != size:
        print(total_per_file[idx], size)
        sys.exit("ERROR: sanity check 1 on number of samples failed")

    # create buckets using sampling of random ints
    # from (discrete) uniform distribution
    buckets = [[] for _j in range(days)]
    counter = [0] * days
    days_to_sample = days
    if randomize == "total":
        rand_u = np.random.randint(low=0, high=days_to_sample, size=size)
        for k in range(size):
            # sample and make sure elements per buckets do not overflow
            # choose bucket
            p = rand_u[k]
            # retry of the bucket is full
            while counter[p] >= bucket_sizes[p]:
                p = np.random.randint(low=0, high=days_to_sample)
            buckets[p].append(k)
            counter[p] += 1
    else:  # randomize is day or none
        for k in range(size):
            # do not sample, preserve the data in this bucket
            p = idx
            buckets[p].append(k)
            counter[p] += 1
    # sanity check
    if np.sum(counter) != size:
        print(np.sum(counter), size)
        sys.exit("ERROR: sanity check 2 on number of samples failed")
    
    filename_r = npzfile + "_{0}_buckets.npz".format(idx)
    
    np.savez_compressed(
        filename_r,
        buckets=np.array(buckets, dtype=object)
    )
    
    return


def merge_buckets(idx, npzfile, days, total_per_file, bucket_sizes):
    # sanity check
    if np.sum(bucket_sizes) != total_per_file[idx]:
        print(np.sum(bucket_sizes), total_per_file[idx])
        sys.exit("ERROR: sanity check 3 on number of samples failed")
        
    filename_j_y = npzfile + "_{0}_intermediate_y.npy".format(idx)
    filename_j_d = npzfile + "_{0}_intermediate_d.npy".format(idx)
    filename_j_s = npzfile + "_{0}_intermediate_s.npy".format(idx)
    
    for i in range(days):
        filename_i = npzfile + "_{0}_buckets.npz".format(i)
        filename_j = npzfile + "_{0}_processed.npz".format(i)
        if i == 0:
            start = 0
        else:
            start = end
        end = start + bucket_sizes[i]
        with np.load(filename_i, allow_pickle=True, mmap_mode='r') as data:
            buckets = data["buckets"][idx]
        with np.load(filename_j, mmap_mode='r') as data:
            X_cat = data["X_cat"][buckets, :]
            X_int = data["X_int"][buckets, :]
            y = data["y"][buckets]
        fj_y = np.load(filename_j_y, mmap_mode='r+')
        fj_y[start:end] = y
        del fj_y
        fj_d = np.load(filename_j_d, mmap_mode='r+')
        fj_d[start:end, :] = X_int
        del fj_d
        fj_s = np.load(filename_j_s, mmap_mode='r+')
        fj_s[start:end, :] = X_cat
        del fj_s
    
    return


def shuffle_compress_one_file(idx, npzfile, days, randomize, total_per_file):
    filename_j_y = npzfile + "_{0}_intermediate_y.npy".format(idx)
    filename_j_d = npzfile + "_{0}_intermediate_d.npy".format(idx)
    filename_j_s = npzfile + "_{0}_intermediate_s.npy".format(idx)
    fj_y = np.load(filename_j_y)
    fj_d = np.load(filename_j_d)
    fj_s = np.load(filename_j_s)

    indices = range(total_per_file[idx])
    if randomize == "day" or randomize == "total":
        if idx < days - 1:
            indices = np.random.permutation(range(total_per_file[idx]))

    filename_r = npzfile + "_{0}_reordered.npz".format(idx)
    print("Reordering (2nd pass) " + filename_r)
    np.savez_compressed(
        filename_r,
        X_cat=fj_s[indices, :],
        X_int=fj_d[indices, :],
        y=fj_y[indices]
    )
    
    return


def merge_dicts(idx, convertDictsDay, d_path):
    pos = {}
    for key in convertDictsDay.keys():
        pos.update(convertDictsDay[key][idx])
        
    for i, x in enumerate(pos):
        pos[x] = i
        
    filename = d_path + "fea_{}_dict.pkl".format(idx)
    with open(filename, 'wb') as f:
        pickle.dump(pos, f)
        
    return len(pos), filename

def numpy_to_binary(input_files, output_file_path, split='train'):
    """Convert the data to a binary format to be read with CriteoBinDataset."""

    # WARNING - both categorical and numerical data must fit into int32 for
    # the following code to work correctly

    with open(output_file_path, 'wb') as output_file:
        if split in ['train', 'test']:
            for input_file in input_files:
                print('Processing file: ', input_file)

                np_data = np.load(input_file)
                np_data = np.concatenate([np_data['y'].reshape(-1, 1),
                                          np_data['X_int'],
                                          np_data['X_cat']], axis=1)
                np_data = np_data.astype(np.int32)

                output_file.write(np_data.tobytes())
        else:
            assert len(input_files) == 1
            np_data = np.load(input_files[0])
            np_data = np.concatenate([np_data['y'].reshape(-1, 1),
                                      np_data['X_int'],
                                      np_data['X_cat']], axis=1)
            np_data = np_data.astype(np.int32)

            samples_in_file = np_data.shape[0]
            midpoint = int(np.ceil(samples_in_file / 2.))
            if split == "test":
                begin = 0
                end = midpoint
            elif split == "val":
                begin = midpoint
                end = samples_in_file
            else:
                raise ValueError('Unknown split value: ', split)

            output_file.write(np_data[begin:end].tobytes())


if __name__ == "__main__":
    
    parser = argparse.ArgumentParser()
    
    parser.add_argument("--data-set", type=str, default="kaggle")
    parser.add_argument("--max-ind-range", type=int, default=-1)
    parser.add_argument("--data-sub-sample-rate", type=float, default=0.0)
    parser.add_argument("--data-randomize", type=str, default="total")
    parser.add_argument("--raw-data-file", type=str, default="")
    parser.add_argument("--processed-data-file", type=str, default="")
    parser.add_argument("--memory-map", action="store_true", default=False)
    parser.add_argument("--dataset-multiprocessing", action="store_true", default=False)
    parser.add_argument("--eval-days", type=int, choices=list(range(1,25)), default=1, help="The number of days of data used for evaluation (1 day contains 8.16M samples)")
    
    args = parser.parse_args()
    
    o_lstr = args.processed_data_file.split("/")
    o_d_path = "/".join(o_lstr[0:-1]) + "/" + o_lstr[-1].split(".")[0]
    train_file = o_d_path + "_train.bin"
    test_file = o_d_path + "_test.bin"
    counts_file = args.raw_data_file + '_fea_count.npz'
    
    if any(not path.exists(p) for p in [train_file, test_file, counts_file]):
        
        dataset = args.data_set
        max_ind_range = args.max_ind_range
        sub_sample_rate = args.data_sub_sample_rate
        randomize = args.data_randomize
        raw_path = args.raw_data_file
        pro_data = args.processed_data_file
        memory_map = args.memory_map
        dataset_multiprocessing = args.dataset_multiprocessing
        den_fea = 13
        spa_fea = 26
        
        if dataset == "kaggle":
            days = 7
            out_file = "kaggleAdDisplayChallenge_processed"
        elif dataset == "terabyte":
            days = 24
            out_file = "terabyte_processed"
        else:
            raise(ValueError("Data set option is not supported"))
        
        lstr = raw_path.split("/")
        d_path = "/".join(lstr[0:-1]) + "/"
        d_file = lstr[-1].split(".")[0] if dataset == "kaggle" else lstr[-1]
        npzfile = d_path + ((d_file + "_day") if dataset == "kaggle" else d_file)
        trafile = d_path + ((d_file + "_fea") if dataset == "kaggle" else "fea")
        
        # check if pre-processed data is available
        data_ready = True
        if memory_map:
            for i in range(days):
                reo_data = npzfile + "_{0}_reordered.npz".format(i)
                if not path.exists(str(reo_data)):
                    data_ready = False
        else:
            if not path.exists(str(pro_data)):
                data_ready = False
                
        # pre-process data if needed
        # WARNNING: when memory mapping is used we get a collection of files
        if data_ready:
            print("Reading pre-processed data=%s" % (str(pro_data)))
            file = str(pro_data)
        else:
            print("Reading raw data=%s" % (str(raw_path)))
            # *** Start ***
            total_file = d_path + d_file + "_day_count.npz"
            if path.exists(total_file):
                with np.load(total_file) as data:
                    total_per_file = list(data["total_per_file"])
                total_count = np.sum(total_per_file)
                print("Skipping counts per file (already exist)")
            else:
                total_count = 0
                total_per_file = []
                if dataset == "kaggle":
                    # WARNING: The raw data consists of a single train.txt file
                    # Each line in the file is a sample, consisting of 13 continuous and
                    # 26 categorical features (an extra space indicates that feature is
                    # missing and will be interpreted as 0).
                    if path.exists(raw_path):
                        print("Reading data from path=%s" % (raw_path))
                        with open(str(raw_path)) as f:
                            for _ in f:
                                total_count += 1
                        total_per_file.append(total_count)
                        # reset total per file due to split
                        num_data_per_split, extras = divmod(total_count, days)
                        total_per_file = [num_data_per_split] * days
                        for j in range(extras):
                            total_per_file[j] += 1
                        # split into days (simplifies code later on)
                        file_id = 0
                        boundary = total_per_file[file_id]
                        nf = open(npzfile + "_" + str(file_id), "w")
                        with open(str(raw_path)) as f:
                            for j, line in enumerate(f):
                                if j == boundary:
                                    nf.close()
                                    file_id += 1
                                    nf = open(npzfile + "_" + str(file_id), "w")
                                    boundary += total_per_file[file_id]
                                nf.write(line)
                        nf.close()
                    else:
                        sys.exit("ERROR: Criteo Kaggle Display Ad Challenge Dataset path is invalid; please download from https://labs.criteo.com/2014/02/kaggle-display-advertising-challenge-dataset")
                else:
                    # WARNING: The raw data consist of day_0.gz,... ,day_23.gz text files
                    # Each line in the file is a sample, consisting of 13 continuous and
                    # 26 categorical features (an extra space indicates that feature is
                    # missing and will be interpreted as 0).
                    for i in range(days):
                        datafile_i = raw_path + "_" + str(i)  # + ".gz"
                        if path.exists(str(datafile_i)):
                            print("Reading data from path=%s" % (str(datafile_i)))
                            # file day_<number>
                            total_per_file_count = 0
                            with open(str(datafile_i)) as f:
                                for _ in f:
                                    total_per_file_count += 1
                            total_per_file.append(total_per_file_count)
                            total_count += total_per_file_count
                        else:
                            sys.exit("ERROR: Criteo Terabyte Dataset path is invalid; please download from https://labs.criteo.com/2013/12/download-terabyte-click-logs")
                
            # create all splits (reuse existing files if possible)
            recreate_flag = False
            convertDicts = [{} for _ in range(spa_fea)]
            # WARNING: to get reproducable sub-sampling results you must reset the seed below
            # np.random.seed(123)
            # in this case there is a single split in each day
            for i in range(days):
                npzfile_i = npzfile + "_{0}.npz".format(i)
                npzfile_p = npzfile + "_{0}_processed.npz".format(i)
                if path.exists(npzfile_i):
                    print("Skip existing " + npzfile_i)
                elif path.exists(npzfile_p):
                    print("Skip existing " + npzfile_p)
                else:
                    recreate_flag = True

            if recreate_flag:
                if dataset_multiprocessing:
                    resultDay = Manager().dict()
                    convertDictsDay = Manager().dict()
                    convertDictsDay_day = [Manager().dict() for i in range(days)]
                    processes = [Process(target=process_one_file,
                                        name="process_one_file:%i" % i,
                                        args=(npzfile + "_{0}".format(i),
                                            npzfile,
                                            i,
                                            total_per_file[i],
                                            dataset_multiprocessing,
                                            convertDictsDay,
                                            convertDictsDay_day[i],
                                            resultDay
                                            )
                                        ) for i in range(days)]
                    for process in processes:
                        process.start()
                    for process in processes:
                        process.join()
                    for day in range(days):
                        total_per_file[day] = resultDay[day]
                        print("Constructing convertDicts Split: {}".format(day))
                    with Pool() as pool:
                        results = pool.starmap(merge_dicts, [(idx, convertDictsDay, d_path) for idx in range(spa_fea)])
                else:
                    for i in range(days):
                        total_per_file[i] = process_one_file(
                            npzfile + "_{0}".format(i),
                            npzfile,
                            i,
                            total_per_file[i],
                            dataset_multiprocessing
                        )

            # report and save total into a file
            total_count = np.sum(total_per_file)
            if not path.exists(total_file):
                np.savez_compressed(total_file, total_per_file=total_per_file)
            print("Total number of samples:", total_count)
            print("Divided into days/splits:\n", total_per_file)

            # dictionary files
            counts = np.zeros(26, dtype=np.int32)
            dict_files = [result[1] for result in results]
            if recreate_flag:
                # create dictionaries
                for j in range(26):
                    counts[j] = results[j][0]
                # store (uniques and) counts
                count_file = d_path + d_file + "_fea_count.npz"
                if not path.exists(count_file):
                    np.savez_compressed(count_file, counts=counts)
            else:
                # create dictionaries (from existing files)
                for j in range(26):
                    with np.load(d_path + d_file + "_fea_dict_{0}.npz".format(j)) as data:
                        unique = data["unique"]
                    for i, x in enumerate(unique):
                        convertDicts[j][x] = i
                # load (uniques and) counts
                with np.load(d_path + d_file + "_fea_count.npz") as data:
                    counts = data["counts"]

            # process all splits
            if dataset_multiprocessing:
                processes = [Process(target=processCriteoAdData,
                                name="processCriteoAdData:%i" % i,
                                args=(d_path,
                                        d_file,
                                        npzfile,
                                        i,
                                        counts,
                                        dict_files
                                        )
                                ) for i in range(0, days)]
                for process in processes:
                    process.start()
                for process in processes:
                    process.join()

            else:
                for i in range(days):
                    processCriteoAdData(d_path, d_file, npzfile, i, convertDicts, counts)

            if memory_map:
                offset_per_file = np.array([0] + [x for x in total_per_file])
                for i in range(days):
                    offset_per_file[i + 1] += offset_per_file[i]
                    
                # 1st pass of FYR shuffle
                # check if data already exists
                recreate_flag = False
                for j in range(days):
                    filename_j_y = npzfile + "_{0}_intermediate_y.npy".format(j)
                    filename_j_d = npzfile + "_{0}_intermediate_d.npy".format(j)
                    filename_j_s = npzfile + "_{0}_intermediate_s.npy".format(j)
                    if (
                        path.exists(filename_j_y)
                        and path.exists(filename_j_d)
                        and path.exists(filename_j_s)
                    ):
                        print(
                            "Using existing\n"
                            + filename_j_y + "\n"
                            + filename_j_d + "\n"
                            + filename_j_s
                        )
                    else:
                        recreate_flag = True
                # reorder across buckets using sampling
                if recreate_flag:
                    # init intermediate files (.npy appended automatically)
                    for j in range(days):
                        filename_j_y = npzfile + "_{0}_intermediate_y".format(j)
                        filename_j_d = npzfile + "_{0}_intermediate_d".format(j)
                        filename_j_s = npzfile + "_{0}_intermediate_s".format(j)
                        np.save(filename_j_y, np.zeros((total_per_file[j])))
                        np.save(filename_j_d, np.zeros((total_per_file[j], den_fea)))
                        np.save(filename_j_s, np.zeros((total_per_file[j], spa_fea)))
                    # start processing files
                    if dataset_multiprocessing:
                        bucket_sizes = np.array([[total_per_file[i] // days + (total_per_file[i] % days if j == i else 0) for j in range(days)] for i in range(days)], dtype=np.int32)
                        processes = [Process(target=shuffle_one_file, name="shuffle_one_file: {0}".format(idx), args=(idx, npzfile, days, randomize, total_per_file, bucket_sizes[idx])) for idx in range(days)]
                        for process in processes:
                            process.start()
                        for process in processes:
                            process.join()
                        processes = [Process(target=merge_buckets, name="merge_buckets: {0}".format(idx), args=(idx, npzfile, days, total_per_file, bucket_sizes[:, idx])) for idx in range(days)]
                        for process in processes:
                            process.start()
                        for process in processes:
                            process.join()
                    else:
                        total_counter = [0] * days
                        for i in range(days):
                            filename_i = npzfile + "_{0}_processed.npz".format(i)
                            with np.load(filename_i) as data:
                                X_cat = data["X_cat"]
                                X_int = data["X_int"]
                                y = data["y"]
                            size = len(y)
                            # sanity check
                            if total_per_file[i] != size:
                                sys.exit("ERROR: sanity check on number of samples failed")
                            # debug prints
                            print("Reordering (1st pass) " + filename_i)

                            # create buckets using sampling of random ints
                            # from (discrete) uniform distribution
                            buckets = []
                            for _j in range(days):
                                buckets.append([])
                            counter = [0] * days
                            days_to_sample = days
                            if randomize == "total":
                                rand_u = np.random.randint(low=0, high=days_to_sample, size=size)
                                for k in range(size):
                                    # sample and make sure elements per buckets do not overflow
                                    # choose bucket
                                    p = rand_u[k]
                                    # retry of the bucket is full
                                    while total_counter[p] + counter[p] >= total_per_file[p]:
                                        p = np.random.randint(low=0, high=days_to_sample)
                                    buckets[p].append(k)
                                    counter[p] += 1
                            else:  # randomize is day or none
                                for k in range(size):
                                    # do not sample, preserve the data in this bucket
                                    p = i
                                    buckets[p].append(k)
                                    counter[p] += 1
                            # sanity check
                            if np.sum(counter) != size:
                                sys.exit("ERROR: sanity check on number of samples failed")

                            # partially feel the buckets
                            for j in range(days):
                                filename_j_y = npzfile + "_{0}_intermediate_y.npy".format(j)
                                filename_j_d = npzfile + "_{0}_intermediate_d.npy".format(j)
                                filename_j_s = npzfile + "_{0}_intermediate_s.npy".format(j)
                                start = total_counter[j]
                                end = total_counter[j] + counter[j]
                                # target buckets
                                fj_y = np.load(filename_j_y, mmap_mode='r+')
                                fj_y[start:end] = y[buckets[j]]
                                del fj_y
                                # dense buckets
                                fj_d = np.load(filename_j_d, mmap_mode='r+')
                                fj_d[start:end, :] = X_int[buckets[j], :]
                                del fj_d
                                # sparse buckets
                                fj_s = np.load(filename_j_s, mmap_mode='r+')
                                fj_s[start:end, :] = X_cat[buckets[j], :]
                                del fj_s
                                # update counters for next step
                                total_counter[j] += counter[j]

                # 2nd pass of FYR shuffle
                # check if data already exists
                for j in range(days):
                    filename_j = npzfile + "_{0}_reordered.npz".format(j)
                    if path.exists(filename_j):
                        print("Using existing " + filename_j)
                    else:
                        recreate_flag = True
                # reorder within buckets
                if recreate_flag:
                    if dataset_multiprocessing:
                        processes = [Process(target=shuffle_compress_one_file, name="shuffle_compress_one_file: {0}".format(idx), args=(idx, npzfile, days, randomize, total_per_file)) for idx in range(days)]
                        for process in processes:
                            process.start()
                        for process in processes:
                            process.join()
                    else:
                        for j in range(days):
                            filename_j_y = npzfile + "_{0}_intermediate_y.npy".format(j)
                            filename_j_d = npzfile + "_{0}_intermediate_d.npy".format(j)
                            filename_j_s = npzfile + "_{0}_intermediate_s.npy".format(j)
                            fj_y = np.load(filename_j_y)
                            fj_d = np.load(filename_j_d)
                            fj_s = np.load(filename_j_s)

                            indices = range(total_per_file[j])
                            if randomize == "day" or randomize == "total":
                                if j < days - 1:
                                    indices = np.random.permutation(range(total_per_file[j]))

                            filename_r = npzfile + "_{0}_reordered.npz".format(j)
                            print("Reordering (2nd pass) " + filename_r)
                            np.savez_compressed(
                                filename_r,
                                X_cat=fj_s[indices, :],
                                X_int=fj_d[indices, :],
                                y=fj_y[indices]
                            )
            else:
                print("Concatenating multiple days into %s.npz file" % str(d_path + out_file))
                # load and concatenate data
                for i in range(days):
                    filename_i = npzfile + "_{0}_processed.npz".format(i)
                    with np.load(filename_i) as data:
                        if i == 0:
                            X_cat = data["X_cat"]
                            X_int = data["X_int"]
                            y = data["y"]
                        else:
                            X_cat = np.concatenate((X_cat, data["X_cat"]))
                            X_int = np.concatenate((X_int, data["X_int"]))
                            y = np.concatenate((y, data["y"]))
                    print("Loaded day:", i, "y = 1:", len(y[y == 1]), "y = 0:", len(y[y == 0]))

                with np.load(d_path + d_file + "_fea_count.npz") as data:
                    counts = data["counts"]
                print("Loaded counts!")

                np.savez_compressed(
                    d_path + out_file + ".npz",
                    X_cat=X_cat,
                    X_int=X_int,
                    y=y,
                    counts=counts
                )
        
        # ** Convert .npz to .bin **
        for split in ['train', 'test']:
            print('Running preprocessing for split =', split)

            train_files = ['{}_{}_reordered.npz'.format(args.raw_data_file, day)
                        for
                        day in range(0, 24 - args.eval_days)]
            
            test_valid_files = ['{}_{}_reordered.npz'.format(args.raw_data_file, day)
                        for
                        day in range(24 - args.eval_days, 24)]

            output_file = o_d_path + '_{}.bin'.format(split)

            input_files = train_files if split == 'train' else test_valid_files
            numpy_to_binary(input_files=input_files, output_file_path=output_file, split=split)