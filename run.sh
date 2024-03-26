#!/bin/bash
# author:simahao
# date: 2024/3/26
# start linux with qemu

if [[ $# -ge 3 ]]; then
    echo "usage: run.sh <machine_type> <gdb>"
    echo "machine_type: virt|sifive_u"
    echo "e.g., run.sh                   start with sifive_u type"
    echo "      run.sh virt              start with virt"
    echo "      run.sh sifive_u gdb      start with sifive_u and support debug"
    exit 1
fi

if [[ ! -f ./fat32.img ]]; then
    make image
fi
if [[ $# == 0 ]]; then
    OPTION=qemu_sifive_u
else
    if [[ $1 == 'sifive' ]]; then
        OPTION=qemu_sifive_u
    elif [[ $1 == 'virt' ]]; then
        OPTION=qemu_virt
    else
        echo "support options: virt | sifive"
        echo "e.g., run.sh virt"
        exit 1
    fi
fi

make clean
if [[ $# == 2 && $2 == 'gdb' ]]; then
    make PLATFORM=${OPTION} gdb
else
    make PLATFORM=${OPTION}
fi