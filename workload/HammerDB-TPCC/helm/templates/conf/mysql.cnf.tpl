{{/*
Expand to data
*/}}
{{- define "configMapOfMysql" }}
[mysqld]
default_authentication_plugin={{ .Values.MYSQL_DEFAULT_AUTHENTICATION_PLUGIN }} # mysql_native_password
# general
max_connections={{ .Values.MYSQL_MAX_CONNECTIONS }} # 4000
table_open_cache={{ .Values.MYSQL_TABLE_OPEN_CACHE }} # 8000
table_open_cache_instances={{ .Values.MYSQL_TABLE_OPEN_CACHE_INSTANCES }} # 16
back_log={{ .Values.MYSQL_BACK_LOG }} # 1500
default_password_lifetime={{ .Values.MYSQL_DEFAULT_PASSWORD_LIFETIME }} # 0
ssl={{ .Values.MYSQL_SSL }} # 0
performance_schema={{ .Values.MYSQL_PERFORMANCE_SCHEMA }} # OFF
max_prepared_stmt_count={{ .Values.MYSQL_MAX_PREPARED_STMT_COUNT }} # 128000
skip_log_bin={{ .Values.MYSQL_SKIP_LOG_BIN }} # 1
character_set_server={{ .Values.MYSQL_CHARACTER_SET_SERVER }} # latin1
collation_server={{ .Values.MYSQL_COLLATION_SERVER }} # latin1_swedish_ci
transaction_isolation={{ .Values.MYSQL_TRANSACTION_ISOLATION }} # REPEATABLE-READ
# files
innodb_file_per_table={{ .Values.MYSQL_INNODB_FILE_PER_TABLE }} # ON
innodb_log_file_size={{ .Values.MYSQL_INNODB_LOG_FILE_SIZE }} # 1024M
innodb_log_files_in_group={{ .Values.MYSQL_INNODB_LOG_FILES_IN_GROUP }} # 32G scale up per 100 warehouse ~ 4G
innodb_open_files={{ .Values.MYSQL_INNODB_OPEN_FILES }} # 4000
# buffers
innodb_buffer_pool_size={{ .Values.MYSQL_INNODB_BUFFER_POOL_SIZE }} # 96G scale up per 100 warehouse ~ 12G
innodb_buffer_pool_instances={{ .Values.MYSQL_INNODB_BUFFER_POOL_INSTANCES }} # 16
innodb_log_buffer_size={{ .Values.MYSQL_INNODB_LOG_BUFFER_SIZE }} # 64M
# tune
innodb_doublewrite={{ .Values.MYSQL_INNODB_DOUBLEWRITE }} # 0
innodb_thread_concurrency={{ .Values.MYSQL_INNODB_THREAD_CONCURRENCY }} # 0
innodb_flush_log_at_trx_commit={{ .Values.MYSQL_INNODB_FLUSH_LOG_AT_TRX_COMMIT }} # 0
innodb_max_dirty_pages_pct={{ .Values.MYSQL_INNODB_MAX_DIRTY_PAGES_PCT }} # 90
innodb_max_dirty_pages_pct_lwm={{ .Values.MYSQL_INNODB_MAX_DIRTY_PAGES_PCT_LWM }} # 10
join_buffer_size={{ .Values.MYSQL_JOIN_BUFFER_SIZE }} # 32K
sort_buffer_size={{ .Values.MYSQL_SORT_BUFFER_SIZE }} # 32K
innodb_use_native_aio={{ .Values.MYSQL_INNODB_USE_NATIVE_AIO }} # 1
innodb_stats_persistent={{ .Values.MYSQL_INNODB_STATS_PERSISTENT }} # 1
innodb_spin_wait_delay={{ .Values.MYSQL_INNODB_SPIN_WAIT_DELAY }} # 6
innodb_max_purge_lag_delay={{ .Values.MYSQL_INNODB_MAX_PURGE_LAG_DELAY }} # 300000
innodb_max_purge_lag={{ .Values.MYSQL_INNODB_MAX_PURGE_LAG }} # 0
innodb_checksum_algorithm={{ .Values.MYSQL_INNODB_CHECKSUM_ALGORITHM }} # none
innodb_io_capacity={{ .Values.MYSQL_INNODB_IO_CAPACITY }} # 4000
innodb_io_capacity_max={{ .Values.MYSQL_INNODB_IO_CAPACITY_MAX }} # 20000
innodb_lru_scan_depth={{ .Values.MYSQL_INNODB_LRU_SCAN_DEPTH }} # 9000
innodb_change_buffering={{ .Values.MYSQL_INNODB_CHANGE_BUFFERING }} # none
innodb_read_only={{ .Values.MYSQL_INNODB_READ_ONLY }} # 0
innodb_page_cleaners={{ .Values.MYSQL_INNODB_PAGE_CLEANERS }} # 4
innodb_undo_log_truncate={{ .Values.MYSQL_INNODB_UNDO_LOG_TRUNCATE }} # off
# perf special
innodb_adaptive_flushing={{ .Values.MYSQL_INNODB_ADAPTIVE_FLUSHING }} # 1
innodb_flush_neighbors={{ .Values.MYSQL_INNODB_FLUSH_NEIGHBORS }} # 0
innodb_read_io_threads={{ .Values.MYSQL_INNODB_READ_IO_THREADS }} # 16
innodb_write_io_threads={{ .Values.MYSQL_INNODB_WRITE_IO_THREADS }} # 16
innodb_purge_threads={{ .Values.MYSQL_INNODB_PURGE_THREADS }} # 4
innodb_adaptive_hash_index={{ .Values.MYSQL_INNODB_ADAPTIVE_HASH_INDEX }} # 0

### WSF optimized
# reduce spin lock wait, refer to https://dev.mysql.com/doc/refman/8.0/en/innodb-performance-spin_lock_polling.html
innodb_spin_wait_pause_multiplier={{ .Values.MYSQL_INNODB_SPIN_WAIT_PAUSE_MULTIPLIER }} # 50 -> 5
innodb_sync_spin_loops={{ .Values.MYSQL_INNODB_SYNC_SPIN_LOOPS }} # 30 -> 15
# Intel SSDs perform better with a 4096 Byte (4KB) alignment, refer to https://www.intel.com/content/dam/www/public/us/en/documents/white-papers/ssd-server-storage-applications-paper.pdf
innodb_page_size={{ .Values.MYSQL_INNODB_PAGE_SIZE }} # 16K - > 4K

# mysqltuner.pl recommendations
thread_cache_size={{ .Values.MYSQL_THREAD_CACHE_SIZE }}

###special configuration
{{- if ne .Values.DB_FS_TYPE "ramfs" }}
innodb_flush_method=O_DIRECT_NO_FSYNC
{{- end }}

{{- if eq .Values.DB_HUGEPAGE_STATUS "on" }}
large-pages
{{- end }}

{{- if .Values.DEBUG }}
log-error={{ .Values.MYSQL_LOG_DIR }}/{{ .Values.MYSQL_ERROR_LOG }}
{{- end }}
###

{{- end }}