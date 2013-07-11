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


XOS_Module				EQU	&02001E
XOS_ReadUnsigned			EQU	&020021
OS_ReadArgs				EQU	&000049; Should be XO
OS_PrettyPrint				EQU	&000044
OS_NewLine				EQU	&000003
OS_Write0				EQU	&000002
XResourceFS_RegisterFiles		EQU	&061B40
XResourceFS_DeregisterFiles		EQU	&061B41
XFilter_RegisterPostFilter		EQU	&062641
XFilter_DeRegisterPostFilter		EQU	&062643
XOS_Find				EQU	&02000D
XOS_File				EQU	&020008
OS_BGet					EQU	&00000A	; Should be X
XOS_ConvertHex6				EQU	&0200D3
XOS_ConvertHex8				EQU	&0200D4
XOS_ConvertCardinal1			EQU	&0200D5
XOS_ConvertInteger4			EQU	&0200DC
XReport_Text0				EQU	&074C80
XTaskManager_TaskNameFromHandle		EQU	&062680

; workspace_target%=&600
; workspace_size%=0 : REM This is updated.
; block_size%=256

; ---------------------------------------------------------------------------------------------------------------------
; Set up the Module Workspace

BlockSize		*	256

			^	0
WS_ModuleFlags		#	4	; \TODO -- Not sure if we use this?
WS_MsgList		#	4
WS_MsgFileData		#	4
WS_MsgFileIndex		#	4
WS_MsgFileLength	#	4
WS_Block		#	BlockSize

WS_Size			*	&600	; @

; PRINT'"Stack size:  ";workspace_target%-workspace_size%;" bytes."
; stack%=FNworkspace(workspace_size%,workspace_target%-workspace_size%)

; ---------------------------------------------------------------------------------------------------------------------
; Set up the Message List Block Template

			^	0
MsgBlock_MagicWord	#	4
MsgBlock_Next		#	4
MsgBlock_Dim		#	4	; \TODO -- Not sure if we use this?
MsgBlock_Number		#	4

MsgBlock_Size		*	@




;REM --------------------------------------------------------------------------------------------------------------------
;
;DIM time% 5, date% 256
;?time%=3
;SYS "OS_Word",14,time%
;SYS "Territory_ConvertDateAndTime",-1,time%,date%,255,"(%dy %m3 %ce%yr)" TO ,date_end%
;?date_end%=13

;REM --------------------------------------------------------------------------------------------------------------------


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
	BL	FindMsgBlock
	TEQ	R6,#0
	BNE	AddMsgExit

	MOV	R6,R0					; Keep the message number somewhere safe

; Claim a block from the RMA to store the message details.

AddMsgClaimBlock
	MOV	R0,#6
	MOV	R3,#MsgBlock_Size
	SWI	XOS_Module
	BVS	AddMsgExit

; Initialise the details.

