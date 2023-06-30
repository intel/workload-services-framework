#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
"""malconv inference benchmark test"""
import time
import socket
import argparse
import os
import json
import numpy as np
from progress.bar import Bar
from analyze_scores import analyze_scores
import tensorflow as tf
from tensorflow.python.client import timeline
import onnxruntime as ort

os.environ["CUDA_VISIBLE_DEVICES"]="-1"

def read_file(filepath, expect_size=1048576):
    """read test file raw bytes"""
    if filepath[-4:] == '.npy':
        data = np.load(filepath, allow_pickle=True)
    else:
        data = np.fromfile(filepath, np.ubyte)
    if data.size < expect_size:
        data = np.pad(data, (0, expect_size - data.size), 'constant', constant_values=(0, 0))
    else:
        data = data[:expect_size]

    return np.array([data])

class H5Model:
    """class for handling Keras h5 file"""
    def __init__(self, h5_path):
        self.model = tf.keras.models.load_model(h5_path)

    def predict(self, input_data):
        """h5 inference"""
        start = time.time()
        result = self.model.predict(input_data)
        finish = time.time()
        return result[0], 1000 * (finish - start)

class SavedModel:
    """class for handling tf saved model"""
    def __init__(self, save_model_dir):
        self.session = tf.compat.v1.Session()
        meta_graph_def = tf.compat.v1.saved_model.loader.load(
            self.session, ['serve'], save_model_dir)
        signature = meta_graph_def.signature_def
        serving_default = signature['serving_default']
        self.X = serving_default.inputs['input_1'].name
        self.y = serving_default.outputs['dense_2'].name

    def predict(self, input_data):
        """saved model inference"""
        start = time.time()
        result = self.session.run(self.y, feed_dict={self.X: input_data})
        finish = time.time()
        return result[0][0], 1000 * (finish - start)

class ONNXModel:
    """class for handling ONNX model"""
    def __init__(self, onnx_file, num_cores=1):
        self.onnx_file = onnx_file
        if num_cores > 0:
            sess_options = ort.SessionOptions()
            sess_options.intra_op_num_threads = num_cores
            sess_options.execution_mode = ort.ExecutionMode.ORT_SEQUENTIAL
            sess_options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
            self.session = ort.InferenceSession(self.onnx_file, sess_options=sess_options, providers=['CPUExecutionProvider'])
        else:
            print('ONNXModel: not specify session options')
            self.session = ort.InferenceSession(self.onnx_file, providers=['CPUExecutionProvider'])
        self.input_name = self.session.get_inputs()[0].name
        self.output_name = self.session.get_outputs()[0].name

    def predict(self, input_data):
        """onnx inference"""
        float32_data = input_data.astype(np.float32)
        start = time.time()
        result = self.session.run([self.output_name], {self.input_name: float32_data})
        finish = time.time()
        return result[0][0][0], 1000 * (finish - start)

class FrozenModel:
    """class for handling frozen graphs"""
    def __init__(self, pb_filepath, config=None):
        self.timeline = timeline
        self.json = json
        graph = tf.Graph()
        with graph.as_default():
            graph_def = tf.compat.v1.GraphDef()
            with open(pb_filepath, "rb") as f:
                self.model_path = pb_filepath
                graph_def.ParseFromString(f.read())
                _ = tf.import_graph_def(graph_def, name='')
                self.session = tf.compat.v1.Session(config=config, graph=graph)
                self.input_t1 = graph.get_tensor_by_name("input_1:0")
                self.output_data = graph.get_tensor_by_name("Identity:0")
                self.run_options = tf.compat.v1.RunOptions(trace_level=tf.compat.v1.RunOptions.FULL_TRACE)
                self.run_metadata = tf.compat.v1.RunMetadata()

    def predict(self, input_data):
        """frozen graph inference"""
        result = self.session.run(self.output_data, feed_dict={self.input_t1: input_data}, options=self.run_options, run_metadata=self.run_metadata)
        # calculation infer time from timeline
        # much more accurate then time.time() method.
        tl = self.timeline.Timeline(self.run_metadata.step_stats)
        ctf = tl.generate_chrome_trace_format()
        trace = self.json.loads(ctf)
        try:
            # latency = last_op_start_time + last_op_duration - first_op_start times
            latency = trace['traceEvents'][-1]['ts'] + trace['traceEvents'][-1]['dur'] - trace['traceEvents'][3]['ts']
        except:
            # may not have last_op_duration for warm up stage.
            # thus use this to catch the exception. will not be calculated into the final results.
            latency = trace['traceEvents'][-1]['ts'] - trace['traceEvents'][3]['ts']
        # do not save the json file here
        # IO interrupt cores which make other cores running on higher frequency
        # to output timeline data, print the trace
        # print(trace)

        return result[0][0], latency/1000


