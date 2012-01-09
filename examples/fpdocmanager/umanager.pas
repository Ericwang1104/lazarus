unit uManager;
(* Manager object for FPDoc GUI, by DoDi
Holds configuration and packages.

Packages (shall) contain extended descriptions for:
- default OSTarget (FPCDocs: Unix/Linux)
- inputs: by OSTarget
- directories: project(file), InputDir, DescrDir[by language?]
- FPCVersion, LazVersion: variations of inputs
- Skeleton and Output options, depending on DocType/Level and Format.
Units can be described in multiple XML docs, so that it's possible to
have specific parts depending on Laz/FPC version, OSTarget, Language, Widgetset.

This version is decoupled from the fpdoc classes, introduces the classes
  TFPDocManager for all packages
  TDocPackage for a single package
  TFPDocHelper for fpdoc projects
*)

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles,
  umakeskel, fpdocproj, dw_HTML;

type
  TFPDocHelper = class;

  { TDocPackage }

(* TDocPackage describes a package documentation project.
*)
  TDocPackage = class
  private
    FDescrDir: string;
    FDescriptions: TStrings;
    FIncludePath: string;
    FInputDir: string;
    FLazPkg: string;
    FLoaded: boolean;
    FName: string;
    FProjectDir: string;
    FProjectFile: string;
    FRequires: TStrings;
    FUnitPath: string;
    FUnits: TStrings;
    procedure SetDescrDir(AValue: string);
    procedure SetDescriptions(AValue: TStrings);
    procedure SetIncludePath(AValue: string);
    procedure SetInputDir(AValue: string);
    procedure SetLazPkg(AValue: string);
    procedure SetLoaded(AValue: boolean);
    procedure SetName(AValue: string);
    procedure SetProjectDir(AValue: string);
    procedure SetProjectFile(AValue: string);
    procedure SetRequires(AValue: TStrings);
    procedure SetUnitPath(AValue: string);
    procedure SetUnits(AValue: TStrings);
  protected
    Config: TIniFile;
    procedure ReadConfig;
  public
    constructor Create;
    destructor Destroy; override;
    function  CreateProject(APrj: TFPDocHelper; const AFile: string): boolean; //new package project
    function  ImportProject(APrj: TFPDocHelper; APkg: TFPDocPackage; const AFile: string): boolean;
    procedure UpdateConfig;
    property Name: string read FName write SetName;
    property Loaded: boolean read FLoaded write SetLoaded;
    property ProjectFile: string read FProjectFile write SetProjectFile; //xml?
  //from LazPkg
    property LazPkg: string read FLazPkg write SetLazPkg; //LPK name?
    property ProjectDir: string read FProjectDir write SetProjectDir;
    property DescrDir: string read FDescrDir write SetDescrDir;
    property Descriptions: TStrings read FDescriptions write SetDescriptions;
    property InputDir: string read FInputDir write SetInputDir;
    property Units: TStrings read FUnits write SetUnits;
    property Requires: TStrings read FRequires write SetRequires; //only string?
    property IncludePath: string read FIncludePath write SetIncludePath; //-Fi
    property UnitPath: string read FUnitPath write SetUnitPath; //-Fu
    //property DefOS: string; - variations!
  end;

  { TFPDocHelper }

//holds temporary project

  TFPDocHelper = class(TFPDocMaker)
  private
    FProjectDir: string;
    procedure CleanXML(const FileName: string);
    procedure SetProjectDir(AValue: string);
  public
    InputList, DescrList: TStringList; //still required?
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function  BeginTest(APkg: TDocPackage): boolean;
    function  BeginTest(const AFile : string): boolean;
    procedure EndTest;
    function  CmdToPrj(const AFileName: string): boolean;
    function  TestRun(APkg: TDocPackage; AUnit: string): boolean;
    function  Update(APkg: TDocPackage; const AUnit: string): boolean;
    property ProjectDir: string read FProjectDir write SetProjectDir;
  end;

  TLogHandler = Procedure (Sender : TObject; Const Msg : String) of object;

  { TFPDocManager }

