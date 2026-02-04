bits 64
global _start
default rel

; ---------------------------------------------
; ALU Simulator (Digital Logic) - macOS x86_64
; NASM Mach-O 64 + syscalls
;
; Ops: ADD, SUB, AND, OR, XOR, SHL, SHR, CMP
; Prints Result + Flags: C (carry/borrow), Z, S
; Inputs: signed decimal integers (32-bit range)
; ---------------------------------------------

section .text

_start:
.menu:
    lea     rsi, [rel menu_txt]
    mov     edx, menu_txt_len
    call    write_stdout

    call    read_choice           ; AL = choice

    ; -------------------------------
    ; Digital logic blocks (letters)
    ; -------------------------------
    cmp     al, 'F'               ; Full Adder truth table
    je      .op_fa
    cmp     al, 'f'
    je      .op_fa

    cmp     al, 'G'               ; Gate-level full adder breakdown
    je      .op_fa_gate
    cmp     al, 'g'
    je      .op_fa_gate

    cmp     al, 'R'               ; 4-bit ripple carry adder
    je      .op_rca4
    cmp     al, 'r'
    je      .op_rca4

    cmp     al, 'T'               ; Logic gates truth table
    je      .op_tt
    cmp     al, 't'
    je      .op_tt

    cmp     al, 'M'               ; Mini ALU System
    je      .op_mini
    cmp     al, 'm'
    je      .op_mini

    ; Backward-compat keys (not shown)
    cmp     al, '0'
    je      .op_fa
    cmp     al, 'A'
    je      .op_fa_gate
    cmp     al, 'a'
    je      .op_fa_gate
    cmp     al, 'B'
    je      .op_rca4
    cmp     al, 'b'
    je      .op_rca4
    cmp     al, '9'
    je      .op_tt

    cmp     al, '1'               ; ADD
    je      .op_add
    cmp     al, '2'               ; SUB
    je      .op_sub
    cmp     al, '3'               ; AND
    je      .op_and
    cmp     al, '4'               ; OR
    je      .op_or
    cmp     al, '5'               ; XOR
    je      .op_xor
    cmp     al, '6'               ; SHL
    je      .op_shl
    cmp     al, '7'               ; SHR
    je      .op_shr
    cmp     al, '8'               ; CMP
    je      .op_cmp

    cmp     al, 'q'
    je      .exit
    cmp     al, 'Q'
    je      .exit

    lea     rsi, [rel invalid_txt]
    mov     edx, invalid_txt_len
    call    write_stdout
    jmp     .menu
; ---- Full Adder Gate-Level Breakdown ----
.op_fa_gate:
    lea     rsi, [rel title_fa_gate]
    mov     edx, title_fa_gate_len
    call    write_stdout

    ; Read A, B, Cin (0/1)
    lea     rsi, [rel prompt_fa_a]
    mov     edx, prompt_fa_a_len
    call    write_stdout
    call    read_line
    lea     rsi, [rel inbuf]
    call    parse_u32
    and     eax, 1
    mov     ebx, eax              ; A

    lea     rsi, [rel prompt_fa_b]
    mov     edx, prompt_fa_b_len
    call    write_stdout
    call    read_line
    lea     rsi, [rel inbuf]
    call    parse_u32
    and     eax, 1
    mov     r10d, eax             ; B

    lea     rsi, [rel prompt_fa_c]
    mov     edx, prompt_fa_c_len
    call    write_stdout
    call    read_line
    lea     rsi, [rel inbuf]
    call    parse_u32
    and     eax, 1
    mov     r13d, eax             ; Cin

    lea     rsi, [rel header_fa_gate]
    mov     edx, header_fa_gate_len
    call    write_stdout

    ; X = A xor B
    mov     eax, ebx
    xor     eax, r10d
    mov     r14d, eax             ; X

    ; AB = A & B
    mov     eax, ebx
    and     eax, r10d
    mov     r15d, eax             ; AB

    ; CinX = Cin & X
    mov     eax, r13d
    and     eax, r14d
    mov     r12d, eax             ; CinX

    ; Sum = X xor Cin
    mov     eax, r14d
    xor     eax, r13d

    ; Cout = AB | CinX
    mov     eax, r15d
    or      eax, r12d

    ; Print: A B Cin | X AB CinX | Sum Cout
    mov     eax, ebx
    call    print_u32
    call    print_sp

    ; FIX: use stored B to avoid clobbered r10 across syscalls
    mov     eax, dword [rel B4_TMP]
    call    print_u32
    call    print_sp

    mov     eax, r13d
    call    print_u32

    lea     rsi, [rel sep_fa]
    mov     edx, sep_fa_len
    call    write_stdout

    mov     eax, r14d             ; X
    call    print_u32
    call    print_sp

    mov     eax, r15d             ; AB
    call    print_u32
    call    print_sp

    mov     eax, r12d             ; CinX
    call    print_u32

    lea     rsi, [rel sep_gate]
    mov     edx, sep_gate_len
    call    write_stdout

    ; Sum = X xor Cin (recompute right before printing)
    mov     eax, r14d
    xor     eax, r13d
    call    print_u32
    call    print_sp

    ; Cout = AB | CinX (recompute right before printing)
    mov     eax, r15d
    or      eax, r12d
    call    print_u32
    call    print_nl

    lea     rsi, [rel eq_fa]
    mov     edx, eq_fa_len
    call    write_stdout

    call    wait_enter
    jmp     .menu

; ---- Mini ALU System (Registers + Control Word) ----
.op_mini:
    lea     rsi, [rel mini_title]
    mov     edx, mini_title_len
    call    write_stdout

.mini_loop:
    lea     rsi, [rel mini_prompt]
    mov     edx, mini_prompt_len
    call    write_stdout

    call    read_choice
    cmp     al, 'S'
    je      .mini_state
    cmp     al, 's'
    je      .mini_state
    cmp     al, 'L'
    je      .mini_load
    cmp     al, 'l'
    je      .mini_load
    cmp     al, 'E'
    je      .mini_exec
    cmp     al, 'e'
    je      .mini_exec
    cmp     al, 'P'
    je      .mini_prog
    cmp     al, 'p'
    je      .mini_prog
    cmp     al, 'Q'
    je      .mini_exit
    cmp     al, 'q'
    je      .mini_exit

    lea     rsi, [rel mini_invalid]
    mov     edx, mini_invalid_len
    call    write_stdout
    jmp     .mini_loop

.mini_state:
    call    mini_print_state
    jmp     .mini_loop

.mini_load:
    lea     rsi, [rel prompt_reg]
    mov     edx, prompt_reg_len
    call    write_stdout
    call    read_line
    lea     rsi, [rel inbuf]
    call    parse_u32
    and     eax, 3
    mov     byte [rel M_TMP_IDX], al   ; save reg index (0..3)

    lea     rsi, [rel prompt_val]
    mov     edx, prompt_val_len
    call    write_stdout
    call    read_line
    lea     rsi, [rel inbuf]
    call    parse_hex_or_dec
    and     eax, 0xFF

    movzx   ecx, byte [rel M_TMP_IDX]  ; restore reg index safely
    lea     rdx, [rel M_REGS]
    mov     [rdx + rcx], al
    lea     rsi, [rel load_ok_prefix]
    mov     edx, load_ok_prefix_len
    call    write_stdout
    movzx   eax, byte [rel M_TMP_IDX]
    call    print_u32
    lea     rsi, [rel load_ok_mid]
    mov     edx, load_ok_mid_len
    call    write_stdout
    lea     rsi, [rel hex_prefix]
    mov     edx, hex_prefix_len
    call    write_stdout
    ; NOTE: print_u32 / write_stdout clobber registers like RDX/RCX.
    ; Reload base pointer and index before reading the stored register value.
    movzx   ecx, byte [rel M_TMP_IDX]
    lea     rdx, [rel M_REGS]
    movzx   eax, byte [rdx + rcx]
    call    print_hex8
    call    print_nl
    jmp     .mini_loop

.mini_exec:
    lea     rsi, [rel prompt_src1]
    mov     edx, prompt_src1_len
    call    write_stdout
    call    read_line
    lea     rsi, [rel inbuf]
    call    parse_u32
    and     eax, 3
    mov     byte [rel M_SRC1], al

    lea     rsi, [rel prompt_src2]
    mov     edx, prompt_src2_len
    call    write_stdout
    call    read_line
    lea     rsi, [rel inbuf]
    call    parse_u32
    and     eax, 3
    mov     byte [rel M_SRC2], al

    lea     rsi, [rel prompt_op]
    mov     edx, prompt_op_len
    call    write_stdout
    call    read_line
    lea     rsi, [rel inbuf]
    call    parse_u32
    and     eax, 7
    mov     byte [rel M_OP], al

    lea     rsi, [rel prompt_dest]
    mov     edx, prompt_dest_len
    call    write_stdout
    call    read_line
    lea     rsi, [rel inbuf]
    call    parse_u32
    and     eax, 3
    mov     byte [rel M_DEST], al

    lea     rsi, [rel prompt_we]
    mov     edx, prompt_we_len
    call    write_stdout
    call    read_line
    lea     rsi, [rel inbuf]
    call    parse_u32
    and     eax, 1
    mov     byte [rel M_WE], al

    call    mini_exec_core

