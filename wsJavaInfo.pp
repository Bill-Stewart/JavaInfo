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

unit
  wsJavaInfo;

interface

// If Java installation found, returns path of Java home directory
function wsGetJavaHome(): unicodestring;

// If Java installation found, returns version number of java.exe as a string
// (a.b.c.d)
function wsGetJavaVersion(): unicodestring;

// If Java installation found, returns true if java.exe is 64-bit or false
// otherwise
function wsIsJava64Bit(): boolean;

// Returns true if a Java installation was found, or false otherwise
function wsIsJavaInstalled(): boolean;

implementation

uses
  windows,
  wsUtilArch,
  wsUtilEnv,
  wsUtilFile,
  wsUtilReg,
  wsUtilStr;

var
  JavaHome, JavaVersion: unicodestring;
  JavaIs64Bit: boolean;

// Tries 3 ways to detect a Java installation:
// 1. Search JavaSoft registry subkeys and return JavaHome value for latest
//    version
// 2. If previous search fails, use the JAVA_HOME, JDK_HOME, or JRE_HOME
//    environment variable (whichever is defined first, in that order)
// 3. If previous searches fail, search directories in the path for java.exe
function FindJavaHome(): unicodestring;
  var
    RootKey: HKEY;
    StringList, SubKeyNames: TArrayOfString;
    I, J: longint;
    SubKeyExists: boolean;
    SubKeyName, LatestVersion: unicodestring;
  begin
  result := '';
  // Try #1: Search the registry
  RootKey := 0;
  SetLength(StringList, 4);
  StringList[0] := 'SOFTWARE\JavaSoft\Java Development Kit';
  StringList[1] := 'SOFTWARE\JavaSoft\JDK';
  StringList[2] := 'SOFTWARE\JavaSoft\Java Runtime Environment';
  StringList[3] := 'SOFTWARE\JavaSoft\JRE';
  for I := 0 to Length(StringList) - 1 do
    begin
    SubKeyExists := false;
    SubKeyName := StringList[I];
    if IsWin64() then
      begin
      SubKeyExists := RegKeyExists(HKEY_LOCAL_MACHINE_64, SubKeyName);
      if SubKeyExists then
        RootKey := HKEY_LOCAL_MACHINE_64
      else
        begin
        SubKeyExists := RegKeyExists(HKEY_LOCAL_MACHINE_32, SubKeyName);
        if SubKeyExists then RootKey := HKEY_LOCAL_MACHINE_32;
        end;
      end
    else
      begin
      SubKeyExists := RegKeyExists(HKEY_LOCAL_MACHINE, SubKeyName);
      if SubKeyExists then RootKey := HKEY_LOCAL_MACHINE;
      end;
    if SubKeyExists then
      begin
      LatestVersion := '0';
      if RegGetSubKeyNames(RootKey, SubKeyName, SubKeyNames) then
        begin
        for J := 0 to Length(SubKeyNames) - 1 do
          begin
          if CompareVersionStrings(SubKeyNames[J], LatestVersion) > 0 then
            LatestVersion := SubKeyNames[J];
          end;
        if RegQueryStringValue(RootKey, SubKeyName + '\' + LatestVersion, 'JavaHome', result) then
          begin
          while result[Length(result)] = '\' do
            result := Copy(result, 1, Length(result) - 1);
          break;
          end;
        end;
      end;
    end;
  // Try #2: Check environment variables
  if result = '' then
    begin
    SetLength(StringList, 3);
    StringList[0] := 'JAVA_HOME';
    StringList[1] := 'JDK_HOME';
    StringList[2] := 'JRE_HOME';
    for I := 0 to Length(StringList) - 1 do
      begin
      result := GetEnvVar(StringList[I]);
      if result <> '' then
        begin
        while result[Length(result)] = '\' do
          result := Copy(result, 1, Length(result) - 1);
        break;
        end;
      end;
    end;
  // Try #3: Search the path
  if result = '' then
    begin
    result := FileSearch('java.exe', GetEnvVar('Path'));
    if result <> '' then
      result := ExtractFileDir(ExtractFileDir(result));
    end;
  end;

procedure Init();
  var
    DirName, FileName, FileVersion: unicodestring;
  begin
  // Initialize unit vars
  JavaHome := '';
  JavaVersion := '';
  JavaIs64Bit := false;
  // Try to find Java home dir
  DirName := FindJavaHome();
  if DirName = '' then exit();
  if not DirExists(DirName) then exit();
  // Look for Java binary
  FileName := JoinPath(DirName, 'bin\java.exe');
  if not FileExists(FileName) then exit();
  // Try to get version number 
  FileVersion := GetFileVersion(FileName);
  if FileVersion = '' then exit();
  // Try to get binary type
  if IsImage64Bit(FileName, JavaIs64Bit) then
    begin
    JavaHome := DirName;
    JavaVersion := FileVersion;
    end;
  end;

function wsGetJavaHome(): unicodestring;
  begin
  Init();
  result := JavaHome;
  end;

function wsGetJavaVersion(): unicodestring;
  begin
  Init();
  result := JavaVersion;
  end;

function wsIsJava64Bit(): boolean;
  begin
  Init();
  result := JavaIs64Bit;
  end;

function wsIsJavaInstalled(): boolean;
  begin
  Init();
  result := (JavaHome <> '') and (JavaVersion <> '');
  end;

begin
end.