(* Holds configuration and package projects.
*)
  TFPDocManager = class(TComponent)
  private
    FFPDocDir: string;
    FLazarusDir: string;
    FModified: boolean;
    FOnChange: TNotifyEvent;
    FOnLog: TLogHandler;
    FPackage: TDocPackage;
    FPackages: TStrings;
    FRootDir: string;
    UpdateCount: integer;
    procedure SetFPDocDir(AValue: string);
    procedure SetLazarusDir(AValue: string);
    procedure SetOnChange(AValue: TNotifyEvent);
    procedure SetPackage(AValue: TDocPackage);
    procedure SetRootDir(AValue: string);
  protected
    Helper: TFPDocHelper; //temporary
    procedure Changed;
    function  BeginTest(const AFile: string): boolean;
    procedure EndTest;
    function  RegisterPackage(APkg: TDocPackage): integer;
    Procedure DoLog(Const Msg : String);
  public
    Config: TIniFile; //extend class?
    constructor Create(AOwner: TComponent);
    destructor Destroy; override;
    procedure BeginUpdate;
    procedure EndUpdate;
    function  LoadConfig(const ADir: string; Force: boolean = False): boolean;
    function  SaveConfig: boolean;
    function  AddProject(const APkg, AFile: string; UpdateCfg: boolean): boolean; //from config
    function CreateProject(const AFileName: string; APkg: TDocPackage): boolean;
    function  AddPackage(AName: string): TDocPackage;
    function  ImportLpk(const AFile: string): TDocPackage;
    procedure ImportProject(APkg: TFPDocPackage; const AFile: string);
    function  ImportCmd(const AFile: string): boolean;
  //actions
    //function MakeDoc(APkg: TDocPackage; AUnit: string): boolean; configure???
    function  TestRun(APkg: TDocPackage; AUnit: string): boolean;
    function  Update(APkg: TDocPackage; const AUnit: string): boolean;
  public //published?
    property FpcDocDir: string read FFPDocDir write SetFPDocDir;
    property LazarusDir: string read FLazarusDir write SetLazarusDir;
    property RootDir: string read FRootDir write SetRootDir;
    property Packages: TStrings read FPackages;
    property Package: TDocPackage read FPackage write SetPackage;
    property Modified: boolean read FModified; //app
    property OnChange: TNotifyEvent read FOnChange write SetOnChange;
    Property OnLog : TLogHandler Read FOnLog Write FOnLog;
  end;

var
  Manager: TFPDocManager = nil; //init by application

implementation

uses
  uLpk;

const
  ConfigName = 'docmgr.ini';
  SecProjects = 'projects';

{ TDocPackage }

procedure TDocPackage.SetDescrDir(AValue: string);
begin
  if FDescrDir=AValue then Exit;
  FDescrDir:=AValue;
end;

procedure TDocPackage.SetDescriptions(AValue: TStrings);
(* Shall we allow for multiple descriptions? (general + OS specific!?)
*)

  procedure Import;
  var
    i: integer;
    s: string;
  begin
    FDescriptions.Clear; //assume full replace
    for i := 0 to AValue.Count - 1 do begin
      s := AValue[i]; //filespec
      FDescriptions.Add(ExtractUnitName(s) + '=' + s);
    end;
  end;

begin
  if FDescriptions=AValue then Exit;
  if AValue = nil then exit; //clear?
  if AValue.Count = 0 then exit;
//import formatted: <unit>=<descr file> (multiple???)
  if Pos('=', AValue[0]) > 0 then
    FDescriptions.Assign(AValue) //clears previous content
  else //if AValue.Count > 0 then
    Import;
end;

