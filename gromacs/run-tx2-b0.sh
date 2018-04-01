#!/bin/bash

if [ ! -r "tx2/build/bin/gmx" ]
then
    echo "tx2/build/bin/gmx not found"
    exit 1
fi

module purge
module load gcc/7.2.0

cd tx2

export GMX_NBNXN_EWALD_TABLE=1
export GMX_MAXBACKUP=-1
$PWD/build/bin/gmx mdrun \
    -s ../benchmarks/benchmarks/ion_channel_vsites.bench/pme-runs/topol.tpr \
    -noconfout -resethway -nsteps -1 -maxh 0.05 -v -quiet -nb cpu -ntmpi 64 -ntomp 4 -npme 0 -pin on -notunepme
