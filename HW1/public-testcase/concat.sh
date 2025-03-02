#!/bin/bash

hex1="$(sha256sum ./1/dir1/code/hello.c | awk '{print $1}')"
hex2="$(sha256sum ./1/dir1/code/judge.py | awk '{print $1}')"
echo "hex1 $hex1"
echo "hex2 $hex2"

bin1="$(sha256sum ./1/dir1/code/hello.c | awk '{print $1}' | xxd -r -p)"
echo "bin1 $bin1"
bin2="$(sha256sum ./1/dir1/code/judge.py | awk '{print $1}' | xxd -r -p)"
echo "bin2 $bin2"

hex="$(echo -n $hex1$hex2 | xxd -r -p | sha256sum | awk '{print $1}')"
echo "hex $hex"

bin="$(echo -n $bin1$bin2 | sha256sum | awk '{print $1}')"
echo "bin $bin"

hexc="$(echo -n $hex1$hex2)"
echo "hexc $hexc"

binc="$(echo -n "$bin1$bin2" | xxd -p -c 0)"
echo "binc $binc"

binc="$(echo -n "$bin1""$bin2" | xxd -p -c 0)"
echo "binc $binc"

binc_no_qoute="$(echo -n $bin1$bin2 | xxd -p -c 0)"
echo "binc $binc_no_qoute"

# echo hex1
# echo -n $hex1 | xxd -r -p | xxd -b -c 1 > hex1
# echo hex2
# echo -n $hex2 | xxd -r -p | xxd -b -c 1 > hex2
# echo bin1
# echo -n $bin1 | xxd -b -c 1 > bin1
# echo bin2
# echo -n $bin2 | xxd -b -c 1 > bin2

# echo hex2
# echo -n $hex2 | xxd -r -p | xxd -b
# echo bin2
# echo -n "$bin2" | xxd -b
# echo
# echo "hi" | xxd | xxd -r -p
# echo -n $'\x9' | xxd
# echo -n $'\x11' | xxd
# echo -n $'\x11'
# echo -n $'\x9'
# echo -n $'\x11'