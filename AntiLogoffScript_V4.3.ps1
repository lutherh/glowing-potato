#prerequests and parameters
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.speech

#Build EXE from this ps1
#Invoke-ps2exe -InputFile "C:\Users\marcel\Desktop\StarCitizen Tools\Projekt Jericho (3D Navigation)\AntiLogoff\AntiLogoffScript_V4.3.ps1" -OutputFile "C:\Users\marcel\Desktop\StarCitizen Tools\Projekt Jericho (3D Navigation)\AntiLogoff\AntiLogoffScript_V4.3.exe" -IconFile "C:\Users\marcel\Desktop\StarCitizen Tools\Projekt Jericho (3D Navigation)\AntiLogoff\bin\AntiLogoff_Inactive.ico"

#$form = [Hashtable]::Synchronized(@{})
$RunSpaceSyncData = [hashtable]::Synchronized(@{})
$RunSpaceSyncData.objNotifyIcon = New-Object System.Windows.Forms.NotifyIcon


if($psISE){$script:ScriptDir = Split-Path -Path $psISE.CurrentFile.FullPath}                                                                     #Powershell ISE Editor
if((Get-Host).Version.Major -gt "5"){$script:ScriptDir = $PSScriptRoot}else{$script:ScriptDir = $PSScriptRoot}                                   #Powershell V7 or v5
if($env:TERM_PROGRAM -eq "vscode"){$script:ScriptDir = [System.IO.Path]::GetDirectoryName($psEditor.GetEditorContext().CurrentFile.Path)}        #Visual Studio Code
if($null -ne $env:WT_SESSION){$script:ScriptDir  = (Get-Item .).FullName} 
$script:ScriptDir = if (-not $PSScriptRoot) { Split-Path -Parent (Convert-Path ([Environment]::GetCommandLineArgs()[0])) } else { $PSScriptRoot } #PS1 to EXE Convter
# $script:ScriptDir = "C:\Users\marcel\Desktop\StarCitizen Tools\Projekt Jericho (3D Navigation)\AntiLogoff"

#keystrokes
#Add-Type -Path "$script:ScriptDir\ClassLibrary1.dll"
#Add-Type -Path "$script:ScriptDir\ClassLibrary2.dll"

#Load settings from config file, with default having anything turned on
$RunSpaceSyncData.DisableWarningMessage = $false
$RunSpaceSyncData.DisableSounds = $false
$RunSpaceSyncData.DisableNotifications = $false

Get-Content "$($script:ScriptDir)\settings.cfg" | ForEach-Object {
    $key, $value = $_ -split '\s*=\s*'
    $boolValue = if ($value -eq '0') { $false } else { $true }
    switch ($key.Trim()) {
        "DisableWarningMessage" { $RunSpaceSyncData.DisableWarningMessage = $boolValue }
        "DisableSounds"         { $RunSpaceSyncData.DisableSounds = $boolValue }
        "DisableNotifications"  { $RunSpaceSyncData.DisableNotifications = $boolValue }
    }
}

#Allow only a single instance of the script
$pipeName = "MyPowerShellScriptPipe"
$pipePath = "\\.\pipe\$pipeName"

# Try to create a named pipe server
try{$pipeHandle = [System.IO.Pipes.NamedPipeServerStream]::new($pipeName)}catch{
    msg * "Anti-Logoff is already running, exiting"
    exit 1
}

# Extract Icon from DLL
add-type @"

using System;
using System.Runtime.InteropServices;

public class Shell32_Extract {

  [DllImport(
     "Shell32.dll",
      EntryPoint        = "ExtractIconExW",
      CharSet           =  CharSet.Unicode,
      ExactSpelling     =  true,
      CallingConvention =  CallingConvention.StdCall)
  ]

