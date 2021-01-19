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
  wsUtilStr;

interface

type
  TArrayOfString = array of unicodestring;

// Compares two version number strings; returns:
// < 0 if V1 < V2, 0 if V1 = V2, or > 0 if V1 > V2
function CompareVersionStrings(V1, V2: unicodestring): longint;

// Expands a version string into a full 4-part version string; missing parts
// are returned as zeroes; e.g., '10' returns '10.0.0.0', '11.1' returns
// '11.1.0.0', and '12.1.2' returns '12.1.2.0'; returns an empty string if
// no version number or an invalid version number is supplied; each part must
// be in the range 0..65535 (16-bit unsigned - word)
function ExpandVersionString(const Version: unicodestring): unicodestring;

// Scans a string for digit characters and returns found digits in OutputStr;
// returns false if InputStr contains no digits
function GetDigitsInString(const InputStr: unicodestring; var OutputStr: unicodestring): boolean;

// Converts the specified integer to a string a returns the result
function IntToStr(const I: int64): unicodestring;

// Removes trailing '\' from string unless string is 3 characters long and
// second character is ':'
function RemoveBackslashUnlessRoot(S: unicodestring): unicodestring;

// Converts the specified string to a number and returns the result; if the
// conversion fails, returns Def
function StrToIntDef(const S: unicodestring; const Def: longint): longint;

// Converts the specified string to a Unicode string
function StringToUnicodeString(const S: string): unicodestring;

// Converts the specified Unicode string to a regular (multi-byte) string and
// returns the resulting multi-byte string
function UnicodeStringToString(const S: unicodestring): string;

implementation

uses
  windows;

function StrToIntDef(const S: unicodestring; const Def: longint): longint;
  var
    Code: word;
  begin
  Val(S, result, Code);
  if Code > 0 then result := Def;
  end;

function CompareVersionStrings(V1, V2: unicodestring): longint;
  var
    P, N1, N2: longint;
  begin
  result := 0;
  while (result = 0) and ((V1 <> '') or (V2 <> '')) do
    begin
    P := Pos('.', V1);
    if P > 0 then
      begin
      N1 := StrToIntDef(Copy(V1, 1, P - 1), 0);
      Delete(V1, 1, P);
      end
    else if V1 <> '' then
      begin
      N1 := StrToIntDef(V1, 0);
      V1 := '';
      end
    else
      N1 := 0;
    P := Pos('.', V2);
    if P > 0 then
      begin
      N2 := StrToIntDef(Copy(V2, 1, P - 1), 0);
      Delete(V2, 1, P);
      end
    else if V2 <> '' then
      begin
      N2 := StrToIntDef(V2, 0);
      V2 := '';
      end
    else
      N2 := 0;
    if N1 < N2 then
      result := -1
    else if N1 > N2 then
      result := 1;
    end;
  end;

// Returns the position of SubString in S starting at Offset; returns 0
// if SubString is not found in S
function PosEx(const SubString, S: unicodestring; Offset: longint): longint;
  var
    SubLen, MaxLen, I: longint;
    FirstChar: widechar;
    pFirstChar: pwidechar;
  begin
  result := 0;
  SubLen := Length(SubString);
  if (SubLen > 0) and (Offset > 0) and (Offset <= Length(S)) then
    begin
    MaxLen := Length(S) - SubLen;
    FirstChar := SubString[1];
    I := IndexWord(S[Offset], Length(S) - Offset + 1, word(FirstChar));
    while (I >= 0) and ((Offset + I - 1) <= MaxLen) do
      begin
      pFirstChar := @S[Offset + I];
      if CompareWord(SubString[1], pFirstChar^, SubLen) = 0 then exit(Offset + I);
      Offset := Offset + I + 1;
      I := IndexWord(S[Offset], Length(S) - Offset + 1, word(FirstChar));
      end;
    end;
  end;

// Returns the number of times SubString appears in S
function CountSubstring(const SubString, S: unicodestring): longint;
  var
    P: longint;
  begin
  result := 0;
  P := PosEx(SubString, S, 1);
  while P <> 0 do
    begin
    Inc(result);
    P := PosEx(SubString, S, P + Length(SubString));
    end;
  end;

// Splits S into the Dest array using Delim as a delimiter
procedure StrSplit(S, Delim: unicodestring; var Dest: TArrayOfString);
  var
    I, P: longint;
  begin
  I := CountSubstring(Delim, S);
  if I = 0 then exit();
  SetLength(Dest, I + 1);
  for I := 0 to Length(Dest) - 1 do
    begin
    P := Pos(Delim, S);
    if P > 0 then
      begin
      Dest[I] := Copy(S, 1, P - 1);
      Delete(S, 1, P + Length(Delim) - 1);
      end
    else
      Dest[I] := S;
    end;
  end;

