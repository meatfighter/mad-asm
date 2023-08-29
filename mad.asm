; MAD ASM
; nasm mad.asm -fbin -o mad.com

    cpu 8086
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

    ; Draw line segments
        
    mov si, endpoints
    cld
    .drawLines:
        mov ax, ds
        mov es, ax
        mov di, x0               
        movsw                                   ;   x0 = endpoints[si++]; y0 = endpoints[si++];
        movsw                                   ;   x1 = endpoints[si++]; y1 = endpoints[si++];

        mov ah, [x1]
        sub ah, [x0]
        mov [delX], ah                          ;   delX = x1 - x0;
        jns .delXPos                            ;   if (delX < 0) {
            neg byte [delX]                     ;       delX = -delX;
            
            mov byte [.stepX+1], 0eh            ;       self-modifying code (--x0;)

            jmp .delXEnd
        .delXPos:                               ;   } else {
            mov byte [.stepX+1], 06h            ;       self-modifying code (++x0;)
        .delXEnd:                               ;   }

        mov ah, [y1]
        sub ah, [y0]
        mov [delY], ah                          ;   delY = y1 - y0;
        jns .delYPos                            ;   if (delY < 0) {
            mov byte [.stepY+1], 0eh            ;       self-modifying code (--y0;)
            jmp .delYEnd
        .delYPos:                               ;   } else {
            neg byte [delY]                     ;       delY = -delY;
            
            mov byte [.stepY+1], 06h            ;       self-modifying code (++y0;)
        .delYEnd:                               ;   } 

        mov ah, [delX]
        add ah, [delY]
        mov [err], ah                           ;   err = delX + delY;

        .plotLoop:                              ;   while (true) {

            ; -- write two adjacent red pixels at (x0, y0) and (x0 + 1, y0) --------------------------------------------
            mov ah, [y0]
            and ah, 1
            shl ah, 1
            or ah, 0xb8
            mov al, 0
            mov es, ax                          ;   es = 0xb800 | ((y0 & 1) << 9);

            mov di, 0
            mov ah, 0
            mov al, [y0]
            shr ax, 1
            mov cl, 4
            shl ax, cl
            add di, ax
            shl ax, 1
            shl ax, 1
            add di, ax                          ;   di = 80 * (y0 >> 1);

            mov ah, 0
            mov al, [x0]
            shr ax, 1
            shr ax, 1
            add di, ax                          ;   di += (x0 >> 2);

            mov ax, 0xa000
            mov cl, [x0]
            and cl, 3
            shl cl, 1
            shr ax, cl                          ;   ax = 0xa000 >> ((x0 & 3) << 1);

            or [es:di], ah                      ;   *di |= ah;

            or al, al                           
            jz .no2ndWrite                      ;   if (al != 0) {
                inc di
                or [es:di], al                  ;       *(di + 1) |= al;
            .no2ndWrite:                        ;   }
            ; ----------------------------------------------------------------------------------------------------------

            mov ah, [x0]
            cmp ah, [x1]                        ;       if (x0 == x1) {
            jne .ptsNotEq       
                mov ah, [y0]                    ;           if (y0 == y1) {
                cmp ah, [y1]                    ;               break; 
                je .endPlotLoop                 ;           }             
            .ptsNotEq:                          ;       }

            mov ah, [err]
            shl ah, 1                           ;       ah = err << 1;

            cmp ah, [delY]                         
            js .e2dyEnd                         ;       if (ah >= delY) {
                mov al, [x0]                    ;           if (x0 == x1) {
                cmp al, [x1]                    ;               break;
                je .endPlotLoop                 ;           }

                mov al, [err]                   
                add al, [delY]
                mov [err], al                   ;           err += delY;
                
                .stepX:
                    inc byte [x0]               ;           self-modifying code: ++x0; or --x0;
                
            .e2dyEnd:                           ;       }

            cmp [delX], ah                         
            js .dxe2End                         ;       if (delX >= ah) {
                mov al, [y0]                    ;           if (y0 == y1) {
                cmp al, [y1]                    ;               break;
                je .endPlotLoop                 ;           }

                mov al, [err]                   
                add al, [delX]
                mov [err], al                   ;           err += delX;
                
                .stepY:
                    inc byte [y0]               ;           self-modifying code: ++y0; or --y0;
                
            .dxe2End:                           ;       }            
            
            jmp .plotLoop           
        .endPlotLoop:                           ;   }

        dec word [lines]                        ;   if (--lines != 0) {
        jnz .drawLines                          ;       goto drawLines;
                                                ;   }


    ; Wait for a keypress
    .waitForKey:
        mov ah, 01h
        int 16h
        jz .waitForKey
    mov ah, 00h
    int 16h    

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
 