   public static extern int ExtractIconEx(
      string lpszFile          , // Name of the .exe or .dll that contains the icon
      int    iconIndex         , // zero based index of first icon to extract. If iconIndex == 0 and and phiconSmall == null and phiconSmall = null, the number of icons is returnd
      out    IntPtr phiconLarge,
      out    IntPtr phiconSmall,
      int    nIcons
  );

}
"@

$ErrorActionPreference = "Stop"

[System.IntPtr] $phiconSmall = 0
[System.IntPtr] $phiconLarge = 0

$nofIconsExtracted = [Shell32_Extract]::ExtractIconEx("$script:ScriptDir\icons.dll", 0, [ref] $phiconLarge, [ref] $phiconSmall, 1)
$RunSpaceSyncData.Icon1 = [System.Drawing.Icon]::FromHandle($phiconLarge) #red

[System.IntPtr] $phiconSmall = 0
[System.IntPtr] $phiconLarge = 0
$nofIconsExtracted = [Shell32_Extract]::ExtractIconEx("$script:ScriptDir\icons.dll", 1, [ref] $phiconLarge, [ref] $phiconSmall, 1)
$RunSpaceSyncData.Icon2 = [System.Drawing.Icon]::FromHandle($phiconLarge) #yellow

[System.IntPtr] $phiconSmall = 0
[System.IntPtr] $phiconLarge = 0
$nofIconsExtracted = [Shell32_Extract]::ExtractIconEx("$script:ScriptDir\icons.dll", 2, [ref] $phiconLarge, [ref] $phiconSmall, 1)
$RunSpaceSyncData.Icon3 = [System.Drawing.Icon]::FromHandle($phiconLarge) #red

$RunSpaceSyncData.objNotifyIcon.Icon = $RunSpaceSyncData.Icon3
$RunSpaceSyncData.objNotifyIcon.Text = "AntiLogoff V4.0"

#show icon always on desktop
#REG ADD HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\FileZilla.Client.AppID /v Enabled /t REG_DWORD /d 1 /f

