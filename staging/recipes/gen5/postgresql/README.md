## Overview
Database performance is one of the most important components for enterprise applications experience. The entire industry, be it web-based ecommerce, social media, cloud services or most other enterprise applications, they use databases.  [PostgreSQL](https://www.postgresql.org/)  is the fastest growing database in popularity for RDBMS and provides the foundation for many enhanced database releases such as Citus, Greenplum and EnterpriseDB. 

### PostgreSQL Configuration

We provide a configuration file that was tuned for performance with PostgreSQL for general deployment scenarios : [postgresql.conf](postgrsql.conf)

### Container Execution
This file can be mounted on the community version of PostgreSQL using the command:

```
docker run -v  $(pwd)/postgresql.conf:/etc/postgresql/postgresql.conf -e POSTGRES_PASSWORD=mysecretpassword -d postgres -c config_file=/etc/postgresql/postgresql.conf
```

* Adjust the path of the local postgres.conf if not in print working directory (PWD).
* Adjust the root password (mysecretpassword )

Some of optimizations are implemented as low-level kernel configuration. The --privileged flag can be used to run with escalated priviliges.


```
docker run --privileged -v  $(pwd)/postgresql.conf:/etc/postgresql/postgresql.conf -e POSTGRES_PASSWORD=mysecretpassword  -d postgres -c config_file=/etc/postgresql/postgresql.conf
```

Please see [Docker Documentation](https://docs.docker.com/reference/cli/docker/container/run/#privileged) on implications of running containers in privileged mode.

### References
* [Open-Source Database Xeon Tuning Guide](https://www.intel.com/content/www/us/en/developer/articles/guide/open-source-database-tuning-guide-on-xeon-systems.html) - Provides guideance for tuning PostgreSQL for use case

* [PostgreSQL Container](https://hub.docker.com/_/postgres) - Official PostgreSQL container documentation

* [PostgreSQL Container Source Code](https://github.com/docker-library/postgres) - Source code for official PostgreSQL container
