if not A_IsAdmin
{
   Run *RunAs "%A_ScriptFullPath%"  ; Requires v1.0.92.01+
   ExitApp
}


#NoEnv
#MaxHotkeysPerInterval 99000000
#HotkeyInterval 99000000
#KeyHistory 0
#InstallKeybdHook
#InstallMouseHook
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
ListLines Off
Process, Priority, , H
SetBatchLines, -1
SetKeyDelay, -1, -1
SetMouseDelay, -1
SetDefaultMouseSpeed, 0
SetWinDelay, 0
SetControlDelay, 0
SendMode Input


global delimiters := "! ""$`%&'()*+,-./:;<=>?@[\]^``{|}~"

global delimRegEx := 
delimRegEx := StrReplace(delimiters, "\", "\\")
delimRegEx := StrReplace(delimRegEx, "]", "\]")
delimRegEx := StrReplace(delimRegEx, "^", "\^")
delimRegEx := StrReplace(delimRegEx, "-", "\-")
delimRegEx := StrReplace(delimRegEx, " ", "\s")
delimRegEx := "[^" . delimRegEx . "]+"

global needsClick := false
/*Loop
{
	needsClick := A_TimeIdleMouse < A_TimeIdleKeyboard
	Sleep, 100
}
*/


getClip() {
	res:= ""

	ClipboardOld:=ClipboardAll
	Clipboard:=""
	While clipboard
		Sleep 5 

	SendInput, ^{c}
	ClipWait, 0.1
	if(!ErrorLevel)
	{
		res:=Clipboard
	} 

	Clipboard:=ClipboardOld
	return res
}

; select the word at the caret position (or mouse position for non editable areas) and return it
SelectWord(allowNonEditable:=true)
{
	; special handling of windows that respond properly to selection or caret movements
	WinGetTitle, title, A
	special := InStr(title, "Mozilla Thunderbird")

	res := getClip()
	resLen := StrLen(res)

	if (resLen = 0 && needsClick) {
		Click 1
	}

	charLeft := leftLen := charRight := rightLen :=

	if (!special) {
		; get another character on the left
		SendInput, +{left}
		charLeft := getClip()
		leftLen := StrLen(charLeft)
		if (leftLen != resLen) ; if we're not at the begining of the first line revert selection
		{
			SendInput, +{right}
		}

		; get another character on the right
		SendInput, +{right}
		charRight := getClip()
		rightLen := StrLen(charRight)
		if (rightLen != resLen) ; if we're not at the end of the last line return selection
		{
			SendInput, +{left}
		}
		
		;OutputDebug _res_%res%_

		; work around editors which redefines ^c without selection to copy line
		if (resLen > 0 && (resLen>leftLen || resLen>rightLen) && (leftLen==1 || rightLen==1))
		{
			res := ""	
			resLen = 0
		}
	} 

	if (resLen > 0)
	{
		Clipboard := res	
		return res
	}

	; select word

	if (special || (leftLen == 0 && rightLen == 0)) { ; a non editable area
		if (!allowNonEditable) {
			return
		}
		
		CoordMode, Mouse, Screen
		MouseGetPos, X_1, Y_1, ID_1, Control_1 
		X_1 += 3 
		MouseMove, %X_1%, %Y_1% ; shift cursor a bit to prevent dblclick from selecting the whole line
		Click 2
		res := getClip()
		X_1 -= 3 ; restore mouse
		MouseMove, %X_1%, %Y_1%
	
	} else { ; editable area
		if (InStr(delimiters, charLeft)) { ; char on the left is aq delimiter
			SendInput +^{Right}
		} else { 
			SendInput ^{Left}+^{Right} ; char on the left is alphanumeric
		}
		res := getClip()
	}
		
	; trim non alnum 
	fw := RegExMatch(res, delimRegEx, alnumRes) -1

	len := StrLen(alnumRes)
	bw := StrLen(res) - fw - len  

	if (fw < 0) { ; no alnum
		SendInput {left}
		res :=
	} else if (fw > 0 && !special) { ; leading (and triling) non alnum
		SendInput {left}{right %fw%}+{right %len%}
		res := alnumRes
	} else if (bw > 0) { ; trailing non alnum (faster)
		SendInput +{left %bw%}
		res := alnumRes
	}
  
	return res
}


CopyWord()
{
	res := SelectWord(true)
	if (res != "") {
		Clipboard := res
	}
}
	
PasteWord() {
	res := SelectWord(false)
	if (res != "") {
		SendInput {Del}^v
	}
}


DelWord() {
	res := SelectWord(false)
	if (res != "") {
		SendInput {Del}
	}
}


CutWord() {
	res := SelectWord(false)
	if (res != "") {
		Clipboard := res
		SendInput {Del}
	}
}

findWord() {
	res := SelectWord(true)
	if (res != "") {
		Clipboard := res
		SendInput ^f
		Sleep 20
		SendInput ^v
	}
}


#c::
CopyWord()
return

#v::
PasteWord()
return

#s::
SelectWord()
return

#x::
CutWord()
return

#d::
DelWord()
return


RAlt::
KeyWait, RAlt
KeyWait, RAlt, D, T0.12
if (ErrorLevel = 1) {
	CopyWord()
} else {
	CutWord()
}
SendInput {RAlt up}
return

RWin::
KeyWait, RWin
KeyWait, RWin, D, T0.12
if (ErrorLevel = 1) {
	SendInput ^v
} else {
	PasteWord()
}
SendInput {RWin up}
return

/*
RCtrl::
KeyWait, RCtrl
KeyWait, RCtrl, D, T0.12
if (ErrorLevel = 1) {
	SendInput ^v
} else {
	PasteWord()
}
SendInput {RCtrl up}
return
*/

/*
RCtrl::
KeyWait, RCtrl
KeyWait, RCtrl, D, T0.12
if (ErrorLevel = 1) {
	findWord()
} else {
	SendInput ^f
	Sleep 20
	SendInput ^v
}
SendInput {RCtrl up}
return
*/


/*
HookShortLongHandlers(hk, funShort, funLong, tilde:=false) {
	Static funsShort := {}, funsLong := {}
	funsShort[hk] := Func(funShort), funsLong[hk] := Func(funLong)
	if (tilde=true) {
		hk:="~"hk
	}
	Hotkey, %hk%, Hotkey_Handle
	Return
Hotkey_Handle:
	tilde:=(InStr(A_ThisHotkey, "~")!=0)
	if (tilde=true) {
		hk := StrReplace(A_ThisHotkey, "~", "")
		KeyWait, %hk%, L T0.3 
	} else {
		hk := A_ThisHotkey
		KeyWait, %hk%, T0.3 
	}
	err := ErrorLevel
	SendInput {%hk% up}
	If %err% { ; long press
		funsLong[hk].()
	} else { ; short press
		funsShort[hk].()
	}
	Keywait, %hk%
	return
}

HookShortLongHandlers("RAlt", "XCopy", "XCut")
HookShortLongHandlers("RWin", "Paste", "XPaste")
HookShortLongHandlers("AppsKey", "Paste", "XPaste")
;HookShortLongHandlers("RCtrl", "Paste", "XPaste", true)
*/

