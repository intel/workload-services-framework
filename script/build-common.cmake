#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

function(check_git_repo)
    set(repo_list "${git_repo_list}")
    foreach(repo1 ${ARGN})
        if(NOT " '${repo_list}' " MATCHES " '${repo1}' ")
            set(repo_list "${repo_list}'${repo1}' ")
        endif()
    endforeach()
    set(git_repo_list "${repo_list}" PARENT_SCOPE)
endfunction()

function(check_license name license_text)
    if (NOT ";${license_list}" MATCHES ";${name}:")
        set(license_list "${license_list};${name}:${license_text}" PARENT_SCOPE)
    endif()
endfunction()

