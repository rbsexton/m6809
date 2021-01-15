; Generate a small ROM images for use in simulation.
; asm6809 validation.asm -o validation.bin -l validation.lst
; Post-Process this into a ROM image with hexdump. 

		org $FF00

          ; Condition codes: H NZVC
reset		
		clra 
    inca
    lda #$ff
    inca

    nop 
    lda #$80
    asra 
    asra 
    asla 
    
    nop  

    ; Jump test
    lda #$80
loop 
    rora 
    bcc  loop 
    
    nop
    rola 
    rola 
    rola 
    rola 
    rola 

    nop 




    
    asla    
    lda #$7f
    inca     ; This should trigger overflow

    tfr cc,b ; Condition Code Check

    
    inca 
    tfr cc,b
    
    inca 
    tfr cc,b
    
    inca 
    tfr cc,b
    
    coma 
    lsra 
    	
    nop 
    nop
    nop 
    	
;		tfr a,dp	;Set direct page register to 0.
;		lds #ramstart
;		ldx #intvectbl
;		ldu #swi3vec
;		ldb #osvectbl-intvectbl
;		bsr blockmove   ;Initialize interrupt vectors from ROM.
;		ldx #osvectbl
;		ldu #0
;		ldb #endvecs-osvectbl
;		bsr blockmove	;Initialize I/O vectors from ROM.
;		bsr initacia	;Initialize serial port.
;		andcc #$0	;Enable interrupts
;* Put the 'saved' registers of the program being monitored on top of the
;* stack. There are 12 bytes on the stack for cc,b,a,dp,x,y,u and pc
								
* Interrupt vector addresses at top of ROM. Most are vectored through jumps
* in RAM.
		org $fffe
		fdb reset

		end
