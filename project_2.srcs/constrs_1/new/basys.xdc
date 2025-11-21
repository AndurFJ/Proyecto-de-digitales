## Archivo de Restricciones para Basys 3 (Artix-7)
## Configurado para la entidad: top_game

## 1. RELOJ (100 MHz)
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## 2. SWITCHES (SW)
# SW[4] = Selector de Modo
# SW[3:0] = Entrada de Datos (Clave/Intento)
set_property PACKAGE_PIN V17 [get_ports {SW[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[0]}]
set_property PACKAGE_PIN V16 [get_ports {SW[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[1]}]
set_property PACKAGE_PIN W16 [get_ports {SW[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[2]}]
set_property PACKAGE_PIN W17 [get_ports {SW[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[3]}]
set_property PACKAGE_PIN W15 [get_ports {SW[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[4]}]

## 3. BOTONES
# BTNC = Validar / Confirmar
# BTNL = Modo Configuración
# BTNR = Reset Global
set_property PACKAGE_PIN U18 [get_ports BTNC]
set_property IOSTANDARD LVCMOS33 [get_ports BTNC]
set_property PACKAGE_PIN W19 [get_ports BTNL]
set_property IOSTANDARD LVCMOS33 [get_ports BTNL]
set_property PACKAGE_PIN T17 [get_ports BTNR]
set_property IOSTANDARD LVCMOS33 [get_ports BTNR]

## 4. LEDS (16 LEDs)
set_property PACKAGE_PIN U16 [get_ports {LEDS[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[0]}]
set_property PACKAGE_PIN E19 [get_ports {LEDS[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[1]}]
set_property PACKAGE_PIN U19 [get_ports {LEDS[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[2]}]
set_property PACKAGE_PIN V19 [get_ports {LEDS[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[3]}]
set_property PACKAGE_PIN W18 [get_ports {LEDS[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[4]}]
set_property PACKAGE_PIN U15 [get_ports {LEDS[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[5]}]
set_property PACKAGE_PIN U14 [get_ports {LEDS[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[6]}]
set_property PACKAGE_PIN V14 [get_ports {LEDS[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[7]}]
set_property PACKAGE_PIN V13 [get_ports {LEDS[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[8]}]
set_property PACKAGE_PIN V3 [get_ports {LEDS[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[9]}]
set_property PACKAGE_PIN W3 [get_ports {LEDS[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[10]}]
set_property PACKAGE_PIN U3 [get_ports {LEDS[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[11]}]
set_property PACKAGE_PIN P3 [get_ports {LEDS[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[12]}]
set_property PACKAGE_PIN N3 [get_ports {LEDS[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[13]}]
set_property PACKAGE_PIN P1 [get_ports {LEDS[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[14]}]
set_property PACKAGE_PIN L1 [get_ports {LEDS[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[15]}]

## 5. DISPLAY 7 SEGMENTOS (Cátodos)
# Mapeo: bit[6]=a (W7) ... bit[0]=g (U7)
# Coincide con la lógica "abcdefg" del VHDL
set_property PACKAGE_PIN W7 [get_ports {DISP_SEG[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {DISP_SEG[6]}]
set_property PACKAGE_PIN W6 [get_ports {DISP_SEG[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {DISP_SEG[5]}]
set_property PACKAGE_PIN U8 [get_ports {DISP_SEG[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {DISP_SEG[4]}]
set_property PACKAGE_PIN V8 [get_ports {DISP_SEG[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {DISP_SEG[3]}]
set_property PACKAGE_PIN U5 [get_ports {DISP_SEG[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {DISP_SEG[2]}]
set_property PACKAGE_PIN V5 [get_ports {DISP_SEG[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {DISP_SEG[1]}]
set_property PACKAGE_PIN U7 [get_ports {DISP_SEG[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {DISP_SEG[0]}]

## 6. ÁNODOS (Transistores de control de dígito)
# an[0] es el dígito de la derecha
set_property PACKAGE_PIN U2 [get_ports {DISP_AN[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {DISP_AN[0]}]
set_property PACKAGE_PIN U4 [get_ports {DISP_AN[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {DISP_AN[1]}]
set_property PACKAGE_PIN V4 [get_ports {DISP_AN[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {DISP_AN[2]}]
set_property PACKAGE_PIN W4 [get_ports {DISP_AN[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {DISP_AN[3]}]

## CONFIGURACIÓN DE BITSTREAM
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]