class TestOnDataset:
    """read dataset and run benchmark depends on the model format"""
    def __init__(self, model, input_path, num_files):
        self.model = model
        self.threshold = 0.99
        self.avg_infer_time = None
        self.standard_deviation = None

        self.all_files = []
        mal_path = os.path.join(input_path, 'MALICIOUS')
        mal_files = [(1, os.path.join(mal_path, fp)) for fp in os.listdir(mal_path)]
        mal_files = mal_files[0:num_files]
        self.all_files.extend(mal_files)

        clean_path = os.path.join(input_path, 'KNOWN')
        clean_files = [(0, os.path.join(clean_path, fp)) for fp in os.listdir(clean_path)]
        clean_files = clean_files[0:num_files]
        self.all_files.extend(clean_files)

    def run(self):
        """run benchmark"""
        input_tensor = read_file(self.all_files[0][1])
        for _ in range(30):
            self.model.predict(input_tensor)

        all_infer_time = []
        files, scores, pred, all_y = [], [], [], []
        bar = Bar('Progress... ', max=len(self.all_files))
        for label, filepath in self.all_files:
            int8_data = read_file(filepath)
            score, infer_time = self.model.predict(int8_data)
            all_infer_time.append(infer_time)
            files.append(filepath)
            scores.append(score)
            pred.append(int(score >= self.threshold))
            all_y.append(label)
            bar.next()
        bar.finish()

        self.avg_infer_time = np.mean(all_infer_time)
        self.standard_deviation = np.std(all_infer_time)

        print(f'average inference time: {self.avg_infer_time} ms')
        print(f'standard deviation: {self.standard_deviation} ms')
        print(f'filecount: {len(self.all_files)}')

        analyze_scores(
          all_data=[{'Filename': files, 'Score': scores, 'Predict': pred, 'Actual': all_y}],
          labels=[socket.gethostname()],
          ref_fprs=[0.05, 0.01],
    )

def load_model(model_path, num_cores):
    """load model file"""
    if model_path[-2:] == 'h5':
        return H5Model(model_path)
    if model_path[-4:] == 'onnx':
        return ONNXModel(model_path, num_cores)
    if os.path.isdir(model_path):
        return SavedModel(model_path)
    return FrozenModel(model_path)

def main():
    """main function"""
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-m', '--model_path', type=str, dest='model_path', help='model path', required=True)
    parser.add_argument(
        '-i', '--input_path', type=str, dest='input_path', help='input dataset path', required=True)
    parser.add_argument(
        '-c', '--num_cores', type=int, dest='num_cores', help='number of cores for ONNX runtime', default=1)
    parser.add_argument(
        '-t', '--tag', type=str, dest='tag', help='special tag of test, pkm or gated', default='none')
    args = parser.parse_args()
    model = load_model(args.model_path, args.num_cores)

    num_files = 500
    if args.tag == 'gated':
        num_files = 100
    if args.tag == 'pkm':
        num_files = 2000

    TestOnDataset(model, args.input_path, num_files).run()

if __name__ == '__main__':
    main()
