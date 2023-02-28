# JavaInfo.dll Version History

## 1.5.0.0 (2023-02-27)

* Added `GetJavaJVMPath()` function.

* Added `--javadll` (`-d`) option to GetJavaInfo utility.

* Updated all sample code to add `GetJavaJVMPath()` function.

## 1.4.0.0 (2023-01-12)

* Added Microsoft JDK registry detection.

* Minor tweaks.

## 1.3.1.0 (2021-11-16)

* Added 'Eclipse Adoptium' registry detection. (For some reason, Adoptium changed the registry location, _again_).

## 1.3.0.0 (2021-10-05)

* Added adoptium.net 'Eclipse Foundation' and 'Semeru' registry detection (adoptium.net is replacing adoptopenjdk.net).

* Minor tweaks.

## 1.2.2.0 (2021-05-25)

* Updated string-reading registry code to account for strings that might be missing a null terminator (to prevent a potential, but very low probability, buffer overflow).

* Adjusted code formatting.

* Compiled using FPC 3.2.2.

* Wrote markdown documentation for GetJavaInfo.exe.

* Minor tweaks.

## 1.2.1.0 (2021-01-19)

* Minor tweaks and minor corrections to documentation.

## 1.2.0.0 (2021-01-15)

* Added the `IsJavaMinimumVersion()` function.

* Added GetJavaInfo.exe that implements the JavaInfo.dll code as a console (command-line) utility. Run `GetJavaInfo -h` to display the help information.

* Enhanced the `JavaInfo.iss` Inno Setup sample script to use the `IsJavaMinimumVersion()` function.

* Added sample PowerShell script to illustrate using .NET P/Invoke to call the JavaInfo.dll functions.

## 1.1.0.0 (2021-01-07)

* Fixed: Registry search now returns the latest version across all registry searches instead of stopping after one subkey.

* Fixed: Unhandled exception in edge case where no registry subkeys present to enumerate.

## 1.0.0.0 (2021-01-06)

* Split registry searching code into separate functions to improve readability/maintenance.

* Added AdoptOpenJDK registry key search.

* Fixed buffer allocation/hang issue that could occur when searching the `Path` environment variable (regression bug from v0.0.0.2).

## 0.0.0.5 (2021-01-05)

* Updated search order to search `Path` before registry.

* Cleaned up registry search (removed redundant code and improved robustness and readability).

* Updated/clarified documentation and fixed a couple of typos.

## 0.0.0.4 (2021-01-04)

* Updated license to less restrictive LGPL.

* Changed search order to use environment variables first.

* Added registry searches for IBM and Azul JDKs.

## 0.0.0.3 (2020-12-31)

* Changed `IsJava64Bit()` function to `IsBinary64Bit()` function. The reason for this change is that it is useful to determine whether a binary (i.e., a `.exe` or `.dll` file) is 64-bit even when Java is not detected. For example, if the `IsJavaInstalled()` function returns 0 but an instance of Java is present, you can use the `IsBinary64Bit()` function to determine whether the Java instance is 64-bit if you know its path. An added benefit is that the `IsBinary64Bit()` function works on any Windows binary, not just Java binaries.

* Included Inno Setup (https://www.jrsoftware.org/isinfo.php) sample script (`JavaInfo.iss`).

## 0.0.0.2 (2020-12-30)

Misread Windows documentation on `SearchPathW` API function and allocated potentially insufficient buffer size. Fixed.

## 0.0.0.1 (2020-12-29)

Initial version.
