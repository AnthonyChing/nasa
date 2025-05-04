#!/bin/bash

# Function to get a random unused port
get_random_port() {
  while : ; do
    port=$((RANDOM % 49152 + 16384)) # Ephemeral port range
    (echo "" > /dev/tcp/127.0.0.1/$port) &>/dev/null || break
  done
  echo $port
}

# Extract the final 6 digits from the student_id
student_id=b12902118
suffix=6
final_digits="${student_id: -6}"
shift=$((${student_id:1:2}*3))

# Generate the base MAC address prefix (52:54:90:20:00)
mac_base="52:54"

# Generate two MAC addresses using the final 6 digits
mac1="${mac_base}:${final_digits:0:2}:${final_digits:2:2}:${final_digits:4:2}:$shift"
mac2="${mac_base}:${final_digits:0:2}:${final_digits:2:2}:${final_digits:4:2}:$(($shift+1))"
mac3="${mac_base}:${final_digits:0:2}:${final_digits:2:2}:${final_digits:4:2}:$(($shift+2))"

# Output the generated MAC addresses
echo "Generated MAC addresses for student_id $student_id:"
echo "MAC for hpc1: $mac1"
echo "MAC for hpc2: $mac2"
echo "MAC for server: $mac3"

# Paths
SRC_DIR="/tmp2/rabhunter/hw9"
DEST_DIR="/tmp2/$(whoami)/nasa/HW9"

# Ensure destination directory exists
mkdir -p "$DEST_DIR"
chmod 700 "$DEST_DIR"

# Files to check
FILES=("nasahw9-hpc1.qcow2" "nasahw9-hpc2.qcow2" "nasahw9-nfs-server.qcow2")

# Check and copy missing files
for file in "${FILES[@]}"; do
    if [ ! -f "$DEST_DIR/$file" ]; then
        echo "Copying $file to $DEST_DIR"
        cp "$SRC_DIR/$file" "$DEST_DIR/"
    fi
done

# Generate random ports for both VNC and SSH
SSH_PORT1=$(get_random_port)
VNC_PORT1=$(get_random_port)
SSH_PORT2=$(get_random_port)
VNC_PORT2=$(get_random_port)
SSH_PORT3=$(get_random_port)
VNC_PORT3=$(get_random_port)

# Start a new tmux session
SESSION_NAME="qemu_vms"
tmux kill-session -t $SESSION_NAME
tmux new-session -d -s $SESSION_NAME

# Run the first QEMU VM in the first tmux pane
tmux split-window -h -t $SESSION_NAME "echo 'HPC1 SSH port: ${SSH_PORT1}, VNC port: ${VNC_PORT1}'; qemu-system-x86_64 -enable-kvm -cpu host -m 8G \
    -drive file=${DEST_DIR}/nasahw9-hpc1.qcow2,format=qcow2 \
    -monitor stdio \
    -nic user,hostfwd=tcp::${SSH_PORT1}-:22 \
    -net nic,macaddr=${mac1} -net vde,sock=/tmp/vde${suffix}.ctl \
    -vnc :$((VNC_PORT1 - 5900)),password=on"

echo "VM1 running: SSH port $SSH_PORT1, VNC port $VNC_PORT1"

# Run the second QEMU VM in the second tmux pane
tmux split-window -v -t $SESSION_NAME "echo 'HPC2 SSH port: ${SSH_PORT2}, VNC port: ${VNC_PORT2}'; qemu-system-x86_64 -enable-kvm -cpu host -m 8G \
    -drive file=${DEST_DIR}/nasahw9-hpc2.qcow2,format=qcow2 \
    -monitor stdio \
    -nic user,hostfwd=tcp::${SSH_PORT2}-:22 \
    -net nic,macaddr=${mac2} -net vde,sock=/tmp/vde${suffix}.ctl \
    -vnc :$((VNC_PORT2 - 5900)),password=on"

echo "VM2 running: SSH port $SSH_PORT2, VNC port $VNC_PORT2"

# Run the third QEMU VM in the third tmux pane
tmux split-window -v -t $SESSION_NAME "echo 'NFS Sever SSH port: ${SSH_PORT3}, VNC port: ${VNC_PORT3}'; qemu-system-x86_64 -enable-kvm -cpu host -m 8G \
    -drive file=${DEST_DIR}/nasahw9-nfs-server.qcow2,format=qcow2 \
    -monitor stdio \
    -nic user,hostfwd=tcp::${SSH_PORT3}-:22 \
    -net nic,macaddr=${mac3} -net vde,sock=/tmp/vde${suffix}.ctl \
    -vnc :$((VNC_PORT3 - 5900)),password=on"

echo "VM3 running: SSH port $SSH_PORT3, VNC port $VNC_PORT3"

# Attach to the tmux session
#tmux attach -t $SESSION_NAME

echo "QEMU VMs starting in tmux session '$QEMU_SESSION_NAME'."
echo "  VM1 (HPC1): SSH port $SSH_PORT1, VNC port $VNC_PORT1"
echo "  VM2 (HPC2): SSH port $SSH_PORT2, VNC port $VNC_PORT2"
echo "  VM3 (Server): SSH port $SSH_PORT3, VNC port $VNC_PORT3"
echo "Waiting for VMs to boot before starting SSH session..."

# --- Wait for VMs to boot ---
total_sleep_time=20 # Total time to wait in seconds
echo "Waiting for VMs to boot ($total_sleep_time seconds)..."
for (( i=1; i<=$total_sleep_time; i++ )); do
    printf "\rProgress: %d/%d seconds" "$i" "$total_sleep_time"
    sleep 1
done
printf "\nDone waiting.\n" # Print a newline after the loop finishes

# --- Start SSH connections in a new tmux window ---
SSH_WINDOW_NAME="ssh_vms" # Window name
SSH_USER="inituser" # IMPORTANT: Change this to the correct username inside your VMs
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" # For automated connection, less secure

echo "Creating SSH window '$SSH_WINDOW_NAME' in session '$SESSION_NAME'..."

# Create a new window in the existing tmux session
tmux new-window -t $SESSION_NAME -n $SSH_WINDOW_NAME \
    "echo 'Connecting to Server (VM3) on port ${SSH_PORT3}...'; \
     ssh ${SSH_OPTS} -p ${SSH_PORT3} ${SSH_USER}@localhost"

# Split vertically, start SSH to HPC1 (VM1) in the bottom pane
tmux split-window -v -t $SESSION_NAME:$SSH_WINDOW_NAME.0 \
    "echo 'Connecting to HPC1 (VM1) on port ${SSH_PORT1}...'; \
     ssh ${SSH_OPTS} -p ${SSH_PORT1} ${SSH_USER}@localhost"

# Split the bottom pane horizontally, start SSH to HPC2 (VM2) in the right pane
tmux split-window -h -t $SESSION_NAME:$SSH_WINDOW_NAME.1 \
    "echo 'Connecting to HPC2 (VM2) on port ${SSH_PORT2}...'; \
     ssh ${SSH_OPTS} -p ${SSH_PORT2} ${SSH_USER}@localhost"

# Resize top pane (server SSH) to 50%
tmux resize-pane -t $SESSION_NAME:$SSH_WINDOW_NAME.0 -y 50%

# Select the server pane initially
tmux select-pane -t $SESSION_NAME:$SSH_WINDOW_NAME.0

echo "SSH window created in session '$SESSION_NAME'."

echo "SSH session created. Attaching now..."
# Attach to the new SSH tmux session
tmux attach -t $SESSION_NAME