.mini_print:
    lea     rsi, [rel ctl_lbl]
    mov     edx, ctl_lbl_len
    call    write_stdout

    lea     rsi, [rel src1_lbl]
    mov     edx, src1_lbl_len
    call    write_stdout
    movzx   eax, byte [rel M_SRC1]
    call    print_u32
    call    print_sp

    lea     rsi, [rel src2_lbl]
    mov     edx, src2_lbl_len
    call    write_stdout
    movzx   eax, byte [rel M_SRC2]
    call    print_u32
    call    print_sp

    lea     rsi, [rel op_lbl]
    mov     edx, op_lbl_len
    call    write_stdout
    movzx   eax, byte [rel M_OP]
    call    print_u32
    call    print_sp

    lea     rsi, [rel dest_lbl]
    mov     edx, dest_lbl_len
    call    write_stdout
    movzx   eax, byte [rel M_DEST]
    call    print_u32
    call    print_sp

    lea     rsi, [rel we_lbl]
    mov     edx, we_lbl_len
    call    write_stdout
    movzx   eax, byte [rel M_WE]
    call    print_u32
    call    print_nl

    lea     rsi, [rel ab_out_lbl]
    mov     edx, ab_out_lbl_len
    call    write_stdout

    lea     rsi, [rel a8_lbl]
    mov     edx, a8_lbl_len
    call    write_stdout
    lea     rsi, [rel hex_prefix]
    mov     edx, hex_prefix_len
    call    write_stdout
    movzx   eax, byte [rel M_A]
    call    print_hex8
    call    print_sp
    movzx   eax, byte [rel M_A]
    call    print_bin8
    call    print_sp

    lea     rsi, [rel b8_lbl]
    mov     edx, b8_lbl_len
    call    write_stdout
    lea     rsi, [rel hex_prefix]
    mov     edx, hex_prefix_len
    call    write_stdout
    movzx   eax, byte [rel M_B]
    call    print_hex8
    call    print_sp
    movzx   eax, byte [rel M_B]
    call    print_bin8
    call    print_sp

    lea     rsi, [rel out8_lbl]
    mov     edx, out8_lbl_len
    call    write_stdout
    lea     rsi, [rel hex_prefix]
    mov     edx, hex_prefix_len
    call    write_stdout
    movzx   eax, byte [rel M_OUT]
    call    print_hex8
    call    print_sp
    movzx   eax, byte [rel M_OUT]
    call    print_bin8
    call    print_nl

    call    mini_print_state
    jmp     .mini_loop

.mini_prog:
    lea     rsi, [rel prog_title]
    mov     edx, prog_title_len
    call    write_stdout

.prog_loop:
    lea     rsi, [rel prog_prompt]
    mov     edx, prog_prompt_len
    call    write_stdout

    call    read_choice
    cmp     al, 'I'
    je      .prog_init
    cmp     al, 'i'
    je      .prog_init
    cmp     al, 'N'
    je      .prog_step
    cmp     al, 'n'
    je      .prog_step
    cmp     al, 'R'
    je      .prog_run
    cmp     al, 'r'
    je      .prog_run
    cmp     al, 'D'
    je      .prog_dump
    cmp     al, 'd'
    je      .prog_dump
    cmp     al, 'S'
    je      .prog_dash
    cmp     al, 's'
    je      .prog_dash
    cmp     al, 'Q'
    je      .prog_back
    cmp     al, 'q'
    je      .prog_back

    lea     rsi, [rel prog_invalid]
    mov     edx, prog_invalid_len
    call    write_stdout
    jmp     .prog_loop

.prog_init:
    call    mini_prog_init
    call    mini_prog_dashboard
    jmp     .prog_loop

.prog_step:
    call    mini_prog_step
    call    mini_prog_dashboard
    jmp     .prog_loop

.prog_run:
    call    mini_prog_run
    jmp     .prog_loop

.prog_dump:
    call    mini_mem_dump
    jmp     .prog_loop

.prog_dash:
    call    mini_prog_dashboard
    jmp     .prog_loop

.prog_back:
    jmp     .mini_loop

.mini_exit:
    jmp     .menu


; ---- 4-bit Ripple Carry Adder ----
.op_rca4:
    lea     rsi, [rel title_rca4]
    mov     edx, title_rca4_len
    call    write_stdout

    ; Read A (0..15)
    lea     rsi, [rel prompt_a4]
    mov     edx, prompt_a4_len
    call    write_stdout
    call    read_line
    lea     rsi, [rel inbuf]
    call    parse_u32
    and     eax, 15
    mov     ebx, eax              ; A4

    ; Read B (0..15)
    lea     rsi, [rel prompt_b4]
    mov     edx, prompt_b4_len
    call    write_stdout
    call    read_line
    lea     rsi, [rel inbuf]
    call    parse_u32
    and     eax, 15
    mov     dword [rel B4_TMP], eax ; B4 (store in memory; avoid relying on r10 across syscalls)
    mov     r10d, eax               ; also keep a copy in r10d (optional)

    ; Read Cin (0/1)
    lea     rsi, [rel prompt_fa_c]
    mov     edx, prompt_fa_c_len
    call    write_stdout
    call    read_line
    lea     rsi, [rel inbuf]
    call    parse_u32
    and     eax, 1
    mov     r13d, eax             ; carry (Cin)
    ; record C0
    mov     byte [rel CARRY+0], r13b

    ; Print inputs in binary
    lea     rsi, [rel in_lbl]
    mov     edx, in_lbl_len
    call    write_stdout

    lea     rsi, [rel a_lbl]
    mov     edx, a_lbl_len
    call    write_stdout
    mov     eax, ebx
    call    print_bin4
    call    print_sp

    lea     rsi, [rel b_lbl]
    mov     edx, b_lbl_len
    call    write_stdout
    mov     eax, r10d
    call    print_bin4
    call    print_sp

    lea     rsi, [rel cin_lbl]
    mov     edx, cin_lbl_len
    call    write_stdout
    mov     eax, r13d
    call    print_u32
    call    print_nl
    call    print_nl

    lea     rsi, [rel header_rca4]
    mov     edx, header_rca4_len
    call    write_stdout

    xor     r12d, r12d            ; i = 0
    xor     r14d, r14d            ; sum4 = 0

.rca4_loop:
    cmp     r12d, 4
    jge     .rca4_done

    ; ai = (A>>i)&1
    mov     eax, ebx
    mov     cl,  r12b
    shr     eax, cl
    and     eax, 1
    mov     r8d, eax              ; ai

    ; bi = (B>>i)&1   (B4 is stored in memory)
    mov     eax, dword [rel B4_TMP]
    mov     cl,  r12b
    shr     eax, cl
    and     eax, 1
    mov     r9d, eax              ; bi

    ; X = ai xor bi
    mov     eax, r8d
    xor     eax, r9d
    mov     r11d, eax             ; X

    ; keep old carry-in
    mov     r15d, r13d            ; cin_i

    ; Cout = (ai&bi) | (cin_i & X)
    mov     eax, r8d
    and     eax, r9d              ; ai&bi
    mov     edx, r15d
    and     edx, r11d             ; cin_i & X
    or      eax, edx
    mov     r13d, eax             ; carry = Cout

    ; record C(i+1)
    lea     rdx, [rel CARRY]
    mov     eax, r12d
    inc     eax
    mov     byte [rdx + rax], r13b

    ; sum_i = X xor cin_i, and accumulate sum4 |= (sum_i << i)
    mov     eax, r11d
    xor     eax, r15d             ; sum_i
    mov     cl,  r12b
    shl     eax, cl
    or      r14d, eax

    ; Print stage row: i ai bi cin | x sum cout
    mov     eax, r12d
    call    print_u32
    call    print_sp

    ; FIX: recompute ai/bi for printing (print_u32 clobbers r8/r9)
    mov     eax, ebx
    mov     cl,  r12b
    shr     eax, cl
    and     eax, 1
    call    print_u32
    call    print_sp

    mov     eax, dword [rel B4_TMP]
    mov     cl,  r12b
    shr     eax, cl
    and     eax, 1
    call    print_u32
    call    print_sp

    mov     eax, r15d             ; cin_i
    call    print_u32

    lea     rsi, [rel sep_fa]
    mov     edx, sep_fa_len
    call    write_stdout

    mov     eax, r11d             ; X
    call    print_u32
    call    print_sp

    mov     eax, r11d
    xor     eax, r15d             ; sum_i
    call    print_u32
    call    print_sp

    mov     eax, r13d             ; cout_i
    call    print_u32
    call    print_nl

    inc     r12d
    jmp     .rca4_loop

.rca4_done:
    call    print_nl

    ; Print carry chain after stage table
    lea     rsi, [rel carries_lbl]
    mov     edx, carries_lbl_len
    call    write_stdout

    xor     ecx, ecx              ; idx = 0
.print_carry:
    cmp     ecx, 5
    jge     .carries_done

    ; print "C" idx "=" value
    lea     rsi, [rel cchar]
    mov     edx, 1
    call    write_stdout

    mov     eax, ecx
    call    print_u32

    lea     rsi, [rel eqchar]
    mov     edx, 1
    call    write_stdout

    lea     rdx, [rel CARRY]
    movzx   eax, byte [rdx + rcx]
    call    print_u32

    cmp     ecx, 4
    je      .no_sep_c
    call    print_sp
.no_sep_c:
    inc     ecx
    jmp     .print_carry

.carries_done:
    call    print_nl
    call    print_nl

    lea     rsi, [rel out_lbl]
    mov     edx, out_lbl_len
    call    write_stdout

    lea     rsi, [rel sum_lbl2]
    mov     edx, sum_lbl2_len
    call    write_stdout
    mov     eax, r14d
    call    print_bin4
    call    print_sp

    lea     rsi, [rel cout_lbl2]
    mov     edx, cout_lbl2_len
    call    write_stdout
    mov     eax, r13d
    call    print_u32
    call    print_nl

    lea     rsi, [rel sum_dec_lbl]
    mov     edx, sum_dec_lbl_len
    call    write_stdout
    mov     eax, r14d
    call    print_u32
    call    print_nl

    call    wait_enter
    jmp     .menu
