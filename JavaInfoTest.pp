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
{$APPTYPE CONSOLE}

program
  JavaInfoTest;

uses
  windows;

type
  TIsBinary64Bit = function(FileName: pwidechar; Is64Bit: PDWORD): DWORD; stdcall;
  TIsJavaInstalled = function(): DWORD; stdcall;
  TGetString = function(Buffer: pwidechar; NumChars: DWORD): DWORD; stdcall;

var
  DLLHandle: HMODULE;
  IsJavaInstalled: TIsJavaInstalled;
  IsBinary64Bit: TIsBinary64Bit;
  GetJavaHome, GetJavaVersion: TGetString;
  JavaBinary: unicodestring;
  Err, Is64Bit: DWORD;

function GetString(var Func: TGetString): unicodestring;
  var
    NumChars: DWORD;
    OutStr: unicodestring;
  begin
  result := '';
  NumChars := Func(nil, 0);
  SetLength(OutStr, NumChars);
  if Func(pwidechar(OutStr), NumChars) > 0 then
    result := OutStr;
  end;

begin
  DLLHandle := LoadLibrary('JavaInfo.dll');
  ExitCode := GetLastError();
  if ExitCode = 0 then
    begin
    IsBinary64Bit := TIsBinary64Bit(GetProcAddress(DLLHandle, 'IsBinary64Bit'));
    IsJavaInstalled := TIsJavaInstalled(GetProcAddress(DLLHandle, 'IsJavaInstalled'));
    GetJavaHome := TGetString(GetProcAddress(DLLHandle, 'GetJavaHome'));
    GetJavaVersion := TGetString(GetProcAddress(DLLHandle, 'GetJavaVersion'));
    if IsJavaInstalled() <> 0 then
      begin
      JavaBinary := GetString(GetJavaHome) + '\bin\java.exe';
      WriteLn('Java binary: ', JavaBinary);
      Write('Java binary type: ' );
      Err := IsBinary64Bit(pwidechar(JavaBinary), @Is64Bit);
      if Err = 0 then
        begin
        if Is64Bit = 0 then WriteLn('32-bit') else WriteLn('64-bit');
        end
      else
        WriteLn('Error - ', Err);
      WriteLn('Java version: ', GetString(GetJavaVersion));
      end
    else
      WriteLn('Java not found');
    FreeLibrary(DLLHandle);
    end
  else
    WriteLn('Unable to load JavaInfo.dll');
end.
