#!/usr/bin/python
from __future__ import with_statement

from BaseHTTPServer import HTTPServer, BaseHTTPRequestHandler
from SocketServer import ThreadingMixIn
import os
import sys
import time
import pickle
import random
import hashlib
import argparse
import threading
import numpy as np

class WebPageParam( object ):
    """ Class to store the parameters to use when constructing a web page """
    
    def __init__( self, obj_dist="fixed", x=0.5, y=10.0 ):
        self.obj_dist = obj_dist
        self.x = x
        self.y = y
        self.obj_size = 1048576
        self.x_n = 0
        self.x_actual = 0.0
        self.y_actual = 0.0
        self.tot_demand = 0
        self.default_web_page_sizes = [
            32768,   # 32 KB
            65536,   # 64 KB
            262144,  # 256 KB
            524288,  # 512 KB
            786432,  # 768 KB
            1048576, # 1 MB
            2831155, # 2.7 MB
        ]        
        self.mu = 1431961.5 # Mid-point of default web page sizes
        self.index_mu = 5
        self.sigma = 1.0
        self.a = 2.0

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
        web_page_param_file = os.path.join( os.path.dirname(os.path.realpath(__file__)), "web_page_param.pickle" )
        if os.path.exists( web_page_param_file ):
            obj_size = self.select_obj_size( web_page_param_file )
        else:
            obj_size = self.extract_obj_size( )
        web_page = self.create_web_page( obj_size )
        md5 = hashlib.md5( )
        md5.update( b"%s %s %s" % (self.command, self.path, self.request_version) )
        self.send_response( 200 )
        self.send_header( "Cache-Control", "max-age=31536000" ) # 180
        self.send_header( "Content-Length", "%d" % (len(web_page)) )
        self.send_header( "Content-type", "text/plain" )
        self.send_header( "Etag", "\"" + md5.hexdigest() + "\"" )
        # Note: Date is included by default in response header
        self.end_headers( )
        self.wfile.write( web_page )
        
        return

    def create_web_page( self, page_size ):
        """ Generate web page content using all 0's.
        """
        sub_str = "0"
        content = sub_str * int( np.ceil((page_size / float(len(sub_str)))) )
        if len( content ) > page_size:
            content = content[:page_size]
        
        return content

    #def log_message( self, format, *args):
    #    """ Suppress logging """
    #    return

    def extract_obj_size( self ):
        """ Extract object size from URL
        """
