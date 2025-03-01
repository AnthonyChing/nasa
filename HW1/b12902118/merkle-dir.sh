#!/bin/bash

usage() {
	local exit_status=$1
    cat <<EOF
merkle-dir.sh - A tool for working with Merkle trees of directories.

Usage:
  merkle-dir.sh <subcommand> [options] [<argument>]
  merkle-dir.sh build <directory> --output <merkle-tree-file>
  merkle-dir.sh gen-proof <path-to-leaf-file> --tree <merkle-tree-file> --output <proof-file>
  merkle-dir.sh verify-proof <path-to-leaf-file> --proof <proof-file> --root <root-hash>

Subcommands:
  build          Construct a Merkle tree from a directory (requires --output).
  gen-proof      Generate a proof for a specific file in the Merkle tree (requires --tree and --output).
  verify-proof   Verify a proof against a Merkle root (requires --proof and --root).

Options:
  -h, --help     Show this help message and exit.
  --output FILE  Specify an output file (required for build and gen-proof).
  --tree FILE    Specify the Merkle tree file (required for gen-proof).
  --proof FILE   Specify the proof file (required for verify-proof).
  --root HASH    Specify the expected Merkle root hash (required for verify-proof).

Examples:
  merkle-dir.sh build dir1 --output dir1.mktree
  merkle-dir.sh gen-proof file1.txt --tree dir1.mktree --output file1.proof
  merkle-dir.sh verify-proof dir1/file1.txt --proof file1.proof --root abc123def456
EOF
    exit $exit_status
}

OPTIONS="h"
LONGOPTIONS="help,output:,tree:,proof:,root:"
PARSED="$(getopt -l "$LONGOPTIONS" -o "$OPTIONS" -- "$@" 2>/dev/null)"
# Prints the usage if errors happened during passing options
if [[ $? -ne 0 ]]; then
	usage 1
fi
# Check for incorrect usage of long options in the form --option=value
for arg in "$@"; do
	if [[ "$arg" =~ ^--(output|tree|proof|root)= ]]; then
    	usage 1
	fi
done
eval set -- "$PARSED"
# echo "Parsed arguments: $@">&2
total_arguments=$(($#-1))
while true; do
	case "$1" in
		-h)
			h="true"
			shift
			;;
		--help)
			help="true"
			shift
			;;
    	--output)
			output=$2
      		shift 2
      		;;
		--tree)
			tree=$2
			shift 2
			;;
		--proof)
			proof=$2
			shift 2
			;;
		--root)
			root=$2
			shift 2
			;;
    	--)
      		shift
      		break
      		;;
    	*)
      		break
      		;;
  	esac
done

