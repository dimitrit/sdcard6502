PROGRAM = loadfile

LIBS = libfat32.o libio.o libsd.o

all: $(PROGRAM).ptp

$(PROGRAM).ptp: $(PROGRAM).bin Makefile
	srec_cat $(PROGRAM).bin -binary -offset 0xa000 -o $(PROGRAM).ptp -MOS_Technologies

$(PROGRAM).bin: $(PROGRAM).o $(LIBS)
	ld65 -S 0xA000 -C kim1-60k.cfg -vm -m $(PROGRAM).map -Ln $(PROGRAM).lbl -o $(PROGRAM).bin $(PROGRAM).o $(LIBS)

%.o: %.s
	ca65 -DDEBUG -g -l $(basename $<).lst $<

clean:
	$(RM) *.o *.lst *.map *.bin *.ptp

flash:
	minipro -p AT28C64B -w $(PROGRAM).bin -s

distclean: clean