; --------- helpers to read A/B ----------
.read_ab:
    ; read A
    lea     rsi, [rel prompt_a]
    mov     edx, prompt_a_len
    call    write_stdout
    call    read_line
    lea     rsi, [rel inbuf]
    call    parse_s32
    mov     dword [rel A], eax

    ; read B
    lea     rsi, [rel prompt_b]
    mov     edx, prompt_b_len
    call    write_stdout
    call    read_line
    lea     rsi, [rel inbuf]
    call    parse_s32
    mov     dword [rel B], eax
    ret

.read_shift_amt:
    lea     rsi, [rel prompt_shift]
    mov     edx, prompt_shift_len
    call    write_stdout
    call    read_line
    lea     rsi, [rel inbuf]
    call    parse_u32
    ; clamp to 0..31
    and     eax, 31
    mov     byte [rel SH], al
    ret

; --------- Operations ----------
.op_add:
    call    .read_ab
    mov     eax, dword [rel A]
    mov     ebx, dword [rel B]
    add     eax, ebx
    setc    r11b                  ; carry
    call    store_flags_from_eax
    mov     byte [rel FLAG_C], r11b
    mov     dword [rel RES], eax
    lea     rsi, [rel title_add]
    mov     edx, title_add_len
    call    write_stdout
    call    print_result_block
    call    wait_enter
    jmp     .menu

.op_sub:
    call    .read_ab
    mov     eax, dword [rel A]
    mov     ebx, dword [rel B]
    sub     eax, ebx
    setb    r11b                  ; borrow (CF=1 means borrow in unsigned sense)
    call    store_flags_from_eax
    mov     byte [rel FLAG_C], r11b ; show as C=borrow
    mov     dword [rel RES], eax
    lea     rsi, [rel title_sub]
    mov     edx, title_sub_len
    call    write_stdout
    call    print_result_block
    call    wait_enter
    jmp     .menu

.op_and:
    call    .read_ab
    mov     eax, dword [rel A]
    mov     ebx, dword [rel B]
    and     eax, ebx
    xor     r11d, r11d            ; C=0
    call    store_flags_from_eax
    mov     byte [rel FLAG_C], r11b
    mov     dword [rel RES], eax
    lea     rsi, [rel title_and]
    mov     edx, title_and_len
    call    write_stdout
    call    print_result_block
    call    wait_enter
    jmp     .menu

.op_or:
    call    .read_ab
    mov     eax, dword [rel A]
    mov     ebx, dword [rel B]
    or      eax, ebx
    xor     r11d, r11d            ; C=0
    call    store_flags_from_eax
    mov     byte [rel FLAG_C], r11b
    mov     dword [rel RES], eax
    lea     rsi, [rel title_or]
    mov     edx, title_or_len
    call    write_stdout
    call    print_result_block
    call    wait_enter
    jmp     .menu

.op_xor:
    call    .read_ab
    mov     eax, dword [rel A]
    mov     ebx, dword [rel B]
    xor     eax, ebx
    xor     r11d, r11d            ; C=0
    call    store_flags_from_eax
    mov     byte [rel FLAG_C], r11b
    mov     dword [rel RES], eax
    lea     rsi, [rel title_xor]
    mov     edx, title_xor_len
    call    write_stdout
    call    print_result_block
    call    wait_enter
    jmp     .menu

.op_shl:
    call    .read_ab
    call    .read_shift_amt
    mov     eax, dword [rel A]
    mov     cl,  byte [rel SH]
    shl     eax, cl
    setc    r11b
    call    store_flags_from_eax
    mov     byte [rel FLAG_C], r11b
    mov     dword [rel RES], eax
    lea     rsi, [rel title_shl]
    mov     edx, title_shl_len
    call    write_stdout
    call    print_result_block
    call    wait_enter
    jmp     .menu

.op_shr:
    call    .read_ab
    call    .read_shift_amt
    mov     eax, dword [rel A]
    mov     cl,  byte [rel SH]
    shr     eax, cl
    setc    r11b
    call    store_flags_from_eax
    mov     byte [rel FLAG_C], r11b
    mov     dword [rel RES], eax
    lea     rsi, [rel title_shr]
    mov     edx, title_shr_len
    call    write_stdout
    call    print_result_block
    call    wait_enter
    jmp     .menu

.op_cmp:
    call    .read_ab
    mov     eax, dword [rel A]
    mov     ebx, dword [rel B]
    cmp     eax, ebx
    ; For CMP we print relation + flags from comparison
    ; Use result = A - B (conceptually) to derive Z/S and C(borrow)
    mov     ecx, eax
    sub     ecx, ebx
    mov     eax, ecx
    setb    r11b                  ; borrow
    call    store_flags_from_eax
    mov     byte [rel FLAG_C], r11b
    mov     dword [rel RES], eax

    lea     rsi, [rel title_cmp]
    mov     edx, title_cmp_len
    call    write_stdout

    ; relation
    mov     eax, dword [rel A]
    mov     ebx, dword [rel B]
    cmp     eax, ebx
    je      .rel_eq
    jl      .rel_lt
.rel_gt:
    lea     rsi, [rel rel_gt_txt]
    mov     edx, rel_gt_len
    call    write_stdout
    jmp     .rel_done
.rel_eq:
    lea     rsi, [rel rel_eq_txt]
    mov     edx, rel_eq_len
    call    write_stdout
    jmp     .rel_done
.rel_lt:
    lea     rsi, [rel rel_lt_txt]
    mov     edx, rel_lt_len
    call    write_stdout
.rel_done:
    call    print_result_block
    call    wait_enter
    jmp     .menu

.op_fa:
    lea     rsi, [rel title_fa]
    mov     edx, title_fa_len
    call    write_stdout

    ; Read single input A, B, Cin (0/1)
    lea     rsi, [rel prompt_fa_a]
    mov     edx, prompt_fa_a_len
    call    write_stdout
    call    read_line
    lea     rsi, [rel inbuf]
    call    parse_u32
    and     eax, 1
    mov     ebx, eax              ; A

    lea     rsi, [rel prompt_fa_b]
    mov     edx, prompt_fa_b_len
    call    write_stdout
    call    read_line
    lea     rsi, [rel inbuf]
    call    parse_u32
    and     eax, 1
    mov     ecx, eax              ; B

    lea     rsi, [rel prompt_fa_c]
    mov     edx, prompt_fa_c_len
    call    write_stdout
    call    read_line
    lea     rsi, [rel inbuf]
    call    parse_u32
    and     eax, 1
    mov     r13d, eax             ; Cin

    lea     rsi, [rel header_fa]
    mov     edx, header_fa_len
    call    write_stdout

    ; print single input row
    mov     eax, ebx
    call    print_u32
    call    print_sp

    mov     eax, ecx
    call    print_u32
    call    print_sp

    mov     eax, r13d
    call    print_u32

    lea     rsi, [rel sep_fa]
    mov     edx, sep_fa_len
    call    write_stdout

    ; Sum = A xor B xor Cin
    mov     eax, ebx
    xor     eax, ecx
    xor     eax, r13d
    mov     r14d, eax             ; Sum

    ; Cout = (A & B) | (Cin & (A xor B))
    mov     eax, ebx
    and     eax, ecx              ; A&B
    mov     r15d, eax             ; t1

    mov     eax, ebx
    xor     eax, ecx              ; A xor B
    and     eax, r13d             ; Cin & (A xor B)
    or      eax, r15d             ; Cout
    mov     edx, eax              ; save Cout (0/1) before print_u32 clobbers RAX

    ; print Sum Cout
    mov     eax, r14d
    call    print_u32
    call    print_sp
    mov     eax, edx              ; restore Cout
    call    print_u32

    call    print_nl
    call    print_nl

    lea     rsi, [rel header_fa]
    mov     edx, header_fa_len
    call    write_stdout

    ; rows: 000..111
    xor     r12d, r12d            ; row = 0
.fa_row:
    cmp     r12d, 8
    jge     .fa_done

    ; A = (row>>2)&1, B = (row>>1)&1, Cin = row&1
    mov     eax, r12d
    shr     eax, 2
    and     eax, 1
    mov     ebx, eax              ; A

    mov     eax, r12d
    shr     eax, 1
    and     eax, 1
    mov     ecx, eax              ; B

    mov     eax, r12d
    and     eax, 1
    mov     r13d, eax             ; Cin (keep in R13D)

    ; print A B Cin
    mov     eax, ebx
    call    print_u32
    call    print_sp

    mov     eax, ecx
    call    print_u32
    call    print_sp

    mov     eax, r13d
    call    print_u32

    lea     rsi, [rel sep_fa]
    mov     edx, sep_fa_len
    call    write_stdout

    ; Sum = A xor B xor Cin
    mov     eax, ebx
    xor     eax, ecx
    xor     eax, r13d
    mov     r14d, eax             ; Sum (R14D)

    ; Cout = (A & B) | (Cin & (A xor B))
    mov     eax, ebx
    and     eax, ecx              ; A&B
    mov     r15d, eax             ; t1

    mov     eax, ebx
    xor     eax, ecx              ; A xor B
    and     eax, r13d             ; Cin & (A xor B)
    or      eax, r15d             ; Cout
    mov     edx, eax              ; save Cout (0/1)

    ; print Sum Cout
    mov     eax, r14d
    call    print_u32
    call    print_sp
    mov     eax, edx              ; restore Cout
    call    print_u32

    call    print_nl

    inc     r12d
    jmp     .fa_row

