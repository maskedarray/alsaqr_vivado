vsim tb_axi_serial_link -t 1ps -voptargs=+acc

set StdArithNoWarnings 1
set NumericStdNoWarnings 1
log -r /*

# do test/serial_wave.do
