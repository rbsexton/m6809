; Generate a small ROM images for use in simulation.
; asm6809 val-loadstore.asm -o validation.bin -l validation.lst
; Post-Process this into a ROM image with hexdump. 

; Put the direct page data at the end so that 
; first instruction doesn't move.

		org $FF00

reset		

; ------------------------------------------------------
; Indexed Load operations  
; ------------------------------------------------------

;  lda #$ff 
;  tfr a,dp 
  
    SETDP #$ff
  
    ldx #$0100 
    
    lda ,x      ;  No offset     $100
    lda $4,x    ;  5-bit offset  $104 
    lda -64,x  ;  8-bit offset $0  
    lda $200,x  ; 16-bit offset  $300

    ; Indirection.  Calculate the address with the pointer. 
    lda [,x]      ;  No offset     $100
    lda [$4,x]    ;  5-bit offset  $104 
    lda [-64,x]  ;  8-bit offset $0  
    lda [$200,x]  ; 16-bit offset  $300

    ; Accumulator Offsets 
    lda #$40 
    ldb #$60
  
    ; Direct 
    lda a,x     ; Accumulator offset $140 
    lda b,x     ; Accumulator offset $140 

    ldd #$148 
    ldd d,x     ; D Offset $248

    lda [a,x]     ; Accumulator offset $140 
    lda [b,x]     ; Accumulator offset $140 

    ldd [d,x]     ; D Offset $248

    ; PostIncrement 
    lda ,x + 
    ldb ,x + 
    ldd ,x ++
    
    ; Pre-Decrement 
    lda ,- x 
    ldb ,- x 
    ldd ,-- x 
     
    ; Indirect Forms 
    ldd [,x ++]
    ldd [,-- x] 
    
    ; Program Counter Relative forms.
    lda $4,pc 
    lda $200,pc 
    lda -512,pc 

    lda [$4,pc] 
    lda [$200,pc] 
    
    ; Extended Indirect 
    lda [$f00a]
    
; ------------------------------------------------------
; End of Test Spin Loop 
; ------------------------------------------------------

spin 
	nop
	bra spin


    ; 16-Bit Immediate 
    ldd #$dead 

        	
    	
* Interrupt vector addresses at top of ROM.
	org $fffe
	fdb reset

 	end