section .data

    lines   dw  522

    x0      db  0
    y0      db  0
    x1      db  0
    y1      db  0
    delX    db  0
    delY    db  0
    err     db  0

    endpoints:
        dd 0x5f7a6476, 0x5f7c6674, 0x5e885e7e, 0x66776776, 0x75647668, 0x695a7566, 0x4c964c8c, 0x50735573, 0x75656a5a
        dd 0x615a6a5b, 0x4d964d8c, 0x4c745474, 0x635b685a, 0x6ac873c6, 0x4b7d5091, 0x2d98299c, 0x89608056, 0x75547054
        dd 0x6f50704d, 0x80628064, 0x90c18dc1, 0x9170896a, 0x95779170, 0x90bea3a1, 0x64a4659d, 0x64b361a7, 0x64a2669d
        dd 0x61a262ae, 0x6c79687a, 0x687c6b77, 0x6c7c6b78, 0x697d6b7a, 0x4f62575b, 0x68ca64c4, 0x509e4b9e, 0x518f4c8b
        dd 0x7a917a90, 0x7d8f7d8f, 0x79907990, 0x768e768e, 0x82687967, 0x8055724c, 0x7c5a765a, 0x71527a55, 0x80677b68
        dd 0x6f4e6c59, 0x715a7252, 0x7f5f725c, 0x6c647164, 0x67ca73c7, 0x4b7f5292, 0x2f9b29a0, 0x88bb7fb6, 0x7e838373
        dd 0x89a28c89, 0x88b37fb5, 0xa0a7a291, 0xa39ca392, 0xa1a4a29c, 0x92c0a1a0, 0x8f9c8994, 0x837e7d84, 0x86bc7baa
        dd 0x899d8e8f, 0x84c48cc6, 0x8bc486c5, 0x8ec287c4, 0x87c288c2, 0x71ac72a8, 0x6db26bb2, 0x6bad6ca4, 0x8aae8ba0
        dd 0x97928e88, 0x8aa78a90, 0x8ea9979b, 0x74656c65, 0x6dca67cb, 0x4b7c4c7c, 0x2f982ba0, 0x75677066, 0x6cd273c8
        dd 0x54794b7a, 0x2998309a, 0x8a678359, 0x7d5b735e, 0x6e4f6b56, 0x70567560, 0x606a6c66, 0x66d26bd2, 0x4b775478
        dd 0x31a13097, 0x5f7f627c, 0x5f80627d, 0x62895f7d, 0x6183617f, 0x75527352, 0x7e6a826a, 0x815a784f, 0x816b7d67
        dd 0x778f7590, 0x778e758f, 0x779c759d, 0x789d769d, 0x7da17e9d, 0x80947f88, 0x7c947a8f, 0x808c7c86, 0x6a826b7e
        dd 0x6a846b85, 0x6b836b82, 0x6a856a7e, 0x5f6c6a67, 0x65d067d3, 0x4c7a5179, 0x32a43197, 0x5a6b5f6b, 0x62c667c7
        dd 0x4e79517a, 0x31ad32a7, 0x34703777, 0x39733470, 0x35723973, 0x37673973, 0x5a6c5e6c, 0x65c766c6, 0x4b765277
        dd 0x33a332af, 0x7e53764d, 0x7d647c5e, 0x8360805b, 0x7c4f714d, 0x6dd871de, 0x79df70de, 0x71df76df, 0x7add76de
        dd 0x979c8eaa, 0x8baa899d, 0x8f9889a0, 0x89808274, 0x97918d85, 0x8ca18c90, 0x88748476, 0x94a09790, 0x47644b5f
        dd 0x4a604060, 0x4e644764, 0x59594e62, 0x69ac6ca8, 0x6cac69a7, 0x69a06b9e, 0x69a36aa0, 0x7ec483c5, 0x79c681c5
        dd 0x80c67ac7, 0x7dc57bc5, 0x83ca81c8, 0x79cc83cb, 0x82cc7dcd, 0x82ca7fc8, 0x52ce64d0, 0x62c667c7, 0x35a834a8
        dd 0x35ad35aa, 0x7e5c755b, 0x744c794d, 0x8a627c54, 0x7c647b5f, 0xa08f9a85, 0x92bc9da7, 0x98ae9aac, 0x9ab29fa7
        dd 0x84bc82bb, 0x849b839a, 0x837a847c, 0x8d8b8d8b, 0x86b981ba, 0x89af8ba7, 0x87788776, 0x88768877, 0x6889638a
        dd 0x688a648b, 0x668c668a, 0x658c6489, 0x85b97faf, 0x8992898e, 0x887d8676, 0x968f9088, 0x64d153d0, 0x5ec763c5
        dd 0x36b036ac, 0x37b237ad, 0x51cc5cd3, 0x64c45ec6, 0x48ca36b2, 0x38b648cc, 0x7dcd81cd, 0x80ca7fca, 0x7ad477cd
        dd 0x79d477ce, 0x74da79da, 0x6ed172cb, 0x61a1669e, 0x65a061a2, 0x60a462b2, 0x63b362a3, 0x71d672da, 0x71d972d4
        dd 0x73d879d9, 0x76d974d9, 0x73da71d4, 0x6a776686, 0x6b8a6988, 0x6b896784, 0x6782677d, 0x6aaf6dac, 0x6ca969a4
        dd 0x6ca26da0, 0x70ad70a6, 0x6e866f7c, 0x707d6f83, 0x707f6e7d, 0x6e806e7e, 0x5cd155ce, 0x57c25dc7, 0x49c749cd
        dd 0x50ce49c7, 0x5bc755c2, 0x5d5c625b, 0x50cc4eca, 0x4e974e94, 0x625c5d5e, 0x5a5b5c5c, 0x51a04e98, 0x50a14e9b
        dd 0x75d079cd, 0x7cd17fd1, 0x72d37ed2, 0x77d47ed3, 0x76527053, 0x7a4e714e, 0x765f7055, 0x8361815f, 0x7f607b61
        dd 0x7e647e61, 0x7f647f61, 0x8a64875c, 0x6ba269af, 0x72ad6ab0, 0x6cb071ae, 0x72ac70a2, 0x376c3865, 0x39683965
        dd 0x3a643a68, 0x3b603964, 0x7e887d92, 0x7c9e7c9e, 0x7d8c7e92, 0x7f917f8c, 0x69a16ba0, 0x9373866c, 0x8e6c876b
        dd 0x92778968, 0x9372896c, 0x94788d6d, 0x95789070, 0x9d858a6d, 0x967c8c6b, 0x545f5c5b, 0x4a9b50a2, 0x4f9d4a9a
        dd 0x4b9d4e9d, 0x6ed46fce, 0x6dd96ed0, 0x6ed06ed8, 0x6fdd6dd9, 0x95bc99b3, 0x92bf94ba, 0x8dc094be, 0x8ac191c0
        dd 0x8cc879df, 0x82d38cca, 0x87cc82d2, 0x82d77edc, 0x42603b67, 0x445f3b68, 0x4e5e415f, 0x3e644d5f, 0x789d769e
        dd 0x7ca67ca6, 0x7ca07e9b, 0x7ea07d9c, 0x8b8c8a83, 0x8aa18ea1, 0x80b97eae, 0x82798082, 0x85bc7daf, 0x969c9794
        dd 0x8ea993a1, 0x877c8577, 0x4d625859, 0x4ca84b9e, 0x51aa4ea6, 0x55b64fae, 0x575b4e64, 0x4dad4ca0, 0x4da24ead
        dd 0x54b650b0, 0x947c9179, 0xa391937a, 0x9c84917a, 0xa18c927d, 0x9e88a28e, 0xa0919d88, 0x9d86937d, 0xa3a0a08a
        dd 0x7ca779a4, 0x7ea479a6, 0x7ea67ba7, 0x7da77ea3, 0x618a5f82, 0x5f8a6286, 0x5f89608a, 0x5f845f88, 0x80af7caa
        dd 0x91a7979e, 0x89828ca7, 0x889b849b, 0x67886589, 0x688b6688, 0x6984697e, 0x69846982, 0x71886f89, 0x70886f8b
        dd 0x71896d8b, 0x708b6d8c, 0x536e5b6d, 0x52b952b4, 0x53ba51ba, 0x50c051bb, 0x5a6e566e, 0x51c151be, 0x57c152c1
        dd 0x52c055c0, 0x4e715370, 0x55734e72, 0x3092299a, 0x29983090, 0x978f9490, 0x88af8da4, 0x8e948f94, 0x979a9591
        dd 0x8a658861, 0x77537155, 0x896a846b, 0x795b7e5e, 0x87608966, 0x856c8868, 0x81597d50, 0x865c7c50, 0x83bc83b3
        dd 0x96929692, 0x6b5a6c55, 0xa1a1a190, 0x6fa26fa2, 0x6fad6fad, 0x69a669a6, 0x6da26ca1, 0x827d8378, 0x8f9b8e98
        dd 0x87bb81b9, 0x89b084b5, 0x5fac639d, 0x60af5fa7, 0x649d61b0, 0x7d857f97, 0x79897e86, 0x7a887c85, 0x8cc77ed8
        dd 0x7adf89cd, 0x89c28ac7, 0x718a6e8a, 0x607c6774, 0x36772e92, 0x30903677, 0x357e328b, 0x34773777, 0x9597938f
        dd 0x837d8479, 0x879a869a, 0x8e9b8d9b, 0x1aec10ec, 0x0bea0feb, 0x1fea1beb, 0x24e420e9, 0x06e40bea, 0x03dc06e3
        dd 0x29d824e3, 0x28ca28d9, 0x29d829ce, 0x03cd03dc, 0x04cd05c8, 0x25c527cb, 0x26c527c8, 0x04c604c7, 0x03be03c5
        dd 0x29be26c4, 0x1fc00ac0, 0x1fbf0abf, 0x21bc20bf, 0x0abc09bf, 0x06ba04bc, 0x09bb06bb, 0x0aba07ba, 0x22b922bb
        dd 0x28b228be, 0x29b429bc, 0x27b027b3, 0x0baa22b8, 0x0aae0aac, 0x05ae09ae, 0x29ac26af, 0x29aa27ad, 0x29a729a9
        dd 0x28a728aa, 0x03a304ad, 0x24a429a6, 0x24a329a4, 0x20a823a3, 0x1ea71fa8, 0x1e951ea7, 0x1f941fa7, 0x069e04a2
        dd 0x0397059d, 0x04900396, 0x098f058f, 0x0a8e068e, 0x0a920a90, 0x21860b94, 0x0b922185, 0x20911e94, 0x23952191
        dd 0x22972296, 0x27972397, 0x29952796, 0x298e2994, 0x288f2894, 0x268b298f, 0x278a298e, 0x28822889, 0x29832988
        dd 0x267d2982, 0x277c2980, 0x22832284, 0x0b7c2182, 0x0a7f0a7d, 0x057f097f, 0x2872287a, 0x29722979, 0x22712971
        dd 0x28702370, 0x22742272, 0x0378047e, 0x06730477, 0x13702274, 0x12712274, 0x036e0674, 0x036a036d, 0x28651370
        dd 0x05660468, 0x08660666, 0x0a650665, 0x0b6a0966, 0x18650b6a, 0x0b681864, 0x0b5c1962, 0x0a600a5e, 0x05600960
        dd 0x0359045f, 0x285e2864, 0x295c2964, 0x1353295c, 0x1253285c, 0x214e1253, 0x05550458, 0x044f0654, 0x0349034e
        dd 0x2350224f, 0x22542352, 0x27542354, 0x29522753, 0x284d2852, 0x294e2950, 0x2649294d, 0x2748294c, 0x05460448
        dd 0x0a460646, 0x0a440644, 0x0a490a47, 0x21440b4a, 0x0b492243, 0x28402847, 0x293e2944, 0x223e2243, 0x293e223e
        dd 0x233d283d, 0x18df12df, 0x1ade10de, 0x11dd10dd, 0x1ddc18de, 0x21d71cdd, 0x0bd80fdd, 0x09d70edd, 0x09d009d7
        dd 0x0ad80acd, 0x21d021d7, 0x20cd20ce, 0x0bcd0bce, 0x1fcc0bcc, 0x17a30d9e, 0x0d9d17a2, 0x179717a1, 0x0e9d1796