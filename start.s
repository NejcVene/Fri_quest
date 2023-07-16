.equ PMC_BASE,  0xFFFFFC00  /* (PMC) Base Address */
.equ CKGR_MOR,	0x20        /* (CKGR) Main Oscillator Register */
.equ CKGR_PLLAR,0x28        /* (CKGR) PLL A Register */
.equ PMC_MCKR,  0x30        /* (PMC) Master Clock Register */
.equ PMC_SR,	  0x68        /* (PMC) Status Register */

.text
.code 32

.global _error
_error:
  b _error

.global	_start
_start:

/* select system mode 
  CPSR[4:0]	Mode
  --------------
   10000	  User
   10001	  FIQ
   10010	  IRQ
   10011	  SVC
   10111	  Abort
   11011	  Undef
   11111	  System   
*/

  mrs r0, cpsr
  bic r0, r0, #0x1F   /* clear mode flags */  
  orr r0, r0, #0xDF   /* set supervisor mode + DISABLE IRQ, FIQ*/
  msr cpsr, r0     
  
  /* init stack */
  ldr sp,_Lstack_end
                                   
  /* setup system clocks */
  ldr r1, =PMC_BASE

  ldr r0, = 0x0F01
  str r0, [r1,#CKGR_MOR]

osc_lp:
  ldr r0, [r1,#PMC_SR]
  tst r0, #0x01
  beq osc_lp
  
  mov r0, #0x01
  str r0, [r1,#PMC_MCKR]

  ldr r0, =0x2000bf00 | ( 124 << 16) | 12  /* 18,432 MHz * 125 / 12 */
  str r0, [r1,#CKGR_PLLAR]

pll_lp:
  ldr r0, [r1,#PMC_SR]
  tst r0, #0x02
  beq pll_lp

  /* MCK = PCK/4 */
  ldr r0, =0x0202
  str r0, [r1,#PMC_MCKR]

mck_lp:
  ldr r0, [r1,#PMC_SR]
  tst r0, #0x08
  beq mck_lp

  /* Enable caches */
  mrc p15, 0, r0, c1, c0, 0 
  orr r0, r0, #(0x1 <<12) 
  orr r0, r0, #(0x1 <<2)
  mcr p15, 0, r0, c1, c0, 0 

.global _main
/* main program */
_main:

@ DBGU registers
.equ DBGU_BASE, 0xFFFFF200	/* Debug Unit Base Address */
.equ DBGU_CR, 0x00  		/* DBGU Control Register */
.equ DBGU_MR, 0x04	  	/* DBGU Mode Register*/
.equ DBGU_IER, 0x08		/* DBGU Interrupt Enable Register*/
.equ DBGU_IDR, 0x0C		/* DBGU Interrupt Disable Register */
.equ DBGU_IMR, 0x10		/* DBGU Interrupt Mask Register */
.equ DBGU_SR,   0x14		/* DBGU Status Register */
.equ DBGU_RHR, 0x18		/* DBGU Receive Holding Register */
.equ DBGU_THR, 0x1C		/* DBGU Transmit Holding Register */
.equ DBGU_BRGR, 0x20		/* DBGU Baud Rate Generator Register */

@ PIO registers
.equ PIOC_BASE, 0xFFFFF800 /* Zacetni naslov registrov za PIOC */
.equ PIO_PER, 0x00 /* Odmiki... */
.equ PIO_OER, 0x10
.equ PIO_SODR, 0x30
.equ PIO_CODR, 0x34

/* user code here */

  mov r10, #8
  /* Init DBGU */
  bl PRINT_INIT
  
  /* Init LED */
  bl LED_INIT
  
  /* Intro text */
  ldr r0, =hello_string
  bl PRINT_SEND

  /* Get player name and print it out*/
  ldr r0, =player_name_info
  bl PRINT_SEND
  mov r1, #4
  ldr r0, =player_name
  bl PRINT_GET
  ldr r0, =player_name
  bl PRINT_SEND
  ldr r0, =new_line
  bl PRINT_SEND
  mov r4, #0
  ldr r0, =enemy_move_right
  bl PRINT_SEND

GAME_LOOP:
  cmp r9, #1
  beq END_GAME
  bl LED_OFF
  bl PRINT_FIELD
  bl PRINT_POWER
  bl PRINT_PROMPT
  bl GET
  bl PRINT
  bl MOVE_PLAYER
  bl MOVE_ENEMY
  cmp r10, #0
  beq END_GAME
  cmp r4, #0
  moveq r4, #1
  ldreq r0, =enemy_move_down
  movne r4, #0
  ldrne r0, =enemy_move_right
  bl PRINT_SEND
  bl DECREASE_POWER
  b GAME_LOOP

END_GAME:
  cmp r9, #1
  ldreq r0, =ending_string2
  ldrne r0, =ending_string
  bl PRINT_SEND

/* end user code */

_wait_for_ever:
  b _wait_for_ever

PRINT_INIT:
  stmfd r13!, {r0, r1, r14}
  ldr r0, =DBGU_BASE
  mov r1, #156
  str r1, [r0, #DBGU_BRGR] @ set speed
  mov r1, #1 << 11
  str r1, [r0, #DBGU_MR] @ set mode (normal mode)
  mov r1, #0x50
  str r1, [r0, #DBGU_CR] @ enable recive and send
  ldmfd r13!, {r0, r1, pc} @ pc = r15

LED_INIT:
  stmfd r13!, {r0, r1, r14}
  ldr r0, =PIOC_BASE
  mov r1, #0b0010
  str r1, [r0, #PIO_PER]
  str r1, [r0, #PIO_OER]
  ldmfd r13!, {r0, r1, pc}

LED_ON:
  stmfd r13!, {r0, r1, r14}
  ldr r0, =PIOC_BASE
  mov r1, #0b0010
  str r1, [r0, #PIO_CODR]
  ldmfd r13!, {r0, r1, pc}

LED_OFF:
  stmfd r13!, {r0, r1, r14}
  ldr r0, =PIOC_BASE
  mov r1, #0b0010
  str r1, [r0, #PIO_SODR]
  ldmfd r13!, {r0, r1, pc}

DELAY:
  stmfd r13!, {r0, r1, r14}
  ldr r0, =500
OUT_DELAY:
  ldr r1, =48000
IN_DELAY:
  subs r1, r1, #1
  bne IN_DELAY
  subs r0, r0, #1
  bne OUT_DELAY   
  ldmfd r13!, {r0, r1, pc}

PRINT_SEND:
  stmfd r13!, {r2, r14}
  mov r2, r0
MAIN_LOOP_PRINT:
  ldrb r0, [r2], #1
  cmp r0, #0 @ check for end of string
  beq END_PRINT
  bl PRINT
  b MAIN_LOOP_PRINT
END_PRINT:
  ldmfd r13!, {r2, pc}
PRINT:
  stmfd r13!, {r1, r2, r14}
  ldr r1, =DBGU_BASE
PRINT_LOOP:
  ldr r2, [r1, #DBGU_SR]
  tst r2, #1 << 1
  beq PRINT_LOOP
  cmp r0, #';'
  moveq r0, #0xA
  cmp r7, #1 @ if r7 == 1 && r0 == 0xA then: dont go to new line
  cmpeq r0, #0xA
  strne r0, [r1, #DBGU_THR]
  ldmfd r13!, {r1, r2, pc}

PRINT_GET:
  stmfd r13!, {r1, r2, r14}
  mov r2, r0
MAIN_LOOP_GET:
  bl GET
  strb r0, [r2], #1
  subs r1, r1, #1
  bne MAIN_LOOP_GET
  mov r0, #0
  strb r0, [r2]
  ldmfd r13!, {r1, r2, pc}

GET:
  stmfd r13!, {r1, r14}
  ldr r1, =DBGU_BASE
GET_LOOP:
  ldr r0, [r1, #DBGU_SR]
  tst r0, #1
  beq GET_LOOP
  ldr r0, [r1, #DBGU_RHR]
  ldmfd r13!, {r1, pc}

MOVE_PLAYER:
  stmfd r13!, {r0, r1, r2, r3, r14}
  cmp r0, #0x61 @ move left
  beq MOVE_X_POS
  cmp r0, #0x64 @ move right
  beq MOVE_X_POS
  cmp r0, #0x77 @ move forward
  beq MOVE_Y_POS
  cmp r0, #0x73 @ move back
  beq MOVE_Y_POS
  cmp r0, #0x71 @ attack enemy
  beq CHECK_CORDS
  bl PRINT_NEW_LINE @ wrong input
  ldmfd r13!, {r0, r1, r2, r3, pc}
MOVE_X_POS:
  mov r3, #0
  ldr r1, =player_stat
  ldrsb r2, [r1]
  cmp r0, #0x61
  beq LEFT
  bne RIGHT
LEFT:
  subs r2, r2, #1
  ldr r0, =move_left
  b SAVE_MOVE
RIGHT:
  adds r2, r2, #1
  ldr r0, =move_right
  b SAVE_MOVE
MOVE_Y_POS:
  mov r3, #1
  ldr r1, =player_stat
  ldrsb r2, [r1, r3]
  cmp r0, #0x77
  beq UP
  bne DOWN
UP:
  subs r2, r2, #1
  ldr r0, =move_up
  b SAVE_MOVE
DOWN:
  adds r2, r2, #1
  ldr r0, =move_back
SAVE_MOVE:
  cmp r2, #10
  movge r2, #0
  cmp r2, #0
  movlt r2, #9
  strb r2, [r1, r3]
  bl PRINT_NEW_LINE
  bl PRINT_PLAYER_NAME
  bl PRINT_SEND
  ldmfd r13!, {r0, r1, r2, r3, pc}  

MOVE_ENEMY:
  stmfd r13!, {r0, r1, r2, r4, r14}
  ldr r0, =enemy
  mov r2, #0
  cmp r4, #0 @ if r4 == 0 then pointer to x pos, else pointer to y pos
  addne r0, r0, #1
MOVE_ENEMY_LOOP:
  ldrsb r1, [r0]
  cmp r1, #9
  addlt r1, r1, #1
  movge r1, #0 @ reset position
  strb r1, [r0]
  add r2, r2, #1
  add r0, r0, #5
  cmp r2, #8
  blo MOVE_ENEMY_LOOP
  ldmfd r13!, {r0, r1, r2, r4, pc}

PRINT_PLAYER_NAME:
  stmfd r13!, {r0, r14}
  ldr r0, =player_name
  bl PRINT_SEND
  ldmfd r13!, {r0, pc}

PRINT_PROMPT:
  stmfd r13!, {r0, r7, r14}
  bl PRINT_NEW_LINE
  mov r7, #1
  ldr r0, =prompt
  bl PRINT_SEND
  ldmfd r13!, {r0, r7, pc}

PRINT_NEW_LINE:
  stmfd r13!, {r0, r7, r14}
  mov r7, #0
  ldr r0, =new_line
  bl PRINT_SEND
  ldmfd r13!, {r0, r7, pc}

@ before a player can attack they have to be on the same tile
CHECK_CORDS:
  stmfd r13!, {r0, r1, r2, r4, r5, r6, r8, r9, r14}
  ldr r0, =player_stat
  ldr r1, =enemy
  ldr r6, =enemy
  ldr r9, =enemy
  add r6, r6, #1
  add r9, r9, #4
  ldrb r2, [r0] @ player x pos
  ldrb r3, [r0, #1] @ player y pos
  mov r7, #2 @ pointer to enemy health
  mov r0, #0 @ NUM OF ENEMIES COUNTER!
CHECK:
  add r0, r0, #1
  ldrb r4, [r1], #5
  ldrb r5, [r6], #5
  ldrb r8, [r9], #5
  cmp r2, r4
  cmpeq r3, r5
  cmpeq r8, #1
  beq CAN
  add r7, r7, #5
  cmp r0, #8 @ !!!
  blo CHECK
  beq NOT
CAN:
  sub r10, r10, #1
  bl PRINT_NEW_LINE
  bl PRINT_PLAYER_NAME
  mov r4, r7
  bl PLAYER_ATTACK
  b CON_CORD
NOT:
  bl PRINT_NEW_LINE
  bl PRINT_PLAYER_NAME
  ldr r0, =player_cannot_attack
  bl PRINT_SEND
CON_CORD:
  ldmfd r13!, {r0, r1, r2, r4, r5, r6, r8, r9, pc}

@ r0 the enemy pointer, r1 the player himself
@ r2 player attack, r3 enemy health
@ r4 pointer (odmik oz. index) to the correct enemy for its health
PLAYER_ATTACK:
  stmfd r13!, {r0, r1, r2, r3, r14}
  ldr r0, =enemy
  ldr r1, =player_stat
  ldrb r2, [r1, #3] @ player attack
  ldrsb r3, [r0, r4] @ enemy health
  subs r3, r3, r2
  cmp r3, #0
  addle r4, r4, #2
  movle r3, #0
  strb r3, [r0, r4]
  ldrle r0, =enemy_is_dead
  blle PRINT_SEND
  bl LED_ON
  bl DELAY
  ldmfd r13!, {r0, r1, r2, r3, pc}

DECREASE_POWER:
  stmfd r13!, {r0, r1, r14}
  ldr r0, =player_power
  ldrb r1, [r0]
  sub r1, r1, #1
  strb r1, [r0]
  cmp r1, #0
  moveq r9, #1
  ldmfd r13!, {r0, r1, pc}

PRINT_POWER:
  stmfd r13!, {r0, r1, r2, r14}
  ldr r0, =player_power
  ldrb r1, [r0]
  mov r2, #1
  mov r0, #'X'
PRINT_POWER_LOOP:
  bl PRINT
  cmp r2, #25
  bleq PRINT_NEW_LINE
  cmp r2, r1
  add r2, r2, #1
  blo PRINT_POWER_LOOP  
  ldmfd r13!, {r0, r1, r2, pc}

PRINT_FIELD:
  stmfd r13!, {r0, r1, r2, r3, r5, r6, r7, r8, r9, r10, r14}
  mov r2, #0
  b OUT
IN:
  ldr r1, =player_stat
  cmp r3, #10
  addhs r2, r2, #1
  bhs OUT
  mov r0, #' '
  bl PRINT
  mov r0, #'.'
  ldrb r5, [r1] @ x pos (player)
  ldrb r6, [r1, #1] @ y pos (player)
  cmp r5, r3 @ check for player
  cmpeq r6, r2
  moveq r0, #0xFF
  beq FIELD_CON
  ldr r7, =enemy
  mov r8, r7
  mov r9, r7
  add r8, r8, #1
  add r9, r9, #4
  mov r1, #0
PRINT_FIELD_LOOP:
  add r1, r1, #1
  ldrb r5, [r7], #5
  ldrb r6, [r8], #5
  ldrb r10, [r9], #5
  cmp r5, r3 @ check for enemy
  cmpeq r6, r2
  cmpeq r10, #1
  moveq r0, #0xD6
  movne r0, #'.'
  beq FIELD_CON
  cmp r1, #8
  blo PRINT_FIELD_LOOP
FIELD_CON:  
  bl PRINT
  add r3, r3, #1
  b IN
OUT:
  bl PRINT_NEW_LINE
  cmp r2, #10
  movlo r3, #0
  blo IN
  ldmfd r13!, {r0, r1, r2, r3, r5, r6, r7, r8, r9, r10, pc}

/* constants */

@ game vars & stuff
hello_string: .asciz "*------------------------*;|                        |;|       Welcome  to      |;|        FRI-Quest       |;|          vol.1         |;|                        |;|       Made by N.V      |;|                        |;*------------------------*\n"
ending_string: .asciz "*----------------------------*;|                            |;|       Congratulations      |;|      You have defeated     |;|       all the trolls!      |;|                            |;|    Thank you for playing   |;|                            |;*----------------------------*\n"
ending_string2: .asciz "*----------------------------*;|                            |;|       You have failed      |;|       to apprehend all     |;|       the miscreants!      |;|                            |;|    Better luck next time   |;|                            |;*----------------------------*\n"
player_name_info: .asciz "Your name is (4 letters only):\n"
new_line: .asciz "\n"
prompt: .asciz "Input: \n"
move_left: .asciz ": (moved left)\n"
move_right: .asciz ": (moved right)\n"
move_up: .asciz ": (moved forward)\n"
move_back: .asciz ": (moved back)\n"
player_cannot_attack: .asciz ": (not in range)\n"
enemy_is_dead: .asciz ": (enemy slain)\n"
enemy_move_right: .asciz "Next move: >\n"
enemy_move_down: .asciz "Next move: v\n"

@ player stuff
player_name: .asciz "    "
  .align
player_stat: .byte 0, 0, 100, 20 @ x, y, health, attack
player_power: .byte 50

@ enemy stuff (x pos, y pos, health, attack, is alive)
enemy: .byte 1, 1, 10, 2, 1,    3, 3, 10, 2, 1,    6, 3, 10, 10, 1,   8, 1, 10, 10, 1,   1, 8, 10, 10, 1,   3, 6, 10, 10, 1,   6, 6, 10, 10, 1,  8, 8, 10, 10, 1
  .align

_Lstack_end:
  .long __STACK_END__

.end

