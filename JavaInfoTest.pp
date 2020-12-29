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

{$MODE OBJFPC}
{$H+}
{$APPTYPE CONSOLE}

program
  JavaInfoTest;

uses
  windows;

type
  TDLLIntFunc = function(): longint; stdcall;
  TDLLStrFunc = function(Buffer: pwidechar; NumChars: DWORD): DWORD; stdcall;

var
  DLLHandle: HMODULE;
  GetJavaHome, GetJavaVersion: TDLLStrFunc;
  IsJava64Bit, IsJavaInstalled: TDLLIntFunc;

function GetString(var DLLStrFunc: TDLLStrFunc): unicodestring;
  var
    NumChars: DWORD;
    OutStr: unicodestring;
  begin
  result := '';
  NumChars := DLLStrFunc(nil, 0);
  SetLength(OutStr, NumChars);
  if DLLStrFunc(pwidechar(OutStr), NumChars) > 0 then
    result := OutStr;
  end;

begin
  DLLHandle := LoadLibrary('JavaInfo.dll');
  ExitCode := GetLastError();
  if ExitCode = 0 then
    begin
    GetJavaHome := TDLLStrFunc(GetProcAddress(DLLHandle, 'GetJavaHome'));
    GetJavaVersion := TDLLStrFunc(GetProcAddress(DLLHandle, 'GetJavaVersion'));
    IsJava64Bit := TDLLIntFunc(GetProcAddress(DLLHandle, 'IsJava64Bit'));
    IsJavaInstalled := TDLLIntFunc(GetProcAddress(DLLHandle, 'IsJavaInstalled'));
    if IsJavaInstalled() <> 0 then
      begin
      WriteLn('Java home: ', GetString(GetJavaHome));
      WriteLn('Java version: ', GetString(GetJavaVersion));
      WriteLn('Is Java 64 bit? ', IsJava64Bit() = 1);
      end
    else
      WriteLn('Java not found');
    FreeLibrary(DLLHandle);
    end
  else
    WriteLn('Unable to load JavaInfo.dll');
end.
