#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: $0 <file.F> [preprocessor flags]"
    exit 1
fi

file="$1"
args="$2"

filename=$(echo "$file" | sed 's/\.[^.]*$//')
head -n 8 "$file" > .__poly_top.f
tail -n +9 "$file" > .__poly_bottom.F
benchdir=$(dirname "$file")

# 1. Run the preprocessor
cpp -P -traditional-cpp .__poly_bottom.F -I "$benchdir" $args > .__tmp_poly.f

if [ $? -ne 0 ]; then
    echo "  [!] Error: Preprocessing failed for $file"
    rm -f .__tmp_poly.f .__poly_bottom.f .__poly_top.f .__poly_bottom.F
    exit 1
fi

# 2. Clean up, Modernize, AND Inject OpenMP Function Call
sed -e '/^#/d' \
    -e '/^[ ]*$/d' \
    -e 's/IARGC()/COMMAND_ARGUMENT_COUNT()/gI' \
    -e 's/CALL GETARG/CALL GET_COMMAND_ARGUMENT/gI' \
    -e 's/!\$pragma scop/      CONTINUE\n      !DIR$ scop/gI' \
    -e 's/!$pragma endscop/!DIR$ end scop/gI' \
    -e '/implicit none/d' \
    .__tmp_poly.f | \
awk '
    # If we see the start of init_array, set flag and inject declarations
    tolower($0) ~ /subroutine[ \t]+init_array/ { 
        print $0
        print "      use omp_lib"
        print "      integer :: omp_dummy_ret_val"
        in_init = 1
        next # Skip the default print below so we do not print the subroutine line twice
    }
    
    # If we see the end of a subroutine AND our flag is set, inject the function call
    tolower($0) ~ /end[ \t]+subroutine/ && in_init {
        print "      omp_dummy_ret_val = omp_pause_resource_all(2)"
        in_init = 0
    }
    
    # Print the current line regardless
    { print }
' > .__poly_bottom.f

# 3. Assemble
cat .__poly_top.f > "${filename}.preproc.f90"
cat .__poly_bottom.f >> "${filename}.preproc.f90"

rm -f .__tmp_poly.f .__poly_bottom.f .__poly_top.f .__poly_bottom.F