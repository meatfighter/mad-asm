; 16-bit MAD Computer Program COM
; nasm mad.asm -fbin -o mad.com

    org 100h 
 
section .text 
 
main:

    ; Push current video mode onto stack
    mov ah, 0fh
    int 10h
    push ax

    ; Set mode to CGA 320x200
    mov ax, 0004h
    int 10h

    ; write pixel dot
    mov ah, 0ch
    mov al, 07h
    mov cx, 160
    mov dx, 100
    int 10h

    ; Restore original video mode
    pop ax
    mov ah, 00h    
    int 10h

    ; exit
    int 20h
 
section .data
  ; program data
 
;   msg  db 'Hello world'
;   crlf db 0x0d, 0x0a
;   endstr db '$'
 
section .bss
  ; uninitialized data