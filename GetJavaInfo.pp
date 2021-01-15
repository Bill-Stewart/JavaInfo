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
{$H+}
{$R *.res}
{$APPTYPE CONSOLE}

program
  GetJavaInfo;

uses
  getopts,
  windows,
  wsUtilFile,
  wsJavaInfo;

const
  NEWLINE: unicodestring = #13 + #10;

type
  TCommandLine = object
    ErrorCode: word;
    ErrorMessage: unicodestring;
    ArgHelp: boolean;                  // --help/-h
    ArgQuiet: boolean;                 // --quiet/-q
    ArgVersion: boolean;               // --version/v
    ArgJavaIs64Bit: boolean;           // --javais64bit/-b
    ArgJavaHome: boolean;              // --javahome/-H
    ArgJavaInstalled: boolean;         // --javainstalled/-i
    ArgJavaMinVersion: unicodestring;  // --javaminversion/-m
    ArgJavaVersion: boolean;           // --javaversion/-V
    procedure Parse();
    end;
var
  CommandLine: TCommandLine;
  JavaDetected, JavaIs64Bit, VersionOK: boolean;
  JavaHome, JavaVersion, OutputStr: unicodestring;

procedure Usage();
  const
    NEWLINE: unicodestring = #13 + #10;
  var
    UsageText: unicodestring;
  begin
  UsageText := 'GetJavaInfo - Copyright (C) 2021 by Bill Stewart (bstewart at iname.com)' + NEWLINE
    + NEWLINE
    + 'This is free software and comes with ABSOLUTELY NO WARRANTY.' + NEWLINE
    + NEWLINE
    + 'Usage: GetJavaInfo [options]' + NEWLINE
    + NEWLINE
    + 'Options:' + NEWLINE
    + NEWLINE
    + '--javainstalled or -i - Returns exit code of 0 if Java is installed, or 2 if' + NEWLINE
    + 'not.' + NEWLINE
    + NEWLINE
    + '--javahome or -H - Outputs the Java home directory.' + NEWLINE
    + NEWLINE
    + '--javaversion or -V - Outputs the Java version.' + NEWLINE
    + NEWLINE
    + '--javais64bit or -b - Returns exit code of 1 if Java is 64-bit, or 0 if not.' + NEWLINE
    + NEWLINE
    + '--javaminversion or -m - Specify a version number after this parameter. Returns' + NEWLINE
    + 'an exit code of 0 if the Java version is less than the specified version, 1 if' + NEWLINE
    + 'the Java version is greater than or equal to the specified version, or 87 if' + NEWLINE
    + 'the version number is missing or not valid.' + NEWLINE
    + NEWLINE
    + '--version or -v - Outputs the version of GetJavaInfo.' + NEWLINE
    + NEWLINE
    + '--quiet or -q - Suppresses output messages from other options.' + NEWLINE
    + NEWLINE
    + '--help or -h - Outputs this help information.' + NEWLINE
    + NEWLINE
    + 'Without arguments, outputs Java details if Java is installed. If Java was' + NEWLINE
    + 'not detected, returns an exit code of 2.';
  WriteLn(UsageText);
  end;

