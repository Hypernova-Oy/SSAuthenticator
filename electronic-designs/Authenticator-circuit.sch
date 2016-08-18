EESchema Schematic File Version 2
LIBS:power
LIBS:device
LIBS:transistors
LIBS:conn
LIBS:linear
LIBS:regul
LIBS:74xx
LIBS:cmos4000
LIBS:adc-dac
LIBS:memory
LIBS:xilinx
LIBS:microcontrollers
LIBS:dsp
LIBS:microchip
LIBS:analog_switches
LIBS:motorola
LIBS:texas
LIBS:intel
LIBS:audio
LIBS:interface
LIBS:digital-audio
LIBS:philips
LIBS:display
LIBS:cypress
LIBS:siliconi
LIBS:opto
LIBS:atmel
LIBS:contrib
LIBS:valves
LIBS:Authenticator-circuit-cache
EELAYER 25 0
EELAYER END
$Descr A4 11693 8268
encoding utf-8
Sheet 1 1
Title ""
Date ""
Rev ""
Comp ""
Comment1 ""
Comment2 ""
Comment3 ""
Comment4 ""
$EndDescr
$Comp
L LED_RCBG D?
U 1 1 57A9A337
P 7100 4400
F 0 "D?" H 7100 4750 50  0000 C CNN
F 1 "LED_RCBG" H 7100 4050 50  0000 C CNN
F 2 "" H 7100 4350 50  0000 C CNN
F 3 "" H 7100 4350 50  0000 C CNN
	1    7100 4400
	1    0    0    -1  
$EndComp
$Comp
L R Ohm
U 1 1 57A9A3E0
P 7550 4600
F 0 "Ohm" V 7630 4600 50  0000 C CNN
F 1 "220" V 7550 4600 50  0000 C CNN
F 2 "" V 7480 4600 50  0000 C CNN
F 3 "" H 7550 4600 50  0000 C CNN
	1    7550 4600
	0    1    1    0   
$EndComp
$Comp
L R Ohm
U 1 1 57A9A42D
P 7550 4200
F 0 "Ohm" V 7630 4200 50  0000 C CNN
F 1 "220" V 7550 4200 50  0000 C CNN
F 2 "" V 7480 4200 50  0000 C CNN
F 3 "" H 7550 4200 50  0000 C CNN
	1    7550 4200
	0    1    1    0   
$EndComp
$Comp
L Earth #PWR?
U 1 1 57A9A7DA
P 7150 5050
F 0 "#PWR?" H 7150 4800 50  0001 C CNN
F 1 "Earth" H 7150 4900 50  0001 C CNN
F 2 "" H 7150 5050 50  0000 C CNN
F 3 "" H 7150 5050 50  0000 C CNN
	1    7150 5050
	1    0    0    -1  
$EndComp
Wire Wire Line
	5900 4400 5900 5050
Wire Wire Line
	5900 4400 6800 4400
Wire Wire Line
	7700 4200 9750 4200
Wire Wire Line
	7700 4600 9750 4600
Connection ~ 7150 5050
Wire Wire Line
	5900 5050 6300 5050
Wire Wire Line
	6300 5050 7150 5050
Wire Wire Line
	7150 5050 7600 5050
Wire Wire Line
	7750 5050 8000 5050
$Comp
L R Ohm
U 1 1 57A9AFA9
P 8150 5050
F 0 "Ohm" V 8230 5050 50  0000 C CNN
F 1 "220" V 8150 5050 50  0000 C CNN
F 2 "" V 8080 5050 50  0000 C CNN
F 3 "" H 8150 5050 50  0000 C CNN
	1    8150 5050
	0    -1   -1   0   
$EndComp
Wire Wire Line
	8300 5050 9750 5050
$Comp
L SPEAKER SP?
U 1 1 57A9B173
P 6400 5950
F 0 "SP?" H 6300 6200 50  0000 C CNN
F 1 "SPEAKER" H 6300 5700 50  0000 C CNN
F 2 "" H 6400 5950 50  0000 C CNN
F 3 "" H 6400 5950 50  0000 C CNN
	1    6400 5950
	0    1    1    0   
$EndComp
$Comp
L R Ohm
U 1 1 57A9A4D7
P 6800 5500
F 0 "Ohm" V 6880 5500 50  0000 C CNN
F 1 "440" V 6800 5500 50  0000 C CNN
F 2 "" V 6730 5500 50  0000 C CNN
F 3 "" H 6800 5500 50  0000 C CNN
	1    6800 5500
	0    1    1    0   
$EndComp
Wire Wire Line
	6650 5500 6500 5500
Wire Wire Line
	6500 5500 6500 5650
Wire Wire Line
	6300 5650 6300 5050
Connection ~ 6300 5050
Wire Wire Line
	6950 5500 9750 5500
Text Label 9450 5450 0    60   ~ 0
GPIO24
Text Label 9450 4150 0    60   ~ 0
GPIO14
Text Label 9450 4550 0    60   ~ 0
GPIO18
Text Label 9450 5000 0    60   ~ 0
GPIO23
Wire Wire Line
	7750 5050 7750 5300
Connection ~ 7750 5050
Text Label 7800 5300 0    60   ~ 0
DOOR
Connection ~ 7750 5300
Text Label 7400 4100 0    60   ~ 0
RED
Text Label 7400 4500 0    60   ~ 0
GREEN
Wire Wire Line
	7600 5050 7600 5300
Connection ~ 7600 5050
Connection ~ 7600 5300
$EndSCHEMATC
