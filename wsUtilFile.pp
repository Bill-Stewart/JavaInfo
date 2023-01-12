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

unit wsUtilFile;

interface

// Returns true if the named directorty exists, or false if not
function DirExists(const DirName: UnicodeString): Boolean;

// Returns directory name from a path without trailing separator
function ExtractFileDir(const FileName: UnicodeString): UnicodeString;

// Returns true if the named file exists, or false if not
function FileExists(const FileName: UnicodeString): Boolean;

// Searches for a named file in semicolon-delimited list of directory names;
// returns an empty string if nothing found
function FileSearch(const Name, DirList: UnicodeString): UnicodeString;

// Gets the specified file's binary type to the BinaryType parameter; returns
// 0 for success, or non-zero for failure
function GetBinaryType(const FileName: UnicodeString; var BinaryType: Word): DWORD;

// Gets the path for the current running executable
function GetExecutablePath(): UnicodeString;

// Returns a version number string (a.b.c.d) for the named file; returns an
// empty string if the function failed (e.g., no version information found)
function GetFileVersion(const FileName: UnicodeString): UnicodeString;

// Concatenates Path1 to Path2 with only a single path separator between
function JoinPath(Path1, Path2: UnicodeString): UnicodeString;

implementation

uses
  imagehlp,
  Windows,
  wsUtilArch,
  wsUtilStr;

const
  INVALID_FILE_ATTRIBUTES = DWORD(-1);

var
  PerformWow64FsRedirection: Boolean;
  Wow64FsRedirectionOldValue: Pointer;

procedure ToggleWow64FsRedirection();
begin
  if PerformWow64FsRedirection then
  begin
    if not Assigned(Wow64FsRedirectionOldValue) then
    begin
      if not Wow64DisableWow64FsRedirection(@Wow64FsRedirectionOldValue) then
        Wow64FsRedirectionOldValue := nil;
    end
    else
    begin
      if Wow64RevertWow64FsRedirection(Wow64FsRedirectionOldValue) then
        Wow64FsRedirectionOldValue := nil;
    end;
  end;
end;

function DirExists(const DirName: UnicodeString): Boolean;
var
  Attrs: DWORD;
begin
  ToggleWow64FsRedirection();
  Attrs := GetFileAttributesW(PWideChar(DirName));
  ToggleWow64FsRedirection();
  result := (Attrs <> INVALID_FILE_ATTRIBUTES) and
    ((Attrs and FILE_ATTRIBUTE_DIRECTORY) <> 0);
end;

