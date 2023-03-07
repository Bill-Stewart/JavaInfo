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
{$H+}

unit wsJavaInfo;

interface

type
  TJavaDetectionType = (JDNone, JDEnvironment, JDPath, JDJavaSoft, JDIBM,
    JDAdoptium, JDMicrosoft, JDZulu);

// Gets whether specified binary is 64-bit or not in Is64Bit parameter; returns
// 0 for success, or non-zero for failure
function wsIsBinary64Bit(FileName: UnicodeString; var Is64Bit: Boolean): DWORD;

// If Java installation found, returns path of Java home directory
function wsGetJavaHome(): UnicodeString;

// If Java installation found, returns path for jvm.dll
function wsGetJavaJVMPath(): UnicodeString;

// If Java installation found, returns version number of java.exe as a string
// (a.b.c.d)
function wsGetJavaVersion(): UnicodeString;

// Returns true if a Java installation was found, or false otherwise
function wsIsJavaInstalled(): Boolean;

// Gets whether the installed Java version is at least the specified version
// in the VersionOK parameter; returns true for success, or false otherwise
function wsIsJavaMinimumVersion(Version: UnicodeString; var VersionOK: Boolean): Boolean;

// Diagnostic: returns Java detection type
function wsGetJavaDetectionType(): TJavaDetectionType;

implementation

uses
  Windows,
  wsUtilArch,
  wsUtilEnv,
  wsUtilFile,
  wsUtilReg,
  wsUtilStr;

var
  JavaHome, JavaJVMPath, JavaVersion: UnicodeString;
  JavaDetectionType: TJavaDetectionType;

function wsIsBinary64Bit(FileName: UnicodeString; var Is64Bit: Boolean): DWORD;
var
  BinaryType: Word;
begin
  result := GetBinaryType(FileName, BinaryType);
  if result = 0 then
    Is64Bit := BinaryType <> IMAGE_FILE_MACHINE_I386;
end;

// Find Java home from environment variables
function FindJavaHomeEnvironment(): UnicodeString;
var
  VarList: TArrayOfString;
  I: LongInt;
begin
  result := '';
  SetLength(VarList, 3);
  VarList[0] := 'JAVA_HOME';
  VarList[1] := 'JDK_HOME';
  VarList[2] := 'JRE_HOME';
  for I := 0 to Length(VarList) - 1 do
  begin
    result := GetEnvVar(VarList[I]);
    if result <> '' then
      break;
  end;
end;

// Find Java home by searching the Path
function FindJavaHomePath(): UnicodeString;
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
// * Adoptium if 'JavaSoft (Oracle) registry keys' component selected
// * Amazon Corretto JDK if 'Setup Registry Keys' component selected
// * Azul Systems Zulu JDK
// If starting subkey is 'SOFTWARE\IBM', this function should detect IBM JDK
// (hopefully? I have no way to test, as I don't have a way to get an IBM
// JRE/JDK on Windows)
function FindJavaHomeRegistryJavaSoft(const StartingSubKey: UnicodeString): UnicodeString;
var
  LatestSubKeyName, LatestVersion, ResultStr: UnicodeString;
  RootKey: HKEY;
  I, J: LongInt;
  StartingSubKeys, SubKeyNames: TArrayOfString;
  SubKeyExists: Boolean;
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
        if SubKeyExists then
          RootKey := HKEY_LOCAL_MACHINE_32;
      end;
    end
    else
    begin
      SubKeyExists := RegKeyExists(HKEY_LOCAL_MACHINE, StartingSubKeys[I]);
      if SubKeyExists then
        RootKey := HKEY_LOCAL_MACHINE;
    end;
    if SubKeyExists then
    begin
      if RegGetSubKeyNames(RootKey, StartingSubKeys[I], SubKeyNames) and (Length(SubKeyNames) > 0) then
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
  if (LatestVersion <> '0') and (RegQueryStringValue(RootKey, LatestSubKeyName + '\' + LatestVersion,
    'JavaHome', ResultStr)) and (ResultStr <> '') then
    result := ResultStr;
