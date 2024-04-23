#include <fs/ioctls.h>
#include <fs/vfs/fs.h>
#include <fs/stat.h>
#include "proc/pcb_life.h"

static long do_ioctl(struct file *filp, unsigned int cmd,
                     unsigned long arg) {
    int error = -1;

    if (!filp->f_op)
        goto out;

    if (filp->f_op->ioctl) {
        error = filp->f_op->ioctl(filp, cmd, arg);
    }

#include "termios.h"
    extern struct termios term;
    if (cmd == TCSETS) {
        struct termios newterm;
        if (copyin(proc_current()->mm->pagetable, (char *)&newterm, arg, sizeof(newterm)) < 0)
            return -1;
        term = newterm;
    } else if (cmd == TCGETS) {
        if (copyout(proc_current()->mm->pagetable, arg, (char *)&term, sizeof(term)) < 0)
            return -1;
    }

    return 0;
out:
    return error;
}

static int file_ioctl(struct file *filp, unsigned int cmd,
                      unsigned long arg) {
    switch (cmd) {
    default:
        return 0;
        break;
    }

    return do_ioctl(filp, cmd, arg);
}

/*
 * When you add any new common ioctls to the switches above and below
 * please update compat_sys_ioctl() too.
 *
 * vfs_ioctl() is not for drivers and not intended to be EXPORT_SYMBOL()'d.
 * It's just a simple helper for sys_ioctl and compat_sys_ioctl.
 */
int vfs_ioctl(struct file *filp, unsigned int fd, unsigned int cmd, unsigned long __user arg) {
    int error = 0;

    // note: fd temporarily unused

    // 处理标准的 ioctl (此处暂时未实现)

    // 如果是常规文件，调用 file_ioctl => do_ioctl
    if (S_ISREG(filp->f_tp.f_inode->i_mode)) {
        error = file_ioctl(filp, cmd, arg);
    } else {
        // 立即调用 do_ioctl, 对应于 file->f_op->ioctl
        error = do_ioctl(filp, cmd, arg);
    }
    return error;
}

// uint64 sys_ppoll(void) {
//     static uint64 lines = 1000000000000;
//     if (lines--)
//         return 1;
//     else
//         return 0;
//     // return 1; // a positive value indicates success
// }