add_workload("openssl_rsamb_qatsw")

string(REPLACE "_qatsw" "_sw" workload1 "${workload}")
foreach(algo "rsa" "dsa" "ecdsa" "ecdh" "aes-sha" "aes-gcm")

    add_testcase(${workload}_${algo} "qatsw-${algo}")
    add_testcase(${workload1}_${algo} "sw-${algo}")

endforeach()

add_testcase(${workload}_rsa_gated "qatsw-rsa")
add_testcase(${workload}_rsa_pkm "qatsw-rsa")