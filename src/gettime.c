/* Copyright 2013, Stephen Fryatt (info@stevefryatt.org.uk)
 *
 * This file is part of MsgMon:
 *
 *   http://www.stevefryatt.org.uk/software/
 *
 * Licensed under the EUPL, Version 1.1 only (the "Licence");
 * You may not use this work except in compliance with the
 * Licence.
 *
 * You may obtain a copy of the Licence at:
 *
 *   http://joinup.ec.europa.eu/software/page/eupl
 *
 * Unless required by applicable law or agreed to in
 * writing, software distributed under the Licence is
 * distributed on an "AS IS" basis, WITHOUT WARRANTIES
 * OR CONDITIONS OF ANY KIND, either express or implied.
 *
 * See the Licence for the specific language governing
 * permissions and limitations under the Licence.
 */

/**
 * \file: gettime.c
 *
 * Generate command line arguments for Asasm to set the current timestamp
 * for the embedded file.
 */

#include <time.h>
#include <stdio.h>

void main(void)
{
	time_t now;
	long long riscos;

	time(&now);

	riscos = now;
	riscos = (riscos + 2208988800LL) * 100LL;

	printf("-PreDefine 'ExecAddr SETS \"&%08llX\"' -PreDefine 'LoadAddr SETS \"&%08llX\"\n'", riscos & 0xffffffff, 0xffffff00 | ((riscos >> 32) & 0xff));
}