procedure TDocPackage.SetRequires(AValue: TStrings);

  procedure Import;
  var
    i, j: integer;
    s: string;
  begin
    FRequires.Clear; //assume full replace
    for i := 0 to AValue.Count - 1 do begin
      s := AValue[i]; //<name.xct>,<prefix>
      FRequires.Add(ExtractImportName(s) + '=' + s);
    end;
  end;

begin
  if FRequires=AValue then Exit;
  if AValue = nil then exit;
  if AValue.Count = 0 then exit;
  if Pos('=', AValue[0]) > 0 then
    FRequires.Assign(AValue) //clears previous content
  else
    Import;
end;

procedure TDocPackage.SetUnits(AValue: TStrings);

  procedure Import;
  var
    i: integer;
    s: string;
  begin
    FUnits.Clear; //assume full replace
    for i := 0 to AValue.Count - 1 do begin
      s := AValue[i]; //filespec
      FUnits.Add(ExtractUnitName(AValue, i) + '=' + s);
    end;
  end;

begin
  if FUnits=AValue then Exit;
  if AValue = nil then exit;
  if AValue.Count = 0 then exit;
//import formatted: <unit>=<descr file> (multiple???)
  if Pos('=', AValue[0]) > 0 then
    FUnits.Assign(AValue) //clears previous content
  else //if AValue.Count > 0 then
    Import;
end;

procedure TDocPackage.SetIncludePath(AValue: string);
begin
  if FIncludePath=AValue then Exit;
  FIncludePath:=AValue;
end;

procedure TDocPackage.SetInputDir(AValue: string);
begin
  if FInputDir=AValue then Exit;
  FInputDir:=AValue;
end;

procedure TDocPackage.SetLazPkg(AValue: string);
begin
  if FLazPkg=AValue then Exit;
  if AValue = '' then exit;
  FLazPkg:=AValue;
  FProjectDir := ExtractFilePath(AValue);
  //todo: import
end;

procedure TDocPackage.SetLoaded(AValue: boolean);
begin
  if FLoaded=AValue then Exit;
  FLoaded:=AValue;
  Manager.RegisterPackage(self); //now definitely loaded
end;

procedure TDocPackage.SetName(AValue: string);
begin
  if FName=AValue then Exit;
  FName:=AValue;
  ReadConfig;
end;

procedure TDocPackage.SetProjectDir(AValue: string);
begin
  if FProjectDir=AValue then Exit;
  FProjectDir:=AValue;
end;

procedure TDocPackage.SetProjectFile(AValue: string);
begin
  if FProjectFile=AValue then Exit;
  FProjectFile:=AValue;
//really do more?
  if FProjectFile <> '' then
    FProjectDir:=ExtractFilePath(FProjectFile);
  //import requires fpdocproject - must be created by Manager!
end;

procedure TDocPackage.SetUnitPath(AValue: string);
begin
  if FUnitPath=AValue then Exit;
  FUnitPath:=AValue;
//save to config?
end;

constructor TDocPackage.Create;
begin
  FUnits := TStringList.Create;
  FDescriptions := TStringList.Create;
  FRequires := TStringList.Create;
  //Config requires valid Name -> in SetName
end;

destructor TDocPackage.Destroy;
begin
  FreeAndNil(FUnits);
  FreeAndNil(FDescriptions);
  FreeAndNil(FRequires);
  FreeAndNil(Config);
  inherited Destroy;
end;

(* Create new(?) project.
Usage: after LoadLpk, in general for configured project (user options!)
(more options to come)
*)
function TDocPackage.CreateProject(APrj: TFPDocHelper; const AFile: string): boolean;
var
  s, imp: string;
  pkg: TFPDocPackage;
  i: integer;
begin
  Result := False;
  if ProjectDir = '' then
    exit; //dir must be known
//create pkg
  APrj.ParseFPDocOption('--package=' + Name); //selects or creates the pkg
  pkg := APrj.SelectedPackage;
