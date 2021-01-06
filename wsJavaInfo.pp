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

type
  TJavaDetectionType = (JDNone,JDEnvironment,JDPath,JDJavaSoft,JDIBM,JDAdoptOpenJDK,JDZulu);

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

// Diagnostic: returns Java detection type
function wsGetJavaDetectionType(): TJavaDetectionType;

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
  JavaDetectionType: TJavaDetectionType;

function wsIsBinary64Bit(FileName: unicodestring; var Is64Bit: boolean): DWORD;
  var
    BinaryType: word;
  begin
  result := GetBinaryType(FileName, BinaryType);
  if result = 0 then Is64Bit := BinaryType <> IMAGE_FILE_MACHINE_I386;
  end;

// Find Java home from environment variables
function FindJavaHomeEnvironment(): unicodestring;
  var
    VarList: TArrayOfString;
    I: longint;
  begin
  result := '';
  SetLength(VarList, 3);
  VarList[0] := 'JAVA_HOME';
  VarList[1] := 'JDK_HOME';
  VarList[2] := 'JRE_HOME';
  for I := 0 to Length(VarList) - 1 do
    begin
    result := GetEnvVar(VarList[I]);
    if result <> '' then break;
    end;
  end;

// Find Java home by searching the Path
function FindJavaHomePath(): unicodestring;
  begin
  result := FileSearch('java.exe', GetEnvVar('Path'));
  if result <> '' then
    result := ExtractFileDir(ExtractFileDir(result));
  end;

