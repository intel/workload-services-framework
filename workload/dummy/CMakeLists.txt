
# CMakeLists.txt is the place to manage test cases. Think of a test case as certain 
# combination of configurable parameters of a workload. You need to configure at 
# least a common test case  and a gated test case. The common test case is used to 
# measure the workload performance and the gated test case is used to validate 
# workload features at commit time. The gated test case should be short to improve 
# validation efficiency. It is recomended that you define as many commonly used 
# test cases as needed.  

# As a prerequisite to the workload build and test. You can test certain conditions
# such as repository access permissions and license agreement. See doc/cmakelists.txt
# for full documentation. The simple dummy workload does not have such prerequisite.   

# It is recommendded to condition your workload build on the supported platforms.
# The full list of supported platforms is in workload/platforms.  
if(" ICX " MATCHES " ${PLATFORM} ")

    # The add_workload function defines a workload. The workload name must be unique 
    # and do not have special characters except _. You can specify additional 
    # constraints as additional parameters such as license constraints and platform 
    # constraints. See doc/cmakelists.txt.md for details. 
    add_workload("dummy")

    # The add_testcase function adds a test case, which will be executed through
    # validate.sh. The test case name must be unique and avoid any special 
    # characters except _. Any arguments to add_testcase will be passed literally 
    # to validate.sh. See CMakeLists.txt for details. You can define any number
    # of test cases here but there are special test cases that every workload 
    # must have as follows: 

    add_testcase(${workload}_pi 2000)

    # Define at least a gated test case for commit validation. The gated test case 
    # must be short and cover most of the workload features.  
    add_testcase(${workload}_gated 1000)

endif()

# For workloads with multiple versions, repeat the definitions to support multiple
# versions. The recommendation is to suffix the versions as part of the workload 
# name.  

