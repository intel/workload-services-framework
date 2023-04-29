# Generate multiple Dockerfiles 

list(APPEND jdk_variant openjdk zulu)

if(" ICX SPR " MATCHES " ${PLATFORM} ")

    file(GLOB customers "configs/*/*.cmake")
    foreach(customer ${customers})
        include(${customer})
    endforeach()
endif()
