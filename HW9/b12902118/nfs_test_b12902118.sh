#!/bin/bash
# nfs_test_b12902118.sh
sudo -v

MOUNT_POINT="/mnt/nfs-share"
TESTFILE="$MOUNT_POINT/$(whoami)_dir/$(hostname)"
RESULT_FILE="$MOUNT_POINT/$(whoami)_dir/nfs_test_result_$(hostname)_$(date +%s).txt"


# Function to monitor vmstat during a test and compute averages
monitor_vmstat() {
    local duration_pid=$1
    local log_file=$2

    sleep 0.1
    vmstat 1 > "$log_file" &
    local vm_pid=$!

    wait "$duration_pid"
    kill "$vm_pid" 2>/dev/null
    wait "$vm_pid" 2>/dev/null
}

# Function to extract average CPU usage and load from vmstat log
parse_vmstat_avg() {
    local log_file=$1

    awk '
    NR > 2 {
        load_sum += $1;
        us_sum += $13;
        sy_sum += $14;
        count++;
    }
    END {
        if (count > 0) {
            printf "%.2f\n", (us_sum + sy_sum) / count;
            printf "%.2f\n", load_sum / count;
        } else {
            print "No data collected from vmstat.";
        }
    }' "$log_file"
}

# Function to extract time and speed from dd output
parse_dd_output() {
    local output="$1"
    echo "$output" | grep -Eo '[0-9\.]+ s, [0-9\.]+ MB/s' | awk -F'[ ,]+' '{printf "%s\n%s\n", $1, $3}'
}

# --- Write Test ---

WRITE_VMSTAT_LOG="/tmp/vmstat_write_$(whoami)_$(hostname).log"
WRITE_DD_LOG="/tmp/dd_write_$(whoami)_$(hostname).log"
(dd if=/dev/zero of="$TESTFILE" bs=1M count=1000 conv=fdatasync) &>"$WRITE_DD_LOG" &
WRITE_PID=$!
monitor_vmstat "$WRITE_PID" "$WRITE_VMSTAT_LOG"
wait "$WRITE_PID"

parse_dd_output "$(cat "$WRITE_DD_LOG")" | tee -a "$RESULT_FILE"
parse_vmstat_avg "$WRITE_VMSTAT_LOG" | tee -a "$RESULT_FILE"

# Clear cache
sync; echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null

# --- Read Test ---

READ_VMSTAT_LOG="/tmp/vmstat_read_$(whoami)_$(hostname).log"
READ_DD_LOG="/tmp/dd_read_$(whoami)_$(hostname).log"
(dd if="$TESTFILE" of=/dev/null bs=1M count=1000) &>"$READ_DD_LOG"  &
READ_PID=$!
monitor_vmstat "$READ_PID" "$READ_VMSTAT_LOG"
wait "$READ_PID"

parse_dd_output "$(cat "$READ_DD_LOG")" | tee -a "$RESULT_FILE"
parse_vmstat_avg "$READ_VMSTAT_LOG" | tee -a "$RESULT_FILE"

# Cleanup
rm -f "$TESTFILE"