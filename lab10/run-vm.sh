#!/bin/bash

# --- Configuration ---
# Base directory under /tmp2 for storing VM overlay disks and related files
VM_INSTANCE_BASE_DIR="/tmp2/$(whoami)"
# QEMU VM memory
VM_MEMORY="8G"
# QEMU CPU settings (-cpu host attempts to match the host CPU features)
VM_CPU="host"
# --- End Configuration ---

# --- Helper Functions ---

# Function to get a random unused TCP port
get_random_port() {
  local port
  while : ; do
    # Generate a port in the dynamic/private range
    port=$(( RANDOM % (65535 - 49152 + 1) + 49152 ))
    # Check if the port is free by trying to connect to it (failure means it's likely free)
    (echo > /dev/tcp/127.0.0.1/$port) &>/dev/null
    if [ $? -ne 0 ]; then
      echo $port
      break
    fi
  done
}

# Function to check if required commands exist
check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo "Error: Required command '$1' not found. Please install it."
    exit 1
  fi
}

# --- Pre-flight Checks ---
check_command "qemu-img"
check_command "qemu-system-x86_64"
check_command "tmux"
check_command "realpath" # Used for resolving the absolute path of the base image

# --- Input Argument Handling ---
if [ $# -ne 2 ]; then
    echo "Usage: $0 <student_id> <path_to_base_qcow2_file>"
    echo "Example: $0 112999001 /path/to/your/base-image.qcow2"
    exit 1
fi

student_id=$1
base_qcow2_path=$2

# Validate base qcow2 file existence and readability
if [ ! -f "$base_qcow2_path" ]; then
    echo "Error: Base QCOW2 file not found at '$base_qcow2_path'"
    exit 1
fi
 if [ ! -r "$base_qcow2_path" ]; then
    echo "Error: Cannot read base QCOW2 file '$base_qcow2_path'. Check permissions."
    exit 1
fi

# Resolve the absolute path to the base image to avoid issues with relative paths
base_qcow2_abs_path=$(realpath "$base_qcow2_path")
# Get just the filename for naming purposes
base_qcow2_name=$(basename "$base_qcow2_path")
# Remove .qcow2 extension for cleaner directory/file names
base_name_noext="${base_qcow2_name%.qcow2}"

echo "Using base image: $base_qcow2_abs_path"

# --- MAC Address Generation ---
# Extract the last 6 digits from the student_id
final_digits="${student_id: -6}"
# Define the MAC address prefix (common QEMU/KVM prefix)
mac_base="52:54"

# Generate two unique MAC addresses based on the final 6 digits
mac1="${mac_base}:${final_digits:0:2}:${final_digits:2:2}:${final_digits:4:2}:01"
mac2="${mac_base}:${final_digits:0:2}:${final_digits:2:2}:${final_digits:4:2}:02"

echo "Generated MAC addresses for student_id $student_id:"
echo "  VM1 MAC: $mac1"
echo "  VM2 MAC: $mac2"

# --- Prepare VM Overlay Disks ---
# Define the specific directory for this set of VMs under the base directory
# This uses /tmp2 as requested
instance_dir="${VM_INSTANCE_BASE_DIR}/${student_id}_${base_name_noext}"
mkdir -p "$instance_dir"
# Set restrictive permissions
chmod 700 "$instance_dir"
echo "VM overlay disk files will be stored in: $instance_dir"

# Define paths for the instance-specific overlay (differencing) qcow2 files
vm1_disk_overlay="${instance_dir}/vm1_overlay.qcow2"
vm2_disk_overlay="${instance_dir}/vm2_overlay.qcow2"

# Create overlay disk for VM1 if it doesn't exist
# This disk will store changes relative to the base image
if [ ! -f "$vm1_disk_overlay" ]; then
    echo "Creating overlay disk for VM1: $vm1_disk_overlay ..."
    # The '-b' option links this new qcow2 file to the base image
    qemu-img create -f qcow2 -b "$base_qcow2_abs_path" -F qcow2 "$vm1_disk_overlay"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create VM1 overlay disk."
        exit 1
    fi
    echo "VM1 overlay disk created successfully."
else
    echo "Using existing overlay disk for VM1: $vm1_disk_overlay"
    echo "Note: VM1 will resume from its previous state. Delete the file to start fresh."
fi

# Create overlay disk for VM2 if it doesn't exist
if [ ! -f "$vm2_disk_overlay" ]; then
    echo "Creating overlay disk for VM2: $vm2_disk_overlay ..."
    qemu-img create -f qcow2 -b "$base_qcow2_abs_path" -F qcow2 "$vm2_disk_overlay"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create VM2 overlay disk."
        exit 1
    fi
    echo "VM2 overlay disk created successfully."
else
    echo "Using existing overlay disk for VM2: $vm2_disk_overlay"
    echo "Note: VM2 will resume from its previous state. Delete the file to start fresh."
fi

# --- Generate Random Ports ---
echo "Generating random ports for SSH and VNC..."
SSH_PORT1=$(get_random_port)
VNC_PORT1=$(get_random_port)
SSH_PORT2=$(get_random_port)
VNC_PORT2=$(get_random_port)

echo "VM1 Ports: Host SSH -> $SSH_PORT1 (VM Port 22), Host VNC -> $VNC_PORT1"
echo "VM2 Ports: Host SSH -> $SSH_PORT2 (VM Port 22), Host VNC -> $VNC_PORT2"

# --- Start Tmux and VMs ---
# Create a unique tmux session name based on student ID and base image name
SESSION_NAME="qemu_${student_id}_${base_name_noext}"

echo "Starting tmux session '$SESSION_NAME' and launching VMs..."

# Check if the session already exists to prevent conflicts
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Warning: tmux session '$SESSION_NAME' already exists."
    echo "You can attach to it using: tmux attach -t $SESSION_NAME"
    echo "Or kill it first using: tmux kill-session -t $SESSION_NAME"
    read -p "Do you want to kill the existing session and restart? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
         echo "Killing existing session '$SESSION_NAME'..."
         tmux kill-session -t "$SESSION_NAME"
         sleep 1 # Give tmux a moment to clean up
    else
         echo "Aborting startup. Please manage the existing tmux session manually."
         exit 0
    fi
fi

# Start a new detached tmux session with a named window "VMs"
tmux new-session -d -s "$SESSION_NAME" -n "VMs"

# Pane 0: Launch VM1 using tmux send-keys
# This sends commands to the specified pane as if typed
tmux send-keys -t "${SESSION_NAME}:VMs.0" "echo '--- Launching VM1 (ID: ${student_id}-1) ---'" C-m
tmux send-keys -t "${SESSION_NAME}:VMs.0" "echo 'Base Image: ${base_qcow2_abs_path}'" C-m
tmux send-keys -t "${SESSION_NAME}:VMs.0" "echo 'Overlay Disk: ${vm1_disk_overlay}'" C-m
tmux send-keys -t "${SESSION_NAME}:VMs.0" "echo 'Host SSH Forward Port: ${SSH_PORT1}'" C-m
tmux send-keys -t "${SESSION_NAME}:VMs.0" "echo 'Host VNC Port: ${VNC_PORT1} (Connect via 127.0.0.1)'" C-m
# Assemble QEMU command for VM1 (using '\' for line continuation for readability)
# Using virtio for disk and simplified user networking
qemu_cmd1="qemu-system-x86_64 \\
    -enable-kvm \\
    -cpu ${VM_CPU} \\
    -m ${VM_MEMORY} \\
    -name vm1_${student_id} \\
    -drive file=${vm1_disk_overlay},format=qcow2,if=virtio \\
    -nic user,hostfwd=tcp::${SSH_PORT1}-:22 \\
    -net nic,macaddr=${mac1} -net vde \\
    -vnc 127.0.0.1:$((VNC_PORT1 - 5900)),password=on \\
    -monitor stdio" # Redirect QEMU monitor to the pane's stdio
tmux send-keys -t "${SESSION_NAME}:VMs.0" "$qemu_cmd1" C-m

# Split the window horizontally (creating pane 1 to the right of pane 0)
tmux split-window -h -t "${SESSION_NAME}:VMs.0"

# Pane 1: Launch VM2
tmux send-keys -t "${SESSION_NAME}:VMs.1" "echo '--- Launching VM2 (ID: ${student_id}-2) ---'" C-m
tmux send-keys -t "${SESSION_NAME}:VMs.1" "echo 'Base Image: ${base_qcow2_abs_path}'" C-m
tmux send-keys -t "${SESSION_NAME}:VMs.1" "echo 'Overlay Disk: ${vm2_disk_overlay}'" C-m
tmux send-keys -t "${SESSION_NAME}:VMs.1" "echo 'Host SSH Forward Port: ${SSH_PORT2}'" C-m
tmux send-keys -t "${SESSION_NAME}:VMs.1" "echo 'Host VNC Port: ${VNC_PORT2} (Connect via 127.0.0.1)'" C-m
# Assemble QEMU command for VM2
qemu_cmd2="qemu-system-x86_64 \\
    -enable-kvm \\
    -cpu ${VM_CPU} \\
    -m ${VM_MEMORY} \\
    -name vm2_${student_id} \\
    -drive file=${vm2_disk_overlay},format=qcow2,if=virtio \\
    -nic user,hostfwd=tcp::${SSH_PORT2}-:22 \\
    -net nic,macaddr=${mac2} -net vde \\
    -vnc 127.0.0.1:$((VNC_PORT2 - 5900)),password=on \\
    -monitor stdio"
tmux send-keys -t "${SESSION_NAME}:VMs.1" "$qemu_cmd2" C-m

# --- Post-Launch Information ---
echo ""
echo "VMs are launching in the background within tmux session '$SESSION_NAME'."
echo "Connection details (from the host machine):"
echo "  VM1 SSH: ssh <user>@<nasaws[1-4]> -p $SSH_PORT1"
echo "  VM1 VNC: vncviewer <nasaws[1-4]>:$VNC_PORT1"
echo "  VM2 SSH: ssh <user>@<nasaws[1-4]> -p $SSH_PORT2"
echo "  VM2 VNC: vncviewer <nasaws[1-4]>:$VNC_PORT2"
echo ""
echo "To view the VM consoles and QEMU monitor, attach to the tmux session:"
echo "  tmux attach -t $SESSION_NAME"
echo ""
echo "To stop the VMs, attach to the tmux session and type 'quit' in each QEMU monitor, or kill the session:"
echo "  tmux kill-session -t $SESSION_NAME"

# Optional: Uncomment the line below to automatically attach to the session after starting.
# tmux attach -t "$SESSION_NAME"

exit 0

