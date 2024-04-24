## Overview

### MySQL Configuration

We provide a configuration file that was tuned for performance with MySQL for general deployment scenarios : [mysql.cnf](mysql.cnf)

This file can be mounted on the community version of MySQL using the command:

```
docker run -v $(pwd)/mysql.cnf:/etc/mysql/conf.d/mysql.cnf -d mysql
```
Adjust the path of the local mysql.cnf if not in print working directory (PWD).

Some of optimizations are implemented as low-level kernel configuration. The --privileged flag can be used to run with escalated priviliges.

```
docker run --privileged -v $(pwd)/mysql.cnf:/etc/mysql/conf.d/mysql.cnf -d mysql
```

Please see [Docker Documentation](https://docs.docker.com/reference/cli/docker/container/run/#privileged) on implications of running containers in privileged mode.

### References
* [Open-Source Database Xeon Tuning Guide](https://www.intel.com/content/www/us/en/developer/articles/guide/open-source-database-tuning-guide-on-xeon-systems.html) - Provides guideance for tuning MySQL for use case


* [MySQL Container](https://hub.docker.com/_/mysql) - Official MySQL container documentation

* [MySQL Container Source Code](https://github.com/docker-library/mysql/) - Source code for official MySQL container
