unit U_SimpleComPort;

interface

uses Windows, SysUtils, Classes, StrUtils;

type
  TByteSize = (bs5, bs6, bs7, bs8);
  TParity = (paNone, paOdd, paEven, paMark, paSpace);
  TStopBits = (sb1, sb1_5, sb2);

  TSComPort = class
  private
    FConnected: boolean;
    FHandle: THandle;
    FTxBufferSize: cardinal;
    FBaudRate: cardinal;
    FParity: TParity;
    FReadInterval: integer;
    FStopBits: TStopBits;
    FReadTotalMultiplier: integer;
    FReadTotalConstant: integer;
    FWriteTotalMultiplier: integer;
    FWriteTotalConstant: integer;
    FByteSize: TByteSize;
    FFlags: integer;
    FRxBufferSize: cardinal;
    FPort: string;
  public
    constructor Create(AOwner: TComponent); overload;
    constructor Create(); overload;
    destructor Destroy; override;
    function Read(var Buffer; Count: integer): integer;
    function ReadStream(aStream: TMemoryStream; aCount: integer): integer;
    function Write(const Buffer; Count: integer): integer;
    function WriteStream(aStream: TMemoryStream): integer;
    procedure FlushBuffer;
    function Open: boolean;
    function Close: boolean;
    property Connected: boolean read FConnected;
    property Port: string read FPort write FPort;
    property BaudRate: cardinal read FBaudRate write FBaudRate default 9600;
    property ByteSize: TByteSize read FByteSize write FByteSize default bs8;
    property Parity: TParity read FParity write FParity default paNone;
    property Flags: integer read FFlags write FFlags default 1;
    property StopBits: TStopBits read FStopBits write FStopBits default sb1;
    property ReadInterval: integer read FReadInterval write FReadInterval default 1000;
    property ReadTotalMultiplier: integer read FReadTotalMultiplier write FReadTotalMultiplier default 0;
    property ReadTotalConstant: integer read FReadTotalConstant write FReadTotalConstant default 1000;
    property WriteTotalMultiplier: integer read FWriteTotalMultiplier write FWriteTotalMultiplier default 0;
    property WriteTotalConstant: integer read FWriteTotalConstant write FWriteTotalConstant default 1000;
    property InBufSize: cardinal read FRxBufferSize write FRxBufferSize default 2048;
    property OutBufSize: cardinal read FTxBufferSize write FTxBufferSize default 2048;
  end;

procedure EnumComPorts(Ports: TStrings);

implementation

procedure EnumComPorts(Ports: TStrings);
var
  KeyHandle: HKEY;
  ErrCode, Index: integer;
  ValueName: widestring;
  Data: ansistring;
  ValueLen, DataLen, ValueType: DWORD;
  TmpPorts: TStringList;
