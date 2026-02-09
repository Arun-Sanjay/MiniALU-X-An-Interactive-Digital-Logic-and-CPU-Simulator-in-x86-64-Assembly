# Minimal macOS Mach-O NASM build for the simulator.

NASM ?= nasm
LD   ?= ld

BIN_DIR := bin
OUT     := $(BIN_DIR)/minialu-x
OBJ     := $(BIN_DIR)/alu.o
SRC     := alu.asm

.PHONY: all clean

all: $(OUT)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(OBJ): $(SRC) | $(BIN_DIR)
	$(NASM) -fmacho64 $(SRC) -o $(OBJ)

$(OUT): $(OBJ)
	$(LD) -lSystem -macosx_version_min 10.13 -o $(OUT) -e _start $(OBJ)

clean:
	rm -rf $(BIN_DIR)