//add Inputs
  //todo: common options? OS options?
  for i := 0 to Units.Count - 1 do begin
    s := Units.ValueFromIndex[i];
    //add further options?
    pkg.Inputs.Add(Units.ValueFromIndex[i]);
  end;
//add Descriptions
  if DescrDir <> '' then begin
  //first check for existing directory
    if not DirectoryExists(DescrDir) then begin
      MkDir(DescrDir); //exclude \?
    end else if Descriptions.Count = 0 then begin
      APrj.ParseFPDocOption('--descr-dir=' + DescrDir); //adds all XML files
    end;
  end;
  for i := 0 to Descriptions.Count - 1 do begin
    s := Descriptions[i];
    pkg.Descriptions.Add(s);
  end;
//add Imports
  for i := 0 to Requires.Count - 1 do begin
    s := Requires[i];
    imp := Manager.RootDir + s + '.xct,../' + s + '/';
    APrj.ParseFPDocOption('--import=' + imp);
  end;
//add options
  pkg.Output := Manager.RootDir + Name;
  pkg.ContentFile := Manager.RootDir + Name + '.xct';
//now create project file
  if AFile <> '' then begin
    if ExtractFileExt(AFile) <> '.xml' then
      FProjectFile := ExtractFilePath(AFile) + Name + '_prj.xml'
    else
      FProjectFile := AFile;
    APrj.CreateProjectFile(ProjectFile);
  end;
  Result := True; //assume okay
end;

(* Init from TFPDocPackage, into which AFile has been loaded.
*)
function TDocPackage.ImportProject(APrj: TFPDocHelper; APkg: TFPDocPackage; const AFile: string): boolean;
var
  j: integer;
  s: string;
begin
//check loaded
  Result := Loaded;
  if Result then
    exit;
//init...
  s := UnitFile(APkg.Inputs, 0);
  if s <> '' then
    FUnitPath := ExtractFilePath(s);
  s := UnitFile(APkg.Descriptions, 0);
  if s <> '' then
    FDescrDir := ExtractFilePath(s);
//project file - empty if not applicable (multi-package project?!)
  if (AFile <> '') and (APrj.Packages.Count = 1) then
    ProjectFile := AFile //only if immediately applicable!
  else
    ProjectDir := ExtractFilePath(AFile);
//init lists
  Units := APkg.Inputs;
  Descriptions := APkg.Descriptions;
  Requires := APkg.Imports;
//more?
//save config!
  UpdateConfig;
//finish
  Result := Loaded;
end;

const
  SecDoc = 'project';

procedure TDocPackage.ReadConfig;
var
  s: string;
begin
  if Loaded then
    exit;
  if Config = nil then
    Config := TIniFile.Create(Manager.RootDir + Name + '.ini');
//check config
  s := Config.ReadString(SecDoc, 'projectdir', '');
  if s = '' then
    exit; //project directory MUST be known
  ProjectFile := Config.ReadString(SecDoc, 'projectfile', '');
  FInputDir := Config.ReadString(SecDoc, 'inputdir', '');
  FDescrDir := Config.ReadString(SecDoc, 'descrdir', '');
  Requires.CommaText := Config.ReadString(SecDoc, 'requires', '');
//units
  Config.ReadSectionRaw('units', Units);
  Config.ReadSectionRaw('descrs', Descriptions);
//more?
//all done
  Loaded := True;
end;

(* Initialize the package, write global config (+local?)
*)
procedure TDocPackage.UpdateConfig;

  procedure WriteSection(const SecName: string; AList: TStrings);
  var
    j: integer;
  begin
    if AList = nil then
      exit; //how that?
    for j := 0 to AList.Count - 1 do begin
      Config.WriteString(SecName, AList.Names[j], AList.ValueFromIndex[j]);
    end;
  end;

var
  i: integer;
begin
//create ini file, if not already created
  if Config = nil then
    Config := TIniFile.Create(Name + '.ini'); //in document RootDir
