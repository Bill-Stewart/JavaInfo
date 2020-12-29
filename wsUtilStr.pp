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
  wsUtilStr;

interface

type
  TArrayOfString = array of unicodestring;

// Compares two version strings (e.g., 'a.b.c.d') and returns < 0 if V1 < V2,
// 0 if V1 = V2, or > 0 if V1 > V2
function CompareVersionStrings(V1, V2: unicodestring): longint;

// Converts the specified integer to a string a returns the result
function IntToStr(const I: int64): unicodestring;

// Converts the specified string to a number and returns the result; if the
// conversion fails, returns the value specified by Def
function StrToIntDef(const S: unicodestring; const Def: longint): longint;

// Converts the specified unicode string to a regular (multi-byte) string and
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

// Compares two version number strings; returns:
// -1 if V1 < V2, 0 if V1 = V2, or 1 if V1 > V2
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

function IntToStr(const I: int64): unicodestring;
  begin
  Str(I, result);
  end;

function UnicodeStringToString(const S: unicodestring): string;
  var
    NumChars, BufSize: DWORD;
    pBuffer: pchar;
  begin
  result := '';
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
