INCLUDE_SRCS = include/*.inc
ASM_SRCS = *.asm

emu.bin: ${ASM_SRCS} ${INCLUDE_SRCS}
	64tass -D emulator=true -o emu.bin --nostart --no-monitor --line-numbers --tab-size=1 --list=emu.lst main_pymon.asm

clean:
	rm  -f *.bin *.hex *.lst *~
