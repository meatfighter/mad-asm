; MADasm
;
; 

; compile: nasm mad.asm -f bin -o mad.com
;
; Run in DOSBox or on a PC with a Color Graphics Adapter (CGA)

cpu 8086
bits 16
org 100h 
 
section .text

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

    ; Select green-red-brown palette
    mov ah, 0bh
    mov bx, 0100h
    int 10h

    ; Draw 522 line segments
    mov dx, 522                                 ;   lines = 522;
    mov si, endpoints                           ;   si = endpoints;
    .drawLines:
        mov bl, [si]                            ;   x0 = *si;                          
        inc si                                  ;   ++si;

        mov bh, [si]                            ;   y0 = *si;
        inc si                                  ;   ++si;

        mov ah, [si]                            ;   x1 = *si;
        mov [.x1_0+2], ah                       ;   modify code: cmp x0, x1
        mov [.x1_1+2], ah                       ;   modify code: cmp x0, x1
        inc si                                  ;   ++si;

        sub ah, bl                              ;   delX = x1 - x0;
        jns .delXPos                            ;   if (delX < 0) {
            neg ah                              ;       delX = -delX;            
            mov byte [.stepX+1], 0xcb           ;       modify code: dec x0
            jmp .delXEnd
        .delXPos:                               ;   } else {
            mov byte [.stepX+1], 0xc3           ;       modify code: inc x0
        .delXEnd:                               ;   }
        mov [.delX_0+1], ah                     ;   modify code: mov al, delX
        mov [.delX_1+2], ah                     ;   modify code: add err, delX
        mov ch, ah                              ;   err = delX;
        
        mov ah, [si]                            ;   y1 = *si;
        mov [.y1_0+2], ah                       ;   modify code: cmp y0, y1
        mov [.y1_1+2], ah                       ;   modify code: cmp y0, y1
        inc si                                  ;   ++si;

        mov al, bh
        sub al, ah                              ;   delY = y0 - y1;
        mov [.delY_0+2], al                     ;   modify code: cmp ah, delY
        mov [.delY_1+2], al                     ;   modify code: add err, delY
                 
        add ch, al                              ;   err += delY;

        .plotLoop:                              ;   while (true) {

            ; -- draw two horizontally-adjacent red pixels at (x0, y0) and (x0 + 1, y0) --------------------------------
            mov ah, bh
            and ah, 1
            shl ah, 1
            or ah, 0xb8
            mov al, 0
            mov es, ax                          ;       es = 0xb800 | ((y0 & 1) << 9);

            mov ah, 0
            mov al, bh
            shr ax, 1
            mov cl, 4
            shl ax, cl
            mov di, ax
            shl ax, 1
            shl ax, 1
            add di, ax                          ;       di = 80 * (y0 >> 1);

            mov ah, 0
            mov al, bl
            shr ax, 1
            shr ax, 1
            add di, ax                          ;       di += (x0 >> 2);

            mov ax, 0xa000
            mov cl, bl
            and cl, 3
            shl cl, 1
            shr ax, cl                          ;       ax = 0xa000 >> ((x0 & 3) << 1);

            or [es:di], ah                      ;       *di |= ah;

            test al, al
            jz .no2ndWrite                      ;       if (al != 0) {
                inc di
                or [es:di], al                  ;           *(di + 1) |= al;
            .no2ndWrite:                        ;       }
            ; ----------------------------------------------------------------------------------------------------------

            .x1_0:
                cmp bl, 0xff                    ;       modified code: cmp x0, x1 
            jne .ptsNotEq                       ;       if (x0 == x1) {                                  
                .y1_0:    
                    cmp bh, 0xff                ;           modified code: cmp y0, y1
                                                ;           if (y0 == y1) {
                je .endPlotLoop                 ;               break;          
            .ptsNotEq:                          ;           }   
                                                ;       }

            mov ah, ch
            shl ah, 1                           ;       ah = err << 1;

            .delY_0:
                cmp ah, 0xff                    ;       modified code: cmp ah, delY
            js .e2dyEnd                         ;       if (ah >= delY) {                  
                .x1_1:
                    cmp bl, 0xff                ;           modified code: cmp x0, x1
                                                ;           if (x0 == x1) {         
                je .endPlotLoop                 ;               break;
                                                ;           }

                .delY_1:                   
                    add ch, 0xff                ;           modified code: add err, delY
                
                .stepX:
                    inc bl                      ;           modified code: inc x0 / dec x0                
            .e2dyEnd:                           ;       }

            .delX_0:
                mov al, 0xff                    ;       modified code: mov al, delX
            cmp al, ah                         
            js .dxe2End                         ;       if (delX >= ah) {                 
                .y1_1:
                    cmp bh, 0xff                ;           modified code: cmp y0, y1                    
                                                ;           if (y0 == y1) {
                je .endPlotLoop                 ;               break;
                                                ;           }
                
                .delX_1:
                    add ch, 0xff                ;           modified code: add err, delX
                
                inc bh                          ;           ++y0;                
            .dxe2End:                           ;       }            
            
            jmp .plotLoop           
        .endPlotLoop:                           ;   }

        dec dx                                  ;   if (--lines != 0) {
        jnz .drawLines                          ;       goto drawLines;
                                                ;   }
    
    ; Print motto at column 12 and row 23 in brown
    mov bx, 3
    mov cx, 1
    mov dx, 170Ch
    mov si, motto
    .printMotto:
        mov al, [si]
        test al, al
        jz .endPrintMotto

        mov ah, 02h    
        int 10h

        mov ah, 09h        
        int 10h

        inc dl
        inc si
        jmp .printMotto        
    .endPrintMotto:    

    call .waitForKeypress                       ;   waitForKeyPress();

    ; Change to 80x25 16-color text mode
    mov ax, 0003h
    int 10h

    ; Hide the cursor
    mov ah, 01h
    mov cx, 2020h
    int 10h

    ; Print copyright at column 22 and row 11 in gray
    mov ax, 0xb800
    mov es, ax
    mov si, copyright
    mov di, 2 * 22 + 160 * 11
    .printCopyright:
        mov al, [si]
        test al, al
        jz .endPrintCopyright

        mov [es:di], al
        mov [es:di+1], byte 7
                
        inc si
        add di, 2
        jmp .printCopyright
    .endPrintCopyright:    

    call .waitForKeypress                       ;   waitForKeyPress();

    ; Restore original video mode
    pop ax
    mov ah, 00h    
    int 10h

    ; Restore original active display page
    mov ah, 05h
    pop bx
    mov al, bh
    int 10h

    ; Exit
    mov ax, 4c00h
    int 21h

    ; waitForKeyPress() ------------------------------------------------------------------------------------------------
    .waitForKeypress:
        .waitLoop:
            mov ah, 01h
            int 16h
            jz .waitLoop
        mov ah, 00h
        int 16h
        ret
    ; ------------------------------------------------------------------------------------------------------------------        

