
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

include(cmake/${PLATFORM}.cmake OPTIONAL)

# For workloads with multiple versions, repeat the definitions to support multiple
# versions. The recommendation is to suffix the versions as part of the workload 
