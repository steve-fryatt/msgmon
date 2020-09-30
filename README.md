MsgMon
======

Snoop on Wimp messages between applications with Reporter.


Introduction
------------

MsgMon is a module to work with Reporter, from Chris Morison and Martin Avison, in order to display details of messages passed between applications using the Wimp's User Message protocol. When run, it installs a set of filters to watch for messages; these are decoded and, if they are in the list of message codes that MsgMon is interested in, displayed in the Reporter window.

Copies of the latest version of Reporter can be found on [Martin Avison's website](http://www.avisoft.force9.co.uk/).


Building
--------

MsgMon consists of a collection of ARM assembler, C and un-tokenised BASIC, which must be assembled using the [SFTools build environment](https://github.com/steve-fryatt). It will be necessary to have suitable Linux system with a working installation of the [GCCSDK](http://www.riscos.info/index.php/GCCSDK) to be able to make use of this.

With a suitable build environment set up, making MsgMon is a matter of running

	make

from the root folder of the project. This will build everything from source, and assemble a working MsgMon module and its associated files within the build folder. If you have access to this folder from RISC OS (either via HostFS, LanManFS, NFS, Sunfish or similar), it will be possible to run it directly once built.

To clean out all of the build files, use

	make clean

To make a release version and package it into Zip files for distribution, use

	make release

This will clean the project and re-build it all, then create a distribution archive (no source), source archive and RiscPkg package in the folder within which the project folder is located. By default the output of `git describe` is used to version the build, but a specific version can be applied by setting the `VERSION` variable -- for example

	make release VERSION=1.23


Licence
-------

MsgMon is licensed under the EUPL, Version 1.2 only (the "Licence"); you may not use this work except in compliance with the Licence.

You may obtain a copy of the Licence at <http://joinup.ec.europa.eu/software/page/eupl>.

Unless required by applicable law or agreed to in writing, software distributed under the Licence is distributed on an "**as is**"; basis, **without warranties or conditions of any kind**, either express or implied.

See the Licence for the specific language governing permissions and limitations under the Licence.