# Copyright 2013-2016, Stephen Fryatt (info@stevefryatt.org.uk)
#
# This file is part of MsgMon:
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

ARCHIVE := msgmon

MODULE := MsgMon,ffa
GETTIME := gettime

OUTDIR := build
EXTRASRCPREREQ := $(OUTDIR)/$(GETTIME)

ASOPTIONS = $(shell $(OUTDIR)/$(GETTIME))

OBJS := MsgMon.o

include $(SFTOOLS_MAKE)/Module

# Build the GetTime helper utility.

$(OUTDIR)/$(GETTIME): $(SRCDIR)/gettime.c
	$(CC) $(SRCDIR)/gettime.c -o $(OUTDIR)/$(GETTIME)

# Clean targets

clean::
	$(RM) $(OUTDIR)/$(GETTIME)
