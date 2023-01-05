import collectd
import time
import os
import datetime

PLUGIN_NAME = "network_irq_affinity"
UID = "0"
IRQS = []


def set_uid():
    global UID
    UID = datetime.datetime.today().strftime("%Y%m%d%H%M%S%f")


def logger(message):
    collectd.info("%s: %s" % (PLUGIN_NAME, message))


def _GetIrqAffinity(irq):
    global UID
    os.system('cat /proc/irq/{irq}/smp_affinity > /tmp/nirqa{UID}{irq}.out'.format(irq=irq, UID=UID))
    with open("/tmp/nirqa{UID}{irq}.out".format(irq=irq, UID=UID)) as f:
        lines = f.readlines()
    return lines[0].strip()


def _GetIpInterfaceName():
    global UID
    os.system("ip link | awk -F: '$0 !~ \"lo|vir|wl|^[^0-9]\"{print $2a;getline}' > /tmp/nirqa%snm.out" % (UID))
    with open("/tmp/nirqa{UID}nm.out".format(UID=UID)) as f:
        lines = f.readlines()
    return lines[0].strip()


def _GetIpInterfaceIrqs():
    global UID
    os.system("cat /proc/interrupts | grep {name} | awk '{{print substr($1,1,length($1)-1)}}' > /tmp/nirqa{UID}irqs.out"
              .format(name=_GetIpInterfaceName(), UID=UID))
    with open("/tmp/nirqa{UID}irqs.out".format(UID=UID)) as f:
        lines = f.readlines()
    irqs = []
    for line in lines:
        irqs.append(line.strip())
    return irqs


def _GetCpusFromIrqAffinity(affinity):
    """returns a list of ints representing a single irq's associated CPUs"""
    """e.g. 00000000,10000000,00000000"""
    cpus = []
    position = 0
    for c in reversed(affinity):
        if c == ',':
            continue
        n = int(c, 16)
        for i in range(4):
            if n & 2 ** i:
                cpus.append((position * 4) + i)
        position += 1
    return cpus


def config_func(config):
    pass


def read_func():
    global IRQS
    for irq in IRQS:
        cpus = _GetCpusFromIrqAffinity(_GetIrqAffinity(irq))
        # logger(str(irq) + ":" + str(cpus))
        metric = collectd.Values()
        metric.plugin = PLUGIN_NAME
        metric.type = "count"
        metric.type_instance = irq
        metric.values = cpus
        metric.dispatch()
        collectd.flush()


def init_func():
    set_uid()

    global IRQS
    IRQS = _GetIpInterfaceIrqs()


# Hook Callbacks, Order is important!
collectd.register_config(config_func)
collectd.register_init(init_func)
collectd.register_read(read_func)
