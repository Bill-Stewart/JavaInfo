# JavaInfo.dll

JavaInfo.dll is a Windows DLL that provides information about whether Java is installed and its properties (home directory, version, and whether it is 64-bit).

# Author

Bill Stewart - bstewart at iname dot com

# Background

A Java Development Kit (JDK) or Java Runtime Environment (JRE) is required to run Java applications, but there's not a standard way to detect whether Java is installed and details about it. JavaInfo.dll provides this information. For example, you could use JavaInfo.dll in an installer or a Java application launcher executable to detect if Java is installed, and direct users to a Java download if it is not installed.

JavaInfo.dll searches for Java in the following three ways:

1. It searches the JavaSoft registry subkeys (`HKEY_LOCAL_MACHINE\SOFTWARE\JavaSoft`). If the registry data is found, it returns the `JavaHome` value for latest version.

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

# Functions

This section documents the functions exported by JavaInfo.dll.

---

## IsJavaInstalled

The `IsJavaInstalled` function detects whether Java is installed.

### Syntax

C/C++:
```
INT IsJavaInstalled();
```

Pascal:
```
function IsJavaInstalled(): longint;
```

### Return Value

The `IsJavaInstalled` function returns zero if no Java installations were detected, or non-zero otherwise.

---

## IsJava64Bit

The `IsJava64Bit` function detects whether Java is 64-bit.

### Syntax

C/C++:
```
INT IsJava64Bit();
```

Pascal:
```
function IsJava64Bit(): longint;
```

### Return Value

The `IsJava64Bit` function returns zero if Java is not 64-bit, or non-zero otherwise. The return value of this function is undefined if the `IsJavaInstalled` function returns zero.

---

## GetJavaHome

The `GetJavaHome` function gets the Java home directory.

### Syntax

C/C++:
```
DWORD GetJavaHome(LPWSTR Buffer, DWORD NumChars);
````

Pascal:
```
function GetJavaHome(Buffer: pwidechar; NumChars: DWORD): DWORD;
```

### Parameters

`Buffer`

A pointer to a variable that receives a unicode string that contains the Java home directory. You must allocate this buffer.

`NumChars`

Specifies the number of characters needed to store the home directory string, not including the terminating null character. To get the required number of characters needed, call the function twice. In the first call to the function, specify a null pointer for the `Buffer` parameter and `0` for the `NumChars` parameter. The function will return with the number of characters required for the buffer. Allocate the buffer, then call the function a second time to retrieve the string.

### Return Value

The `GetJavaHome` function returns zero if it failed, or non-zero if if succeeded.

---

## GetJavaVersion

The `GetJavaVersion` function gets the version of Java as a string in the following format: `a.b.c.d`.

### Syntax

C/C++:
```
DWORD GetJavaVersion(LPWSTR Buffer, DWORD NumChars);
````

Pascal:
```
function GetJavaVersion(Buffer: pwidechar; NumChars: DWORD): DWORD;
```

### Parameters

`Buffer`

A pointer to a variable that receives a unicode string that contains the Java version string. You must allocate this buffer.

`NumChars`

Specifies the number of characters needed to store the version number string, not including the terminating null character. To get the required number of characters needed, call the function twice. In the first call to the function, specify a null pointer for the `Buffer` parameter and `0` for the `NumChars` parameter. The function will return with the number of characters required for the buffer. Allocate the buffer, then call the function a second time to retrieve the string.

### Return Value

The `GetJavaVersion` function returns zero if it failed, or non-zero if if succeeded.