.fa_done:
    call    wait_enter
    jmp     .menu

.op_tt:
    lea     rsi, [rel title_tt]
    mov     edx, title_tt_len
    call    write_stdout

    lea     rsi, [rel header_tt]
    mov     edx, header_tt_len
    call    write_stdout

    ; rows: 00,01,10,11
    xor     r12d, r12d            ; row = 0
.tt_row:
    cmp     r12d, 4
    jge     .tt_done

    ; A = (row>>1)&1, B = row&1
    mov     eax, r12d
    shr     eax, 1
    and     eax, 1
    mov     ebx, eax              ; A (keep in EBX)

    mov     eax, r12d
    and     eax, 1
    mov     ecx, eax              ; B (keep in ECX)

    ; print A
    mov     eax, ebx
    call    print_u32
    call    print_sp

    ; print B
    mov     eax, ecx
    call    print_u32

    ; print separator " | "
    lea     rsi, [rel sep_tt]
    mov     edx, sep_tt_len
    call    write_stdout

    ; AND = A & B
    mov     eax, ebx
    and     eax, ecx
    call    print_u32
    call    print_sp

    ; OR = A | B
    mov     eax, ebx
    or      eax, ecx
    call    print_u32
    call    print_sp

    ; XOR = A ^ B
    mov     eax, ebx
    xor     eax, ecx
    call    print_u32
    call    print_sp

    ; NAND = ~(A & B) & 1
    mov     eax, ebx
    and     eax, ecx
    xor     eax, 1
    call    print_u32
    call    print_sp

    ; NOR = ~(A | B) & 1
    mov     eax, ebx
    or      eax, ecx
    xor     eax, 1
    call    print_u32

    call    print_nl

    inc     r12d
    jmp     .tt_row

.tt_done:
    call    wait_enter
    jmp     .menu

.exit:
    mov     rax, 0x2000001
    xor     rdi, rdi
    syscall

; -------------------------
; Flags handling
; -------------------------
; store_flags_from_eax:
; input: EAX result
; sets FLAG_Z (1 if zero), FLAG_S (1 if negative)
store_flags_from_eax:
    ; Z
    test    eax, eax
    setz    byte [rel FLAG_Z]
    ; S (sign bit)
    bt      eax, 31
    setc    byte [rel FLAG_S]
    ret

; -------------------------
; Printing result block
; -------------------------
print_result_block:
    ; Print "Result: "
    lea     rsi, [rel result_lbl]
    mov     edx, result_lbl_len
    call    write_stdout

    mov     eax, dword [rel RES]
    call    print_s32
    call    print_nl

    ; Print "Binary: "
    lea     rsi, [rel bin_lbl]
    mov     edx, bin_lbl_len
    call    write_stdout
    mov     eax, dword [rel RES]
    call    print_bin32
    call    print_nl

    ; Print flags
    lea     rsi, [rel flags_lbl]
    mov     edx, flags_lbl_len
    call    write_stdout

    ; C
    lea     rsi, [rel c_lbl]
    mov     edx, c_lbl_len
    call    write_stdout
    movzx   eax, byte [rel FLAG_C]
    call    print_bit_color
    call    print_sp

    ; Z
    lea     rsi, [rel z_lbl]
    mov     edx, z_lbl_len
    call    write_stdout
    movzx   eax, byte [rel FLAG_Z]
    call    print_bit_color
    call    print_sp

    ; S
    lea     rsi, [rel s_lbl]
    mov     edx, s_lbl_len
    call    write_stdout
    movzx   eax, byte [rel FLAG_S]
    call    print_bit_color
    call    print_nl
    ret

; -------------------------
; IO syscalls
; -------------------------
write_stdout:
    mov     rax, 0x2000004
    mov     rdi, 1
    syscall
    ret

read_stdin:
    mov     rax, 0x2000003
    xor     rdi, rdi
    syscall
    ret

read_choice:
    lea     rsi, [rel inbuf]
    mov     edx, 2
    call    read_stdin
    mov     al, byte [rel inbuf]
    ret

read_line:
    lea     rsi, [rel inbuf]
    mov     edx, 64
    call    read_stdin
    ret

wait_enter:
    lea     rsi, [rel press_enter]
    mov     edx, press_enter_len
    call    write_stdout
    lea     rsi, [rel inbuf]
    mov     edx, 8
    call    read_stdin
    ret

print_nl:
    lea     rsi, [rel nlc]
    mov     edx, 1
    call    write_stdout
    ret

print_sp:
    lea     rsi, [rel spc]
    mov     edx, 1
    call    write_stdout
    ret

; print_bit_color: prints EAX (0/1) as colored bit
; 1 -> green, 0 -> dim gray
; input: EAX (only low 8 bits used)
; clobbers: rsi, rdx
print_bit_color:
    cmp     al, 0
    je      .pbc_zero
    lea     rsi, [rel ansi_green]
    mov     edx, ansi_green_len
    call    write_stdout
    mov     byte [rel onech], '1'
    lea     rsi, [rel onech]
    mov     edx, 1
    call    write_stdout
    lea     rsi, [rel ansi_reset]
    mov     edx, ansi_reset_len
    call    write_stdout
    ret
.pbc_zero:
    lea     rsi, [rel ansi_dim]
    mov     edx, ansi_dim_len
    call    write_stdout
    mov     byte [rel onech], '0'
    lea     rsi, [rel onech]
    mov     edx, 1
    call    write_stdout
    lea     rsi, [rel ansi_reset]
    mov     edx, ansi_reset_len
    call    write_stdout
    ret

; -------------------------
; Parsing (ASCII -> int)
; -------------------------
; parse_u32:
; rsi -> buffer, returns EAX unsigned
parse_u32:
    xor     eax, eax
    xor     ecx, ecx
.skip_ws_u:
    mov     dl, byte [rsi + rcx]
    cmp     dl, ' '
    je      .ws_u
    cmp     dl, 9
    je      .ws_u
    jmp     .digits_u
.ws_u:
    inc     ecx
    jmp     .skip_ws_u
.digits_u:
    mov     dl, byte [rsi + rcx]
    cmp     dl, '0'
    jb      .done_u
    cmp     dl, '9'
    ja      .done_u
    imul    eax, eax, 10
    sub     dl, '0'
    movzx   edx, dl
    add     eax, edx
    inc     ecx
    jmp     .digits_u
.done_u:
    ret

; parse_s32:
; rsi -> buffer, returns EAX signed
parse_s32:
    xor     eax, eax
    xor     ecx, ecx
    xor     r8d, r8d            ; sign flag (1 if negative)
.skip_ws_s:
    mov     dl, byte [rsi + rcx]
    cmp     dl, ' '
    je      .ws_s
    cmp     dl, 9
    je      .ws_s
    jmp     .sign_s
.ws_s:
    inc     ecx
    jmp     .skip_ws_s
.sign_s:
    mov     dl, byte [rsi + rcx]
    cmp     dl, '-'
    jne     .digits_s
    mov     r8d, 1
    inc     ecx
.digits_s:
    mov     dl, byte [rsi + rcx]
    cmp     dl, '0'
    jb      .done_s
    cmp     dl, '9'
    ja      .done_s
    imul    eax, eax, 10
    sub     dl, '0'
    movzx   edx, dl
    add     eax, edx
    inc     ecx
    jmp     .digits_s
.done_s:
    cmp     r8d, 1
    jne     .ret_s
    neg     eax
.ret_s:
    ret

; parse_hex_or_dec:
; rsi -> buffer, returns EAX unsigned
; accepts 0x prefix for hex, otherwise decimal
parse_hex_or_dec:
    xor     eax, eax
    xor     ecx, ecx
.skip_ws_hd:
    mov     dl, byte [rsi + rcx]
    cmp     dl, ' '
    je      .ws_hd
    cmp     dl, 9
    je      .ws_hd
    jmp     .check_hex
.ws_hd:
    inc     ecx
    jmp     .skip_ws_hd
.check_hex:
    mov     dl, byte [rsi + rcx]
    cmp     dl, '0'
    jne     .dec_loop
    mov     dl, byte [rsi + rcx + 1]
    cmp     dl, 'x'
    je      .hex_start
    cmp     dl, 'X'
    je      .hex_start
    jmp     .dec_loop
.hex_start:
    add     ecx, 2
.hex_loop:
    mov     dl, byte [rsi + rcx]
    cmp     dl, '0'
    jb      .done_hd
    cmp     dl, '9'
    jbe     .hex_num
    cmp     dl, 'A'
    jb      .hex_lower
    cmp     dl, 'F'
    jbe     .hex_upper
.hex_lower:
    cmp     dl, 'a'
    jb      .done_hd
    cmp     dl, 'f'
    ja      .done_hd
    sub     dl, 'a'
    add     dl, 10
    jmp     .hex_accum
.hex_upper:
    sub     dl, 'A'
    add     dl, 10
    jmp     .hex_accum
.hex_num:
    sub     dl, '0'
.hex_accum:
    movzx   edx, dl
    imul    eax, eax, 16
    add     eax, edx
    inc     ecx
    jmp     .hex_loop
.dec_loop:
    mov     dl, byte [rsi + rcx]
    cmp     dl, '0'
    jb      .done_hd
    cmp     dl, '9'
    ja      .done_hd
    imul    eax, eax, 10
    sub     dl, '0'
    movzx   edx, dl
    add     eax, edx
    inc     ecx
    jmp     .dec_loop
