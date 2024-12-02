
# CMakeLists.txt is the place to manage test cases. Think of a test case as 
# certain combination of configurable parameters of a workload. You need to 
# configure at least a common test case and a gated test case. The common 
# test case is used to measure the workload performance and the gated test 
# case is used to validate workload features at commit time. The gated test 
# case should be short to improve validation efficiency. It is recomended 
# that you define as many commonly used test cases as needed.  

# As a prerequisite to the workload build and test. You can test certain 
# conditions such as repository access permissions and license agreement. 
# See doc/cmakelists.txt for full documentation. The simple dummy workload 
# does not have such prerequisite.   

# It is recommendded to condition your workload build on the supported 
# platforms. The full list of supported platforms is in workload/platforms.  

if((" GNR SPR SRF ICX MILAN ROME " MATCHES " ${PLATFORM} ") AND (BACKEND STREQUAL "terraform"))

    add_workload(tpcc_mysql_aws SUT aws)
    set(DB_TYPE "mysql")
    add_testcase(${workload}_${DB_TYPE}_gated "${DB_TYPE}")
    add_testcase(${workload}_${DB_TYPE}_pkm "${DB_TYPE}")

    add_workload(tpcc_mssql_azure SUT azure)
    set(DB_TYPE "mssql")
    add_testcase(${workload}_${DB_TYPE}_gated "${DB_TYPE}")
    add_testcase(${workload}_${DB_TYPE}_pkm "${DB_TYPE}")

endif()

