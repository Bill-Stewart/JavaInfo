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

unit wsUtilVer;

interface

// Returns true if the specified version string is valid, or false otherwise
function TestVersionString(const S: string): Boolean;

// Compares two version strings 'a[.b[.c[.d]]]'
// Returns:
// < 0  if V1 < V2
// 0    if V1 = V2
// > 0  if V1 > V2
function CompareVersionStrings(const V1, V2: string): Integer;

// Expands a version string into a full 4-part version string; missing parts
// are returned as zeroes; e.g., '10' returns '10.0.0.0', '11.1' returns
// '11.1.0.0', and '12.1.2' returns '12.1.2.0'; returns an empty string if
// no version number or an invalid version number is supplied; each part must
// be in the range 0..65535 (16-bit unsigned - word)
function ExpandVersionString(const S: string): string;

implementation

type
  TStringArray = array of string;
  TVersionArray = array[0..3] of Word;

// Returns the number of times Substring appears in S
function CountSubstring(const Substring, S: string): Integer;
var
  P: Integer;
begin
  result := 0;
  P := Pos(Substring, S, 1);
  while P <> 0 do
  begin
    Inc(result);
    P := Pos(Substring, S, P + Length(Substring));
  end;
end;

// Splits S into the Dest array using Delim as a delimiter
procedure StrSplit(S, Delim: string; var Dest: TStringArray);
var
  I, P: Integer;
begin
  I := CountSubstring(Delim, S);
  // If no delimiters, Dest is a single-element array
  if I = 0 then
  begin
    SetLength(Dest, 1);
    Dest[0] := S;
    exit;
  end;
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

function IntToStr(const I: Integer): string;
begin
  Str(I, result);
end;

function StrToInt(const S: string; var I: Integer): Boolean;
var
  Code: Word;
begin
  Val(S, I, Code);
  result := Code = 0;
end;

function StrToWord(const S: string; var W: Word): Boolean;
var
  Code: Word;
begin
  Val(S, W, Code);
  result := Code = 0;
end;

function GetVersionArray(const S: string; var Version: TVersionArray): Boolean;
var
  A: TStringArray;
  ALen, I, Part: Integer;
begin
  result := false;
  StrSplit(S, '.', A);
  ALen := Length(A);
  if ALen > 4 then
    exit;
  if ALen < 4 then
  begin
    SetLength(A, 4);
    for I := ALen to 3 do
      A[I] := '0';
  end;
  for I := 0 to Length(A) - 1 do
  begin
    result := StrToInt(A[I], Part);
    if not result then
      exit;
    result := (Part >= 0) and (Part <= $FFFF);
    if not result then
      exit;
  end;
  for I := 0 to 3 do
  begin
    result := StrToWord(A[I], Version[I]);
    if not result then
      exit;
  end;
end;

function TestVersionString(const S: string): Boolean;
var
  Version: TVersionArray;
begin
  result := GetVersionArray(S, Version);
end;

function CompareVersionStrings(const V1, V2: string): Integer;
var
  Ver1, Ver2: TVersionArray;
  I: Integer;
  Word1, Word2: Word;
begin
  result := 0;
  if not GetVersionArray(V1, Ver1) then
    exit;
  if not GetVersionArray(V2, Ver2) then
    exit;
  for I := 0 to 3 do
  begin
    Word1 := Ver1[I];
    Word2 := Ver2[I];
    if Word1 > Word2 then
    begin
      result := 1;
      exit;
    end
    else if Word1 < Word2 then
    begin
      result := -1;
      exit;
    end;
  end;
end;

function ExpandVersionString(const S: string): string;
var
  Version: TVersionArray;
  I: Integer;
begin
  result := '';
  if not GetVersionArray(S, Version) then
    exit;
  result := IntToStr(Version[0]);
  for I := 1 to 3 do
    result := result + '.' + IntToStr(Version[I]);
end;

begin
end.