AddMsgFillBlock
	LDR	R0,MagicWord				; Magic word to check block identity.
	STR	R0,[R2,#MsgBlock_MagicWord]
	STR	R3,[R2,#MsgBlock_Dim]			; Block size.
	STR	R6,[R2,#MsgBlock_Number]		; Point to the start of the namespace...

; Link the block into the message list.

AddMsgLinkIn
	LDR	R5,[R12,#WS_MsgList]
	STR	R5,[R2,#MsgBlock_Next]
	STR	R2,[R12,#WS_MsgList]

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
	BL	FindMsgBlock
	TEQ	R6,#0
	BEQ	RemMsgExit

; Find the message block in the linked list and remove it.

RemMsgStartMsgSearch
	ADD	R0,R12,#WS_MsgList

RemMsgFindMsgLoop
	LDR	R1,[R0]

	TEQ	R1,R6
	BEQ	RemMsgFoundMsg

	ADD	R0,R1,#MsgBlock_Next
	B	RemMsgFindMsgLoop

RemMsgFoundMsg
	LDR	R1,[R6,#MsgBlock_Next]
	STR	R1,[R0]

	MOV	R0,#7
	MOV	R2,R6
	SWI	XOS_Module

	B	RemMsgExit

; Remove all the messages.

RemMsgAll
	LDR	R6,[R12,#WS_MsgList]
	TEQ	R6,#0
	BEQ	RemMsgExit

	MOV	R4,#0
	STR	R4,[R12,#WS_MsgList]

RemMsgAllLoop
	LDR	R5,[R6,#MsgBlock_Next]

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

	LDR	R6,[R12,#WS_MsgList]
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
	LDR	R0,[R6,#MsgBlock_Number]
	ADD	R1,R12,#WS_Block
	BL	ConvertMsgNumber

	ADD	R0,R12,#WS_Block
	SWI	OS_Write0

; End off with a new line.

ListMsgsPrintEOL
	SWI	OS_NewLine

; Get the next message data block and loop.

	LDR	R6,[R6,#MsgBlock_Next]

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
	DCB	"All messages are being reported.",0

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
	MOV	R3,#WS_Size
	SWI	XOS_Module
	BVS	InitExit
	STR	R2,[R12]
	MOV	R12,R2

; Initialise the workspace that was just claimed.

	MOV	R0,#0
	STR	R0,[R12,#WS_ModuleFlags]

	STR	R0,[R12,#WS_MsgList]

	STR	R0,[R12,#WS_MsgFileData]
	STR	R0,[R12,#WS_MsgFileIndex]
	STR	R0,[R12,#WS_MsgFileLength]

; Stick the message translastion file into ResourceFS.

	ADRL	R0,FileData				; Point R0 to the file data
	SWI	XResourceFS_RegisterFiles		; Register the files

; Load the message file

	ADRL	R0,DefaultMsgFile
	BL	LoadMsgFile

; Register a general post filter to see what messages are getting passed in.

	ADRL	R0,TitleString
	ADR	R1,FilterCode
	MOV	R2,R12
	MOV	R3,#0
	LDR	R4,FilterPollMask
	SWI	XFilter_RegisterPostFilter

InitExit
	LDMFD	R13!,{PC}

; ----------------------------------------------------------------------------------------------------------------------

FinalCode
	STMFD	R13!,{R14}
	LDR	R12,[R12]

; De-register the post filter.

	ADRL	R0,TitleString
	ADR	R1,FilterCode
	MOV	R2,R12
	MOV	R3,#0
	LDR	R4,FilterPollMask
	SWI	XFilter_DeRegisterPostFilter

; Work through the apps list, freeing the workspace.

FinalFreeMsgs
	LDR	R6,[R12,#WS_MsgList]
	MOV	R0,#7

FinalFreeMsgsLoop
	TEQ	R6,#0
	BEQ	FinalDeregisterResFS

	MOV	R2,R6
	LDR	R6,[R6,#MsgBlock_Next]
	SWI	XOS_Module

	B	FinalFreeMsgsLoop

; Remove the message translation file from ResourceFS.

FinalDeregisterResFS
	ADRL	R0,FileData				; Point R0 to the file data
	SWI	XResourceFS_DeregisterFiles		; De-register the files

; Free any message tables in RMA.

	MOV	R0,#7					; OS_Module 7

FinalClrData
	LDR	R2,[R12,#WS_MsgFileData]
	TEQ	R2,#0
	BEQ	FinalClrIndex

	SWI	XOS_Module

FinalClrIndex
	LDR	R2,[R12,#WS_MsgFileData]
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

ServiceCode
	TEQ	R1,#&60
	MOVNE	PC,R14

; Register the message translation file into ResourceFS.

	STMFD	R13!,{R0-R3,R14}
	ADRL	R0,FileData
	MOV	R14,PC
	MOV	PC,R2
	LDMFD	R13!,{R0-R3,PC}

; ----------------------------------------------------------------------------------------------------------------------

DefaultMsgFile
	DCB	"Resources:$$.ThirdParty.MsgMon.MsgList",0
	ALIGN

; ======================================================================================================================

FilterCode
	STMFD	R13!, {R0-R6,R12,R14}

; Check that the reason code is 17, 18 or 19.

	TEQ	R0,#17
	TEQNE	R0,#18
	TEQNE	R0,#19
	BNE	FilterExit

; Store some useful registers out of the way.

	MOV	R5,R1					; Poll block
	MOV	R4,R2					; Task handle
	MOV	R3,R0					; Reason code

; If there isn't a list of allowed messages, jump straight to the output code.

	LDR	R0,[R12,#WS_MsgList]
	TEQ	R0,#0
	BEQ	FilterOutputData

; If there is a list of messages, check that the current one is wanted and exit if not.

	LDR	R0,[R1,#16]
	BL	FindMsgBlock
	TEQ	R6,#0
	BEQ	FilterExit

; Output the message number.

FilterOutputData
	ADRL	R0,FilterTextMessageStart
	ADD	R1,R12,#WS_Block
	BL	CopyString

	LDR	R0,[R5,#16]
	BL	ConvertMsgNumber

	ADRL	R0,FilterTextReasonStart
	BL	CopyString

	MOV	R0,R3
	BL	ConvertReasonCode

	ADRL	R0,FilterTextReasonEnd
	BL	CopyString

	ADD	R0,R12,#WS_Block
	SWIVC	XReport_Text0

; Output the two task names.

	ADRL	R0,FilterTextFrom
	ADD	R1,R12,#WS_Block
	BL	CopyString

	LDR	R0,[R5,#4]
	SWI	XTaskManager_TaskNameFromHandle
	BLVC	CopyString

	ADRL	R0,FilterTextTo
	BL	CopyString

	MOV	R0,R4
	SWI	XTaskManager_TaskNameFromHandle
	BLVC	CopyString

	ADRL	R0,FilterTextTaskEnd
	BL	CopyString

	ADD	R0,R12,#WS_Block
	SWIVC	XReport_Text0

; Output the references

	ADRL	R0,FilterTextMyRef
	ADD	R1,R12,#WS_Block
	BL	CopyString

	LDR	R0,[R5,#8]
	MOV	R2,#16
	SWI	XOS_ConvertHex8

	ADRL	R0,FilterTextYourRef
	BL	CopyString

	LDR	R0,[R5,#12]
	MOV	R2,#16
	SWI	XOS_ConvertHex8

	ADD	R0,R12,#WS_Block
	SWIVC	XReport_Text0

; Output the data contained in the message

	MOV	R4,#20
FilterDataLoop
	LDR	R3,[R5,#0]
	CMP	R4,R3
	BGE	FilterDataLoopExit

	ADD	R1,R12,#WS_Block				; Output the word number

	ADRL	R0,FilterTextLineStart
	BL	CopyString

	MOV	R0,R4
	MOV	R2,#4
	SWI	XOS_ConvertCardinal1

	MOV	R0,#32	; ASC(" ")
	SUB	R2,R2,#1

FilterDataPadLoop
	TEQ	R2,#0
	BEQ	FilterDataPadLoopExit

	STRB	R0,[R1],#1
	SUB	R2,R2,#1
	B	FilterDataPadLoop

FilterDataPadLoopExit
	ADRL	R0,FilterTextLineSep
	BL	CopyString

	LDR	R0,[R5,R4]				; Output the word as hex
	MOV	R2,#16
	SWI	XOS_ConvertHex8

	ADRL	R0,FilterTextLineSep
	BL	CopyString

	ADD	R3,R4,R5				; Output the word as bytes

	LDRB	R0,[R3,#0]
	CMP	R0,#32
	MOVLT	R0,#46	; ASC(".")
	CMP	R0,#126
	MOVGT	R0,#46	; ASC(".")
	STRB	R0,[R1],#1

	LDRB	R0,[R3,#1]
	CMP	R0,#32
	MOVLT	R0,#46	; ASC(".")
	CMP	R0,#126
	MOVGT	R0,#46	; ASC(".")
	STRB	R0,[R1],#1

	LDRB	R0,[R3,#2]
	CMP	R0,#32
	MOVLT	R0,#46	; ASC(".")
	CMP	R0,#126
	MOVGT	R0,#46	; ASC(".")
	STRB	R0,[R1],#1

	LDRB	R0,[R3,#3]
	CMP	R0,#32
	MOVLT	R0,#46	; ASC(".")
	CMP	R0,#126
	MOVGT	R0,#46	; ASC(".")
	STRB	R0,[R1],#1

	ADRL	R0,FilterTextLineSep
	BL	CopyString

	LDR	R0,[R5,R4]				; Output the word as decimal
	MOV	R2,#16
	SWI	XOS_ConvertInteger4

	MOV	R0,#0
	STRB	R0,[R1]

	ADD	R0,R12,#WS_Block
	SWI	XReport_Text0

	ADD	R4,R4,#4
	B	FilterDataLoop

; Put a space between blocks.

FilterDataLoopExit
	ADD	R0,R12,#WS_Block
	MOV	R1,#0
	STR	R1,[R0]
	SWI	XReport_Text0

FilterExit
	LDMFD	R13!,{R0-R6,R12,R14}
	TEQ	PC,PC
	MOVNES	PC,R14
	MSR	CPSR_f,#0
	MOV	PC,R14

; ======================================================================================================================

FilterTextMessageStart
	DCB	"\\C",0

FilterTextReasonStart
	DCB	" [",0

FilterTextReasonEnd
	DCB	"]",0

FilterTextFrom
	DCB	"From '",0

FilterTextTo
	DCB	"' to '",0

FilterTextTaskEnd
	DCB	"'",0

FilterTextMyRef
	DCB	"My ref: &",0

FilterTextYourRef
	DCB	"; Your ref: &",0

FilterTextLineStart
	DCB	"\b",0

FilterTextLineSep
	DCB	" : ",0
	ALIGN

FilterPollMask
	DCD	&FFFFFFFF:EOR:((1:SHL:17):OR:(1:SHL:18):OR:(1:SHL:19))
	ALIGN

; ======================================================================================================================

FindMsgBlock

; Find the block containing details of the given message.
;
; R0  =  Message Number
; R12 => Workspace
;
; R6  <= block (zero if not found)

	STMFD	R13!,{R0-R5,R14}

; Set R4 up ready for the compare subroutine.  R6 points to the first block of message data.

	LDR	R6,[R12,#WS_MsgList]

; If this is the end of the list (null pointer in R6), exit now.

FindMsgLoop
	TEQ	R6,#0
	BEQ	FindMsgExit

; Point R3 to the application name and compare with the name supplied.  If equal, exit now with R6 pointing to
; the data block.

	LDR	R1,[R6,#MsgBlock_Number]
	TEQ	R0,R1
	BEQ	FindMsgExit

; Load the next block pointer into R6 and loop.

	LDR	R6,[R6,#MsgBlock_Next]
	B	FindMsgLoop

FindMsgExit
	LDMFD	R13!,{R0-R5,PC}

; ======================================================================================================================

ConvertReasonCode

; Convert a reason code into a textual version.
;
; R0  =  Message number
; R1  => Buffer for name
;
; R1  <= Terminating null

	STMFD	R13!,{R0,R2-R5,R14}

ConvertReasonTest17
	TEQ	R0,#17
	BNE	ConvertReasonTest18

	ADR	R0,ConvertReason17
	B	ConvertReasonCopy

ConvertReasonTest18
	TEQ	R0,#18
	BNE	ConvertReasonTest19

	ADR	R0,ConvertReason18
	B	ConvertReasonCopy

ConvertReasonTest19
	TEQ	R0,#19
	BNE	ConvertReasonUnknown

	ADR	R0,ConvertReason19
	B	ConvertReasonCopy

ConvertReasonUnknown
	ADR	R0,ConvertUnknown

ConvertReasonCopy
	BL	CopyString

ConvertReasonExit
	LDMFD	R13!,{R0,R2-R5,PC}

; ----------------------------------------------------------------------------------------------------------------------

ConvertReason17
	DCB	"Message",0

ConvertReason18
	DCB	"Message Recorded",0

ConvertReason19
	DCB	"Message Acknowledge",0

ConvertUnknown
	DCB	"Unknown",0
	ALIGN

; ======================================================================================================================

ConvertMsgNumber

; Convert a message number into a textual version.
;
; R0  =  Message number
; R1  => Buffer for name
; R12 => Workspace
;
; R1  <= Terminating null

	STMFD	R13!,{R0,R2-R5,R14}

	LDR	R2,[R12,#WS_MsgFileIndex]
	LDR	R3,[R12,#WS_MsgFileLength]

ConvertFindLoop
	TEQ	R3,#0
	BEQ	ConvertNotFound

	LDR	R4,[R2],#4
	LDR	R5,[R4],#4
	TEQ	R5,R0
	BEQ	ConvertFound

	SUB	R3,R3,#1
	B	ConvertFindLoop

ConvertFound
	MOV	R5,R0

	ADR	R0,ConvertTextNameStart
	BL	CopyString

	MOV	R0,R4
	BL	CopyString

	ADR	R0,ConvertTextNameMid
	BL	CopyString

	MOV	R0,R5
	MOV	R2,#16
	SWI	XOS_ConvertHex6

	ADR	R0,ConvertTextNameEnd
	BL	CopyString

	B	ConvertExit

ConvertNotFound
	MOV	R5,R0

	ADR	R0,ConvertTextNumberStart
	BL	CopyString

	MOV	R0,R5
	MOV	R2,#16
	SWI	XOS_ConvertHex6

ConvertExit
	LDMFD	R13!,{R0,R2-R5,PC}

; ----------------------------------------------------------------------------------------------------------------------

ConvertTextNumberStart
	DCB	"Message &",0

ConvertTextNameStart
	DCB	"Message_",0

ConvertTextNameMid
	DCB	" (&",0

ConvertTextNameEnd
	DCB	")",0

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
	LDR	R2,[R12,#WS_MsgFileData]
	TEQ	R2,#0
	BEQ	LoadClearIndex

	SWI	XOS_Module

LoadClearIndex
	LDR	R2,[R12,#WS_MsgFileData]
	TEQ	R2,#0
	BEQ	LoadClearPtrs

	SWI	XOS_Module

LoadClearPtrs
	MOV	R2,#0
	STR	R2,[R12,#WS_MsgFileData]
	STR	R2,[R12,#WS_MsgFileIndex]
	STR	R2,[R12,#WS_MsgFileLength]

; Get the length of the file, and claim memory from the RMA to hold the lot.

	MOV	R0,#17
	SWI	XOS_File
	BVS	LoadMsgFileExit

	MOV	R0,#6
	MOV	R3,R4,ASL #2				; Double the file size to be safe
	SWI	XOS_Module
	BVS	LoadMsgFileExit

	STR	R2,[R12,#WS_MsgFileData]
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
	STR	R5,[R12,#WS_MsgFileLength]

; Close the file.

LoadCloseFile
	MOV	R0,#0
	SWI	XOS_Find

; Shrink the RMA allocation down to that required.

	MOV	R0,#13
	MOV	R2,R7
	SUB	R3,R6,R8
	SWI	XOS_Module
	BVS	LoadMsgFileExit

	STR	R2,[R12,#WS_MsgFileData]
	MOV	R7,R2

; Claim memory for the index.

	MOV	R0,#6
	MOV	R3,R5,ASL #2
	SWI	XOS_Module
	BVS	LoadMsgFileExit

	STR	R2,[R12,#WS_MsgFileIndex]

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

CopyString

; Copy a null- or LF-terminated string.
;
; R0 => Source
; R1 => Destination
;
; R1 <= Copied terminator

	STMFD	R13!,{R0,R2,R14}

CopyStringLoop
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

FileData
	DCD	FileBlockEnd - FileData
	DCD	$LoadAddr
	DCD	$ExecAddr
	DCD	FileEnd - FileStart
	DCD	2_00011001
	DCB	"ThirdParty.MsgMon.MsgList",0
	ALIGN
	DCD	(FileEnd - FileStart) + 4

FileStart
	DCB	"&0",9,		"Quit",10
	DCB	"&1",9,		"DataSave",10
	DCB	"&2",9,		"DataSaveAck",10
	DCB	"&3",9,		"DataLoad",10
	DCB	"&4",9,		"DataLoadAck",10
	DCB	"&5",9,		"DataOpen",10
	DCB	"&6",9,		"RAMFetch",10
	DCB	"&7",9,		"RAMTransmit",10
	DCB	"&D",9,		"DataSaved",10
	DCB	"&8",9,		"PreQuit",10
	DCB	"&9",9,		"PaletteChange",10
	DCB	"&A",9,		"SaveDesktop",10
	DCB	"&B",9,		"DeviceClaim",10
	DCB	"&C",9,		"DeviceInUse",10
	DCB	"&E",9,		"Shutdown",10
	DCB	"&F",9,		"ClaimEntity",10
	DCB	"&10",9,	"DataRequest",10
	DCB	"&11",9,	"Dragging",10
	DCB	"&12",9,	"DragClaim",10
	DCB	"&13",9,	"ReleaseEntity",10
	DCB	"&15",9,	"AppControl",10
	DCB	"&400",9,	"FilerOpenDir",10
	DCB	"&401",9,	"FilerCloseDir",10
	DCB	"&402",9,	"FilerOpenDirAt",10
	DCB	"&403",9,	"FilerSelectionDirectory",10
	DCB	"&404",9,	"FilerAddSelection",10
	DCB	"&405",9,	"FilerAction",10
	DCB	"&406",9,	"FilerControlAction",10
	DCB	"&407",9,	"FilerSelection",10
	DCB	"&500",9,	"AlarmSet",10
	DCB	"&501",9,	"AlarmGoneOff",10
	DCB	"&502",9,	"HelpRequest",10
	DCB	"&503",9,	"HelpReply",10
	DCB	"&504",9,	"HelpEnable",10
	DCB	"&40040",9,	"Notify",10
	DCB	"&400C0",9,	"MenuWarning",10
	DCB	"&400C1",9,	"ModeChange",10
	DCB	"&400C2",9,	"TaskInitialise",10
	DCB	"&400C3",9,	"TaskCloseDown",10
	DCB	"&400C4",9,	"SlotSize",10
	DCB	"&400C5",9,	"SetSlot",10
	DCB	"&400C6",9,	"TaskNameRq",10
	DCB	"&400C7",9,	"TaskNameIs",10
	DCB	"&400C8",9,	"TaskStarted",10
	DCB	"&400C9",9,	"MenusDeleted",10
	DCB	"&400CA",9,	"Iconize",10
	DCB	"&400CB",9,	"WindowClosed",10
	DCB	"&400CC",9,	"WindowInfo",10
	DCB	"&400CD",9,	"Swap",10
	DCB	"&400CE",9,	"ToolsChanged",10
	DCB	"&400CF",9,	"FontChanged",10
	DCB	"&400D0",9,	"IconizeAt",10
	DCB	"&47700",9,	"ColourChoice",10
	DCB	"&47701",9,	"ColourChanged",10
	DCB	"&47702",9,	"CloseRequest",10
	DCB	"&47703",9,	"OpenParent",10
	DCB	"&4D540",9,	"PlugIn_Open",10
	DCB	"&4D541",9,	"PlugIn_Opening",10
	DCB	"&4D542",9,	"PlugIn_Close",10
	DCB	"&4D543",9,	"PlugIn_Closed",10
	DCB	"&4D544",9,	"PlugIn_Reshape",10
	DCB	"&4D545",9,	"PlugIn_Reshape_Request",10
	DCB	"&4D546",9,	"PlugIn_Focus",10
	DCB	"&4D547",9,	"PlugIn_Unlock",10
	DCB	"&4D548",9,	"PlugIn_StreamNew",10
	DCB	"&4D549",9,	"PlugIn_StreamDestroy",10
	DCB	"&4D54A",9,	"PlugIn_StreamWrite",10
	DCB	"&4D54B",9,	"PlugIn_StreamWritten",10
	DCB	"&4D54C",9,	"PlugIn_StreamAsFile",10
	DCB	"&4D54D",9,	"PlugIn_URLAccess",10
	DCB	"&4D54E",9,	"PlugIn_Notify",10
	DCB	"&4D54F",9,	"PlugIn_Status",10
	DCB	"&4D550",9,	"PlugIn_Busy",10
	DCB	"&4D551",9,	"PlugIn_Action",10
	DCB	"&4D552",9,	"PlugIn_Abort",10
	DCB	"&42580",9,	"ThrowbackStart",10
	DCB	"&42581",9,	"ProcessingFile",10
	DCB	"&42582",9,	"ErrorsIn",10
	DCB	"&42583",9,	"ErrorDetails",10
	DCB	"&42584",9,	"ThrowbackEnd",10
	DCB	"&42585",9,	"InfoForFile",10
	DCB	"&42586",9,	"InfoDetails",10
	DCB	"&808C0",9,	"TW_Input",10
	DCB	"&808C1",9,	"TW_Output",10
	DCB	"&808C2",9,	"TW_Ego",10
	DCB	"&808C3",9,	"TW_Morio",10
	DCB	"&808C4",9,	"TW_Morite",10
	DCB	"&808C5",9,	"TW_NewTask",10
	DCB	"&808C6",9,	"TW_Suspend",10
	DCB	"&808C7",9,	"TW_Resume",10
	DCB	"&80140",9,	"PrintFile",10
	DCB	"&80141",9,	"WillPrint",10
	DCB	"&80142",9,	"PrintSave",10
	DCB	"&80143",9,	"PrintInit",10
	DCB	"&80144",9,	"PrintError",10
	DCB	"&80145",9,	"PrintTypeOdd",10
	DCB	"&80146",9,	"PrintTypeKnown",10
	DCB	"&80147",9,	"SetPrinter",10
	DCB	"&8014C",9,	"PSPrinterQuery",10
	DCB	"&8014D",9,	"PSPrinterAck",10
	DCB	"&8014E",9,	"PSPrinterModified",10
	DCB	"&8014F",9,	"PSPrinterDefaults",10
	DCB	"&80150",9,	"PSPrinterDefaulted",10
	DCB	"&80151",9,	"PSPrinterNotPS",10
	DCB	"&80152",9,	"ResetPrinter",10
	DCB	"&80153",9,	"PSIsFontPrintRunning",10
	DCB	"&81400",9,	"DDE_ToolInfo",10
	DCB	"&4E380",9,	"URI_MStarted",10
	DCB	"&4E381",9,	"URI_MDying",10
	DCB	"&4E382",9,	"URI_MProcess",10
	DCB	"&4E383",9,	"URI_MReturnResult",10
	DCB	"&4E384",9,	"URI_MProcessAck",10
	DCB	"&45D80",9,	"EditRq",10
	DCB	"&45D81",9,	"EditAck",10
	DCB	"&45D82",9,	"EditReturn",10
	DCB	"&45D83",9,	"EditAbort",10
	DCB	"&45D84",9,	"EditDataSave",10
	DCB	"&45D85",9,	"EditCursor",10
	DCB	"&80E1E",9,	"OLE_FileChanged",10
	DCB	"&80E21",9,	"OLE_OpenSession",10
	DCB	"&80E22",9,	"OLE_OpenSessionAck",10
	DCB	"&80E23",9,	"OLE_CloseSession",10
	DCB	"&83580",9,	"NewsBase_Command",10
	DCB	"&83581",9,	"NewsBase_Reply",10
	DCB	"&83582",9,	"NewsBase_Update",10
	DCB	"&DAB00",9,	"IRC_SendData",10
	DCB	"&DAB01",9,	"IRC_SendRawData",10
	DCB	"&46005",9,	"ANT_SendAction",10
	DCB	"&4A43B",9,	"PopupHelp_SendHelp",10
	DCB	"&4A43C",9,	"PopupHelp_RequestHelp",10
	DCB	"&825C0",9,	"UtilDeclare",10
	DCB	"&825C1",9,	"UtilOpen",10
	DCB	"&825C2",9,	"UtilQuitting",10
	DCB	"&825C3",9,	"UtilReside",10
	DCB	"&825C4",9,	"UtilLoadAck",10
	DCB	"&450C0",9,	"Connect",10
	DCB	"&4AF80",9,	"OpenURL",10
	DCB	"&4AF81",9,	"HotlistAddURL",10
	DCB	"&4AF82",9,	"HotlistChanged",10
	DCB	"&4AF83",9,	"HotlistDelURL",10
	DCB	"&4AF87",9,	"HotlistShow",10
	DCB	"&4AF88",9,	"HotlistUser",10
FileEnd
	ALIGN
FileBlockEnd
	DCD	0

	END
