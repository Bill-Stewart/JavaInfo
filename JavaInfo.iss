; Copyright (C) 2020 by Bill Stewart (bstewart at iname.com)
;
; This program is free software: you can redistribute it and/or modify it under
; the terms of the GNU General Public License as published by the Free Software
; Foundation, either version 3 of the License, or (at your option) any later
; version.
;
; This program is distributed in the hope that it will be useful, but WITHOUT
; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
; FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
; details.
;
; You should have received a copy of the GNU General Public License
; along with this program. If not, see https://www.gnu.org/licenses/.

; JavaInfo.iss
; Sample Inno Setup (https://www.jrsoftware.org/isinfo.php) script
; demonstrating use of JavaInfo.dll; doesn't install anything; just displays a
; message box and exits

[Setup]
AppName=JavaInfo
AppVersion=1
UsePreviousAppDir=false
DefaultDirName={autopf}\JavaInfo
Uninstallable=false
OutputDir=.
OutputBaseFilename=JavaInfo
PrivilegesRequired=none

[Files]
Source: "x86\JavaInfo.dll"; Flags: dontcopy

[Messages]
SetupAppTitle=JavaInfo

[Code]

// Import functions from DLL - named with 'DLL' prefix so we can write our own
// 'wrapper' functions for ease of use

// Note 'var' parameter (pointer) for second parameter 
function DLLIsBinary64Bit(FileName: string; var Is64Bit: DWORD): DWORD;
  external 'IsBinary64Bit@files:JavaInfo.dll stdcall setuponly';
function DLLIsJavaInstalled(): DWORD;
  external 'IsJavaInstalled@files:JavaInfo.dll stdcall setuponly';
function DLLGetJavaHome(PathName: string; NumChars: DWORD): DWORD;
  external 'GetJavaHome@files:JavaInfo.dll stdcall setuponly';
function DLLGetJavaVersion(Version: string; NumChars: DWORD): DWORD;
  external 'GetJavaVersion@files:JavaInfo.dll stdcall setuponly';

// Wrapper for DLL function - returns true if specified file is a 64-bit
// binary, or false otherwise
function IsBinary64Bit(FileName: string): boolean;
  var
    Is64Bit: DWORD;
  begin
  result := false;
  if DLLIsBinary64Bit(FileName, Is64Bit) = 0 then
    if Is64Bit = 1 then result := true;
  end;

// Wrapper - returns true if DLL fuction returns 1, or false otherwise
function IsJavaInstalled(): boolean;
  begin
  result := DLLIsJavaInstalled() = 1;
  end;

// Wrapper - note two function calls, first to determine buffer size, and
// second to retrieve the string
function GetJavaHome(): string;
  var
    NumChars: DWORD;
    OutStr: string;
  begin
  result := '';
  NumChars := DLLGetJavaHome('', 0);
  SetLength(OutStr, NumChars);
  if DLLGetJavaHome(OutStr, NumChars) > 0 then
    result := OutStr;
  end;

// Wrapper - same note as above
function GetJavaVersion(): string;
  var
    NumChars: DWORD;
    OutStr: string;
  begin
  result := '';
  NumChars := DLLGetJavaVersion('', 0);
  SetLength(OutStr, NumChars);
  if DLLGetJavaVersion(OutStr, NumChars) > 0 then
    result := OutStr;
  end;

function BoolToStr(Bool: boolean): string;
  begin
  if Bool then result := 'Yes' else result := 'No';
  end;

function InitializeSetup(): boolean;
  var
    JavaHome, FileName, Msg: string;
  begin
  result := false;
  if IsJavaInstalled() then
    begin
    JavaHome := GetJavaHome();
    FileName := JavaHome + '\bin\java.exe';
    Msg := 'Home: ' + JavaHome + #10
      + 'Version: ' + GetJavaVersion() + #10
      + '64-bit? ' + BoolToStr(IsBinary64Bit(FileName));
    end
  else
    Msg := 'Java not detected';
  MsgBox(Msg, mbInformation, MB_OK);
  end;
