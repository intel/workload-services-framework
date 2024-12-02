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
--outlier <n>         Remove outliers beyond N-stdev.  
--params              List workload configurations.  
--sutinfo             List sutinfo information.   
--format list|xls-list|xls-ai|xls-inst|xls-table  
                      Specify the output format.
--var[1-9] <value>    Specify the spread sheet variables.   
--filter _(real|throughput)
                      Specify a trim filter to shorten spreadsheet name.  
--file <filename>     Specify the spread sheet filename. 
--uri                 Show the WSF portal URI if present.   
--intel_publish       Publish to the WSF dashboard. 
--export-trace        Re-run the trace export routines.  
--owner <name>        Set the publisher owner.  
--tags <tags>         Set the publisher tags.  
--recent              List KPIs for recent testcases.  
```

The `xls-ai` option writes the KPI data in the `kpi-report.xls` spread sheet as follows:

![image-ss-ai][image-ss-ai]
    
where `--var1=batch_size` `--var2=cores_per_instance` `--var3='*Throughput'` `--var4=Throughput_`.

The `xls-inst` option writes the KPI data in the `kpi-report.xls` spread sheet as follows:

![image-ss-inst][image-ss-inst]
    
The `xls-table` option writes the KPI data in the `kpi-report.xls` spread sheet as follows:

![image-ss-table][image-ss-table]
    
where `--var1=scale`, `--var2=sleep_time`. Optionally, you can specify `--var3` and `--var4` variables for multiple tables in the same spreadsheet.

[validate.sh]: ../../developer-guide/component-design/validate.md
[Cloud SUT Reuse]: #cloud-sut-reuse

[image-ss-ai]: ../../image/ss-ai.png
[image-ss-inst]: ../../image/ss-inst.png
[image-ss-table]: ../../image/ss-table.png
