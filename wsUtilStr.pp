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

unit wsUtilStr;

interface

uses
  Windows;

// Scans a string for digit characters and returns found digits in OutputStr;
// returns false if InputStr contains no digits
function GetDigitsInString(const InputStr: string; var OutputStr: string): Boolean;

// Returns I as a string
function IntToStr(const I: Integer): string;

// Removes trailing '\' from string unless string is 3 characters long and
// second character is ':'
function RemoveBackslashUnlessRoot(S: string): string;

// Converts the specified string to a Unicode string
function AnsiToUnicodeString(const S: RawByteString; const CodePage: UINT): string;

// Converts the specified Unicode string to a regular (multi-byte) string and
// returns the resulting multi-byte string
function UnicodeStringToAnsi(const S: string; const CodePage: UINT): RawByteString;

implementation

function GetDigitsInString(const InputStr: string; var OutputStr: string): Boolean;
const
  Digits: string = '0123456789';
var
  DigitStr: string;
  I: Integer;
begin
  DigitStr := '';
  for I := 1 to Length(InputStr) do
    if Pos(InputStr[I], Digits) > 0 then
      DigitStr := DigitStr + InputStr[I];
  result := DigitStr <> '';
  if result then
    OutputStr := DigitStr;
end;

function IntToStr(const I: Integer): string;
begin
  Str(I, result);
end;

function RemoveBackslashUnlessRoot(S: string): string;
begin
  result := '';
  if s <> '' then
  begin
    if (Length(S) = 3) and (S[2] = ':') and (S[3] = '\') then
      exit(S);
    while S[Length(S)] = '\' do
      SetLength(S, Length(S) - 1);
    result := S;
  end;
end;

function AnsiToUnicodeString(const S: RawByteString; const CodePage: UINT): string;
var
  NumChars, BufSize: DWORD;
  pBuffer: PChar;
begin
  result := '';
  // Get number of characters needed for buffer
  NumChars := MultiByteToWideChar(CodePage,  // UINT   CodePage
    0,                                       // DWORD  dwFlags
    PAnsiChar(S),                            // LPCCH  lpMultiByteStr
    -1,                                      // int    cbMultiByte
    nil,                                     // LPWSTR lpWideCharStr
    0);                                      // int    cchWideChar
  if NumChars > 0 then
  begin
    BufSize := NumChars * SizeOf(Char);
    GetMem(pBuffer, BufSize);
    if MultiByteToWideChar(CodePage,  // UINT   CodePage
      0,                              // DWORD  dwFlags
      PAnsiChar(S),                   // LPCCH  lpMultiByteStr
      -1,                             // int    cbMultiByte
      pBuffer,                        // LPWSTR lpWideCharStr
      NumChars) > 0 then              // int    cchWideChar
    begin
      result := pBuffer;
    end;
    FreeMem(pBuffer);
  end;
end;

function UnicodeStringToAnsi(const S: string; const CodePage: UINT): RawByteString;
var
  NumChars, BufSize: DWORD;
  pBuffer: PAnsiChar;
begin
  result := '';
  // Get number of characters needed for buffer
  NumChars := WideCharToMultiByte(CodePage,  // UINT   CodePage
    0,                                       // DWORD  dwFlags
    PChar(S),                                // LPCWCH lpWideCharStr
    -1,                                      // int    cchWideChar
    nil,                                     // LPSTR  lpMultiByteStr
    0,                                       // int    cbMultiByte
    nil,                                     // LPCCH  lpDefaultChar
    nil);                                    // LPBOOL lpUsedDefaultChar
  if NumChars > 0 then
  begin
    BufSize := NumChars * SizeOf(AnsiChar);
    GetMem(pBuffer, BufSize);
    if WideCharToMultiByte(CodePage,  // UINT   CodePage
      0,                              // DWORD  dwFlags
      PChar(S),                       // LPCWCH lpWideCharStr
      -1,                             // int    cchWideChar
      pBuffer,                        // LPSTR  lpMultiByteStr
      NumChars,                       // int    cbMultiByte
      nil,                            // LPCCH  lpDefaultChar
      nil) > 0 then                   // LPBOOL lpUsedDefaultChar
    begin
      result := pBuffer;
    end;
    FreeMem(pBuffer);
  end;
end;

begin
end.
