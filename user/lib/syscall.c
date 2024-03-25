#include "stddef.h"
#include "unistd.h"
#include "syscall.h"

int open(const char *path, int flags)
{
    return syscall(SYS_openat, AT_FDCWD, path, flags, O_RDWR);
}

int openat(int dirfd,const char *path, int flags)
{
    return syscall(SYS_openat, dirfd, path, flags, 0600);
}

int close(int fd)
{
    return syscall(SYS_close, fd);
}

ssize_t read(int fd, void *buf, size_t len)
{
    return syscall(SYS_read, fd, buf, len);
}

ssize_t write(int fd, const void *buf, size_t len)
{
    return syscall(SYS_write, fd, buf, len);
}

pid_t getpid(void)
{
    return syscall(SYS_getpid);
}

pid_t getppid(void)
{
    return syscall(SYS_getppid);
}

int sched_yield(void)
{
    return syscall(SYS_sched_yield);
}

pid_t fork(void)
{
    return syscall(SYS_clone, SIGCHLD, 0);
}

pid_t clone(int (*fn)(void *arg), void *arg, void *stack, size_t stack_size, unsigned long flags)
{
    if (stack)
	stack += stack_size;

    return __clone(fn, stack, flags, NULL, NULL, NULL);
    //return syscall(SYS_clone, fn, stack, flags, NULL, NULL, NULL);
}
void exit(int code)
{
    syscall(SYS_exit, code);
}

int waitpid(int pid, int *code, int options)
{
    return syscall(SYS_wait4, pid, code, options, 0);
}

int exec(char *name)
{
    return syscall(SYS_execve, name);
}

int execve(const char *name, char *const argv[], char *const argp[])
{
    return syscall(SYS_execve, name, argv, argp);
}

int times(void *mytimes)
{
	return syscall(SYS_times, mytimes);
}

int64 get_time()
{
    TimeVal time;
    int err = sys_get_time(&time, 0);
    if (err == 0)
    {
        return ((time.sec & 0xffff) * 1000 + time.usec / 1000);
    }
    else
    {
        return -1;
    }
}

int sys_get_time(TimeVal *ts, int tz)
{
    return syscall(SYS_gettimeofday, ts, tz);
}

int time(unsigned long *tloc)
{
    return syscall(SYS_time, tloc);
}

int sleep(unsigned long long time)
{
    TimeVal tv = {.sec = time, .usec = 0};
    if (syscall(SYS_nanosleep, &tv, &tv)) return tv.sec;
    return 0;
}

int set_priority(int prio)
{
    return syscall(SYS_setpriority, prio);
}

void *mmap(void *start, size_t len, int prot, int flags, int fd, off_t off)
{
    return syscall(SYS_mmap, start, len, prot, flags, fd, off);
}

int munmap(void *start, size_t len)
{
    return syscall(SYS_munmap, start, len);
}

int wait(int *code)
{
    return waitpid((int)-1, code, 0);
}

int spawn(char *file)
{
    return syscall(SYS_spawn, file);
}

int mailread(void *buf, int len)
{
    return syscall(SYS_mailread, buf, len);
}

int mailwrite(int pid, void *buf, int len)
{
    return syscall(SYS_mailwrite, pid, buf, len);
}

int fstat(int fd, struct kstat *st)
{
    return syscall(SYS_fstat, fd, st);
}

int sys_linkat(int olddirfd, char *oldpath, int newdirfd, char *newpath, unsigned int flags)
{
    return syscall(SYS_linkat, olddirfd, oldpath, newdirfd, newpath, flags);
}

int sys_unlinkat(int dirfd, char *path, unsigned int flags)
{
    return syscall(SYS_unlinkat, dirfd, path, flags);
}

int link(char *old_path, char *new_path)
{
    return sys_linkat(AT_FDCWD, old_path, AT_FDCWD, new_path, 0);
}

int unlink(const char *path)
{
    return sys_unlinkat(AT_FDCWD, path, 0);
}

int uname(void *buf)
{
    return syscall(SYS_uname, buf);
}

int brk(void *addr)
{
    return syscall(SYS_brk, addr);
}

char *getcwd(char *buf, size_t size){
    return syscall(SYS_getcwd, buf, size);
}

int chdir(const char *path){
    return syscall(SYS_chdir, path);
}

int mkdir(const char *path, mode_t mode){
    return syscall(SYS_mkdirat, AT_FDCWD, path, mode);
}

int getdents(int fd, struct linux_dirent64 *dirp64, unsigned long len){
    //return syscall(SYS_getdents64, fd, dirp64, len);
    return syscall(SYS_getdents64, fd, dirp64, len);
}

int pipe(int fd[2]){
    return syscall(SYS_pipe2, fd, 0);
}

int dup(int fd){
    return syscall(SYS_dup, fd);
}

int dup2(int old, int new){
    return syscall(SYS_dup3, old, new, 0);
}

int mount(const char *special, const char *dir, const char *fstype, unsigned long flags, const void *data)
{
        return syscall(SYS_mount, special, dir, fstype, flags, data);
}

int umount(const char *special)
{
        return syscall(SYS_umount2, special, 0);
}

/* above is the oscomp's required syscall, don't modify, add new syscall below */
/* ================================================================================= */

/* add */
int mknod(const char* path, int mode, int dev) {
    return syscall(SYS_mknod, path, mode, dev);
}

char *sbrk(int increment) {
    return syscall(SYS_sbrk, increment);
}

int kill(int pid, sig_t signo) {
    return syscall(SYS_kill, pid, signo);
}

void shutdown() {
    return syscall(SYS_shutdown);
}

/* busybox */
int clock_gettime(clockid_t clockid, struct timespec *tp) {
    return syscall(SYS_clock_gettime, clockid, tp);
}

int sysinfo(struct sysinfo *info) {
    return syscall(SYS_sysinfo, info);
}

int rt_sigaction(int signum, const struct sigaction *act, struct sigaction *oldact, size_t sigsetsize) {
    return syscall(SYS_rt_sigaction, signum, act, oldact, sigsetsize);
}
    // => fs  
ssize_t writev(int fd, const struct iovec *iov, int iovcnt) {
    return syscall(SYS_writev, fd, iov, iovcnt);
}

ssize_t readv(int fd, const struct iovec *iov, int iovcnt) {
    return syscall(SYS_readv, fd, iov, iovcnt);
}

off_t lseek(int fd, off_t offset, int whence) {
    return syscall(SYS_lseek, fd, offset, whence);
}

ssize_t sendfile(int out_fd, int in_fd, off_t *offset, size_t count) {
    return syscall(SYS_sendfile, out_fd, in_fd, offset, count);
}

int statfs(const char *path, struct statfs *buf) {
    return syscall(SYS_statfs, path, buf);
}

int renameat2(int olddirfd, const char *oldpath, 
            int newdirfd, const char *newpath, unsigned int flags) {
    return syscall(SYS_renameat2, olddirfd, oldpath, newdirfd, newpath, flags);
}

/* debug */
int print_pgtable() {
    return syscall(SYS_print_pgtable);
}

int print_vma() {
    return syscall(SYS_print_vma);
}

void print_rawfile(int fd, int printdir) {
    return syscall(SYS_print_rawfile, fd, printdir);
}