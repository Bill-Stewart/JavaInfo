{ Copyright (C) 2020 by Bill Stewart (bstewart at iname.com)

  This program is free software: you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free Software
  Foundation, either version 3 of the License, or (at your option) any later
  version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
  details.

  You should have received a copy of the GNU General Public License
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

  // Example using a widechar pointer
  function GetJavaHomeDir(): unicodestring;
    var
      NumChars, BufSize: DWORD;
      OutStr: pwidechar;
    begin
    result := '';
    // First call: Get number of characters needed
    NumChars := GetJavaHome(nil, 0);
    // Specify buffer size (+ space for null terminator character)
    BufSize := NumChars * SizeOf(widechar) + SizeOf(widechar);
    // Allocate the buffer
    GetMem(OutStr, BufSize);
    // Second call: Get the string
    if GetJavaHome(OutStr, NumChars) > 0 then
      result := OutStr;
    FreeMem(OutStr, BufSize);
    end;

  // Example using a unicode string
  function GetJavaHomeDir(): unicodestring;
    var
      NumChars: DWORD;
      OutStr: unicodestring;
    begin
    result := '';
    // First call: Get number of characters needed
    NumChars := GetJavaHome(nil, 0);
    // Allocate space for the string (accounts for null terminator)
    SetLength(OutStr, NumChars);
    // Second call: Get the string
    if GetJavaHome(pwidechar(OutStr), NumChars) > 0 then
      result := OutStr;
    end;

}

{$MODE OBJFPC}
{$H+}
{$R *.res}

library
  JavaInfo;

uses
  wsJavaInfo;

type
  TStringFunction = function(): unicodestring;

// Retrieves whether a specified binary is 64-bit or not to the Is64Bit
// parameter. Returns 0 for success, or non-zero for failure. If successful,
// value pointed to by Is64Bit will be 0 if not 64-bit, or 1 otherwise.
function IsBinary64Bit(FileName: pwidechar; Is64Bit: PDWORD): DWORD; stdcall;
  var
    Is64: boolean;
  begin
  result := wsIsBinary64Bit(FileName, Is64);
  if result = 0 then
    begin
    if Is64 then Is64Bit^ := 1 else Is64Bit^ := 0;
    end;
  end;

// Copies Source to Dest.
procedure CopyString(const Source: unicodestring; Dest: pwidechar);
  var
    NumChars: DWORD;
  begin
  NumChars := Length(Source);
  Move(Source[1], Dest^, NumChars * SizeOf(widechar));
  Dest[NumChars] := #0;
  end;

// First parameter is address of string function you want to call. Returns
// number of characters needed for output buffer, not including the terminating
// null character.
function GetString(var StringFunction: TStringFunction; Buffer: pwidechar; const NumChars: DWORD): DWORD;
  var
    OutStr: unicodestring;
  begin
  OutStr := StringFunction();
  if (Length(OutStr) > 0) and Assigned(Buffer) and (NumChars >= Length(OutStr)) then
    CopyString(OutStr, Buffer);
  result := Length(OutStr);
  end;

// Gets Java home directory into string buffer pointed to by PathName.
function GetJavaHome(PathName: pwidechar; NumChars: DWORD): DWORD; stdcall;
  var
    StringFunction: TStringFunction;
  begin
  StringFunction := @wsGetJavaHome;
  result := GetString(StringFunction, PathName, NumChars);
  end;

// Gets Java version string (a.b.c.d) into string buffer pointed to by Version.
function GetJavaVersion(Version: pwidechar; NumChars: DWORD): DWORD; stdcall;
  var
    StringFunction: TStringFunction;
  begin
  StringFunction := @wsGetJavaVersion;
  result := GetString(StringFunction, Version, NumChars);
  end;

// Returns 1 if Java installation detected or 0 otherwise.
function IsJavaInstalled(): DWORD; stdcall;
  begin
  if wsIsJavaInstalled() then result := 1 else result := 0;
  end;

exports
  IsBinary64Bit,
  IsJavaInstalled,
  GetJavaHome,
  GetJavaVersion;

end.
