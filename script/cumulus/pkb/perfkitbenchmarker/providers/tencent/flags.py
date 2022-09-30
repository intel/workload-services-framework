# Copyright 2015 PerfKitBenchmarker Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from absl import flags

flags.DEFINE_string('tencent_user_name', 'ubuntu',
                    'This determines the user name that Perfkit will '
                    'attempt to use. This must be changed in order to '
                    'use any image other than ubuntu.')
flags.DEFINE_string('tencent_boot_disk_type', None,
                    '"CLOUD_BASIC" - HDD cloud disk, '
                    '"CLOUD_PREMIUM" - premium cloud disk, '
                    '"CLOUD_SSD" - cloud SSD disk, '
                    '"LOCAL_BASIC" - local disk, '
                    '"LOCAL_SSD" - local SSD disk')
flags.DEFINE_string('tencent_boot_disk_size', None,
                    'Boot disk size in GB.')
flags.DEFINE_string('tencent_internet_bandwidth', None,
                    'Internet bandwidth in Mbps.')
flags.DEFINE_string('tencent_image_id', None,
                    'Image ID.')
flags.DEFINE_integer('tencent_project_id', 0,
                     'Project ID.')
