# Component's README

Each workload should have a README with the required instructions.

## Sections

The workload README should have the following sections:
- Introduction: Introduce the workload and any background information.
- Test Case: Describe the test cases.
- Configuration: Describe the workload configuration parameters.
- Execution: Show some examples of how to run the workload.
- KPI: Describe the KPI definitions and the meanings of the values.
- [Performance BKM][Performance BKM]: Describe system setup and any performance tunning tips.
- [Index Info][Index Info]: List the workload indexing information.
- Validation Notes: This section is auto-inserted by the validation team. New workload should remove this section.
- See Also: Add any workload-related references.

The dummy workload [README](../../../workload/dummy/README.md) for reference.

## Performance BKM

It is recommended to include (but not limited to) the following information in the Performance BKM section:
- The minimum system setup (and the corresponding testcase).
- The recommended system setup (and the corresponding test case).
- Workload parameter tuning guidelines. 
- Links to any performance report(s).

[Performance BKM]: #performance-bkm
[Index Info]: #index-info
[platform]: ../../../workload/platforms
