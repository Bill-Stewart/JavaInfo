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

unit
  wsJavaInfo;

interface

// Gets whether specified binary is 64-bit or not in Is64Bit parameter; returns
// true for success, or false for failure
function wsIsBinary64Bit(FileName: unicodestring; var Is64Bit: boolean): DWORD;

// If Java installation found, returns path of Java home directory
function wsGetJavaHome(): unicodestring;

// If Java installation found, returns version number of java.exe as a string
// (a.b.c.d)
function wsGetJavaVersion(): unicodestring;

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

function wsIsBinary64Bit(FileName: unicodestring; var Is64Bit: boolean): DWORD;
  var
    BinaryType: word;
  begin
  result := GetBinaryType(FileName, BinaryType);
  if result = 0 then Is64Bit := BinaryType <> IMAGE_FILE_MACHINE_I386;
  end;

// Tries 4 ways to detect a Java installation:
// 1. Use JAVA_HOME/JDK_HOME/JRE_HOME (in that order) environment variable
// 2. If environment variables not defined, search the Path for java.exe
// 3. If not found, search 'JavaSoft' and 'IBM' registry subkeys and return
//    'JavaHome' value for latest version
// 4. If not found, search 'Azul Systems' registry subkey and return
//    'InstallationPath' value for latest version
function FindJavaHome(): unicodestring;
  var
    StringList, SubKeyNames: TArrayOfString;
    I, J: longint;
    RootKey: HKEY;
    SubKeyExists: boolean;
    CurrentVersion, CurrentSubKeyName, LatestSubKeyName, LatestVersion, JavaHome: unicodestring;
  begin
  result := '';
  // Try #1: Check environment variables
  SetLength(StringList, 3);
  StringList[0] := 'JAVA_HOME';
  StringList[1] := 'JDK_HOME';
  StringList[2] := 'JRE_HOME';
  for I := 0 to Length(StringList) - 1 do
    begin
    result := GetEnvVar(StringList[I]);
    if result <> '' then break;
    end;
  // Try #2: Search the path
  if result = '' then
    begin
    result := FileSearch('java.exe', GetEnvVar('Path'));
    if result <> '' then
      result := ExtractFileDir(ExtractFileDir(result));
    end;
  // Try #3: Search JDK/JRE in registy under JavaSoft and IBM
  if result = '' then
    begin
    LatestSubKeyName := '';
    LatestVersion := '0';
    RootKey := 0;
    SetLength(StringList, 6);
    StringList[0] := 'SOFTWARE\JavaSoft\Java Development Kit';
    StringList[1] := 'SOFTWARE\JavaSoft\JDK';
    StringList[2] := 'SOFTWARE\JavaSoft\Java Runtime Environment';
    StringList[3] := 'SOFTWARE\JavaSoft\JRE';
    StringList[4] := 'SOFTWARE\IBM\Java Development Kit';
    StringList[5] := 'SOFTWARE\IBM\Java Runtime Environment';
    for I := 0 to Length(StringList) - 1 do
      begin
      SubKeyExists := false;
      CurrentSubKeyName := StringList[I];
      if IsWin64() then
        begin
        SubKeyExists := RegKeyExists(HKEY_LOCAL_MACHINE_64, CurrentSubKeyName);
        if SubKeyExists then
          RootKey := HKEY_LOCAL_MACHINE_64
        else
          begin
          SubKeyExists := RegKeyExists(HKEY_LOCAL_MACHINE_32, CurrentSubKeyName);
          if SubKeyExists then RootKey := HKEY_LOCAL_MACHINE_32;
          end;
        end
      else
        begin
        SubKeyExists := RegKeyExists(HKEY_LOCAL_MACHINE, CurrentSubKeyName);
        if SubKeyExists then RootKey := HKEY_LOCAL_MACHINE;
        end;
      if SubKeyExists then
        begin
        if RegGetSubKeyNames(RootKey, CurrentSubKeyName, SubKeyNames) then
          begin
          for J := 0 to Length(SubKeyNames) - 1 do
            begin
            if CompareVersionStrings(SubKeyNames[J], LatestVersion) > 0 then
              begin
              LatestSubKeyName := CurrentSubKeyName;
              LatestVersion := SubKeyNames[J];
              end;
            end;
          end;
        end;
      end;
    if (LatestVersion <> '0') and (RegQueryStringValue(RootKey, LatestSubKeyName + '\' + LatestVersion, 'JavaHome', JavaHome)) and (JavaHome <> '') then
      result := JavaHome;
    end;
  // Try # 4: Look for Azul Zulu in registry
  if result = '' then
    begin
    LatestVersion := '0';
    RootKey := 0;
    SubKeyExists := false;
    CurrentSubKeyName := 'SOFTWARE\Azul Systems\Zulu';
    if IsWin64() then
      begin
      SubKeyExists := RegKeyExists(HKEY_LOCAL_MACHINE_64, CurrentSubKeyName);
      if SubKeyExists then
        RootKey := HKEY_LOCAL_MACHINE_64
      else
        begin
        SubKeyExists := RegKeyExists(HKEY_LOCAL_MACHINE_32, CurrentSubKeyName);
        if SubKeyExists then RootKey := HKEY_LOCAL_MACHINE_32;
        end;
      end
    else
      begin
      SubKeyExists := RegKeyExists(HKEY_LOCAL_MACHINE, CurrentSubKeyName);
      if SubKeyExists then RootKey := HKEY_LOCAL_MACHINE;
      end;
    if SubKeyExists then
      begin
      if RegGetSubKeyNames(RootKey, CurrentSubKeyName, SubKeyNames) then
        begin
        for I := 0 to Length(SubKeyNames) - 1 do
          begin
          if (Length(SubKeyNames[I]) > 5) and (LowerCase(Copy(SubKeyNames[I], 1, 5)) = 'zulu-') then
            begin
            CurrentVersion := Copy(SubKeyNames[I], 6, Length(SubKeyNames[I]) - 5);
            if StrToIntDef(CurrentVersion, 0) > 0 then
              begin
              if CompareVersionStrings(CurrentVersion, LatestVersion) > 0 then
                LatestVersion := CurrentVersion;
              end;
            end;
          end;
        end;
      end;
    if (LatestVersion <> '0') and (RegQueryStringValue(RootKey, CurrentSubKeyName + '\zulu-' + LatestVersion, 'InstallationPath', JavaHome)) and (JavaHome <> '') then
      result := JavaHome;
    end;
  // Remove trailing separator character(s)
  if result <> '' then
    while result[Length(result)] = '\' do
      result := Copy(result, 1, Length(result) - 1);
  end;

procedure Init();
  var
    DirName, FileName, FileVersion: unicodestring;
  begin
  // Initialize unit vars
  JavaHome := '';
  JavaVersion := '';
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
  JavaHome := DirName;
  JavaVersion := FileVersion;
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

function wsIsJavaInstalled(): boolean;
  begin
  Init();
  result := (JavaHome <> '') and (JavaVersion <> '');
  end;

begin
end.
