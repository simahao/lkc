#!/bin/bash

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
make PLATFORM=${OPTION}