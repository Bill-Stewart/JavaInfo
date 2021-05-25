{ Copyright (C) 2020-2021 by Bill Stewart (bstewart at iname.com)

  This program is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the Free
  Software Foundation; either version 3 of the License, or (at your option) any
  later version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE. See the GNU General Lesser Public License for more
  details.

  You should have received a copy of the GNU Lesser General Public License
  along with this program. If not, see https://www.gnu.org/licenses/.

}

{
  Note Regarding the GetJavaHome() and GetJavaVersion() Functions
  ===============================================================
  You must allocate a buffer to get the result strings from these functions. To
  determine the required buffer size, call the function with a null pointer for
  the first parameter and 0 for the second parameter. The function will return
  the number of characters required for the buffer, not including the
  terminating null character. Allocate the buffer (don't forget to account for
  the terminating null character), then call the function again.

  // Example using WideChar pointer
  function GetJavaHomeDir(): UnicodeString;
  var
    NumChars, BufSize: DWORD;
    OutStr: PWideChar;
  begin
    result := '';
    // First call: Get number of characters needed
    NumChars := GetJavaHome(nil, 0);
    // Specify buffer size (+ space for null terminator character)
    BufSize  := NumChars * SizeOf(WideChar) + SizeOf(WideChar);
    // Allocate the buffer
    GetMem(OutStr, BufSize);
    // Second call: Get the string
    if GetJavaHome(OutStr, NumChars) > 0 then
      result := OutStr;
    FreeMem(OutStr, BufSize);
  end;

  // Example using UnicodeString
  function GetJavaHomeDir(): UnicodeString;
  var
    NumChars: DWORD;
    OutStr: UnicodeString;
  begin
    result := '';
    // First call: Get number of characters needed
    NumChars := GetJavaHome(nil, 0);
    // Allocate space for the string (accounts for null terminator)
    SetLength(OutStr, NumChars);
    // Second call: Get the string
    if GetJavaHome(PWideChar(OutStr), NumChars) > 0 then
      result := OutStr;
  end;

}

{$MODE OBJFPC}
{$H+}
{$R *.res}

library JavaInfo;

uses
  Windows,
  wsJavaInfo;

type
  TStringFunction = function(): UnicodeString;

// Copies Source to Dest.
procedure CopyString(const Source: UnicodeString; Dest: PWideChar);
var
  NumChars: DWORD;
begin
  NumChars := Length(Source);
  Move(Source[1], Dest^, NumChars * SizeOf(WideChar));
  Dest[NumChars] := #0;
end;

// First parameter is address of string function you want to call. Returns
// number of characters needed for output buffer, not including the terminating
// null character.
function GetString(var StringFunction: TStringFunction; Buffer: PWideChar; const NumChars: DWORD): DWORD;
var
  OutStr: UnicodeString;
begin
  OutStr := StringFunction();
  if (Length(OutStr) > 0) and Assigned(Buffer) and (NumChars >= Length(OutStr)) then
    CopyString(OutStr, Buffer);
  result := Length(OutStr);
end;

// Gets Java home directory into string buffer pointed to by PathName.
function GetJavaHome(PathName: PWideChar; NumChars: DWORD): DWORD; stdcall;
var
  StringFunction: TStringFunction;
begin
  StringFunction := @wsGetJavaHome;
  result := GetString(StringFunction, PathName, NumChars);
end;

// Gets Java version string (a.b.c.d) into string buffer pointed to by Version.
function GetJavaVersion(Version: PWideChar; NumChars: DWORD): DWORD; stdcall;
var
  StringFunction: TStringFunction;
begin
  StringFunction := @wsGetJavaVersion;
  result := GetString(StringFunction, Version, NumChars);
end;

// Retrieves whether a specified binary is 64-bit or not to the Is64Bit
// parameter. Returns 0 for success, or non-zero for failure. If successful,
// value pointed to by Is64Bit will be 0 if not 64-bit, or 1 otherwise.
function IsBinary64Bit(FileName: PWideChar; Is64Bit: PDWORD): DWORD; stdcall;
var
  Is64: Boolean;
begin
  result := wsIsBinary64Bit(FileName, Is64);
  if result = 0 then
  begin
    if Is64 then
      Is64Bit^ := 1
    else
      Is64Bit^ := 0;
  end;
end;

// Returns 1 if Java installation detected or 0 otherwise.
function IsJavaInstalled(): DWORD; stdcall;
begin
  if wsIsJavaInstalled() then
    result := 1
  else
    result := 0;
end;

// Retrieves whether the installed Java version is at least the specified
// version to the VersionOK parameter. Returns 0 for success, or non-zero for
// failure. If successful, the value pointed to by VersionOK will be 1 if the
// installed Java version is at least the specified version, or 0 otherwise.
function IsJavaMinimumVersion(Version: PWideChar; VersionOK: PDWORD): DWORD; stdcall;
var
  IsOK: Boolean;
begin
  if wsIsJavaMinimumVersion(Version, IsOK) then
  begin
    result := ERROR_SUCCESS;
    if IsOK then
      VersionOK^ := 1
    else
      VersionOK^ := 0;
  end
  else
    result := ERROR_INVALID_PARAMETER;
end;

exports
  GetJavaHome,
  GetJavaVersion,
  IsBinary64Bit,
  IsJavaInstalled,
  IsJavaMinimumVersion;

end.
