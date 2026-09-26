; =============================================================
; stats_vector.asm
; Version VECTORIZADA (AVX2) de los kernels de computo.
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
    vxorps  ymm0, ymm0, ymm0       

    mov     ecx, esi
    and     ecx, ~7                
    test    ecx, ecx
    jle     .sum_reduce

.sum_vec_loop:
    cmp     eax, ecx
    jge     .sum_reduce
    vmovups ymm1, [rdi + rax*4]    
    vaddps  ymm0, ymm0, ymm1       
    add     eax, 8
    jmp     .sum_vec_loop

.sum_reduce:
    vextractf128 xmm2, ymm0, 1     
    vaddps  xmm0, xmm0, xmm2       
    vhaddps xmm0, xmm0, xmm0       
    vhaddps xmm0, xmm0, xmm0       

.sum_scalar_tail:
    cmp     eax, esi
    jge     .sum_done
    vmovss  xmm1, [rdi + rax*4]
    vaddss  xmm0, xmm0, xmm1
    inc     eax
    jmp     .sum_scalar_tail

.sum_done:
    vzeroupper                     
    ret

; ---------------------------------------------------------------
; void compute_stats(...)
; rdi = arr, esi = n, rdx = mean*, rcx = var*, r8 = min*, r9 = max*
; ---------------------------------------------------------------
compute_stats:
    mov     r11, rcx        
    movsxd  rcx, esi
    test    rcx, rcx
    jle     zero_stats

    mov     r10, rcx
    and     r10, -8         ; r10 = n & ~7 (bucle vectorial)
    xor     rax, rax

    vxorps  ymm0, ymm0, ymm0       ; ymm0 = sum (Kahan)
    vxorps  ymm1, ymm1, ymm1       ; ymm1 = c (Kahan)
    vbroadcastss ymm2, [rdi]       ; ymm2 = min
    vbroadcastss ymm3, [rdi]       ; ymm3 = max

    test    r10, r10
    jle     vec_tail

global vec_stats_loop
vec_stats_loop:
    cmp     rax, r10
    jge     vec_tail
    
    ; [DEFENSA] vmovaps exige memoria alineada a 32B. Genera #GP si no lo esta.
    vmovaps ymm4, [rdi + rax*4]    
    
    vminps  ymm2, ymm2, ymm4
    vmaxps  ymm3, ymm3, ymm4
    
    ; Kahan Vectorial
    vsubps  ymm5, ymm4, ymm1
    vaddps  ymm6, ymm0, ymm5
global vec_after_vaddps
vec_after_vaddps:
    vsubps  ymm7, ymm6, ymm0
    vsubps  ymm1, ymm7, ymm5
    vmovaps ymm0, ymm6
    
    add     rax, 8
    jmp     vec_stats_loop

global vec_tail
vec_tail:
    ; Reduccion de Suma a escalar
    vextractf128 xmm4, ymm0, 1
    vaddps  xmm0, xmm0, xmm4
    vhaddps xmm0, xmm0, xmm0
    vhaddps xmm0, xmm0, xmm0
    
    vextractf128 xmm4, ymm1, 1
    vaddps  xmm1, xmm1, xmm4
    vhaddps xmm1, xmm1, xmm1
    vhaddps xmm1, xmm1, xmm1

    ; Reduccion de Min/Max a escalar
    vextractf128 xmm4, ymm2, 1
    vextractf128 xmm5, ymm3, 1
    vminps  xmm2, xmm2, xmm4
    vmaxps  xmm3, xmm3, xmm5
    
    vmovshdup xmm4, xmm2
    vmovshdup xmm5, xmm3
    vminps  xmm2, xmm2, xmm4
    vmaxps  xmm3, xmm3, xmm5
    
    vmovhlps xmm4, xmm4, xmm2
    vmovhlps xmm5, xmm5, xmm3
    vminps  xmm2, xmm2, xmm4
    vmaxps  xmm3, xmm3, xmm5

scalar_tail_loop:
    cmp     rax, rcx
    jge     pasada1_done
    
    vmovss  xmm4, [rdi + rax*4]
    vminss  xmm2, xmm2, xmm4
    vmaxss  xmm3, xmm3, xmm4
    
    vsubss  xmm5, xmm4, xmm1
    vaddss  xmm6, xmm0, xmm5
    vsubss  xmm7, xmm6, xmm0
    vsubss  xmm1, xmm7, xmm5
    vmovss  xmm0, xmm0, xmm6
    
    inc     rax
    jmp     scalar_tail_loop

