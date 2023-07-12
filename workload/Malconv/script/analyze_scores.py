#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
"""
analyze_scores.py
*** Code has been significantly cropped for public demo release ***
@author: Brody Kutt (bkutt@paloaltonetworks.com)
"""

import os
import csv
import argparse
import numpy as np
from collections import defaultdict
from sklearn.metrics import f1_score, roc_curve, roc_auc_score, confusion_matrix


def float2string(inp):
    """float to string"""
    return ('%.15f' % inp).rstrip('0').rstrip('.')


def format_predict_data(fields, prediction):
    """format predict data"""
    result = defaultdict(list)

    for row in prediction:
        for field, value in zip(fields, row):
            result[field].append(value)

    result['Score'] = [float(x) for x in result['Score']]
    result['Predict'] = [int(x) for x in result['Predict']]
    result['Actual'] = [int(x) for x in result['Actual']]

    return result


def read_predict_file(path: str) -> dict:
    """read predict file"""
    with open(path, 'r') as csv_file:
        csv_reader = csv.reader(csv_file)
        _ = next(csv_reader)
        fields = next(csv_reader)
        return format_predict_data(fields, csv_reader)


def apply_threshold(scores: list, threshold: float) -> list:
    """apply threshold"""
    return [int(score >= threshold) for score in scores]


def recall_specificity_at_thresh(y_scores, y_test, threshold, adjusted_ben=None, adjusted_mal=None):
    """
    Return the highest recall possible when the specificity is set to 100%
    i.e. there are no FPs. If 100% specificity isn't possible even with a
    maximum threshold, -1 will be returned.
        Parameters:
        y_scores: array-like, shape (n_samples), ensemble scores
        y_test: array-like, shape (n_samples), test labels
        threshold: float, the decision threshold
        adjusted_ben: int, adjusted total number of benign files (when
                           measuring adjusted performance)
        adjusted_ben: int, adjusted total number of malicious files (when
                           measuring adjusted performance)
        Returns:
        recall, specificity: float, float; the recall and specificity
    """
    predict_discrete = apply_threshold(y_scores, threshold)
    cm = confusion_matrix(y_test, predict_discrete, labels=[0, 1])

    if adjusted_ben:
        # assert adjusted_ben >= (cm[0][0] + cm[0][1])
        cm[0][0] += (adjusted_ben - (cm[0][0] + cm[0][1]))  # Count them as TNs

    if adjusted_mal:
        # assert adjusted_mal >= (cm[1][0] + cm[1][1])
        cm[1][0] += (adjusted_mal - (cm[1][0] + cm[1][1]))  # Count them as FNs

    tn, fp, fn, tp = cm.ravel()

    recall = (tp * 100.0) / float(fn + tp) if float(fn + tp) != 0 else 100.0
    specificity = (tn * 100.0) / float(fp + tn) if float(fp + tn) != 0 else 100.0

    return recall, specificity


def parse_args():
    """parse args"""
    parser = argparse.ArgumentParser(
        description='Do analysis on computed malicious class scores.')
    parser.add_argument(
        '--pred_fps',
        nargs='+',
        help=('All filepaths leading to prediction files you wish compare. '
              'Separate each with a space.'))
    parser.add_argument(
        '--labels',
        help=('Labels for prediction files you wish to see in the plot '
              'legend. Supply one for each prediction file. Separate each '
              'with a comma.'))
    parser.add_argument(
        '--cust_threshs',
        default='',
        required=False,
        metavar='thresh1,thresh2,...',
        help=('All custom threhsolds you would like to test. Separate each '
              'with a comma.'))
    parser.add_argument(
        '--ref_fprs',
        default='',
        required=False,
        metavar='fpr1,fpr2,...',
        help=('All FPRs which you want to discover corresponding recall. '
              'Separate each with a comma.'))
    return parser.parse_args()


class Analyzer:
    """analyzer"""
    def __init__(self, **kwargs):
        self.roc_data = []
        self.labels = kwargs['labels']
        self.ref_fprs = kwargs['ref_fprs']
        self.custom_thresholds = kwargs['custom_thresholds'] if 'custom_thresholds' in kwargs else None

        if 'pred_fps' in kwargs:
            self.all_data = self._read_predict_files(kwargs['pred_fps'])
        else:
            self.all_data = kwargs['all_data']

    def run(self):
        """run analyzer"""
        self._print_header()
        self._compute_custom_threshold_stats()
        self._compute_roc_curves()
        self._compute_tprs()
        self._print_tail()

    @staticmethod
    def _print_header():
        print('-' * 80)

    @staticmethod
    def _print_tail():
        print('\nExiting...')
        print('-' * 80)

    def _read_predict_files(self, pred_fps):
        print('Reading in predictions files...')
        result = []
        for label, filepath in zip(self.labels, pred_fps):
            result.append(read_predict_file(filepath))
            print(f'\tRead in {label} predictions: {filepath}!')
        return result

    def _compute_custom_threshold_stats(self) -> None:
        if not self.custom_thresholds:
            return

        print('\nComputing custom threshold stats...')
        for label, data in enumerate(self.labels, self.all_data):
            print(f'\n--> Using predictions with label \'{label}\':')
            for threshold in self.custom_thresholds:
                print(f'----> Stats using custom threshold {float2string(threshold)}...')
                r, s = recall_specificity_at_thresh(data['Score'], data['Actual'], threshold)
                predict = apply_threshold(data['Score'], thresh)
                f1 = f1_score(data['Actual'], predict)
                print(f'------> Recall: {r:%.6f}, Specificity: {s:%.6f}, F1: {f1:%.6f}')

    def _compute_roc_curves(self):
        print('\nComputing ROC curves...')
        for label, data in zip(self.labels, self.all_data):
            print(f'\n--> Using predictions with label \'{label}\':')
            fpr, tpr, thresholds = roc_curve(data['Actual'], data['Score'])
            self.roc_data.append((fpr, tpr, thresholds))
            auc = roc_auc_score(data['Actual'], data['Score'])
            print(f'----> ROC AUC: {float2string(auc)}')

    def _compute_tprs(self):
        if not self.ref_fprs:
            return

        print('\nComputing TPRs at reference FPRs...')
        for label, data, (fpr, tpr, thresholds) in zip(self.labels, self.all_data, self.roc_data):
            print(f'\n--> Using predictions with label \'{label}\':')
            for ref_fpr in self.ref_fprs:
                print(f'----> Stats using reference FPR <= {float2string(ref_fpr)}...')
                idx = np.sum(fpr <= ref_fpr) - 1
                print(f'------> Threshold: {thresholds[idx]:.10f}, FPR: {fpr[idx]:.10f}, TPR {tpr[idx]:.10f}')


def analyze_scores(**kwargs):
    """analyze scores"""
    if 'pred_fps' in kwargs or 'all_data' in kwargs:
        Analyzer(**kwargs).run()
    else:
        raise Exception('No prediction file or data found!')


def main():
    """main function"""
    args = parse_args()

    # for fp in args.pred_fps:
    #     assert (os.path.isfile(fp))

    analyze_scores(
        pred_fps=args.pred_fps,
        labels=args.labels.strip().split(','),
        ref_fprs=[float(i) for i in args.ref_fprs.strip().split(',') if i != ''],
        custom_thresholds=[float(i) for i in args.cust_threshs.strip().split(',') if i != ''],
    )


if __name__ == '__main__':
    # from pudb import set_trace
    # set_trace()
    main()
