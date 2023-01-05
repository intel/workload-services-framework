"""quantize onnx model"""
import os
import argparse
import numpy as np
import onnx
from neural_compressor.experimental import Quantization, common
from neural_compressor import options

def load_dataset(input_path):
    """load dataset"""
    result = []
    mal_path = os.path.join(input_path, 'MALICIOUS')
    if os.path.exists(mal_path):
        mal_files = [(1, os.path.join(mal_path, fp)) for fp in os.listdir(mal_path)]
        result.extend(mal_files)

    clean_path = os.path.join(input_path, 'KNOWN')
    if os.path.exists(clean_path):
        clean_files = [(0, os.path.join(clean_path, fp)) for fp in os.listdir(clean_path)]
        result.extend(clean_files)

    return result


def read_file(filepath: str, expect_size: int):
    """read data raw bytes"""
    if filepath[-4:] == '.npy':
        data = np.load(filepath, allow_pickle=True)
    else:
        data = np.fromfile(filepath, np.ubyte)

    if data.size < expect_size:
        data = np.pad(data, (0, expect_size - data.size), 'constant', constant_values=(0, 0))
    else:
        data = data[:expect_size]
    data = np.array([data])
    return data.astype(np.float32)


class Dataset:
    """load dataset"""
    def __init__(self, input_path):
        self.batch_size = 32
        self.dataset = load_dataset(input_path)

    def __iter__(self):
        for label, filepath in self.dataset:
            data = read_file(filepath, expect_size=1048576)
            yield data, label

    def __len__(self):
        return len(self.dataset)


def parse_args():
    """parse args"""
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-m', '--input_model',
        type=str, dest='input_model',
        help='path of frozen fp32 model', required=True)
    parser.add_argument(
        '-c', '--input_config',
        type=str, dest='input_config',
        help='path of yaml config file', required=True)
    parser.add_argument(
        '-i', '--input_path',
        type=str, dest='input_path',
        help='path of input dataset', required=True)
    parser.add_argument(
        '-o', '--output_file',
        type=str, dest='output_file',
        help='path of output file', required=True)
    args = parser.parse_args()
    return args

class Quantize:
    """quantization"""
    def __init__(self):
        self.args = parse_args()
        self._create_quantizer()

    def run(self):
        """run quantization"""
        q_model = self.quantizer()
        q_model.save(self.args.output_file)

    def _create_quantizer(self):
        args = self.args
        model = onnx.load(args.input_model)
        options.onnxrt.graph_optimization.level = 'ENABLE_BASIC'
        self.quantizer = Quantization(args.input_config)
        self.quantizer.model = common.Model(model)
        self.quantizer.calib_dataloader = Dataset(args.input_path)

if __name__ == '__main__':
    Quantize().run()