// Converts a word (16-bit unsigned integer) to a Unicode string
function WordToStr(const W: word): unicodestring;
  begin
  Str(W, result);
  end;

function ExpandVersionString(const Version: unicodestring): unicodestring;
  const
    VERSION_PARTS = 4;
    MAXWORD = 65535;
  var
    Part, PartCount, I: longint;
    OutParts: array[0..VERSION_PARTS - 1] of word = (0,0,0,0);
    InParts: TArrayOfString;
  begin
  result := '';
  // Special case: empty string
  if Length(Version) = 0 then exit();
  // Special case: no delimiters
  if Pos('.', Version) = 0 then
    begin
    Part := StrToIntDef(Version, -1);
    // Return empty string (error) if out of range
    if (Part < 0) or (Part > MAXWORD) then exit();
    result := Version + '.0.0.0';
    exit();
    end;
  // Split input version string into array
  StrSplit(Version, '.', InParts);
  // Version number can contain up to 4 parts
  if Length(InParts) > 4 then exit();
  // Copy up to VERSION_PARTS to output array
  PartCount := 0;
  for I := 0 to Length(InParts) - 1 do
    begin
    if PartCount < VERSION_PARTS then
      begin
      Part := StrToIntDef(InParts[I], -1);
      if (Part < 0) or (Part > MAXWORD) then exit();
      OutParts[PartCount] := word(Part);
      Inc(PartCount);
      end;
    end;
  // Construct result string
  result := WordToStr(OutParts[0]);
  for I := 1 to VERSION_PARTS - 1 do
    result := result + '.' + WordToStr(OutParts[I]);
  end;

function GetDigitsInString(const InputStr: unicodestring; var OutputStr: unicodestring): boolean;
  const
    Digits: set of char = ['0'..'9'];
  var
    DigitStr: unicodestring;
    I: longint;
  begin
  DigitStr := '';
  for I := 1 to Length(InputStr) do
    if InputStr[I] in Digits then DigitStr := DigitStr + InputStr[I];
  result := DigitStr <> '';
  if result then OutputStr := DigitStr;
  end;

function IntToStr(const I: int64): unicodestring;
  begin
  Str(I, result);
  end;

function RemoveBackslashUnlessRoot(S: unicodestring): unicodestring;
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

function StringToUnicodeString(const S: string): unicodestring;
  var
    NumChars, BufSize: DWORD;
    pBuffer: pwidechar;
  begin
  result := '';
  // Get number of characters needed for buffer
  NumChars := MultiByteToWideChar(CP_OEMCP,  // UINT   CodePage
                                  0,         // DWORD  dwFlags
                                  pchar(S),  // LPCCH  lpMultiByteStr
                                  -1,        // int    cbMultiByte
                                  nil,       // LPWSTR lpWideCharStr
                                  0);        // int    cchWideChar
  if NumChars > 0 then
    begin
    BufSize := NumChars * SizeOf(widechar);
    GetMem(pBuffer, BufSize);
    if MultiByteToWideChar(CP_OEMCP,          // UINT   CodePage
                           0,                 // DWORD  dwFlags
                          pchar(S),           // LPCCH  lpMultiByteStr
                          -1,                 // int    cbMultiByte
                          pBuffer,            // LPWSTR lpWideCharStr
                          NumChars) > 0 then  // int    cchWideChar
      result := pBuffer;
    FreeMem(pBuffer, BufSize);
    end;
  end;

function UnicodeStringToString(const S: unicodestring): string;
  var
    NumChars, BufSize: DWORD;
    pBuffer: pchar;
  begin
  result := '';
  // Get number of characters needed for buffer
  NumChars := WideCharToMultiByte(CP_OEMCP,      // UINT   CodePage
                                  0,             // DWORD  dwFlags
                                  pwidechar(S),  // LPCWCH lpWideCharStr
                                  -1,            // int    cchWideChar
                                  nil,           // LPSTR  lpMultiByteStr
                                  0,             // int    cbMultiByte
                                  nil,           // LPCCH  lpDefaultChar
                                  nil);          // LPBOOL lpUsedDefaultChar
  if NumChars > 0 then
    begin
    BufSize := NumChars * SizeOf(char);
    GetMem(pBuffer, BufSize);
    if WideCharToMultiByte(CP_OEMCP,      // UINT   CodePage
                           0,             // DWORD  dwFlags
                           pwidechar(S),  // LPCWCH lpWideCharStr
                           -1,            // int    cchWideChar
                           pBuffer,       // LPSTR  lpMultiByteStr
                           NumChars,      // int    cbMultiByte
                           nil,           // LPCCH  lpDefaultChar
                           nil) > 0 then  // LPBOOL lpUsedDefaultChar
      result := pBuffer;
    FreeMem(pBuffer, BufSize);
    end;
  end;

begin
end.