//general information
  Config.WriteString(SecDoc, 'projectdir', ProjectDir);
  Config.WriteString(SecDoc, 'projectfile', ProjectFile);
  Config.WriteString(SecDoc, 'inputdir', InputDir);
  Config.WriteString(SecDoc, 'descrdir', DescrDir);
  Config.WriteString(SecDoc, 'requires', Requires.CommaText);
//units
  WriteSection('units', Units);
  WriteSection('descrs', Descriptions);
//all done
  Loaded := True;
end;

{ TFPDocManager }

constructor TFPDocManager.Create(AOwner: TComponent);
var
  lst: TStringList;
begin
  inherited Create(AOwner);
  lst := TStringList.Create;
  lst.OwnsObjects := True;
  FPackages := lst;
end;

destructor TFPDocManager.Destroy;
begin
  FreeAndNil(Config); //save?
  FreeAndNil(FPackages);
  inherited Destroy;
end;

procedure TFPDocManager.SetFPDocDir(AValue: string);
begin
  if FFPDocDir=AValue then Exit;
  FFPDocDir:=AValue;
end;

procedure TFPDocManager.SetLazarusDir(AValue: string);
begin
  if FLazarusDir=AValue then Exit;
  FLazarusDir:=AValue;
end;

procedure TFPDocManager.SetOnChange(AValue: TNotifyEvent);
begin
  if FOnChange=AValue then Exit;
  FOnChange:=AValue;
end;

procedure TFPDocManager.SetPackage(AValue: TDocPackage);
begin
  if FPackage=AValue then Exit;
  FPackage:=AValue;
end;

(* Try load config from new dir - this may fail on the first run.
*)
procedure TFPDocManager.SetRootDir(AValue: string);
var
  s: string;
begin
  s := IncludeTrailingPathDelimiter(AValue);
  if FRootDir=s then Exit; //prevent recursion
  FRootDir:=s;
//load config - not here!
end;

procedure TFPDocManager.Changed;
begin
  if not Modified or (UpdateCount > 0) then
    exit; //should not be called directly
  FModified := False;
  if Assigned(OnChange) then
    FOnChange(self);
end;

function TFPDocManager.BeginTest(const AFile: string): boolean;
begin
  Helper.Free; //should have been done
  Helper := TFPDocHelper.Create(nil);
  Helper.OnLog := OnLog;
  Result := Helper.BeginTest(AFile);
end;

procedure TFPDocManager.EndTest;
begin
  SetCurrentDir(ExtractFileDir(RootDir));
  FreeAndNil(Helper);
end;

procedure TFPDocManager.BeginUpdate;
begin
  inc(UpdateCount);
end;

procedure TFPDocManager.EndUpdate;
begin
  dec(UpdateCount);
  if UpdateCount <= 0 then begin
    UpdateCount := 0;
    if Modified then
      Changed;
  end;
end;

(* Try load config.
  Init RootDir (only when config found?)
  Try load packages from their INI files
*)
function TFPDocManager.LoadConfig(const ADir: string; Force: boolean): boolean;
var
  s, pf, cf: string;
  i: integer;
  pkg: TDocPackage;
begin
  s := IncludeTrailingPathDelimiter(ADir);
  cf := s + ConfigName;
  Result := FileExists(cf);
  if not Result and not Force then
    exit;
  RootDir:=s; //recurse if RootDir changed
//sanity check: only one config file!
  if assigned(Config) then begin
    if (Config.FileName = cf) then
      exit(false) //nothing new?
    else
      Config.Free;
    //clear packages???
  end;
  Config := TIniFile.Create(cf);
  Config.CacheUpdates := True;
  //FDirty := True; //to be saved
  if not Result then
    exit; //nothing to read
//read directories
  FFPDocDir := Config.ReadString('dirs', 'fpc', '');
//read packages
  Config.ReadSectionValues(SecProjects, FPackages); //<prj>=<file>
