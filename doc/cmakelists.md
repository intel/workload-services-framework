
### Workload CMakeLists.txt

The `CMakeLists.txt` defines actions in `cmake`: build and test. Let us start with a simple example:  

```
add_workload("dummy")
add_testcase(${workload})
```

The `add_workload` function defines `cmake` build rules for a workload. The name must be lower cased as a convention and does not contain any special characters with the exception of `_`. It is recommedded to append the version info to indicate the implementation versioning. The function also defines a parent-scope variable `workload` with the same name that any subsequent function can use.   

The `add_testcase` function defines a test case. You may define multiple test cases, each with a unique name and some configuration parameters. Internally, this gets routed to the `validate.sh` script with the specified parameters. (There is no argument in the above example.) The validation results are saved to the corresponding `logs-$workload` directory under the build tree.  

Note that the name of any `cmake` target must be unique across all workloads. Thus it is usually a concatenation of platform, feature, workload and configuration.   

### Special Test Cases

The test case name should be descriptive for the workload test conditions. For example, use `_1n` to indicate that the workload runs on a single worker node, and `_3n` to indicate that the workload runs on multiple worker nodes.  

The following test case suffixes are reserved: 
- `_gated`: A test case suffixed with `_gated` is designed for CI commit validation. The test case is expected to be a quick test of the workload software stack. To improve CI efficiency, design the test case such that the workload completes within 5 minutes.  

### Licensing Terms

If the workload requires the user to agree to any license terms, use the `check_license` function. The function prompts the user for license agreement and then saves the decision. If the user denies the license terms, the workload will be skipped during the build process. If there are multiple license terms, you can write as many `check_license` functions as needed. 

```
check_license("media.xiorg.com" "Please agree to the license terms for downloading datasets from xiorg.com")
add_workload("foo" LICENSE "media.xiorg.com")
```

### Fixed SUT

If the workload can only run on specific SUT (System Under Test), specify the SUT constraints as part of the `add_workload` function as follows:

```
add_workload("foo" SUT azure)
```

where the `azure` SUT must be defined with `script/cumulus/cumulus-config.<sut>.yaml`.  

### Software Stack CMakeLists.txt

`CMakeLists.txt` for software stacks defines the software stack build and test targets. Let us start with a simple example:  

```
add_stack("foo_setup")
add_testcase(${stack})
```

The `add_stack` function defines `cmake` build rules for a workload. The name must be lower cased as a convention and does not contain any special characters with the exception of `_`. It is recommedded to append the version info to indicate the implementation versioning. The function also defines a parent-scope variable `stack` with the same name that any subsequent function can use.   

The `add_testcase` function defines a test case. You may define multiple test cases, each with a unique name and some configuration parameters. Internally, this gets routed to the `validate.sh` script with the specified parameters. (There is no argument in the above example.) The validation results are saved to the corresponding `logs-$stack` directory under the build tree.  

Note that the name of any `cmake` target must be unique across all workloads. Thus it is usually a concatenation of platform, feature, stack and configuration.   
