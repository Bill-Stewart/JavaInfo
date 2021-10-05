# Copyright (C) 2020-2021 by Bill Stewart (bstewart at iname.com)
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU Lesser General Public License as published by the Free
# Software Foundation; either version 3 of the License, or (at your option) any
# later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Lesser Public License for more
# details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program. If not, see https://www.gnu.org/licenses/.

#requires -version 2

# Prerequisites:
# * 64-bit JavaInfo.dll v1.2.0.0 or later in x64 directory
# * 32-bit JavaInfo.dll v1.2.0.0 or later in x86 directory

# If you use -MinimumVersion parameter, specify a version number string as
# a[.b[.c[.d]]]; e.g. "-MinimumVersion 8" would test for at least Java 8
param(
  [String] $MinimumVersion
)

function Get-Platform {
  if ( [IntPtr]::Size -eq 8 ) {
    "x64"
  }
  else {
    "x86"
  }
}

$APIDefs = @"
[DllImport("{0}\\JavaInfo.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern uint IsBinary64Bit(
  string   FileName,
  out uint Is64bit
);

[DllImport("{0}\\JavaInfo.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern uint IsJavaInstalled();

[DllImport("{0}\\JavaInfo.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern uint IsJavaMinimumVersion(
  string   Version,
  out uint VersionOK
);

[DllImport("{0}\\JavaInfo.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern uint GetJavaHome(
  StringBuilder PathName,
  uint          NumChars
);

[DllImport("{0}\\JavaInfo.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern uint GetJavaVersion(
  StringBuilder Version,
  uint          NumChars
);
"@ -f (Get-Platform)

$JavaInfo = Add-Type -Name JavaInfo `
  -MemberDefinition $APIDefs `
  -Namespace "D8BE189018594F8F841FDF1359E47C6C" `
  -UsingNamespace "System.Text" `
  -PassThru `
  -ErrorAction Stop

# DLL function wrapper to retrieve strings
function Get-DLLString {
  param(
    [Management.Automation.PSMethod] $dllFunction
  )
  $result = ""
  # Create a StringBuilder with 0 capacity to get string length
  $stringBuilder = New-Object Text.StringBuilder(0)
  # Invoke function with 0 for 2nd parameter to get length as return value
  $numChars = $dllFunction.Invoke($stringBuilder,0)
  if ( $numChars -gt 0 ) {
    # Specify size of string and call function again
    $stringBuilder.Capacity = $numChars
    if ( $dllFunction.Invoke($stringBuilder,$numChars) -gt 0 ) {
      $result = $stringBuilder.ToString()
    }
  }
  $result
}

# Wrapper for GetJavaHome() DLL function
function Get-JavaHome {
  Get-DLLString ($JavaInfo::GetJavaHome)
}

# Wrapper for GetJavaVersion() DLL function
function Get-JavaVersion {
  Get-DLLString ($JavaInfo::GetJavaVersion)
}

# Wrapper for IsBinary64Bit() DLL function
function Get-Binary64Bit {
  param(
    [String] $fileName
  )
  $result = "Unknown"
  if ( $fileName ) {
    # Variable must exist before calling as [Ref] parameter
    $is64Bit = $null
    # Function returns 0 if successful
    if ( $JavaInfo::IsBinary64Bit($fileName,[Ref] $is64Bit) -eq 0 ) {
      if ( $is64Bit -eq 1 ) {
        $result = "Yes"
      }
      else {
        $result = "Yes"
      }
    }
  }
  $result
}

# Wrapper for IsJavaMinimumVersion() DLL function
function Get-JavaMinimumVersion {
  param(
    [String] $version
  )
  $result = ""
  # Variable must exist before calling as [Ref] parameter
  $versionOK = $null
  if ( $JavaInfo::IsJavaMinimumVersion($version,[Ref] $versionOK) -eq 0 ) {
    if ( $versionOK -eq 1 ) {
      $result = "Yes"
    }
    else {
      $result = "No"
    }
  }
  $result
}

# Main body of script follows...

try {
  $IsJavaInstalled = $JavaInfo::IsJavaInstalled() -eq 1
}
catch {
  # End script with error message if DLL function failed
  Write-Error $_
  return
}

if ( $IsJavaInstalled ) {
  $JavaHome = Get-JavaHome
  $JavaBinary = Join-Path $JavaHome "bin\java.exe"
  "Java home:`t{0}" -f $JavaHome
  "Java version:`t{0}" -f (Get-JavaVersion)
  "Java is 64-bit:`t{0}" -f (Get-Binary64Bit $JavaBinary)
  if ( $MinimumVersion ) {
    $TestVersion = Get-JavaMinimumVersion $MinimumVersion
    if ( $TestVersion -ne "" ) {
      "At least version {0}:`t{1}" -f $MinimumVersion,$TestVersion
    }
    else {
      Write-Warning "Invalid version specified with -MinimumVersion parameter."
    }
  }
}
else {
  "JavaInfo.dll did not detect a Java installation."
}
