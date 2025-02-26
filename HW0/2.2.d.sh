#!/bin/bash

# Define the IP address
IP="140.112.91.2"

# Loop through the port range 48000 to 49000
for PORT in $(seq 48000 49000); do
  echo "Curling $IP:$PORT"
  # Perform the curl request
  curl -i -X POST "$IP:$PORT"
  echo -e "\n" # Print a newline for better readability
done

echo "Done curling all ports."