#        obj_sizes = [ 1024,    # HLS manifest, v1, 1KB
#                      8388608, # HLS video, v1, 8MB
#                      131072,  # HLS audio, v1, 128KB
#                      1024,    # DASH medium manifest, v1-3, 1KB
#                      4070400, # DASH medium video, v1-3, 6MB
#                      73728,   # DASH medium audio, v1-3, 288KB
#                      1024,    # DASH high manifest, v1-3, 1KB
#                      6291456, # DASH high video, v1-3, 6MB
#                      294912,  # DASH high audio, v1-3, 288KB
#                    ]
        obj_sizes = [ 1024,    # HLS manifest, v1, 1KB
                      4070400, # HLS video, v1, 8MB
                      294912,  # HLS audio, v1, 128KB
                      1024,    # DASH medium manifest, v1-3, 1KB
                      4070400, # DASH medium video, v1-3, 6MB
                      294912,   # DASH medium audio, v1-3, 288KB
                      1024,    # DASH high manifest, v1-3, 1KB
                      4070400, # DASH high video, v1-3, 6MB
                      294912,  # DASH high audio, v1-3, 288KB
                    ]
        req_len = 5
        v1_boundary = 8621
        v2_v3_objects = 6

        path_sub_strings = self.path.split( '/' )
        try:
            obj_size_index = int( path_sub_strings[-1][-req_len:] )
            if obj_size_index > v1_boundary:
                # Adjust for variant 2 and 3, which does not include HLS
                obj_sizes = obj_sizes[-v2_v3_objects:]
            obj_size = obj_sizes[obj_size_index % len(obj_sizes)]
        except ValueError, IndexError:
            obj_size = 0

        return obj_size

    def select_obj_size( self, web_page_param_file ):
        """ Select object size based on distribution
        """          
        with open( web_page_param_file, "rb" ) as input_file:
            web_page_param = pickle.load( input_file )            
        if ( web_page_param.obj_dist == "fixed" ):
            return 3024
        else:
            if ( web_page_param.obj_dist == "gauss" ):
                index = int( round(np.random.normal(loc=web_page_param.index_mu, scale=web_page_param.sigma)) )
                index = max( 0, min(index, len(web_page_param.default_web_page_sizes) - 1) )
                return web_page_param.default_web_page_sizes[index]
            elif ( web_page_param.obj_dist == "zipf" ):
                index = np.random.zipf( web_page_param.a ) % len( web_page_param.default_web_page_sizes )
                return  web_page_param.default_web_page_sizes[index]
            elif ( web_page_param.obj_dist == "real" ):
                obj_size = random.choice( web_page_param.default_web_page_sizes )
                if web_page_param.x_actual < web_page_param.x:
                    obj_size = max( web_page_param.default_web_page_sizes )
                    y_perc_tot = float( web_page_param.tot_demand ) * ( web_page_param.y / 100.0 )
                    if ( y_perc_tot < float(max(web_page_param.default_web_page_sizes)) ):
                        obj_size = min( web_page_param.default_web_page_sizes, key=lambda a : abs(float(a) - y_perc_tot) )
                    if ( web_page_param.obj_size == obj_size ):
                        web_page_param.x_n += 1
                    else:
                        web_page_param.x_n = 1                       
                    web_page_param.obj_size = obj_size
                web_page_param.tot_demand += obj_size
                web_page_param.x_actual = float( web_page_param.x_n * web_page_param.obj_size ) / web_page_param.tot_demand
                with open( web_page_param_file, "wb" ) as output_file:
                    pickle.dump( web_page_param, output_file, protocol=pickle.HIGHEST_PROTOCOL )           
                return obj_size

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

    script_dir = os.path.dirname( os.path.realpath(__file__) )
    web_page_param_file = os.path.join( script_dir, "web_page_param.pickle" )
        
    parser = argparse.ArgumentParser( description="Generates a web server that serves up objects according to the specified distribution." )
    parser.add_argument( "--host", dest="host_name", default="localhost",
                         help="Host name/IP address to use for the server" )
    parser.add_argument( "--port", dest="port_number", default=8888, type=port_type,
                         help="Port number to use for the server" )        
    parser.add_argument( "--obj-dist", dest="obj_dist", choices=["fixed", "gauss", "zipf", "real", "user"], default="fixed",
                         help="Object Distribution Type" )
    parser.add_argument( "--perc-obj", dest="x", type=float, default=0.5,
                         help="Set percentage of objects for real distribution" )
    parser.add_argument( "--perc-tot", dest="y", type=float, default=10.0,
                         help="Set percentage of total demand for real distribution" )
    args = parser.parse_args()

    if args.obj_dist == "real":
        web_page_param = WebPageParam( obj_dist=args.obj_dist, x=args.x, y=args.y )
    else:
        web_page_param = WebPageParam( args.obj_dist )
        if ( args.obj_dist == "zipf" ):
            web_page_param.default_web_page_sizes.append( 0 ).reverse( )    

    if args.obj_dist != "user":
        with open( web_page_param_file, "wb" ) as output_file:
            pickle.dump( web_page_param, output_file, protocol=pickle.HIGHEST_PROTOCOL )
    else:
        if os.path.exists( web_page_param_file ):
            os.remove( web_page_param_file )

    server = ThreadedHTTPServer( (args.host_name, args.port_number), Handler )
    sys.stdout.write( "[%s]: Web Server Started - %s:%s\n" % (time.asctime(), args.host_name, args.port_number) )
    try:
        server.serve_forever( )
    except KeyboardInterrupt:
        server.server_close( )
    sys.stdout.write( "[%s]: Web Server Stopped - %s:%s\n" % (time.asctime(), args.host_name, args.port_number) )
    if os.path.exists( web_page_param_file ):
        os.remove( web_page_param_file )

    return 0

if __name__ == '__main__':
    sys.exit( main(sys.argv) )
