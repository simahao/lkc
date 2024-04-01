#!/bin/bash
# author:simahao
# date: 2024/3/26
# start linux with qemu

function usage() {
    echo "usage: run.sh <machine_type> <gdb>"
    echo "machine_type: virt|sifive_u, virt means generic machine, sifive_u means embemd machine"
    echo "e.g., run.sh                   start with sifive_u type"
    echo "      run.sh virt              start with virt"
    echo "      run.sh sifive_u gdb      start with sifive_u and support debug"
    exit 1
}

apt update
apt install sudo cmake -y

if [[ $# -ge 3 ]]; then
    usage
fi

if [[ ! -f ./fat32.img ]]; then
    make image
fi

# default value
OPTION1=qemu_sifive_u

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
make clean
make "PLATFORM=${OPTION1}" ${OPTION2}