; Copyright 2007-2013, Stephen Fryatt (info@stevefryatt.org.uk)
;
; This file is part of MsgMon:
;
;   http://www.stevefryatt.org.uk/software/
;
; Licensed under the EUPL, Version 1.1 only (the "Licence");
; You may not use this work except in compliance with the
; Licence.
;
; You may obtain a copy of the Licence at:
;
;   http://joinup.ec.europa.eu/software/page/eupl
;
; Unless required by applicable law or agreed to in
; writing, software distributed under the Licence is
; distributed on an "AS IS" basis, WITHOUT WARRANTIES
; OR CONDITIONS OF ANY KIND, either express or implied.
;
; See the Licence for the specific language governing
; permissions and limitations under the Licence.

; MsgMon.s
;
; MsgMon Module Source
;
; REM 26/32 bit neutral


XOS_Module				EQU &02001E
XOS_ReadUnsigned			EQU &020021
OS_ReadArgs				; Should be XOS...
OS_PrettyPrint
OS_NewLine
OS_Write0
XResourceFS_RegisterFiles
XResourceFS_DeregisterFiles
XFilter_RegisterPostFilter
OS_Find
OS_BGet




version$="1.02"
save_as$="MsgMon"

LIBRARY "<Reporter$Dir>.AsmLib"

PRINT "Assemble debug? (Y/N)"
REPEAT
 g%=GET
UNTIL (g% AND &DF)=ASC("Y") OR (g% AND &DF)=ASC("N")
debug%=((g% AND &DF)=ASC("Y"))

ON ERROR PRINT REPORT$;" at line ";ERL : END

REM --------------------------------------------------------------------------------------------------------------------
REM Set up workspace

workspace_target%=&600
workspace_size%=0 : REM This is updated.
block_size%=256

module_flags%=FNworkspace(workspace_size%,4)
msg_list%=FNworkspace(workspace_size%,4)
msg_file_data%=FNworkspace(workspzce_size%,4)
msg_file_index%=FNworkspace(workspace_size%,4)
msg_file_len%=FNworkspace(workspace_size%,4)
block%=FNworkspace(workspace_size%,block_size%)

PRINT'"Stack size:  ";workspace_target%-workspace_size%;" bytes."
stack%=FNworkspace(workspace_size%,workspace_target%-workspace_size%)

REM --------------------------------------------------------------------------------------------------------------------
REM Set up the module flags

flag_icon% =   &10 : REM Flag set if the caret is currently in a writable icon.
flag_wimp% =   &20 : REM Flag set if we are currently in a Wimp context.
flag_doicon% = &40 : REM Flag set if we are supposed to be fiddling wimp icon keys.

REM --------------------------------------------------------------------------------------------------------------------
REM Set up application list block

msg_block_size%=0 : REM This is updated.

msg_block_magic_word%=FNworkspace(msg_block_size%,4)
msg_block_next%=FNworkspace(msg_block_size%,4)
msg_block_dim%=FNworkspace(msg_block_size%,4)
msg_block_number%=FNworkspace(msg_block_size%,4)

REM --------------------------------------------------------------------------------------------------------------------

DIM time% 5, date% 256
?time%=3
SYS "OS_Word",14,time%
SYS "Territory_ConvertDateAndTime",-1,time%,date%,255,"(%dy %m3 %ce%yr)" TO ,date_end%
?date_end%=13

REM --------------------------------------------------------------------------------------------------------------------

code_space%=8000
DIM code% code_space%

pass_flags%=%11100

IF debug% THEN PROCReportInit(200)

