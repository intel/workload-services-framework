# List KPIs

`list-kpi.sh` is used to display KPI results of a workload execution by scanning ctest log files.

Execute this command in the workload folder to fetch KPIs:

```shell
./list-kpi.sh --all <testcase>
```

## Options for `list-kpi.sh`

<!-- TODO: Expand this section-->

```text
Usage: [options] [logs-directory]
--primary             List only the primary KPI.  
--all                 List all KPIs.  
--params              List workload configurations.  
--sutinfo             List sutinfo information.   
--format list|xls-list
                      Specify the output format.
--file <filename>     Specify the spread sheet filename. 
--uri                 Show the WSF portal URI if present.   
--intel_publish       Publish to the WSF dashboard. 
--export-trace        Re-run the trace export routines.  
--owner <name>        Set the publisher owner.  
--tags <tags>         Set the publisher tags.  
--recent              List KPIs for recent testcases.  
```
