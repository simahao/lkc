#include "ipc/options.h"
#include "memory/vma.h"
#include "common.h"
#include "kernel/syscall.h"
#include "proc/pcb_life.h"
#include "ipc/shm.h"
#include "fs/fcntl.h"
#include "fs/stat.h"
#include "memory/allocator.h"
#include "fs/vfs/ops.h"

static void do_IPC_INFO() {
    panic("IPC_INFO : not tested\n");
}

static void do_SHM_INFO() {
    panic("SHM_INFO : not tested\n");
}

static void do_STAT() {
    panic("STAT : not tested\n");
}

static void do_shm_rmid(struct ipc_namespace *ns, struct kern_ipc_perm *ipcp) {
    struct shmid_kernel *shp;
    shp = container_of(ipcp, struct shmid_kernel, shm_perm);

    if (shp->shm_nattch) {
        shp->shm_perm.mode |= SHM_DEST;
        /* Do not find it any more */
        shp->shm_perm.key = IPC_PRIVATE;
        release(&shp->shm_perm.lock);
        // shm_unlock(shp);
    } else {
        shm_destroy(ns, shp);
    }
}

long do_shmat(int shmid, char *shmaddr, int shmflg, uint64 *raddr) {
    struct shmid_kernel *shp;
    uint64 addr;
    uint64 size;
    struct file *file;
    int err;
    uint64 flags;
    uint64 prot;
    int acc_mode;
    uint64 user_addr;
    struct ipc_namespace *ns;
    struct shm_file_data *sfd;
    // 	struct path path;
    fmode_t f_mode;

    err = -EINVAL;
    if (shmid < 0)
        goto out;
    else if ((addr = (uint64)shmaddr)) {
        if (addr & (SHMLBA - 1)) {
            if (shmflg & SHM_RND)
                addr &= ~(SHMLBA - 1); /* round down */
            else {
                panic("do_shmat : not tested\n");
            }
        }
        flags = MAP_SHARED | MAP_FIXED;
    } else {
        if ((shmflg & SHM_REMAP))
            goto out;
        flags = MAP_SHARED;
    }

    if (shmflg & SHM_RDONLY) {
        prot = PROT_READ;
        acc_mode = S_IRUGO;
        f_mode = FMODE_READ;
    } else {
        prot = PROT_READ | PROT_WRITE;
        acc_mode = S_IRUGO | S_IWUGO;
        f_mode = FMODE_READ | FMODE_WRITE;
    }
    if (shmflg & SHM_EXEC) {
        prot |= PROT_EXEC;
        acc_mode |= S_IXUGO;
    }

    ns = proc_current()->ipc_ns;

    shp = shm_lock_check(ns, shmid);
    shp->shm_nattch++;
    size = shp->shm_file->f_tp.f_inode->i_size;

    // 	size = i_size_read(path.dentry->d_inode);
    shm_unlock(shp);

    err = -ENOMEM;
    if ((sfd = (struct shm_file_data *)kzalloc(sizeof(struct shm_file_data))) == 0) {
        panic("no free memory\n");
    }

    file = shp->shm_file;
    if (!file) {
        panic("occur error\n");
    }
    file->f_mode |= f_mode;


    file->private_data = sfd;
    sfd->id = shp->shm_perm.id;
    sfd->ns = ns;
    sfd->file = shp->shm_file;

    struct proc *p = proc_current();
    sema_wait(&p->mm->mmap_sem);

    if (addr && !(shmflg & SHM_REMAP)) {
        panic("do_shmat : not tested\n");
    }

    user_addr = (uint64)do_mmap(addr, size, prot, flags, file, 0);
    if (user_addr == -1) {
        panic("error\n");
    }
    sfd->user_addr = user_addr;
    *raddr = user_addr;
    err = 0;
    sema_signal(&p->mm->mmap_sem);
    sema_wait(&shm_ids(ns).rwsem);

    shp = shm_lock(ns, shmid);
    shp->shm_nattch--;

    if (shp->shm_nattch == 0 && (shp->shm_perm.mode & SHM_DEST))
        shm_destroy(ns, shp);
    else
        shm_unlock(shp);
    sema_signal(&shm_ids(ns).rwsem);
out:
    return err;
}

static int shmctl_down(struct ipc_namespace *ns, int shmid, int cmd, struct shmid_kernel *buf) {
    struct kern_ipc_perm *ipcp;
    struct shmid_kernel shmid_kern;
    int err;

    ipcp = ipcctl_pre_down(&shm_ids(ns), shmid, cmd, &shmid_kern.shm_perm, 0);

    switch (cmd) {
    case IPC_RMID:
        do_shm_rmid(ns, ipcp);
        goto out_up;
    case IPC_SET:
        ipc_update_perm(&shmid_kern.shm_perm, ipcp);
        break;
    default:
        err = -EINVAL;
    }
out_up:
    sema_signal(&shm_ids(ns).rwsem);
    return err;
}

// int shmget(key_t key, size_t size, int shmflg);
// allocates a System V shared memory segment
uint64 sys_shmget(void) {
    key_t key;
    size_t size;
    int shmflg;
    argint(0, &key);
    argulong(1, &size);
    argint(2, &shmflg);

    struct ipc_namespace *ns;
    static const struct ipc_ops shm_ops = {
        .getnew = newseg,
        .associate = security_shm_associate,
        .more_checks = shm_more_checks,
    };
    struct ipc_params shm_params;

    // extern int print_tf_flag;
    // print_tf_flag = 1;

    ns = proc_current()->ipc_ns;

    shm_params.key = key;
    shm_params.flg = shmflg;
    shm_params.u.size = size;

    return ipcget(ns, &shm_ids(ns), &shm_ops, &shm_params);
}

// int shmctl(int shmid, int cmd, struct shmid_ds *buf);
// System V shared memory control
// IPC_STAT
// IPC_SET
// IPC_RMID
uint64 sys_shmctl(void) {
    int shmid;
    int cmd;
    uint64 buf_addr;
    argint(0, &shmid);
    argint(1, &cmd);
    argaddr(2, &buf_addr);

    struct shmid_kernel buf;

    int err;
    struct ipc_namespace *ns;

    if (cmd < 0 || shmid < 0) {
        err = -EINVAL;
        goto out;
    }

    // version = ipc_parse_version(&cmd);
    struct proc *p = proc_current();
    ns = p->ipc_ns;

    switch (cmd) { /* replace with proc interface ? */
    case IPC_INFO: {
        do_IPC_INFO();
    }
    case SHM_INFO: {
        do_SHM_INFO();
    }
    case SHM_STAT:
    case IPC_STAT: {
        do_STAT();
    }
    case SHM_LOCK:
    case SHM_UNLOCK: {
        panic("shm_lock and shm_unlock not tested\n");
    }
    case IPC_RMID:
    case IPC_SET:
        if (cmd == IPC_SET) {
            if (copyin(p->mm->pagetable, (char *)&buf, buf_addr, sizeof(buf)) < 0) {
                return -EFAULT;
            }
        }
        err = shmctl_down(ns, shmid, cmd, &buf);

        return err;
    default:
        return -EINVAL;
    }

out:
    return err;
}

// void *shmat(int shmid, const void *shmaddr, int shmflg);
// System V shared memory operations
uint64 sys_shmat(void) {
    int shmid;
    uint64 shmaddr;
    int shmflg;
    argint(0, &shmid);
    argaddr(1, &shmaddr);
    argint(2, &shmflg);

    uint64 ret;
    long err = do_shmat(shmid, (char *)shmaddr, shmflg, &ret);
    if (err)
        return err;
    return (long)ret;
}