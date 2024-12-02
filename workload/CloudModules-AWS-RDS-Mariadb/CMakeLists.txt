if(" SPR ICX MILAN " MATCHES " ${PLATFORM} " AND (BACKEND STREQUAL "terraform"))

    add_workload("hammerdb_rds_mariadb" SUT aws)
    add_testcase(${workload}_server_gated)
    add_testcase(${workload}_server_pkm)

endif()