FOR pass%=pass_flags% TO pass_flags% OR %10 STEP %10
L%=code%+code_space%
O%=code%
P%=0
IF debug% THEN PROCReportStart(pass%)
[OPT pass%
EXT 1

	AREA	Module,CODE
	ENTRY

; ======================================================================================================================
; Module Header

ModuleHeader
	DCD	0			; Offset to task code
	DCD	InitCode		; Offset to initialisation code
	DCD	FinalCode		; Offset to finalisation code
	DCD	ServiceCode		; Offset to service-call handler
	DCD	TitleString		; Offset to title string
	DCD	HelpString		; Offset to help string
	DCD	CommandTable		; Offset to command table
	DCD	0			; SWI Chunk number
	DCD	0			; Offset to SWI handler code
	DCD	0			; Offset to SWI decoding table
	DCD	0			; Offset to SWI decoding code
	DCD	0			; MessageTrans file
	DCD	ModuleFlags		; Offset to module flags

; ======================================================================================================================

ModuleFlags
	DCD	1			; 32-bit compatible

; ======================================================================================================================

TitleString
	DCB	"MsgMon",0
	ALIGN

HelpString
	DCB	"Message Monitor",9,$BuildVersion," (",$BuildDate,") ",169," Stephen Fryatt, 2011"
	ALIGN

; ======================================================================================================================

CommandTable
	DCB	"MsgMonAddMsg",0
	ALIGN
	DCD	CommandAddMsg
	DCD	&00020001
	DCD	CommandAddMsgSyntax
	DCD	CommandAddMsgHelp

	DCB	"MsgMonRemoveMsg",0
	ALIGN
	DCD	CommandRemoveMsg
	DCD	&00020001
	DCD	CommandRemoveMsgSyntax
	DCD	CommandRemoveMsgHelp

	DCB	"MsgMonListMsgs",0
	ALIGN
	DCD	CommandListMsgs
	DCD	&00000000
	DCD	CommandListMsgsSyntax
	DCD	CommandListMsgsHelp

	DCB	"MsgMonLoadMsgs",0
	ALIGN
	DCD	CommandLoadMsgs
	DCD	&00020001
	DCD	CommandLoadMsgsSyntax
	DCD	CommandLoadMsgsHelp

	DCD	0

; ----------------------------------------------------------------------------------------------------------------------

CommandAddMsgHelp
	DCB	"*"
	DCB	27
	DCB	0
	DCB	" "
	DCB	"adds a message to the MsgMon list."
	DCB	13

CommandAddMsgSyntax
	DCB	27
	DCB	30
	DCB	"-message] <message code>"
	DCB	0

CommandRemoveMsgHelp
	DCB	"*"
	DCB	27
	DCB	0
	DCB	" "
	DCB	"removes messages from the MsgMon list."
	DCB	13

CommandRemoveMsgSyntax
	DCB	27
	DCB	30
	DCB	"-message] <message code> [-all]"
	DCB	0

CommandListMsgsHelp
	DCB	"*"
	DCB	27
	DCB	0
	DCB	" "
	DCB	"lists the messages currently on the MsgMon list."
	DCB	13

CommandListMsgsSyntax
	DCB	27
	DCB	1
	DCB	0

CommandLoadMsgsHelp
	DCB	"*"
	DCB	27
	DCB	0
	DCB	" "
	DCB	"loads a new file of message definitions."
	DCB	13

CommandLoadMsgsSyntax
	DCB	27
	DCB	30
	DCB	"-file] <message file>"
	DCB	0

	ALIGN

; ======================================================================================================================
; The code for the *MsgMonAddMsg command.
;
; Entered with one parameter (the new message number).

CommandAddMsg
	STMFD	R13!,{R14}
	LDR	R12,[R12]

; Claim 64 bytes of workspace from the stack.

	SUB	R13,R13,#64

; Decode the parameter string.

	MOV	R1,R0
	ADR	R0,AddMsgKeywordString
	MOV	R2,R13
	MOV	R3,#64
	SWI	OS_ReadArgs

	MOV	R4,R2					; Put the command buffer somewhere safe.

; Start to decode the parameters

	LDR	R1,[R4,#0]
	TEQ	R1,#0
	BEQ	AddMsgExit

	MOV	R0,#10
	SWI	XOS_ReadUnsigned
	BVS	AddMsgExit

	MOV	R0,R2
	BL	find_msg_block
	TEQ	R6,#0
	BNE	AddMsgExit

	MOV	R6,R0					; Keep the message number somewhere safe

; Claim a block from the RMA to store the message details.

AddMsgClaimBlock
	MOV	R0,#6
	MOV	R3,#msg_block_size%
	SWI	XOS_Module
	BVS	AddMsgExit

; Initialise the details.

AddMsgFillBlock
	LDR	R0,MagicWord				; Magic word to check block identity.
	STR	R0,[R2,#msg_block_magic_word%]
	STR	R3,[R2,#msg_block_dim%]			; Block size.
	STR	R6,[R2,#msg_block_number%]		; Point to the start of the namespace...

; Link the block into the message list.

AddMsgLinkIn
	LDR	R5,[R12,#msg_list%]
	STR	R5,[R2,#msg_block_next%]
	STR	R2,[R12,#msg_list%]

AddMsgExit
	ADD	R13,R13,#64
	LDMFD	R13!,{PC}

; ----------------------------------------------------------------------------------------------------------------------

AddMsgKeywordString
	DCB	"message/A",0
	ALIGN

; ======================================================================================================================
; The code for the *MsgMonRemoveMsg command.
;
; Entered with one parameter (the message number).

CommandRemoveMsg
	STMFD	R13!,{R14}
	LDR	R12,[R12]

; Claim 64 bytes of workspace from the stack.

	SUB	R13,R13,#64

; Decode the parameter string.

	MOV	R1,R0
	ADR	R0,RemMsgKeywordString
	MOV	R2,R13
	MOV	R3,#64
	SWI	OS_ReadArgs

	MOV	R4,R2					; Put the command buffer somewhere safe.

; Start to decode the parameters

	; First test for the 'all' flag.

	LDR	R1,[R4,#4]
	TEQ	R1,#0
	BNE	RemMsgAll

	; Now look for a value against the message parameter.

	LDR	R1,[R4,#0]
	TEQ	R1,#0
	BEQ	RemMsgExit

	MOV	R0,#10
	SWI	XOS_ReadUnsigned
	BVS	RemMsgExit

; Find the message block if it exists.

	MOV	R0,R2
	BL	find_msg_block
	TEQ	R6,#0
	BEQ	RemMsgExit

; Find the message block in the linked list and remove it.

RemMsgStartMsgSearch
	ADRW	R0,msg_list%

RemMsgFindMsgLoop
	LDR	R1,[R0]

	TEQ	R1,R6
	BEQ	RemMsgFoundMsg

	ADD	R0,R1,#msg_block_next%
	B	RemMsgFindMsgLoop

RemMsgFoundMsg
	LDR	R1,[R6,#msg_block_next%]
	STR	R1,[R0]

	MOV	R0,#7
	MOV	R2,R6
	SWI	XOS_Module"

	B	RemMsgExit

; Remove all the messages.

RemMsgAll
	LDR	R6,[R12,#msg_list%]
	TEQ	R6,#0
	BEQ	RemMsgExit

	MOV	R4,#0
	STR	R4,[R12,#msg_list%]

RemMsgAllLoop
	LDR	R5,[R6,#msg_block_next%]

	MOV	R0,#7
	MOV	R2,R6
	SWI	XOS_Module

	MOVS	R6,R5
	BNE	RemMsgAllLoop

RemMsgExit
	ADD	R13,R13,#64
	LDMFD	R13!,{PC}

; ----------------------------------------------------------------------------------------------------------------------

RemMsgKeywordString
	DCB	"message,all/S",0
	ALIGN

; ======================================================================================================================

; The code for the *MsgMonListMsgs command.
;
; Entered with no parameters.

CommandListMsgs
	STMFD	R13!,{R14}
	LDR	R12,[R12]

; Traverse the message linked list, printing the message data out as we go.

	LDR	R6,[R12,#msg_list%]
	TEQ	R6,#0
	BEQ	ListMsgsAllMsgs

; Write out the column headings.

ListMsgsMsgList
	MOV	R1,#0
	MOV	R2,#0

	ADR	R0,DisplaySomeMsgs
	SWI	OS_PrettyPrint
	SWI	OS_NewLine
	SWI	OS_NewLine

ListMsgsOuterLoop

; Print the message number

ListMsgsPrintNames
	LDR	R0,[R6,#msg_block_number%]
	ADRW	R1,block%
	BL	convert_msg_number

	ADRW	R0,block%
	SWI	OS_Write0

; End off with a new line.

ListMsgsPrintEOL
	SWI	OS_NewLine

; Get the next message data block and loop.

	LDR	R6,[R6,#msg_block_next%]

	TEQ	R6,#0
	BNE	ListMsgsOuterLoop

	B	ListMsgsExit

ListMsgsAllMsgs
	ADR	R0,DisplayAllMsgs
	SWI	OS_PrettyPrint
	SWI	OS_NewLine

; Print a final blank line and exit.

ListMsgsExit
	SWI	OS_NewLine

	LDMFD	R13!,{PC}

; ----------------------------------------------------------------------------------------------------------------------

MagicWord
	DCB	"MSGM"					; The RMA data block identifier.

DisplayAllMsgs
	EQUZ	"All messages are being reported.",0

DisplaySomeMsgs
	DCB	"The following messages are being reported:",0

	ALIGN

; ======================================================================================================================

; The code for the *MsgMonLoadMsgs command.
;
; Entered with one paramener (the message file name).

CommandLoadMsgs
	STMFD	R13!,{R14}
	LDR	R12,[R12]

; Claim 64 bytes of workspace from the stack.

	SUB	R13,R13,#64

; Decode the parameter string.

	MOV	R1,R0
	ADR	R0,LoadMsgsKeywordString
	MOV	R2,R13
	MOV	R3,#64
	SWI	OS_ReadArgs

	MOV	R4,R2					; Put the command buffer somewhere safe.

; Start to decode the parameters

	; Look for a value against the message parameter.

	LDR	R0,[R4,#0]
	TEQ	R0,#0
	BEQ	LoadMsgsExit

	BL	LoadMsgFile

LoadMsgsExit
	ADD	R13,R13,#64
	LDMFD	R13!,{PC}

; ----------------------------------------------------------------------------------------------------------------------

LoadMsgsKeywordString
	DCB	"file",0
	ALIGN

; ======================================================================================================================

InitCode
	STMFD	R13!,{R14}

; Claim our workspace and store the pointer.

	MOV	R0,#6
	MOV	R3,#workspace_size%
	SWI	XOS_Module
	BVS	InitExit
	STR	R2,[R12]
	MOV	R12,R2

; Initialise the workspace that was just claimed.

	MOV	R0,#0
	STR	R0,[R12,#module_flags%]

	STR	R0,[R12,#msg_list%]

	STR	R0,[R12,#msg_file_data%]
	STR	R0,[R12,#msg_file_index%]
	STR	R0,[R12,#msg_file_len%]

; Stick the message translastion file into ResourceFS.

	ADRL	R0,file_data				; Point R0 to the file data
	SWI	XResourceFS_RegisterFiles		; Register the files

; Load the message file

	ADRL	R0,DefaultMsgFile
	BL	LoadMsgFile

; Register a general post filter to see what messages are getting passed in.

	ADRL	R0,TitleString
	ADR	R1,filter_code
	MOV	R2,R12
	MOV	R3,#0
	LDR	R4,filter_poll_mask
	SWI	XFilter_RegisterPostFilter

InitExit
	LDMFD	R13!,{PC}

; ----------------------------------------------------------------------------------------------------------------------

FinalCode
	STMFD	R13!,{R14}
	LDR	R12,[R12]

; De-register the post filter.

	ADRL	R0,TitleString
	ADR	R1,filter_code
	MOV	R2,R12
	MOV	R3,#0
	LDR	R4,filter_poll_mask
	SWI	XFilter_DeRegisterPostFilter

; Work through the apps list, freeing the workspace.

FinalFreeMsgs
	LDR	R6,[R12,#msg_list%]
	MOV	R0,#7

FinalFreeMsgsLoop
	TEQ	R6,#0
	BEQ	FinalDeregisterResFS

	MOV	R2,R6
	LDR	R6,[R6,#msg_block_next%]
	SWI	XOS_Module

	B	FinalFreeMsgsLoop

; Remove the message translation file from ResourceFS.

FinalDeregisterResFS
	ADRL	R0,file_data				; Point R0 to the file data
	SWI	XResourceFS_DeregisterFiles		; De-register the files

; Free any message tables in RMA.

	MOV	R0,#7					; OS_Module 7

FinalClrData
	LDR	R2,[R12,#msg_file_data%]
	TEQ	R2,#0
	BEQ	FinalClrIndex

	SWI	XOS_Module

FinalClrIndex
	LDR	R2,[R12,#msg_file_data%]
	TEQ	R2,#0
	BEQ	FinalReleaseWorkspace

	SWI	XOS_Module

; Free the RMA workspace

FinalReleaseWorkspace
	TEQ	R12,#0
	BEQ	FinalExit

	MOV	R0,#7
	MOV	R2,R12

	SWI	XOS_Module

FinalExit
	LDMFD	R13!,{PC}

; ----------------------------------------------------------------------------------------------------------------------

.ServiceCode
	TEQ	R1,#&60
	MOVNE	PC,R14

; Register the message translation file into ResourceFS.

	STMFD	R13!,{R0-R3,R14}
	ADRL	R0,file_data
	MOV	R14,PC
	MOV	PC,R2
	LDMFD	R13!,{R0-R3,PC}

; ----------------------------------------------------------------------------------------------------------------------

.DefaultMsgFile
	DCB	"Resources:$.ThirdParty.MsgMon.MsgList",0
	ALIGN

; ======================================================================================================================

.filter_code
          STMFD     R13!, {R0-R6,R12,R14}

; Check that the reason code is 17, 18 or 19.

          TEQ       R0,#17
          TEQNE     R0,#18
          TEQNE     R0,#19
          BNE       filter_exit

; Store some useful registers out of the way.

          MOV       R5,R1                         ; Poll block
          MOV       R4,R2                         ; Task handle
          MOV       R3,R0                         ; Reason code

; If there isn't a list of allowed messages, jump straight to the output code.

          LDR       R0,[R12,#msg_list%]
          TEQ       R0,#0
          BEQ       filter_output_data

; If there is a list of messages, check that the current one is wanted and exit if not.

          LDR       R0,[R1,#16]
          BL        find_msg_block
          TEQ       R6,#0
          BEQ       filter_exit

; Output the message number.

.filter_output_data
          ADRL      R0,filter_text_message
          ADRW      R1,block%
          BL        CopyString

          LDR       R0,[R5,#16]
          BL        convert_msg_number

          ADRL      R0,filter_text_reasonstart
          BL        CopyString

          MOV       R0,R3
          BL        convert_reason_code

          ADRL      R0,filter_text_reasonend
          BL        CopyString

          ADRW      R0,block%
          SWIVC     "XReport_Text0"

; Output the two task names.

          ADRL      R0,filter_text_from
          ADRW      R1,block%
          BL        CopyString

          LDR       R0,[R5,#4]
          SWI       "XTaskManager_TaskNameFromHandle"
          BLVC      CopyString

          ADRL      R0,filter_text_to
          BL        CopyString

          MOV       R0,R4
          SWI       "XTaskManager_TaskNameFromHandle"
          BLVC      CopyString

          ADRL      R0,filter_text_taskend
          BL        CopyString

          ADRW      R0,block%
          SWIVC     "XReport_Text0"

; Output the references

          ADRL      R0,filter_text_myref
          ADRW      R1,block%
          BL        CopyString

          LDR       R0,[R5,#8]
          MOV       R2,#16
          SWI       "XOS_ConvertHex8"

          ADRL      R0,filter_text_yourref
          BL        CopyString

          LDR       R0,[R5,#12]
          MOV       R2,#16
          SWI       "XOS_ConvertHex8"

          ADRW      R0,block%
          SWIVC     "XReport_Text0"

; Output the data contained in the message

          MOV       R4,#20
.filter_data_loop
          LDR       R3,[R5,#0]
          CMP       R4,R3
          BGE       filter_data_loop_exit

          ADRW      R1,block%                     ; Output the word number

          ADRL      R0,filter_text_linestart
          BL        CopyString

          MOV       R0,R4
          MOV       R2,#4
          SWI       "XOS_ConvertCardinal1"

          MOV       R0,#ASC(" ")
          SUB       R2,R2,#1

.filter_data_pad_loop
          TEQ       R2,#0
          BEQ       filter_data_pad_loop_exit

          STRB      R0,[R1],#1
          SUB       R2,R2,#1
          B         filter_data_pad_loop

.filter_data_pad_loop_exit

          ADRL      R0,filter_text_linesep
          BL        CopyString

          LDR       R0,[R5,R4]                    ; Output the word as hex
          MOV       R2,#16
          SWI       "XOS_ConvertHex8"

          ADRL      R0,filter_text_linesep
          BL        CopyString

          ADD       R3,R4,R5                       ; Output the word as bytes

          LDRB      R0,[R3,#0]
          CMP       R0,#32
          MOVLT     R0,#ASC(".")
          CMP       R0,#126
          MOVGT     R0,#ASC(".")
          STRB      R0,[R1],#1

          LDRB      R0,[R3,#1]
          CMP       R0,#32
          MOVLT     R0,#ASC(".")
          CMP       R0,#126
          MOVGT     R0,#ASC(".")
          STRB      R0,[R1],#1

          LDRB      R0,[R3,#2]
          CMP       R0,#32
          MOVLT     R0,#ASC(".")
          CMP       R0,#126
          MOVGT     R0,#ASC(".")
          STRB      R0,[R1],#1

          LDRB      R0,[R3,#3]
          CMP       R0,#32
          MOVLT     R0,#ASC(".")
          CMP       R0,#126
          MOVGT     R0,#ASC(".")
          STRB      R0,[R1],#1

          ADRL      R0,filter_text_linesep
          BL        CopyString

          LDR       R0,[R5,R4]                    ; Output the word as decimal
          MOV       R2,#16
          SWI       "XOS_ConvertInteger4"

          MOV       R0,#0
          STRB      R0,[R1]

          ADRW      R0,block%
          SWI       "XReport_Text0"

          ADD       R4,R4,#4
          B         filter_data_loop

; Put a space between blocks.

.filter_data_loop_exit
          ADRW      R0,block%
          MOV       R1,#0
          STR       R1,[R0]
          SWI       "XReport_Text0"

.filter_exit
          LDMFD     R13!,{R0-R6,R12,R14}
          TEQ       PC,PC
          MOVNES    PC,R14
          MSR       CPSR_f,#0
          MOV       PC,R14

; ======================================================================================================================

.filter_text_message
          EQUZ      "\C"

.filter_text_reasonstart
          EQUZ      " ["

.filter_text_reasonend
          EQUZ      "]"

.filter_text_from
          EQUZ      "From '"

.filter_text_to
          EQUZ      "' to '"

.filter_text_taskend
          EQUZ      "'"

.filter_text_myref
          EQUZ      "My ref: &"

.filter_text_yourref
          EQUZ      "; Your ref: &"

.filter_text_linestart
          EQUZ      "\b"

.filter_text_linesep
          EQUZ      " : "

.filter_poll_mask
          DCD      &FFFFFFFF EOR (1<<17 OR 1<<18 OR 1<<19)
          ALIGN

; ======================================================================================================================

.find_msg_block

; Find the block containing details of the given message.
;
; R0  =  Message Number
; R12 => Workspace
;
; R6  <= block (zero if not found)

          STMFD     R13!,{R0-R5,R14}

; Set R4 up ready for the compare subroutine.  R6 points to the first block of message data.

          LDR       R6,[R12,#msg_list%]

; If this is the end of the list (null pointer in R6), exit now.

.find_msg_loop
          TEQ       R6,#0
          BEQ       find_msg_exit

; Point R3 to the application name and compare with the name supplied.  If equal, exit now with R6 pointing to
; the data block.

          LDR       R1,[R6,#msg_block_number%]
          TEQ       R0,R1
          BEQ       find_msg_exit

; Load the next block pointer into R6 and loop.

          LDR       R6,[R6,#msg_block_next%]
          B         find_msg_loop

.find_msg_exit
          LDMFD     R13!,{R0-R5,PC}

; ======================================================================================================================

.convert_reason_code

; Convert a reason code into a textual version.
;
; R0  =  Message number
; R1  => Buffer for name
;
; R1  <= Terminating null

          STMFD     R13!,{R0,R2-R5,R14}

.convert_reason_test17
          TEQ       R0,#17
          BNE       convert_reason_test18

          ADR       R0,reason_17
          B         convert_reason_copy

.convert_reason_test18
          TEQ       R0,#18
          BNE       convert_reason_test19

          ADR       R0,reason_18
          B         convert_reason_copy

.convert_reason_test19
          TEQ       R0,#19
          BNE       convert_reason_unknown

          ADR       R0,reason_19
          B         convert_reason_copy

.convert_reason_unknown
          ADR       R0,reason_unknown

.convert_reason_copy
          BL        CopyString

.exit_convert_reason
          LDMFD     R13!,{R0,R2-R5,PC}

; ----------------------------------------------------------------------------------------------------------------------

.reason_17
          EQUZ      "Message"

.reason_18
          EQUZ      "Message Recorded"

.reason_19
          EQUZ      "Message Acknowledge"

.reason_unknown
          EQUZ      "Unknown"
          ALIGN

; ======================================================================================================================

.convert_msg_number

; Convert a message number into a textual version.
;
; R0  =  Message number
; R1  => Buffer for name
; R12 => Workspace
;
; R1  <= Terminating null

          STMFD     R13!,{R0,R2-R5,R14}

          LDR       R2,[R12,#msg_file_index%]
          LDR       R3,[R12,#msg_file_len%]

.convert_find_loop
          TEQ       R3,#0
          BEQ       convert_not_found

          LDR       R4,[R2],#4
          LDR       R5,[R4],#4
          TEQ       R5,R0
          BEQ       convert_found

          SUB       R3,R3,#1
          B         convert_find_loop

.convert_found
          MOV       R5,R0

          ADR       R0,convert_text_name_start
          BL        CopyString

          MOV       R0,R4
          BL        CopyString

          ADR       R0,convert_text_name_mid
          BL        CopyString

          MOV       R0,R5
          MOV       R2,#16
          SWI       "XOS_ConvertHex6"

          ADR       R0,convert_text_name_end
          BL        CopyString

          B         exit_convert_msg

.convert_not_found
          MOV       R5,R0

          ADR       R0,convert_text_number_start
          BL        CopyString

          MOV       R0,R5
          MOV       R2,#16
          SWI       "XOS_ConvertHex6"

.exit_convert_msg
          LDMFD     R13!,{R0,R2-R5,PC}

; ----------------------------------------------------------------------------------------------------------------------

.convert_text_number_start
          EQUZ      "Message &"

.convert_text_name_start
          EQUZ      "Message_"

.convert_text_name_mid
          EQUZ      " (&"

.convert_text_name_end
          EQUZ      ")"

          ALIGN

; ----------------------------------------------------------------------------------------------------------------------

LoadMsgFile

; Load a file of message translations into memory.
;
; R0  => Filename
; R12 => Workspace

	STMFD	R13!,{R0-R8,R14}

	MOV	R1,R0

; Clear any data currently in memory.

	MOV	R0,#7

LoadClearData
	LDR	R2,[R12,#msg_file_data%]
	TEQ	R2,#0
	BEQ	LoadClearIndex

	SWI	XOS_Module

LoadClearIndex
	LDR	R2,[R12,#msg_file_data%]
	TEQ	R2,#0
	BEQ	LoadClearPtrs

	SWI	XOS_Module

LoadClearPtrs
	MOV	R2,#0
	STR	R2,[R12,#msg_file_data%]
	STR	R2,[R12,#msg_file_index%]
	STR	R2,[R12,#msg_file_len%]

; Get the length of the file, and claim memory from the RMA to hold the lot.

	MOV	R0,#17
	SWI	XOS_File
	BVS	LoadMsgFileExit

	MOV	R0,#6
	MOV	R3,R4,ASL #2				; Double the file size to be safe
	SWI	XOS_Module
	BVS	LoadMsgFileExit

	STR	R2,[R12,#msg_file_data%]
	MOV	R7,R2					; Block start ptr
	ADD	R8,R7,R4				; Block end ptr

; Try and open the file, leaving the file handle in R1.

LoadOpenFile
	MOV	R0,#&43
	SWI	XOS_Find
	BVS	LoadMsgFileExit

	TEQ	R0,#0
	BEQ	LoadMsgFileExit

	MOV	R1,R0					; File handle
	MOV	R6,R7					; Main load ptr
	MOV	R5,#0					; Message counter

; Now read the file in line by line.  We assume the format
;
; &XXXXX<tab>Message_Name<lf>

LoadOuterReadLoop
	MOV	R3,R6					; Copy of load Ptr

	; Start by reading in the message number, up to the tab.

LoadReadNumLoop
	SWI	OS_BGet
	BCS	LoadOuterLoopExit

	TEQ	R0,#9
	BEQ	LoadReadNumLoopExit

	STRB	R0,[R3],#1
	B	LoadReadNumLoop

	; Terminate the number string, and convert it into an integer.  Store that integer over the start
	; of the string.

LoadReadNumLoopExit
	MOV	R0,#0
	STRB	R0,[R3]

	MOV	R4,R1
	MOV	R0,#10
	MOV	R1,R6
	SWI	XOS_ReadUnsigned
	STR	R2,[R6],#4

	MOV	R1,R4

	; Read in the message name, following on from the integer.

LoadReadStrLoop
	SWI	OS_BGet
	BCS	LoadReadStrLoopExit

	CMP	R0,#32
	BLT	LoadReadStrLoopExit

	STRB	R0,[R6],#1
	B	LoadReadStrLoop

	; Terminate the message string, and repeat until we finish with CS.

LoadReadStrLoopExit
	MOV	R0,#0
	STRB	R0,[R6],#1

	ADD	R6,R6,#3
	BIC	R6,R6,#3

	ADD	R5,R5,#1

	BCC	LoadOuterReadLoop

LoadOuterLoopExit
	STR	R5,[R12,#msg_file_len%]

; Close the file.

LoadCloseFile
	MOV	R0,#0
	SWI	OS_Find

; Shrink the RMA allocation down to that required.

	MOV	R0,#13
	MOV	R2,R7
	SUB	R3,R6,R8
	SWI	XOS_Module
	BVS	LoadMsgFileExit

	STR	R2,[R12,#msg_file_data%]
	MOV	R7,R2

; Claim memory for the index.

	MOV	R0,#6
	MOV	R3,R5,ASL #2
	SWI	XOS_Module
	BVS	LoadMsgFileExit

	STR	R2,[R12,#msg_file_index%]

; Populate the index of messages.

	MOV	R0,R7
	MOV	R1,#0

LoadIndexLoop
	CMP	R1,R5
	BGE	LoadMsgFileExit

	STR	R0,[R2,R1,ASL #2]

	ADD	R0,R0,#4
	ADD	R1,R1,#1

LoadIndexSkip
	LDRB	R4,[R0],#1
	TEQ	R4,#0
	BNE	LoadIndexSkip

	ADD	R0,R0,#3
	BIC	R0,R0,#3

	B	LoadIndexLoop

LoadMsgFileExit
	LDMFD	R13!,{R0-R8,R14}
	TEQ	PC,PC
	MOVNES	PC,R14
	MSR	CPSR_f,#0
	MOV	PC,R14

; ======================================================================================================================

.CopyString

; Copy a null- or LF-terminated string.
;
; R0 => Source
; R1 => Destination
;
; R1 <= Copied terminator

	STMFD	R13!,{R0,R2,R14}

.CopyStringLoop
	LDRB	R2,[R0],#1
	STRB	R2,[R1],#1

	TEQ	R2,#0
	TEQNE	R2,#10
	BNE	CopyStringLoop

	SUB	R1,R1,#1

	LDMFD	R13!,{R0,R2,PC}

; ======================================================================================================================
; Message file data
;
; This is the default message translation file, which is lodged into ResourceFS for us to load.

.file_data
          DCD      file_block_end-file_data
          DCD      &FFFFFF00 OR time%?4
          DCD      !time%
          DCD      file_end-file_start
          DCD      %00011001
          EQUZ      "ThirdParty.MsgMon.MsgList"
          ALIGN
          DCD      (file_end-file_start)+4

.file_start
          DCB      "&0"+CHR$(9)+"Quit"+CHR$(10)
          DCB      "&1"+CHR$(9)+"DataSave"+CHR$(10)
          DCB      "&2"+CHR$(9)+"DataSaveAck"+CHR$(10)
          DCB      "&3"+CHR$(9)+"DataLoad"+CHR$(10)
          DCB      "&4"+CHR$(9)+"DataLoadAck"+CHR$(10)
          DCB      "&5"+CHR$(9)+"DataOpen"+CHR$(10)
          DCB      "&6"+CHR$(9)+"RAMFetch"+CHR$(10)
          DCB      "&7"+CHR$(9)+"RAMTransmit"+CHR$(10)
          DCB      "&D"+CHR$(9)+"DataSaved"+CHR$(10)
          DCB      "&8"+CHR$(9)+"PreQuit"+CHR$(10)
          DCB      "&9"+CHR$(9)+"PaletteChange"+CHR$(10)
          DCB      "&A"+CHR$(9)+"SaveDesktop"+CHR$(10)
          DCB      "&B"+CHR$(9)+"DeviceClaim"+CHR$(10)
          DCB      "&C"+CHR$(9)+"DeviceInUse"+CHR$(10)
          DCB      "&E"+CHR$(9)+"Shutdown"+CHR$(10)
          DCB      "&F"+CHR$(9)+"ClaimEntity"+CHR$(10)
          DCB      "&10"+CHR$(9)+"DataRequest"+CHR$(10)
          DCB      "&11"+CHR$(9)+"Dragging"+CHR$(10)
          DCB      "&12"+CHR$(9)+"DragClaim"+CHR$(10)
          DCB      "&13"+CHR$(9)+"ReleaseEntity"+CHR$(10)
          DCB      "&15"+CHR$(9)+"AppControl"+CHR$(10)
          DCB      "&400"+CHR$(9)+"FilerOpenDir"+CHR$(10)
          DCB      "&401"+CHR$(9)+"FilerCloseDir"+CHR$(10)
          DCB      "&402"+CHR$(9)+"FilerOpenDirAt"+CHR$(10)
          DCB      "&403"+CHR$(9)+"FilerSelectionDirectory"+CHR$(10)
          DCB      "&404"+CHR$(9)+"FilerAddSelection"+CHR$(10)
          DCB      "&405"+CHR$(9)+"FilerAction"+CHR$(10)
          DCB      "&406"+CHR$(9)+"FilerControlAction"+CHR$(10)
          DCB      "&407"+CHR$(9)+"FilerSelection"+CHR$(10)
          DCB      "&500"+CHR$(9)+"AlarmSet"+CHR$(10)
          DCB      "&501"+CHR$(9)+"AlarmGoneOff"+CHR$(10)
          DCB      "&502"+CHR$(9)+"HelpRequest"+CHR$(10)
          DCB      "&503"+CHR$(9)+"HelpReply"+CHR$(10)
          DCB      "&504"+CHR$(9)+"HelpEnable"+CHR$(10)
          DCB      "&40040"+CHR$(9)+"Notify"+CHR$(10)
          DCB      "&400C0"+CHR$(9)+"MenuWarning"+CHR$(10)
          DCB      "&400C1"+CHR$(9)+"ModeChange"+CHR$(10)
          DCB      "&400C2"+CHR$(9)+"TaskInitialise"+CHR$(10)
          DCB      "&400C3"+CHR$(9)+"TaskCloseDown"+CHR$(10)
          DCB      "&400C4"+CHR$(9)+"SlotSize"+CHR$(10)
          DCB      "&400C5"+CHR$(9)+"SetSlot"+CHR$(10)
          DCB      "&400C6"+CHR$(9)+"TaskNameRq"+CHR$(10)
          DCB      "&400C7"+CHR$(9)+"TaskNameIs"+CHR$(10)
          DCB      "&400C8"+CHR$(9)+"TaskStarted"+CHR$(10)
          DCB      "&400C9"+CHR$(9)+"MenusDeleted"+CHR$(10)
          DCB      "&400CA"+CHR$(9)+"Iconize"+CHR$(10)
          DCB      "&400CB"+CHR$(9)+"WindowClosed"+CHR$(10)
          DCB      "&400CC"+CHR$(9)+"WindowInfo"+CHR$(10)
          DCB      "&400CD"+CHR$(9)+"Swap"+CHR$(10)
          DCB      "&400CE"+CHR$(9)+"ToolsChanged"+CHR$(10)
          DCB      "&400CF"+CHR$(9)+"FontChanged"+CHR$(10)
          DCB      "&400D0"+CHR$(9)+"IconizeAt"+CHR$(10)
          DCB      "&47700"+CHR$(9)+"ColourChoice"+CHR$(10)
          DCB      "&47701"+CHR$(9)+"ColourChanged"+CHR$(10)
          DCB      "&47702"+CHR$(9)+"CloseRequest"+CHR$(10)
          DCB      "&47703"+CHR$(9)+"OpenParent"+CHR$(10)
          DCB      "&4D540"+CHR$(9)+"PlugIn_Open"+CHR$(10)
          DCB      "&4D541"+CHR$(9)+"PlugIn_Opening"+CHR$(10)
          DCB      "&4D542"+CHR$(9)+"PlugIn_Close"+CHR$(10)
          DCB      "&4D543"+CHR$(9)+"PlugIn_Closed"+CHR$(10)
          DCB      "&4D544"+CHR$(9)+"PlugIn_Reshape"+CHR$(10)
          DCB      "&4D545"+CHR$(9)+"PlugIn_Reshape_Request"+CHR$(10)
          DCB      "&4D546"+CHR$(9)+"PlugIn_Focus"+CHR$(10)
          DCB      "&4D547"+CHR$(9)+"PlugIn_Unlock"+CHR$(10)
          DCB      "&4D548"+CHR$(9)+"PlugIn_StreamNew"+CHR$(10)
          DCB      "&4D549"+CHR$(9)+"PlugIn_StreamDestroy"+CHR$(10)
          DCB      "&4D54A"+CHR$(9)+"PlugIn_StreamWrite"+CHR$(10)
          DCB      "&4D54B"+CHR$(9)+"PlugIn_StreamWritten"+CHR$(10)
          DCB      "&4D54C"+CHR$(9)+"PlugIn_StreamAsFile"+CHR$(10)
          DCB      "&4D54D"+CHR$(9)+"PlugIn_URLAccess"+CHR$(10)
          DCB      "&4D54E"+CHR$(9)+"PlugIn_Notify"+CHR$(10)
          DCB      "&4D54F"+CHR$(9)+"PlugIn_Status"+CHR$(10)
          DCB      "&4D550"+CHR$(9)+"PlugIn_Busy"+CHR$(10)
          DCB      "&4D551"+CHR$(9)+"PlugIn_Action"+CHR$(10)
          DCB      "&4D552"+CHR$(9)+"PlugIn_Abort"+CHR$(10)
          DCB      "&42580"+CHR$(9)+"ThrowbackStart"+CHR$(10)
          DCB      "&42581"+CHR$(9)+"ProcessingFile"+CHR$(10)
          DCB      "&42582"+CHR$(9)+"ErrorsIn"+CHR$(10)
          DCB      "&42583"+CHR$(9)+"ErrorDetails"+CHR$(10)
          DCB      "&42584"+CHR$(9)+"ThrowbackEnd"+CHR$(10)
          DCB      "&42585"+CHR$(9)+"InfoForFile"+CHR$(10)
          DCB      "&42586"+CHR$(9)+"InfoDetails"+CHR$(10)
          DCB      "&808C0"+CHR$(9)+"TW_Input"+CHR$(10)
          DCB      "&808C1"+CHR$(9)+"TW_Output"+CHR$(10)
          DCB      "&808C2"+CHR$(9)+"TW_Ego"+CHR$(10)
          DCB      "&808C3"+CHR$(9)+"TW_Morio"+CHR$(10)
          DCB      "&808C4"+CHR$(9)+"TW_Morite"+CHR$(10)
          DCB      "&808C5"+CHR$(9)+"TW_NewTask"+CHR$(10)
          DCB      "&808C6"+CHR$(9)+"TW_Suspend"+CHR$(10)
          DCB      "&808C7"+CHR$(9)+"TW_Resume"+CHR$(10)
          DCB      "&80140"+CHR$(9)+"PrintFile"+CHR$(10)
          DCB      "&80141"+CHR$(9)+"WillPrint"+CHR$(10)
          DCB      "&80142"+CHR$(9)+"PrintSave"+CHR$(10)
          DCB      "&80143"+CHR$(9)+"PrintInit"+CHR$(10)
          DCB      "&80144"+CHR$(9)+"PrintError"+CHR$(10)
          DCB      "&80145"+CHR$(9)+"PrintTypeOdd"+CHR$(10)
          DCB      "&80146"+CHR$(9)+"PrintTypeKnown"+CHR$(10)
          DCB      "&80147"+CHR$(9)+"SetPrinter"+CHR$(10)
          DCB      "&8014C"+CHR$(9)+"PSPrinterQuery"+CHR$(10)
          DCB      "&8014D"+CHR$(9)+"PSPrinterAck"+CHR$(10)
          DCB      "&8014E"+CHR$(9)+"PSPrinterModified"+CHR$(10)
          DCB      "&8014F"+CHR$(9)+"PSPrinterDefaults"+CHR$(10)
          DCB      "&80150"+CHR$(9)+"PSPrinterDefaulted"+CHR$(10)
          DCB      "&80151"+CHR$(9)+"PSPrinterNotPS"+CHR$(10)
          DCB      "&80152"+CHR$(9)+"ResetPrinter"+CHR$(10)
          DCB      "&80153"+CHR$(9)+"PSIsFontPrintRunning"+CHR$(10)
          DCB      "&81400"+CHR$(9)+"DDE_ToolInfo"+CHR$(10)
          DCB      "&4E380"+CHR$(9)+"URI_MStarted"+CHR$(10)
          DCB      "&4E381"+CHR$(9)+"URI_MDying"+CHR$(10)
          DCB      "&4E382"+CHR$(9)+"URI_MProcess"+CHR$(10)
          DCB      "&4E383"+CHR$(9)+"URI_MReturnResult"+CHR$(10)
          DCB      "&4E384"+CHR$(9)+"URI_MProcessAck"+CHR$(10)
          DCB      "&45D80"+CHR$(9)+"EditRq"+CHR$(10)
          DCB      "&45D81"+CHR$(9)+"EditAck"+CHR$(10)
          DCB      "&45D82"+CHR$(9)+"EditReturn"+CHR$(10)
          DCB      "&45D83"+CHR$(9)+"EditAbort"+CHR$(10)
          DCB      "&45D84"+CHR$(9)+"EditDataSave"+CHR$(10)
          DCB      "&45D85"+CHR$(9)+"EditCursor"+CHR$(10)
          DCB      "&80E1E"+CHR$(9)+"OLE_FileChanged"+CHR$(10)
          DCB      "&80E21"+CHR$(9)+"OLE_OpenSession"+CHR$(10)
          DCB      "&80E22"+CHR$(9)+"OLE_OpenSessionAck"+CHR$(10)
          DCB      "&80E23"+CHR$(9)+"OLE_CloseSession"+CHR$(10)
          DCB      "&83580"+CHR$(9)+"NewsBase_Command"+CHR$(10)
          DCB      "&83581"+CHR$(9)+"NewsBase_Reply"+CHR$(10)
          DCB      "&83582"+CHR$(9)+"NewsBase_Update"+CHR$(10)
          DCB      "&DAB00"+CHR$(9)+"IRC_SendData"+CHR$(10)
          DCB      "&DAB01"+CHR$(9)+"IRC_SendRawData"+CHR$(10)
          DCB      "&46005"+CHR$(9)+"ANT_SendAction"+CHR$(10)
          DCB      "&4A43B"+CHR$(9)+"PopupHelp_SendHelp"+CHR$(10)
          DCB      "&4A43C"+CHR$(9)+"PopupHelp_RequestHelp"+CHR$(10)
          DCB      "&825C0"+CHR$(9)+"UtilDeclare"+CHR$(10)
          DCB      "&825C1"+CHR$(9)+"UtilOpen"+CHR$(10)
          DCB      "&825C2"+CHR$(9)+"UtilQuitting"+CHR$(10)
          DCB      "&825C3"+CHR$(9)+"UtilReside"+CHR$(10)
          DCB      "&825C4"+CHR$(9)+"UtilLoadAck"+CHR$(10)
          DCB      "&450C0"+CHR$(9)+"Connect"+CHR$(10)
          DCB      "&4AF80"+CHR$(9)+"OpenURL"+CHR$(10)
          DCB      "&4AF81"+CHR$(9)+"HotlistAddURL"+CHR$(10)
          DCB      "&4AF82"+CHR$(9)+"HotlistChanged"+CHR$(10)
          DCB      "&4AF83"+CHR$(9)+"HotlistDelURL"+CHR$(10)
          DCB      "&4AF87"+CHR$(9)+"HotlistShow"+CHR$(10)
          DCB      "&4AF88"+CHR$(9)+"HotlistUser"+CHR$(10)
.file_end
          ALIGN
.file_block_end
          DCD      0
]
IF debug% THEN
[OPT pass%
          FNReportGen
]
ENDIF
NEXT pass%

SYS "OS_File",10,"<Basic$Dir>."+save_as$,&FFA,,code%,code%+P%

PRINT "Module size: ";P%;" bytes."

END



DEF FNworkspace(RETURN size%,dim%)
LOCAL ptr%
ptr%=size%
size%+=dim%
=ptr%
