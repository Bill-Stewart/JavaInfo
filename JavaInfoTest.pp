{ Copyright (C) 2020-2023 by Bill Stewart (bstewart at iname.com)

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
{$MODESWITCH UNICODESTRINGS}
{$APPTYPE GUI}

program JavaInfoTest;

uses
  Windows;

type
  TGetDWORD = function(): DWORD; stdcall;
  TGetString = function(Buffer: PChar; NumChars: DWORD): DWORD; stdcall;
  TIsBinary64Bit = function(FileName: PChar; Is64Bit: PDWORD): DWORD; stdcall;

var
  DLLHandle: HMODULE;
  IsJavaInstalled: TGetDWORD;
  GetJavaHome, GetJavaJVMPath, GetJavaVersion: TGetString;
  IsBinary64Bit: TIsBinary64Bit;
  JavaHome, JavaBinary, JavaJVMPath, JavaVersion, BinaryType, Msg: string;
  Is64Bit: DWORD;

procedure MsgBox(const Msg: string; const MsgBoxType: UINT);
begin
  MessageBoxW(0, PChar(Msg), 'JavaInfo.dll Test', MsgBoxType or MB_OK);
end;

function GetString(var Func: TGetString): string;
var
  NumChars: DWORD;
  OutStr: string;
begin
  result := '';
  NumChars := Func(nil, 0);
  SetLength(OutStr, NumChars);
  if Func(PChar(OutStr), NumChars) > 0 then
    result := OutStr;
end;

begin
  DLLHandle := LoadLibraryW('JavaInfo.dll');  // LPCWSTR lpLibFileName
  if DLLHandle = 0 then
    ExitCode := GetLastError()
  else
    ExitCode := 0;
  if ExitCode <> 0 then
  begin
    MsgBox('Unable to load JavaInfo.dll.', MB_ICONERROR);
    exit();
  end;
  GetJavaHome := TGetString(GetProcAddress(DLLHandle,  // HMODULE hModule
    'GetJavaHome'));                                   // LPCSTR  lpProcName
  GetJavaJVMPath := TGetString(GetProcAddress(DLLHandle,  // HMODULE hModule
    'GetJavaJVMPath'));                                   // LPCSTR  lpProcName
  GetJavaVersion := TGetString(GetProcAddress(DLLHandle,  // HMODULE hModule
    'GetJavaVersion'));                                   // LPCSTR  lpProcName
  IsBinary64Bit := TIsBinary64Bit(GetProcAddress(DLLHandle,  // HMODULE hModule
    'IsBinary64Bit'));                                       // LPCSTR  lpProcName
  IsJavaInstalled := TGetDWORD(GetProcAddress(DLLHandle,  // HMODULE hModule
    'IsJavaInstalled'));                                  // LPCSTR  lpProcName
  if IsJavaInstalled() = 0 then
    MsgBox('JavaInfo.dll did not detect a Java installation.', 0)
  else
  begin
    JavaHome := GetString(GetJavaHome);
    JavaBinary := JavaHome + '\bin\java.exe';
    if IsBinary64Bit(PChar(JavaBinary), @Is64Bit) = 0 then
    begin
      if Is64Bit = 1 then
        BinaryType := '64-bit'
      else
        BinaryType := '32-bit';
    end
    else
      BinaryType := 'unknown';
    JavaJVMPath := GetString(GetJavaJVMPath);
    JavaVersion := GetString(GetJavaVersion);
    Msg := 'Java home: ' + JavaHome + #10
      + 'jvm.dll path: ' + JavaJVMPath + #10
      + 'Java file version: ' + JavaVersion + #10
      + 'Platform: ' + BinaryType;
    MsgBox(Msg, 0);
  end;
  FreeLibrary(DLLHandle);  // HMODULE hLibModule
end.
