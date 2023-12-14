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

unit wsUtilFile;

interface

// Returns true if the named directorty exists, or false if not
function DirExists(const DirName: string): Boolean;

// Returns directory name from a path without trailing separator
function ExtractFileDir(const FileName: string): string;

// Returns true if the named file exists, or false if not
function FileExists(const FileName: string): Boolean;

// Searches for a named file in semicolon-delimited list of directory names;
// returns an empty string if nothing found
function FileSearch(const Name, DirList: string): string;

// Gets the specified file's binary type to the BinaryType parameter; returns
// 0 for success, or non-zero for failure
function GetBinaryType(const FileName: string; var BinaryType: Word): DWORD;

// Returns a version number string (a.b.c.d) for the named file; returns an
// empty string if the function failed (e.g., no version information found)
function GetFileVersion(const FileName: string): string;

// Concatenates Path1 to Path2 with only a single path separator between
function JoinPath(Path1, Path2: string): string;

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
      if not Wow64DisableWow64FsRedirection(@Wow64FsRedirectionOldValue) then  // PVOID *OldValue
        Wow64FsRedirectionOldValue := nil;
    end
    else
    begin
      if Wow64RevertWow64FsRedirection(Wow64FsRedirectionOldValue) then  // PVOID OlValue
        Wow64FsRedirectionOldValue := nil;
    end;
  end;
end;

function DirExists(const DirName: string): Boolean;
var
  Attrs: DWORD;
begin
  ToggleWow64FsRedirection();
  Attrs := GetFileAttributesW(PChar(DirName));  // LPCWSTR lpFileName
  ToggleWow64FsRedirection();
  result := (Attrs <> INVALID_FILE_ATTRIBUTES) and
    ((Attrs and FILE_ATTRIBUTE_DIRECTORY) <> 0);
end;

function ExtractFileDir(const FileName: string): string;
const
  Separators: string = ':\';
var
  I: Integer;
begin
  I := Length(FileName);
  while (I > 0) and (Pos(FileName[I], Separators) > 0) do
    Dec(I);
  if (I > 1) and (FileName[I] = '\') and (Pos(FileName[I - 1], Separators) > 0) then
    Dec(I);
  result := Copy(FileName, 1, I);
end;

function FileExists(const FileName: string): Boolean;
var
  Attrs: DWORD;
begin
  ToggleWow64FsRedirection();
  Attrs := GetFileAttributesW(PChar(FileName));  // LPCWSTR lpFileName
  ToggleWow64FsRedirection();
  result := (Attrs <> INVALID_FILE_ATTRIBUTES) and
    ((Attrs and FILE_ATTRIBUTE_DIRECTORY) = 0);
end;

function FileSearch(const Name, DirList: string): string;
var
  NumChars, BufSize: DWORD;
  pBuffer: PChar;
begin
  result := '';
  // Get number of characters needed for buffer
  ToggleWow64FsRedirection();
  NumChars := SearchPathW(PChar(DirList),  // LPCSTR lpPath
    PChar(Name),                           // LPCSTR lpFilename
    nil,                                   // LPCSTR lpExtension
    0,                                     // DWORD  nBufferLength
    nil,                                   // LPSTR  lpBuffer
    nil);                                  // LPSTR  lpFilePart
  if NumChars > 0 then
  begin
    BufSize := NumChars * SizeOf(Char);
    GetMem(pBuffer, BufSize);
    if SearchPathW(PChar(DirList),  // LPCSTR lpPath
      PChar(Name),                  // LPCSTR lpFilename
      nil,                          // LPCSTR lpExtension
      NumChars,                     // DWORD  nBufferLength
      pBuffer,                      // LPSTR  lpBuffer
      nil) > 0 then                 // LPSTR  lpFilePart
    begin
      result := pBuffer;
    end;
    FreeMem(pBuffer);
  end;
  ToggleWow64FsRedirection();
end;

function GetBinaryType(const FileName: string; var BinaryType: Word): DWORD;
var
  ImagePath: RawByteString;
  pLoadedImage: PLOADED_IMAGE;
begin
  ImagePath := UnicodeStringToAnsi(FileName, CP_ACP);
  if Length(ImagePath) = 0 then
    exit(ERROR_INVALID_DATA);
  ToggleWow64FsRedirection();
  pLoadedImage := ImageLoad(PAnsiChar(ImagePath),  // PCSTR DllName
    '');                                           // PCSTR DllPath
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

function GetFileVersion(const FileName: string): string;
var
  VerInfoSize, Handle: DWORD;
  pBuffer: Pointer;
  pFileInfo: ^VS_FIXEDFILEINFO;
  Len: UINT;
begin
  result := '';
  ToggleWow64FsRedirection();
  VerInfoSize := GetFileVersionInfoSizeW(PChar(FileName),  // LPCWSTR lptstrFilename
    Handle);                                               // LPDWORD lpdwHandle
  if VerInfoSize > 0 then
  begin
    GetMem(pBuffer, VerInfoSize);
    if GetFileVersionInfoW(PChar(FileName),  // LPCWSTR lptstrFilename
      Handle,                                // DWORD   dwHandle
      VerInfoSize,                           // DWORD   dwLen
      pBuffer) then                          // LPVOID  lpData
    begin
      if VerQueryValueW(pBuffer,  // LPCVOID pBlock
        '\',                      // LPCWSTR lpSubBlock
        pFileInfo,                // LPVOID  *lplpBuffer
        Len) then                 // PUINT   puLen
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
    FreeMem(pBuffer);
  end;
  ToggleWow64FsRedirection();
end;

function JoinPath(Path1, Path2: string): string;
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
