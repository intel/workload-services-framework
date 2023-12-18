#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
import sys
import os
import subprocess
import uuid
from multiprocessing import Pool
from time import strftime, localtime
import secrets

def get_task_cmd(params):
    if params['kafka_enable_encryption'] == "true":
        if params['id'] == "consumer":
            cmd = [params['kafka_dir'] + "/bin/kafka-consumer-perf-test.sh",
                   "--messages",params['messages'],
                   "--topic",params['topic'],
                   "--broker-list",params['kafka_server'],
                   "--group",params['kafka_consumer_group_id'],
                   "--timeout",params['consumer_timeout'],
                   "--fetch-size",params['fetch_size'],
                   "--consumer.config",params['kafka_dir'] + "/config/client-ssl.properties"]
        elif params['id'] == "producer":
            prepare_payload(params)
            cmd = [params['kafka_dir'] + "/bin/kafka-producer-perf-test.sh",
                   "--topic",params['topic'],
                   "--num-records",params['num_records'],
                   "--throughput",params['throughput'],
                   "--payload-file",params['payload_file'],
                   "--producer-props","bootstrap.servers=" + params['kafka_server'],
                   "compression.type=" + params['compression_type'],
                   "buffer.memory=" + params['buffer_mem'],"batch.size=" + params['batch_size'],
                   "linger.ms=" + params['linger_ms'],"acks=" + params['ack'],
                   "--producer.config",params['kafka_dir'] + "/config/client-ssl.properties","--print-metrics"]
        else:
            raise Exception("Unknown id [{}].".format(params['id']))
    else:
        if params['id'] == "consumer":
            cmd = [params['kafka_dir'] + "/bin/kafka-consumer-perf-test.sh",
                   "--messages",params['messages'],
                   "--topic",params['topic'],
                   "--broker-list",params['kafka_server'],
                   "--group",params['kafka_consumer_group_id'],
                   "--timeout",params['consumer_timeout'],
                   "--fetch-size",params['fetch_size']]
        elif params['id'] == "producer":
            prepare_payload(params)
            cmd = [params['kafka_dir'] + "/bin/kafka-producer-perf-test.sh",
                   "--topic",params['topic'],
                   "--num-records",params['num_records'],
                   "--throughput",params['throughput'],
                   "--payload-file",params['payload_file'],
                   "--producer-props","bootstrap.servers=" + params['kafka_server'],
                   "compression.type=" + params['compression_type'],
                   "buffer.memory=" + params['buffer_mem'],"batch.size=" + params['batch_size'],
                   "linger.ms=" + params['linger_ms'],"acks=" + params['ack'],"--print-metrics"]
        else:
            raise Exception("Unknown id [{}].".format(params['id']))
    return cmd

def get_pool_size(params):
    pool_size = 0
    if params['id'] == "consumer":
        pool_size = params['consumers']
    elif params['id'] == "producer":
        pool_size = params['producers']
    else:
        raise Exception("Unknown id [{}].".format(params['id']))
    return int(pool_size)

def get_params():
    params = {}
    params['id'] = os.getenv('K_IDENTIFIER')
    params['kafka_dir'] = os.getenv('K_KAFKA_DIR')
    params['messages'] = os.getenv('K_MESSAGES')
    params['topic'] = os.getenv('K_KAFKA_BENCHMARK_TOPIC')
    params['kafka_server'] = os.getenv('K_KAFKA_SERVER')
    params['throughput'] = os.getenv('K_THROUGHPUT')
    params['kafka_consumer_group_id'] = os.getenv('K_KAFKA_CONSUMER_GROUP_ID')
    params['num_records'] = os.getenv('K_NUM_RECORDS')
    params['compression_type'] = os.getenv('K_COMPRESSION_TYPE')
    params['record_size'] = os.getenv('K_RECORD_SIZE')
    params['consumers'] = os.getenv('K_CONSUMERS')
    params['producers'] = os.getenv('K_PRODUCERS')
    params['consumer_timeout'] = os.getenv('K_CONSUMER_TIMEOUT')
    params['buffer_mem'] = os.getenv('K_BUFFER_MEM')
    params['batch_size'] = os.getenv('K_BATCH_SIZE')
    params['linger_ms'] = os.getenv('K_LINGER_MS')
    params['ack'] = os.getenv('K_ACKS')
    params['fetch_size'] = os.getenv('K_FETCH_SIZE')
    params['kafka_enable_encryption'] = os.getenv('K_ENCRYPTION')
    params['payload_num'] = os.getenv('K_PAYLOAD_NUM')
    params['payload_file'] = os.getenv('K_KAFKA_DIR')+'/payload.txt'
    return params

def start_benchmark(cmd):
    log_name = "log_" + str(uuid.uuid4())
    print(cmd)
    print(strftime("process started at :  [%Y-%m-%d %H:%M:%S]", localtime()))
    popen = subprocess.Popen(cmd,
                         stdout = subprocess.PIPE,
                         stderr = subprocess.PIPE,
                         universal_newlines = True,
                         bufsize = 1)
    out,err = popen.communicate()
    print(out)
    print(strftime("process ended at :  [%Y-%m-%d %H:%M:%S]", localtime()))
    print("--------------------------------------------------")
    print(err)
    with open(log_name, 'w') as FILE:
        FILE.write(out)
        FILE.write(err)

def prepare_payload(params):
    # number of random payloads
    number = int(params['payload_num'])
    record_size = int(params['record_size'])
    seed_str = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    fileName = params['payload_file']
    with open(fileName,'w',encoding='utf-8') as file:
        for _ in range(number):
            file.write(''.join(secrets.choice(seed_str) for _ in range(record_size))+"\n")
    file.close()

if __name__ == '__main__':

    params = get_params()
    print("Parameters:", params)
    cmd = get_task_cmd(params)
    pool_size = get_pool_size(params)

    obj_lst = []
    pool = Pool(pool_size)
    for i in range(pool_size):
        p_obj = pool.apply_async(start_benchmark, (cmd,))
        obj_lst.append(p_obj)
    pool.close()
    pool.join()
