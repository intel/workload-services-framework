#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
import numpy as np
import csv

if __name__ == '__main__':
    cells = 0
    pre_ho = []
    ov_ho = []
    post_ho = []
    total_ho = []
    with open('xapp.log') as f:
        for line in f:
            if 'Number of Cells' in line:
                cells = int(line.split()[-1])
            if 'PRE HO processing time' in line:
                pre_ho.append(float(line.split()[-2]) * 1000)
            if 'OpenVINO Inference HO processing time' in line:
                ov_ho.append(float(line.split()[-2]) * 1000)
            if 'Post HO processing time' in line:
                post_ho.append(float(line.split()[-2]) * 1000)
            if 'Total HO processing time' in line:
                total_ho.append(float(line.split()[-2]) * 1000)
    print()
    print('CM xApp results')
    print('Number of Cells: {}'.format(cells))
    ho_names = ['Pre HO processing time', 'OpenVINO HO processing time',
                'Post HO processing time', 'Total HO processing time']
    ho_arrays = [pre_ho, ov_ho, post_ho, total_ho]
    for i in range(len(ho_names)):
        if i == 3:
            print('*', end='')
        print(ho_names[i] + ' avg (ms): ' +
              '{:.3f}'.format(np.average(ho_arrays[i])))
        print(ho_names[i] + ' std (ms): ' +
              '{:.3f}'.format(np.std(ho_arrays[i])))
        print(ho_names[i] + ' min (ms): ' +
              '{:.3f}'.format(np.min(ho_arrays[i])))
        print(ho_names[i] + ' max (ms): ' +
              '{:.3f}'.format(np.max(ho_arrays[i])))

    with open('latency.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(ho_names)
        for i in range(len(total_ho)):
            writer.writerow([ho[i] for ho in ho_arrays])
