#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

import os
import sys
import time
import json
import stl_path
import argparse
from ast import Raise
from struct import pack
from trex.stl.api import *
import warnings

warnings.filterwarnings("ignore")

def get_streams (pkt_size, src_str, dst_str, stream_num):
    stream_list = list()
    streams = list()
    for i in range(stream_num):
        src_list=src_str.split(".")
        src_list[-1]=str(i+1)
        src_str=".".join(src_list)
        base_pkt = Ether()/IP(src=src_str, dst=dst_str)/TCP(dport=5678 + i,sport=8765 + i)
        paddings = max(0, pkt_size - len(base_pkt) - 4) * 'x'
        pkt = STLPktBuilder(pkt=base_pkt/paddings)
        s = STLStream( packet = pkt, mode = STLTXCont())
        stream_list.append(s)

    streams.extend(stream_list)
    return streams

def ipv4_continuous (pkt_size, duration, src, dst, stream_num):

    port_a = 0
    rate = "100%"
    c = STLClient()
    passed = True

    try:
        # create two bursts and link them
        s = get_streams(pkt_size, src, dst, stream_num)

        # connect to server
        c.connect()

        # prepare our ports
        c.reset(ports = [port_a])
        c.set_port_attr(ports=[port_a], promiscuous=True)
        c.remove_all_streams(ports=[port_a])
        
        # add streams to ports
        c.add_streams(s, ports=[port_a])

        # check link status
        while(c.get_port_attr(port_a)['link'] != 'UP'):
            #print("port_a link:",c.get_port_attr(port_a)['link'])
            print("link is down, wait 10s and try again.")
            time.sleep(10)
        
        c.clear_stats()
        # print(duration)
        c.start(ports = [port_a], mult = rate, duration=duration)


        time_start = time.monotonic()
        # wait_on_traffic fails if duration stretches by 30 seconds or more.
        # TRex has some overhead, wait some more.
        time.sleep(duration)
        c.stop()
        time_stop = time.monotonic()
        approximated_duration = time_stop - time_start

        # Read the stats after the traffic stopped (or time up).
        stats = c.get_stats()

        if c.get_warnings():
            for warning in c.get_warnings():
                print(warning)
        # Now finish the complete reset.
        c.reset()

        print(u"##### Statistics #####")

        lost_a = stats[port_a][u"opackets"] - stats[port_a][u"ipackets"]
        total_sent = stats[0][u"opackets"]
        total_rcvd = stats[0][u"ipackets"]
        print(f"packets lost one to one port: {lost_a} pkts")

    except STLError as e:
        passed = False
        print(e)

    finally:
        if c:
            c.disconnect()

    if passed and not c.get_warnings():
        tx_pps = stats['total']['tx_pps']/1000/1000
        tx_bps = stats['total']['tx_bps']/1000/1000/1000
        tx_bps_L1 = stats['total']['tx_bps_L1']/1000/1000/1000
        rx_pps = stats['total']['rx_pps']/1000/1000
        rx_bps = stats['total']['rx_bps']/1000/1000/1000
        rx_bps_L1 = stats['total']['rx_bps_L1']/1000/1000/1000

        print("\nTestcase passed with results:")
        print("All Ports TX Throughput (Mpps): %.2f" %(tx_pps))
        print("All Ports TX_L1 Throughput (Gbps): %.2f" %(tx_bps_L1))
        print("All Ports TX Throughput (Gbps): %.2f" %(tx_bps))
        print("All Ports RX Throughput (Mpps): %.2f" %(rx_pps))
        print("All Ports RX_L1 Throughput (Gbps):  %.2f" %(rx_bps_L1))
        print("All Ports RX Throughput (Gbps): %.2f" %(rx_bps))

    else:
        print("\nTestcase failed")

def main():
    parser = argparse.ArgumentParser( description="TRex to send packets" )
    parser.add_argument( "--packet-size", dest="pkt_size", type=int, default=64, help="Sent packet size" )
    parser.add_argument( "--duration", dest="duration", type=int, default=64, help="Duration in second" )
    parser.add_argument( "--src", dest="src", default=64, help="Source ip address" )
    parser.add_argument( "--dst", dest="dst", default=64, help="Destination ip address" )
    parser.add_argument( "--stream-num", dest="stream_num", type=int, default=1, help="Sent stream num")
    args = parser.parse_args()

    # send packets
    ipv4_continuous (pkt_size = args.pkt_size, duration = args.duration, src = args.src, dst = args.dst, stream_num = args.stream_num)

if __name__ == "__main__":
    main()
