#!/bin/bash

# TODO: FFTW vs MKL
# TODO: Intel compiler

DEFAULT_COMPILER=gcc-7.2
function usage
{
    echo
    echo "Usage: ./benchmark.sh build|run [COMPILER]"
    echo
    echo "Valid compilers:"
    echo "  gcc-7.2"
    echo
    echo "The default configuration is '$DEFAULT_COMPILER'."
    echo
}

# Process arguments
if [ $# -lt 1 ]
then
    usage
    exit 1
fi

ACTION=$1
COMPILER=${2:-$DEFAULT_COMPILER}
SCRIPT="`realpath $0`"
SCRIPT_DIR="`realpath $(dirname $SCRIPT)`"

export BENCHMARK_PLATFORM=skl-csd3
export BENCHMARK_DIR="$PWD/gromacs-benchmarks"
export LARGE_BENCHMARK="$PWD/nsteps800.tpr"
export SRC_DIR="$PWD/gromacs-2018.1"
export RUN_DIR="$PWD/gromacs-$BENCHMARK_PLATFORM-$COMPILER"
export BUILD_DIR="$RUN_DIR/build"

# Set up the environment
module purge
module load rhel7/default-peta4
module load cmake-3.9.4-gcc-4.8.5-agn6vsm
case "$COMPILER" in
    gcc-7.2)
        module load gcc-7.2.0-gcc-4.8.5-pqn7o2k
        module load fftw-3.3.6-pl2-gcc-4.8.5-axyncql
        CMAKE_OPTS="-DCMAKE_C_COMPILER=mpicc -DCMAKE_CXX_COMPILER=mpicxx"
        export I_MPI_CC=gcc
        export I_MPI_CXX=g++
        ;;
    *)
        echo
        echo "Invalid compiler '$COMPILER'."
        usage
        exit 1
        ;;
esac


# Handle actions
if [ "$ACTION" == "build" ]
then
    # Fetch source code if necessary
    if ! "$SCRIPT_DIR/../fetch.sh"
    then
        echo
        echo "Failed to fetch source code."
        echo
        exit 1
    fi

    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    # Configure with CMake
    if ! eval cmake "$SRC_DIR" -DCMAKE_BUILD_TYPE=Release \
        -DGMX_CYCLE_SUBCOUNTERS=ON \
        -DGMX_MPI=ON -DGMX_GPU=OFF \
        -DGMX_SIMD=AVX_512 \
        $CMAKE_OPTS
    then
        echo
        echo "Running CMake failed."
        echo
        exit 1
    fi

    # Perform build
    if ! make -j 8
    then
        echo
        echo "Build failed."
        echo
        exit 1
    fi

elif [ "$ACTION" == "run" ]
then
    if [ ! -x "$BUILD_DIR/bin/gmx_mpi" ]
    then
        echo "Executable '$BUILD_DIR/bin/gmx_mpi' not found."
        echo "Use the 'build' action first."
        exit 1
    fi

    if [ ! -r "$LARGE_BENCHMARK" ]
    then
        echo "'$LARGE_BENCHMARK' found."
        echo "Copy nsteps800.tpr into the current directory first."
        exit 1
    fi

    cd "$RUN_DIR"
    sbatch "$SCRIPT_DIR/scaling.job" \
        -o "$PWD/gromacs-$BENCHMARK_PLATFORM-$COMPILER.out" \
        -job-name gromacs
else
    echo
    echo "Invalid action (use 'build' or 'run')."
    echo
    exit 1
fi
