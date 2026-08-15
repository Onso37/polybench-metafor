#!/bin/bash

export OMP_NUM_THREADS=16
export OMP_PROC_BIND=close
export OMP_PLACES=cores
NUM_RUNS=20 # Change this to 10 for more stability
echo "Running Suite with Averaging ($NUM_RUNS runs per kernel)..."
echo "------------------------------------------------"

echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo

# --- Benchmark Toggle Matrix ---
# Comment out any benchmark with a '#' to toggle it OFF.
# Leave it uncommented to keep it ON.
ENABLED_BENCHMARKS=(
    "correlation"
    "covariance"
    #"floyd-warshall"
    "reg_detect"
    "fdtd-2d"
    #"seidel-2d"
    "fdtd-apml"
    "adi"
    "jacobi-1d-imper"
    "jacobi-2d-imper"
    "mvt"
    "syr2k"
    #"trmm"
    #"gesummv" crashes
    #"trisolv"
    "syrk"
    "cholesky"
    "bicg"
    "gemver"
    "3mm"
    "atax"
    "2mm"
    "symm"
    "gemm"
    "doitgen"
    "dynprog"
    "ludcmp"
    #"durbin" crashes
    "lu"
    "gramschmidt"
)

# Function to extract the last number (re-used from your comparison script)
get_timer_value() {
    grep -oE '[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?' "$1" | tail -n 1
}

# Function to strip the last number (re-used from your comparison script)
get_functional_data() {
    perl -0777 -pe 's/\s+[\d.eE+-]+\s*$/\n/' "$1"
}

count=0
while read -r exe_path; do
    dir_name=$(dirname "$exe_path")
    base_name=$(basename "$exe_path" .exe)
    output_file="$dir_name/$base_name.output.txt"
    times_file="$dir_name/$base_name.times.txt"
    temp_file="$dir_name/temp_run.txt"

    # NEW CHECK: Determine if this benchmark name is in our enabled list
    # If the file is inside 'woven_code', its folder name might be 'woven_code'
    # so we extract the base name of the executable to match the matrix array.
    is_enabled=false
    for name in "${ENABLED_BENCHMARKS[@]}"; do
        if [[ "$base_name" == "$name" ]]; then
            is_enabled=true
            break
        fi
    done

    # Skip if it's turned off in the matrix above
    if [ "$is_enabled" = false ]; then
        continue
    fi

    echo "Processing: $base_name ($exe_path)"

    rm -f "$times_file"

    total_time=0
    success=true

    for i in $(seq 1 $NUM_RUNS); do
        # Run the benchmark
        "$exe_path" > "$temp_file" 2>&1

        if [ $? -ne 0 ]; then
            echo "   [!] Error in $base_name on run $i"
            success=false
            break
        fi

        # Extract time from this run
        current_time=$(get_timer_value "$temp_file")

        echo "   [OK] Run Time: $current_time"

        # Guard against empty values
        if [[ -z "$current_time" ]]; then current_time=0; fi

        echo "$current_time" >> "$times_file"

        # Add to total using awk for floating point math
        total_time=$(awk "BEGIN {print $total_time + $current_time}")

        # If it's the last run, we'll keep the functional data
        if [ $i -eq $NUM_RUNS ]; then
            get_functional_data "$temp_file" > "$output_file"
        fi
    done

    if [ "$success" = true ]; then
        # Calculate average
        avg_time=$(awk "BEGIN {print $total_time / $NUM_RUNS}")

        # Append the average time as the NEW last number in the output file
        # Your comparison script will now find the average instead of a single run
        echo "$avg_time" >> "$output_file"

        ((count++))
        echo "   [OK] Avg Time: $avg_time"
    fi

    # Cleanup temp file
    rm -f "$temp_file"

done < <(find . -type f -name "*.exe")

echo "------------------------------------------------"
echo "Done. Captured $count averaged benchmark results."
