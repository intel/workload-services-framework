### Introduction

This is a dummy workload. It is used to quickly test the validation pipeline and also an example of any new workload.   

### Test Case

There are two defined test cases: 
- `pi`: This test case calculate `PI` to the 2000 digits.  
- `gated`: This test case validates the dummy workload for commit validation.  

### Docker Image

The workload contains a single docker image: `dummy`. Configure the docker image with the environment variable `SCALE`: The `PI` precision digits.  

```
mkdir -p logs
id=$(docker run --rm --detach -e SCALE=2000 dummy)
docker exec $id cat /export-logs | tar xf - -C logs
docker rm -f $id
```

### KPI

Run the [`kpi.sh`](kpi.sh) script to generate the KPIs. The KPI script uses the following command line options:  

```
Usage: <scale>
```

The following KPI is defined:
- `throughput`: The workload throughput value in the unit of digits/second.  

### Index Info

- Name: `dummy`
- Category: `Synthetic`
- Platform: `ICX`
- keywords:

### See Also

- [Workload Elements](../../doc/workload.md)   

