; Generate a small ROM images for use in simulation.
; asm6809 val-loadstore.asm -o validation.bin -l validation.lst
; Post-Process this into a ROM image with hexdump. 


		org $FF00

byte0
    fdb #$dead
byte2 
    fdb #$beef
byte4
    fdb #$cafe
byte6 
    fdb #$babe 

          ; Condition codes: H NZVC
reset		

  lda #$ff 
  tfr a,dp 
  
  SETDP #$ff

; ------------------------------------------------------
; Loads 
; ------------------------------------------------------
    ; Immediate Loads 
    lda #$45 
    ldb #$23 
  
    ; 16-bit Immediate Loads 
    ldd #$cafe 
    lds #$babe 
    ldu #$dead 
    ldx #$beef 
    ldy #$d00f 
    
  
    ; Direct Page Loads 
    lda < byte2  
    ldb < byte6  

    ldd < byte6 
    lds < byte4
    ldu < byte2
    ldx < byte0 
    ldy < byte6


    ; 16-Bit Immediate 
    ldd #$dead 

; ------------------------------------------------------
; Stores 
; ------------------------------------------------------
    
    lda #$cf 
    sta byte4 

; ------------------------------------------------------
; Spin 
; ------------------------------------------------------

spin 
	nop
	bra spin
        	
    	
* Interrupt vector addresses at top of ROM.
	org $fffe
	fdb reset

 	end
