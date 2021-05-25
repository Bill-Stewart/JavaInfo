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

{$MODE OBJFPC}
{$H+}
{$APPTYPE GUI}

program JavaInfoTest;

uses
  Windows;

type
  TGetDWORD = function(): DWORD; stdcall;
  TGetString = function(Buffer: PWideChar; NumChars: DWORD): DWORD; stdcall;
  TIsBinary64Bit = function(FileName: PWideChar; Is64Bit: PDWORD): DWORD; stdcall;

var
  DLLHandle: HMODULE;
  IsJavaInstalled: TGetDWORD;
  GetJavaHome, GetJavaVersion: TGetString;
  IsBinary64Bit: TIsBinary64Bit;
  JavaHome, JavaBinary, JavaVersion, BinaryType, Msg: UnicodeString;
  Is64Bit: DWORD;

procedure MsgBox(const Msg: UnicodeString; const MsgBoxType: UINT);
begin
  MessageBoxW(0, PWideChar(Msg), 'JavaInfo.dll Test', MsgBoxType or MB_OK);
end;

function GetString(var Func: TGetString): UnicodeString;
var
  NumChars: DWORD;
  OutStr: UnicodeString;
begin
  result := '';
  NumChars := Func(nil, 0);
  SetLength(OutStr, NumChars);
  if Func(PWideChar(OutStr), NumChars) > 0 then
    result := OutStr;
end;

begin
  DLLHandle := LoadLibrary('JavaInfo.dll');
  if DLLHandle = 0 then
    ExitCode := GetLastError()
  else
    ExitCode := 0;
  if ExitCode <> 0 then
  begin
    MsgBox('Unable to load JavaInfo.dll.', MB_ICONERROR);
    exit();
  end;
  GetJavaHome := TGetString(GetProcAddress(DLLHandle, 'GetJavaHome'));
  GetJavaVersion := TGetString(GetProcAddress(DLLHandle, 'GetJavaVersion'));
  IsBinary64Bit := TIsBinary64Bit(GetProcAddress(DLLHandle, 'IsBinary64Bit'));
  IsJavaInstalled := TGetDWORD(GetProcAddress(DLLHandle, 'IsJavaInstalled'));
  if IsJavaInstalled() = 0 then
    MsgBox('JavaInfo.dll did not detect a Java installation.', 0)
  else
  begin
    JavaHome := GetString(GetJavaHome);
    JavaBinary := JavaHome + '\bin\java.exe';
    if IsBinary64Bit(PWideChar(JavaBinary), @Is64Bit) = 0 then
    begin
      if Is64Bit = 1 then
        BinaryType := '64-bit'
      else
        BinaryType := '32-bit';
    end
    else
      BinaryType := 'unknown';
    JavaVersion := GetString(GetJavaVersion);
    Msg := 'Java home: ' + JavaHome + #10 + 'Java file version: ' + JavaVersion + #10 +
      'Platform: ' + BinaryType;
    MsgBox(Msg, 0);
  end;
  FreeLibrary(DLLHandle);
end.
