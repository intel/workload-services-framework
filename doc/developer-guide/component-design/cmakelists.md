
# Workload CMakeLists.txt

The `CMakeLists.txt` defines actions in `cmake`: build and test. It contains a set of directives and instructions that describe project's source files and targets.

<!--TODO: Define available target options, add_workload() is only one of them-->

## Writing the definition for workload

Let us start with a simple example:

```cmake
add_workload("bert_large")
add_testcase(${workload})
```

The `add_workload` function defines `cmake` build rules for a workload. The name must be lower cased as a convention and does not contain any special characters with the exception of `_`. It is recommended to append the version info to indicate the implementation versioning. The function also defines a parent-scope variable `workload` with the same name that any subsequent function can use.

The `add_testcase` function defines a test case. You may define multiple test cases, each with a unique name and some configuration parameters. Internally, this gets routed to the `validate.sh` script with the specified parameters. (There is no argument in the above example.) The validation results are saved to the corresponding `logs-$workload` directory under the build tree. See also: [Workload Testcases][Workload Testcases].

> Note that the name of any `cmake` target must be unique across all workloads. Thus it is usually a concatenation of platform, feature, workload and configuration.

## Licensing Terms

If the workload requires the user to agree to any license terms, use the `check_license` function. The function prompts the user for license agreement and then saves the decision. If the user denies the license terms, the workload will be skipped during the build process. If there are multiple license terms, you can write as many `check_license` functions as needed.

```cmake
check_license("media.xiorg.com" "Please agree to the license terms for downloading datasets from xiorg.com")
add_workload("foo" LICENSE "media.xiorg.com")
```

## Fixed or Negative SUT

If the workload can only run on specific SUT (System Under Test), in this case `azure`, specify the SUT constraints as part of the `add_workload` function as follows:

```cmake
add_workload("foo" SUT azure)
```

where the `azure` SUT must be defined with `script/terraform/terraform-config.<sut>.tf`.

You can also specify a negative SUT name to remove the SUT type from selection. This will match all possible SUTs, except `aws`:

```cmake
add_workload("foo" SUT -aws)
```

<!-- TODO: List of available SUTs is available under... -->

## Software Stack CMakeLists.txt

`CMakeLists.txt` for software stacks defines the software stack build and test targets. Let us start with a simple example:

```cmake
add_stack("qat_setup")
add_testcase(${stack})
```

The `add_stack` function defines `cmake` build rules for a workload. The name must be lower cased as a convention and does not contain any special characters with the exception of `_`. It is recommended to append the version info to indicate the implementation versioning. The function also defines a parent-scope variable `stack` with the same name that any subsequent function can use.

The `add_testcase` function defines a test case. You may define multiple test cases, each with a unique name and some configuration parameters. Internally, this gets routed to the `validate.sh` script with the specified parameters. (There is no argument in the above example.) The validation results are saved to the corresponding `logs-$stack` directory under the build tree.

> Note that the name of any `cmake` target must be unique across all workloads. Thus it is usually a concatenation of platform, feature, stack and configuration.

Similar to workload `CMakeLists.txt`, you can also use the `check_git_repo` function, the `check_license` function, and the `SUT`/`LICENSE` constraints.

## See also
- [Documentation of available CMake controls][cmake-language docs], including conditional blocks and loops

[Workload Testcases]: ../../user-guide/executing-workload/testcase.md
[cmake-language docs]: https://cmake.org/cmake/help/latest/manual/cmake-language.7.html
