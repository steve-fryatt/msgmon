# Copyright 2013, Stephen Fryatt (info@stevefryatt.org.uk)
#
# This file is part of MenuGen:
#
#   http://www.stevefryatt.org.uk/software/
#
# Licensed under the EUPL, Version 1.1 only (the "Licence");
# You may not use this work except in compliance with the
# Licence.
#
# You may obtain a copy of the Licence at:
#
#   http://joinup.ec.europa.eu/software/page/eupl
#
# Unless required by applicable law or agreed to in
# writing, software distributed under the Licence is
# distributed on an "AS IS" basis, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, either express or implied.
#
# See the Licence for the specific language governing
# permissions and limitations under the Licence.

# This file really needs to be run by GNUMake.
# It is intended for native compilation on Linux (for use in a GCCSDK
# environment) or cross-compilation under the GCCSDK.

# Set VERSION to build using a version number and not an SVN revision.

.PHONY: all clean application documentation release backup

# The build date.

BUILD_DATE := $(shell date "+%d %b %Y")
HELP_DATE := $(shell date "+%-d %B %Y")

# Construct version or revision information.

ifeq ($(VERSION),)
  RELEASE := $(shell svnversion --no-newline)
  VERSION := r$(RELEASE)
  RELEASE := $(subst :,-,$(RELEASE))
  HELP_VERSION := ----
else
  RELEASE := $(subst .,,$(VERSION))
  HELP_VERSION := $(VERSION)
endif

$(info Building with version $(VERSION) ($(RELEASE)) on date $(BUILD_DATE))

# The archive to assemble the release files in.  If $(RELEASE) is set, then the file can be given
# a standard version number suffix.

ZIPFILE := msgmon$(RELEASE).zip
SRCZIPFILE := msgmon$(RELEASE)src.zip
BUZIPFILE := msgmon$(shell date "+%Y%m%d").zip

# Build Tools

AS := $(wildcard $(GCCSDK_INSTALL_CROSSBIN)/*asasm)
STRIP := $(wildcard $(GCCSDK_INSTALL_CROSSBIN)/*strip)
CC := gcc

MKDIR := mkdir
RM := rm -rf
CP := cp

ZIP := /home/steve/GCCSDK/env/bin/zip

SFBIN := /home/steve/GCCSDK/sfbin

TEXTMAN := $(SFBIN)/textman
STRONGMAN := $(SFBIN)/strongman
HTMLMAN := $(SFBIN)/htmlman
DDFMAN := $(SFBIN)/ddfman
BINDHELP := $(SFBIN)/bindhelp
TEXTMERGE := $(SFBIN)/textmerge
MENUGEN := $(SFBIN)/menugen


# Build Flags

ASFLAGS :=
STRIPFLAGS := -O binary
ZIPFLAGS := -x "*/.svn/*" -r -, -9
SRCZIPFLAGS := -x "*/.svn/*" -r -9
BUZIPFLAGS := -x "*/.svn/*" -r -9
BINDHELPFLAGS := -f -r -v


# Set up the various build directories.

SRCDIR := src
MANUAL := manual
OBJDIR := obj
OUTDIR := build


# Set up the named target files.

RUNIMAGE := MsgMon,ffa
README := ReadMe,fff
LICENSE := Licence,fff
GETTIME := gettime


# Set up the source files.

MANSRC := Source
MANSPR := ManSprite
READMEHDR := Header

OBJS := MsgMon.o

# Build everything, but don't package it for release.

all: application documentation


# Build the application and its supporting binary files.

application: $(OUTDIR)/$(RUNIMAGE)


# Build the complete !RunImage from the object files.

OBJS := $(addprefix $(OBJDIR)/, $(OBJS))

$(OUTDIR)/$(RUNIMAGE): $(OBJS) $(OBJDIR)
	$(STRIP) $(STRIPFLAGS) -o $(OUTDIR)/$(RUNIMAGE) $(OBJS)
	armalyser -d -o Compare/new.txt $(OUTDIR)/$(RUNIMAGE)

# Create a folder to hold the object files.

$(OBJDIR):
	$(MKDIR) $(OBJDIR)

# Build the object files, and identify their dependencies.

$(OBJDIR)/%.o: $(SRCDIR)/%.s $(OUTDIR)/$(GETTIME)
	$(AS) $(ASFLAGS) $(shell $(OUTDIR)/$(GETTIME)) -PreDefine 'BuildDate SETS "\"$(BUILD_DATE)\""' -PreDefine 'BuildVersion SETS "\"$(VERSION)\""' -o $@ $<

$(OUTDIR)/$(GETTIME): $(SRCDIR)/gettime.c
	$(CC) $(SRCDIR)/gettime.c -o $(OUTDIR)/$(GETTIME)

# Build the documentation

documentation: $(OUTDIR)/$(README)

$(OUTDIR)/$(README): $(MANUAL)/$(MANSRC)
	$(TEXTMAN) -I$(MANUAL)/$(MANSRC) -O$(OUTDIR)/$(README) -D'version=$(HELP_VERSION)' -D'date=$(HELP_DATE)'


# Build the release Zip file.

release: clean all
	$(RM) ../$(ZIPFILE)
	(cd $(OUTDIR) ; $(ZIP) $(ZIPFLAGS) ../../$(ZIPFILE) $(RUNIMAGE) $(README) $(LICENSE))
	$(RM) ../$(SRCZIPFILE)
	$(ZIP) $(SRCZIPFLAGS) ../$(SRCZIPFILE) $(OUTDIR) $(SRCDIR) $(MANUAL) Makefile


# Build a backup Zip file

backup:
	$(RM) ../$(BUZIPFILE)
	$(ZIP) $(BUZIPFLAGS) ../$(BUZIPFILE) *


# Clean targets

clean:
	$(RM) $(OBJDIR)/*
	$(RM) $(OUTDIR)/$(RUNIMAGE)
	$(RM) $(OUTDIR)/$(README)
	$(RM) $(OUTDIR)/$(GETTIME)

