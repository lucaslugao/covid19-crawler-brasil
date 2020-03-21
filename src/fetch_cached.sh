#!/bin/bash
set -e
set -o errexit
set -o nounset
set -o pipefail
cd "$(cd -P -- "$(dirname -- "$0")" && pwd -P)"

which curl

CACHE_DIR="$(realpath ./.cache)"

mkdir -p "${CACHE_DIR}"

function md5(){
    echo "${1}" | md5sum | awk '{print $1}'
}

function fetch_daily(){
    echo "Fetching > ${1}" >&2
    local cached_file="${CACHE_DIR}/$(md5 ${1})"
    
    [ "$(stat -c %y "${cached_file}" 2>/dev/null | awk '{print $1}')" != "$(date '+%Y-%m-%d')" ] &&
        curl -s "${1}" > "${cached_file}"
    
    echo "${cached_file}"
}

function fetch_once(){
    echo "Fetching > ${1}" >&2
    local cached_file="${CACHE_DIR}/$(md5 ${1})"
    
    [[ ! -f "${cached_file}" ]] && curl -s "${1}" > "${cached_file}"
    
    echo "${cached_file}"
}