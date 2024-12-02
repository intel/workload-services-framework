# Parsing KPIs

The `kpi.sh` script parses the validation output and exports a set of key/value pairs to represent the workload performance.

## Output format

The following is some example of the KPI data:

```text
# this is a test                        ## Optional comments
## threads: 4                           ## Tunable parameters overwrite
throughput: 123.45                      ## Simple key/value
throughput (op/s): 123.45               ## Key, unit (in parentheses) and value
*throughput (images/s): 123.45          ## Primary KPI for regression reporting
throughput: 123.45  # This is a tooltip ## Comment shown as toolkit in UI
```

> Please note that it is crucial that the decimal separator is a point (`.`), not a comma (`,`).

## Parsing the output

To avoid introducing additional software dependencies, it is recommended to use `gawk` to parse the validation logs and format the output.

The validation output is assumed to be stored at 1 layer under the current directory. The `kpi.sh` example is as follows:

```shell
#!/bin/bash -e

awk '
{
   # KPI parsing script
}
' */output.logs 2>/dev/null || true
```

where `2>/dev/null` suppresses any error message if `*/output.logs` does not exist, and `||true` makes the `kpi.sh` always returns an ok status.

> Check [The GNU AWK User's Guide][gawk manual] for more information on how to write a parsing script using `gawk`.

[gawk manual]: https://www.gnu.org/software/gawk/manual/gawk.html