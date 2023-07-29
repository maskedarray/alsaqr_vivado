vsim axi_hyper_tb -t 1ps -voptargs=+acc -classdebug
##vsim hyperbus_tb -t 1ps -voptargs=+acc -classdebug

set StdArithNoWarnings 1
set NumericStdNoWarnings 1
log -r /*

delete wave *
