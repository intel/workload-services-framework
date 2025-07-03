#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
from pathlib import Path
import openvino as ov
import nncf
import torch
from fastdownload import FastDownload
from torchvision import datasets
from torchvision import transforms

DATASET_PATH = Path().home() / ".cache" / "nncf" / "datasets"
DATASET_URL = "https://s3.amazonaws.com/fast-ai-imageclas/imagenette2-320.tgz"
DATASET_CLASSES = 10

def download(url: str, path: Path) -> Path:
    downloader = FastDownload(base=path.resolve(), archive="downloaded", data="extracted")
    return downloader.get(url)

dataset_path = download(DATASET_URL, DATASET_PATH)
normalize = transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
val_dataset = datasets.ImageFolder(
    root=dataset_path / "val",
    transform=transforms.Compose(
        [
            transforms.Resize(256),
            transforms.CenterCrop(224),
            transforms.ToTensor(),
            normalize,
        ]
    ),
)
val_data_loader = torch.utils.data.DataLoader(val_dataset, batch_size=1, shuffle=False)

def transform_fn(data_item):
    images, _ = data_item
    return images

ov_model = ov.Core().read_model('public/mobilenet-v2-pytorch/FP16/mobilenet-v2-pytorch.xml')
calibration_dataset = nncf.Dataset(val_data_loader, transform_fn)
ov_quantized_model = nncf.quantize(ov_model, calibration_dataset, preset=nncf.QuantizationPreset.PERFORMANCE, advanced_parameters=nncf.AdvancedQuantizationParameters())
ov.save_model(ov_quantized_model, 'mobilenet-v2.xml')