######################################################
$AntiLogoff = {
    param($syncData)

$source = @"
    using System;
    using System.Collections.Generic;
    using System.Text;
    using System.Runtime.InteropServices;
    
    //class for accessing windows - can be access with [User32]::SetForegroundWindow
    public class User32 {
        [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool SetForegroundWindow(IntPtr hWnd);
        [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
        [DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(IntPtr hWnd, out int lpdwProcessId);
        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
    }

    //class to send directx input to games - can be accessed with [KeyboardEmulator]::SendKey
    public static class KeyboardEmulator {
        [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
        [DllImport("user32.dll")] public static extern byte MapVirtualKey(uint uCode, uint uMapType);

        public static void SendKey(byte key) {
            const uint KEYEVENTF_EXTENDEDKEY = 0x0000;
            const uint KEYEVENTF_KEYUP = 0x0002;
            keybd_event(key, MapVirtualKey(key, 0), KEYEVENTF_EXTENDEDKEY, (UIntPtr)0);
            keybd_event(key, MapVirtualKey(key, 0), KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, (UIntPtr)0);
        }

        public static void SendKeyAction(byte key, byte key2) {
            keybd_event(key, MapVirtualKey(key, 0), key2, (UIntPtr)0);
        }

    }

    public class KeyboardEmulator2 {
        [DllImport("user32.dll", SetLastError = true)] static extern void keybd_event(byte bVk, byte bScan, int dwFlags, int dwExtraInfo);
        [DllImport("user32.dll")] public static extern byte MapVirtualKey(uint uCode, uint uMapType);
        const int KEY_DOWN_EVENT = 0x0000;        //Key down flag
        const int KEY_DOWN_EXTENDED = 0x0001;     //Key extended flag
        const int KEY_UP_EVENT = 0x0002;          //Key up flag
                                                  //UniCode = 0x0004 and ScanCode = 0x0008

        public static void HoldKey(byte key, int duration)
        {
            int PauseBetweenStrokes = duration;
            keybd_event(key, MapVirtualKey(key, 0), KEY_DOWN_EVENT, 0);
            System.Threading.Thread.Sleep(PauseBetweenStrokes);
            keybd_event(key, MapVirtualKey(key, 0), KEY_UP_EVENT, 0);
        }
    }

    public static class KeyboardEmulator3 {
        public enum InputType : uint {
            INPUT_MOUSE = 0,
            INPUT_KEYBOARD = 1,
            INPUT_HARDWARE = 3
        }

        [Flags]
        internal enum KEYEVENTF : uint
        {
            KEYDOWN = 0x0,
            EXTENDEDKEY = 0x0001,
            KEYUP = 0x0002,
            SCANCODE = 0x0008,
            UNICODE = 0x0004
        }

        [Flags]
        internal enum MOUSEEVENTF : uint
        {
            ABSOLUTE = 0x8000,
            HWHEEL = 0x01000,
            MOVE = 0x0001,
            MOVE_NOCOALESCE = 0x2000,
            LEFTDOWN = 0x0002,
            LEFTUP = 0x0004,
            RIGHTDOWN = 0x0008,
            RIGHTUP = 0x0010,
            MIDDLEDOWN = 0x0020,
            MIDDLEUP = 0x0040,
            VIRTUALDESK = 0x4000,
            WHEEL = 0x0800,
            XDOWN = 0x0080,
            XUP = 0x0100
        }

        // Master Input structure
        [StructLayout(LayoutKind.Sequential)]
        public struct lpInput {
            internal InputType type;
            internal InputUnion Data;
            internal static int Size { get { return Marshal.SizeOf(typeof(lpInput)); } }			
        }

        // Union structure
        [StructLayout(LayoutKind.Explicit)]
        internal struct InputUnion {
            [FieldOffset(0)]
            internal MOUSEINPUT mi;
            [FieldOffset(0)]
            internal KEYBDINPUT ki;
            [FieldOffset(0)]
            internal HARDWAREINPUT hi;
        }

        // Input Types
        [StructLayout(LayoutKind.Sequential)]
        internal struct MOUSEINPUT
        {
            internal int dx;
            internal int dy;
            internal int mouseData;
            internal MOUSEEVENTF dwFlags;
            internal uint time;
            internal UIntPtr dwExtraInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        internal struct KEYBDINPUT
        {
            internal short wVk;
            internal short wScan;
            internal KEYEVENTF dwFlags;
            internal int time;
            internal UIntPtr dwExtraInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        internal struct HARDWAREINPUT
        {
            internal int uMsg;
            internal short wParamL;
            internal short wParamH;
        }

        private class unmanaged {
            [DllImport("user32.dll", SetLastError = true)]
            internal static extern uint SendInput (
                int cInputs, 
                [MarshalAs(UnmanagedType.LPArray)]
                lpInput[] inputs,
                int cbSize
            );
            
            [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
            public static extern short VkKeyScan(char ch);
        }

        internal static byte[] VkKeyScan(char ch) {
            short keyCode = unmanaged.VkKeyScan(ch);
            if(keyCode > 254) {
                byte key = BitConverter.GetBytes(keyCode)[0];
                byte highByte = BitConverter.GetBytes(keyCode)[1];
                byte extraKey = 0;
                switch(highByte) {
                    case 0x1:
                        extraKey = 0x10;  //VK_SHIFT
                        break;
                    case 0x2:
                        extraKey = 0x11;  //VK_CONTROL
                        break;
                    case 0x4:
                        extraKey = 0x12;  //VK_ALT
                        break;
                }
                byte[] rtn = new byte[] {extraKey, key};
                return rtn;
            } else {
                byte[] rtn = new byte[] {BitConverter.GetBytes(keyCode)[0]};
                return rtn;
            }
            
        }

        internal static uint SendInput(int cInputs, lpInput[] inputs, int cbSize) {return unmanaged.SendInput(cInputs, inputs, cbSize);}

        // Virtual KeyCodes: https://msdn.microsoft.com/en-us/library/windows/desktop/dd375731(v=vs.85).aspx
        public static void SendKeyCode(byte[] keyCode) {
            lpInput[] KeyInputs = new lpInput[keyCode.Length];
            
            for(int i = 0; i < keyCode.Length; i++) {
                lpInput KeyInput = new lpInput();
                // Generic Keyboard Event
                KeyInput.type = InputType.INPUT_KEYBOARD;
                KeyInput.Data.ki.wScan = 0;
                KeyInput.Data.ki.time = 0;
                KeyInput.Data.ki.dwExtraInfo = UIntPtr.Zero;
                
                
                // Push the correct key
                KeyInput.Data.ki.wVk = Convert.ToInt16(keyCode[i]);
                KeyInput.Data.ki.dwFlags = KEYEVENTF.KEYDOWN;
                KeyInputs[i] = KeyInput;
            }
            SendInput(keyCode.Length, KeyInputs, lpInput.Size);
            
            // Release the key
            for(int i = 0; i < keyCode.Length; i++) {
                KeyInputs[i].Data.ki.dwFlags = KEYEVENTF.KEYUP;
            }
            SendInput(keyCode.Length, KeyInputs, lpInput.Size);
            
            return;
        }

        public static void SendCharacter(char ch) {
            SendKeyCode(VkKeyScan(ch));
            return;
        }

        public static void SendString(string st) {
            foreach (char ch in st.ToCharArray()) 
            {
                SendCharacter(ch);
            }
        }

        public static byte[] GetKeyCode(char ch) {
            return VkKeyScan(ch);
        }
    }
"@
Add-Type -TypeDefinition $source


#keystrokes
Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class KeyboardMonitor {
        [DllImport("user32.dll")]
        public static extern short GetAsyncKeyState(int vKey);
    }
    public class Kernel32 {
        [DllImport("kernel32.dll")]
        public static extern IntPtr GetConsoleWindow();
    }
"@



#    $host.UI.WriteLine("[$(Get-Date -Format HH:mm:ss)] INFO - test")

    $PowerShellWindowHandle = [Kernel32]::GetConsoleWindow()

    $MonitoringDurationForKeypresses = 500
    $MinDelayLoop = 1
    $MaxDelayLoop = 30
    $host.UI.WriteLine("[$(Get-Date -Format HH:mm:ss)] LOOP - Anti-Logoff started with monitoring duration: $MonitoringDurationForKeypresses secs")

    #Start Loop for Monitoring StarCitizen
    while($true){
        #Starting Parameters
        $StarCitizenRunning = $null
        $StarCitizenFocussed = $null
        $StarCitizenProcess = $null
        $KeystrokesSentToSC = $null
        $keystroke = $null

        if ($PSVersionTable.PSEdition -eq 'Core' -and $PSVersionTable.PSVersion -ge 7) {
            $green = "`e[32m"  # Green
            $cyan = "`e[36m"   # Cyan
            $reset = "`e[0m"   # Reset
            $darkGray = "`e[90m"  # Dark Gray
            $red = "`e[31m"       # Red
            $yellow = "`e[33m"    # Yellow
        } else {
            # Set empty values for legacy PowerShell
            $green = ""
            $cyan = ""
            $reset = ""
            $darkGray = ""
            $red = ""
            $yellow = ""
        }
        
        #$RunSpaceSyncData.objNotifyIcon.ContextMenuStrip.Items[0].Text = "test"

        while($syncData.AntiloggoffActive -eq $true){
            #$host.UI.WriteLine("[$(Get-Date -Format HH:mm:ss)] INFO - Activated")
            $host.UI.Write("$reset[$(Get-Date -Format HH:mm:ss)] INFO -$cyan new loop starting$reset`n")

            #Detect any Keypresses sent to SC in the past 300secs
            $randomDelayLoop = Get-Random -Minimum $MinDelayLoop -Maximum $MaxDelayLoop
            $endTime = (Get-Date).AddSeconds($MonitoringDurationForKeypresses + $randomDelayLoop)
            $host.UI.WriteLine("[$(Get-Date -Format HH:mm:ss)] INFO - total cycle duration:$cyan $($MonitoringDurationForKeypresses + $randomDelayLoop)$reset secs (randomized)")
            
            $Host.UI.RawUI.WindowTitle = "StarCitizen Detection Phase from [$(Get-Date -Format HH:mm:ss)] until [$($endTime.ToString('HH:mm:ss'))]"

            $lastMousePosition = [System.Windows.Forms.Cursor]::Position
            $global:activityDetected = $false

            while ((Get-Date) -lt $endTime) {
                #Detect if Star Citizen is running
                $StarCitizenProcess = Get-Process | Where-Object {$_.mainWindowTitle } | Where-Object {$_.Name -like "StarCitizen"}
                $StarCitizenHandle = $StarCitizenProcess.MainWindowHandle
                if($StarCitizenProcess -ne $null){
                    if($StarCitizenRunning -ne $true){
                        #Trigger Notification only once until StarCitizen Windows got detected
                        $RunSpaceSyncData.objNotifyIcon.Icon = $RunSpaceSyncData.Icon1
                        if($RunSpaceSyncData.DisableNotifications -eq $false){
                            $syncData.objNotifyIcon.BalloonTipText = "StarCitizen detected"
                            $syncData.objNotifyIcon.BalloonTipTitle = "Anti-Logoff"
                            $syncData.objNotifyIcon.ShowBalloonTip(3000)
                        }
                    }
                    $StarCitizenRunning = $true
                    #Write-Host "Star Citizen is running"
                }else{
                    if($StarCitizenRunning -ne $false){
                        #Trigger Notification only once until StarCitizen Windows got detected
                        $RunSpaceSyncData.objNotifyIcon.Icon = $RunSpaceSyncData.Icon2
                        if($RunSpaceSyncData.DisableNotifications -eq $false){
                            $syncData.objNotifyIcon.BalloonTipText = "StarCitizen is not running"
                            $syncData.objNotifyIcon.BalloonTipTitle = "Anti-Logoff"
                            $syncData.objNotifyIcon.ShowBalloonTip(3000)
                        }
                    }
                    $StarCitizenRunning = $false
                    #Write-Host "Star Citizen is not running"
                    continue #stop loop and startover
                }

                # Loop through and check key states
                for ($i = 1; $i -le 255; $i++) {
                    # Get the state of the key
                    #$keyState = [ClassLibrary1.KeyState]::IsKeyPressed($i) # out sourced dll, to prevent false positive of bitdefender, does currently detect no keystrokes at all
                    $keyState = [KeyboardMonitor]::GetAsyncKeyState($i)
                    
                    # Check if the high-order bit is set (which indicates the key is actually being pressed)
                    if (($keyState -band 0x8000) -ne 0) {
                        $key = [System.Windows.Forms.Keys]$i
                        $host.UI.WriteLine("[$(Get-Date -Format HH:mm:ss)] INFO - Keystroke detected:$cyan $key $reset")
                        $keystroke = $key
                        $global:activityDetected = $true
                        break
                    }
                }

                # Check for mouse movement
                $currentMousePosition = [System.Windows.Forms.Cursor]::Position
                if ($currentMousePosition -ne $lastMousePosition) {
                    $host.UI.WriteLine("[$(Get-Date -Format HH:mm:ss)] INFO -$cyan Mouse movement$reset detected!")
                    #$host.UI.WriteLine("[$(Get-Date -Format HH:mm:ss)] INFO - Old position: $lastMousePosition, New position: $currentMousePosition")
                    $lastMousePosition = $currentMousePosition
                    $keystroke = "Mouse"
                    $global:activityDetected = $true
                }
                
                #Detect if any keys were pressed and sent to StarCitizen
                if ($activityDetected) {
                    $HandleForKeystrokes = [User32]::GetForegroundWindow()
                    if ($StarCitizenHandle -eq $HandleForKeystrokes){
                        $keystrokesSentToSC = $true
                        $host.UI.WriteLine("[$(Get-Date -Format HH:mm:ss)] INFO -$green Activity$reset detected within StarCitizen")
         
                    }elseif($KeystrokesSentToSC -eq $null){
                        $keystrokesSentToSC = $false
                        #Write-Host "Keystrokes have NOT been sent to SC"
                    }
                }

                # Exit loop early if activity detected
                $global:activityDetected = $false
                Start-Sleep -Milliseconds 10
            }

            $host.UI.WriteLine("[$(Get-Date -Format HH:mm:ss)] INFO - LastKey: $keystroke, Sent to SC: $keystrokesSentToSC")

            if (-not $keystrokesSentToSC) {
                $KeystrokesSentToSC = $false
                $host.UI.WriteLine("[$(Get-Date -Format HH:mm:ss)] LOOP -$red No activity detected within the monitoring period$reset")
            }

            #if(($StarCitizenRunning -eq $true -AND $activityDetected -eq $false) -OR ($StarCitizenRunning -eq $true -AND ($keystrokesSentToSC -eq $false -OR $keystrokesSentToSC -eq $null))){
            if($StarCitizenRunning -and (-not $keystrokesSentToSC)) {
                $host.UI.WriteLine("[$(Get-Date -Format HH:mm:ss)] ACTION - Starting AntiLogoff Precedure")
                #Add a random delay to avoid beeing detected as automated keystroke


                #grab current focussed window
                $CurrentFocusWindow = [User32]::GetForegroundWindow()
                #msg * previous focus was set $PreviousFocus
                
                #play sound to indicate to user that antilogoff mechanism is going to start
                if($RunSpaceSyncData.DisableWarningMessage -eq $false){
                    $audio = New-Object System.speech.Synthesis.SpeechSynthesizer
                    $audio.selectVoice('Microsoft Zira Desktop')
                    $audio.rate = 0
                    $audiotext = "AntiLogoff in 5, 4, 3, 2, 1"
                    $audio.speak($audiotext)
                }

                #Detect if StarCitizen is focused
                if($StarCitizenRunning -eq $true){
                    if($CurrentFocusWindow -eq $StarCitizenProcess.id){
                        $StarCitizenFocussed = $true
                        $host.UI.WriteLine("[$(Get-Date -Format HH:mm:ss)] ACTION -$green Star Citizen is focussed$reset")
                    }else{
                        $StarCitizenFocussed = $false
                        $host.UI.WriteLine("[$(Get-Date -Format HH:mm:ss)] ACTION -$red Star Citizen is not focussed$reset")
                    }
                }

                #play sound to indicate to user that antilogoff mechanism is going to start

                #focus starcitizen
                if($StarCitizenFocussed -eq $false){
                    $host.UI.WriteLine("[$(Get-Date -Format HH:mm:ss)] ACTION - Focussing Star Citizen")
                    [User32]::SetForegroundWindow($StarCitizenHandle) | Out-Null
                    [User32]::ShowWindow($StarCitizenHandle,3) | Out-Null  
                    Start-Sleep -Milliseconds 500
                }

                #toggle chat twice with F12 / execute keystroke action
                #add randoms delays here for each sleep
                $MinimumDelay = 30
                $MaximumDelay = 60
                $randomDelay = Get-Random -Minimum $MinimumDelay -Maximum $MaximumDelay

                $RandomExecutionDelay = Get-Random -Minimum 1 -Maximum 99
                Start-Sleep -Milliseconds (300 + $RandomExecutionDelay)
                if($RunSpaceSyncData.DisableSounds -eq $false){[console]::beep(659,250)}
                #[console]::beep(587,125) #G
                [KeyboardEmulator2]::HoldKey(0x7B, 100)  # Press F12
                Start-Sleep -Milliseconds (400 + $RandomExecutionDelay/2)
                [KeyboardEmulator2]::HoldKey(0x7B, 100)  # Press F12
                #[console]::beep(659,250) #C
                if($RunSpaceSyncData.DisableSounds -eq $false){[console]::beep(587,250)}
                Start-Sleep -Milliseconds (300 + $RandomExecutionDelay)
                $host.UI.WriteLine("[$(Get-Date -Format HH:mm:ss)] ACTION - Keystrokes sent to SC")
                <#
                #CTRL + V
                [KeyboardEmulator2]::HoldKey(0x11, 100)  # Hold CTRL
                [KeyboardEmulator2]::HoldKey(0x56, 100)  # Press V
                [KeyboardEmulator2]::HoldKey(0x11, 100)  # Release CTRL
                #>

                #return focus to previous window if user was not in the game
                if($StarCitizenFocussed -eq $false -AND $PowerShellWindowHandle -ne $CurrentFocusWindow){
                    $host.UI.WriteLine("[$(Get-Date -Format HH:mm:ss)] ACTION -$green returning focus to previous window$reset")
                    [User32]::SetForegroundWindow($CurrentFocusWindow) | Out-Null 
                    #[User32]::ShowWindow($CurrentFocusWindow,3) | Out-Null 
                    #msg * returned focus $PreviousFocus
                }else{
                    #msg * focus not returned
                }

                W$host.UI.WriteLine("[$(Get-Date -Format HH:mm:ss)] ACTION - AntiLogoff Precedure complete")
            }
            if($keystrokesSentToSC){
                $host.UI.WriteLine("[$(Get-Date -Format HH:mm:ss)] LOOP - Activity detected in the past$cyan $MonitoringDurationForKeypresses$reset secs")
            }
            if(-not $StarCitizenRunning){
                $host.UI.WriteLine("[$(Get-Date -Format HH:mm:ss)] LOOP - StarCitizen is not running")
            }
            $keystrokesSentToSC = $false
            Start-Sleep -Seconds 1
        }else{Start-Sleep -Seconds 1}
    }
}
##########################################################################################################################

#Runspace 
$RunspaceOne = [runspacefactory]::CreateRunspace($host)                                          # Create runspace
$RunspaceOne.Name = "Antilogoff"                                                            # Set Runspace name (in case its not closed properly)
#$RunspaceHotkey.ApartmentState = "STA"                                                     # no idea anymore
#$RunspaceHotkey.ThreadOptions = "ReuseThread"                                              # no idea anymore
$RunspaceOne.Open()
$RunspaceOne.SessionStateProxy.SetVariable("RunSpaceSyncData", $RunSpaceSyncData)           # Synched Variable to communicate between backend script and runspace

$PSinstanceHotkey = [powershell]::Create().AddScript($AntiLogoff).AddArgument($RunSpaceSyncData)                           #Load Powershell Instance with content from function for execution in runspace
$PSinstanceHotkey.RunspacePool = $RunSpacePool                                              # Adds this runspace to a runspace pool, this makes closing all runspaces on program termination easier
$PSinstanceHotkey.Runspace = $RunspaceOne                                                   # Add runspace to powershell instance

$JobRunspaceOne = $PSinstanceHotkey.BeginInvoke()

#systray - left/rightclick menu to enable or disable the tool
$ContextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$RunSpaceSyncData.objNotifyIcon.ContextMenuStrip = $ContextMenu

$global:consoleVisible = $false
$windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
$asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
$consoleProcess = Get-Process -Id $pid
$consoleHandle = $consoleProcess.MainWindowHandle
$null = $asyncwindow::ShowWindowAsync($consoleHandle, 0)

$MenuItemData = New-Object System.Windows.Forms.ToolStripMenuItem
$MenuItemData.Text = 'Debug: NO'
$MenuItemData.Enabled = $true
$MenuItemData.Add_Click({
    if ($global:consoleVisible -eq $true) {
        # Hide the console
        $null = $asyncwindow::ShowWindowAsync($consoleHandle, 0)  # SW_HIDE = 0
        $global:consoleVisible = $false
        $MenuItemData.Text ="Debug: NO"
    } else {
        # Show the console
        $null = $asyncwindow::ShowWindowAsync($consoleHandle, 5)  # SW_SHOW = 5
        $null = $asyncwindow::ShowWindowAsync($consoleHandle, 9)
        $global:consoleVisible = $true
        $MenuItemData.Text ="Debug: YES"
    }
})
$RunSpaceSyncData.objNotifyIcon.ContextMenuStrip.Items.AddRange($MenuItemData)

$MenuItemMonitor = New-Object System.Windows.Forms.ToolStripMenuItem
$MenuItemMonitor.Text = 'Monitor'
$MenuItemMonitor.Enabled = $true
$MenuItemMonitor.add_Click({
    $MenuItemSuspend.Enabled = $true             #Enable Suspend in Menu
    $MenuItemMonitor.Enabled = $false            #Disable Monitor in menu
    $RunSpaceSyncData.AntiloggoffActive = $true 
    $RunSpaceSyncData.objNotifyIcon.Icon = $RunSpaceSyncData.Icon1

    #Start-Threadjob -ScriptBlock $AntiLogoff -Name "mainscript" -StreamingHost $Host -InputObject $objNotifyIcon -ArgumentList @($MyHash)
      
})
$RunSpaceSyncData.objNotifyIcon.ContextMenuStrip.Items.AddRange($MenuItemMonitor)

$MenuItemSuspend = New-Object System.Windows.Forms.ToolStripMenuItem
$MenuItemSuspend.Text = 'Suspend'
$MenuItemSuspend.Enabled = $false
$MenuItemSuspend.add_Click({
    $MenuItemSuspend.Enabled = $false
    $MenuItemMonitor.Enabled = $true
    $RunSpaceSyncData.AntiloggoffActive = $false 
    $RunSpaceSyncData.objNotifyIcon.Icon = $RunSpaceSyncData.Icon3
})
$RunSpaceSyncData.objNotifyIcon.ContextMenuStrip.Items.AddRange($MenuItemSuspend)

$MenuItemExit = New-Object System.Windows.Forms.ToolStripMenuItem
$MenuItemExit.Text = 'E&xit'
$MenuItemExit.add_Click({
    try{$pipeHandle.Close()}catch{}

    $RunSpaceSyncData.AntiloggoffActive = $false 
    #Stop Runspace
    $PSinstanceHotkey.RunSpace.Dispose()     
    $PSinstanceHotkey.Dispose() 

    $RunSpaceSyncData.objNotifyIcon.Visible = $False  
    $RunSpaceSyncData.objNotifyIcon.Dispose()

    $appContext.ExitThread()
    Stop-Process $pid
})
$RunSpaceSyncData.objNotifyIcon.ContextMenuStrip.Items.AddRange($MenuItemExit)

$RunSpaceSyncData.objNotifyIcon.Visible = $True

###############


# Make PowerShell Disappear
#$windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
#$asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
#$null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0) 

# Force garbage collection just to start slightly lower RAM usage.
#[System.GC]::Collect()

# Create an application context for processing WinForms GUI events.
$appContext = New-Object System.Windows.Forms.ApplicationContext

# Synchronously start a WinForms event loop for the application context.
# This call will block until the Exit context-menu item is invoked.
$null = [System.Windows.Forms.Application]::Run($appContext)