//read detailed package information - possibly multiple packages per project!
  BeginUpdate;  //turn of app notification!
  for i := 0 to Packages.Count - 1 do begin
  //read package config (=project file name?)
    s := Packages.Names[i];
    pf := Packages.ValueFromIndex[i];
    if pf <> '' then begin
      AddProject(s, pf, False); //add and load project file, don't update config!
      FModified := True; //force app notification
    end;
  end;
//more? (preferences?)
//done, nothing modified
  EndUpdate;
end;

function TFPDocManager.SaveConfig: boolean;
begin
(* Protection against excessive saves requires a subclass of TIniFile,
  which flushes the file only if Dirty.
*)
end;

(* Add a DocPackage to Packages and INI.
  Return package Index.
  For exclusive use by Package.SetLoaded!
*)
function TFPDocManager.RegisterPackage(APkg: TDocPackage): integer;
begin
  Result := Packages.IndexOfName(APkg.Name);
  if Result < 0 then begin
  //add package
    Result := Packages.AddObject(APkg.Name + '=' + APkg.ProjectFile, APkg);
  end else if Packages.Objects[Result] = nil then
    Packages.Objects[Result] := APkg;
  if APkg.Loaded then begin
  //check/create project file?
    if (ExtractFileExt(APkg.ProjectFile) <> '.xml') then begin
    //create project file
      CreateProject(APkg.ProjectFile, APkg);
    //update Packages[] string
      Packages[Result] := APkg.Name + '=' + APkg.ProjectFile;
    end;
    Config.WriteString(SecProjects, APkg.Name, APkg.ProjectFile);
  end;
  FModified := True;
end;

(* Load FPDoc (XML) project file.
Called by
- init - not Dirty!
*)
function TFPDocManager.AddProject(const APkg, AFile: string; UpdateCfg: boolean): boolean;
var
  pkg: TDocPackage;
  i: integer;
begin
//create DocPackage
  pkg := AddPackage(APkg);
  if pkg.Loaded then
    exit(True); //assume registered!?
//check project file
  if ExtractFileExt(AFile) <> '.xml' then begin
    DoLog('Not a project file: ' + AFile);
    Exit(False);
  end;
//create helper
  BeginTest(AFile);
  try
  //load the project file into Helper
    Helper.LoadProjectFile(AFile);
    if Helper.Packages.Count = 1 then begin
      Helper.Package := Helper.Packages[0]; //in LoadProject?
      Result := pkg.ImportProject(Helper, Helper.Package, AFile);
      exit;
    end;
  //load all packages
    for i := 0 to Helper.Packages.Count - 1 do begin
      Helper.Package := Helper.Packages[i];
      pkg := AddPackage(Helper.Package.Name);
      if pkg.Loaded then
        continue; //already initialized
    {$IFDEF v0}
      if pkg.ImportProject(Helper, Helper.Package, '') then //force create new project file?
        RegisterPackage(pkg);
    {$ELSE}
      pkg.ImportProject(Helper, Helper.Package, '');
    //create new project file?
    {$ENDIF}
    end;
  finally
    EndTest;
  end;
end;

(* Ask DocPackage to create an projectfile.
  Overwrite if exists???
  AFileName is any file in the project directory, required for CD!
  !!! prevent recursive calls, destroying Helper !!!
*)
function TFPDocManager.CreateProject(const AFileName: string; APkg: TDocPackage
  ): boolean;
begin
  if Helper = nil then begin
    BeginTest(AFileName); //CD into project dir
    try
      Result := APkg.CreateProject(Helper, AFileName);
    finally
      EndTest;
    end;
  end else begin
  //assume that Helper IS for APkg
    Result := APkg.CreateProject(Helper, AFileName);
  end;
end;

(* Return the named package, create if not found.
  Rename: GetPackage?
*)
function TFPDocManager.AddPackage(AName: string): TDocPackage;
var
  i: integer;
