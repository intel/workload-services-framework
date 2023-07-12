#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
"""converting h5 model to saved model"""
import argparse
import tensorflow as tf

def parse_args():
    """parse args"""
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-m', '--input_model',
        type=str, dest='input_model',
        help='path of h5 model', required=True)
    parser.add_argument(
        '-o', '--output_path',
        type=str, dest='output_path',
        help='path of output saved model', required=True)
    args = parser.parse_args()
    return args

if __name__ == '__main__':
    args = parse_args()
    model = tf.keras.models.load_model(args.input_model)
    model.save(args.output_path)
