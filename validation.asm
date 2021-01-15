; Generate a small ROM images for use in simulation.
; asm6809 validation.asm -o validation.bin -l validation.lst
; Post-Process this into a ROM image with hexdump. 

		org $FF00

          ; Condition codes: H NZVC
reset		
		clra ; CC: X 0100 
    inca ; CC: X ...X
     
    asla ; 
    asla 

    tfr cc,b ; Condition Code Check

    lda #$ff 
    
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