begin
  AName := LowerCase(AName);
  i := FPackages.IndexOfName(AName);
  if i < 0 then
    Result := nil
  else
    Result := FPackages.Objects[i] as TDocPackage;
  if Result = nil then begin
    Result := TDocPackage.Create;
    Result.Name := AName; //triggers load config --> register
    i := FPackages.IndexOfName(AName); //already registered?
  end;
  if i < 0 then begin
  //we MUST create an entry
    Packages.AddObject(AName + '=' + Result.ProjectFile, Result);
  end;
end;

function TFPDocManager.ImportLpk(const AFile: string): TDocPackage;
var
  s: string;
begin
  BeginUpdate;
//import the LPK file into? Here: TDocPackage, could be FPDocProject?
  Result := uLpk.ImportLpk(AFile);
  if Result = nil then
    DoLog('Import failed on ' + AFile)
  else begin
    //todo: ImportCompiled - where?
    CreateProject(AFile, Result);
    FModified := True; //always?
    //Changed;
  end;
  EndUpdate;
end;

(* Add the project, just created from cmdline or projectfile
*)
procedure TFPDocManager.ImportProject(APkg: TFPDocPackage; const AFile: string);
var
  pkg: TDocPackage;
begin
  pkg := AddPackage(APkg.Name);
  pkg.ImportProject(Helper, APkg, AFile);
//update config?
  Config.WriteString(SecProjects, pkg.Name, AFile);
  FModified := true;
//notify app?
  //Changed;
end;

function TFPDocManager.ImportCmd(const AFile: string): boolean;
var
  pkg: TDocPackage;
begin
  Result := False;
  BeginTest(AFile);
  try
    Result := Helper.CmdToPrj(AFile);
    if not Result then
      exit;
    pkg := AddPackage(Helper.SelectedPackage.Name); //create [and register]
    if not pkg.Loaded then begin
      Result := pkg.ImportProject(Helper, Helper.Package, AFile);
    //register now, with project file known
      //RegisterPackage(pkg);
    end;
  finally
    EndTest;
  end;
  if Result then
    Changed;
end;

function TFPDocManager.TestRun(APkg: TDocPackage; AUnit: string): boolean;
begin
  BeginTest(APkg.ProjectFile);
  try
    Result := Helper.TestRun(APkg, AUnit);
  finally
    EndTest;
  end;
end;

function TFPDocManager.Update(APkg: TDocPackage; const AUnit: string): boolean;
begin
  BeginTest(APkg.ProjectFile);
  try
    Result := Helper.Update(APkg, AUnit);
  finally
    EndTest;
  end;
end;

procedure TFPDocManager.DoLog(const Msg: String);
begin
  if Assigned(FOnLog) then
    FOnLog(self, msg);
end;

{ TFPDocHelper }

constructor TFPDocHelper.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  InputList := TStringList.Create;
  DescrList := TStringList.Create;
end;

destructor TFPDocHelper.Destroy;
begin
  FreeAndNil(InputList);
  FreeAndNil(DescrList);
  inherited Destroy;
end;

(* Prepare MakeSkel on temporary FPDocPackage
*)
function TFPDocHelper.BeginTest(APkg: TDocPackage): boolean;
var
  pf: string;
begin
  if not assigned(APkg) then
    exit(False);
  Result := BeginTest(APkg.ProjectFile);
  if not Result then
    exit;
  ParseFPDocOption('--project='+APkg.ProjectFile);
  Package := Packages.FindPackage(APkg.Name);
//okay, so far
  Result := assigned(Package);
end;

procedure TFPDocHelper.EndTest;
begin
//???
end;

function TFPDocHelper.BeginTest(const AFile: string): boolean;
begin
  Result := AFile <> '';
  if not Result then
    exit;
//remember dir!
  ProjectDir:=ExtractFileDir(AFile);
  SetCurrentDir(ProjectDir);
end;

(* Create a project from an FPDoc commandline.
  Do NOT create an project file!(?)
*)
function TFPDocHelper.CmdToPrj(const AFileName: string): boolean;
var
  l, w: string;
  i: integer;
