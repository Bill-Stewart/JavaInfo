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
{$MODESWITCH UNICODESTRINGS}

unit wsUtilReg;

interface

uses
  Windows;

type
  TStringArray = array of string;

const
  HKEY_LOCAL_MACHINE_64 = $80000102;
  HKEY_LOCAL_MACHINE_32 = $80000202;

// NOTE: The RootKey parameter in the below functions can also be
// HKEY_LOCAL_MACHINE_64 (works from 32-bit process) or HKEY_LOCAL_MACHINE_32

// Gets registry subkey names into Names array; returns true for success
// or false for failure
function RegGetSubKeyNames(RootKey: HKEY; const SubKeyName: string;
  var Names: TStringArray): Boolean;

// Returns true if the specified registry subkey exists or false otherwise
function RegKeyExists(RootKey: HKEY; const SubKeyName: string): Boolean;

// Returns the ValueName value from the specified key and subkey into
// ResultStr; returns true for success or false for failure
function RegQueryStringValue(RootKey: HKEY; const SubKeyName, ValueName: string;
  var ResultStr: string): Boolean;

implementation

// Updates RootKey and AccessFlags appropriately if using _32 or _64 RootKey
procedure UpdateRootKeyAndFlags(var RootKey: HKEY; var AccessFlags: REGSAM);
begin
  if (RootKey and KEY_WOW64_32KEY) <> 0 then
  begin
    RootKey := RootKey and (not KEY_WOW64_32KEY);
    AccessFlags := AccessFlags or KEY_WOW64_32KEY;
  end
  else if (RootKey and KEY_WOW64_64KEY) <> 0 then
  begin
    RootKey := RootKey and (not KEY_WOW64_64KEY);
    AccessFlags := AccessFlags or KEY_WOW64_64KEY;
  end;
end;

function RegGetSubKeyNames(RootKey: HKEY; const SubKeyName: string;
  var Names: TStringArray): Boolean;
var
  AccessFlags: REGSAM;
  hkHandle: HANDLE;
  NumSubKeys: DWORD;
  MaxSubKeyNameLen: DWORD;
  NumValues: DWORD;
  MaxValueNameLen: DWORD;
  MaxValueLen: DWORD;
  Name: PChar;
  I: DWORD;
  MaxSubKeyNameLen2: DWORD;
begin
  AccessFlags := KEY_READ;
  UpdateRootKeyAndFlags(RootKey, AccessFlags);
  result := RegOpenKeyExW(RootKey,  // HKEY   hKey
    PChar(SubKeyName),              // LPCSTR lpSubKey
    0,                              // DWORD  ulOptions
    AccessFlags,                    // REGSAM samdesired
    hkHandle) = 0;                  // PHKEY  phkResult
  if result then
  begin
    result := RegQueryInfoKeyW(hkHandle,  // HKEY      hKey
      nil,                                // LPSTR     lpClass
      nil,                                // LPDWORD   lpcchClass
      nil,                                // LPDWORD   lpReserved
      @NumSubKeys,                        // LPDWORD   lpcSubKeys
      @MaxSubKeyNameLen,                  // LPDWORD   lpcbMaxSubKeyLen
      nil,                                // LPDWORD   lpcbMaxClassLen
      @NumValues,                         // LPDWORD   lpcValues
      @MaxValueNameLen,                   // LPDWORD   lpcbMaxValueNameLen
      @MaxValueLen,                       // LPDWORD   lpcbMaxValueLen
      nil,                                // LPDWORD   lpcbSecurityDescriptor
      nil) = 0;                           // PFILETIME lpftLastWriteTime
    // Set dynamic array size
    SetLength(Names, NumSubKeys);
    if NumSubKeys > 0 then
    begin
      // lpcbMaxValueNameLen doesn't include terminating null
      MaxSubKeyNameLen := (MaxSubKeyNameLen + 1) * SizeOf(Char);
      // Each call to RegEnumKeyEx will use this buffer
      GetMem(Name, MaxSubKeyNameLen);
      // Enumerate subkey names
      for I := 0 to NumSubKeys - 1 do
      begin
        // Reset max buffer size on each call because RegEnumKeyExW updates it
        MaxSubKeyNameLen2 := MaxSubKeyNameLen;
        if RegEnumKeyExW(hkHandle,  // HKEY      hKey
          I,                        // DWORD     dwIndex
          Name,                     // LPSTR     lpName
          @MaxSubKeyNameLen2,       // LPDWORD   lpcchName
          nil,                      // LPDWORD   lpReserved
          nil,                      // LPSTR     lpClass
          nil,                      // LPDWORD   lpcchClass
          nil) = 0 then             // PFILETIME lpftLastWriteTime
          Names[I] := Name
        else
          Names[I] := '';
      end;
      FreeMem(Name);
    end;
    RegCloseKey(hkHandle);
  end;