build(){
	find $directory -type f | LC_COLLATE=C sort | sed -E "s:^$directory(/)*::g"
	echo
	files=$(find $directory -type f | LC_COLLATE=C sort)
	n=0
	for file in $files; do
		n=$(($n+1))
	done
	level=1
	i=0
	declare -a array
	for file in $files; do
		hash=$(sha256sum $file | awk '{print $1}')
		# array[$i]="$(sha256sum $file | awk '{print $1}' | xxd -r -p)"
		array[$i]=$hash
		i=$(($i+1))
		if [[ $i = $n ]]; then
			echo -ne "$hash\n"
		else
			echo -n "$hash:"
		fi
	done
	# for i in ${array[@]}; do
	# 	echo "===="
	# 	echo $i 
	# done
	# echo "${array[0]}${array[1]}"
	# left=$(echo ${array[0]} | xxd -r -p)
	# right=$(echo ${array[1]} | xxd -r -p)
	# echo $left
	# echo $right
	# echo "$left$right"
	# H=$(echo -n "$left$right" | sha256sum | awk '{print $1}' | xxd -r -p)
	# echo "$H"
	# echo -n $H | xxd -p -c 0
	width=$n
	while [ $level -lt $n ]; do
		# k=$(($k+1))
		level=$(($level*2))
		# if $(($(($n % $((2**$k)) )) <= $((2**$(($k-1)) )) )); then
		# 	# Case 1
		# else
		# 	# Case 2
		# fi
		new_width=0
		# for i in ${array[@]}; do
		# 	echo $i
		# 	echo =====
		# done
		while true; do
			if [ $(($(($new_width*2))+2)) -le $width ]; then
				# left="$(echo -n ${array[$(($new_width*2))]} | xxd -r -p)"
				# right="$(echo -n ${array[$(($(($new_width*2))+1))]} | xxd -r -p)"
				# left+=$right
				# H="$(echo -n "$left" | sha256sum | awk '{print $1}' | xxd -r -p)"
				# hash="$(echo -n $H | xxd -p -c 0)"
				hash="$(echo -n ${array[$(($new_width*2))]}${array[$(($(($new_width*2))+1))]} | xxd -r -p | sha256sum | awk '{print $1}')"
				array[$new_width]="$hash"
				# hash=$(echo -n ${array[$(($new_width*2))]}${array[$(($(($new_width*2))+1))]} | sha256sum | awk '{print $1}')
				# hash=$(echo -n "${array[$new_width]}${array[$(($new_width+1))]}" | xxd -p -c 0)
				# array[$new_width]=$(echo -n ${array[$new_width]}${array[$(($new_width+1))]} | sha256sum | awk '{print $1}' | xxd -r -p)
				# array[$new_width]=$(echo $hash | xxd -r -p)
				new_width=$(($new_width+1))
				if [ $(($(($new_width*2))+1)) -eq $width ]; then
					echo -ne "$hash\n"
				elif [ $(($new_width*2)) -eq $width ]; then
					echo -ne "$hash\n"
				else
					echo -n "$hash:"
				fi
			elif [ $(($(($new_width*2))+1)) -eq $width ]; then
				# hash=$(echo -n ${array[$(($new_width*2))]} | sha256sum | awk '{print $1}')
				# hash=$(echo -n "${array[$new_width]}" | xxd -p -c 0)
				# array[$new_width]=$(echo -n ${array[$new_width]} | sha256sum | awk '{print $1}' | xxd -r -p)
				array[$new_width]="${array[$(($new_width*2))]}"
				new_width=$(($new_width+1))
			else
				break
			fi
			
		done
		width=$new_width
	done
}

gen-proof2(){
	n=0
	# read until a blank line
	while IFS= read -r line; do
		if [[ $line ]]; then
			n=$(($n+1))
			if [[ "$line" == "$path_to_leaf_file" ]]; then
				# echo "$path_to_leaf_file found in line $n">&2
				leaf_index=$n
			fi
		else
			break
		fi
	done
	echo "leaf_index:$leaf_index,tree_size:$n"
	# echo "n = $n">&2
	array=()
	while IFS= read -r line; do
		array+=("$line")
	done
	# for i in ${array[@]}; do
	# 	echo $i | awk -F ':' "{print \$1}">&2
	# done
	i=0
	while [ $n -ne 1 ]; do
		# echo "leaf index = $leaf_index">&2
		if [ $(($leaf_index%2)) -eq 0 ]; then
			pos=$(($leaf_index-1))
			echo ${array[$i]} | awk -F ":" "{print \$$pos}"
		else
			if [ $leaf_index -ne $n ]; then
				pos=$(($leaf_index+1))
				echo ${array[$i]} | awk -F ":" "{print \$$pos}"
			fi
		fi
		if [ $(($n%2)) -eq 1 ]; then
			index=$(($i+1))
			array[$index]+=":"$(echo ${array[$i]} | awk -F ":" "{print \$$n}")
		fi
		n=$(($(($n+1))/2))
		leaf_index=$(($(($leaf_index+1))/2))
		i=$(($i+1))
	done
}