.done_hd:
    ret

; -------------------------
; Printing numbers
; -------------------------
; print_u32: EAX unsigned
; Clobbers: r8,r9,rax,rdx,r11
print_u32:
    mov     edi, eax
    lea     r8, [rel buf_num]
    mov     r9, r8
    add     r9, 15
    mov     byte [r9], 0

    mov     eax, edi
    cmp     eax, 0
    jne     .conv
    dec     r9
    mov     byte [r9], '0'
    mov     rsi, r9
    mov     edx, 1
    call    write_stdout
    ret

.conv:
    mov     r11d, 10
.loop:
    xor     edx, edx
    div     r11d
    add     dl, '0'
    dec     r9
    mov     byte [r9], dl
    test    eax, eax
    jne     .loop

    mov     rsi, r9
    mov     rdx, r8
    add     rdx, 15
    sub     rdx, r9
    call    write_stdout
    ret

; print_s32: EAX signed
print_s32:
    test    eax, eax
    jns     .pos
    ; print '-'
    lea     rsi, [rel minus]
    mov     edx, 1
    call    write_stdout
    neg     eax
.pos:
    call    print_u32
    ret

; print_bin32: EAX as 32-bit binary, grouped 4 bits
; Clobbers: r8,rcx,rdx
print_bin32:
    mov     r8d, eax
    mov     ecx, 31
.pb_loop:
    ; bit -> dl = '0'/'1'
    bt      r8d, ecx
    setc    dl
    add     dl, '0'
    mov     byte [rel onech], dl
    lea     rsi, [rel onech]
    mov     edx, 1
    call    write_stdout

    ; space every 4 bits except at end
    mov     eax, ecx
    and     eax, 3
    cmp     eax, 0
    jne     .no_sp
    cmp     ecx, 0
    je      .no_sp
    call    print_sp
.no_sp:
    dec     ecx
    jns     .pb_loop
    ret

; print_bin4: EAX lower 4 bits as binary (xxxx)
; Clobbers: r8,rcx,rdx
print_bin4:
    mov     r8d, eax
    and     r8d, 15
    mov     ecx, 3
.pb4_loop:
    bt      r8d, ecx
    setc    dl
    add     dl, '0'
    mov     byte [rel onech], dl
    lea     rsi, [rel onech]
    mov     edx, 1
    call    write_stdout
    dec     ecx
    jns     .pb4_loop
    ret

; print_bin8: EAX lower 8 bits as binary (xxxx xxxx)
; Clobbers: r8,r9,rcx,rdx
print_bin8:
    mov     r9d, eax
    mov     r8d, r9d
    shr     r8d, 4
    mov     eax, r8d
    call    print_bin4
    call    print_sp
    mov     eax, r9d
    call    print_bin4
    ret

; print_hex8: EAX lower 8 bits as hex (two digits)
; Clobbers: r8,r9,rax,rdx
print_hex8:
    mov     r8d, eax
    and     r8d, 0xFF

    mov     r9d, r8d
    shr     r9d, 4
    lea     rsi, [rel hex_digits]
    movzx   eax, byte [rsi + r9]
    mov     byte [rel onech], al
    lea     rsi, [rel onech]
    mov     edx, 1
    call    write_stdout

    mov     r9d, r8d
    and     r9d, 0x0F
    lea     rsi, [rel hex_digits]
    movzx   eax, byte [rsi + r9]
    mov     byte [rel onech], al
    lea     rsi, [rel onech]
    mov     edx, 1
    call    write_stdout
    ret

; mini_print_state: prints Mini ALU registers and flags
mini_print_state:
    lea     rsi, [rel flags_m_lbl]
    mov     edx, flags_m_lbl_len
    call    write_stdout

    lea     rsi, [rel m_c_lbl]
    mov     edx, m_c_lbl_len
    call    write_stdout
    movzx   eax, byte [rel M_FLAG_C]
    call    print_bit_color
    call    print_sp

    lea     rsi, [rel m_z_lbl]
    mov     edx, m_z_lbl_len
    call    write_stdout
    movzx   eax, byte [rel M_FLAG_Z]
    call    print_bit_color
    call    print_sp

    lea     rsi, [rel m_s_lbl]
    mov     edx, m_s_lbl_len
    call    write_stdout
    movzx   eax, byte [rel M_FLAG_S]
    call    print_bit_color
    call    print_sp

    lea     rsi, [rel m_v_lbl]
    mov     edx, m_v_lbl_len
    call    write_stdout
    movzx   eax, byte [rel M_FLAG_V]
    call    print_bit_color
    call    print_nl

    lea     rsi, [rel regs_lbl]
    mov     edx, regs_lbl_len
    call    write_stdout
    call    print_nl

    lea     rsi, [rel r0_lbl]
    mov     edx, r0_lbl_len
    call    write_stdout
    lea     rsi, [rel hex_prefix]
    mov     edx, hex_prefix_len
    call    write_stdout
    movzx   eax, byte [rel M_REGS + 0]
    call    print_hex8
    call    print_sp
    movzx   eax, byte [rel M_REGS + 0]
    call    print_bin8
    call    print_nl

    lea     rsi, [rel r1_lbl]
    mov     edx, r1_lbl_len
    call    write_stdout
    lea     rsi, [rel hex_prefix]
    mov     edx, hex_prefix_len
    call    write_stdout
    movzx   eax, byte [rel M_REGS + 1]
    call    print_hex8
    call    print_sp
    movzx   eax, byte [rel M_REGS + 1]
    call    print_bin8
    call    print_nl

    lea     rsi, [rel r2_lbl]
    mov     edx, r2_lbl_len
    call    write_stdout
    lea     rsi, [rel hex_prefix]
    mov     edx, hex_prefix_len
    call    write_stdout
    movzx   eax, byte [rel M_REGS + 2]
    call    print_hex8
    call    print_sp
    movzx   eax, byte [rel M_REGS + 2]
    call    print_bin8
    call    print_nl

    lea     rsi, [rel r3_lbl]
    mov     edx, r3_lbl_len
    call    write_stdout
    lea     rsi, [rel hex_prefix]
    mov     edx, hex_prefix_len
    call    write_stdout
    movzx   eax, byte [rel M_REGS + 3]
    call    print_hex8
    call    print_sp
    movzx   eax, byte [rel M_REGS + 3]
    call    print_bin8
    call    print_nl
    call    print_nl
    ret

; mini_exec_core:
; Uses M_SRC1/M_SRC2/M_OP/M_DEST/M_WE
; Loads A/B from M_REGS, executes, sets flags, writes back if WE=1
mini_exec_core:
    ; Load A, B
    lea     rdx, [rel M_REGS]
    movzx   ecx, byte [rel M_SRC1]
    movzx   eax, byte [rdx + rcx]
    mov     byte [rel M_A], al
    movzx   ecx, byte [rel M_SRC2]
    movzx   eax, byte [rdx + rcx]
    mov     byte [rel M_B], al

    ; Defaults
    mov     byte [rel M_FLAG_C], 0
    mov     byte [rel M_FLAG_V], 0

    movzx   ecx, byte [rel M_OP]
    cmp     ecx, 0
    je      .mec_add
    cmp     ecx, 1
    je      .mec_sub
    cmp     ecx, 2
    je      .mec_and
    cmp     ecx, 3
    je      .mec_or
    cmp     ecx, 4
    je      .mec_xor
    cmp     ecx, 5
    je      .mec_not
    cmp     ecx, 6
    je      .mec_shl
    cmp     ecx, 7
    je      .mec_shr
    jmp     .mec_flags

.mec_add:
    movzx   eax, byte [rel M_A]
    movzx   ebx, byte [rel M_B]
    add     eax, ebx
    ; FIX: use r11b for flag writes (avoid dl clobber)
    setc    r11b
    mov     byte [rel M_FLAG_C], r11b
    mov     byte [rel M_OUT], al
    movzx   ecx, byte [rel M_A]
    movzx   edx, byte [rel M_B]
    movzx   edi, byte [rel M_OUT]
    mov     eax, ecx
    xor     eax, edx
    not     eax
    mov     ebx, ecx
    xor     ebx, edi
    and     eax, ebx
    and     eax, 0x80
    ; FIX: use r11b for flag writes (avoid dl clobber)
    setnz   r11b
    mov     byte [rel M_FLAG_V], r11b
    jmp     .mec_flags

.mec_sub:
    movzx   eax, byte [rel M_A]
    movzx   ebx, byte [rel M_B]
    sub     eax, ebx
    ; FIX: use r11b for flag writes (avoid dl clobber)
    setb    r11b
    mov     byte [rel M_FLAG_C], r11b
    mov     byte [rel M_OUT], al
    movzx   ecx, byte [rel M_A]
    movzx   edx, byte [rel M_B]
    movzx   edi, byte [rel M_OUT]
    mov     eax, ecx
    xor     eax, edx
    mov     ebx, ecx
    xor     ebx, edi
    and     eax, ebx
    and     eax, 0x80
    ; FIX: use r11b for flag writes (avoid dl clobber)
    setnz   r11b
    mov     byte [rel M_FLAG_V], r11b
    jmp     .mec_flags

.mec_and:
    movzx   eax, byte [rel M_A]
    movzx   ebx, byte [rel M_B]
    and     eax, ebx
    mov     byte [rel M_OUT], al
    jmp     .mec_flags

.mec_or:
    movzx   eax, byte [rel M_A]
    movzx   ebx, byte [rel M_B]
    or      eax, ebx
    mov     byte [rel M_OUT], al
    jmp     .mec_flags

