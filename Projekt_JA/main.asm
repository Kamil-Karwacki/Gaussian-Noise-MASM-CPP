; Temat: Dodanie szumu o rozk³adzie Gaussa
; Opis: Algorytm wykorzystuje transformacjê Boxa-Mullera do wygenerowania liczb o rozk³adzie Gaussowskim 
;       po czym dodawane s¹ one do pikseli
; Semestr: 5
; Rok akademicki: 2025/2026
; Autor: Kamil Karwacki
; Wersja: 1.0.0
.data
    ; sta³a 2*PI, u¿ywana do obliczania k¹ta w transformacji Boxa-Mullera (k¹t = 2*PI * u2)
    const_2_pi      REAL8   6.283185307179586
    ; odwrotnoœæ maksymalnej wartoœci 32-bitowej liczby ca³kowitej (1 / 2^32)
    ; s³u¿y do normalizacji wylosowanej liczby ca³kowitej do zakresu [0.0, 1.0]
    const_inv_max   REAL8   2.328306436538696e-10
    ; sta³a -2.0, u¿ywana w czêœci wzoru: R = sqrt(-2 * ln(u1))
    const_minus_2   REAL8   -2.0

    ; maska 128-bitowa dla instrukcji SIMD.
    ; wartoœæ -1 (0xFFFF) oznacza zachowanie danych, 0 oznacza wyzerowanie.
    ; uk³ad: [Pixel2_Alpha, Pixel2_RGB... | Pixel1_Alpha, Pixel1_RGB...]
    ; s³u¿y do zerowania szumu na kanale Alpha, aby nie zmieniaæ przezroczystoœci
    align 16
    alpha_mask_x2   DW      -1, -1, -1, 0, -1, -1, -1, 0

.code

DllMain PROC hInst:QWORD, reason:DWORD, reserved:QWORD
    mov rax, 1
    ret
DllMain ENDP

;   generuje dwie wartoœci szumu Gaussaprzy u¿yciu transformacji Boxa-Mullera
;   wykorzystuje instrukcje koprocesora arytmetycznego do obliczeñ matematycznych
;   oraz generator LCG do liczb pseudolosowych.
;   
;   dane wejœciowe
;   R11D        - seed generatora liczb losowych (zakres: 0..2^32-1)
;   [RSP]       - si³a szumu
;
;   dane wyjœciowe
;   [RSP+8]     - (DWORD) wartoœæ szumu dla pierwszego piksela (liczba ca³kowita ze znakiem)
;   [RSP+12]    - (DWORD) wartoœæ szumu dla drugiego piksela (liczba ca³kowita ze znakiem)
;   R11D        - zaktualizowany stan generatora losowego.
;
;   zmieniane flagi
;   EAX         - u¿ywany do LCG.
;   R11D        - modyfikowany przez imul/add.
;   FPU Stack   - rejestry ST(0) do ST(7) s¹ u¿ywane, ale stos jest czyszczony przed koñcem makra.
;   Flagi CPU   - OF, CF
;
CALC_PAIR_TO_STACK MACRO
    ; u1
    imul r11d, r11d, 1103515245 ;lcg
    add r11d, 12345 ; lcg
    mov eax, r11d ; przepisujemy wartoœæ losow¹ do eax
    shr eax, 1 ; bit shift right
    or eax, 1 ; upewniamy siê aby nie by³o 0
    mov dword ptr [rsp+8], eax  ; zapisujemy wartoœæ na stosie
    fild dword ptr [rsp+8]      ; zamienia liczbê na floata
    fmul const_inv_max          ; ST(0) = u1_float

    ; u2
    imul r11d, r11d, 1103515245
    add r11d, 12345
    mov eax, r11d
    mov dword ptr [rsp+12], eax
    fild dword ptr [rsp+12]     ; ST(0)=u2_int, ST(1)=u1_float
    fmul const_inv_max          ; ST(0)=u2, ST(1)=u1

    fmul const_2_pi             ; ST(0) = 2*pi*u2
    fxch st(1)                  ; zamienia ST(0) i ST(1)
    fldln2                      ; £adowanie ln(2)
    fxch st(1)                  ; ST(0)=u1, ST(1)=ln(2), ST(2)=Angle
    fyl2x                       ; ST(0) = ln(u1), ST(1)=Angle
    fmul const_minus_2
    fsqrt                       ; ST(0) = Radius, ST(1) = Angle
    fmul real8 ptr [rsp]        ; promieñ * si³a
    
    fxch st(1)                  ; ST(0)=Angle, ST(1)=Radius
    fsincos                     ; ST(0)=Cos, ST(1)=Sin, ST(2)=Radius

    fmul st(0), st(2)           ; Cos * Radius
    fistp dword ptr [rsp+12]
    
    fmulp st(1), st(0)          ; Sin * Radius
    fistp dword ptr [rsp+8]