function ExtractFileDir(const FileName: UnicodeString): UnicodeString;
const
  Separators: set of Char = [':', '\'];
var
  I: LongInt;
begin
  I := Length(FileName);
  while (I > 0) and (not (FileName[I] in Separators)) do
    Dec(I);
  if (I > 1) and (FileName[I] = '\') and (not (FileName[I - 1] in Separators)) then
    Dec(I);
  result := Copy(FileName, 1, I);
end;

function FileExists(const FileName: UnicodeString): Boolean;
var
  Attrs: DWORD;
begin
  ToggleWow64FsRedirection();
  Attrs := GetFileAttributesW(PWideChar(FileName));
  ToggleWow64FsRedirection();
  result := (Attrs <> INVALID_FILE_ATTRIBUTES) and
    ((Attrs and FILE_ATTRIBUTE_DIRECTORY) = 0);
end;

function FileSearch(const Name, DirList: UnicodeString): UnicodeString;
var
  NumChars, BufSize: DWORD;
  pBuffer: PWideChar;
begin
  result := '';
  // Get number of characters needed for buffer
  ToggleWow64FsRedirection();
  NumChars := SearchPathW(PWideChar(DirList),  // LPCSTR lpPath
    PWideChar(Name),                           // LPCSTR lpFilename
    nil,                                       // LPCSTR lpExtension
    0,                                         // DWORD  nBufferLength
    nil,                                       // LPSTR  lpBuffer
    nil);                                      // LPSTR  lpFilePart
  if NumChars > 0 then
  begin
    BufSize := NumChars * SizeOf(WideChar);
    GetMem(pBuffer, BufSize);
    if SearchPathW(PWideChar(DirList),  // LPCSTR lpPath
      PWideChar(Name),                  // LPCSTR lpFilename
      nil,                              // LPCSTR lpExtension
      NumChars,                         // DWORD  nBufferLength
      pBuffer,                          // LPSTR  lpBuffer
      nil) > 0 then                     // LPSTR  lpFilePart
      result := pBuffer;
    FreeMem(pBuffer, BufSize);
  end;
  ToggleWow64FsRedirection();
end;

function GetBinaryType(const FileName: UnicodeString; var BinaryType: Word): DWORD;
var
  pLoadedImage: PLOADED_IMAGE;
begin
  ToggleWow64FsRedirection();
  pLoadedImage := ImageLoad(PChar(UnicodeStringToString(FileName, CP_ACP)), '');
  ToggleWow64FsRedirection();
  if Assigned(pLoadedImage) then
    result := 0
  else
    result := GetLastError();
  if result = 0 then
  begin
    BinaryType := pLoadedImage^.Fileheader^.FileHeader.Machine;
    ImageUnload(pLoadedImage);
  end;
end;

function GetExecutablePath(): UnicodeString;
var
  NumChars, BufSize: DWORD;
  pBuffer: PWideChar;
begin
  result := '';
  // GetModuleFileNameW() doesn't let us determine the needed length of the
  // string by setting third parameter to zero, so just create a 64K buffer
  NumChars := 32768;
  BufSize := NumChars * SizeOf(WideChar);
  GetMem(pBuffer, BufSize);
  NumChars := GetModuleFileNameW(0,  // HMODULE hModule
    pBuffer,                         // LPWSTR  lpFilename
    NumChars);                       // DWORD   nSize
  if (NumChars > 0) and (GetLastError() = ERROR_SUCCESS) then
    result := pBuffer;
  FreeMem(pBuffer, BufSize);
end;

function GetFileVersion(const FileName: UnicodeString): UnicodeString;
var
  VerInfoSize, Handle: DWORD;
  pBuffer: Pointer;
  pFileInfo: ^VS_FIXEDFILEINFO;
  Len: UINT;
begin
  result := '';
  ToggleWow64FsRedirection();
  VerInfoSize := GetFileVersionInfoSizeW(PWideChar(FileName), Handle);
  if VerInfoSize > 0 then
  begin
    GetMem(pBuffer, VerInfoSize);
    if GetFileVersionInfoW(PWideChar(FileName), Handle, VerInfoSize, pBuffer) then
    begin
      if VerQueryValueW(pBuffer, '\', pFileInfo, Len) then
      begin
        with pFileInfo^ do
        begin
          result := IntToStr(HiWord(dwFileVersionMS)) + '.' +
            IntToStr(LoWord(dwFileVersionMS)) + '.' +
            IntToStr(HiWord(dwFileVersionLS)) + '.' +
            IntToStr(LoWord(dwFileVersionLS));
        end;
      end;
    end;
    FreeMem(pBuffer, VerInfoSize);
  end;
  ToggleWow64FsRedirection();
end;

function JoinPath(Path1, Path2: UnicodeString): UnicodeString;
begin
  if (Length(Path1) > 0) and (Length(Path2) > 0) then
  begin
    while Path1[Length(Path1)] = '\' do
      Path1 := Copy(Path1, 1, Length(Path1) - 1);
    while Path2[1] = '\' do
      Path2 := Copy(Path2, 2, Length(Path2) - 1);
    result := Path1 + '\' + Path2;
  end
  else
    result := '';
end;

procedure InitializeUnit();
begin
  PerformWow64FsRedirection := IsProcessWoW64();
  Wow64FsRedirectionOldValue := nil;
end;

initialization
  InitializeUnit();

end.
