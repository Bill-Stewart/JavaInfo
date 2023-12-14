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
{$R *.res}
{$APPTYPE CONSOLE}

program GetJavaInfo;

// wargcv/wgetopts - https://github.com/Bill-Stewart/wargcv
uses
  Windows,
  wargcv,
  wgetopts,
  wsJavaInfo,
  wsUtilFile,
  wsUtilStr;

type
  TCommandLine = object
    ErrorCode:         Word;
    ErrorMessage:      string;
    ArgHelp:           Boolean;  // --help/-h
    ArgQuiet:          Boolean;  // --quiet/-q
    ArgVersion:        Boolean;  // --version/v
    ArgJavaIs64Bit:    Boolean;  // --javais64bit/-b
    ArgJavaHome:       Boolean;  // --javahome/-H
    ArgJavaDLL:        Boolean;  // --javadll/-d
    ArgJavaInstalled:  Boolean;  // --javainstalled/-i
    ArgJavaMinVersion: string;   // --javaminversion/-m
    ArgJavaVersion:    Boolean;  // --javaversion/-V
    procedure Parse();
  end;

var
  CommandLine: TCommandLine;
  JavaDetected, JavaIs64Bit, VersionOK: Boolean;
  JavaHome, JavaJVMPath, JavaVersion, OutputStr: string;

procedure Usage();
var
  UsageText: string;
begin
  UsageText := 'GetJavaInfo - Copyright 2020-2023 by Bill Stewart (bstewart at iname.com)' + sLineBreak
    + 'This is free software and comes with ABSOLUTELY NO WARRANTY.' + sLineBreak
    + sLineBreak
    + 'Usage: GetJavaInfo [--javainstalled | --javahome | --javaversion |' + sLineBreak
    + '       --javais64bit] [--quiet]' + sLineBreak
    + 'or:    GetJavaInfo --javaminversion <version> [--quiet]' + sLineBreak
    + sLineBreak
    + 'Without parameters, outputs Java installation details.' + sLineBreak
    + sLineBreak
    + 'Parameter         Abbrev.  Description' + sLineBreak
    + '----------------  -------  -------------------------------------' + sLineBreak
    + '--javainstalled   -i       Tests if Java is installed' + sLineBreak
    + '--javahome        -H       Outputs Java home directory' + sLineBreak
    + '--javadll         -d       Outputs jvm.dll path' + sLineBreak
    + '--javaversion     -V       Outputs Java version' + sLineBreak
    + '--javais64bit     -b       Tests if Java is 64-bit' + sLineBreak
    + '--version         -v       Outputs this program''s version number' + sLineBreak
    + '--javaminversion  -m       Tests for a minimum version of Java' + sLineBreak
    + '--quiet           -q       Suppresses output from other options' + sLineBreak
    + '--help            -h       Outputs this help information' + sLineBreak
    + sLineBreak
    + 'Parameters can be spelled out (e.g., --javahome) or specified in abbreviated' + sLineBreak
    + 'form (e.g., -H). Parameters are case-sensitive.' + sLineBreak
    + sLineBreak
    + 'General exit codes:' + sLineBreak
    + '* 0 = no error/Java is installed' + sLineBreak
    + '* 2 = Java is not installed' + sLineBreak
    + '* 87 = invalid parameter on command line' + sLineBreak
    + sLineBreak
    + 'Exit codes with --javais64bit (-b) parameter:' + sLineBreak
    + '* 0 = Java is not 64-bit' + sLineBreak
    + '* 1 = Java is 64-bit' + sLineBreak
    + sLineBreak
    + 'Exit codes with --javaminversion (-m) parameter:' + sLineBreak
    + '* 0 = Java version is < specified version' + sLineBreak
    + '* 1 = Java version is >= specified version' + sLineBreak
    + sLineBreak
    + 'Version number for --javaminversion (-m) parameter uses the following format:' + sLineBreak
    + 'n[.n[.n[.n]]]' + sLineBreak
    + '(i.e., up to 4 numbers separated by dots)';
  WriteLn(UsageText);
end;

procedure TCommandLine.Parse();
var
  LongOpts: array[1..10] of TOption;
  Opt: Char;
  I: Integer;
