#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
import csv
import os
import sys
import xlsxwriter
import uuid

DEFAULT_CSV_NAME = 'Summary Results'
            
            
class ResultHandler():
    
    def __init__(self, remote_path, path):
        self.remote_path = remote_path
        self.path = path
    
        
class xlsx(ResultHandler):
    
    def __init__(self, remote_path=None, path=None, ):
        self.remote_path = remote_path
        self.run_uri = str(uuid.uuid4())[-8:]
        if path == None:
            path = 'ffmpeg_{}.xlsx'.format(self.run_uri)
            self.path = path
        super().__init__(remote_path,path)
        self.workbook = xlsxwriter.Workbook(path)
        self.worksheets = {}
        self.main_worksheet = self.workbook.add_worksheet(DEFAULT_CSV_NAME)
        self.worksheets[DEFAULT_CSV_NAME] = {}
        self.worksheets[DEFAULT_CSV_NAME]['sheet'] = self.main_worksheet
        self.worksheets[DEFAULT_CSV_NAME]['row'] = 0
        self.worksheet_row = 0
        self.last_sample_row = 0
        
    
    def write(self, string, sheet=None):
        row = None
        worksheet = None
        if sheet is not None:
            if sheet not in self.worksheets:
                new_worksheet = self.workbook.add_worksheet(sheet)
                self.worksheets[sheet] = {}
                self.worksheets[sheet]['sheet'] = new_worksheet
                self.worksheets[sheet]['row'] = 0
                row = 0
                worksheet = new_worksheet
            else:
                worksheet = self.worksheets[sheet]['sheet'] 
                row = self.worksheets[sheet]['row']
        else:
            sheet = DEFAULT_CSV_NAME
            row = self.worksheets[DEFAULT_CSV_NAME]['row']
            worksheet = self.main_worksheet                              
        lines = string.split('\n')
        for line in lines:
            item = line.split(',')
            for i in range(len(item)):
                worksheet.write(row, i, item[i])
            row += 1
        self.worksheets[sheet]['row'] = row
    
    def close(self):
        self.workbook.close()
        
                
class CSV(ResultHandler):
    def __init__(self,remote_path=None,path=None):
        super().__init__(remote_path, path)
        self.sys_info = []
        self.data = []
        os.system('mkdir -p {}'.format(os.path.dirname(os.path.realpath(remote_path))))
        os.system('echo \'\' > {}\n'.format(self.remote_path))

    def write(self,string, sheet=None):
        if sheet is DEFAULT_CSV_NAME or sheet is None:
            self.write_remote(string)
        
    def write_remote(self, string):
        os.system('echo \'{}\' >> {}'.format(string, self.remote_path))
    
    def close(self):
        #self.vm.PullFile(self.path, self.remote_path)
        pass
    
    def CreateDashboard(self):
        pass

class ResultsCollection:
    def __init__(self, *args):
        self.handlers = []
        for arg in args:
            self.handlers.add(arg)
    
    def add(self, handler):
        if self.handlers:
            self.handlers.append(handler)
        else:
            self.handlers = [handler]
    
    def write(self, string, sheet=None):
        for handler in self.handlers:
            handler.write(string, sheet)
            
    def close(self):
        for handler in self.handlers:
            handler.close()

    def GetExcel(self):
        excels = []
        for handler in self.handlers:
            if type(handler) is xlsx:
                excels.append(handler)
        return excels

    def GetCsv(self):
        csvs = []
        for handler in self.handlers:
            if type(handler) is CSV:
                csvs.append(handler)
        return csvs
    
    def GetResults(self, results_type=None):
        if results_type is None:
            return self.handlers
        else:
            toReturn = []
            for handler in self.handlers:
                if type(handler) is results_type:
                    toReturn.append(handler)