.mec_xor:
    movzx   eax, byte [rel M_A]
    movzx   ebx, byte [rel M_B]
    xor     eax, ebx
    mov     byte [rel M_OUT], al
    jmp     .mec_flags

.mec_not:
    movzx   eax, byte [rel M_A]
    xor     eax, 0xFF
    mov     byte [rel M_OUT], al
    jmp     .mec_flags

.mec_shl:
    mov     al, byte [rel M_A]
    shl     al, 1
    ; FIX: use r11b for flag writes (avoid dl clobber)
    setc    r11b
    mov     byte [rel M_FLAG_C], r11b
    mov     byte [rel M_OUT], al
    jmp     .mec_flags

.mec_shr:
    mov     al, byte [rel M_A]
    shr     al, 1
    ; FIX: use r11b for flag writes (avoid dl clobber)
    setc    r11b
    mov     byte [rel M_FLAG_C], r11b
    mov     byte [rel M_OUT], al
    jmp     .mec_flags

.mec_flags:
    movzx   eax, byte [rel M_OUT]
    test    eax, eax
    setz    dl
    mov     byte [rel M_FLAG_Z], dl
    bt      eax, 7
    setc    dl
    mov     byte [rel M_FLAG_S], dl

    movzx   eax, byte [rel M_WE]
    test    eax, eax
    jz      .mec_done
    movzx   ecx, byte [rel M_DEST]
    lea     rdx, [rel M_REGS]
    mov     al, byte [rel M_OUT]
    mov     [rdx + rcx], al
.mec_done:
    ret

; mini_prog_init: reset CPU state and load demo program
mini_prog_init:
    ; clear registers
    lea     rdx, [rel M_REGS]
    xor     eax, eax
    mov     ecx, 4
.mpi_reg_loop:
    mov     byte [rdx], al
    inc     rdx
    loop    .mpi_reg_loop

    mov     byte [rel M_FLAG_C], 0
    mov     byte [rel M_FLAG_Z], 0
    mov     byte [rel M_FLAG_S], 0
    mov     byte [rel M_FLAG_V], 0

    mov     byte [rel CPU_PC], 0
    mov     byte [rel CPU_HALT], 0
    mov     byte [rel CPU_IR_OP], 0
    mov     byte [rel CPU_IR_B1], 0
    mov     byte [rel CPU_IR_B2], 0

    ; clear MEM[0..15]
    lea     rdx, [rel CPU_MEM]
    mov     ecx, 16
.mpi_mem_loop:
    mov     byte [rdx], al
    inc     rdx
    loop    .mpi_mem_loop

    ; clear PROG and load demo program
    lea     rdi, [rel CPU_PROG]
    mov     ecx, 96
.mpi_prog_clear:
    mov     byte [rdi], al
    inc     rdi
    loop    .mpi_prog_clear

    lea     rsi, [rel demo_prog]
    lea     rdi, [rel CPU_PROG]
    mov     ecx, demo_prog_len
    rep     movsb
    ; FIX: track program length for bounds checking
    mov     byte [rel CPU_PROG_LEN], demo_prog_len
    ret

; mini_prog_step: execute one instruction with micro-ops trace
mini_prog_step:
    movzx   eax, byte [rel CPU_HALT]
    test    eax, eax
    jz      .mps_go
    lea     rsi, [rel uop_halt]
    mov     edx, uop_halt_len
    call    write_stdout
    ret
.mps_go:
    ; FIX: bounds check: PC+2 < CPU_PROG_LEN
    movzx   eax, byte [rel CPU_PC]
    add     eax, 2
    movzx   ecx, byte [rel CPU_PROG_LEN]
    cmp     eax, ecx
    jb      .mps_fetch
    mov     byte [rel CPU_HALT], 1
    ; FIX: halt and report out-of-bounds fetch
    lea     rsi, [rel uop_oob]
    mov     edx, uop_oob_len
    call    write_stdout
    ret
.mps_fetch:
    ; FETCH
    mov     al, byte [rel CPU_PC]
    mov     byte [rel CPU_PC_TMP], al
    movzx   ecx, al
    lea     rdx, [rel CPU_PROG]
    mov     al, byte [rdx + rcx]
    mov     byte [rel CPU_IR_OP], al
    mov     al, byte [rdx + rcx + 1]
    mov     byte [rel CPU_IR_B1], al
    mov     al, byte [rdx + rcx + 2]
    mov     byte [rel CPU_IR_B2], al

    mov     al, byte [rel CPU_PC]
    add     al, 3
    mov     byte [rel CPU_PC], al

    lea     rsi, [rel uop_fetch]
    mov     edx, uop_fetch_len
    call    write_stdout
    lea     rsi, [rel trace_pc]
    mov     edx, trace_pc_len
    call    write_stdout
    movzx   eax, byte [rel CPU_PC_TMP]
    call    print_u32
    call    print_sp
    lea     rsi, [rel trace_ir]
    mov     edx, trace_ir_len
    call    write_stdout
    lea     rsi, [rel hex_prefix]
    mov     edx, hex_prefix_len
    call    write_stdout
    movzx   eax, byte [rel CPU_IR_OP]
    call    print_hex8
    call    print_sp
    lea     rsi, [rel hex_prefix]
    mov     edx, hex_prefix_len
    call    write_stdout
    movzx   eax, byte [rel CPU_IR_B1]
    call    print_hex8
    call    print_sp
    lea     rsi, [rel hex_prefix]
    mov     edx, hex_prefix_len
    call    write_stdout
    movzx   eax, byte [rel CPU_IR_B2]
    call    print_hex8
    call    print_nl

    lea     rsi, [rel uop_decode]
    mov     edx, uop_decode_len
    call    write_stdout
    lea     rsi, [rel uop_exec]
    mov     edx, uop_exec_len
    call    write_stdout

    movzx   eax, byte [rel CPU_IR_OP]
    cmp     eax, 0x01
    je      .mps_load
    cmp     eax, 0x02
    je      .mps_ld
    cmp     eax, 0x03
    je      .mps_st
    cmp     eax, 0x10
    je      .mps_add
    cmp     eax, 0x11
    je      .mps_sub
    cmp     eax, 0x12
    je      .mps_and
    cmp     eax, 0x13
    je      .mps_or
    cmp     eax, 0x14
    je      .mps_xor
    cmp     eax, 0xFF
    je      .mps_hlt
    ret

.mps_load:
    lea     rsi, [rel exec_load]
    mov     edx, exec_load_len
    call    write_stdout
    movzx   ecx, byte [rel CPU_IR_B1]
    and     ecx, 3
    movzx   eax, byte [rel CPU_IR_B2]
    lea     rdx, [rel M_REGS]
    mov     [rdx + rcx], al
    mov     eax, ecx
    call    print_u32
    lea     rsi, [rel exec_arrow]
    mov     edx, exec_arrow_len
    call    write_stdout
    lea     rsi, [rel hex_prefix]
    mov     edx, hex_prefix_len
    call    write_stdout
    movzx   eax, byte [rel CPU_IR_B2]
    call    print_hex8
    call    print_nl
    ret

.mps_ld:
    lea     rsi, [rel exec_ld]
    mov     edx, exec_ld_len
    call    write_stdout
    movzx   ecx, byte [rel CPU_IR_B1]
    and     ecx, 3
    movzx   eax, byte [rel CPU_IR_B2]
    and     eax, 0x0F
    lea     rdx, [rel CPU_MEM]
    mov     bl, byte [rdx + rax]
    lea     rdx, [rel M_REGS]
    mov     [rdx + rcx], bl
    mov     eax, ecx
    call    print_u32
    lea     rsi, [rel exec_mem_at]
    mov     edx, exec_mem_at_len
    call    write_stdout
    lea     rsi, [rel hex_prefix]
    mov     edx, hex_prefix_len
    call    write_stdout
    movzx   eax, byte [rel CPU_IR_B2]
    and     eax, 0x0F
    call    print_hex8
    lea     rsi, [rel exec_mem_end]
    mov     edx, exec_mem_end_len
    call    write_stdout
    call    print_nl
    ret

.mps_st:
    lea     rsi, [rel exec_st]
    mov     edx, exec_st_len
    call    write_stdout
    movzx   ecx, byte [rel CPU_IR_B1]
    and     ecx, 3
    lea     rdx, [rel M_REGS]
    mov     bl, byte [rdx + rcx]
    movzx   eax, byte [rel CPU_IR_B2]
    and     eax, 0x0F
    lea     rdx, [rel CPU_MEM]
    mov     [rdx + rax], bl
    lea     rsi, [rel exec_mem_at]
    mov     edx, exec_mem_at_len
    call    write_stdout
    lea     rsi, [rel hex_prefix]
    mov     edx, hex_prefix_len
    call    write_stdout
    movzx   eax, byte [rel CPU_IR_B2]
    and     eax, 0x0F
    call    print_hex8
    lea     rsi, [rel exec_from_r]
    mov     edx, exec_from_r_len
    call    write_stdout
    movzx   eax, byte [rel CPU_IR_B1]
    and     eax, 3
    call    print_u32
    call    print_nl
    ret

.mps_add:
    mov     byte [rel M_OP], 0
    lea     rsi, [rel exec_alu_add]
    mov     edx, exec_alu_add_len
    call    write_stdout
    jmp     .mps_alu
.mps_sub:
    mov     byte [rel M_OP], 1
    lea     rsi, [rel exec_alu_sub]
    mov     edx, exec_alu_sub_len
    call    write_stdout
    jmp     .mps_alu
.mps_and:
    mov     byte [rel M_OP], 2
    lea     rsi, [rel exec_alu_and]
    mov     edx, exec_alu_and_len
    call    write_stdout
    jmp     .mps_alu
