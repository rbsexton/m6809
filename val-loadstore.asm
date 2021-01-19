; Generate a small ROM images for use in simulation.
; asm6809 val-loadstore.asm -o validation.bin -l validation.lst
; Post-Process this into a ROM image with hexdump. 

; Put the direct page data at the end so that 
; first instruction doesn't move.

		org $FF00

reset		

; ------------------------------------------------------
; Immediate Loads 
; ------------------------------------------------------
    ; Immediate Loads 
    lda #$45 
    ldb #$23 
  
    ; 16-bit Immediate Loads, single-byte instruction. 
    ldd #$cafe 
    ldu #$dead 
    ldx #$beef 

    ; 16-bit Immediate Loads, extended instructions  
    lds #$babe 
    ldy #$d00f 

; ------------------------------------------------------
; End of Test Spin Loop 
; ------------------------------------------------------

spin 
	nop
	bra spin

; ------------------------------------------------------
; Direct Page Loads 
; ------------------------------------------------------

;  lda #$ff 
;  tfr a,dp 
  
;  SETDP #$ff
  
  
    lda < byte2  
    ldb < byte6  

    ldd < byte6 
    ldu < byte2
    ldx < byte0 

    lds < byte4
    ldy < byte6


    ; 16-Bit Immediate 
    ldd #$dead 

; ------------------------------------------------------
; Stores 
; ------------------------------------------------------
    
    lda #$cf 
    sta byte4 


; ------------------------------------------------------
; Direct Page read payloads  
; ------------------------------------------------------
    
byte0
    fdb #$dead
byte2 
    fdb #$beef
byte4
    fdb #$cafe
byte6 
    fdb #$babe 




        	
    	
* Interrupt vector addresses at top of ROM.
	org $fffe
	fdb reset

 	end