begin
  // Set up array of options; requires final option with empty name;
  // set Value member to specify short option match for GetLongOps
  with LongOpts[1] do
  begin
    Name := 'javais64bit';
    Has_arg := No_Argument;
    Flag := nil;
    Value := 'b';
  end;
  with LongOpts[2] do
  begin
    Name := 'javadll';
    Has_arg := No_Argument;
    flag := nil;
    Value := 'd';
  end;
  with LongOpts[3] do
  begin
    Name := 'javahome';
    Has_arg := No_Argument;
    Flag := nil;
    Value := 'H';
  end;
  with LongOpts[4] do
  begin
    Name := 'help';
    Has_arg := No_Argument;
    Flag := nil;
    Value := 'h';
  end;
  with LongOpts[5] do
  begin
    Name := 'javainstalled';
    Has_arg := No_Argument;
    Flag := nil;
    Value := 'i';
  end;
  with LongOpts[6] do
  begin
    Name := 'javaminversion';
    Has_arg := Required_Argument;
    Flag := nil;
    Value := 'm';
  end;
  with LongOpts[7] do
  begin
    Name := 'quiet';
    Has_arg := No_Argument;
    Flag := nil;
    Value := 'q';
  end;
  with LongOpts[8] do
  begin
    Name := 'javaversion';
    Has_arg := No_Argument;
    Flag := nil;
    Value := 'V';
  end;
  with LongOpts[9] do
  begin
    Name := 'version';
    Has_arg := No_Argument;
    Flag := nil;
    Value := 'v';
  end;
  with LongOpts[10] do
  begin
    Name := '';
    Has_arg := No_Argument;
    Flag := nil;
    Value := #0;
  end;
  // Initialize defaults
  ErrorCode := 0;
  ErrorMessage := '';
  ArgHelp := false;           // --help/-h
  ArgQuiet := false;          // --quiet/-q
  ArgVersion := false;        // --version/v
  ArgJavaIs64Bit := false;    // --javais64bit/-b
  ArgJavaHome := false;       // --javahome/-H
  ArgJavaDLL := false;        // --javadll/-d
  ArgJavaInstalled := false;  // --javainstalled/-i
  ArgJavaMinVersion := '';    // --javaminversion/-m
  ArgJavaVersion := false;    // --javaversion/-V
  OptErr := false;  // no error outputs from wgetopts
  repeat
    Opt := GetLongOpts('bdHhim:qVv', @LongOpts, I);
    case Opt of
      'b': ArgJavaIs64Bit := true;
      'd': ArgJavaDLL := true;
      'H': ArgJavaHome := true;
      'h': ArgHelp := true;
      'i': ArgJavaInstalled := true;
      'm': ArgJavaMinVersion := OptArg;
      'q': ArgQuiet := true;
      'V': ArgJavaVersion := true;
      'v': ArgVersion := true;
      '?':
      begin
        ErrorCode := ERROR_INVALID_PARAMETER;
        ErrorMessage := 'Invalid parameter(s). Use --help (-h) for usage information.';
      end;
    end; //case Opt
  until Opt = EndOfOptions;
end;

function BoolToStr(const B: Boolean): string;
begin
  if B then
    result := 'Yes'
  else
    result := 'No';
end;

begin
  // Special case - show help if first parameter is '/?'
  if ParamStr(1) = '/?' then
  begin
    Usage();
    exit();
  end;

  // Parse the command line using getopts library
  CommandLine.Parse();

  // --help/-h
  if CommandLine.ArgHelp then
  begin
    Usage();
    exit();
  end;

  // --version/-v
  if CommandLine.ArgVersion then
  begin
    WriteLn(GetFileVersion(ParamStr(0)));
    exit();
  end;

  // Exit code is non-zero if error on command line
  ExitCode := CommandLine.ErrorCode;
  if ExitCode <> 0 then
  begin
    WriteLn(CommandLine.ErrorMessage);
    exit();
  end;

  // Initialize variables
  JavaDetected := wsIsJavaInstalled();
  JavaHome := '';
  JavaJVMPath := '';
  JavaVersion := '';
  JavaIs64Bit := false;

  // Get details if Java was detected
  if JavaDetected then
  begin
    JavaHome := wsGetJavaHome();
    JavaJVMPath := wsGetJavaJVMPath();
    JavaVersion := wsGetJavaVersion();
    if wsIsBinary64Bit(JavaHome + '\bin\java.exe', JavaIs64Bit) <> 0 then
      JavaIs64Bit := false;
  end;

  // --javainstalled/-i
  if CommandLine.ArgJavaInstalled then
  begin
    if not JavaDetected then
      ExitCode := ERROR_FILE_NOT_FOUND;
    if not CommandLine.ArgQuiet then
      if JavaDetected then
        WriteLn('Java detected.')
      else
        WriteLn('Java not detected.');
    exit();
  end;

  // Exit if Java not detected
  if not JavaDetected then
  begin
    ExitCode := ERROR_FILE_NOT_FOUND;
    if not CommandLine.ArgQuiet then
      WriteLn('Java not detected.');
    exit();
  end;

  // --javais64bit/-b
  if CommandLine.ArgJavaIs64Bit then
  begin
    if JavaIs64Bit then
      ExitCode := 1
    else
      ExitCode := 0;
    if not CommandLine.ArgQuiet then
      if JavaIs64Bit then
        WriteLn('Java is 64-bit.')
      else
        WriteLn('Java is not 64-bit.');
    exit();
  end;

  // --javaminversion/-m
  if CommandLine.ArgJavaMinVersion <> '' then
  begin
    if wsIsJavaMinimumVersion(CommandLine.ArgJavaMinVersion, VersionOK) then
    begin
      if VersionOK then
        ExitCode := 1
      else
        ExitCode := 0;
      if not CommandLine.ArgQuiet then
        if VersionOK then
          WriteLn('Java version is greater than or equal to the specified version.')
        else
          WriteLn('Java version is less than the specified version.');
      exit();
    end
    else
    begin
      ExitCode := ERROR_INVALID_PARAMETER;
      if not CommandLine.ArgQuiet then
        WriteLn('--javaminversion (-m) parameter requires a valid version number as an argument.');
      exit();
    end;
  end;

  if not (CommandLine.ArgJavaHome or CommandLine.ArgJavaDLL or CommandLine.ArgJavaVersion) then
  begin
    OutputStr := 'Java home:' + #9 + JavaHome + sLineBreak
      + 'jvm.dll path:' + #9 + JavaJVMPath + sLineBreak
      + 'Java version:' + #9 + JavaVersion + sLineBreak
      + 'Java is 64-bit:' + #9 + BoolToStr(JavaIs64Bit);
    WriteLn(OutputStr);
    exit();
  end;

  // --javahome/-H or --javadll/-d or --javaversion/-V
  if CommandLine.ArgJavaHome then
    WriteLn(JavaHome)
  else if CommandLine.ArgJavaDLL then
    WriteLn(JavaJVMPath)
  else if CommandLine.ArgJavaVersion then
    WriteLn(JavaVersion);
end.
