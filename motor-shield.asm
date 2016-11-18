/*
 * motor_shield_3.asm
 *
 *  Created: 17/11/2016 08:29:30 a.m.
 *   Author: Lucas Larroque
 */ 
.cseg

.ORG	0x0000

	RJMP	MAIN

;————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————
;Definimos los .def y .equ
;————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————
.def	temp0				= r16		; registro auxiliar 1, colocar en 0 luego de usar.
.def	temp1				= r17		; registro auxiliar 2, colocar en 0 luego de usar.

.def	counter				= r18		; registro dedicado al contador.
.def	motion_direction	= r19		; registro donde se definira el byte de direccion de movimiento.
.def	speed_motor_1		= r20		; registro donde se definira la velocidad del motor 1.
.def	speed_motor_2		= r21		; registro donde se definira la velocidad del motor 2.

.equ	DATA_PIN			= 0			; Pin correspondiente a la salida del dato (Pin 0 del puerto B).
.equ	LATCH_PIN			= 4			; Pin correspondiente a la salida del latch (Pin 4 del puerto B).
.equ	CLOCK_PIN			= 4			; Pin correspondiente a la salida del clock (Pin 4 del puerto D).
.equ	ENABLE_PIN			= 7			; Pin correspondiente a la salida de la habilitación (Pin 7 del puerto D).
.equ	MOTOR_1_OUT_PIN		= 3			; Pin correspondiente a la salida del PWM del motor 1 (Pin 3 del puerto B).
.equ	MOTOR_2_OUT_PIN		= 3			; Pin correspondiente a la salida del PWM del motor 2 (Pin 3 del puerto D).
.equ	PWM_TCCR_2A			= 0xA1		; Habilitacion de TCCR2A.
.equ	PWM_TCCR_2B			= 0x07		; Habilitacion de TCCR2B.

;——————————————————————————————————————————————————————————————RESET—————————————————————————————————————————————————————————
MAIN:
;————————————————————————————————————————————————————Inicializamos Stackpointer——————————————————————————————————————————————
LDI		temp0,low(RAMEND)				; Colocamos stackptr en ram end.
OUT		SPL,temp0
LDI		temp0, high(RAMEND)
OUT		SPH, temp0
LDI		temp0,0
CLR		temp0							; Limpiamos el regitro temp0.

CLI										; Desabilitamos las interrupciones

;————————————————————————————————————————————————————Configuramos los pines de salida————————————————————————————————————————
;Configuramos los pines de los puertos que usaremos como salida.
SBI		DDRB, DATA_PIN					; Seteamos PIN de DATA como salida.
SBI		DDRB, LATCH_PIN					; Seteamos PIN de LATCH como salida.
SBI		DDRD, CLOCK_PIN					; Seteamos PIN de CLOCK como salida.
SBI		DDRD, ENABLE_PIN				; Seteamos PIN de ENABLE como salida.
SBI		DDRB, MOTOR_1_OUT_PIN			; Seteamos la salida del PWM del motor 1 como salida.
SBI		DDRD, MOTOR_2_OUT_PIN			; Seteamos la salida del PWM del motor 2 como salida.

;—————————————————————————————————————————————————Configuramos los PWM para  los motores—————————————————————————————————————
;Seteamos PWM para motor 1 y 2.
LDI		temp0, PWM_TCCR_2A
STS		TCCR2A, temp0					; Cargo el valor de TCCR2B.
LDI		temp0, PWM_TCCR_2B
STS		TCCR2B, temp0					; Cargo el valor de TCCR2B.
CLR		temp0							; Limpiamos el regitro temp0.

;—————————————————————————————————————————————————————————————————PROGRAMA———————————————————————————————————————————————————
LDI		speed_motor_1, 0xfe				; Defino la velocidad del motor 1.
LDI		speed_motor_2, 0xfe				; Defino la velocidad del motor 2.
LDI		motion_direction,0b00010100		; Define el byte de posición.
RCALL	CMD_MOTION_SPEED

　
;———————————————————————————————Secuencia para controlar la dirección y velocidad de los motores—————————————————————————————
;Esta secuencia recibe en el registro motoion la direccion de los motores y en los registros speed_motor_1 y speed_motor_2 la 
;velocidad de los  mismos.
CMD_MOTION_SPEED:
OUT		GPIOR0, motion_direction		; Setea el estado del registro GPIOR0.
STS		OCR2A, speed_motor_1			; Cargamos la velocidad del motor 1.
STS		OCR2B, speed_motor_2			; Cargamos la velocidad del motor 2.
RCALL	CMD_MOTION
RET

;——————————————————————————————————————Secuencia para controlar la dirección de los motores——————————————————————————————————
;Esta secuencia recibe en el registro motoion la direccion de los motores y setea el motor_shield.
CMD_MOTION:
CBI		PORTB, LATCH_PIN				; Setea el latch pin en estado bajo.
CBI		PORTB, DATA_PIN					; Setea el data pin en estado bajo.
LDI		counter, 8						; Inicializa el contador a 8.
IN		motion_direction, GPIOR0		; Toma el estado de GPIOR0 y lo guarda en motion.

DECIDE_DATA_PIN:						; Decide el próximo estado de pin data a partir del registro motion.
CBI		PORTD, CLOCK_PIN				; Setea el clock pin en estado bajo.
LSL		motion_direction				; Desplaza el registro motion un bit y coloca el mas significativo en el carry.
BRCS	SET_DATA_PIN					; Si el carry esta en 1, carga un 1 en el pin de data (SER).
RJMP	CLEAR_DATA_PIN					; Si el carry esta en 0, carga un 0 en el pin de data (SER).

CLEAR_DATA_PIN:							; Carga un 1 en el pin de data.
CBI		PORTB, DATA_PIN
RJMP	SET_CLOCK
SET_DATA_PIN:							; Carga un 0 en el pin de data.
SBI		PORTB, DATA_PIN
RJMP	SET_CLOCK

SET_CLOCK:
SBI		PORTD, CLOCK_PIN				; Setea el clock pin en estado alto.
DEC		counter							; Decrementamos el contador.
BRNE	DECIDE_DATA_PIN					; Si el contador es distinto que cero, vuelve a DECIDE_DATA_PIN.
SBI		PORTB, LATCH_PIN				; Setea el latch pin en estado alto.
RET

;————————————————————————————————————————————————————Delay_de_0.2_segundos———————————————————————————————————————————————————
DALEY_02:
NOP
RET
;————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————
