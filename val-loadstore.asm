; Generate a small ROM images for use in simulation.
; asm6809 val-loadstore.asm -o validation.bin -l validation.lst
; Post-Process this into a ROM image with hexdump. 

    org $0040  
target    

    org $0130  
target2

		org $FF00

          ; Condition codes: H NZVC
reset		
  
    ; Immediate Loads 
    lda #$45 
    ldb #$23 
  
    ldd #$dead 
    nop

spin 
	nop
	bra spin
        	
    nop 
    nop
    nop 
    	
* Interrupt vector addresses at top of ROM.
	org $fffe
	fdb reset

 	end
