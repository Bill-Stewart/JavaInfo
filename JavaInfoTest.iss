; Copyright (C) 2020-2021 by Bill Stewart (bstewart at iname.com)
;
; This program is free software; you can redistribute it and/or modify it under
; the terms of the GNU Lesser General Public License as published by the Free
; Software Foundation; either version 3 of the License, or (at your option) any
; later version.
;
; This program is distributed in the hope that it will be useful, but WITHOUT
; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
; FOR A PARTICULAR PURPOSE. See the GNU General Lesser Public License for more
; details.
;
; You should have received a copy of the GNU Lesser General Public License
; along with this program. If not, see https://www.gnu.org/licenses/.

; JavaInfoTest.iss
; Sample Inno Setup (https://www.jrsoftware.org/isinfo.php) script
; demonstrating use of JavaInfo.dll; doesn't install anything

; Only works with Unicode versions of IS 5.6 or later, or IS 6.x or later (6.x
; and later versions are all Unicode)
#ifndef UNICODE
  #error This script requires Unicode Inno Setup
#endif

[Setup]
AppName=JavaInfoTest
AppVersion=1.3.0.0
UsePreviousAppDir=false
DefaultDirName={autopf}\JavaInfoTest
Uninstallable=false
OutputDir=.
OutputBaseFilename=JavaInfoTest
PrivilegesRequired=none

[Files]
Source: "x86\JavaInfo.dll"; Flags: dontcopy

[Messages]
ButtonNext=&Test
ButtonCancel=&Close
SetupAppTitle=JavaInfo
SetupWindowTitle=JavaInfo.dll Test

[Code]

var
  InputPage: TInputQueryWizardPage;

// Import functions from DLL - named with 'DLL' prefix so we can write our own
// 'wrapper' functions for ease of use
function DLLIsBinary64Bit(FileName: string; var Is64Bit: DWORD): DWORD;
  external 'IsBinary64Bit@files:JavaInfo.dll stdcall setuponly';
function DLLIsJavaInstalled(): DWORD;
  external 'IsJavaInstalled@files:JavaInfo.dll stdcall setuponly';
function DLLIsJavaMinimumVersion(Version: string; var VersionOK: DWORD): DWORD;
  external 'IsJavaMinimumVersion@files:JavaInfo.dll stdcall setuponly';
function DLLGetJavaHome(PathName: string; NumChars: DWORD): DWORD;
  external 'GetJavaHome@files:JavaInfo.dll stdcall setuponly';
function DLLGetJavaVersion(Version: string; NumChars: DWORD): DWORD;
  external 'GetJavaVersion@files:JavaInfo.dll stdcall setuponly';
// Note that 'var' parameters above are pointers

// Wrapper for IsBinary64Bit() DLL function
function IsBinary64Bit(const FileName: string): Boolean;
var
  Is64Bit: DWORD;
begin
  result := false;
  if DLLIsBinary64Bit(FileName, Is64Bit) = 0 then
    result := Is64Bit = 1;
end;

// Wrapper for IsJavaInstalled() DLL function
function IsJavaInstalled(): Boolean;
begin
  result := DLLIsJavaInstalled() = 1;
end;

// Wrapper for IsJavaMinimumVersion() DLL function
function IsJavaMinimumVersion(const Version: string): string;
var
  VersionOK: DWORD;
begin
  result := '';
  if DLLIsJavaMinimumVersion(Version, VersionOK) = 0 then
    if VersionOK = 1 then
      result := 'Yes'
    else
      result := 'No';
end;

// Wrapper for GetJavaHome() DLL function; note that we call the DLL function
// twice: The first call gets the required number of characters, and the second
// call gets the output string from the DLL
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

// Wrapper for GetJavaVersion() DLL function (same note as above)
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

function BoolToStr(const B: Boolean): string;
begin
  if B then
    result := 'Yes'
  else
    result := 'No';
end;

// Show content of a string array in a message box
procedure ShowStringArray(var A: TArrayOfString);
var
  Msg: string;
  I: LongInt;
begin
  if GetArrayLength(A) = 0 then
    MsgBox('Array length is 0', mbInformation, MB_OK)
  else
  begin
    Msg := '[0] ' + A[0];
    for I := 1 to GetArrayLength(A) - 1 do
      Msg := Msg + #10 + '[' + IntToStr(I) + '] ' + A[I];
    MsgBox(Msg, mbInformation, MB_OK);
  end;
end;

function InitializeSetup(): Boolean;
begin
  result := IsJavaInstalled();
  // Exits the wizard if Java is not detected
  if not result then
    MsgBox('JavaInfo.dll did not detect a Java installation.', mbInformation, MB_OK);
end;

procedure CancelButtonClick(CurPageID: Integer; var Cancel, Confirm: Boolean);
begin
  // Don't show the confirmation prompt when exiting
  Confirm := false;
end;

procedure InitializeWizard();
begin
  // Create input query page and text field for entering the Java version
  InputPage := CreateInputQueryPage(wpWelcome,
    'Minimum Java Version',
    'What minimum version of Java to you want to check for?',
    'Specify the minimum version of Java to check for, then click Test.');
  InputPage.Add('&Minimum Java version:', false);
end;

// Splits S into the array Dest using Delim as the delimiter
procedure StrSplit(S, Delim: string; var Dest: TArrayOfString);
var
  Temp: string;
  I, P: Integer;
begin
  Temp := S;
  I := StringChangeEx(Temp, Delim, '', true);
  SetArrayLength(Dest, I + 1);
  for I := 0 to GetArrayLength(Dest) - 1 do
  begin
    P := Pos(Delim, S);
    if P > 0 then
    begin
      Dest[I] := Copy(S, 1, P - 1);
      Delete(S, 1, P + Length(Delim) - 1);
    end
    else
      Dest[I] := S;
  end;
end;

// Returns a packed version number from an input string
function StrToPackedVersion(const Version: string): Int64;
var
  Parts: TArrayOfString;
  PartCount, I, Part: LongInt;
begin
  result := 0;
  StrSplit(Version, '.', Parts);
  PartCount := GetArrayLength(Parts);
  if Parts[0] = '' then
    exit;
  if PartCount < 4 then
  begin
    SetArrayLength(Parts, 4);
    // Missing parts are '0'
    for I := PartCount to 3 do
      Parts[I] := '0';
  end;
  // Return 0 if any part not numeric or out of range
  for I := 0 to 3 do
  begin
    Part := StrToIntDef(Parts[I], -1);
    if (Part < 0) or (Part > 65535) then
      exit;
  end;
  result := PackVersionComponents(StrToIntDef(Parts[0], 0),
    StrToIntDef(Parts[1], 0),
    StrToIntDef(Parts[2], 0),
    StrToIntDef(Parts[3], 0));
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  MinVersion, JavaHome, Message: string;
begin
  result := true;
  // Check if current page is the custom Java version page
  if CurPageID = InputPage.ID then
  begin
    // Disable 'Next' button (relabeled as 'Test')
    result := false;
    MinVersion := Trim(InputPage.Values[0]);
    if StrToPackedVersion(MinVersion) = 0 then
    begin
      MsgBox('Please specify a minimum Java version number.', mbError, MB_OK);
      WizardForm.ActiveControl := InputPage.Edits[0];
      InputPage.Edits[0].SelectAll();
    end
    else
    begin
      JavaHome := GetJavaHome();
      Message := 'Java home: ' + JavaHome + #10
        + 'Java version: ' + GetJavaVersion() + #10
        + 'Java is 64-bit: ' + BoolToStr(IsBinary64Bit(JavaHome + '\bin\java.exe')) + #10
        + 'At least version ' + MinVersion + ': ' + IsJavaMinimumVersion(MinVersion);
      MsgBox(Message, mbInformation, MB_OK);
    end;
  end;
end;
