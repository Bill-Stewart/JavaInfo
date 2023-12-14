# GetJavaInfo

GetJavaInfo is a console mode (command line) Windows utility that provides information about Java installations.

## Author

Bill Stewart - bstewart at iname dot com

## License

GetJavaInfo is covered by the GNU Lesser License (LPGL). See the file `LICENSE` for details.

## Download

https://github.com/Bill-Stewart/JavaInfo/releases/

## Description

GetJavaInfo is a command line utility that uses the same code as JavaInfo.dll to detect Java installation details. GetJavaInfo does not require JavaInfo.dll.

## Usage

`GetJavaInfo` [`--javainstalled` | `--javahome` | `--javaversion` | `--javais64bit`] [`--quiet`]

or:

`GetJavaInfo` `--javaminversion` _version_ [`--quiet`]

Without command-line parameters, GetJavaInfo outputs Java installation details. The following table describes the command line parameters:

| Parameter          | Abbreviation | Description
| ------------------ | ------------ | -------------------------------------
| `--javainstalled`  | `-i`         | Tests if Java is installed
| `--javahome`       | `-H`         | Outputs Java home directory
| `--javadll`        | `-d`         | Outputs jvm.dll path
| `--javaversion`    | `-V`         | Outputs Java version
| `--javais64bit`    | `-b`         | Tests if Java is 64-bit
| `--version`        | `-v`         | Outputs this program's version number
| `--javaminversion` | `-m`         | Tests for a minimum version of Java
| `--quiet`          | `-q`         | Suppresses output from other options
| `--help`           | `-h`         | Outputs help information

Parameters can be spelled out (e.g., `--javahome`) or used in abbreviated form (e.g., `-H`). Parameters are case-sensitive.

General exit codes:

* 0 = no errors/Java is installed
* 2 = Java is not installed
* 87 = invalid parameter on command line

Exit codes with `--javais64bit` (`-b`) parameter:

* 0 = Java is not 64-bit
* 1 = Java is 64-bit

Exit codes with `--javaminversion` (`-m`) parameter:

* 0 = Java version is < specified version
* 1 = Java version is >= specified version

When specifying the `--javaminversion` (`-m`) parameter, specify a version number after the parameter in on the command line in the following format:

_n_[._n_[._n_[._n_]]]

That is, up to 4 numbers (in the range 0 through 65535, inclusive) separated by dots (`.`). Values not specified are assumed to be zero. Examples:

| Version | Value
| ------- | --------
| 11      | 11.0.0.0
| 8.1     | 8.1.0.0
| 7.5.1   | 7.5.1.0

If the version number does not follow the above format, GetJavaInfo will exit with error code 87 (87 is the Windows error code `ERROR_INVALID_PARAMETER`).

For example:

    GetJavaInfo --javaminversion 11.0.9.1

In this example, GetJavaInfo will return one of the following exit codes:

* 0 - Java is installed, and is at least version 11.0.9.1
* 1 - Java is installed, but is less than version 11.0.9.1
* 2 - Java is not installed

## Examples

1.  `GetJavaInfo --javainstalled --quiet`

    Returns an exit code 0 if Java is installed or an exit code of 2 if Java is not installed. The program produces no output.

2.  Sample batch file (cmd.exe shell script) for getting the Java home directory:

        @echo off
        setlocal enableextensions
        set _JHOME=
        for /f "delims=" %%a in ('GetJavaInfo --javahome') do set _JHOME=%%a
        if "%_JHOME%"=="" goto :NOJAVA
        echo Java home: %_JHOME%
        goto :END
        :NOJAVA
        echo Java is not installed
        :END
        endlocal

    This script sets the `_JHOME` environment variable within the script to the Java home directory if Java is installed. The variable will not be set if Java is not instaled.

3.  Sample batch file (cmd.exe shell script) for checking whether Java is installed and is at least a minimum version:

        @echo off
        setlocal enableextensions
        set _JMINVER=11
        GetJavaInfo --javaminversion %_JMINVER% --quiet
        if errorlevel 2 goto :NOJAVA
        if errorlevel 1 goto :VER_OK
        echo Java is installed, but it is less than version %_JMINVER%
        goto :END
        :VER_OK
        echo At least Java %_JMINVER% is installed
        goto :END
        :NOJAVA
        echo Java is not installed
        :END
        endlocal

4.  Sample batch file (cmd.exe shell script) for getting the path and filename of jvm.dll in an environment variable:

        @echo off
        setlocal enableextensions
        GetJavaInfo -i -q
        if errorlevel 2 goto :NOJAVA
        set _JVMPATH=
        for /f "delims=" %%a in ('GetJavaInfo --javadll') do set _JVMPATH=%%a
        echo jvm.dll path: %_JVMPATH%
        goto :END
        :NOJAVA
        echo Java is not installed
        :END
        endlocal
