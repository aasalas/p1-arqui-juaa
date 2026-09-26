; =============================================================
; stats_scalar.asm
; Version ESCALAR de los kernels de computo.
; =============================================================

    global sum_array
    global compute_stats
    global normalize_array

    section .text

; ---------------------------------------------------------------
; float sum_array(const float *arr, int n)
; ---------------------------------------------------------------
sum_array:
    xor     eax, eax           
    xorps   xmm0, xmm0         

.sum_loop:
    cmp     eax, esi
    jge     .sum_done
    movss   xmm1, [rdi + rax*4]
    addss   xmm0, xmm1
    inc     eax
    jmp     .sum_loop

.sum_done:
    ret

; ---------------------------------------------------------------
; void compute_stats(const float *arr, int n,
;                     float *mean, float *var, float *min, float *max)
; rdi = arr, esi = n, rdx = mean*, rcx = var*, r8 = min*, r9 = max*
; ---------------------------------------------------------------
compute_stats:
    ; [DEFENSA] Movemos rcx a r11 para no destruirlo y poder usar rcx como contador 64-bit
    mov     r11, rcx        
    movsxd  rcx, esi        ; Extendemos n a 64 bits

    test    rcx, rcx
    jle     .zero_stats     ; Si n <= 0, poner en 0

    ; Inicializacion
    movss   xmm2, [rdi]     ; xmm2 = min (init con arr[0])
    movss   xmm3, [rdi]     ; xmm3 = max (init con arr[0])
    xorps   xmm0, xmm0      ; xmm0 = sum
    xorps   xmm1, xmm1      ; xmm1 = c (compensador Kahan)
    xor     rax, rax        ; indice = 0

.pasada1_loop:
    cmp     rax, rcx
    jge     .pasada1_done
    
    movss   xmm4, [rdi + rax*4]  ; x = arr[i]
    
    ; Min y Max
    minss   xmm2, xmm4
    maxss   xmm3, xmm4

    ; Kahan Sum: y = x - c
    movss   xmm5, xmm4
    subss   xmm5, xmm1
    
    ; t = sum + y
    movss   xmm6, xmm0
    addss   xmm6, xmm5
    
    ; (t - sum)
    movss   xmm7, xmm6
    subss   xmm7, xmm0
    
    ; c = (t - sum) - y
    movss   xmm1, xmm7
    subss   xmm1, xmm5
    
    ; sum = t
    movss   xmm0, xmm6
    
    inc     rax
    jmp     .pasada1_loop

.pasada1_done:
    ; Media = (sum - c) / n
    movss   xmm4, xmm0
    subss   xmm4, xmm1      ; Aplicamos compensacion final
    cvtsi2ss xmm5, rcx      ; Convertir n a float
    divss   xmm4, xmm5      ; xmm4 = mean
    
    ; Guardar primeros resultados
    movss   [rdx], xmm4     ; mean
    movss   [r8], xmm2      ; min
    movss   [r9], xmm3      ; max

    ; Pasada 2: Varianza (tambien con Kahan)
    xorps   xmm0, xmm0      ; sum_sq = 0
    xorps   xmm1, xmm1      ; c_sq = 0
    xor     rax, rax

.pasada2_loop:
    cmp     rax, rcx
    jge     .pasada2_done
    
    movss   xmm5, [rdi + rax*4]
    subss   xmm5, xmm4      ; d = x - mean
    mulss   xmm5, xmm5      ; d = d^2
    
    ; Kahan Sum_sq
    movss   xmm6, xmm5
    subss   xmm6, xmm1      ; y = d - c
    
    movss   xmm7, xmm0
    addss   xmm7, xmm6      ; t = sum_sq + y
    
    movss   xmm2, xmm7
    subss   xmm2, xmm0      ; (t - sum_sq)
    
    movss   xmm1, xmm2
    subss   xmm1, xmm6      ; c = (t - sum_sq) - y
    
    movss   xmm0, xmm7      ; sum_sq = t
    
    inc     rax
    jmp     .pasada2_loop

.pasada2_done:
    ; Varianza = (sum_sq - c) / n
    subss   xmm0, xmm1
    cvtsi2ss xmm5, rcx      ; <--- AÑADE ESTA LÍNEA AQUÍ
    divss   xmm0, xmm5      ; ahora xmm5 sí tiene 'n' correcto
    movss   [r11], xmm0     ; guardar var
    ret

.zero_stats:
    xorps   xmm0, xmm0
    movss   [rdx], xmm0
    movss   [r11], xmm0
    movss   [r8], xmm0
    movss   [r9], xmm0
    ret

; ---------------------------------------------------------------
; void normalize_array(const float *in, float *out, int n, float mean, float stddev)
; rdi = in, rsi = out, edx = n, xmm0 = mean, xmm1 = stddev
; ---------------------------------------------------------------
normalize_array:
    movsxd  rcx, edx
    test    rcx, rcx
    jle     .norm_done
    
    xor     rax, rax
    xorps   xmm2, xmm2
    ucomiss xmm1, xmm2      ; Comparar stddev con 0.0
    je      .norm_zero_loop

.norm_loop:
    cmp     rax, rcx
    jge     .norm_done
    
    movss   xmm3, [rdi + rax*4]
    subss   xmm3, xmm0      ; (x - mean)
    divss   xmm3, xmm1      ; / stddev  [DEFENSA]: Division real en escalar
    movss   [rsi + rax*4], xmm3
    
    inc     rax
    jmp     .norm_loop

.norm_zero_loop:
    cmp     rax, rcx
    jge     .norm_done
    movss   [rsi + rax*4], xmm2 ; stddev==0 -> llenar de ceros
    inc     rax
    jmp     .norm_zero_loop

.norm_done:
    ret