section .data

    endpoints:
        dd 0x64765f7a, 0x66745f7c, 0x5e885e7e, 0x67766677, 0x76687564, 0x7566695a, 0x4c964c8c, 0x55735073, 0x75656a5a
        dd 0x6a5b615a, 0x4d964d8c, 0x54744c74, 0x685a635b, 0x73c66ac8, 0x50914b7d, 0x2d98299c, 0x89608056, 0x75547054
        dd 0x704d6f50, 0x80628064, 0x90c18dc1, 0x9170896a, 0x95779170, 0xa3a190be, 0x659d64a4, 0x64b361a7, 0x669d64a2
        dd 0x62ae61a2, 0x6c79687a, 0x6b77687c, 0x6c7c6b78, 0x6b7a697d, 0x575b4f62, 0x68ca64c4, 0x509e4b9e, 0x518f4c8b
        dd 0x7a917a90, 0x7d8f7d8f, 0x79907990, 0x768e768e, 0x82687967, 0x8055724c, 0x7c5a765a, 0x7a557152, 0x80677b68
        dd 0x6f4e6c59, 0x7252715a, 0x7f5f725c, 0x71646c64, 0x73c767ca, 0x52924b7f, 0x2f9b29a0, 0x88bb7fb6, 0x83737e83
        dd 0x8c8989a2, 0x88b37fb5, 0xa291a0a7, 0xa39ca392, 0xa29ca1a4, 0xa1a092c0, 0x8f9c8994, 0x837e7d84, 0x86bc7baa
        dd 0x8e8f899d, 0x8cc684c4, 0x8bc486c5, 0x8ec287c4, 0x88c287c2, 0x72a871ac, 0x6db26bb2, 0x6ca46bad, 0x8ba08aae
        dd 0x97928e88, 0x8aa78a90, 0x979b8ea9, 0x74656c65, 0x6dca67cb, 0x4c7c4b7c, 0x2f982ba0, 0x75677066, 0x73c86cd2
        dd 0x54794b7a, 0x309a2998, 0x8a678359, 0x7d5b735e, 0x6e4f6b56, 0x75607056, 0x6c66606a, 0x6bd266d2, 0x54784b77
        dd 0x31a13097, 0x627c5f7f, 0x627d5f80, 0x62895f7d, 0x6183617f, 0x75527352, 0x826a7e6a, 0x815a784f, 0x816b7d67
        dd 0x778f7590, 0x778e758f, 0x779c759d, 0x789d769d, 0x7e9d7da1, 0x80947f88, 0x7c947a8f, 0x808c7c86, 0x6b7e6a82
        dd 0x6b856a84, 0x6b836b82, 0x6a856a7e, 0x6a675f6c, 0x67d365d0, 0x51794c7a, 0x32a43197, 0x5f6b5a6b, 0x67c762c6
        dd 0x517a4e79, 0x32a731ad, 0x37773470, 0x39733470, 0x39733572, 0x39733767, 0x5e6c5a6c, 0x66c665c7, 0x52774b76
        dd 0x33a332af, 0x7e53764d, 0x7d647c5e, 0x8360805b, 0x7c4f714d, 0x71de6dd8, 0x79df70de, 0x76df71df, 0x7add76de
        dd 0x979c8eaa, 0x8baa899d, 0x8f9889a0, 0x89808274, 0x97918d85, 0x8ca18c90, 0x88748476, 0x979094a0, 0x4b5f4764
        dd 0x4a604060, 0x4e644764, 0x59594e62, 0x6ca869ac, 0x6cac69a7, 0x6b9e69a0, 0x6aa069a3, 0x83c57ec4, 0x81c579c6
        dd 0x80c67ac7, 0x7dc57bc5, 0x83ca81c8, 0x83cb79cc, 0x82cc7dcd, 0x82ca7fc8, 0x64d052ce, 0x67c762c6, 0x35a834a8
        dd 0x35ad35aa, 0x7e5c755b, 0x794d744c, 0x8a627c54, 0x7c647b5f, 0xa08f9a85, 0x9da792bc, 0x9aac98ae, 0x9fa79ab2
        dd 0x84bc82bb, 0x849b839a, 0x847c837a, 0x8d8b8d8b, 0x86b981ba, 0x8ba789af, 0x87788776, 0x88768877, 0x6889638a
        dd 0x688a648b, 0x668c668a, 0x658c6489, 0x85b97faf, 0x8992898e, 0x887d8676, 0x968f9088, 0x64d153d0, 0x63c55ec7
        dd 0x36b036ac, 0x37b237ad, 0x5cd351cc, 0x64c45ec6, 0x48ca36b2, 0x48cc38b6, 0x81cd7dcd, 0x80ca7fca, 0x7ad477cd
        dd 0x79d477ce, 0x79da74da, 0x72cb6ed1, 0x669e61a1, 0x65a061a2, 0x62b260a4, 0x63b362a3, 0x72da71d6, 0x72d471d9
        dd 0x79d973d8, 0x76d974d9, 0x73da71d4, 0x6a776686, 0x6b8a6988, 0x6b896784, 0x6782677d, 0x6dac6aaf, 0x6ca969a4
        dd 0x6da06ca2, 0x70ad70a6, 0x6f7c6e86, 0x707d6f83, 0x707f6e7d, 0x6e806e7e, 0x5cd155ce, 0x5dc757c2, 0x49c749cd
        dd 0x50ce49c7, 0x5bc755c2, 0x625b5d5c, 0x50cc4eca, 0x4e974e94, 0x625c5d5e, 0x5c5c5a5b, 0x51a04e98, 0x50a14e9b
        dd 0x79cd75d0, 0x7fd17cd1, 0x7ed272d3, 0x7ed377d4, 0x76527053, 0x7a4e714e, 0x765f7055, 0x8361815f, 0x7f607b61
        dd 0x7e647e61, 0x7f647f61, 0x8a64875c, 0x6ba269af, 0x72ad6ab0, 0x71ae6cb0, 0x72ac70a2, 0x3865376c, 0x39683965
        dd 0x3a643a68, 0x3b603964, 0x7e887d92, 0x7c9e7c9e, 0x7e927d8c, 0x7f917f8c, 0x6ba069a1, 0x9373866c, 0x8e6c876b
        dd 0x92778968, 0x9372896c, 0x94788d6d, 0x95789070, 0x9d858a6d, 0x967c8c6b, 0x5c5b545f, 0x50a24a9b, 0x4f9d4a9a
        dd 0x4e9d4b9d, 0x6fce6ed4, 0x6ed06dd9, 0x6ed06ed8, 0x6fdd6dd9, 0x99b395bc, 0x94ba92bf, 0x94be8dc0, 0x91c08ac1
        dd 0x8cc879df, 0x8cca82d3, 0x87cc82d2, 0x82d77edc, 0x42603b67, 0x445f3b68, 0x4e5e415f, 0x4d5f3e64, 0x789d769e
        dd 0x7ca67ca6, 0x7e9b7ca0, 0x7ea07d9c, 0x8b8c8a83, 0x8ea18aa1, 0x80b97eae, 0x82798082, 0x85bc7daf, 0x9794969c
        dd 0x93a18ea9, 0x877c8577, 0x58594d62, 0x4ca84b9e, 0x51aa4ea6, 0x55b64fae, 0x575b4e64, 0x4dad4ca0, 0x4ead4da2
        dd 0x54b650b0, 0x947c9179, 0xa391937a, 0x9c84917a, 0xa18c927d, 0xa28e9e88, 0xa0919d88, 0x9d86937d, 0xa3a0a08a
        dd 0x7ca779a4, 0x7ea479a6, 0x7ea67ba7, 0x7ea37da7, 0x618a5f82, 0x62865f8a, 0x608a5f89, 0x5f845f88, 0x80af7caa
        dd 0x979e91a7, 0x8ca78982, 0x889b849b, 0x67886589, 0x688b6688, 0x6984697e, 0x69846982, 0x71886f89, 0x70886f8b
        dd 0x71896d8b, 0x708b6d8c, 0x5b6d536e, 0x52b952b4, 0x53ba51ba, 0x51bb50c0, 0x5a6e566e, 0x51c151be, 0x57c152c1
        dd 0x55c052c0, 0x53704e71, 0x55734e72, 0x3092299a, 0x30902998, 0x978f9490, 0x8da488af, 0x8f948e94, 0x979a9591
        dd 0x8a658861, 0x77537155, 0x896a846b, 0x7e5e795b, 0x89668760, 0x8868856c, 0x81597d50, 0x865c7c50, 0x83bc83b3
        dd 0x96929692, 0x6c556b5a, 0xa1a1a190, 0x6fa26fa2, 0x6fad6fad, 0x69a669a6, 0x6da26ca1, 0x8378827d, 0x8f9b8e98
        dd 0x87bb81b9, 0x89b084b5, 0x639d5fac, 0x60af5fa7, 0x649d61b0, 0x7f977d85, 0x7e867989, 0x7c857a88, 0x8cc77ed8
        dd 0x89cd7adf, 0x8ac789c2, 0x718a6e8a, 0x6774607c, 0x36772e92, 0x36773090, 0x357e328b, 0x37773477, 0x9597938f
        dd 0x8479837d, 0x879a869a, 0x8e9b8d9b, 0x1aec10ec, 0x0feb0bea, 0x1fea1beb, 0x24e420e9, 0x0bea06e4, 0x06e303dc
        dd 0x29d824e3, 0x28ca28d9, 0x29d829ce, 0x03cd03dc, 0x05c804cd, 0x27cb25c5, 0x27c826c5, 0x04c604c7, 0x03be03c5
        dd 0x29be26c4, 0x1fc00ac0, 0x1fbf0abf, 0x21bc20bf, 0x0abc09bf, 0x06ba04bc, 0x09bb06bb, 0x0aba07ba, 0x22b922bb
        dd 0x28b228be, 0x29b429bc, 0x27b027b3, 0x22b80baa, 0x0aae0aac, 0x09ae05ae, 0x29ac26af, 0x29aa27ad, 0x29a729a9
        dd 0x28a728aa, 0x04ad03a3, 0x29a624a4, 0x29a424a3, 0x23a320a8, 0x1fa81ea7, 0x1e951ea7, 0x1f941fa7, 0x069e04a2
        dd 0x059d0397, 0x04900396, 0x098f058f, 0x0a8e068e, 0x0a920a90, 0x21860b94, 0x21850b92, 0x20911e94, 0x23952191
        dd 0x22972296, 0x27972397, 0x29952796, 0x298e2994, 0x288f2894, 0x298f268b, 0x298e278a, 0x28822889, 0x29832988
        dd 0x2982267d, 0x2980277c, 0x22832284, 0x21820b7c, 0x0a7f0a7d, 0x097f057f, 0x2872287a, 0x29722979, 0x29712271
        dd 0x28702370, 0x22742272, 0x047e0378, 0x06730477, 0x22741370, 0x22741271, 0x0674036e, 0x036a036d, 0x28651370
        dd 0x05660468, 0x08660666, 0x0a650665, 0x0b6a0966, 0x18650b6a, 0x18640b68, 0x19620b5c, 0x0a600a5e, 0x09600560
        dd 0x045f0359, 0x285e2864, 0x295c2964, 0x295c1353, 0x285c1253, 0x214e1253, 0x05550458, 0x0654044f, 0x0349034e
        dd 0x2350224f, 0x23522254, 0x27542354, 0x29522753, 0x284d2852, 0x294e2950, 0x294d2649, 0x294c2748, 0x05460448
        dd 0x0a460646, 0x0a440644, 0x0a490a47, 0x21440b4a, 0x22430b49, 0x28402847, 0x293e2944, 0x223e2243, 0x293e223e
        dd 0x283d233d, 0x18df12df, 0x1ade10de, 0x11dd10dd, 0x1ddc18de, 0x21d71cdd, 0x0fdd0bd8, 0x0edd09d7, 0x09d009d7
        dd 0x0ad80acd, 0x21d021d7, 0x20cd20ce, 0x0bcd0bce, 0x1fcc0bcc, 0x17a30d9e, 0x17a20d9d, 0x179717a1, 0x17960e9d

    motto       db  'WHAT, ME WORRY?', 0
    copyright   db  'COPYRIGHT 1985 E.C. PUBLICATIONS', 0