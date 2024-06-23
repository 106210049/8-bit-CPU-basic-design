#!/bin/tcsh
module load vcs
module load verdi

# Syntax: .<vec_name>.
set vec_list = ".syntax.memory.alu.cpu.cpu_multiply.cpu_fibonacci."
set vec_help = `echo "$vec_list:gas/./|/"`


if ($#argv < 1) then
  echo "Error: Missing argument"
  echo "Syntax: $0 <vec_type>"
  echo "        <vec_type>: $vec_help"
endif

set vec_type = $1

# Init value. May change in latter code
setenv TOP cpu_top
setenv SIM_TB $TOP\_tb

setenv WAVE_FILE $vec_type.fsdb
set vector = $vec_type.sv

if ( $vec_list !~ *.$vec_type.*) then
  echo "ERROR DOES NOT SUPPOPRT VECTOR $1"
  echo "Supported list: $vec_help"
  exit
endif

# Additional options or change the default option's value
set user_define = ""
if ($vec_type =~ cpu_multiply*) then
  set user_define = +define+'INSTRUCTION_DB_FILE="prg/prg_multiply.txt"'
else if ($vec_type =~ cpu_fibonacci*) then
  set user_define = +define+'INSTRUCTION_DB_FILE="prg/prg_fibonacci.txt"'
endif

set seed = `date +%s`

vcs +vcs+lic+wait -full64 -lca -debug_access+all -l compile.log -timescale=1ns/1ps +error+100 \
+vpdports -sverilog \
-kdb -debug_acc+all \
-f filelist \
+lint=all \
+define+RD_SEED=$seed+CORETOOLS \
$user_define \
$SIM_TB\.sv \
$vector \
+incdir+../src \
-top $SIM_TB -top vector

simv -ucli -i wave.tcl -l $vec_type.log