end;

// Find latest Java home using Adoptium-style registry subkeys
// Subkey: SOFTWARE\<vendor>\<javatype>\<version>\<buildtype>\MSI
// String value: Path
// Where
//   <vendor> is one of: 'AdoptOpenJDK', 'Eclipse Foundation', or 'Semeru'
//   <javatype> is JDK or JRE
//   <version> is the Java version string
//   <buildtype> is usually 'hotspot' or 'openj9'
function FindJavaHomeRegistryAdoptium(): UnicodeString;
var
  LatestSubKeyName, LatestVersion, ResultStr: UnicodeString;
  RootKey: HKEY;
  I, J, K: LongInt;
  StartingSubKeys, SubKeyNames, SubSubKeyNames: TArrayOfString;
  SubKeyExists: Boolean;
begin
  result := '';
  LatestSubKeyName := '';
  LatestVersion := '0';
  RootKey := 0;
  SetLength(StartingSubKeys, 8);
  StartingSubKeys[0] := 'SOFTWARE\AdoptOpenJDK\JDK';
  StartingSubKeys[1] := 'SOFTWARE\AdoptOpenJDK\JRE';
  StartingSubKeys[2] := 'SOFTWARE\Eclipse Adoptium\JDK';
  StartingSubKeys[3] := 'SOFTWARE\Eclipse Adoptium\JRE';
  StartingSubKeys[4] := 'SOFTWARE\Eclipse Foundation\JDK';
  StartingSubKeys[5] := 'SOFTWARE\Eclipse Foundation\JRE';
  StartingSubKeys[6] := 'SOFTWARE\Semeru\JDK';
  StartingSubKeys[7] := 'SOFTWARE\Semeru\JRE';
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
        if SubKeyExists then
          RootKey := HKEY_LOCAL_MACHINE_32;
      end;
    end
    else
    begin
      SubKeyExists := RegKeyExists(HKEY_LOCAL_MACHINE, StartingSubKeys[I]);
      if SubKeyExists then
        RootKey := HKEY_LOCAL_MACHINE;
    end;
    if SubKeyExists then
    begin
      if RegGetSubKeyNames(RootKey, StartingSubKeys[I], SubKeyNames) and (Length(SubKeyNames) > 0) then
      begin
        for J := 0 to Length(SubKeyNames) - 1 do
        begin
          if CompareVersionStrings(SubKeyNames[J], LatestVersion) > 0 then
          begin
            if RegGetSubKeyNames(RootKey, StartingSubKeys[I] + '\' + SubKeyNames[J], SubSubKeyNames) and
              (Length(SubSubKeyNames) > 0) then
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

// Find latest Java home using Microsoft registry subkeys
// Subkey: SOFTWARE\Microsoft\<javatype>\<version>\<buildtype>\MSI
// String value: Path
// Where
//   <javatype> is JDK
//   <version> is the Java version string
//   <buildtype> is 'hotspot'
function FindJavaHomeRegistryMicrosoft(): UnicodeString;
var
  LatestSubKeyName, LatestVersion, ResultStr: UnicodeString;
  RootKey: HKEY;
  I, J, K: LongInt;
  StartingSubKeys, SubKeyNames, SubSubKeyNames: TArrayOfString;
  SubKeyExists: Boolean;
begin
  result := '';
  LatestSubKeyName := '';
  LatestVersion := '0';
  RootKey := 0;
  SetLength(StartingSubKeys, 1);
  StartingSubKeys[0] := 'SOFTWARE\Microsoft\JDK';
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
        if SubKeyExists then
          RootKey := HKEY_LOCAL_MACHINE_32;
      end;
    end
    else
    begin
      SubKeyExists := RegKeyExists(HKEY_LOCAL_MACHINE, StartingSubKeys[I]);
      if SubKeyExists then
        RootKey := HKEY_LOCAL_MACHINE;
    end;
    if SubKeyExists then
    begin
      if RegGetSubKeyNames(RootKey, StartingSubKeys[I], SubKeyNames) and (Length(SubKeyNames) > 0) then
      begin
        for J := 0 to Length(SubKeyNames) - 1 do
        begin
          if CompareVersionStrings(SubKeyNames[J], LatestVersion) > 0 then
          begin
            if RegGetSubKeyNames(RootKey, StartingSubKeys[I] + '\' + SubKeyNames[J], SubSubKeyNames) and
              (Length(SubSubKeyNames) > 0) then
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
function FindJavaHomeRegistryZulu(): UnicodeString;
var
  LatestSubKeyName, LatestVersion, SubKeyName, CurrentVersion, ResultStr: UnicodeString;
  RootKey: HKEY;
  SubKeyExists: Boolean;
  SubKeyNames: TArrayOfString;
  I: LongInt;
begin
  result := '';
  LatestSubKeyName := '';
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
      if SubKeyExists then
        RootKey := HKEY_LOCAL_MACHINE_32;
    end;
  end
  else
  begin
    SubKeyExists := RegKeyExists(HKEY_LOCAL_MACHINE, SubKeyName);
    if SubKeyExists then
      RootKey := HKEY_LOCAL_MACHINE;
  end;
  if SubKeyExists then
  begin
    if RegGetSubKeyNames(RootKey, SubKeyName, SubKeyNames) and (Length(SubKeyNames) > 0) then
    begin
      for I := 0 to Length(SubKeyNames) - 1 do
      begin
        if (Length(SubKeyNames[I]) > 5) and (LowerCase(Copy(SubKeyNames[I], 1, 5)) = 'zulu-') then
        begin
          if GetDigitsInString(SubKeyNames[I], CurrentVersion) then
          begin
            if CompareVersionStrings(CurrentVersion, LatestVersion) > 0 then
            begin
              LatestSubKeyName := SubKeyName + '\' + SubKeyNames[I];
              LatestVersion := CurrentVersion;
            end;
          end;
        end;
      end;
    end;
  end;
  if (LatestVersion <> '0') and (RegQueryStringValue(RootKey, LatestSubKeyName, 'InstallationPath', ResultStr)) and
    (ResultStr <> '') then
    result := ResultStr;
end;

function GetJavaVersion(const Home: UnicodeString): UnicodeString;
var
  Binary: UnicodeString;
begin
  result := '';
  if (Home <> '') and DirExists(Home) then
  begin
    Binary := JoinPath(Home, '\bin\java.exe');
    if FileExists(Binary) then
      result := GetFileVersion(Binary);
  end;
end;

function GetJVMPath(const Home: UnicodeString): UnicodeString;
var
  Binary: UnicodeString;
begin
  result := '';
  if (Home <> '') and DirExists(Home) then
  begin
    Binary := JoinPath(Home, 'bin\server\jvm.dll');
    if FileExists(Binary) then
      exit(Binary);
    Binary := JoinPath(Home, 'jre\bin\server\jvm.dll');
    if FileExists(Binary) then
      exit(Binary);
  end;
end;

procedure GetJavaDetail(var JavaHome, JavaJVMPath, JavaVersion: UnicodeString;
  var JavaDetectionType: TJavaDetectionType);
var
  CurrentHome, CurrentVersion, LatestVersion, LatestHome: UnicodeString;
  LatestDetectionType: TJavaDetectionType;
begin
  // Initialize
  JavaHome := '';
  JavaJVMPath := '';
  JavaVersion := '';
  JavaDetectionType := JDNone;
  // Environment variable search: Exit if found
  CurrentHome := FindJavaHomeEnvironment();
  CurrentVersion := GetJavaVersion(CurrentHome);
  if CurrentVersion <> '' then
  begin
    JavaHome := CurrentHome;
    JavaVersion := CurrentVersion;
    JavaJVMPath := GetJVMPath(JavaHome);
    JavaDetectionType := JDEnvironment;
    exit();
  end;
  // Path search: Exit if found
  CurrentHome := FindJavaHomePath();
  CurrentVersion := GetJavaVersion(CurrentHome);
  if CurrentVersion <> '' then
  begin
    JavaHome := CurrentHome;
    JavaVersion := CurrentVersion;
    JavaJVMPath := GetJVMPath(JavaHome);
    JavaDetectionType := JDPath;
    exit();
  end;
  // Registry search should return latest version from all searches
  LatestHome := '';
  LatestVersion := '0';
  LatestDetectionType := JDNone;
  // Search 'HKLM\SOFTWARE\JavaSoft'
  CurrentHome := FindJavaHomeRegistryJavaSoft('SOFTWARE\JavaSoft');
  CurrentVersion := GetJavaVersion(CurrentHome);
  if CurrentVersion <> '' then
  begin
    if CompareVersionStrings(CurrentVersion, LatestVersion) > 0 then
    begin
      LatestHome := CurrentHome;
      LatestVersion := CurrentVersion;
      LatestDetectionType := JDJavaSoft;
    end;
  end;
  // Search 'HKLM\SOFTWARE\IBM'
  CurrentHome := FindJavaHomeRegistryJavaSoft('SOFTWARE\IBM');
  CurrentVersion := GetJavaVersion(CurrentHome);
  if CurrentVersion <> '' then
  begin
    if CompareVersionStrings(CurrentVersion, LatestVersion) > 0 then
    begin
      LatestHome := CurrentHome;
      LatestVersion := CurrentVersion;
      LatestDetectionType := JDIBM;
    end;
  end;
  // Search Eclipse Adoptium subkeys
  CurrentHome := FindJavaHomeRegistryAdoptium();
  CurrentVersion := GetJavaVersion(CurrentHome);
  if CurrentVersion <> '' then
  begin
    if CompareVersionStrings(CurrentVersion, LatestVersion) > 0 then
    begin
      LatestHome := CurrentHome;
      LatestVersion := CurrentVersion;
      LatestDetectionType := JDAdoptium;
    end;
  end;
  // Search Microsoft subkeys
  CurrentHome := FindJavaHomeRegistryMicrosoft();
  CurrentVersion := GetJavaVersion(CurrentHome);
  if CurrentVersion <> '' then
  begin
    if CompareVersionStrings(CurrentVersion, LatestVersion) > 0 then
    begin
      LatestHome := CurrentHome;
      LatestVersion := CurrentVersion;
      LatestDetectionType := JDMicrosoft;
    end;
  end;
  // Search Zulu subkeys
  CurrentHome := FindJavaHomeRegistryZulu();
  CurrentVersion := GetJavaVersion(CurrentHome);
  if CurrentVersion <> '' then
  begin
    if CompareVersionStrings(CurrentVersion, LatestVersion) > 0 then
    begin
      LatestHome := CurrentHome;
      LatestVersion := CurrentVersion;
      LatestDetectionType := JDZulu;
    end;
  end;
  if (LatestHome <> '') and (LatestVersion <> '0') then
  begin
    JavaHome := LatestHome;
    JavaJVMPath := GetJVMPath(JavaHome);
    JavaVersion := LatestVersion;
    JavaDetectionType := LatestDetectionType;
  end;
end;

function wsGetJavaHome(): UnicodeString;
begin
  result := RemoveBackslashUnlessRoot(JavaHome);
end;

function wsGetJavaJVMPath(): UnicodeString;
begin
  result := JavaJVMPath;
end;

function wsGetJavaVersion(): UnicodeString;
begin
  result := JavaVersion;
end;

function wsIsJavaInstalled(): Boolean;
begin
  result := (JavaHome <> '') and (JavaVersion <> '');
end;

function wsIsJavaMinimumVersion(Version: UnicodeString; var VersionOK: Boolean): Boolean;
begin
  Version := ExpandVersionString(Version);
  result := Version <> '';
  if result then
    VersionOK := CompareVersionStrings(JavaVersion, Version) >= 0;
end;

function wsGetJavaDetectionType(): TJavaDetectionType;
begin
  result := JavaDetectionType;
end;

initialization
  GetJavaDetail(JavaHome, JavaJVMPath, JavaVersion, JavaDetectionType);

end.