procedure TCommandLine.Parse();
  var
    LongOpts: array[1..9] of TOption;
    Opt: char;
    I: longint;
  begin
  // Set up array of options; requires final option with empty name;
  // set Value member to specify short option match for GetLongOps
  with LongOpts[1] do
    begin
    Name    := 'javais64bit';
    Has_arg := No_Argument;
    Flag    := nil;
    Value   := 'b';
    end;
  with LongOpts[2] do
    begin
    Name    := 'help';
    Has_arg := No_Argument;
    Flag    := nil;
    Value   := 'h';
    end;
  with LongOpts[3] do
    begin
    Name    := 'javahome';
    Has_arg := No_Argument;
    Flag    := nil;
    Value   := 'H';
    end;
  with LongOpts[4] do
    begin
    Name    := 'javainstalled';
    Has_arg := No_Argument;
    Flag    := nil;
    Value   := 'i';
    end;
  with LongOpts[5] do
    begin
    Name    := 'javaminversion';
    Has_arg := Required_Argument;
    Flag    := nil;
    Value   := 'm';
    end;
  with LongOpts[6] do
    begin
    Name    := 'quiet';
    Has_arg := No_Argument;
    Flag    := nil;
    Value   := 'q';
    end;
  with LongOpts[7] do
    begin
    Name     := 'javaversion';
    Has_arg  := No_Argument;
    Flag     := nil;
    Value    := 'V';
    end;
  with LongOpts[8] do
    begin
    Name     := 'version';
    Has_arg  := No_Argument;
    Flag     := nil;
    Value    := 'v';
    end;
  with LongOpts[9] do
    begin
    Name    := '';
    Has_arg := No_Argument;
    Flag    := nil;
    Value   := #0;
    end;
  // Initialize defaults
  ErrorCode := 0;
  ErrorMessage := '';
  ArgHelp := false;           // --help/-h
  ArgQuiet := false;          // --quiet/-q
  ArgVersion := false;        // --version/v
  ArgJavaIs64Bit := false;    // --javais64bit/-b
  ArgJavaHome := false;       // --javahome/-H
  ArgJavaInstalled := false;  // --javainstalled/-i
  ArgJavaMinVersion := '';    // --javaminversion/-m
  ArgJavaVersion := false;    // --javaversion/-V
  OptErr := false;  // no error outputs from getopts
  repeat
    Opt := GetLongOpts('bhHim:qVv', @LongOpts, I);
    case Opt of
      'b': ArgJavaIs64Bit := true;
      'h': ArgHelp := true;
      'H': ArgJavaHome := true;
      'i': ArgJavaInstalled := true;
      'm': ArgJavaMinVersion := unicodestring(OptArg);
      'q': ArgQuiet := true;
      'V': ArgJavaVersion := true;
      'v': ArgVersion := true;
      '?':
        begin
        ErrorCode := ERROR_INVALID_PARAMETER;
        ErrorMessage := 'Incorrect parameter(s). Use --help (-h) for usage information.';
        end;
      end; //case Opt
  until Opt = EndOfOptions;
  end;

function BoolToStr(const B: boolean): unicodestring;
  begin
  if B then result := 'Yes' else result := 'No';
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
    WriteLn(GetFileVersion(GetExecutablePath()));
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
  JavaVersion := '';
  JavaIs64Bit := false;

  // Get details if Java was detected
  if JavaDetected then
    begin
    JavaHome := wsGetJavaHome();
    JavaVersion := wsGetJavaVersion();
    if wsIsBinary64Bit(JavaHome + '\bin\java.exe', JavaIs64Bit) <> 0 then
      JavaIs64Bit := false;
    end;

  // --javainstalled/-i
  if CommandLine.ArgJavaInstalled then
    begin
    if not JavaDetected then ExitCode := ERROR_FILE_NOT_FOUND;
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
    if JavaIs64Bit then ExitCode := 1 else ExitCode := 0;
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
      if VersionOK then ExitCode := 1 else ExitCode := 0;
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

  if not (CommandLine.ArgJavaHome or CommandLine.ArgJavaVersion) then
    begin
    OutputStr := 'Java home:' + #9 + JavaHome + NEWLINE
               + 'Java version:' + #9 + JavaVersion + NEWLINE
               + 'Java is 64-bit:' + #9 + BoolToStr(JavaIs64Bit);
    WriteLn(OutputStr);
    exit();
    end;

  // --javahome/-H or --javaversion/-V
  if CommandLine.ArgJavaHome then
    WriteLn(JavaHome)
  else if CommandLine.ArgJavaVersion then
    WriteLn(JavaVersion);
end.