end;

function RegKeyExists(RootKey: HKEY; const SubKeyName: string): Boolean;
var
  AccessFlags: REGSAM;
  hkHandle: HANDLE;
begin
  AccessFlags := KEY_READ;
  UpdateRootKeyAndFlags(RootKey, AccessFlags);
  result := RegOpenKeyExW(RootKey,  // HKEY   hKey
    PChar(SubKeyName),              // LPCSTR lpSubKey
    0,                              // DWORD  ulOptions
    AccessFlags,                    // REGSAM samDesired
    hkHandle) = 0;                  // PHKEY  phkResult
  if result then
    RegCloseKey(hkHandle);
end;

function RegQueryStringValue(RootKey: HKEY; const SubKeyName, ValueName: string;
  var ResultStr: string): Boolean;
var
  AccessFlags: REGSAM;
  hkHandle: HKEY;
  ValueType, ValueSize, BufSize: DWORD;
  pData, pBuf: Pointer;
begin
  AccessFlags := KEY_READ;
  UpdateRootKeyAndFlags(RootKey, AccessFlags);
  result := RegOpenKeyExW(RootKey,  // HKEY   hKey
    PChar(SubKeyName),              // LPCSTR lpSubKey
    0,                              // DWORD  ulOptions
    AccessFlags,                    // REGSAM samDesired
    hkHandle) = 0;                  // PHKEY  phkResult
  if result then
  begin
    // First call: Get value size
    result := RegQueryValueExW(hkHandle,  // HKEY    hKey
      PChar(ValueName),                   // LPCSTR  lpValueName
      nil,                                // LPDWORD lpReserved
      @ValueType,                         // LPDWORD lpType
      nil,                                // LPBYTE  lpData
      @ValueSize) = 0;                    // LPDWORD lpcbData
    if result then
    begin
      // Must be REG_SZ or REG_EXPAND_SZ
      if (ValueType = REG_SZ) or (ValueType = REG_EXPAND_SZ) then
      begin
        GetMem(pData, ValueSize);
        // Second call: Get value data
        result := RegQueryValueExW(hkHandle,  // HKEY    hKey
          PChar(ValueName),                   // LPCSTR  lpValueName
          nil,                                // LPDWORD lpReserved
          @ValueType,                         // LPDWORD lpType
          pData,                              // LPBYTE  lpData
          @ValueSize) = 0;                    // LPDWORD lpcbData
        if result then
          // Last char is null
          if PChar(pData)[(ValueSize div SizeOf(Char)) - 1] = #0 then
            ResultStr := PChar(pData)
          else
          begin
            // Last char not null: Return as null-terminated string
            BufSize := ValueSize + SizeOf(Char);
            GetMem(pBuf, BufSize);
            FillChar(pBuf^, BufSize, 0);
            Move(pData^, pBuf^, ValueSize);
            ResultStr := PChar(pBuf);
            FreeMem(pBuf);
          end;
        FreeMem(pData);
      end
      else
        result := false;
    end;
    RegCloseKey(hkHandle);
  end;
end;

begin
end.
