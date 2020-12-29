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

// Returns a version number string (a.b.c.d) for the named file; returns an
// empty string if the function failed (e.g., no version information found)
function GetFileVersion(const FileName: unicodestring): unicodestring;

// Returns if the named executable image file is 64-bit in Is64Bit parameter;
// returns true if function succeeded, or non-zero if it failed
function IsImage64Bit(const FileName: unicodestring; var Is64Bit: boolean): boolean;

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
    BufSize: DWORD;
    FileName: pwidechar;
    NumChars: DWORD;
  begin
  result := '';
  BufSize := MAX_PATH + SizeOf(widechar);
  GetMem(FileName, BufSize);
  ToggleWow64FsRedirection();
  NumChars := SearchPathW(pwidechar(DirList),  // LPCSTR lpPath
                          pwidechar(Name),     // LPCSTR lpFileName
                          nil,                 // LPCSTR lpExtension
                          BufSize,             // DWORD  nBufferLength
                          FileName,            // LPSTR  lpBuffer
                          nil);                // LPSTR  lpFilePart
  ToggleWow64FsRedirection();
  if NumChars > 0 then result := FileName;
  FreeMem(FileName, BufSize);
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

function IsImage64Bit(const FileName: unicodestring; var Is64Bit: boolean): boolean;
  var
    pLoadedImage: PLOADED_IMAGE;
  begin
  result := false;
  ToggleWow64FsRedirection();
  pLoadedImage := ImageLoad(pchar(UnicodeStringToString(FileName)), '');
  ToggleWow64FsRedirection();
  result := Assigned(pLoadedImage);
  if result then
    begin
    Is64Bit := pLoadedImage^.Fileheader^.FileHeader.Machine <> IMAGE_FILE_MACHINE_I386;
    ImageUnload(pLoadedImage);
    end;
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
