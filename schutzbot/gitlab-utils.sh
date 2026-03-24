#!/usr/bin/env bash
#
# Utility functions for the GitLab CI/CD pipeline.

set -euo pipefail

# Hide "set +x"/"set -x" from trace when possible (BASH_XTRACEFD).
_trace_quiet() {
    if [[ $- == *x* ]]; then
        set +x
        echo -n 1
    fi
    echo -n 0
}

_trace_restore() {
    set -x
}

# Prints a section start message to the console.
#
# Arguments:
#   $1 - section id
#   $2 - section title
#   $3 - collapsed (optional)
#
# Example:
#   section_start build_image "Building image"
function section_start() {
    local restore_trace
    restore_trace=$(_trace_quiet)
    local section_id="${1}_$$"
    local section_title=$2
    local collapsed=${3:-true}
    local params=""
    [ "$collapsed" == "true" ] && params="[collapsed=true]"

    printf "\e[0Ksection_start:%s:%s%s\r\e[0K\e[1;36m%s\e[0m\n" "$(date +%s)" "$section_id" "$params" "$section_title"
    if [ "$restore_trace" == 1 ]; then
       _trace_restore
    fi
}

# Prints a section end message to the console.
#
# Arguments:
#   $1 - section id
#
# Example:
#   section_end build_image
function section_end() {
    local restore_trace
    restore_trace=$(_trace_quiet)
    local section_id="${1}_$$"
    printf "\e[0Ksection_end:%s:%s\r\e[0K\n" "$(date +%s)" "$section_id"
    if [ "$restore_trace" == 1 ]; then
       _trace_restore
    fi
}
