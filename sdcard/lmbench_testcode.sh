#!/bin/bash
echo latency measurements
lmbench_all lat_syscall -P 1 null
# lmbench_all lat_syscall -P 1 read[ok]
# lmbench_all lat_syscall -P 1 write[ok]

# busybox mkdir -p /var/tmp
# busybox touch /var/tmp/lmbench
# lmbench_all lat_syscall -P 1 stat /var/tmp/lmbench[ok]
# lmbench_all lat_syscall -P 1 fstat /var/tmp/lmbench[ok]
# lmbench_all lat_syscall -P 1 open /var/tmp/lmbench[ok]
# lmbench_all lat_select -n 100 -P 1 file[ok]
# lmbench_all lat_sig -P 1 install[ok]
# lmbench_all lat_sig -P 1 catch[ok]
# lmbench_all lat_sig -P 1 prot lat_sig
# lmbench_all lat_pipe -P 1
# lmbench_all lat_proc -P 1 fork[ok]
# lmbench_all lat_proc -P 1 exec[ok]

busybox cp hello /tmp
# lmbench_all lat_proc -P 1 shell[ok]
lmbench_all lmdd label="File /var/tmp/XXX write bandwidth:" of=/var/tmp/XXX move=1m fsync=1 print=3[ok]
# lmbench_all lat_pagefault -P 1 /var/tmp/XXX
# lmbench_all lat_mmap -P 1 512k /var/tmp/XXX
# busybox echo file system latency
# lmbench_all lat_fs /var/tmp
# busybox echo Bandwidth measurements
# lmbench_all bw_pipe -P 1[ok]
# lmbench_all bw_file_rd -P 1 512k io_only /var/tmp/XXX[ok]
# lmbench_all bw_file_rd -P 1 512k open2close /var/tmp/XXX[ok]
# lmbench_all bw_mmap_rd -P 1 512k mmap_only /var/tmp/XXX
# lmbench_all bw_mmap_rd -P 1 512k open2close /var/tmp/XXX
# busybox echo context switch overhead
# lmbench_all lat_ctx -P 1 -s 32 2 4 8 16 24 32 64 96[ok]