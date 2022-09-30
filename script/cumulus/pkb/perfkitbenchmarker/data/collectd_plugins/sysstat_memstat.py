import collectd
import threading
import time
import os
import datetime

mapping = {
    "pgpgin/s": [3, "gauge"],
    "pgpgout/s": [4, "gauge"],
    "fault/s": [5, "gauge"],
    "majflt/s": [6, "gauge"],
    "pgfree/s": [7, "gauge"],
    "pgscank/s": [8, "gauge"],
    "pgscand/s": [9, "gauge"],
    "pgsteal/s": [10, "gauge"],
    "vmeff": [11, "percent"],
    "kbmemfree": [12, "memory"],
    "kbmemused": [13, "memory"],
    "memused": [14, "percent"],
    "kbbuffers": [15, "memory"],
    "kbcached": [16, "memory"],
    "kbcommit": [17, "counter"],
    "commit": [18, "percent"],
    "kbactive": [19, "memory"],
    "kbinact": [20, "memory"],
    "kbdirty": [21, "memory"],
    "kbswpfree": [22, "memory"],
    "kbswpused": [23, "memory"],
    "swpused": [24, "percent"],
    "kbswpcad": [25, "memory"],
    "swpcad": [26, "percent"],
}


class Queue:
    def __init__(self):
        self.content = []
        self.lock = threading.Lock()

    def put(self, element):
        self.lock.acquire()
        self.content.insert(0, element)
        self.lock.release()

    def get(self):
        self.lock.acquire()
        element = self.content.pop()
        self.lock.release()
        return element

    def empty(self):
        self.lock.acquire()
        result = len(self.content) == 0
        self.lock.release()
        return result


PLUGIN_NAME = "sysstat_memstat"
UID = "0"
SAMPLING_RATE = 5
METRICS = ["kbmemused"]
q = Queue()


def set_uid():
    global UID
    UID = datetime.datetime.today().strftime("%Y%m%d%H%M%S%f")


def logger(message):
    collectd.info("%s: %s" % (PLUGIN_NAME, message))


def thread_runner_func():
    global q
    global SAMPLING_RATE
    global UID
    while True:
        os.system("rm -rf /tmp/mysar{UID} ; rm -rf /tmp/myout{UID}".format(UID=UID))
        os.system("sar -A -o /tmp/mysar{UID} 1 1 > /dev/null 2>&1".format(UID=UID))
        os.system("sadf /tmp/mysar{UID} -d  -U -h -- -rSB  | tr -s ';' ',' > /tmp/myout{UID}".format(UID=UID))  # memory stats
        with open("/tmp/myout{UID}".format(UID=UID)) as f:
            lines = f.readlines()
        del lines[0]
        # del lines[0]
        data = {
            "lines": lines
        }
        q.put(data)
        time.sleep(SAMPLING_RATE - 1)


def config_func(config):
    interval_set = False
    metrics_set = False

    for node in config.children:
        key = node.key.lower()
        val = node.values[0]
        logger(key)
        logger(val)
        if key == "samplingrate":
            global SAMPLING_RATE
            SAMPLING_RATE = int(val)
            interval_set = True
        elif key == "metrics":
            global METRICS
            if str(val) == "all":
                METRICS = mapping.keys()
                metrics_set = True
            else:
                intermediary_str = str(val).split(",")
                new_metrics = []
                for metric in intermediary_str:
                    if metric in mapping.keys():
                        new_metrics.append(metric)
                METRICS = new_metrics
                metrics_set = True
        else:
            logger('Unknown config key "%s"' % key)

    if interval_set:
        logger("Using overridden interval: %s" % str(SAMPLING_RATE))
    else:
        logger("Using default interval: %s " % str(SAMPLING_RATE))

    if metrics_set:
        logger("Using overridden metrics %s" % str(METRICS))
    else:
        logger("Using default metrics: %s " % str(METRICS))


def read_func():
    # logger("In read_func. Queue empty: %s" % str(q.empty()) )
    global METRICS
    while not q.empty():
        data = q.get()
        for line in data["lines"]:
            for keyword in METRICS:
                fields = line.split(",")
                field_value = fields[mapping[keyword][0]]

                metric = collectd.Values()
                metric.plugin = PLUGIN_NAME

                # DS_TYPE_COUNTER, DS_TYPE_GAUGE, DS_TYPE_DERIVE or DS_TYPE_ABSOLUTE.
                # https://collectd.org/documentation/manpages/collectd-python.5.shtml
                # gauge expects data to be float. Needs 1 single value
                # counter expects data to be int
                # more: cat ./collectd/share/collectd/types.db
                # http://giovannitorres.me/using-collectd-python-and-graphite-to-graph-slurm-partitions.html
                metric.type = mapping[keyword][1]

                metric.type_instance = keyword
                metric.values = [field_value]
                # metric.host = 'OverwritenHostname'
                metric.dispatch()
                collectd.flush()


def init_func():
    set_uid()
    worker_thread = threading.Thread(target=thread_runner_func, args=())
    worker_thread.start()
    logger("Monitoring thread started")


# Hook Callbacks, Order is important!
collectd.register_config(config_func)
collectd.register_init(init_func)
collectd.register_read(read_func)
