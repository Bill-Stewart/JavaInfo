<!-- omit from toc -->
# JavaInfo.dll

JavaInfo.dll is a Windows DLL (dynamically linked library) that provides information about Java installations.

- [Author](#author)
- [License](#license)
- [Download](#download)
- [Background](#background)
- [Registry Searches](#registry-searches)
- [Functions](#functions)
  - [IsBinary64Bit](#isbinary64bit)
    - [Syntax](#syntax)
    - [Parameters](#parameters)
    - [Return Value](#return-value)
  - [IsJavaInstalled](#isjavainstalled)
    - [Syntax](#syntax-1)
    - [Return Value](#return-value-1)
  - [IsJavaMinimumVersion](#isjavaminimumversion)
    - [Syntax](#syntax-2)
    - [Parameters](#parameters-1)
    - [Return Value](#return-value-2)
  - [GetJavaHome](#getjavahome)
    - [Syntax](#syntax-3)
    - [Parameters](#parameters-2)
    - [Return Value](#return-value-3)
  - [GetJavaJVMPath](#getjavajvmpath)
    - [Syntax](#syntax-4)
    - [Parameters](#parameters-3)
    - [Return Value](#return-value-4)
  - [GetJavaVersion](#getjavaversion)
    - [Syntax](#syntax-5)
    - [Parameters](#parameters-4)
    - [Return Value](#return-value-5)

## Author

Bill Stewart - bstewart at iname dot com

## License

JavaInfo.dll is covered by the GNU Lesser Public License (LPGL). See the file `LICENSE` for details.

## Download

https://github.com/Bill-Stewart/JavaInfo/releases/

## Background

A Java Development Kit (JDK) or Java Runtime Environment (JRE) is required to run Java applications, but there's not a standard way to detect whether Java is installed and details about it. JavaInfo.dll provides this information. For example, you can use JavaInfo.dll in an installer or a Java application launcher executable to detect if Java is installed.

JavaInfo.dll searches for Java in the following ways:

1. It checks for the presence of the `JAVA_HOME`, `JDK_HOME`, and `JRE_HOME` environment variables (in that order). The value of the environment variable is the Java home directory.

2. If the environment variables noted above are not defined, JavaInfo.dll searches the directories named in the `Path` environment variable for `java.exe`. The home directory is the parent directory of the directory where `java.exe` is found. For example, if `C:\Program Files\Eclipse Adoptium\JRE11\bin` is in the path (and `java.exe` is in that directory), the Java home directory is `C:\Program Files\Eclipse Adoptium\JRE11`.

3. If `java.exe` is not found in the `Path`, JavaInfo.dll searches in the registry for the home directory of the latest Java version installed. (See [Registry Searches](#registry-searches), below, for details on the registry searches.)

> NOTE: On 64-bit platforms, JavaInfo.dll does not search the registry for 32-bit versions of Java if it finds any 64-bit versions in the registry, even if there is a newer 32-bit version installed. This only applies to the registry searches; if one of the environment variables points to a 32-bit Java installation, or if JavaInfo.dll finds a 32-bit copy of `java.exe` in the `Path`, JavaInfo.dll doesn't search the registry.

If JavaInfo.dll succeeds in finding the Java home directory using any of the above techniques, it then looks for the file _javahome_`\bin\java.exe` (where _javahome_ is the Java home directory). If the file exists, it retrieves the file's version information. If the file exists and JavaInfo.dll is successful at retrieving the file's version information, then it considers Java to be installed.

If JavaInfo.dll finds a Java installation, you can use the following paths to find Java binaries (where _javahome_ is the Java home directory):

* _javahome_`\bin\java.exe` - Console-based Java executable
* _javahome_`\bin\javaw.exe` - GUI-based Java executable

The 32-bit (x86) DLL works on both 32-bit and 64-bit versions of Windows. Use the x64 DLL with x64 executables on x64 versions of Windows.

> NOTE: When you use the the 32-bit DLL on 64-bit Windows, it correctly handles 32-bit registry and file system redirection. (That is, the 32-bit DLL can correctly detect 64-bit Java installations and return the correct path.)

## Registry Searches

JavaInfo.dll searches in the following registry locations for the location of the Java home directory:

`HKEY_LOCAL_MACHINE\SOFTWARE\JavaSoft`  
`HKEY_LOCAL_MACHINE\SOFTWARE\IBM`  
`HKEY_LOCAL_MACHINE\SOFTWARE\AdoptOpenJDK`  
`HKEY_LOCAL_MACHINE\SOFTWARE\Eclipse Adoptium`  
`HKEY_LOCAL_MACHINE\SOFTWARE\Eclipse Foundation`  
`HKEY_LOCAL_MACHINE\SOFTWARE\Semeru`  
`HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\JDK`  
`HKEY_LOCAL_MACHINE\SOFTWARE\Azul Systems\Zulu`

If other versions of Java are available that JavaInfo.dll does not detect in the registry, please contact the author so the registry detection can be improved.

## Functions

This section documents the functions exported by JavaInfo.dll.

---

### IsBinary64Bit

The `IsBinary64Bit` function detects whether a Windows binary file is 32-bit or 64-bit.

#### Syntax

C/C++:
```
DWORD IsBinary64Bit(LPWSTR FileName, PDWORD Is64Bit);
```

Pascal:
```
function IsBinary64Bit(FileName: PWideChar; Is64Bit: PDWORD): DWORD;
```

#### Parameters

`FileName`

A Unicode string containing the name of a binary file (exe or dll).

`Is64Bit`

A pointer to a variable that gets set to 1 if the specified binary file is 64-bit, or 0 otherwise. The value of this variable is not defined if the `IsBinary64Bit` function fails.

#### Return Value

The `IsBinary64Bit` function returns 0 for success, or non-zero for failure.

---

### IsJavaInstalled

The `IsJavaInstalled` function detects whether Java is installed.

#### Syntax

C/C++:
```
DWORD IsJavaInstalled;
```

Pascal:
```
function IsJavaInstalled: DWORD;
```

#### Return Value

The `IsJavaInstalled` function returns zero if no Java installations were detected, or non-zero otherwise.

---

### IsJavaMinimumVersion

The `IsJavaMinimumVersion` function checks whether the installed Java version is at least a specified version.

#### Syntax

C/C++:
```
DWORD IsJavaMinimumVersion(LPWSTR Version, PDWORD VersionOK);
```

Pascal:
```
function IsJavaMinimumVersion(Version: PWideChar; VersionOK: PDWORD): DWORD;
```

#### Parameters

`Version`

A Unicode string containing a version number. The string can contain from 1 to 4 numbers in the range 0 through 65535 separated by `.` characters.

`VersionOK`

A pointer to a variable that gets set to 1 if the installed Java version is at least the version specified in the `Version` parameter, or 0 otherwise. The value of this variable is not defined if the `IsJavaMinimumVersion` function fails.

#### Return Value

The `IsJavaMinimumVersion` function returns 0 for success, or non-zero for failure. If the version specified in the `Version` parameter is not a valid version number string, the function will return error code 87 (`ERROR_INVALID_PARAMETER`).

---

### GetJavaHome

The `GetJavaHome` function gets the Java home directory.

#### Syntax

C/C++:
```
DWORD GetJavaHome(LPWSTR PathName, DWORD NumChars);
````

Pascal:
```
function GetJavaHome(PathName: PWideChar; NumChars: DWORD): DWORD;
```

#### Parameters

`PathName`

A pointer to a variable that receives a Unicode string that contains the Java home directory.

`NumChars`

Specifies the number of characters needed to store the home directory string, not including the terminating null character. To get the required number of characters needed, call the function twice. In the first call to the function, specify a null pointer for the `PathName` parameter and `0` for the `NumChars` parameter. The function will return with the number of characters required for the buffer. Allocate a buffer of sufficient size (don't forget to include the terminating null character), then call the function a second time to retrieve the string.

#### Return Value

The `GetJavaHome` function returns zero if it failed, or non-zero if it succeeded.

---

### GetJavaJVMPath

The `GetJavaJVMPath` function gets the path and filename of jvm.dll.

#### Syntax

C/C++:
```
DWORD GetJavaJVMPath(LPWSTR PathName, DWORD NumChars);
````

Pascal:
```
function GetJavaJVMPath(PathName: PWideChar; NumChars: DWORD): DWORD;
```

#### Parameters

`PathName`

A pointer to a variable that receives a Unicode string that contains the path and filename of jvm.dll.

`NumChars`

Specifies the number of characters needed to store the path string, not including the terminating null character. To get the required number of characters needed, call the function twice. In the first call to the function, specify a null pointer for the `PathName` parameter and `0` for the `NumChars` parameter. The function will return with the number of characters required for the buffer. Allocate a buffer of sufficient size (don't forget to include the terminating null character), then call the function a second time to retrieve the string.

#### Return Value

The `GetJavaJVMPath` function returns zero if it failed, or non-zero if it succeeded.

---

### GetJavaVersion

The `GetJavaVersion` function gets the version of Java as a string in the following format: _n_`.`_n_`.`_n_`.`_n_ (where _n_ is a value between 0 and 65535, inclusive).

#### Syntax

C/C++:
```
DWORD GetJavaVersion(LPWSTR Version, DWORD NumChars);
````

Pascal:
```
function GetJavaVersion(Version: PWideChar; NumChars: DWORD): DWORD;
```

#### Parameters

`Version`

A pointer to a variable that receives a Unicode string that contains the Java version string.

`NumChars`

Specifies the number of characters needed to store the version number string, not including the terminating null character. To get the required number of characters needed, call the function twice. In the first call to the function, specify a null pointer for the `Version` parameter and `0` for the `NumChars` parameter. The function will return with the number of characters required for the buffer. Allocate a buffer of sufficient size (don't forget to include the terminating null character), then call the function a second time to retrieve the string.

#### Return Value

The `GetJavaVersion` function returns zero if it failed, or non-zero if it succeeded.