// Find latest Java home using JavaSoft-style registry subkeys
// Subkey: SOFTWARE\<vendor>\<javatype>\<version>
// String value: 'JavaHome'
// Where
//   <vendor> is usually 'JavaSoft' or 'IBM'
//   <javatype> is JDK or JRE (or spelled out versions of those)
//   <version> is the Java version string
// StartingSubKey is subkey where to start search (e.g., 'SOFTWARE\JavaSoft')
// If starting subkey is 'SOFTWARE\JavaSoft', this function should detect:
// * Oracle JDK/JRE
// * AdoptOpenJDK if 'JavaSoft (Oracle) registry keys' component selected
// * Amazon Corretto JDK if 'Setup Registry Keys' component selected
// * Azul Systems Zulu JDK
// If starting subkey is 'SOFTWARE\IBM', this function should detect IBM JDK
// (hopefully? I have no way to test, as I don't have a way to get an IBM
// JRE/JDK on Windows)
function FindJavaHomeRegistryJavaSoft(const StartingSubKey: unicodestring): unicodestring;
  var
    LatestSubKeyName, LatestVersion, ResultStr: unicodestring;
    RootKey: HKEY;
    I, J: longint;
    StartingSubKeys, SubKeyNames: TArrayOfString;
    SubKeyExists: boolean;
  begin
  result := '';
  LatestSubKeyName := '';
  LatestVersion := '0';
  RootKey := 0;
  SetLength(StartingSubKeys, 4);
  StartingSubKeys[0] := JoinPath(StartingSubKey, 'Java Development Kit');
  StartingSubKeys[1] := JoinPath(StartingSubKey, 'JDK');
  StartingSubKeys[2] := JoinPath(StartingSubKey, 'Java Runtime Environment');
  StartingSubKeys[3] := JoinPath(StartingSubKey, 'JRE');
  for I := 0 to Length(StartingSubKeys) - 1 do
    begin
    SubKeyExists := false;
    if IsWin64() then
      begin
      SubKeyExists := RegKeyExists(HKEY_LOCAL_MACHINE_64, StartingSubKeys[I]);
      if SubKeyExists then
        RootKey := HKEY_LOCAL_MACHINE_64
      else
        begin
        SubKeyExists := RegKeyExists(HKEY_LOCAL_MACHINE_32, StartingSubKeys[I]);
        if SubKeyExists then RootKey := HKEY_LOCAL_MACHINE_32;
        end;
      end
    else
      begin
      SubKeyExists := RegKeyExists(HKEY_LOCAL_MACHINE, StartingSubKeys[I]);
      if SubKeyExists then RootKey := HKEY_LOCAL_MACHINE;
      end;
    if SubKeyExists then
      begin
      if RegGetSubKeyNames(RootKey, StartingSubKeys[I], SubKeyNames) then
        begin
        for J := 0 to Length(SubKeyNames) - 1 do
          begin
          if CompareVersionStrings(SubKeyNames[J], LatestVersion) > 0 then
            begin
            LatestSubKeyName := StartingSubKeys[I];
            LatestVersion := SubKeyNames[J];
            end;
          end;
        end;
      end;
    end;
  if (LatestVersion <> '0') and (RegQueryStringValue(RootKey, LatestSubKeyName + '\' + LatestVersion, 'JavaHome', ResultStr)) and (ResultStr <> '') then
    result := ResultStr;
  end;

// Find latest Java home using AdoptOpenJDK-style registry subkeys
// Subkey: SOFTWARE\AdoptOpenJDK\<javatype>\<version>\<buildtype>\MSI
// String value: Path
// Where
//   <javatype> is JDK or JRE
//   <version> is the Java version string
//   <buildtype> is usually 'hotspot' or 'openj9'
function FindJavaHomeRegistryAdoptOpenJDK(): unicodestring;
  var
    LatestSubKeyName, LatestVersion, ResultStr: unicodestring;
    RootKey: HKEY;
    I, J, K: longint;
    StartingSubKeys, SubKeyNames, SubSubKeyNames: TArrayOfString;
    SubKeyExists: boolean;
  begin
  result := '';
  LatestSubKeyName := '';
  LatestVersion := '0';
  RootKey := 0;
  SetLength(StartingSubKeys, 2);
  StartingSubKeys[0] := 'SOFTWARE\AdoptOpenJDK\JDK';
  StartingSubKeys[1] := 'SOFTWARE\AdoptOpenJDK\JRE';
  for I := 0 to Length(StartingSubKeys) - 1 do
    begin
    SubKeyExists := false;
    if IsWin64() then
      begin
      SubKeyExists := RegKeyExists(HKEY_LOCAL_MACHINE_64, StartingSubKeys[I]);
      if SubKeyExists then
        RootKey := HKEY_LOCAL_MACHINE_64
      else
        begin
        SubKeyExists := RegKeyExists(HKEY_LOCAL_MACHINE_32, StartingSubKeys[I]);
        if SubKeyExists then RootKey := HKEY_LOCAL_MACHINE_32;
        end;
      end
    else
      begin
      SubKeyExists := RegKeyExists(HKEY_LOCAL_MACHINE, StartingSubKeys[I]);
      if SubKeyExists then RootKey := HKEY_LOCAL_MACHINE;
      end;
    if SubKeyExists then
      begin
      if RegGetSubKeyNames(RootKey, StartingSubKeys[I], SubKeyNames) then
        begin
        for J := 0 to Length(SubKeyNames) - 1 do
          begin
          if CompareVersionStrings(SubKeyNames[J], LatestVersion) > 0 then
            begin
            if RegGetSubKeyNames(RootKey, StartingSubKeys[I] + '\' + SubKeyNames[J], SubSubKeyNames) then
              begin
              for K := 0 to Length(SubSubKeyNames) - 1 do
                begin
                LatestSubKeyName := StartingSubKeys[I] + '\' + SubKeyNames[J] + '\' + SubSubKeyNames[K] + '\MSI';
                LatestVersion := SubKeyNames[J];
                end;
              end;
            end;
          end;
        end;
      end;
    end;
  if (LatestVersion <> '0') and (RegQueryStringValue(RootKey, LatestSubKeyName, 'Path', ResultStr)) and (ResultStr <> '') then
    result := ResultStr;
  end;

// Find latest Java home using Zulu-style registry subkeys
// Subkey: SOFTWARE\Azul Systems\Zulu\zulu-<version>
// String value: InstallationPath
// <version> is the Java version
// (This search would only occur if the Zulu installer doesn't update the
// JavaSoft registry subkeys for some reason)
function FindJavaHomeRegistryZulu(): unicodestring;
  var
    LatestVersion, SubKeyName, CurrentVersion, ResultStr: unicodestring;
    RootKey: HKEY;
    SubKeyExists: boolean;
    SubKeyNames: TArrayOfString;
    I: longint;
  begin
  result := '';
  LatestVersion := '0';
  RootKey := 0;
  SubKeyExists := false;
  SubKeyName := 'SOFTWARE\Azul Systems\Zulu';
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
    if RegGetSubKeyNames(RootKey, SubKeyName, SubKeyNames) then
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
  if (LatestVersion <> '0') and (RegQueryStringValue(RootKey, SubKeyName + '\zulu-' + LatestVersion, 'InstallationPath', ResultStr)) and (ResultStr <> '') then
    result := ResultStr;
  end;

procedure FindJavaHome(var JavaHome: unicodestring; var JavaDetectionType: TJavaDetectionType);
  begin
  JavaHome := FindJavaHomeEnvironment();
  if JavaHome <> '' then
    begin
    JavaDetectionType := JDEnvironment;
    exit();
    end;
  JavaHome := FindJavaHomePath();
  if JavaHome <> '' then
    begin
    JavaDetectionType := JDPath;
    exit();
    end;
  JavaHome := FindJavaHomeRegistryJavaSoft('SOFTWARE\JavaSoft');
  if JavaHome <> '' then
    begin
    JavaDetectionType := JDJavaSoft;
    exit();
    end;
  JavaHome := FindJavaHomeRegistryJavaSoft('SOFTWARE\IBM');
  if JavaHome <> '' then
    begin
    JavaDetectionType := JDIBM;
    exit();
    end;
  JavaHome := FindJavaHomeRegistryAdoptOpenJDK();
  if JavaHome <> '' then
    begin
    JavaDetectionType := JDAdoptOpenJDK;
    exit();
    end;
  JavaHome := FindJavaHomeRegistryZulu();
  if JavaHome <> '' then
    begin
    JavaDetectionType := JDZulu;
    exit();
    end;
  end;

procedure Init();
  var
    Home, FileName, FileVersion: unicodestring;
    DetectionType: TJavaDetectionType;
  begin
  // Initialize unit vars
  JavaHome := '';
  JavaVersion := '';
  JavaDetectionType := JDNone;
  // Try to find Java home
  FindJavaHome(Home, DetectionType);
  if Home = '' then exit();
  if not DirExists(Home) then exit();
  // Look for Java binary
  FileName := JoinPath(Home, 'bin\java.exe');
  if not FileExists(FileName) then exit();
  // Try to get version number
  FileVersion := GetFileVersion(FileName);
  if FileVersion = '' then exit();
  // Remove trailing separators
  while Home[Length(Home)] = '\' do
    Home := Copy(Home, 1, Length(Home) - 1);
  JavaHome := Home;
  JavaVersion := FileVersion;
  JavaDetectionType := DetectionType;
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

function wsGetJavaDetectionType(): TJavaDetectionType;
  begin
  result := JavaDetectionType;
  end;

initialization
  JavaDetectionType := JDNone;

end.
