log "Run cron"
echo"rdma_ucm is executed"
sudo modprobe rdma_ucm
sudo echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope
