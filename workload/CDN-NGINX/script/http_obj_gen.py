#!/usr/bin/python3
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn
import sys
import time
import hashlib
import argparse
import math
import socket


class Handler( BaseHTTPRequestHandler ):
    """ Customized request handler to serve up variable sized web pages
    """

    def do_HEAD( self ):
        """ Respond to a HEAD request. """
        self.send_response( 200 )
        self.send_header( "Cache-Control", "max-age=31536000" ) # 180
        self.send_header( "Content-type", "text/plain" )
        self.end_headers( )

    def do_GET( self ):
        """ Respond to a GET request. """
        obj_size = self.extract_obj_size( )
        web_page = self.create_web_page( obj_size )
        sha256 = hashlib.sha256( )
        sha256.update( "%s %s %s".format(self.command, self.path, self.request_version).encode() )
        self.send_response( 200 )
        self.send_header( "Cache-Control", "max-age=31536000" ) # 180
        self.send_header( "Content-Length", "%d" % (len(web_page)) )
        self.send_header( "Content-type", "text/plain" )
        self.send_header( "Etag", "\"" + sha256.hexdigest() + "\"" )
        # Note: Date is included by default in response header
        self.end_headers( )
        self.wfile.write( web_page.encode() )
        
        return

    def create_web_page( self, page_size ):
        """ Generate web page content using all 0's.
        """
        sub_str = "0"
        content = sub_str * int( math.ceil((page_size / float(len(sub_str)))) )
        if len( content ) > page_size:
            content = content[:page_size]
        
        return content

    #def log_message( self, format, *args):
    #    """ Suppress logging """
    #    return

    def extract_obj_size( self ):
        """ Extract object size from URL
        """
        path_sub_strings = self.path.split( '/' )
        try:
            size_str = path_sub_strings[-1].split('?')[0].lstrip('_').rstrip('object')
            if size_str[-1] == 'k':
                return int( size_str[:-1] ) * 1024
            elif size_str[-1] == 'm':
                return int( size_str[:-1] ) * 1048576
            else:
                return 1048576
        except (ValueError, IndexError):
            return 1048576

class ThreadedHTTPServer( ThreadingMixIn, HTTPServer ):
    """ Handle each request in a separate thread. """
    
def port_type( x ):

    min_port = 80
    max_port = 65535    

    x = int( x )
    if x < min_port:
        raise argparse.ArgumentTypeError( "Minimum port is %d" % (min_port) )
    elif x > max_port:
        raise argparse.ArgumentTypeError( "Maximum port is %d" % (max_port) )        
    
    return x
    
def main( argv ):
    hostname = socket.gethostname()
    ipaddr = socket.gethostbyname(hostname)
        
    parser = argparse.ArgumentParser( description="Generates a web server that serves up objects according to the specified distribution." )
    parser.add_argument( "--host", dest="host_name", default=ipaddr,
                         help="Host name/IP address to use for the server" )
    parser.add_argument( "--port", dest="port_number", default=8888, type=port_type,
                         help="Port number to use for the server" )        
    args = parser.parse_args()

    server = ThreadedHTTPServer( (args.host_name, args.port_number), Handler )
    sys.stdout.write( "[%s]: Web Server Started - %s:%s\n" % (time.asctime(), args.host_name, args.port_number) )
    try:
        server.serve_forever( )
    except KeyboardInterrupt:
        server.server_close( )
    sys.stdout.write( "[%s]: Web Server Stopped - %s:%s\n" % (time.asctime(), args.host_name, args.port_number) )

    return 0

if __name__ == '__main__':
    sys.exit( main(sys.argv) )
