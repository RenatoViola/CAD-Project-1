#!/bin/bash

# version of the program ('cuda' or 'seq' or 'gprof' or 'nvprof')
version=$1
# number of the set of tests to run (1st set of tests -> test_id = 1)
test_id=$2
test_index=$(($2 - 1))

start_indexes=(0 4 10 11 12 13 14 18 21)
end_indexes=(3 9 10 11 12 13 17 20 21)

start_index=${start_indexes[test_index]}
end_index=${end_indexes[test_index]}

files=("./test_files/files"/*)

length=$((end_index - start_index + 1))

selected_files=("${files[@]:$start_index:$length}")

NUM_POSITIONS=$3

if [[ "$version" == "cuda" ]] || [[ "$version" == "seq" ]]; then
    mkdir -p ./results
    results="./results/results${version^^}.csv"
    output=$(./src/energy_storms_"$version" "$NUM_POSITIONS" "${selected_files[@]}")
    echo "$output"
    echo "Version: ${version^^} |  Set of tests: ${test_id} |  Position count: ${NUM_POSITIONS}" >> "$results"
    echo "$output" >> "$results"
    echo $'\n' >> "$results"
elif [[ "$version" == "gprof" ]]; then
    mkdir -p ./gprof_results
    gprof_output="./gprof_results/gprof_test_${test_id}.csv"
    output=$(./src/energy_storms_"$version" "$NUM_POSITIONS" "${selected_files[@]}")
    profile=$(gprof ./src/energy_storms_seq gmon.out)
    echo "$output" > "$gprof_output"
    echo "$profile" >> "$gprof_output"
elif [[ "$version" == "nvprof" ]]; then
    mkdir -p ./nvprof_results
    nvprof_output="./nvprof_results/nvprof_test_${test_id}.csv"
    nvprof --csv --profile-from-start on --print-summary ./src/energy_storms_cuda "$NUM_POSITIONS" "${selected_files[@]}" &> "$nvprof_output"
else
    echo "Invalid version - the available versions are: { seq; cuda; gprof; nvprof }"
fi