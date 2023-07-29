rm -rf gate
source libraries.sh
vsim -c -do 'source ../../scripts/post_synth_compile.tcl ; quit'
vopt  -suppress 3053 -suppress 8885  -work gate -o hyperbus_tb_opt hyperbus_tb -check_synthesis 

vsim -lib gate -t 1ps -suppress 3053 -suppress 8885 +no_glitch_msg -sdfnoerror -sdfnowarn  hyperbus_tb_opt -sdfmin /hyperbus_tb/fix/i_dut/i_hyperbus_macro=../innovus/trial3/out/hyperbus_synth_wrap.sdf.gz +sdf_verbose

source run_all.sh
