
add_workload("specjbb_2015")

foreach(jdk ${jdk_variant} )   
   add_testcase(${workload}_${jdk}_multijvm_crit_ops_pkm "HBIR_RT_LOADLEVELS" ${jdk}_multijvm_base "multijvm_crit_general")
   add_testcase(${workload}_${jdk}_multijvm_max_jops_pkm "HBIR_RT_LOADLEVELS" ${jdk}_multijvm_pkm "multijvm_max_general")
   add_testcase(${workload}_${jdk}_multijvm_gated "PRESET" ${jdk}_multijvm_preset "multijvm_max_general")
endforeach()

add_testcase(${workload}_openjdk_composite_base "HBIR_RT_LOADLEVELS" openjdk_composite_pkm "composite_max_general")
add_testcase(${workload}_openjdk_composite_gated "PRESET" openjdk_composite_preset "composite_max_general")


