#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
from ansible.plugins.callback import CallbackBase
from ansible.playbook.block import Block
from ansible.playbook.task import Task
import uuid

DOCUMENTATION = '''
    name: error_summary
    type: aggregate
    short_description: Summarizes errors and unreachable hosts at the end of a playbook run
    version_added: historical
    description:
        - This callback plugin provides a summary of failed tasks and unreachable hosts at the end of a playbook run.
        - It collects information about errors throughout the playbook execution and displays them in a consolidated format.
    requirements:
      - set as error_summary in configuration
'''

class CallbackModule(CallbackBase):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'aggregate'
    CALLBACK_NAME = 'error_summary'

    def __init__(self):
        super(CallbackModule, self).__init__()
        self.failed_tasks = {}
        self.rescue_state = False

    def v2_playbook_on_task_start(self, task, is_conditional):
        
        if isinstance(task._parent, Block):
            if task in task._parent.rescue:
                self.rescue_state = True
            elif task in task._parent.always:
                self.rescue_state = False
            elif self._is_start_of_block(task):
                self.rescue_state = False

    def v2_playbook_on_cleanup_task_start(self, task):
        self.rescue_state = False

    def v2_playbook_on_handler_task_start(self, task):
        self.rescue_state = False

    def _is_start_of_block(self, task):
        return task._parent.block and task == task._parent.block[0]

    def v2_runner_on_failed(self, result, ignore_errors=False):
        self._handle_result(result, 'failed', ignore_errors)

    def v2_runner_on_ok(self, result):
        self._handle_result(result, 'ok')

    def _handle_result(self, result, status, ignore_errors=False):
        task = result._task
        host = result._host
        task_key = (task._uuid, host.name)
        
        if self.rescue_state:
            self._remove_failed_tasks_for_host(host)

        if status == 'failed' and not ignore_errors:
            self.failed_tasks[task_key] = {
                'task': task,
                'host': host,
                'result': result,
                'in_rescue': self.rescue_state
            }

    def _remove_failed_tasks_for_host(self, host):
        keys_to_remove = [key for key, task_info in self.failed_tasks.items()
                          if task_info['host'] == host and not task_info['in_rescue']]
        for key in keys_to_remove:
            del self.failed_tasks[key]

    def v2_playbook_on_stats(self, stats):
        if self.failed_tasks:
            self._display.banner("FAILED TASKS SUMMARY")
            for task_info in self.failed_tasks.values():
                task = task_info['task']
                host = task_info['host']
                result = task_info['result']

                self._display.display(f"\nTask: {task.get_name()}")
                self._display.display(f"Host: {host.name}")
                self._display.display(f"Task path: {task.get_path()}")
                self._display.display(f"Error: {self._get_error_message(result._result)}\n")

    def _get_error_message(self, result):
        if 'stderr' in result:
            return result['stderr']
        elif 'msg' in result:
            return result['msg']
        else:
            return "Unknown error occurred"