gen-proof1(){
	n=0
	# read until a blank line
	while IFS= read -r line; do
		if [[ $line ]]; then
			n=$(($n+1))
			if [[ "$line" = "$path_to_leaf_file" ]]; then
				# echo "$path_to_leaf_file found in line $n">&2
				# leaf_index=$n
				found="true"
			fi
		else
			break
		fi
	done
	if [[ ! $found ]]; then
		echo "ERROR: file not found in tree">&2
		echo "ERROR: file not found in tree"
		exit 1
	fi
	gen-proof2 < $merkle_tree_file > $proof_file
}

verify-proof(){
	echo verify-proof
}

validate_execute_subcommand(){
	case "$subcommand" in
		"build")
			merkle_tree_file="$output"
			directory="$argument"
			if [[ $output && ! $tree && ! $proof && ! $root ]]; then
				# echo "merkle-tree-file: $merkle_tree_file, directory: $directory">&2
				if [ -h $merkle_tree_file ]; then
					# echo "$merkle_tree_file is a symbolic link ">&2
					usage 1
				fi
				if [ -e $merkle_tree_file ] && ! [ -f $merkle_tree_file ]; then
					# echo "$merkle_tree_file exists and is not a regular file">&2
					usage 1
				fi
				if [ -h $directory ] || ! [ -d $directory ]; then
					# echo "$directory is a symbolic link or is not an existing directory file">&2
					usage 1
				fi
			else
				# --output not set or --tree set or --proof set or --root set
				usage 1
			fi
			# echo "Executing build...">&2
			build > $merkle_tree_file
			;;
		"gen-proof")
			proof_file="$output"
			merkle_tree_file="$tree"
			path_to_leaf_file="$argument"
			if [[ $output && $tree && ! $proof && ! $root ]]; then
				# echo "proof-file: $proof_file, merkle-tree-file: $merkle_tree_file">&2
				if [ -h $proof_file ]; then
					# $proof_file is a symbolic link
					usage 1
				fi
				if [ -e $proof_file ] && ! [ -f $proof_file ]; then
					# $proof_file exists and is not a regular file
					usage 1
				fi
				if [ -h $merkle_tree_file ] || ! [ -e $merkle_tree_file ] || ! [ -f $merkle_tree_file ]; then
					# $merkle_tree_file is a symbolic link or doesn't exist or is not a regular file
					usage 1
				fi
			else
				# --output not set or --tree not set or --proof set or --root set
				usage 1
			fi
			# echo "Executing gen-proof...">&2
			gen-proof1 < $merkle_tree_file
			;;
		"verify-proof")
			if [[ ! $output && ! $tree && $proof && $root ]]; then
				# echo "proof: $proof, root: $root">&2
				if [ -h $proof ] || ! [ -e $proof ] || ! [ -f $proof ]; then
					# $proof is a symbolic link or doesn't exist or is not a regular file
					usage 1
				fi
				if [[ ! ($root =~ '^[0-9A-F]+$' || $root =~ '^[0-9a-f]+$') ]]; then
					# $root doesn't follow hash regex
					usage 1
				fi
				if [ -h $argument ] || ! [ -f $argument ]; then
					# $argument is a symbolic link is not an existing regular file
					usage 1
				fi
			else
				# --output set or --tree set or --proof not set or --root not set
				usage 1
			fi
			# echo "found verify-proof!">&2
			verify-proof
			;;
		*)
			# echo "Unknown Command">&2
			usage 1
			;;
	esac
}

# Count the number of (subcommands + arguments + other garbage)
case $# in
	0)
		# Only legal if one and only one of -h or --help is set
		if [[ $total_arguments = 1 && ($h || $help) ]]; then
			usage 0 # legal
		else
			usage 1 # illegal
		fi
		;;
	2)
		# Illegal if either -h or --help is set
		if [[ $h || $help ]]; then
			usage 1 # illegal
		fi
		subcommand=$1; argument=$2
		# echo "subcommand: "$subcommand", argument: "$argument>&2
		validate_execute_subcommand
		;;
	*)
		# Illegal
		usage 1
		;;
esac
