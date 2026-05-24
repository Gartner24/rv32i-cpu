# build.tcl - Compile the RV32I CPU project from the command line.
# Usage: quartus_sh -t build.tcl

load_package flow

set project "segmented"

project_open $project
execute_flow -compile
project_close
