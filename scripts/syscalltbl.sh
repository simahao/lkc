# tbl
in="$1"

grep '^[0-9]' "$in" | sort -n | (
    while read nr name entry; do
        if [ -n "$entry" ]; then
            echo "#define SYS_$name $nr" >> include/syscall_gen/syscall_num.h
            echo "[SYS_$name] $entry," >> include/syscall_gen/syscall_func.h
            echo "extern uint64 $entry(void);" >>include/syscall_gen/syscall_def.h
            echo "[SYS_$name] 0," >>include/syscall_gen/syscall_cnt.h
            echo "[SYS_$name] \"$entry\"," >>include/syscall_gen/syscall_str.h
        fi
    done
)

# grep '^[0-9]' "$in" | sort -n | (
#     while read nr name entry; do
#     if [ -n "$entry" ]; then
#         echo "[SYS_$name] $entry,"
#     fi
#     done
# ) > "$out2"

# grep '^[0-9]' "$in" | sort -n | (
#     while read nr name entry; do
#     if [ -n "$entry" ]; then
#         echo "extern uint64 $entry(void);"
#     fi
#     done
# ) > "$out3"

# grep '^[0-9]' "$in" | sort -n | (
#     while read nr name entry; do
#     if [ -n "$entry" ]; then
#         echo "[SYS_$name] 0,"
#     fi
#     done
# ) > "$out4"

# grep '^[0-9]' "$in" | sort -n | (
#     while read nr name entry; do
#     if [ -n "$entry" ]; then
#         echo "[SYS_$name] \"$entry\","
#     fi
#     done
# ) > "$out5"
