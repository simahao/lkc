#/bin/bash
riscv64-linux-gnu-objcopy -S -O binary fsimg/runtest oo
od -v -t x1 -An oo | sed -E 's/ (.{2})/0x\1,/g' > include/initcode.h
rm oo

