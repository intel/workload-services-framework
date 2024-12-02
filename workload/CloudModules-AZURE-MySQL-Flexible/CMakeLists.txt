if(" SPR ICX MILAN " MATCHES " ${PLATFORM} " AND (BACKEND STREQUAL "terraform"))

    add_workload("hammerdb_mysql_flexible" SUT azure)
    add_testcase(${workload}_mysql_flexible_server_gated)
    add_testcase(${workload}_mysql_flexible_server_pkm)

endif()

