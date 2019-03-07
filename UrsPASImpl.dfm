object PAServerLauncher: TPAServerLauncher
  OldCreateOrder = False
  AllowPause = False
  DisplayName = '!PAServerLauncher'
  StartType = stManual
  OnStart = ServiceStart
  OnStop = ServiceStop
  Height = 150
  Width = 215
end