.mps_or:
    mov     byte [rel M_OP], 3
    lea     rsi, [rel exec_alu_or]
    mov     edx, exec_alu_or_len
    call    write_stdout
    jmp     .mps_alu
.mps_xor:
    mov     byte [rel M_OP], 4
    lea     rsi, [rel exec_alu_xor]
    mov     edx, exec_alu_xor_len
    call    write_stdout
    jmp     .mps_alu

.mps_alu:
    movzx   eax, byte [rel CPU_IR_B1]
    and     eax, 3
    mov     byte [rel M_DEST], al
    movzx   eax, byte [rel CPU_IR_B2]
    mov     ecx, eax
    shr     ecx, 4
    and     ecx, 3
    and     eax, 3
    mov     byte [rel M_SRC1], cl
    mov     byte [rel M_SRC2], al
    mov     byte [rel M_WE], 1
    call    mini_exec_core

    lea     rsi, [rel exec_alu_tail]
    mov     edx, exec_alu_tail_len
    call    write_stdout
    movzx   eax, byte [rel M_DEST]
    call    print_u32
    lea     rsi, [rel exec_rs1]
    mov     edx, exec_rs1_len
    call    write_stdout
    movzx   eax, byte [rel M_SRC1]
    call    print_u32
    lea     rsi, [rel exec_rs2]
    mov     edx, exec_rs2_len
    call    write_stdout
    movzx   eax, byte [rel M_SRC2]
    call    print_u32
    call    print_nl
    ret

.mps_hlt:
    lea     rsi, [rel exec_hlt]
    mov     edx, exec_hlt_len
    call    write_stdout
    mov     byte [rel CPU_HALT], 1
    ret

; mini_prog_run: run until HLT (safety limit)
mini_prog_run:
    mov     ecx, 64
.mpr_loop:
    cmp     ecx, 0
    je      .mpr_done
    movzx   eax, byte [rel CPU_HALT]
    test    eax, eax
    jnz     .mpr_done
    call    mini_prog_step
    call    mini_prog_dashboard
    dec     ecx
    jmp     .mpr_loop
.mpr_done:
    ret

; mini_prog_dashboard: clear + show CPU state and memory
mini_prog_dashboard:
    lea     rsi, [rel ansi_clear]
    mov     edx, ansi_clear_len
    call    write_stdout
    lea     rsi, [rel ansi_bold]
    mov     edx, ansi_bold_len
    call    write_stdout
    lea     rsi, [rel ansi_cyan]
    mov     edx, ansi_cyan_len
    call    write_stdout
    lea     rsi, [rel dash_title]
    mov     edx, dash_title_len
    call    write_stdout
    lea     rsi, [rel ansi_reset]
    mov     edx, ansi_reset_len
    call    write_stdout
    call    print_nl

    lea     rsi, [rel dash_pc]
    mov     edx, dash_pc_len
    call    write_stdout
    lea     rsi, [rel hex_prefix]
    mov     edx, hex_prefix_len
    call    write_stdout
    movzx   eax, byte [rel CPU_PC]
    call    print_hex8
    call    print_sp

    lea     rsi, [rel dash_ir]
    mov     edx, dash_ir_len
    call    write_stdout
    lea     rsi, [rel hex_prefix]
    mov     edx, hex_prefix_len
    call    write_stdout
    movzx   eax, byte [rel CPU_IR_OP]
    call    print_hex8
    call    print_sp
    lea     rsi, [rel hex_prefix]
    mov     edx, hex_prefix_len
    call    write_stdout
    movzx   eax, byte [rel CPU_IR_B1]
    call    print_hex8
    call    print_sp
    lea     rsi, [rel hex_prefix]
    mov     edx, hex_prefix_len
    call    write_stdout
    movzx   eax, byte [rel CPU_IR_B2]
    call    print_hex8
    call    print_sp

    lea     rsi, [rel dash_halt]
    mov     edx, dash_halt_len
    call    write_stdout
    movzx   eax, byte [rel CPU_HALT]
    call    print_u32
    call    print_nl

    call    mini_print_state
    call    mini_mem_dump
    ret

; mini_mem_dump: dump MEM[0..15]
mini_mem_dump:
    lea     rsi, [rel mem_hdr]
    mov     edx, mem_hdr_len
    call    write_stdout
    xor     ecx, ecx
.mmd_loop:
    cmp     ecx, 16
    jge     .mmd_done
    mov     eax, ecx
    call    print_hex8
    lea     rsi, [rel mem_colon]
    mov     edx, mem_colon_len
    call    write_stdout
    lea     rdx, [rel CPU_MEM]
    movzx   eax, byte [rdx + rcx]
    call    print_hex8
    call    print_sp
    inc     ecx
    cmp     ecx, 8
    je      .mmd_nl
    jmp     .mmd_loop
.mmd_nl:
    call    print_nl
    jmp     .mmd_loop
.mmd_done:
    call    print_nl
    ret


section .data
; --- ANSI UI helpers (terminal colors) ---
ansi_clear      db 0x1b,"[2J",0x1b,"[H"
ansi_clear_len  equ $-ansi_clear
ansi_reset      db 0x1b,"[0m"
ansi_reset_len  equ $-ansi_reset
ansi_bold       db 0x1b,"[1m"
ansi_bold_len   equ $-ansi_bold
ansi_dim        db 0x1b,"[2m"
ansi_dim_len    equ $-ansi_dim
ansi_red        db 0x1b,"[31m"
ansi_red_len    equ $-ansi_red
ansi_green      db 0x1b,"[32m"
ansi_green_len  equ $-ansi_green
ansi_yellow     db 0x1b,"[33m"
ansi_yellow_len equ $-ansi_yellow
ansi_magenta    db 0x1b,"[35m"
ansi_magenta_len equ $-ansi_magenta
ansi_cyan       db 0x1b,"[36m"
ansi_cyan_len   equ $-ansi_cyan

menu_txt:
    db 0x1b,"[2J",0x1b,"[H"
    db 0x1b,"[1;36m"
    db "==============================",10
    db "        ALU / LOGIC SIM       ",10
    db "==============================",10
    db 0x1b,"[0m",10

    db 0x1b,"[33m","[Digital Logic]",0x1b,"[0m",10
    db "F) Full Adder truth table (A,B,Cin -> Sum,Cout)",10
    db "G) Full Adder gate-level signals (X, AB, CinX)",10
    db "R) 4-bit Ripple Carry Adder (A[3:0] + B[3:0] + Cin)",10
    db "T) Logic-gates truth table (AND/OR/XOR/NAND/NOR)",10
    db "M) Mini ALU System (Registers + Control Word)",10
    db 10

    db 0x1b,"[35m","[ALU Operations]",0x1b,"[0m",10
    db "1) ADD   (A + B)",10
    db "2) SUB   (A - B)",10
    db "3) AND   (A & B)",10
    db "4) OR    (A | B)",10
    db "5) XOR   (A ^ B)",10
    db "6) SHL   (A << k)",10
    db "7) SHR   (A >> k)",10
    db "8) CMP   (Compare A vs B)",10
    db 10

    db 0x1b,"[31m","Q) Quit",0x1b,"[0m",10
    db 10
    db 0x1b,"[1m","Enter choice: ",0x1b,"[0m"
menu_txt_len equ $-menu_txt

invalid_txt db "Invalid choice. Try again.",10
invalid_txt_len equ $-invalid_txt

prompt_a db "Enter A (decimal): "
prompt_a_len equ $-prompt_a
prompt_b db "Enter B (decimal): "
prompt_b_len equ $-prompt_b
prompt_shift db "Enter shift k (0..31): "
prompt_shift_len equ $-prompt_shift

prompt_fa_a db "Enter A (0/1): "
prompt_fa_a_len equ $-prompt_fa_a
prompt_fa_b db "Enter B (0/1): "
prompt_fa_b_len equ $-prompt_fa_b
prompt_fa_c db "Enter Cin (0/1): "
prompt_fa_c_len equ $-prompt_fa_c

mini_title db 10,"--- Mini ALU System (Registers + Control Word) ---",10
mini_title_len equ $-mini_title
mini_prompt db "MiniALU: S=State L=Load E=Exec P=Program Q=Back",10,"Cmd: "
mini_prompt_len equ $-mini_prompt
mini_invalid db "Invalid command. Use S, L, E, P, or Q.",10
mini_invalid_len equ $-mini_invalid

load_ok_prefix db "Loaded R"
load_ok_prefix_len equ $-load_ok_prefix
load_ok_mid db " = "
load_ok_mid_len equ $-load_ok_mid

prog_title db 10,"--- Program Mode (Mini CPU) ---",10
prog_title_len equ $-prog_title
prog_prompt db "Prog: I=Init N=Step R=Run D=DumpMem S=Dashboard Q=Back",10,"Cmd: "
prog_prompt_len equ $-prog_prompt
prog_invalid db "Invalid command. Use I, N, R, D, S, or Q.",10
prog_invalid_len equ $-prog_invalid

uop_fetch db "[uOP] FETCH",10
uop_fetch_len equ $-uop_fetch
uop_decode db "[uOP] DECODE",10
uop_decode_len equ $-uop_decode
uop_exec db "[uOP] EXEC/WRITE",10
uop_exec_len equ $-uop_exec
uop_halt db "[uOP] HALT (already)",10
uop_halt_len equ $-uop_halt
; FIX: OOB fetch message for bounds check
uop_oob db "[uOP] OOB: PC out of program bounds",10
uop_oob_len equ $-uop_oob

