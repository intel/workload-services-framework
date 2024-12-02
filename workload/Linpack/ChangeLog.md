> --- 24.17.2 ---
- update BLIS_ARCH_TYPE to specific meaning

> --- 24.17.1 ---
- Issue 13794 fix

> --- 24.17 ---
- Upgrade base os to ubuntu 24.04

> --- v24.04.2 ---
- Add sse2 support on BERGAMO and GENOA

> --- v24.04 ---
- Add ARMv8, ARMv9 and Bergamo support
- Decrease image size of Intel. 
- Update default value of N_SIZE.

> --- v23.43.1 ---
- Update AMD recipe to 2023_07_18
- Add test-config for Linpack 
- Add sse2 avx2 in SRF.
- Add workload failure check in Dockerfile.1.intel and Dockerfile.1.amd.
- Update Readme file with cloud information.

> --- v23.26.8 ---
- Delete test case: "sse avx2 default_instruction in intel".
- Add MPI_PROC_NUM, MPI_PER_NODE and NUMA_PER_MPI as tunable parameters.

> --- v23.26.6 ---
- Update cmake files and parameter_precheck.sh for external release.
- Update kubernetes-config.yaml.m4.

> --- v23.26.5 ---
- Refactor Linpack's build.sh and validate.sh.
- Add N_SIZE P_SIZE Q_SIZE NB_SIZE tunable parameters in Linpack.
- Add no_proxy setting in Intel Dockerfile.
- Update ROMA to ROME.
- Update oneapi version from 2023.1.0 to 2023.2.0.

> --- v23.17.6 ---
- Refactor Linpack for external release
- Rename from LinPack to Linpack

> --- v23.17.4 ---
- Update CMakeLists.txt, and add cmake folder
