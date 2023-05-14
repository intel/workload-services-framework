add_workload("bertlarge-pytorch-xeon-public")

foreach (option   
                "inference_throughput"
	        "inference_latency"
                "inference_accuracy"
        )

        add_testcase(${workload}_${option}_${platform_precision} "${option}_${platform_precision}")
endforeach()

add_testcase(${workload}_inference_throughput_${platform_precision}_gated "inference_throughput_${platform_precision}_gated")
add_testcase(${workload}_inference_throughput_${platform_precision}_pkm "inference_throughput_${platform_precision}_pkm")
