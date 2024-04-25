## Overview
Database performance is one of the most important components for enterprise applications experience. The entire industry, be it web-based ecommerce, social media, cloud services or most other enterprise applications, they use databases.  [MySQL](https://www.mysql.com/products/community/) is the most popular open source RDBMS and has been running on Intel platforms for over 25 years. The latest version 8.0.23 was released January 2021. MySQL supports the use of multiple storage engines definable for table creation. 

### MySQL Configuration

We provide a configuration file that was tuned for performance with MySQL for general deployment scenarios : [mysql.cnf](mysql.cnf)

### Container Execution
This file can be mounted on the community version of MySQL using the command:

```
docker run -v $(pwd)/mysql.cnf:/etc/mysql/conf.d/mysql.cnf -e MYSQL_ROOT_PASSWORD=my-secret-pw  -d mysql
```
* Adjust the path of the local mysql.cnf if not in print working directory (PWD).
* Adjust the root password (my-secret-pw)

Some of optimizations are implemented as low-level kernel configuration. The --privileged flag can be used to run with escalated priviliges.

```
docker run --privileged -v $(pwd)/mysql.cnf:/etc/mysql/conf.d/mysql.cnf -e MYSQL_ROOT_PASSWORD=my-secret-pw -d mysql
```

Please see [Docker Documentation](https://docs.docker.com/reference/cli/docker/container/run/#privileged) on implications of running containers in privileged mode.

### References
* [Open-Source Database Xeon Tuning Guide](https://www.intel.com/content/www/us/en/developer/articles/guide/open-source-database-tuning-guide-on-xeon-systems.html) - Provides guideance for tuning MySQL for use case

* [MySQL Container](https://hub.docker.com/_/mysql) - Official MySQL container documentation

* [MySQL Container Source Code](https://github.com/docker-library/mysql/) - Source code for official MySQL container
