# Copyright 2017-present, Facebook, Inc.
# All rights reserved.
#
# This source code is licensed under the license found in the
# LICENSE file in the root directory of this source tree.
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

from setuptools import find_packages, setup

setup(
      name='django-workload',
      packages=find_packages(),
      url='https://github.com/Instagram/django-workload',
      license='MIT',
      author='Martijn Pieters',
      author_email='mjpieters@fb.com',
      description='TODO',
      classifiers=[
          'License :: OSI Approved :: BSD License',
          'Topic :: Internet',
          'Programming Language :: Python :: 3 :: Only',
          'Development Status :: 3 - Alpha',
      ],
      install_requires=[
          'Django==5.2.1',
          'django-cassandra-engine',
          'django-statsd-mozilla',
          'psutil',
          'pylibmc',
          'statsd >= 3.0',
          'uwsgi >= 2.0.15',
      ],
      include_package_data=True,
)
