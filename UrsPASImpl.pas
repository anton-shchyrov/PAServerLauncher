unit UrsPASImpl;

{$WARN SYMBOL_PLATFORM OFF}

interface

uses
  Vcl.SvcMgr;

type
  TPAServerLauncher = class(TService)
    procedure ServiceStart(Sender: TService; var AStarted: Boolean);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
  private
    FProcHandle: THandle;
    FInWritePipe: THandle;
  public
    function GetServiceController: TServiceController; override;
  end;

var
  PAServerLauncher: TPAServerLauncher;

implementation

uses
  Winapi.Windows,
  System.SysUtils;

{$R *.dfm}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  PAServerLauncher.Controller(CtrlCode);
end;

function TPAServerLauncher.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TPAServerLauncher.ServiceStart(Sender: TService;
  var AStarted: Boolean);
var
  LBasePath: string;
  LProcName: string;
  LInReadPipe: THandle;
  LSecAttr: TSecurityAttributes;
  LStartup: TStartupInfo;
  LProcInfo: TProcessInformation;
begin
  try
    LBasePath := ExtractFilePath(GetModuleName(HInstance));
    LProcName := LBasePath + 'PAServer.exe';

    LSecAttr.nLength := SizeOf(LSecAttr);
    LSecAttr.lpSecurityDescriptor := nil;
    LSecAttr.bInheritHandle := True;

    Win32Check(CreatePipe(LInReadPipe, FInWritePipe, @LSecAttr, 0));
    try
      Win32Check(SetHandleInformation(FInWritePipe, HANDLE_FLAG_INHERIT, 0));

      FillChar(LStartup, SizeOf(LStartup), 0);
      LStartup.cb := SizeOf(LStartup);
      LStartup.dwFlags := STARTF_USESTDHANDLES;
      LStartup.hStdInput := LInReadPipe;

      Win32Check(CreateProcess(
        PChar(LProcName),
        PChar(Format('"%s"', [LProcName])),
        nil,
        nil,
        True,
        0,
        nil,
        PChar(LBasePath),
        LStartup,
        LProcInfo
      ));
    finally
      CloseHandle(LInReadPipe);
    end;
    CloseHandle(LProcInfo.hThread);

    FProcHandle := LProcInfo.hProcess;
    AStarted := True;
  except
    on E: Exception do begin
      LogMessage(E.Message);
      AStarted := False;
      if FInWritePipe <> 0 then begin
        CloseHandle(FInWritePipe);
        FInWritePipe := 0;
      end;
    end;
  end;
end;

procedure TPAServerLauncher.ServiceStop(Sender: TService; var Stopped: Boolean);
const
  CExit: AnsiString = 'q' + sLineBreak;
var
  LWriteCnt: Cardinal;
begin
  if WaitForSingleObject(FProcHandle, 0) = WAIT_TIMEOUT then begin
    Win32Check(WriteFile(FInWritePipe, CExit[1], Length(CExit), LWriteCnt, nil));
    WaitForSingleObject(FProcHandle, INFINITE);
  end;
  CloseHandle(FProcHandle);
  CloseHandle(FInWritePipe);
end;

end.
