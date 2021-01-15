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
  wsUtilFile;

interface

// Returns true if the named directorty exists, or false if not
function DirExists(const DirName: unicodestring): boolean;

// Returns directory name from a path without trailing separator
function ExtractFileDir(const FileName: unicodestring): unicodestring;

// Returns true if the named file exists, or false if not
function FileExists(const FileName: unicodestring): boolean;

// Searches for a named file in semicolon-delimited list of directory names;
// returns an empty string if nothing found
function FileSearch(const Name, DirList: unicodestring): unicodestring;

// Gets the specified file's binary type to the BinaryType parameter; returns
// 0 for success, or non-zero for failure
function GetBinaryType(const FileName: unicodestring; var BinaryType: word): DWORD;

// Gets the path for the current running executable
function GetExecutablePath(): unicodestring;

// Returns a version number string (a.b.c.d) for the named file; returns an
// empty string if the function failed (e.g., no version information found)
function GetFileVersion(const FileName: unicodestring): unicodestring;

// Concatenates Path1 to Path2 with only a single path separator between
function JoinPath(Path1, Path2: unicodestring): unicodestring;

implementation

uses
  imagehlp,
  windows,
  wsUtilArch,
  wsUtilStr;

const
  INVALID_FILE_ATTRIBUTES = DWORD(-1);

var
  PerformWow64FsRedirection: boolean;
  Wow64FsRedirectionOldValue: pointer;

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
      if Assigned(Wow64FsRedirectionOldValue) then
        begin
        if Wow64RevertWow64FsRedirection(Wow64FsRedirectionOldValue) then
          Wow64FsRedirectionOldValue := nil;
        end;
      end;
    end;
  end;

function DirExists(const DirName: unicodestring): boolean;
  var
    Attrs: DWORD;
  begin
  ToggleWow64FsRedirection();
  Attrs := GetFileAttributesW(pwidechar(DirName));
  ToggleWow64FsRedirection();
  result := (Attrs <> INVALID_FILE_ATTRIBUTES) and
    ((Attrs and FILE_ATTRIBUTE_DIRECTORY) <> 0);
  end;

function ExtractFileDir(const FileName: unicodestring): unicodestring;
  const
    Separators: set of char = [':','\'];
  var
    I: longint;
  begin
  I := Length(FileName);
  while (I > 0) and (not (FileName[I] in Separators)) do
    Dec(I);
  if (I > 1) and (FileName[I] = '\') and (not (FileName[I - 1] in Separators)) then
    Dec(I);
  result := Copy(FileName, 1, I);
  end;

function FileExists(const FileName: unicodestring): boolean;
  var
    Attrs: DWORD;
  begin
  ToggleWow64FsRedirection();
  Attrs := GetFileAttributesW(pwidechar(FileName));
  ToggleWow64FsRedirection();
  result := (Attrs <> INVALID_FILE_ATTRIBUTES) and
    ((Attrs and FILE_ATTRIBUTE_DIRECTORY) = 0);
  end;

function FileSearch(const Name, DirList: unicodestring): unicodestring;
  var
    NumChars, BufSize: DWORD;
    pBuffer: pwidechar;
  begin
  result := '';
  // Get number of characters needed for buffer
  ToggleWow64FsRedirection();
  NumChars := SearchPathW(pwidechar(DirList),  // LPCSTR lpPath
                          pwideChar(Name),     // LPCSTR lpFilename
                          nil,                 // LPCSTR lpExtension
                          0,                   // DWORD  nBufferLength
                          nil,                 // LPSTR  lpBuffer
                          nil);                // LPSTR  lpFilePart
  if NumChars > 0 then
    begin
    BufSize := NumChars * SizeOf(widechar);
    GetMem(pBuffer, BufSize);
    if SearchPathW(pwidechar(DirList),  // LPCSTR lpPath
                   pwideChar(Name),     // LPCSTR lpFilename
                   nil,                 // LPCSTR lpExtension
                   NumChars,            // DWORD  nBufferLength
                   pBuffer,             // LPSTR  lpBuffer
                   nil) > 0 then        // LPSTR  lpFilePart
      result := pBuffer;
    FreeMem(pBuffer, BufSize);
    end;
  ToggleWow64FsRedirection();
  end;

function GetBinaryType(const FileName: unicodestring; var BinaryType: word): DWORD;
  var
    pLoadedImage: PLOADED_IMAGE;
  begin
  ToggleWow64FsRedirection();
  pLoadedImage := ImageLoad(pchar(UnicodeStringToString(FileName)), '');
  ToggleWow64FsRedirection();
  if Assigned(pLoadedImage) then result := 0 else result := GetLastError();
  if result = 0 then
    begin
    BinaryType := pLoadedImage^.Fileheader^.FileHeader.Machine;
    ImageUnload(pLoadedImage);
    end;
  end;

function GetExecutablePath(): unicodestring;
  var
    NumChars, BufSize: DWORD;
    pBuffer: pwidechar;
  begin
  result := '';
  // GetModuleFileNameW() doesn't let us determine the needed length of the
  // string by setting third parameter to zero, so just create a 64K buffer
  NumChars := 32768;
  BufSize := NumChars * SizeOf(widechar);
  GetMem(pBuffer, BufSize);
  NumChars := GetModuleFileNameW(0,          // HMODULE hModule
                                 pBuffer,    // LPWSTR  lpFilename
                                 NumChars);  // DWORD   nSize
  if (NumChars > 0) and (GetLastError() = ERROR_SUCCESS) then
    result := pBuffer;
  FreeMem(pBuffer, BufSize);
  end;

function GetFileVersion(const FileName: unicodestring): unicodestring;
  var
    VerInfoSize, Handle: DWORD;
    pBuffer: pointer;
    pFileInfo: ^VS_FIXEDFILEINFO;
    Len: UINT;
  begin
  result := '';
  ToggleWow64FsRedirection();
  VerInfoSize := GetFileVersionInfoSizeW(pwidechar(FileName), Handle);
  if VerInfoSize > 0 then
    begin
    GetMem(pBuffer, VerInfoSize);
    if GetFileVersionInfoW(pwidechar(FileName), Handle, VerInfoSize, pBuffer) then
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

function JoinPath(Path1, Path2: unicodestring): unicodestring;
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
