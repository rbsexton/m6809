; Generate a small ROM images for use in simulation.
; asm6809 validation.asm -o validation.bin -l validation.lst
; Post-Process this into a ROM image with hexdump. 

; Validation code for logical operators, immediate modes.
; Use the B register for a test code.

		org $FF00

          ; Condition codes: H NZVC
reset		
    ldb  #01
    clra 
    ora  #$3c; 
    anda #$0f; Should be 0x0c
    eora #$03; Should be 0x0f 
    coma     ; Should be 0xf0
    NOP

; --------------------------------------------------
; Arithmetic Shifts     
; --------------------------------------------------

; --------------  Walking one left
    ldb  #02
    lda #$01 
    lsla 
loop2 
    lsla 
    bcc loop2 

; ----  Walking one left

    ldb  #03 
    lda #$01 
loop3
    asla 
    asla 
    bcc loop3 
    

; ----  Walking pattern right, sign extension

    ldb  #04 
    lda #$80 
loop4 
    asra 
    bcc loop4 

; ----   Walking pattern right, no sign extension

    ldb  #05;
    lda #$40 
loop5 
    asra 
    bcc loop5 


; --------------------------------------------------
; Logical Shifts     
; --------------------------------------------------

; ----  Walking pattern right, no extension

    ldb  #06 
    lda #$80 
loop6 
    lsra 
    bcc loop6 

; -- Exit this loop with the carry set.

; --------------------------------------------------
; Rotates 
; --------------------------------------------------


; ----   Walking pattern left. c_in = 1
      
    ldb  #07; Walking zero left 
    lda #$00 
loop7 
    rola 
    bcc loop7

; ----   Walking pattern right. c_in = 1

    ldb  #08
    lda #$7f
loop8 
    rora 
    bcs loop8

; --------------------------------------------------
; Terminal State 
; --------------------------------------------------

    ldb  #09
spin 
    nop 
    bcs spin 



								
* Interrupt vector addresses at top of ROM
		org $fffe
		fdb reset

		end
