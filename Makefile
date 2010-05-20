# Makefile for MsgMon
#
# This just builds the manual, as the module is assembled in the BASIC
# Assembler on RISC OS.

.PHONY: all documentation release

# Build Tools

RM := rm -r
CP := cp

ZIP := /home/steve/GCCSDK/env/bin/zip

SFBIN := /home/steve/GCCSDK/sfbin/

TEXTMAN := $(SFBIN)textman
STRONGMAN := $(SFBIN)strongman
HTMLMAN := $(SFBIN)htmlman
DDFMAN := $(SFBIN)ddfman
BINDHELP := $(SFBIN)bindhelp

BUILD := build/
RELEASE := release/
RISCOS := RISCOS/

ZIPFLAGS = -r -, -9 -j


# Default target.

all:	documentation

documentation:	$(BUILD)ReadMe,fff $(BUILD)MsgMonSH,3d6 $(BUILD)MsgMon.html

$(BUILD)ReadMe,fff:	manual/Source
	$(TEXTMAN) manual/Source $(BUILD)ReadMe,fff

$(BUILD)MsgMonSH,3d6: manual/Source manual/ManSprite
	$(STRONGMAN) manual/Source SHTemp
	$(CP) manual/ManSprite SHTemp/Sprites,ff9
	$(BINDHELP) SHTemp $(BUILD)MsgMonSH,3d6 -f -r -v
	$(RM) SHTemp

$(BUILD)MsgMon.html: manual/Source
	$(HTMLMAN) manual/Source $(BUILD)MsgMon.html

release:	all
	$(RM) $(RELEASE)*
	$(CP) $(RISCOS)MsgMon,ffa $(RELEASE)MsgMon,ffa
	$(CP) $(RISCOS)MsgMonSrc,ffb $(RELEASE)MsgMonSrc,ffb
	$(CP) $(BUILD)ReadMe,fff $(RELEASE)ReadMe,fff
	$(ZIP) $(ZIPFLAGS) msgmon$(VERSION).zip $(RELEASE)MsgMon,ffa
	$(ZIP) $(ZIPFLAGS) msgmon$(VERSION).zip $(RELEASE)MsgMonSrc,ffb
	$(ZIP) $(ZIPFLAGS) msgmon$(VERSION).zip $(RELEASE)ReadMe,fff

