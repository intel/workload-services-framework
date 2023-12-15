#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
import os
import sys
import socket
import shutil
import subprocess

instance_num = 1
install_base_path = "/"  #cassandra binary install base path: /cassandra0, /cassandra1
server_port = 30000
OP_COMPACT_WAIT = "compact_wait"
OP_CLEAN = "clean"

def delete_directory(directory_path):
    try:
        shutil.rmtree(directory_path)
        print(f"The directory '{directory_path}' has been deleted.")
        return 0
    except OSError as e:
        print(f"Error: Failed to delete the directory '{directory_path}'. {e}")

def delete_db_data():
    # Check if the folder exists and delete it
    folder_path = install_base_path
    
    i = 0
    message = ""
    while i < int(instance_num):
        folder_path = install_base_path + "/cassandra" + str(i) + "/current_data"
        if delete_directory(folder_path):
            message = message + " " + f"The folder '{folder_path}' does not exist."
        else:
            message = message + " " + f"The folder '{folder_path}' has been deleted."
        i = i + 1
    return message

def check_compaction_status():
    i = 0
    message = ""
    while i < int(instance_num):
        cmd = install_base_path + "/cassandra" + str(i) + "/bin/nodetool compactionstats"
        print("DEBUG-cmd:%s" %cmd)
        result = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        print(result.stdout)
        if result.stdout.find("Active compaction remaining time") != -1:
            #DB data is in compaction
            message = result.stdout
            return message
        i = i + 1
    message = "finished"
    return message

def handle_client_connection(client_socket):
    # Receive the message from the client
    message = client_socket.recv(1024).decode()
    print(f"Received message from client: {message}")

    #check operation code
    if OP_COMPACT_WAIT == message:
        response = check_compaction_status()
    if OP_CLEAN == message:
        response = delete_db_data()

    # Send the response back to the client
    client_socket.send(response.encode())

    # Close the connection
    client_socket.close()

def start_server():
    # Create a TCP/IP socket
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    # Define the server address and port
    server_address = ("", server_port)

    # Bind the socket to the server address and port
    server_socket.bind(server_address)

    # Listen for incoming connections (up to 1 connection)
    server_socket.listen(1)
    print("Server started. Waiting for connections...")

    while True:
        # Wait for a client connection
        client_socket, client_address = server_socket.accept()
        print(f"Accepted connection from {client_address}")

        # Handle the client connection in a separate thread
        handle_client_connection(client_socket)

if __name__ == '__main__':
    if sys.argv[1] is not None and sys.argv[1] != "":
        server_port = int(sys.argv[1])
    if sys.argv[2] is not None and sys.argv[2] != "":
        instance_num = int(sys.argv[2])
    if sys.argv[3] is not None and sys.argv[3] != "":
        install_base_path = sys.argv[3]

    start_server()