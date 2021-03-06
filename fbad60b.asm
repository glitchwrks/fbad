;			   FBAD.ASM ver. 60B
;			  (revised 11/11/87)
;		   NON-DESTRUCTIVE DISK TEST PROGRAM
;
; FBAD will find all bad blocks on a disk and build a file [UNUSED].BAD
; to allocate them, thus "locking out" the bad blocks so CP/M will not
; use them.  This allows continued use of the disk as though it had no
; bad areas.
;
; If an [UNUSED].BAD file is found on the disk before the test you will
; be prompted to keep the existing file (and all currently flagged bad
; blocks) or erase it and only flag the bad blocks found on the current
; pass.
;
; Originally written by Gene Cotton, published in "Interface Age" for
; September 1980, page 80.
;
; See notes below concerning 'TEST' conditional assembly option, SYSTST
; and BADUSR directives.
;
;=======================================================================
;			    current update
;
;
; 11/11/87 Revised track number display.
;   v60B   Modified to allow TEST routines to be left in. If TEST
;	   is TRUE the number of records read will be reported,
;          but only if no bad blocks were found.
;	   Added help message--   A>FBAD $?
;	   Added S, A and X command line options. See help message
;	   for proper usage. Revised handling of system tracks.
;	   Modified LTOP routine so that system track sectors
;	   do not go through sector translation. Reading is slow
;	   but system sectors may not use same XLATE as data
;	   sectors.			- TAH
;
; 03/28/85 Cleaned up some code that sends messages.
;   v60    Modified STOP routine so that you really can abort the
;	   program with ^C.		- Dave Mabry
;
;=======================================================================
; COMMAND LINE OPTIONS:
;
; Three command line options can now be specified -- S, A and X.
;
; If the ASTRS equate is set to NO the TRACK-Nr will be displayed
; during testing unless the A option is specified in which case
; an * will be printed for each track read.
;
; If the SYSTST equate is set to NO the system track test will be
; skipped unless the S option is specified in which case system
; track 0 will be read using the sector count value in the SPT0
; equate. All other system tracks will be read using the sector
; count value in the OSTK equate. If SPT0 or OSTK is set to zero
; then the SPT value for the data tracks will be used.
;   This should permit testing of system tracks where track 0 has
; a different sector count than other system tracks which, in turn,
; may have a different sector count than the data tracks. (e.g. JADE DD)
;   The X option is identical to the S option but allows using a second
; set of default values for SPT0 and/or OSTK (XSPT0 and XOSTK) in case
; you routinely use two different disk formats.
;
; NOTE THAT YOU SHOULD NOT USE THE  X  AND  S  OPTIONS TOGETHER.
;
; Finally, for the odd case, you may specify one or two numbers
; following the S option ( Sn0 or Sn0,n1 ). This will override
; the default sector count values set either for SPT0 alone or
; for both SPT0 and OSTK.
;
; SYSTST, BADUSR and ASTRS options:
;
; Many double-density disk systems have single-density system tracks.
; If this is true with your system, you can change the program to skip
; the system tracks, without re-assembling it.	To do this, set the byte
; at at 103H to 0 if you don't want the system tracks tested, otherwise
; keep it 1.  The program tests if you have a "blocked" disk system,
; that is, when the same physical disk is separated into logical disks
; by use of the SYSTRK word in the disk parameter block.  If more than 5
; tracks are specified, the program skips the system tracks.
;
; If you are using CP/M 2.x , you may assign the user number where the
; [UNUSED.BAD] file will be created, by changing the byte at 104H to the
; desired user number.
;
; FBAD displays the TRACK-Nr it has checked on the screen-terminal.  If
; you like to log the results on a printer (or you have a hardcopy term-
; inal, you may want to change LOC 105H to a non-zero value, and FBAD
; will display a * for each track checked.  The number in 105H controls
; the number of *'s per line.  (Note patch values are HEX: 76=4CH.)  Use
; ^P to turn the printer on before running FBAD, it will be automatically
; turned off by the warm boot at the end.
;
; NOTE:  These changes can be done with DDT as follows:
;
;		A>DDT FBAD.COM
;		-S103
;		103 01 00	;Don't test SYSTEM tracks
;		104 FF 0F	;Put [UNUSED.BAD] in USER 15
;		105 00 4C	;Issue CR/LF after 76 *'s
;		106 31 .	;Finished with changes
;		-^C
;
;		A>SAVE 12 FBAD.COM
;
;=======================================================================
;
;			   USING THE PROGRAM
;
; Before using this program to "reclaim" a diskette, the diskette should
; be reformatted.  If this is not possible, at least assure yourself
; that any existing files on the diskette do not contain unreadable re-
; cords.  If you have changed diskettes since the last warm-boot, you
; must warm boot again before running this program.
;
; To use the program, insert both the disk containing FBAD.COM and the
; diskette to be checked into the disk drives.	The diskette containing
; FBAD.COM can be the one that is to be checked.  Assume that the pro-
; gram is on drive "A" and the suspected bad disk is on drive "B".  In
; response to the CP/M prompt "A>", type in FBAD B: This will load the
; file FBAD.COM from drive "A" and test the diskette on drive "B" for
; unreadable records. If no drive is specified, the currently logged-in
; drive is assumed to contain the diskette to check.
;
; The program first checks the CP/M System tracks (up to 5), and any
; errors here prohibit the diskette from being used on drive "A", since
; all "warm boots" occur using the system tracks from the "A" drive.
; Floppy diskettes normally use 2 tracks for the system; Winchester hard
; disks may use one or more.
;
; Version  5.5	and  later  automatically skip the system check if 5 or
; more tracks are reserved for the system.  This allows the program to
; be used on BOTH floppy and Winchester systems without patching.
;
; The  program next checks the first two data blocks containing the
; diskette directory.  If errors occur here, the program terminates with
; the control returning to CP/M.  No other data blockes are checked as
; errors in the directory render the diskette useless.
;
; Finally, all the remaining data blocks are checked.  Any records that
; are unreadable cause the data block which contains them to be stored
; temporarily as a "bad block".  At the end of this phase, the message
; "nn bad blocks found" is displayed (where nn is replaced by the number
; of bad blocks, or "No" if no read errors occur).  If bad blocks occur,
; the filename [UNUSED].BAD is created, the list of "bad blocks" is put
; in the allocation map of the directory entry for [UNUSED].BAD, and the
; file is closed.  When the number of "bad blocks" exceeds 16, the pro-
; gram will open additional extents as required to hold the overflow.
; If the diskette has more than 32 "bad blocks", perhaps it should be
; sent to the "big disk drive in the sky" for the rest it deserves.
;
; If any "bad blocks" do occur, they are allocated to [UNUSED].BAD and
; no longer will be available to CP/M for future allocation.  This ef-
; fectively locks out bad records on the diskette allowing its continued
; use.
;
;		  Using the TEST conditional assembly
;
; A conditional assembly has been added to allow testing this program to
; make sure it is reading all records on your disk that are accessible
; to CP/M.  The program reads the disk on a block-by-block basis, so it
; is necessary to first determine the number of blocks present.  To com-
; mence, we must know the number of records/block (8 records/block for
; standard IBM single density format).	If this value is not known, it
; can be easily found by saving one page in a test file and interrogating
; using the STAT command:
;
;	A>SAVE 1 TEST.SIZ
;	A>STAT TEST.SIZ
;
; For standard single-density, STAT will report this file as being 1k.
; The file size reported (in bytes) is the size of a block.  This value
; divided by 128 bytes/record (the standard CP/M record size) will give
; records/block.  For our IBM single density example, we have:
;
;      (1024 bytes/block) / (128 bytes/record) = 8 records/block.
;
; We can now calculate blocks/track (assuming we know the number of
; records per track.  In our example:
;
;      (26 records/track) / (8 records/block) = 3.25 blocks/track
;
; Now armed with the total number of data tracks (75 in our IBM single
; density example), we get total blocks accessible:
;
;      75 (tracks/disk) x (3.25 blocks/track) = 243.75 blocks/disk
;
; CP/M cannot access a fractional block, so we round down (to 243 blocks
; in our example).  Now multiplying total blocks by records per block
; results in total records as should be reported when TEST is set YES
; and a good disk is read.  For our example, this value is 1944 records.
;
; Finally, note that if SYSTST is set YES, the records present on the
; system tracks will be displayed as well.  In the previous example,
; this results in 1944 + 52 = 1996 records (reported separately by the
; TEST conditional).  Version 5.4 reported these as a single total at
; the end.
;
; Run the program on a KNOWN-GOOD diskette.  It should report that it
; has read the correct number of records.
; We should not display the number of records read if bad blocks are
; found since this program does not read all the records in a
; block that is found to be bad and thus will report an inaccurate
; number of records read.
;
;=======================================================================
;
; 03/16/85 Program will ask you if you want to continue checking on the
;   v59    same drive as originally entered - added a byte at the end of
;	   the code (ORIGDR) to store the value from the FCB.
;					     ( Ken Kaplan )
;
; 12/12/84  Added the ability to keep bad blocks that were flagged in a
;   v58     previous [UNUSED].BAD file.  If a block was ever flagged as
;	    bad by this program, it is probably weak.  If on a subse-
;	    quent test, it makes it through the BIOS retires and is read
;	    successfully, I want the block to stay in the [UNUSED].BAD
;	    file.  Removed the coded in LTOP which cleared the high byte
;	    of HL after a call to RECTRN.  My BIOS (Morrow DJDMA) sets
;	    the high bit of HL to indicated side 1 of a double-sided
;	    drive.			- Ron Schwabel (Ron Schwabel)
;
; 11/29/84  Integrated Mike Webbs idea to display Track-Nr. Changed DOC
;   v57     up front accordingly.	- BGE
;
; 07/04/84  Added Ted Shapin's fixes from 1981 that were not included in
;   v56     the 06/07/84 version.  Reformatted.
;					- Irv Hoff
;
; 06/07/84  Added code at CHKSYS to skip system tracks if more than 5
;   v55     are present (most systems use 1 or at most 2 tracks for the
;	    system).  This makes the program practical for both floppy
;	    and Winchester systems.  Cosmetic change for printer logging
;	    to add CR/LF after 76 *'s.	Fixed problem in DECOUT to give
;	    correct total for max size Winchester disks.
;					- DHR
;
;=======================================================================
;
NO	EQU	0
YES	EQU	NOT NO
;
;=======================================================================
;
; Conditional assembly switch for testing this program 
;
;
TEST	EQU	YES		; Yes to desplay records read if good disk
;
;=======================================================================
;
; System equates
;
WBOOT	EQU	0		; CP/M warm boot entry
BDOS	EQU	0005H		; BDOS entry point
FCB	EQU	005CH		; CP/M default FCB location
;
TBUFF	EQU	0080H	;COMMAND LINE COPIED HERE
SPCHR	EQU	'$'	;LEADIN FOR OPTIONS
;
;
; Define ASCII characters used
;
BELL	EQU	07H
CR	EQU	0DH		; Carriage return character
LF	EQU	0AH		; Line feed character
TAB	EQU	09H		; Tab character
VERS	EQU	60		; Version number
;
DPBOFF	EQU	3AH		; Cp/m 1.4 offset to DPB within BDOS
TRNOFF	EQU	15		; Cp/m 1.4 offset to record Xlate routine
;
;
	ORG	0100H
;
;
	JMP	START		; Jmp around option bytes
;
;
; If you want the system tracks tested, then put a 1 here, otherwise 0.
;
SYSTST:	DB	0
;
;
; If using CP/M 2.x change this byte to the user number you want
; [UNUSED].BAD to reside in.
;
BADUSR:	DB	15		; User # where [UNUSED.BAD] goes
;
; Set this byte to the number of *'s you want per display line
;
ASTRS:	DB	00		; Number of *'s per line (0 == 'track xx')
;
;
;ENTER DEFAULT SPT VALUE FOR SYSTEM TRACK 0   (26 FOR 8" SS/SD)
DFSPT0:	EQU	26		;IF 00, USE DATA TRACK VALUE
;
;ENTER DEFAULT SPT VALUE FOR OTHER SYSTEM TRACK(S)
DFOSTK:	EQU	00		;IF 00, USE DATA TRACK VALUE
;
SPT0:	DW	DFSPT0
OSTK:	DW	DFOSTK
;
;
;THE FOLLOWING TWO EQUATES ARE FOR USE IN CONJUNCTION WITH THE
; 'X' COMMAND LINE OPTION WHICH WILL INITIALIZE SPT0 AND OSTK
;TO THE VALUES ENTERED.
;
XSPT0	EQU	26	;SPECIAL VALUE FOR SYSTEM TRACK 0 SPT
XOSTK	EQU	50	;SPECIAL VALUE FOR OTHER SYSTEM TRACK(S)
;			;50 FOR JADE DOUBLE D CONTROLLER
;=======================================================================
;
;			  PROGRAM STARTS HERE
;
;=======================================================================
;
START:	LXI	SP,STACK	; Make new stack
	LXI	D,SIGNON	; Introduce ourself
	CALL	PSTRNG
;
	CALL	GETOPT		;CHECK COMMAND LINE OPTIONS
;
RESTRT:	CALL	SETUP		; Set BIOS entry, and check drive
	CALL	ZMEM		; Zero all available memory
	CALL	FINDB		; Establish all bad blocks
	JZ	NOBAD		; Say no bad blocks, if so
	CALL	SETDM		; Fix DM bytes in FCB
;
NOBAD:	CALL	CRLF
	MVI	A,TAB
	CALL	TYPE
	LXI	D,NOMSG		; Point first to 'no'
	LHLD	BADBKS		; Pick up # bad blocks
	MOV	A,H		; Check for zero
	ORA	L
	JZ	PMSG1		; Jump if none
	LXI	D,BELLS
	CALL	PSTRNG
	LHLD	BADBKS
	PUSH	H
	LXI	H,BADBKS
	CALL	DECOUT		; Oops..had some bad ones, report
	POP	H
	SHLD	BADBKS
	LXI	D,BELLS
	CALL	PSTRNG
	JMP	PMSG2
;
PMSG1:	CALL	PSTRNG
;
PMSG2:	LXI	D,ENDMSG	; Rest of exit message
;
PMSG:	CALL	PSTRNG
;
	 IF	TEST
	LHLD	BADBKS
	MOV	A,H
	ORA	L
	JNZ	SKPT1
	MVI	A,TAB		; Get a tab
	CALL	TYPE		; Print it
	LXI	H,RECCNT	;DIR+DATA BLOCK COUNT
	CALL	DECOUT		; Print it
	LXI	D,RECMSG	; Point to message
	CALL	PSTRNG		;
	 ENDIF			; TEST
;
SKPT1:	LXI	D,CMSG1		; Do you want to continue?
	CALL	PSTRNG
	MVI	C,1		; BDOS read console function
	CALL	BDOS
	ANI	5FH		; convert lower to upper case
	CPI	'C'		; if C or c entered continue
	JNZ	SKPT2		; Exit
	MVI	C,13		; do a disk reset to avoid BDOS R/O errors
	CALL	BDOS
	LDA	ORIGDR		; get drive value
	STA	FCB		; put it back in FCB
	LXI	SP,STACK
	JMP	RESTRT		; start over
SKPT2:	MVI	C,37		;FUNCTION 37 OK HERE.
	LXI	D,0FFFFH	;JUST IN CASE FTN 13
	CALL	BDOS		;WAS MODIFIED NOT TO
	JMP	WBOOT		;RESET A HARD DISK.
;
;
; Get actual address of BIOS routines
;
; WARNING...Program modification takes place here...do not change.
;
SETUP:	LHLD	1		; Get pointer to warm boot
	LXI	D,24		; Offset to 'SETDSK'
	DAD	D
	SHLD	SETDSK+1	; Fix our call address
	LXI	D,3		; Offset to 'SETTRK'
	DAD	D
	SHLD	SETTRK+1	; Fix our call address
	LXI	D,3		; Offset to 'SETREC'
	DAD	D
	SHLD	SETREC+1	; Fix our call address
	LXI	D,6		; Offset to 'DREAD'
	DAD	D
	SHLD	DREAD+1		; Fix our call address
	LXI	D,9		; Offset to CP/M 2.x RECTRAN
	DAD	D
	SHLD	RECTRN+1	; Fix our call address
	MVI	C,12		; Get version function
	CALL	BDOS
	MOV	A,H		; Save as flag
	ORA	L
	STA	VER2FL
	JNZ	GDRIV		; Skip 1.4 stuff if is 2.x
	LXI	D,TRNOFF	; Cp/m 1.4 offset to RECTRAN
	LHLD	BDOS+1		; Set up jump to 1.4 RECTRAN
	MVI	L,0
	DAD	D
	SHLD	RECTRN+1
;
;
; Check for drive specification
;
GDRIV:	LDA	FCB		; Get drive name
	STA	ORIGDR		; Store for use later
	MOV	C,A
	ORA	A		; Zero?
	JNZ	GD2		; If not,then go specify drive
	MVI	C,25		; Get logged-in drive
	CALL	BDOS
	INR	A		; Make 1-relative
	STA	ORIGDR
	MOV	C,A
;
GD2:	LDA	VER2FL		; If CP/M version 2.x
	ORA	A
	JNZ	GD3		; Seldsk will return select error
;
;
; Is CP/M 1.4, which doesn't return a select error, so we have to do it
; here
;
	MOV	A,C
	CPI	4+1		; Check for highest drive number
	JNC	SELERR		; Select error
;
GD3:	DCR	C		; Back off for CP/M
	PUSH	B		; Save disk selection
	MOV	E,C		; Align for BDOS
	MVI	C,14		; Select disk function
	CALL	BDOS
	POP	B		; Get back disk number
;
;
; EXPLANATION: Why we do the same thing twice
;
; You might notice that we are doing the disk selection twice, once by a
; BDOS call and once by direct BIOS call.  The BIOS call is necessary in
; order to get the necessary pointer back from CP/M (2.x) to find the
; record translate table.  The BDOS call is necessary to keep CP/M in
; step with the  BIOS.	Later the file [UNUSED].BAD may need to be
; created and CP/M must know which drive is being used.
;
	CALL	SETDSK		; Direct BIOS call
	LDA	VER2FL
	ORA	A
	JZ	DOLOG		; Jump if CP/M 1.4
	MOV	A,H
	ORA	L		; Check for 2.x
	JZ	SELERR		; Jump if select error
	MOV	E,M		; Get record table pointer
	INX	H
	MOV	D,M
	INX	H
	XCHG
	SHLD	RECTBL		; Store it away
	LXI	H,8		; Offset to DPB pointer
	DAD	D
	MOV	A,M		; Pick up DPB pointer
	INX	H		; To use
	MOV	H,M		; As parameter
	MOV	L,A		; To logit
;
DOLOG:	CALL	LOGIT		; Log in drive, get disk parms
	CALL	GETDIR		; Calculate directory information
;
;
; Now set the required user number
;
	LDA	VER2FL
	ORA	A
	RZ			; No users in CP/M 1.4
	LDA	BADUSR		; Get the user number
	MOV	E,A		; BDOS call needs user # in 'E'
	MVI	C,32		; Get/set user code
	CALL	BDOS
	RET
;.....
;
;
; Look for bad blocks
;
FINDB:	LHLD	SPT
	SHLD	SPTSAV		;SAVE DATA TRACK SPT
	MVI	A,0FFH
	STA	SHOFLG		;INIT TRACK DISPLAY FLAG
	LHLD	SYSTRK
	SHLD	DECWRK		;INIT TRACK NUMBER DISPLAY
	LDA	SYSTST
	ORA	A
	JZ	DODIR		; Jump if no system tracks to be tested
	CALL	CHKSYS		; Check for bad blocks on track 0 and 1
;
DODIR:	XRA	A
	STA	RECCNT
	LXI	H,0000
	SHLD	RECCNT+1	;INITIALIZE RECORDS READ TO ZERO
	LHLD	SPTSAV
	SHLD	SPT		;RESTORE DATA TRACK SPT
;
	CALL	CHKDIR		; Check for bad blocks in directory
	LXI	D,TDAMSG	; Testing data area message
	CALL	PSTRNG
	LDA	ASTRS		; Set column count
	STA	COLUMN
	CALL	ERAB		; Erase any [UNUSED].BAD file
	LHLD	DIRBKS		; Start at first data block
	MOV	B,H		; Put into 'BC'
	MOV	C,L
;
FINDBA:	CALL	READB		; Read the block
	CNZ	SETBD		; If bad, add block to list
	INX	B		; Bump to next block
	LHLD	DSM
	MOV	D,B		; Set up for (MAXGRP - CURGRP)
	MOV	E,C
	CALL	SUBDE		; Do subtract: (MAXGRP - CURGRP)
	JNC	FINDBA		; Until CURGRP > MAXGRP
	CALL	CRLF
	LHLD	DMCNT		; Get number of bad records
	MOV	A,H
	ORA	L		; Set zero flag, if no bad blocks
	RET			; Return from 'FINDB'
;.....
;
;
; Check system tracks, notify user if bad, but continue
;
CHKSYS:	XRA	A
	STA	RECCNT
	LXI	H,0000
	SHLD	RECCNT+1	;INITIALIZE RECORDS READ TO ZERO
	LHLD	SYSTRK		; Get # system tracks
	MOV	A,H		; Get high part
	ORA	A
	JNZ	SKPSYS		; Skip system track check if non-zero
	MOV	A,L		; Get low part
	ORA	A
	JZ	NOSYS		;NO SYSTEM TRACKS TO CHECK
	CPI	6		; >5 tracks?
	JNC	SKPSYS		; Skip check if so
	LDA	ASTRS		; Set column counter
	STA	COLUMN
	LXI	D,TSTMSG	; Testing system tracks message
	CALL	PSTRNG
	LXI	H,0		; Set track 0,record 1
	SHLD	TRACK
	SHLD	DECWRK		;INIT TRACK NUMBER DISPLAY
	INX	H
	SHLD	RECORD
;
	LHLD	SPT0		;GET SPT0 VALUE
	MOV	A,H
	ORA	L		;IS IT ZERO?
	JNZ	CHK1
	LHLD	SPTSAV		;IF YES, USE DATA TRACK SPT
CHK1:	SHLD	SPT		;INITIALIZE TRACK 0 SPT
;
CHKSY0:	CALL	READS		;DO TRACK 0
	JNZ	SYSERR
	LXI	D,1
	LHLD	TRACK
	CALL	SUBDE
	JC	CHKSY0
;
	LHLD	OSTK		;GET OTHER SYS TRK VALUE
	MOV	A,H
	ORA	L		;IS IS ZERO?
	JNZ	CHK2
	LHLD	SPTSAV		;IF YES, USE DATA TRACK SPT
CHK2:	SHLD	SPT		;INITIALIZE SPT VALUE
;
CHKSY1:	CALL	READS		; Read a record
	JNZ	SYSERR		; Notify, if bad blocks here
	LHLD	SYSTRK		; Set up
	XCHG
	LHLD	TRACK
	CALL	SUBDE		; Do the subtract
	JC	CHKSY1		; Loop while track < SYSTRK
;
	 IF	TEST
	CALL	CRLF
	MVI	A,TAB		; Get a tab
	CALL	TYPE		; Print it
	LXI	H,RECCNT	; Get # records so far
	CALL	DECOUT		; Print it
	LXI	D,SYSMSG	; Point to message
	CALL	PSTRNG
	 ENDIF			; Test
;
	RET			; Return from "CHKSYS"
;.....
;
NOSYS:	LXI	D,ZROSYS	;NO SYSTEM TRACKS HERE
	JMP	PSTRNG
;
ZROSYS:	DB	CR,LF,'No SYSTEM tracks on this disk',CR,LF,'$'
;
SKPSYS:	LXI	D,SKPMSG	; Say skipping system tracks
	JMP	PSTRNG
;
SKPMSG:	DB	CR,LF,'Skipping system tracks...',CR,LF,'$'
;
SYSERR:
	LXI	D,ERMSG5	; Say no go, and bail out
;
PSTRNG:	MVI	C,9		; BDOS print string function
	CALL	BDOS
	RET			; Return from "SYSERR" or subroutine
;.....
;
;
; Check for bad blocks in directory area
;
CHKDIR:	LXI	D,TDRMSG	; Testing directory area message
	CALL	PSTRNG
	LXI	B,0		; Start at block 0
;
CHKDI1:	CALL	READB		; Read a block
	JNZ	ERROR6		; If bad, show error in directory area
	INX	B		; Bump for next block
	LHLD	DIRBKS		; Set up (CURGRP - DIRBKS)
	DCX	H		; Make 0-relative
	MOV	D,B
	MOV	E,C
	CALL	SUBDE		; Do the subtract
	JNC	CHKDI1		; Loop until CURGRP > DIRGRP
	RET			; Return from CHKDIR
;.....
;
;
; Read all records in block, and return zero flag set if none bad
;
READB:	CALL	CNVRTB		; Convert to track/record in 'HL' regs.
	LDA	BLM
	INR	A		; Number of records/block
	MOV	D,A		; In 'D' register
;
READBA:	PUSH	D
	CALL	READS		; Read skewed record
	POP	D
	RNZ			; Error if not zero
	DCR	D		; Debump record/block
	JNZ	READBA		; Do next, if not finished
	RET			; Return from 'READBA'
;.....
;
;
; Convert block number to track and skewed record number
;
CNVRTB:	PUSH	B		; Save current group
	MOV	H,B		; Need it in 'HL'
	MOV	L,C		; For easy shifting
	LDA	BSH		; Dpb value that tells how to
;
SHIFT:	DAD	H		; Shift group number to get
	DCR	A		; Disk-data-area relative
	JNZ	SHIFT		; Record number
	XCHG			; Rel record # into 'DE'
	LHLD	SPT		; Records per track from DPB
	CALL	NEG		; Faster to DAD than call SUB D
	XCHG
	LXI	B,0		; Initialize quotient
;
;
; Divide by number of records
;	quotient = track
;	     mod = record
;
DIVLP:	INX	B		; Dirty division
	DAD	D
	JC	DIVLP
	DCX	B		; Fixup last
	XCHG
	LHLD	SPT
	DAD	D
	INX	H
	SHLD	RECORD		; Now have logical record
	LHLD	SYSTRK		; But before we have track #,
	DAD	B		; We have to add system track offset
	SHLD	TRACK
	POP	B		; This was our group number
	RET
;.....
;
;
; Reads a logical record (if it can) and returns zero flag set if no
; error.
;
READS:	PUSH	B		; Save the group number
	CALL	LTOP		; Convert logical to physical
	LDA	VER2FL		; Now check version
	ORA	A
	JZ	NOTCP2		; Skip this stuff if CP/M 1.4
	LHLD	PHYREC		; Get physical record
	MOV	B,H		; Into 'BC'
	MOV	C,L
	CALL	SETREC		; BIOS set record call
;
;
; QUICK NOTE OF EXPLANATION:  This code appears as if we skipped the
; SETREC routine for 1.4 CP/M users.  That is not true.  In CP/M 1.4,
; the call within the LTOP routine to RECTRAN actually does the set
; record, so no need to do it twice.
;
NOTCP2:	LHLD	TRACK		; Now set the track
	MOV	B,H		; CP/M wants it in 'BC'
	MOV	C,L
	CALL	SETTRK		; BIOS set track
;
	LXI	H,SHOFLG	;POINT TO FLAG
	MOV	A,M		;AND GET IT.
	MVI	M,0		;ALWAYS CLEAR IT.
	ORA	A		;DISPLAY NEW TRACK NUMBER?
	CNZ	SHOTRK		;YES IF NOT ZERO.
;
; Now do the record read
;
	CALL	DREAD		; BIOS disk read
	ORA	A		; Set flags
	PUSH	PSW		; Save error flag
;
	 IF	TEST
	CALL	INCREC		; Increment record count
	 ENDIF			; Test
;
	LHLD	RECORD		; Get logical record #
	INX	H		; We want to increment to next
	XCHG			; But first,check overflow
	LHLD	SPT		; By doing (recpertrk-record)
	CALL	SUBDE		; Do the subtraction
	XCHG
	JNC	NOOVF		; Jump if not record > recpertrk
;
;
; Record overflow...bump track number, reset record
;
	LHLD	TRACK
	INX	H
	SHLD	TRACK
	MVI	A,0FFH		;SET TRACK DISPLAY FALG
	STA 	SHOFLG
	LXI	H,1		; New record number on next track
;
NOOVF:	SHLD	RECORD		; Put record away
	POP	PSW		; Get back error flags
	POP	B		; Restore group number
	RET
;.....
;
;
; Convert logical record # to physical
;
LTOP:	LHLD	RECTBL		; Set up parameters
	XCHG			; For call to RECTRAN
	LHLD	RECORD
	MOV	B,H
	MOV	C,L
	DCX	B		; Always call RECTRN w/zero-rel sec #
;
	PUSH	H
	PUSH	D
	LHLD	SYSTRK
	XCHG
	LHLD	TRACK
	CALL	SUBDE		;NO TRANSLATION..
	POP	D
	POP	H
	JC	LTOP1		;..IF DOING SYSTEM TRACKS
;
RECT1:	CALL	RECTRN		; Do the record translation
	LDA	SPT+1		; Check if big tracks
	ORA	A		; Set flags (tracks > 256 records)
	JNZ	LTOP1		; No so skip
	LDA	TRACK		; Check for track 0
	MOV	B,A
	LDA	TRACK+1		; High order
	ORA	B
	JNZ	LTOP1		; Not track 0
;;	MOV	H,A		; Zero out upper 8 bits
;
LTOP1:	SHLD	PHYREC		; Put away physical record
	RET
;.....
;
SHOTRK:	LDA	ASTRS		; Check if column length set
	ORA	A
	JNZ	HDCOPY		; Non-zero - do *'s
	LHLD	TRACK
	SHLD	DECWRK		; Decout destroys
	LXI	D,TRKMSG
	CALL	PSTRNG
	LXI	H,DECWRK
	CALL	DECOUT
	MVI	A,' '
	CALL	TYPE
	JMP	NOCRLF
;
HDCOPY:	MVI	A,'*'		; Tell console another track done
	CALL	TYPE
	LDA	COLUMN		; Check column
	ORA	A		; Skip if zero
	JZ	NOCRLF
	DCR	A
	STA	COLUMN
	JNZ	NOCRLF		; Jump if less than 80
	LDA	ASTRS		; Reset column
	STA	COLUMN
	CALL	CRLF
;
NOCRLF:	CALL	STOP		; See if console wants to quit
	RET
;
; Direct BIOS calling is done here...
;
SETDSK:	JMP	$-$		; Filled in by SETUP
SETTRK:	JMP	$-$		; Filled in by SETUP
SETREC:	JMP	$-$		; Filled in by SETUP
DREAD:	JMP	$-$		; Filled in by SETUP
RECTRN:	JMP	$-$		; Filled in by SETUP
;
;
; Put bad block in bad block list
;
SETBD:	PUSH	B
	LXI	D,BBMSG		; Bad block message
	CALL	PSTRNG
	POP	B		; Get back block number
	MOV	A,B
	CALL	HEXO		; Print in hex
	MOV	A,C
	CALL	HEXO
	CALL	CRLF
	LXI	H,DM		; Point to exitsing bad blocks
;
SETBD2:	MOV	A,M		; Get first 8 bits of bad map entry
	INX	H
	CMP	C		; Is new entry already there ?
	JZ	SETBD4		; Maybe
	LDA	DSM+1		; Check size of block entries
	ORA	A
	JZ	SETBD3		; Small blocks
	INX	H		; Skip over high order half
;
SETBD3:	PUSH	H
	XCHG			; Save 'HL'
	LHLD	DMPTR
	XCHG
	CALL	SUBDE		; Scan pointer-(DMPTR)
	POP	H		; Restore scan pointer
	JC	SETBD2		; Continue searching
	JMP	SETBD9		; Put it away

SETBD4:	LDA	DSM+1
	ORA	A
	RZ			; Small blocks = done
	MOV	A,M		; Get high order half of existing block
	CMP	B		; Compare with block to be added
	RZ			; Really already there
	INX	H		; Point to low order of next block
	JMP	SETBD3		; Check if done

SETBD9:	LHLD	DMCNT		; Get number of records
	LDA	BLM		; Get block shift value
	INR	A		; Makes record/group value
	MOV	E,A		; We want 16 bits
	MVI	D,0
	DAD	D		; Bump by number in this block
	SHLD	DMCNT		; Update number of records
	LHLD	BADBKS		; Increment number of bad blocks
	INX	H
	SHLD	BADBKS
	LHLD	DMPTR		; Get pointer into DM
	MOV	M,C		; And put bad block number
	INX	H		; Bump to next available extent
	LDA	DSM+1		; Check if 8 or 16 bit block size
	ORA	A
	JZ	SMGRP		; Jump if 8 bit blocks
	MOV	M,B		; Else store hi byte of block #
	INX	H		; And bump pointer
;
SMGRP:	SHLD	DMPTR		; Save DM pointer, for next time
	RET			; Return from 'SETBD'
;.....
;
;
; Eliminate any previous [UNUSED].BAD entries
;
ERAB:	LXI	D,BFCB		; Bad FCB
	XRA	A
	STA	BFCB+12		; Clear extent
	MVI	C,15		; Open file
	CALL	BDOS		; Try to open file
	CPI	0FFH		; Not found ?
	RZ			; Yes, no need to delete it
	STA	DIROFS		; Directory offset in DMA buffer
;
ERAB0:	LXI	D,ERABMS
	CALL	PSTRNG
	MVI	C,1		; Console input
	CALL	BDOS
	CPI	'a'
	JC	ERAB1		; Already upper case
	ANI	05FH		; Force upper case
;
ERAB1:	CPI	'Y'
	JZ	ERAB4		; Do it
	CPI	'N'
	JNZ	ERAB0		; Invalid response
	CALL	ERAB2		; Load tables, then erase old file
;
ERAB4:	CALL	CRLF
	LXI	D,BFCB		; Point to bad FCB
	MVI	C,19		; BDOS delete file function
	CALL	BDOS
	RET
;.....
;
;
ERABMS:	DB	'Erase Existing [UNUSED].BAD file ? (Y/N) $'
				; Flag old bad blocks for this run
;
;
;Move bad allocated blocks to DM area
;
ERAB2:	LXI	H,DM		; Get DM
	SHLD	DMPTR		; Save as new pointer
	LDA	EXM		; Get the extent shift factor
	MVI	C,0		; Init bit count
	CALL	COLECT		; Get shift value
	LXI	H,128		; Starting extent size
	MOV	A,C		; First see if any shifts to do
	ORA	A
	JZ	ERAB2B		; Jump if none
;
ERAB2A:	DAD	H		; Shift
	DCR	A		; Bump
	JNZ	ERAB2A		; Loop
;
ERAB2B:	PUSH	H		; Save this, it is records per extent
	LDA	BSH		; Get block shift
	MOV	B,A
;
ERAB2C:	CALL	ROTRHL		; Shift right
	DCR	B
	JNZ	ERAB2C		; To get blocks per extent
	MOV	A,L		; It's in 'L' (can't be >16)
	STA	BLKEXT		; SETDME will need this later
	POP	H		; Get back recrds/extent
;
ERAB2D:	XCHG			; Now have records/extent in 'DE'
	LHLD	DMCNT		; Count of bad records
;
ERAB2E:	PUSH	H
	PUSH	D
	LDA	BFCB+15		; Record count
	MOV	L,A
	MVI	H,0
	MOV	B,H		; Save record count in 'BC'
	MOV	C,L
	POP	D
	CALL	SUBDE		; Have to subtract first
	POP	H		; This pop makes it compare only
	PUSH	PSW
	DAD	B		; New count of bad records
	SHLD	DMCNT		; Save count of bad records
	POP	PSW
	JC	ERAB2G		; Jump if less than 1 extent worth
	MOV	A,B
	ORA	C		; Test if subtract was 0
	RZ			; Extent is empty (special case)
	PUSH	H		; Save total
	PUSH	D		; And records/extent
	CALL	ERAB2G		; Get next extent
	POP	D		; Get back records/extent
	POP	H		; And count of bad records
	CPI	0FFH		; Check return from search next
	RZ
	JMP	ERAB2E		; And loop
;
;
; Load an extent's worth of bad records/block numbers.	'BC' contains
; the number of records in this extent
;
ERAB2G:	MOV	A,B
	ORA	C		; Check record count
	MVI	A,0FFH		; Assume zero
	RZ			; No more to process
	PUSH	B		; Save records in this extent
	LDA	BLM		; Block mask
	INR	A		; Make records/block
	CMA			; Make negative
	MOV	E,A
	MVI	D,0FFH
	INX	D		; Make 2's complement
	POP	H		; Hl = number of records
	LXI	B,0
;
;
; Divide records in this extent by recs/block giving blocks
;
ERAB2I:	DAD	D
	INX	B		; Bump quotient
	JC	ERAB2I		; Not done yet
	DCX	B		; Account for overshoot
	LHLD	BADBKS		; Bad block count
	DAD	B
	SHLD	BADBKS
;
ERAB2K:	LXI	H,BFCB+16	; Disk alloc map in FCB
	XCHG
	LHLD	DMPTR		; Point to bad allocation map
;
ERAB2L:	LDAX	D
	MOV	M,A
	INX	H
	INX	D
;
;
; Now see if 16 bit groups...if so, we have to move another byte
;
	LDA	DSM+1		; This tells us
	ORA	A
	JZ	ERAB2M		; If zero, then not
	LDAX	D		; Is 16 bits, so do another
	MOV	M,A
	INX	H
	INX	D
;
ERAB2M:	DCR	C		; Count down
	JNZ	ERAB2L
	SHLD	DMPTR
	LDA	BFCB+12
	INR	A
	STA	BFCB+12		; Next extent number
	LXI	D,BFCB
	MVI	C,15		; Open next extent
	CALL	BDOS
	STA	DIROFS
	RET
;.....
;
;
; Create [UNUSED].BAD file entry
;
OPENB:	LXI	D,BFCB		; Point to bad FCB
	MVI	C,22		; BDOS make file function
	CALL	BDOS
	CPI	0FFH		; Check for open error
	RNZ			; Return from 'OPENB', if no error
	JMP	ERROR7		; Bail out...cannot create [UNUSED].BAD
;
CLOSEB:	XRA	A
	LDA	BFCB+14		; Get CP/M 2.x 's2' byte
	ANI	1FH		; Zero update flags
	STA	BFCB+14		; Restore it to our FCB (won't hurt 1.4)
	LXI	D,BFCB		; FCB for [UNUSED].BAD
	MVI	C,16		; BDOS close file function
	CALL	BDOS
	RET			; Return from 'CLOSEB'
;.....
;
;
; Move bad area DM to BFCB
;
SETDM:	LXI	H,DM		; Get DM
	SHLD	DMPTR		; Save as new pointer
	LDA	EXM		; Get the extent shift factor
	MVI	C,0		; Initialize bit count
	CALL	COLECT		; Get shift value
	LXI	H,128		; Starting extent size
	MOV	A,C		; First see if any shifts to do
	ORA	A
	JZ	NOSHFT		; Jump if none
;
ESHFT:	DAD	H		; Shift
	DCR	A		; Bump
	JNZ	ESHFT		; Loop
;
NOSHFT:	PUSH	H		; Save this, it is records per extent
	LDA	BSH		; Get block shift
	MOV	B,A
;
BSHFT:	CALL	ROTRHL		; Shift right
	DCR	B
	JNZ	BSHFT		; To get blocks per extent
	MOV	A,L		; It is in 'L' (cannot be 16)
	STA	BLKEXT		; SETDME will need this later
	POP	H		; Get back rececord/extent
;
SET1:	XCHG			; Now have records/extent in 'DE'
	LHLD	DMCNT		; Count of bad records
;
SETDMO:	PUSH	H		; Set flags on (DMCNT-BADCNT)
	CALL	SUBDE		; Have to subtract first
	MOV	B,H		; Save result in 'BC'
	MOV	C,L
	POP	H		; This pop makes it compare only
	JC	SETDME		; Jump if less than 1 extent worth
	MOV	A,B
	ORA	C		; Test if subtract was 0
	JZ	EVENEX		; Extent is exactly filled (special case)
	MOV	H,B		; Restore result to 'HL'
	MOV	L,C
	PUSH	H		; Save total
	PUSH	D		; And records/extent
	XCHG
	CALL	SETDME		; Put away one extent
	XCHG
	SHLD	DMPTR		; Put back new DM pointer
	POP	D		; Get back records/extent
	POP	H		; And count of bad records
	JMP	SETDMO		; And loop
;
;
; Handle the special case of a file that ends on an extent boundary.
; CP/M requires that such a file have a succeeding empty extent in order
; for the BDOS to properly access the file.
;
EVENEX:	XCHG			; First set extent with bad blocks
	CALL	SETDME
	XCHG
	SHLD	DMPTR
	LXI	H,0		; Now set one with no data blocks
;
;
; Fill in an extent's worth of bad records/block numbers.  Also fill in
; the extent number in the FCB.
;
SETDME:	PUSH	H		; Save record count
	LDA	EXTNUM		; Update extent byte
	INR	A
	STA	EXTNUM		; Save for later
	STA	BFCB+12		; And put in FCB
	CALL	OPENB		; Open this extent
	POP	H		; Retrieve record count
;
;
; Divide record count by 128 to get the number of logical extents to put
; in the EX field
;
	MVI	B,0		; Initialize quotient
	LXI	D,-128
	MOV	A,H		; Test for special case
	ORA	L		; Of no records
	JZ	SKIP
;
DIVLOP:	DAD	D		; Subtract
	INR	B		; Bump quotient
	JC	DIVLOP
	LXI	D,128		; Fix up overshoot
	DAD	D
	DCR	B
	MOV	A,H		; Test for wraparound
	ORA	L
	JNZ	SKIP
	MVI	L,80H		; Record length
	DCR	B
;
SKIP:	LDA	EXTNUM		; Now fix up extent num
	ADD	B
	STA	EXTNUM
	STA	BFCB+12
	MOV	A,L		; Mod is record count
	STA	BFCB+15		; That goes in receive byte
;
MOVDM:	LDA	BLKEXT		; Get blocks per extent
	MOV	B,A		; Into 'B'
;
SETD1:	LHLD	DMPTR		; Point to bad allocation map
	XCHG
	LXI	H,BFCB+16	; Disk alloc map in FCB
;
SETDML:	LDAX	D
	MOV	M,A
	INX	H
	INX	D
;
;
; Now see if 16 bit groups...if so, we have to move another byte
;
	LDA	DSM+1		; This tells us
	ORA	A
	JZ	BUMP1		; If zero, then not
	LDAX	D		; Is 16 bits, so do another
	MOV	M,A
	INX	H
	INX	D
;
BUMP1:	DCR	B		; Count down
	JNZ	SETDML
	PUSH	D
	CALL	CLOSEB		; Close this extent
	POP	D
	RET
;.....
;
;
; Error messages
;
SELERR:	LXI	D,SELEMS	; Say no go, and bail out
	JMP	PMSG
SELEMS:	DB	CR,LF,'Drive specifier out of range$'
ERMSG5:	DB	CR,LF,BELL,'+++ Warning...system tracks'
	DB	' bad +++',BELL,CR,LF,'$'
ERROR6:	LXI	D,ERMSG6	; Oops...clobbered directory
	JMP	PMSG
ERMSG6:	DB	CR,LF,BELL,'Bad directory area, try reformatting'
	DB	CR,LF,BELL,'$'
ERROR7:	LXI	D,ERMSG7	; Say no go, and bail out
	JMP	PMSG
ERMSG7:	DB	CR,LF,BELL,'Can''t create [UNUSED].BAD$'
BELLS:	DB	BELL,BELL,BELL,'$'
;
;
HELP:	LXI	D,USAGE
	CALL	PSTRNG
	JMP	WBOOT
USAGE:	DB	CR,LF
	DB	'Usage:',CR,LF,CR,LF
	DB	' FBAD [d:] ['
	DB	'$' OR 80H
	DB	'options]',CR,LF,CR,LF
	DB	'     d:  =  drive to check',CR,LF
	DB	'options  =  S       check system tracks',CR,LF
	DB	'            Sn0     n0 =  sector count for track 0',CR,LF
	DB	'            Sn0,n1  n1 =  sector count for sys trk > 0',CR,LF
	DB	'                     (default is '
	DB	DFSPT0/10 + '0', (DFSPT0 MOD 10) + '0'
	DB	', '
	DB	DFOSTK/10 + '0', (DFOSTK MOD 10) + '0'
	DB	')',CR,LF
	DB	'            X       same as  S  with different default SPT'
	DB	CR,LF
	DB	'                     (default is '
	DB	XSPT0/10 + '0', (XSPT0 MOD 10) + '0'
	DB	', '
	DB	XOSTK/10 + '0', (XOSTK MOD 10) + '0'
	DB	')',CR,LF
	DB	'            A       print "*" instead of track number'
	DB	CR,LF
	DB	'$'
;
;LOOK FOR OPTIONS FLAG (SPCHR)
;
GETOPT:
	LXI	H,TBUFF	;START AT BEGINNING OF LINE
	MOV	A,M
	ORA	A	;IF IT IS EMPTY
	RZ		;EXIT.
	INX	H	;POINT TO FIRST CHAR.
	LDA	FCB
	ORA	A	;WAS THERE A DRIVE SPEC.?
	JZ	FINDIT
	INX	H	;YES, SKIP OVER IT.
	INX	H
FINDIT:
	INX	H
	MOV	A,M	;GET A CHARACTER
	CPI	00H	;END OF LINE ?
	RZ		;CONTINUE.
	CPI	' '
	JZ	FINDIT	;SKIP SPACES.
	CPI	SPCHR	;OPTION FLAG ?
	JNZ	HELP	;NO, ERROR
FINDIT1:
	INX	H	;CHECK NEXT CHARACTER
	MOV	A,M
	CPI	00H	;END OF LINE ?
	RZ		; TEST DISK.
	CPI	' '
	JZ	FINDIT1	;SKIP SPACES
	CPI	'A'
	JZ	AOPT	;TOGGLE ASTERISK/TRACK NUMBER FLAG
	CPI	'S'
	JZ	SOPT	;TEST SYSTEM TRACKS
	CPI	'X'
	JZ	XOPT	;SET SPECIAL VALUE FOR SYSTEM TRACKS SPT
	JMP	HELP
;
AOPT:
	MVI	A,76
	STA	ASTRS	;INITIALIZE COLUMN COUNT
	JMP	FINDIT1	;LOOK FOR MORE OPTIONS
;
SOPT:
	MVI	A,1
	STA	SYSTST	;SET SYSTEM TRACK TEST FLAG.
;
; IF NUMERIC AFTER S, MUST BE TRACK ZERO SECTOR COUNT.
	INX	H
	MOV	A,M
	CALL	VALDEC	;NUMBER FROM 0 TO 9 ?
	JC	SOPT1	;NO, CHECK NEXT OPTION
	XCHG		;GET ADDRESS IN DE
	LXI	H,00	;INITIALIZE HL TO 0
	CALL	ATOH	;CONVERT TO HEX
	SHLD	SPT0	;SAVE SECTOR COUNT FOR FIRST TRACK
	XCHG		;RESTORE HL
;
; IF COMMA AFTER FIRST NUMBER, MUST BE SECTOR COUNT
; FOR OTHER SYSTEM TRACKS.
	MOV	A,M
	CPI	','
	JNZ	SOPT1
	INX	H
	MOV	A,M
	CALL	VALDEC
	JC	HELP	;NOT A VALID NUMBER, GIVE HELP
	XCHG
	LXI	H,00
	CALL	ATOH
	SHLD	OSTK
	XCHG
;
SOPT1:	DCX	H	;BACK UP TO NEXT CHAR.
	JMP	FINDIT1	;SEE IF MORE OPTIONS
;
;
XOPT:
	MVI	A,1
	STA	SYSTST	;SET SYSTEM TRACK TEST FLAG.
;
	PUSH	H
	LXI	H,XSPT0	;SPECIAL VALUE FOR SPT0
	SHLD	SPT0
	LXI	H,XOSTK	;SPECIAL VALUE FOR OTHER SYSTEM TRACK(S)
	SHLD	OSTK
	POP	H
	JMP	FINDIT1	;LOOK FOR MORE OPTIONS
;
;  ASCII TO HEX CONVERSION
;
ATOH:
	MOV	B,H	;B = 00
ATOH1:
	LDAX	D	;GET CHARACTER
	CALL	VALDEC	;MAKE 0-9, SEE IF VALID
	RC		;NOT DECIMAL, STOP CONVERSION
	PUSH	D
	MOV	D,H
	MOV	E,L	;DE = HL
	DAD	H	;2*N
	DAD	H	;4*N
	DAD	D	;5*N
	DAD	H	;10*N
	POP	D
	MOV	C,A
	DAD	B	;ADD IN NEXT CHAR
	INX	D	;POINT TO NEXT CHAR
	JMP	ATOH1	;PROCESS IT
;
;CONVERT ASCII DIGIT TO DECIMAL NUMBER
;RETURN WITH CY = 0 IF VALID DIGIT 0-9
;
VALDEC:
	SUI	'0'	;SUBTRACT ASCII OFFSET
	RC		; < 0
	CPI	10	; > 9
	CMC		;ADJUST CARRY FLAG
	RET
;
;
;=======================================================================
;
;			     SUBROUTINES
;
;=======================================================================
;
;
ADD24:	PUSH	H
	ORA	A		; Clear carry
	MOV	A,M		; Do 24-bit add
	ADC	C
	MOV	M,A
	INX	H
	MOV	A,M
	ADC	B
	MOV	M,A
	INX	H
	MOV	A,M
	ADC	B
	MOV	M,A
	POP	H
	RET
;.....
;
;
; CR/LF to the console
;
CRLF:	MVI	A,CR
	CALL	TYPE
	MVI	A,LF		; Fall into 'type'
;
TYPE:	PUSH	B
	PUSH	D
	PUSH	H
	MOV	E,A		; Character to 'E' for CP/M
	MVI	C,2		; Print console function
	CALL	BDOS		; Print character
	POP	H
	POP	D
	POP	B
	RET
;.....
;
;
; Decimal output routine - If the disk size is at or near the maximum of
; 65,536 records, the record addition overflows 16 bits.  The counter
; has been increased to 24 bits.  This routine destroys the counter-
; value it is called with.
;
DECOUT:	PUSH	B
	PUSH	D
	LXI	B,-10
	LXI	D,-1
;
DECOU2:	CALL	ADD24
	INX	D
	JC	DECOU2
	LXI	B,10
	CALL	ADD24
	MOV	A,D
	ORA	E
	PUSH	H
	MOV	A,M
	MOV	M,E
	MOV	E,A
	INX	H
	MOV	A,M
	MOV	M,D
	MOV	D,A
	INX	H
	MVI	M,0
	POP	H
	CNZ	DECOUT		; Recursive call..
	MOV	A,E
	ADI	'0'
	CALL	TYPE
	POP	D
	POP	B
	RET
;.....
;
;
; Collect the number of '1' bits in 'A' as a count in 'C'
;
COLECT:	MVI	B,8
;
COLOP:	RAL
	JNC	COSKIP
	INR	C
;
COSKIP:	DCR	B
	JNZ	COLOP
	RET
;.....
;
;
; Subroutine to determine the number of groups reserved for the directory
;
GETDIR:	MVI	C,0		; Initialize bit count
	LDA	AL0		; Read directory group bits
	CALL	COLECT		; Collect count of directory groups..
	LDA	AL1		; In 'C'
	CALL	COLECT
	MOV	L,C
	MVI	H,0		; 'BC' now has a default start group #
	SHLD	DIRBKS		; Save for later
	RET
;.....
;
;
; Print byte in accumulator in hex
;
HEXO:	PUSH	PSW		; Save for second half
	RRC			; Move into position
	RRC
	RRC
	RRC
	CALL	NYBBLE		; Print most significant nybble
	POP	PSW
;
NYBBLE:	ANI	0FH		; Low nybble only
	ADI	90H
	DAA
	ACI	40H
	DAA
	JMP	TYPE		; Print in hex
;.....
;
;
; Total record count routine (24-bit)
;
INCREC:	LXI	H,RECCNT	; Point to record count
	MVI	A,1		; Add 1
	ORA	A		; Clear carry
	ADC	M		; Add current total
	MOV	M,A		; And save 1st byte
	RNC			; Return if no carry
	INX	H		; Increment pointer
	MVI	A,0		; Reset 'A'
	ADC	M		; Add 2nd byte
	MOV	M,A		; And save
	RNC			; Return if no carry
	INX	H		; Increment pointer
	MVI	A,0		; And again for 3rd byte
	ADC	M
	MOV	M,A
	RET
;.....
;
;
; Routine to fill in disk parameters
;
LOGIT:	LDA	VER2FL
	ORA	A		; If not CP/M 2.x then
	JZ	LOG14		; Do it as 1.4
	LXI	D,DPB		; Then move to local
	MVI	B,DPBLEN	; Workspace
	CALL	MOVE
	RET
;.....
;
;
LOG14:	LHLD	BDOS+1		; First find 1.4 BDOS
	MVI	L,0
	LXI	D,DPBOFF	; Then offset to 1.4's DPB
	DAD	D
	MVI	D,0		; So 8 bit parms will be 16
	MOV	E,M		; Now move parms
	INX	H		; Down from BDOS disk parameter block
	XCHG			; To ours
	SHLD	SPT
	XCHG
	MOV	E,M
	INX	H
	XCHG
	SHLD	DRM
	XCHG
	MOV	A,M
	INX	H
	STA	BSH
	MOV	A,M
	INX	H
	STA	BLM
	MOV	E,M
	INX	H
	XCHG
	SHLD	DSM
	XCHG
	MOV	E,M
	INX	H
	XCHG
	SHLD	AL0
	XCHG
	MOV	E,M
	XCHG
	SHLD	SYSTRK
	RET
;.....
;
;
; Move from (HL) to (DE), with count in (BC)
;
MOVE:	MOV	A,M
	STAX	D
	INX	H
	INX	D
	DCR	B
	JNZ	MOVE
	RET
;.....
;
;
; Negate HL
;
NEG:	MOV	A,L
	CMA
	MOV	L,A
	MOV	A,H
	CMA
	MOV	H,A
	INX	H
	RET
;.....
;
;
; Shift HL right one place
;
ROTRHL:	ORA	A		; Clear carry
	MOV	A,H		; Get hihg byte
	RAR			; Shift right
	MOV	H,A		; Put back
	MOV	A,L		; Get low byte
	RAR			; Shift with carry
	MOV	L,A		; Put back
	RET
;.....
;
;
; Subroutine to test console for CTL-C abort
;
STOP:	CALL	CSTS		; Get console status
	ORA	A		; Test flags on zero
	RZ			; Return if no character
	CALL	CI		; Get the character
	ANI	7FH		; Some teminals set parity bit
	CPI	'C'-40H		; Is it CTL-C?
	RNZ			; Return if not
	LXI	D,ABORTM	; Exit with message
	CALL	PSTRNG
	JMP	WBOOT		; Then leave
;
CSTS:	LDA	VER2FL		; One way for 2.x or higher...
	ORA	A		; Check for non-zero
	JZ	CSTS14
	MVI	C,11
	JMP	BDOS
;
CSTS14:	LHLD	0001H		; Find BIOS in memory
	MVI	L,6		; Offset to console status
	PCHL
;
CI:	LDA	VER2FL
	ORA	A
	JZ	CI14
	MVI	C,1
	JMP	BDOS
;
CI14:	LHLD	1		; Now find console input
	MVI	L,9		; Offset for CONIN
	PCHL
;.....
;
;
; Subtract DE from HL
;
SUBDE:	MOV	A,L
	SUB	E
	MOV	L,A
	MOV	A,H
	SBB	D
	MOV	H,A
	RET
;.....
;
;
; Zero all of memory to hold DM values
;
ZMEM:	LHLD	BDOS+1		; Get top-of-memory pointer
	LXI	D,DM		; Starting point
	CALL	SUBDE		; Get number of bytes
	MOV	B,H
	MOV	C,L
	XCHG			; Begin in 'HL', count in 'BC'
;
ZLOOP:	MVI	M,0		; Zero a byte
	INX	H		; Point past
	DCX	B		; Count down
	MOV	A,B
	ORA	C
	JNZ	ZLOOP
	RET
;.....
;
;
SIGNON:	DB	CR,LF,'FBAD V',(VERS/10 + '0'),(VERS MOD 10)+'0','B'
	DB	' - Bad record lockout program - (^C to abort)',CR,LF,'$'
ABORTM:	DB	CR,LF,'Test aborted by CTL-C','$'
BBMSG:	DB	CR,LF,'Bad block: $'
SYSMSG:	DB	' system records read',CR,LF,'$'
RECMSG:	DB	' directory+data records read',CR,LF,'$'
TRKMSG:	DB	CR,'Track $'
NOMSG:	DB	'No$'
ENDMSG:	DB	' bad blocks found',CR,LF,'$'
TDAMSG:	DB	CR,LF,'Testing data area...',CR,LF,'$'
TSTMSG:	DB	CR,LF,'Testing system tracks...',CR,LF,'$'
TDRMSG:	DB	CR,LF,'Testing directory area...',CR,LF,'$'
DIROFS:	DB	0		; Offset of directory entry in DMA buffer
BFCB:	DB	0,'[UNUSED]BAD',0,0,0,0
FCBDM:	DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
CMSG1:	DB	CR,LF,'Press C to continue on the same drive'
	DB	CR,LF,'Any other key aborts to CP/M $'
;
;
SPTSAV:	DW	00	;SAVE SPT FOR DATA TRACKS
;
; The disk parameter block is moved here from CP/M
;
DPB	EQU	$	; Disk parameter block (copy)
SPT:	DS	2	; Records per track
BSH:	DS	1	; Block shift
BLM:	DS	1	; Block mask
EXM:	DS	1	; Extent mask
DSM:	DS	2	; Maximum block number
DRM:	DS	2	; Maximum directory block number
AL0:	DS	1	; Directory allocation vector
AL1:	DS	1	; Directory allocation vector
CKS:	DS	2	; Checked directory entries
SYSTRK:	DS	2	; System tracks
DPBLEN	EQU	$-DPB	; Length of disk parameter block
;
BLKEXT:	DB	0	; Blocks per extent
DIRBKS:	DW	0	; Calculated # of directory blocks
VER2FL:	DB	0	; Version 2.x flag, non-0 ==> 2.x or higher
BADBKS:	DB	0,0,0	; Count of bad blocks
RECORD:	DW	0	; Current record number
TRACK:	DB	0,0	; Current track number
PHYREC:	DW	0	; Current physical record number
RECTBL:	DW	0	; Record skew table pointer
EXTNUM:	DB	0FFH	; Used for updating extent number
DMCNT:	DW	0	; Number of bad records
DMPTR:	DW	DM	; Pointer to next block identification
RECCNT:	DB	0,0,0	; Number of records read
COLUMN:	DB	0	; CRT column counter
DECWRK:	DB	0,0,0	; Track-storage for decout
ORIGDR:	DS	1	; Original drive spec from FCB stored here
SHOFLG:	DS	0	;IF NON-ZERO, DISPLAY CURRENT TRACK NUMBER
;
;
	DS	200	; Room for 100 level stack
STACK	EQU	$	; Our stack
;
DM	EQU	$	; Bad block allocation map
;
;
	END