pasada1_done:
    vsubss  xmm0, xmm0, xmm1    ; Aplicar compensacion Kahan final
    cvtsi2ss xmm5, rcx
    vdivss  xmm4, xmm0, xmm5    ; xmm4 = mean
    
    vmovss  [rdx], xmm4
    vmovss  [r8], xmm2
    vmovss  [r9], xmm3

    ; Pasada 2: Varianza Vectorial
    vbroadcastss ymm7, xmm4     ; ymm7 = mean
    vxorps  ymm0, ymm0, ymm0    ; ymm0 = sum_sq
    vxorps  ymm1, ymm1, ymm1    ; ymm1 = c_sq
    xor     rax, rax

    test    r10, r10
    jle     var_tail_reduce

var_vec_loop:
    cmp     rax, r10
    jge     var_tail_reduce
    
    vmovaps ymm4, [rdi + rax*4]
    vsubps  ymm4, ymm4, ymm7
    vmulps  ymm4, ymm4, ymm4
    
    ; Kahan vector 
    vsubps  ymm5, ymm4, ymm1
    vaddps  ymm6, ymm0, ymm5
    vsubps  ymm8, ymm6, ymm0
    vsubps  ymm1, ymm8, ymm5
    vmovaps ymm0, ymm6
    
    add     rax, 8
    jmp     var_vec_loop

var_tail_reduce:
    vextractf128 xmm4, ymm0, 1
    vaddps  xmm0, xmm0, xmm4
    vhaddps xmm0, xmm0, xmm0
    vhaddps xmm0, xmm0, xmm0
    
    vextractf128 xmm4, ymm1, 1
    vaddps  xmm1, xmm1, xmm4
    vhaddps xmm1, xmm1, xmm1
    vhaddps xmm1, xmm1, xmm1

var_tail_loop:
    cmp     rax, rcx
    jge     pasada2_done
    
    vmovss  xmm4, [rdi + rax*4]
    vsubss  xmm4, xmm4, xmm7
    vmulss  xmm4, xmm4, xmm4
    
    vsubss  xmm5, xmm4, xmm1
    vaddss  xmm6, xmm0, xmm5
    vsubss  xmm8, xmm6, xmm0
    vsubss  xmm1, xmm8, xmm5
    vmovss  xmm0, xmm0, xmm6
    
    inc     rax
    jmp     var_tail_loop

pasada2_done:
    vsubss  xmm0, xmm0, xmm1
    cvtsi2ss xmm5, rcx      ; <--- AÑADE ESTA LÍNEA AQUÍ
    vdivss  xmm0, xmm0, xmm5      ; ahora xmm5 sí tiene 'n' correcto
    vmovss  [r11], xmm0
    vzeroupper
    ret

zero_stats:
    vxorps  xmm0, xmm0, xmm0
    vmovss  [rdx], xmm0
    vmovss  [r11], xmm0
    vmovss  [r8], xmm0
    vmovss  [r9], xmm0
    vzeroupper
    ret

; ---------------------------------------------------------------
; void normalize_array(...)
; rdi = in, rsi = out, edx = n, xmm0 = mean, xmm1 = stddev
; ---------------------------------------------------------------
global normalize_array
normalize_array:
    movsxd  rcx, edx
    test    rcx, rcx
    jle     norm_done
    
    vxorps  xmm4, xmm4, xmm4
    vucomiss xmm1, xmm4
    je      norm_zero_vector

    vbroadcastss ymm2, xmm0
    vbroadcastss ymm3, xmm1
    
    mov     r10, rcx
    and     r10, -8
    xor     rax, rax
    test    r10, r10
    jle     norm_tail

global vec_norm_loop
vec_norm_loop:
    cmp     rax, r10
    jge     norm_tail
    
    vmovaps ymm4, [rdi + rax*4]
    vsubps  ymm4, ymm4, ymm2
    vdivps  ymm4, ymm4, ymm3
    vmovaps [rsi + rax*4], ymm4
    
    add     rax, 8
    jmp     vec_norm_loop

norm_tail:
    cmp     rax, rcx
    jge     norm_done
    vmovss  xmm4, [rdi + rax*4]
    vsubss  xmm4, xmm4, xmm0
    vdivss  xmm4, xmm4, xmm1
    vmovss  [rsi + rax*4], xmm4
    inc     rax
    jmp     norm_tail

norm_zero_vector:
    mov     r10, rcx
    and     r10, -8
    xor     rax, rax
    vxorps  ymm4, ymm4, ymm4
norm_zero_loop:
    cmp     rax, r10
    jge     norm_zero_tail
    vmovaps [rsi + rax*4], ymm4
    add     rax, 8
    jmp     norm_zero_loop
norm_zero_tail:
    cmp     rax, rcx
    jge     norm_done
    vmovss  [rsi + rax*4], xmm4
    inc     rax
    jmp     norm_zero_tail

norm_done:
    vzeroupper
    ret