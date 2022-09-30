if(" ICX " MATCHES " ${PLATFORM} ")

    #############################################mysql#######################################
    add_workload("hammerdb_tpcc_mysql")
    foreach(fs "disk" "ramfs")
        foreach(hp "on" "off")
        # gated test
            if(NOT "${hp}" STREQUAL "on")
                add_testcase(${workload}_${fs}_hugepage_${hp}_gated "mysql" "${fs}" "${hp}")
            endif()

            # performance test
            add_testcase(${workload}_${fs}_hugepage_${hp} "mysql" "${fs}" "${hp}")
        endforeach()
    endforeach()
    # for pkm test case
    add_testcase(${workload}_disk_hugepage_off_pkm "mysql" "disk" "off")
endif()
