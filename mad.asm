; MAD ASM
; nasm mad.asm -fbin -o mad.com

    org 100h 
 
section .text 
 
main:
   
    ; Push active display page (bh), current video mode (al), and number of character columns (ah) onto the stack
    mov ah, 0fh
    int 10h
    push bx
    push ax

    ; Change to medium resolution CGA mode (320x200 pixels, 4 colors)
    mov ax, 0004h
    int 10h

    ; Set background color to gray
    mov ah, 0bh
    mov bx, 0007h
    int 10h



    ; ; Restore original video mode
    ; pop ax
    ; mov ah, 00h    
    ; int 10h

    ; ; Restore original active display page
    ; mov ah, 05h
    ; pop bx
    ; mov al, bh
    ; int 10h

    ; exit
    int 20h
 
section .data
  ; program data
 
;   msg  db 'Hello world'
;   crlf db 0x0d, 0x0a
;   endstr db '$'
 
section .bss
  ; uninitialized data