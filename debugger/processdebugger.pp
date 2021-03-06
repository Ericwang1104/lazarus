{ $Id$ }
{      ------------------------------------------------  
       ProcessDebugger.pp  -  Debugger class which only
                              executes a target 
       ------------------------------------------------ 
 
 @created(Sun Nov 27st WET 2005)
 @lastmod($Date$)
 @author(Marc Weustink <marc@@dommelstein.net>)                       

 This unit contains the process debugger class. It simply creates a process.
 
 
 ***************************************************************************
 *                                                                         *
 *   This source is free software; you can redistribute it and/or modify   *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This code is distributed in the hope that it will be useful, but      *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   General Public License for more details.                              *
 *                                                                         *
 *   A copy of the GNU General Public License is available on the World    *
 *   Wide Web at <http://www.gnu.org/copyleft/gpl.html>. You can also      *
 *   obtain it by writing to the Free Software Foundation,                 *
 *   Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.        *
 *                                                                         *
 ***************************************************************************
}
unit ProcessDebugger;

{$mode objfpc}
{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Process, Debugger, LCLProc,
  BaseDebugManager, Dialogs, ProcessList;

type

  { TProcessDebugger }

  TProcessDebugger = class(TDebugger)
  private
    FProcess: TProcess;
    procedure ProcessDestroyed(Sender: TObject);
    function  ProcessEnvironment(const AVariable: String; const ASet: Boolean): Boolean;
    function  ProcessRun: Boolean;
    function  ProcessStop: Boolean;
  protected
    function  GetSupportedCommands: TDBGCommands; override;
    function  RequestCommand(const ACommand: TDBGCommand; const AParams: array of const): Boolean; override;
  public
    class function Caption: String; override;
    class function HasExePath: boolean; override;

  published
  end;

implementation

type

  { TDBGProcess }

  TDBGProcess = class(TProcess)
  private
    FOnDestroy: TNotifyEvent;
  protected
  public
    destructor Destroy; override;
    property OnDestroy: TNotifyEvent read FOnDestroy write FOnDestroy;
  end;

{ TDBGProcess }

destructor TDBGProcess.Destroy;
begin
  if Assigned(FOnDestroy) then FOnDestroy(Self);
  inherited Destroy;
end;


{ TProcessDebugger }

procedure TProcessDebugger.ProcessDestroyed(Sender: TObject);
begin
  FProcess := nil;
  SetState(dsStop);
end;

function TProcessDebugger.ProcessEnvironment(const AVariable: String; const ASet: Boolean): Boolean;
begin
  // We don't have to do anything, we'll use the Environment when running
  Result := True;
end;

function TProcessDebugger.ProcessRun: Boolean;
begin
  DebugLn('PR: %s %s', [FileName, Arguments]);

  if FProcess <> nil
  then begin
    MessageDlg('Debugger', Format('There is already a process running: %s', [FProcess.CommandLine]), mtError, [mbOK], 0);
    Result := False;
    Exit;
  end;

  FProcess := TDBGProcess.Create(nil);
  try
    FProcess.CommandLine := UTF8ToSys('"'+FileName + '" ' + Arguments);
    FProcess.CurrentDirectory := UTF8ToSys(WorkingDir);
    FProcess.Environment.Assign(Environment);
    if ShowConsole
    then FProcess.Options:= [poNewConsole]
    else FProcess.Options:= [poNoConsole];
    FProcess.ShowWindow := swoShowNormal;
    TDBGProcess(FProcess).OnDestroy := @ProcessDestroyed;
    FProcess.Execute;
    GetDefaultProcessList.Add(FProcess);
  except
    on E: exception do begin
      MessageDlg('Debugger', Format('Exception while creating process: %s', [E.Message]), mtError, [mbOK], 0);
      Result := False;
      Exit;
    end;
  end;

  SetState(dsRun);
  Result := True;
end;

function TProcessDebugger.ProcessStop: Boolean;
begin
  FProcess.Terminate(0);
  // Do not free the process, the processlist will free it
  // FreeAndNil(FProcess);

  // SetState(dsStop);
  Result := True;
end;

function TProcessDebugger.GetSupportedCommands: TDBGCommands;
begin
  Result := [dcRun, dcStop, dcEnvironment]
end;

function TProcessDebugger.RequestCommand(const ACommand: TDBGCommand; const AParams: array of const): Boolean;
begin
  case ACommand of
    dcRun:         Result := ProcessRun;
    dcStop:        Result := ProcessStop;
    dcEnvironment: Result := ProcessEnvironment(String(APArams[0].VAnsiString), AParams[1].VBoolean);
  end;
end;

class function TProcessDebugger.Caption: String;
begin
  Result := '(none)';
end;

class function TProcessDebugger.HasExePath: boolean;
begin
  Result:= false; // no need to have a valid exe path for the process debugger
end;

initialization
  RegisterDebugger(TProcessDebugger);

end.
