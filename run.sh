#!/bin/bash
# author:simahao
# date: 2024/3/26      init
# date: 2024/4/1       add apt update and apt install sudo cmake
# start linux with qemu

function usage() {
    echo "usage: run.sh <machine_type> <gdb>"
    echo "machine_type: virt|sifive_u, virt means generic machine, sifive_u means embemd machine"
    echo "e.g., run.sh                   start with virt type"
    echo "      run.sh virt              start with virt"
    echo "      run.sh sifive_u gdb      start with sifive_u and support debug"
    exit 1
}

UF=0
if ! which sudo > /dev/null 2>&1; then
    apt update
    UF=1
    apt install sudo -y
fi
if ! which cmake > /dev/null 2>&1; then
    if [[ $UF == 0 ]]; then
        apt update
    fi
    apt install cmake -y
fi

if [[ $# -ge 3 ]]; then
    usage
fi


# default value
OPTION1=qemu_virt

if [[ $1 != '' ]]; then
    if [[ $1 == 'sifive' ]]; then
        OPTION1=qemu_sifive_u
    elif [[ $1 == 'virt' ]]; then
        OPTION1=qemu_virt
    else
        usage
    fi
    if [[ $2 != '' ]]; then
        OPTION2="gdb"
    fi
fi
make local "PLATFORM=${OPTION1}" ${OPTION2}
