import sys
import subprocess
import getopt
import uuid
from multiprocessing import Pool
from time import strftime, localtime

def start_benchmark(kwargs):
    log_name = "log_" + str(uuid.uuid4())
    if kwargs['id'] == "consumer":
        cmd = "date; sh " + kwargs['kafka_dir'] + "/bin/kafka-consumer-perf-test.sh " + " --messages " + kwargs['messages'] + \
              " --topic " + kwargs['topic'] + " --broker-list " + kwargs['kafka_server'] + " --group " + kwargs['kafka_consumer_group_id'] + \
              " --timeout " + kwargs['consumer_timeout']

    elif kwargs['id'] == "producer":
        cmd = "date; sh " + kwargs['kafka_dir'] + "/bin/kafka-producer-perf-test.sh " + " --topic " + kwargs['topic'] + \
              " --num-records " + kwargs['num_records'] + " --throughput " + kwargs['throughput'] + " --record-size " \
              + kwargs['record_size'] + " --producer-props bootstrap.servers="+kwargs['kafka_server'] + \
              " compression.type="+kwargs['compression_type']
    else:
        raise Exception("id {} is not defined!")
    print(cmd)
    print(strftime("process started at :  [%Y-%m-%d %H:%M:%S]", localtime()))
    popen = subprocess.Popen(cmd,
                         shell = True,
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


if __name__ == '__main__':

    try:
        #i = IDENTIFIER
        #k = KAFKA_DIR
        #t = TOPIC
        #m = MESSAGES
        #h = THROUGHPUT
        #s = KAFKA_SERVER
        #g = KAFKA_CONSUMER_GROUP_ID
        #n = NUM_RECORDS
        #c = COMPRESSION_TYPE
        #r = RECORD_SIZE
        #a = CONSUMERS
        #b = PRODUCERS
        #l = CONSUMER_TIMEOUT
        opts, args = getopt.getopt(sys.argv[1:], "i:m:k:t:h:s:g:n:c:r:a:b:l:")
    except getopt.GetoptError:
        print("error when set options!")
        exit(1)
    params = dict()
    for option, value in opts:
        if option in ["-i"]:
            params['id'] = value
        elif option in ["-k"]:
            params['kafka_dir'] = value
        elif option in ["-m"]:
            params['messages'] = value
        elif option in ["-t"]:
            params['topic'] = value
        elif option in ["-s"]:
            params['kafka_server'] = value
        elif option in ["-h"]:
            params['throughput'] = value
        elif option in ["-g"]:
            params['kafka_consumer_group_id'] = value
        elif option in ["-n"]:
            params['num_records'] = value
        elif option in ["-c"]:
            params['compression_type'] = value
        elif option in ["-r"]:
            params['record_size'] = value
        elif option in ["-a"]:
            params['consumers'] = int(value)
        elif option in ["-b"]:
            params['producers'] = int(value)
        elif option in ["-l"]:
            params['consumer_timeout'] = value
    print(params)

    obj_lst = []
    id = params['id']
    print("id is [{}]".format(id))
    if id == "consumer":
        pool = Pool(params['consumers'])
        for i in range(params['consumers']):
            p_obj = pool.apply_async(start_benchmark, (params,))
            obj_lst.append(p_obj)
    elif id == "producer":
        pool = Pool(params['producers'])
        for i in range(params['producers']):
            p_obj = pool.apply_async(start_benchmark, (params,))
            obj_lst.append(p_obj)
    else:
        raise Exception("id {} is not defined!")
    pool.close()
    pool.join()