ENDM

public DodajASM
;   g³ówna procedura przetwarzaj¹ca obraz. Iteruje po wszystkich pikselach obrazu
;   i dodaje do nich szum. Wykorzystuje instrukcje wektorowe
;   przetwarza po 2 piksele w jednej iteracji pêtli
;   
;   parametry wejœciowe:
;   RCX         - wskaŸnik na obraz
;   RDX         - szerokoœæ obrazu
;   R8          - wysokoœæ obrazu
;   XMM3        - si³a szumu (double)
;   [RBP+48]    - stride
;
;   parametry wyjœciowe:
;   EAX         - kod powrotu
;   RCX         - zostaje dodany szum
;
;   zmieniane rejestry:
;   RAX, RCX, RDX, R8-R11
;   XMM0-XMM3
;   R12-R15, RBX, RSI, RDI
;   RFLAGS
;
DodajASM proc frame
    push rbp
    .pushreg rbp
    mov rbp, rsp
    .setframe rbp, 0
    
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15
    .endprolog

    mov rbx, rdx                ; szerokoœæ
    mov r10d, dword ptr [rbp + 48] ; stride
    movsxd r10, r10d

    sub rsp, 32                 
    movsd real8 ptr [rsp], xmm3 ; strength

    rdtsc                       ; seed
    mov r11d, eax
    xor r11d, edx
    
    xor r12, r12                ; y=0

LoopY:
    cmp r12, r8 ; je¿eli y > wysokoœæ obrazu to skoñczyliœmy przetwarzaæ obraz
    jge EndLoopY

    mov r13, rcx                ; r13 = wskaŸnik na pocz¹tek wiersza
    xor r14, r14                ; x=0
    
    ; oblicz limit dla pêtli parzystej (width - 1)
    mov rsi, rbx
    dec rsi                     ; limit dla pêtli par = Width - 1

    LoopX_Pairs:
        cmp r14, rsi
        jge CheckLastPixel      ; jeœli zosta³o 0 lub 1 piksel skacz

        CALC_PAIR_TO_STACK      ; generuje dwie liczby

        vmovd xmm0, dword ptr [rsp+8]  ; xmm0 = [0, 0, 0, S1]
        vmovd xmm1, dword ptr [rsp+12] ; xmm1 = [0, 0, 0, S2]
        
        vpbroadcastw xmm0, xmm0        ; xmm0 = [S1, S1, S1, S1, S1, S1, S1, S1]
        vpbroadcastw xmm1, xmm1        ; xmm1 = [S2, S2, S2, S2, S2, S2, S2, S2]

        vpunpcklqdq xmm0, xmm0, xmm1   ; ³¹czenie dwóch rejestrów w jeden
        
        vpand xmm0, xmm0, xmmword ptr [alpha_mask_x2] ; zerowanie szumu dla kana³u alpha

        vpmovzxbw xmm2, qword ptr [r13] ; za³aduj 2 piksele rozpakuj 8 bajtów do 8 s³ów
        
        vpaddw xmm2, xmm2, xmm0         ; dodaj szum do 2 pikseli naraz
        vpackuswb xmm2, xmm2, xmm2      ; clamp (wynik w dolnych 64 bitach)
        
        vmovq qword ptr [r13], xmm2     ; zapisz 8 bajtów z powrotem

        add r13, 8  ; przesuñ wskaŸnik o 8 bajtów
        add r14, 2  ; x+=2
        jmp LoopX_Pairs

    CheckLastPixel:
        cmp r14, rbx
        jge EndLoopX

        CALC_PAIR_TO_STACK      ; generuje dwie liczby
        
        vmovd xmm1, dword ptr [rsp+8]   ; weŸ tylko pierwszy wynik
        vpbroadcastw xmm1, xmm1 ; xmm1 = [S1, S1, S1, S1, S1, S1, S1, S1]

        vpand xmm1, xmm1, xmmword ptr [alpha_mask_x2] ; zerowanie szumu dla kana³u alpha

        vmovd xmm0, dword ptr [r13]     ; za³aduj 1 piksel
        vpmovzxbw xmm0, xmm0            ; rozpakuj piksele do s³ów
        vpaddw xmm0, xmm0, xmm1         ; dodaj szum do pikseli
        vpackuswb xmm0, xmm0, xmm0      ; clamp i zmiana na 8 bit
        vmovd dword ptr [r13], xmm0     ; zapisz
        

    EndLoopX:
    add rcx, r10 ; dodaj stride do rcx
    inc r12      ; zwieksz y
    jmp LoopY

EndLoopY:
    xor eax, eax
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    pop rbp
    ret

DodajASM endp
end