begin
  ErrCode := RegOpenKeyEx(HKEY_LOCAL_MACHINE, 'HARDWARE\DEVICEMAP\SERIALCOMM', 0, KEY_READ, KeyHandle);
  if ErrCode <> ERROR_SUCCESS then
  begin
    // raise EComPort.Create(CEMess[15]);
    Ports.Clear;
    exit;
  end;
  TmpPorts := TStringList.Create;
  TmpPorts.BeginUpdate;
  try
    Index := 0;
    repeat
      ValueLen := 256;
      DataLen := 256;
      SetLength(ValueName, ValueLen);
      SetLength(Data, DataLen);
      ErrCode := RegEnumValue(KeyHandle, Index, pwidechar(ValueName),
{$IFDEF VER120}
        cardinal(ValueLen),
{$ELSE}
        ValueLen,
{$ENDIF}
        nil, @ValueType, PByte(pansichar(Data)), @DataLen);
      if ErrCode = ERROR_SUCCESS then
      begin
        SetLength(Data, DataLen);
        TmpPorts.Add(ReplaceStr(string(Data), #0, ''));
        Inc(Index);
      end
      else
        if ErrCode <> ERROR_NO_MORE_ITEMS then
      begin
        // raise EComPort.Create(CEMess[15]);
        break;
      end;
    until (ErrCode <> ERROR_SUCCESS);
    TmpPorts.Sort;
    Ports.Assign(TmpPorts);
  finally
    RegCloseKey(KeyHandle);
    TmpPorts.EndUpdate;
    TmpPorts.Free;
  end;
end;

function CloseCOMPort(var hFile: THandle): boolean; forward;

function OpenCOMPort(var hFile: THandle; const aPortName: string): boolean;
begin
  { First step is to open the communications device for read/write. 
    This is achieved using the Win32 'CreateFile' function. 
    If it fails, the function returns false. 
  }
  hFile := CreateFile(pchar('\\.\' + aPortName),
    GENERIC_READ or GENERIC_WRITE,
    0,
    nil,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL,
    0);

  if hFile = INVALID_HANDLE_VALUE then
    Result := False
  else
  begin
    // —брос буферов порта.
    Result := PurgeComm(hFile, PURGE_TXABORT or PURGE_RXABORT or PURGE_TXCLEAR or PURGE_RXCLEAR);
    if (not Result) then
      CloseCOMPort(hFile);

    // —брос значений регистров порта.
    if (hFile <> INVALID_HANDLE_VALUE) then
    begin
      Result := ClearCommBreak(hFile);
      if (not Result) then
        CloseCOMPort(hFile);
    end;
  end;
end;

function SetupCOMPort(hFile: THandle; 
  aBaudRate: cardinal = 9600; aByteSize: TByteSize = bs8; aParity: TParity = paNone;
  aFlags: integer = 1;
  aStopBits: TStopBits = sb1;
  aReadInterval: integer = 1000;
  aReadTotalMultiplier: integer = 0;
  aReadTotalConstant: integer = 1000;
  aWriteTotalMultiplier: integer = 0;
  aWriteTotalConstant: integer = 1000;
  aRxBufferSize: cardinal = 2048; 
  aTxBufferSize: cardinal = 2048): boolean;
var
  DCB: TDCB;
  // Config: string;
  CommTimeouts: TCommTimeouts;
begin
  { We assume that the setup to configure the setup works fine. 
    Otherwise the function returns false. 

    wir gehen davon aus das das Einstellen des COM Ports funktioniert. 
    sollte dies fehlschlagen wird der Ruckgabewert auf "FALSE" gesetzt. 
  }

  Result := SetupComm(hFile, aRxBufferSize, aTxBufferSize);

  if (Result) then
  begin
    Result := GetCommState(hFile, DCB);
    if (Result) then
    begin

      // define the baudrate, parity,...
      // hier die Baudrate, Paritat usw. konfigurieren

      // Config := 'baud=9600 parity=n data=8 stop=1';

      // if not BuildCommDCB(@Config[1], DCB) then
      // Result := False;

      FillChar(DCB, SizeOf(TDCB), 0);
      DCB.DCBlength := SizeOf(TDCB);
      DCB.BaudRate := aBaudRate;
      DCB.ByteSize := Ord(TByteSize(aByteSize)) + 5;
      DCB.Flags := 1;
      if aParity <> paNone then
        DCB.Flags := DCB.Flags or 2;
      DCB.Parity := Ord(TParity(aParity));
      DCB.StopBits := Ord(TStopBits(aStopBits));
      DCB.XonChar := #17;
      DCB.XoffChar := #19;

      Result := SetCommState(hFile, DCB);

      if (Result) then
      begin
        with CommTimeouts do
        begin
          ReadIntervalTimeout := aReadInterval;
          ReadTotalTimeoutMultiplier := aReadTotalMultiplier;
          ReadTotalTimeoutConstant := aReadTotalConstant;
          WriteTotalTimeoutMultiplier := aWriteTotalMultiplier;
          WriteTotalTimeoutConstant := aWriteTotalConstant;
        end;

        Result := SetCommTimeouts(hFile, CommTimeouts);
      end;
    end;
  end;
end;

function CloseCOMPort(var hFile: THandle): boolean;
begin
  // finally close the COM Port!
  // nicht vergessen den COM Port wieder zu schliessen!
  Result := CloseHandle(hFile);
  hFile := INVALID_HANDLE_VALUE;
end;

{ 
  The following is an example of using the 'WriteFile' function 
  to write data to the serial port. 
}

function WriteComPort(var hFile: THandle; const Buffer; Count: cardinal): cardinal;
var
  comStat: TCOMSTAT;
  e: cardinal;
begin
  if not WriteFile(hFile, Buffer, Count, Result, nil) then
  begin
    CloseCOMPort(hFile);
  end
  else
    ClearCommError(hFile, e, @comStat);
end;

{ 
  The following is an example of using the 'ReadFile' function to read 
  data from the serial port. 
}

function ReadComPort(var hFile: THandle; var aBuffer; aLength: cardinal): cardinal;
var
  comStat: TCOMSTAT;
  e: cardinal;
begin
  Result := 0;
  if not ReadFile(hFile, aBuffer, aLength, Result, nil) then
  begin
    { Raise an exception }
    CloseCOMPort(hFile);
  end
  else
    ClearCommError(hFile, e, @comStat);
end;

{ TSComPort }

constructor TSComPort.Create(AOwner: TComponent);
begin
  Create;
end;

function TSComPort.Close: boolean;
begin
  Result := true;
  if (FConnected) then
  begin
    FConnected := False;
    Result := CloseCOMPort(FHandle)
  end;
end;

constructor TSComPort.Create;
begin
  inherited;
  FConnected := False;
  FHandle := 0;
end;

destructor TSComPort.Destroy;
begin
  Close;
  inherited;
end;

procedure TSComPort.FlushBuffer;
begin
  FlushFileBuffers(FHandle);
end;

function TSComPort.Open: boolean;
begin
  if (FConnected) then
    CloseCOMPort(FHandle);
  FConnected := OpenCOMPort(FHandle, FPort);
  Result := FConnected;
  if (FConnected) then
  begin
    Result := SetupCOMPort(FHandle, FBaudRate, FByteSize, FParity, FFlags,
      FStopBits, FReadInterval, FReadTotalMultiplier, FReadTotalConstant,
      FWriteTotalMultiplier, FWriteTotalConstant, FRxBufferSize, FTxBufferSize);
    if (not Result) then
    begin
      CloseCOMPort(FHandle);
      FConnected := False;
    end;
  end;
end;

function TSComPort.Read(var Buffer; Count: integer): integer;
var
  zBuff: array [0 .. 4095] of byte;
begin
  FConnected := FConnected and (FHandle <> INVALID_HANDLE_VALUE);
  if FConnected then
  begin
    Result := ReadComPort(FHandle, zBuff, Count);
    move(zBuff, Buffer, Count);
    FConnected := FHandle <> INVALID_HANDLE_VALUE;
  end
  else
    Result := 0;
end;

function TSComPort.ReadStream(aStream: TMemoryStream; aCount: integer): integer;
var
  // zPtr: PByte;
  i: integer;
  aValue: byte;
begin
  { if (aCount > 0) then
    begin
    aStream.Size := aStream.Size + aCount;
    zPtr := aStream.Memory;
    Inc(zPtr, aStream.Position);
    Result := Read(zPtr^, aCount);
    if (Result < aCount) then
    aStream.Size := aStream.Size - (aCount - Result);
    end
    else
    Result := 0;
  }
  Result := 0;
  for i := 0 to aCount - 1 do
    if (Connected) then
    begin
      if (Read(aValue, 1) = 1) then
      begin
        aStream.Write(aValue, 1);
        Inc(Result);
      end
      else
        break;
    end;

end;

function TSComPort.Write(const Buffer; Count: integer): integer;
begin
  FConnected := FConnected and (FHandle <> INVALID_HANDLE_VALUE);
  if FConnected then
  begin
    Result := WriteComPort(FHandle, Buffer, Count);
    FConnected := FHandle <> INVALID_HANDLE_VALUE;
  end
  else
    Result := 0;
end;

function TSComPort.WriteStream(aStream: TMemoryStream): integer;
var
  i: integer;
  aValue: byte;
begin
  // Result := Write(aStream.Memory^, aStream.Size);
  Result := 0;
  for i := aStream.Position to aStream.Size - 1 do
    if (Connected) then
    begin
      aStream.Read(aValue, 1);
      if (Write(aValue, 1) = 1) then
        Inc(Result)
      else
        break;
    end;

end;

end.