trace_pc db "PC="
trace_pc_len equ $-trace_pc
trace_ir db "IR="
trace_ir_len equ $-trace_ir

exec_load db "  LOAD R"
exec_load_len equ $-exec_load
exec_ld db "  LD R"
exec_ld_len equ $-exec_ld
exec_st db "  ST "
exec_st_len equ $-exec_st
exec_arrow db " <- "
exec_arrow_len equ $-exec_arrow
exec_mem_at db " <- MEM["
exec_mem_at_len equ $-exec_mem_at
exec_mem_end db "]"
exec_mem_end_len equ $-exec_mem_end
exec_from_r db "] <- R"
exec_from_r_len equ $-exec_from_r

exec_alu_add db "  ADD"
exec_alu_add_len equ $-exec_alu_add
exec_alu_sub db "  SUB"
exec_alu_sub_len equ $-exec_alu_sub
exec_alu_and db "  AND"
exec_alu_and_len equ $-exec_alu_and
exec_alu_or db "  OR"
exec_alu_or_len equ $-exec_alu_or
exec_alu_xor db "  XOR"
exec_alu_xor_len equ $-exec_alu_xor
exec_alu_tail db " R"
exec_alu_tail_len equ $-exec_alu_tail
exec_rs1 db " <- R"
exec_rs1_len equ $-exec_rs1
exec_rs2 db " , R"
exec_rs2_len equ $-exec_rs2

exec_hlt db "  HLT",10
exec_hlt_len equ $-exec_hlt

dash_title db "=== Mini CPU Mode (PC/IR, STEP/RUN, MEM) ==="
dash_title_len equ $-dash_title
dash_pc db "PC="
dash_pc_len equ $-dash_pc
dash_ir db " IR="
dash_ir_len equ $-dash_ir
dash_halt db " HALT="
dash_halt_len equ $-dash_halt

mem_hdr db 10,0x1b,"[33m","MEM: ",0x1b,"[0m"
mem_hdr_len equ $-mem_hdr
mem_colon db ":"
mem_colon_len equ $-mem_colon

demo_prog:
    db 0x01,0x00,0x0A
    db 0x01,0x01,0x03
    db 0x10,0x02,0x01
    db 0x03,0x02,0x00
    db 0x02,0x03,0x00
    db 0xFF,0x00,0x00
demo_prog_len equ $-demo_prog

prompt_reg db "Register index (0..3): "
prompt_reg_len equ $-prompt_reg
prompt_val db "Value (dec or 0x..): "
prompt_val_len equ $-prompt_val

prompt_src1 db "SRC1 (0..3): "
prompt_src1_len equ $-prompt_src1
prompt_src2 db "SRC2 (0..3): "
prompt_src2_len equ $-prompt_src2
prompt_op db "OP (0..7): "
prompt_op_len equ $-prompt_op
prompt_dest db "DEST (0..3): "
prompt_dest_len equ $-prompt_dest
prompt_we db "WE (0/1): "
prompt_we_len equ $-prompt_we

ctl_lbl db 10,"Control: "
ctl_lbl_len equ $-ctl_lbl
src1_lbl db "SRC1="
src1_lbl_len equ $-src1_lbl
src2_lbl db "SRC2="
src2_lbl_len equ $-src2_lbl
op_lbl db "OP="
op_lbl_len equ $-op_lbl
dest_lbl db "DEST="
dest_lbl_len equ $-dest_lbl
we_lbl db "WE="
we_lbl_len equ $-we_lbl

ab_out_lbl db "A/B/OUT: "
ab_out_lbl_len equ $-ab_out_lbl
a8_lbl db "A="
a8_lbl_len equ $-a8_lbl
b8_lbl db "B="
b8_lbl_len equ $-b8_lbl
out8_lbl db "OUT="
out8_lbl_len equ $-out8_lbl

flags_m_lbl db "Flags: "
flags_m_lbl_len equ $-flags_m_lbl
m_c_lbl db "C="
m_c_lbl_len equ $-m_c_lbl
m_z_lbl db "Z="
m_z_lbl_len equ $-m_z_lbl
m_s_lbl db "S="
m_s_lbl_len equ $-m_s_lbl
m_v_lbl db "V="
m_v_lbl_len equ $-m_v_lbl

regs_lbl db "Regs:"
regs_lbl_len equ $-regs_lbl
r0_lbl db "R0="
r0_lbl_len equ $-r0_lbl
r1_lbl db "R1="
r1_lbl_len equ $-r1_lbl
r2_lbl db "R2="
r2_lbl_len equ $-r2_lbl
r3_lbl db "R3="
r3_lbl_len equ $-r3_lbl

hex_prefix db "0x"
hex_prefix_len equ $-hex_prefix

title_fa_gate db 10,"--- Full Adder Gate-Level Breakdown ---",10
title_fa_gate_len equ $-title_fa_gate

title_rca4 db 10,"--- 4-bit Ripple Carry Adder ---",10
title_rca4_len equ $-title_rca4

header_fa_gate db "A B Cin | X AB CinX | Sum Cout",10
header_fa_gate_len equ $-header_fa_gate

sep_gate db "  | "
sep_gate_len equ $-sep_gate

eq_fa db 10,"Equations: X=A XOR B, Sum=X XOR Cin, Cout=(A&B) OR (Cin&X)",10
eq_fa_len equ $-eq_fa

prompt_a4 db "Enter A (0..15): "
prompt_a4_len equ $-prompt_a4
prompt_b4 db "Enter B (0..15): "
prompt_b4_len equ $-prompt_b4

in_lbl db "Inputs: "
in_lbl_len equ $-in_lbl
out_lbl db "Output: "
out_lbl_len equ $-out_lbl

a_lbl db "A="
a_lbl_len equ $-a_lbl
b_lbl db "B="
b_lbl_len equ $-b_lbl
cin_lbl db "Cin="
cin_lbl_len equ $-cin_lbl

header_rca4 db "i ai bi cin | x sum cout",10
header_rca4_len equ $-header_rca4

carries_lbl db "Carries: "
carries_lbl_len equ $-carries_lbl
cchar db "C"
eqchar db "="

sum_lbl2 db "Sum[3:0]="
sum_lbl2_len equ $-sum_lbl2
cout_lbl2 db "Cout="
cout_lbl2_len equ $-cout_lbl2
sum_dec_lbl db "Sum (decimal)="
sum_dec_lbl_len equ $-sum_dec_lbl

title_add db 10,"--- ADD ---",10
title_add_len equ $-title_add
title_sub db 10,"--- SUB ---",10
title_sub_len equ $-title_sub
title_and db 10,"--- AND ---",10
title_and_len equ $-title_and
title_or  db 10,"--- OR  ---",10
title_or_len  equ $-title_or
title_xor db 10,"--- XOR ---",10
title_xor_len equ $-title_xor
title_shl db 10,"--- SHL ---",10
title_shl_len equ $-title_shl
title_shr db 10,"--- SHR ---",10
title_shr_len equ $-title_shr
title_cmp db 10,"--- CMP ---",10
title_cmp_len equ $-title_cmp

title_fa db 10,"--- Full Adder Truth Table ---",10
title_fa_len equ $-title_fa

title_tt db 10,"--- Truth Table (A,B) ---",10
title_tt_len equ $-title_tt

header_fa db "A B Cin | Sum Cout",10
header_fa_len equ $-header_fa

header_tt db "A B | AND OR XOR NAND NOR",10
header_tt_len equ $-header_tt

sep_fa db "  | "
sep_fa_len equ $-sep_fa

sep_tt db "  | "
sep_tt_len equ $-sep_tt

rel_gt_txt db "Relation: A > B",10
rel_gt_len  equ $-rel_gt_txt
rel_eq_txt db "Relation: A = B",10
rel_eq_len  equ $-rel_eq_txt
rel_lt_txt db "Relation: A < B",10
rel_lt_len  equ $-rel_lt_txt

result_lbl db "Result: "
result_lbl_len equ $-result_lbl
bin_lbl db "Binary: "
bin_lbl_len equ $-bin_lbl
flags_lbl db "Flags: "
flags_lbl_len equ $-flags_lbl

c_lbl db "C="
c_lbl_len equ $-c_lbl
z_lbl db "Z="
z_lbl_len equ $-z_lbl
s_lbl db "S="
s_lbl_len equ $-s_lbl

press_enter db 10,"Press Enter to return to menu...",10
press_enter_len equ $-press_enter

nlc   db 10
spc   db " "
minus db "-"
hex_digits db "0123456789ABCDEF"

section .bss
A       resd 1
B       resd 1
RES     resd 1
SH      resb 1
FLAG_C  resb 1
FLAG_Z  resb 1
FLAG_S  resb 1

CARRY   resb 5
B4_TMP  resd 1

M_REGS   resb 4
M_TMP_IDX resb 1
M_FLAG_C resb 1
M_FLAG_Z resb 1
M_FLAG_S resb 1
M_FLAG_V resb 1

M_SRC1   resb 1
M_SRC2   resb 1
M_OP     resb 1
M_DEST   resb 1
M_WE     resb 1
M_A      resb 1
M_B      resb 1
M_OUT    resb 1

CPU_PC     resb 1
; FIX: program length for bounds check
CPU_PROG_LEN resb 1
CPU_PC_TMP resb 1
CPU_IR_OP  resb 1
CPU_IR_B1  resb 1
CPU_IR_B2  resb 1
CPU_HALT   resb 1
CPU_MEM    resb 16
CPU_PROG   resb 96

buf_num resb 16
inbuf   resb 64
onech   resb 1