begin
  Result := False; //in case of errors
//read the commandline
  InputList.LoadFromFile(AFileName);
  for i := 0 to InputList.Count - 1 do begin
    l := InputList[i];
    w := GetNextWord(l);
    if w = 'fpdoc' then begin //contains!?
      Result := True; //so far
      break; //fpdoc command found
    end;
  end;
  InputList.Clear;
  if not Result then
    exit;
//parse commandline
  while l <> '' do begin
    w := GetNextWord(l);
    ParseFPDocOption(w);
  end;
{
  w := SelectedPackage.Name;
  if w = '' then
    exit; //no project name???
  l := ChangeFileExt(AFileName, '_prj.xml'); //same directory!!!
  //Result := CreateProject(l, Package);
//now load the project into the manager
  if Result then //add package/project to the manager?
    Manager.AddProject(w, l); //.Packages.Add(w + '=' + l);
}
  Result := True;
end;

function TFPDocHelper.TestRun(APkg: TDocPackage; AUnit: string): boolean;
var
  pf, dir: string;
begin
(* more detailed error handling?
  Must CD to the project file directory!?
*)
  Result := BeginTest(APkg);
  if not Result then
    exit;
  try
    ParseFPDocOption('--format=html');
    ParseFPDocOption('-n');
    Package := Packages.FindPackage(APkg.Name);
    Result := Package <> nil;
    if Result then
      CreateUnitDocumentation(Package, AUnit, True);
  finally
    EndTest;
  end;
end;

(* MakeSkel functionality - create skeleton or update file
  using temporary Project
*)
//function TFPDocManager.Update(APkg: TDocPackage; const AUnit: string): boolean;
function TFPDocHelper.Update(APkg: TDocPackage; const AUnit: string): boolean;

  function DocumentUnit(const AUnit: string): boolean;
  var
    OutName, msg: string;
  begin
    InputList.Clear;
    InputList.Add(UnitSpec(AUnit));
    DescrList.Clear;
    OutName := DescrDir + AUnit + '.xml';
    Options.UpdateMode := FileExists(OutName);
    if Options.UpdateMode then begin
      DescrList.Add(APkg.DescrDir + AUnit + '.xml');
      OutName:=Manager.RootDir + 'upd.' + AUnit + '.xml';
      DoLog('Update ' + OutName);
    end else begin
      DoLog('Create ' + OutName);
    end;
    msg := DocumentPackage(APkg.Name, OutName, InputList, DescrList);
    Result := msg = '';
    if not Result then
      DoLog(msg) //+unit?
    else if Options.UpdateMode then begin
      CleanXML(OutName);
    end;
  end;

var
  i: integer;
  u: string;
begin
  Result := BeginTest(APkg);
  if not Result then
    exit;
  if AUnit <> '' then begin
    Result := DocumentUnit(AUnit);
  end else begin
    for i := 0 to Package.Inputs.Count - 1 do begin
      u := ExtractUnitName(Package.Inputs, i);
      DocumentUnit(u);
    end;
  end;
  EndTest;
end;

(* Kill file if no "<element" found
*)
procedure TFPDocHelper.CleanXML(const FileName: string);
var
  f: TextFile;
  s: string;
begin
  AssignFile(f, FileName);
  Reset(f);
  try
    while not EOF(f) do begin
      ReadLn(f, s);
      if Pos('<element ', s) > 0 then
        exit; //file not empty
    end;
  finally
    CloseFile(f);
  end;
//nothing found, delete the file
  if DeleteFile(FileName) then
    DoLog('File ' + FileName + ' has no elements. Deleted.')
  else
    DoLog('File ' + FileName + ' has no elements. Delete failed.');
end;

procedure TFPDocHelper.SetProjectDir(AValue: string);
begin
  if FProjectDir=AValue then Exit;
  FProjectDir:=AValue;
end;

end.
