#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
import sys
import socket
import re
import time

data_path = '/cassandra' #detault path
server_name = 'cassandra-server-service'
server_port = 30000  #default port
OP_COMPACT_WAIT = "compact_wait"
OP_CLEAN = "clean"

def is_valid_ip(ip):
    pattern = r'^(\d{1,3}\.){3}\d{1,3}$'
    return re.match(pattern, ip)

def send_message(message):
    if not is_valid_ip(server_name):
        service_ip = socket.gethostbyname(server_name)
    else:
        service_ip =  server_name
    print(f"service_ip: {service_ip}")
    # Create a TCP/IP socket
    client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    # Define the server address and port
    server_address = (service_ip, server_port)

    # Connect to the server
    client_socket.connect(server_address)

    # Send the message to the server
    client_socket.send(message.encode())

    # Receive the response from the server
    response = client_socket.recv(1024).decode()
    print(f"Response from server: {response}")

    # Close the connection
    client_socket.close()

    return response

def data_clean():
    message = OP_CLEAN
    send_message(message)

def data_compaction_wait():
    message = OP_COMPACT_WAIT
    wait = 1
    #wait for compaction finished
    while wait:
        response = send_message(message)
        if "finished" == response:
            wait = 0
        else:
            time.sleep(60) #sleep 60s

if __name__ == '__main__':
    if sys.argv[1] is not None and sys.argv[1] != "":
        #operation:
        #          compact_wait : wait database compaction finished.
        #          clean        : clean DB data after testing finished.
        op = sys.argv[1]
    if sys.argv[2] is not None and sys.argv[2] != "":
        server_name = sys.argv[2]
    if sys.argv[3] is not None and sys.argv[3] != "":
        server_port = int(sys.argv[3])

    if OP_COMPACT_WAIT == op:
        data_compaction_wait()
    if OP_CLEAN == op:
        data_clean()
