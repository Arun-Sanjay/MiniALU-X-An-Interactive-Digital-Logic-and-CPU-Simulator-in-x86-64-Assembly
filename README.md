# MiniALU-X  
**An Interactive Digital Logic and Mini CPU Simulator in x86-64 Assembly**

MiniALU-X is an educational, terminal-based simulator written entirely in **x86-64 NASM assembly** that demonstrates how digital logic blocks (adders, logic gates) scale into a functional **ALU and a minimal CPU-style execution model**.

It bridges the gap between **digital logic theory** and **real processor behavior** by exposing registers, control words, carry propagation, and status flags at the lowest level.

## 👀 Preview
![djnf](https://github.com/user-attachments/assets/a6d3bcbd-df47-48f5-8367-a02b8409bb29)

---

## ✨ Key Features

### 🔹 Digital Logic
- **1-bit Full Adder**
  - Truth table generation
- **4-bit Ripple Carry Adder**
  - Stage-by-stage carry propagation
  - Carry chain visualization (`C0 → C4`)
  - Binary and decimal result display
- **Logic Gate Truth Tables**
  - AND, OR, XOR, NAND, NOR

### 🔹 ALU Operations
- ADD, SUB
- AND, OR, XOR
- SHL, SHR
- CMP (comparison with flag effects)

### 🔹 Status Flags
- **C** – Carry / Borrow  
- **Z** – Zero  
- **S** – Sign  
- **V** – Signed Overflow  

Flags are explicitly computed and displayed after every operation.

### 🔹 Mini ALU System
- 4 × 8-bit registers (`R0–R3`)
- Control word–driven execution
- Explicit SRC1, SRC2, DEST, OP, WE fields
- Binary + hexadecimal visualization

### 🔹 Mini CPU Mode
- Program memory
- Data memory (16 bytes)
- Fetch–Decode–Execute cycle
- Instruction Register (IR), Program Counter (PC)
- Micro-operation tracing (`FETCH`, `DECODE`, `EXEC`)
- Step-by-step or continuous execution

---

## 🧠 Educational Purpose

MiniALU-X is designed to help students and learners:

- Understand **how adders actually work beyond truth tables**
- Visualize **carry propagation** and overflow
- See how **ALU results affect CPU flags**
- Connect **logic gates → ALU → CPU execution**
- Learn low-level system behavior through **assembly language**

This makes it especially useful for:
- Digital Logic
- Computer Organization
- Computer Architecture
- Assembly Language courses

---

## 🖥️ Platform & Requirements

- **OS:** macOS (x86-64 binaries, supported on Apple Silicon via Rosetta 2)
- **Assembler:** NASM
- **Linker:** `ld64.lld` or system `ld`
- **Terminal:** ANSI-compatible

> ⚠️ Apple Silicon users must run in x86-64 mode (Rosetta).

---

## 🔧 Build & Run

```bash
nasm -f macho64 sched.asm -o alu.o
ld64.lld -arch x86_64 alu.o -o alu \
  -e _start -lSystem \
  -syslibroot "$(xcrun --sdk macosx --show-sdk-path)"
./alu
```

---

## 📋 Main Menu Overview

```
[Digital Logic]
F) Full Adder truth table
R) 4-bit Ripple Carry Adder
T) Logic-gates truth table
M) Mini ALU System

[ALU Operations]
1) ADD   2) SUB   3) AND   4) OR
5) XOR   6) SHL   7) SHR   8) CMP
```

---

## 🔁 Mini ALU Commands

```
MiniALU: S=State L=Load E=Exec P=Program Q=Back
```

| Command | Function |
|------|---------|
| `S` | Display registers and flags |
| `L` | Load value into register |
| `E` | Execute ALU operation |
| `P` | Enter Mini CPU program mode |
| `Q` | Return to main menu |

---

## 🧪 Example (Ripple Carry Adder)

```
A = 3 (0011)
B = 1 (0001)
Cin = 1

Stage-by-stage carry:
C0=1 C1=1 C2=0 C3=0 C4=0

Sum = 0101 (5)
```

---

## 📦 Project Structure

```
sched.asm      → Complete ALU + Mini CPU implementation (NASM)
README.md      → Project documentation
```

(All logic is implemented in a **single assembly source file** for clarity and traceability.)

---

## 🚀 Future Enhancements

- Wider datapath (16-bit / 32-bit)
- Multiply & divide operations
- Branch instructions (JZ, JNZ)
- Pipeline visualization
- GUI frontend over assembly backend
- Linux syscall support

---

## 📄 License

MIT License  
© 2026 Arun Sanjay

---

## ⭐ Why This Project Matters

Most projects *describe* how CPUs work.  
**MiniALU-X shows it — bit by bit, carry by carry, flag by flag.**

If you’re learning computer architecture, this is the missing bridge between theory and reality.
