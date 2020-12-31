# JavaInfo.dll

JavaInfo.dll is a Windows DLL (dynamically linked library) that provides information about whether Java is installed and its properties.

# Author

Bill Stewart - bstewart at iname dot com

# Background

A Java Development Kit (JDK) or Java Runtime Environment (JRE) is required to run Java applications, but there's not a standard way to detect whether Java is installed and details about it. JavaInfo.dll provides this information. For example, you can use JavaInfo.dll in an installer or a Java application launcher executable to detect if Java is installed.

JavaInfo.dll searches for Java in the following three ways:

1. It searches the JavaSoft registry subkeys (`HKEY_LOCAL_MACHINE\SOFTWARE\JavaSoft`). If the registry data is found, it returns the `JavaHome` value for the latest version. On 64-bit platforms, JavaInfo.dll does not search for 32-bit versions of Java if any 64-bit versions are installed (it will only search for 32-bit Java versions if no 64-bit versions are installed).

2. If the previous search fails, it uses the `JAVA_HOME`, `JDK_HOME`, or `JRE_HOME` environment variable (in that order) as the Java home directory.

3. If the previous searches fail, it searches directories in the `Path` environment variable for `java.exe`. The Java home directory is the parent directory where `java.exe` is found. For example, if `C:\Program Files\AdoptOpenJDK\JRE11\bin` is in the path (and `java.exe` is found in that directory), the Java home directory is `C:\Program Files\AdoptOpenJDK\JRE11`.

If one of the above searches succeeds, JavaInfo.dll looks for _home_`\bin\java.exe` (where _home_ is the Java home directory). If the file is found, it retrieves the version information from the `java.exe` file.

If JavaInfo.dll is successful at finding the `java.exe` and retrieving its version information, then it considers Java to be installed.

If JavaInfo.dll is successful at locating a Java installation, you can use the following paths to find Java binaries (where _home_ is the Java home directory):

* _home_`\bin\java.exe` - Console-based Java executable
* _home_`\bin\javaw.exe` - GUI-based Java executable
* _home_`\bin\server\jvm.dll` - Java virtual machine DLL (used by web servlet containers such as Apache Tomcat)

The 32-bit (x86) DLL works on both 32-bit and 64-bit versions of Windows. Use the x64 DLL with x64 executables on x64 versions of Windows.

# Version History

## 0.0.0.1 (2020-12-29)

Initial version.

## 0.0.0.2 (2020-12-30)

Misread Windows documentation on `SearchPathW` API function and allocated potentially insufficient buffer size. Fixed.

## 0.0.0.3 (2020-12-31)

* Changed `IsJava64Bit()` function to `IsBinary64Bit()` function. The reason for this change is that it is useful to determine whether a binary (i.e., a `.exe` or `.dll` file) is 64-bit even when Java is not detected. For example, if the `IsJavaInstalled()` function returns 0 but an instance of Java is present, you can use the `IsBinary64Bit()` function to determine whether the Java instance is 64-bit if you know its path. An added benefit is that the `IsBinary64Bit()` function works on any Windows binary, not just Java binaries.
* Included Inno Setup (https://www.jrsoftware.org/isinfo.php) sample script (`JavaInfo.iss`).

# Functions

This section documents the functions exported by JavaInfo.dll.

---

## IsBinary64Bit()

The `IsBinary64Bit()` function detects whether a Windows binary file is 32-bit or 64-bit.

### Syntax

C/C++:
```
DWORD IsBinary64Bit(LPWSTR FileName, PDWORD Is64Bit);
```

Pascal:
```
function IsBinary64Bit(FileName: pwidechar; Is64Bit: PDWORD): DWORD;
```

### Parameters

`FileName`

A unicode string containing the name of a binary file (exe or dll).

`Is64Bit`

A pointer to a variable that gets set to 1 if the specified binary file is 64-bit, or 0 otherwise. The value of this variable is not defined if the `IsBinary64Bit()` function fails.

### Return Value

The `IsBinary64Bit()` function returns 0 for success, or non-zero for failure.

---

## IsJavaInstalled()

The `IsJavaInstalled()` function detects whether Java is installed.

### Syntax

C/C++:
```
DWORD IsJavaInstalled();
```

Pascal:
```
function IsJavaInstalled(): DWORD;
```

### Return Value

The `IsJavaInstalled()` function returns zero if no Java installations were detected, or non-zero otherwise.

---

## GetJavaHome

The `GetJavaHome()` function gets the Java home directory.

### Syntax

C/C++:
```
DWORD GetJavaHome(LPWSTR PathName, DWORD NumChars);
````

Pascal:
```
function GetJavaHome(PathName: pwidechar; NumChars: DWORD): DWORD;
```

### Parameters

`PathName`

A pointer to a variable that receives a unicode string that contains the Java home directory.

`NumChars`

Specifies the number of characters needed to store the home directory string, not including the terminating null character. To get the required number of characters needed, call the function twice. In the first call to the function, specify a null pointer for the `PathName` parameter and `0` for the `NumChars` parameter. The function will return with the number of characters required for the buffer. Allocate the buffer, then call the function a second time to retrieve the string.

### Return Value

The `GetJavaHome()` function returns zero if it failed, or non-zero if it succeeded.

---

## GetJavaVersion()

The `GetJavaVersion()` function gets the version of Java as a string in the following format: `a.b.c.d`.

### Syntax

C/C++:
```
DWORD GetJavaVersion(LPWSTR Version, DWORD NumChars);
````

Pascal:
```
function GetJavaVersion(Version: pwidechar; NumChars: DWORD): DWORD;
```

### Parameters

`Version`

A pointer to a variable that receives a unicode string that contains the Java version string.

`NumChars`

Specifies the number of characters needed to store the version number string, not including the terminating null character. To get the required number of characters needed, call the function twice. In the first call to the function, specify a null pointer for the `Version` parameter and `0` for the `NumChars` parameter. The function will return with the number of characters required for the buffer. Allocate the buffer, then call the function a second time to retrieve the string.

### Return Value

The `GetJavaVersion()` function returns zero if it failed, or non-zero if it succeeded.