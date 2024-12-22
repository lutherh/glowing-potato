using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Input;

namespace AntiLogoffConsoleApp
{
    class Program
    {
        static bool disableWarningMessage = false;
        static bool disableSounds = false;
        static bool disableNotifications = false;

        static String gameName = "Game";
        public static class Mouse;
        public enum MouseAction;

        static void Main(string[] args)
        {
            // Load settings from config file
            LoadSettings();

            // Start AntiLogoff monitoring
            AntiLogoff();

            // Keep the console application running
            Console.ReadLine();
        }

        static void LoadSettings()
        {
            string configPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "settings.cfg");
            if (File.Exists(configPath))
            {
                foreach (var line in File.ReadAllLines(configPath))
                {
                    var parts = line.Split('=');
                    if (parts.Length == 2)
                    {
                        var key = parts[0].Trim();
                        var value = parts[1].Trim();
                        bool boolValue = value == "1";

                        switch (key)
                        {
                            case "DisableWarningMessage":
                                disableWarningMessage = boolValue;
                                break;
                            case "DisableSounds":
                                disableSounds = boolValue;
                                break;
                            case "DisableNotifications":
                                disableNotifications = boolValue;
                                break;
                        }
                    }
                }
            }
        }

        static void AntiLogoff()
        {
            var monitoringDuration = 2;
            var minDelayLoop = 1;
            var maxDelayLoop = 3;

            Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] LOOP - Anti-Logoff started with monitoring duration: {monitoringDuration} secs");

            while (true)
            {
                // Starting Parameters
                bool? GameIsRunning = null;
                bool? GameIsFocussed = null;
                Process GameProcess = null;
                bool? keystrokesSentToTheGame = null;
                string keystroke = null;

                var endTime = DateTime.Now.AddSeconds(monitoringDuration + new Random().Next(minDelayLoop, maxDelayLoop));
                Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] INFO - total cycle duration: {monitoringDuration + new Random().Next(minDelayLoop, maxDelayLoop)} secs (randomized)");

                


                var lastMousePosition = Mouse.Equals;
                bool activityDetected = false;

                String programName = "mspaint"; //"Freelancer";

                while (DateTime.Now < endTime)
                {
                    // Detect if the game is running
                    GameProcess = Process.GetProcessesByName(programName).FirstOrDefault();
                    if (GameProcess != null)
                    {
                        if (GameIsRunning != true)
                        {
                            // Trigger notification only once until game window is detected
                            Console.WriteLine(programName + " detected");
                        }
                        GameIsRunning = true;
                    }
                    else
                    {
                        if (GameIsRunning != false)
                        {
                            // Trigger notification only once until game window is detected
                            Console.WriteLine(programName + " is not running");
                        }
                        GameIsRunning = false;
                        continue; // Stop loop and start over
                    }

                    // Loop through and check key states
                    for (int i = 1; i <= 255; i++)
                    {
                        short keyState = GetAsyncKeyState(i);
                        if ((keyState & 0x8000) != 0)
                        {
                            keystroke = ((Keys)i).ToString();
                            Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] INFO - Keystroke detected: {keystroke}");
                            activityDetected = true;
                            break;
                        }
                    }

                    // Check for mouse movement
                    var currentMousePosition = Cursor.Position;
                    
                    if (currentMousePosition.Equals(lastMousePosition)) //if (currentMousePosition != lastMousePosition)
                    {
                        Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] INFO - Mouse movement detected!");
                        //lastMousePosition = currentMousePosition;
                        keystroke = "Mouse";
                        activityDetected = true;
                    }

                    // Detect if any keys were pressed and sent to The game
                    if (activityDetected)
                    {
                        IntPtr handleForKeystrokes = GetForegroundWindow();
                        if (GameProcess.MainWindowHandle == handleForKeystrokes)
                        {
                            keystrokesSentToTheGame = true;
                            Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] INFO - Activity detected within the application");
                        }
                        else if (keystrokesSentToTheGame == null)
                        {
                            keystrokesSentToTheGame = false;
                        }
                    }

                    // Exit loop early if activity detected
                    activityDetected = false;
                    Thread.Sleep(10);
                }

                Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] INFO - LastKey: {keystroke}, Sent to SC: {keystrokesSentToTheGame}");

                if (keystrokesSentToTheGame != true)
                {
                    keystrokesSentToTheGame = false;
                    Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] LOOP - No activity detected within the monitoring period");
                }

                if (GameIsRunning == true && keystrokesSentToTheGame != true)
                {
                    Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] ACTION - Starting AntiLogoff Procedure");

                    // Play sound to indicate to user that antilogoff mechanism is going to start
                    if (!disableWarningMessage)
                    {
                        Console.WriteLine("___StartingAntiLogoff___");
                    }

                    // Focus on the game
                    if (GameIsFocussed != true)
                    {
                        Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] ACTION - Focusing The game");
                        SetForegroundWindow(GameProcess.MainWindowHandle);
                        ShowWindow(GameProcess.MainWindowHandle, 3);
                        Thread.Sleep(100);
                    }

                    ClickMouse("fly", true); // left click

                    Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] ACTION - Keystrokes sent to the game");
                }

                if (keystrokesSentToTheGame == true)
                {
                    Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] LOOP - Activity detected in the past {monitoringDuration} secs");
                }
                if (GameIsRunning != true)
                {
                    Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] LOOP - Applicaation you are trying to automate is not running");
                }
                keystrokesSentToTheGame = false;
                Thread.Sleep(1);
            }
        }

        [DllImport("user32.dll")]
        private static extern short GetAsyncKeyState(int vKey);

        [DllImport("user32.dll")]
        private static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        private static void HoldKey(byte key, int duration)
        {
            const int KEYEVENTF_EXTENDEDKEY = 0x0001;
            const int KEYEVENTF_KEYUP = 0x0002;
            keybd_event(key, MapVirtualKey(key, 0), KEYEVENTF_EXTENDEDKEY, 0);
            Thread.Sleep(duration);
            keybd_event(key, MapVirtualKey(key, 0), KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, 0);
            PressKey("W"); // Press W
        }

        private static void HoldKeyArray(byte[] keys, int duration)
        {
            const int KEYEVENTF_EXTENDEDKEY = 0x0001;
            const int KEYEVENTF_KEYUP = 0x0002;

            foreach (var key in keys)
            {
                keybd_event(key, MapVirtualKey(key, 0), KEYEVENTF_EXTENDEDKEY, 0);
            }

            Thread.Sleep(duration);

            foreach (var key in keys)
            {
                keybd_event(key, MapVirtualKey(key, 0), KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, 0);
            }
        }

        private static void ClickMouse(string button, bool clickTopMiddle)
        {
            const int MOUSEEVENTF_LEFTDOWN = 0x02;
            const int MOUSEEVENTF_LEFTUP = 0x04;
            const int MOUSEEVENTF_RIGHTDOWN = 0x08;
            const int MOUSEEVENTF_RIGHTUP = 0x10;
            const int MOUSEEVENTF_MIDDLEDOWN = 0x20;
            const int MOUSEEVENTF_MIDDLEUP = 0x40;


            // Get screen dimensions
            int screenWidth = GetSystemMetrics(0);
            int screenHeight = GetSystemMetrics(1);

            if (clickTopMiddle)
            {
                // Set cursor position to top-middle of the screen
                SetCursorPos(screenWidth / 2, 0);
            }

            int curserPositionXMiddle = screenWidth / 2;
            int curserPositionYMiddle = screenHeight / 2;

            SetCursorPos(curserPositionXMiddle, curserPositionYMiddle);

            switch (button.ToLower())
            {
                case "left":
                    mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
                    Thread.Sleep(100);
                    mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
                    break;
                case "right":
                    mouse_event(MOUSEEVENTF_RIGHTDOWN, 0, 0, 0, 0);
                    Thread.Sleep(100);
                    mouse_event(MOUSEEVENTF_RIGHTUP, 0, 0, 0, 0);
                    break;
                case "middle":
                    mouse_event(MOUSEEVENTF_MIDDLEDOWN, 0, 0, 0, 0);
                    Thread.Sleep(100);
                    mouse_event(MOUSEEVENTF_MIDDLEUP, 0, 0, 0, 0);
                    break;
                case "fly":
                    mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
                    Thread.Sleep(100);
                    mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
                    break;
                default:
                    Console.WriteLine("Invalid button specified.");
                    break;
            }
        }

[DllImport("user32.dll", CharSet = CharSet.Auto, CallingConvention = CallingConvention.StdCall)]
private static extern bool SetCursorPos(int x, int y);

[DllImport("user32.dll")]
private static extern int GetSystemMetrics(int nIndex);

        private static void PressKey(string key)
        {
            SendKeys.SendWait(key);
        }

        [DllImport("user32.dll", SetLastError = true)]
        private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);

        [DllImport("user32.dll")]
        private static extern byte MapVirtualKey(uint uCode, uint uMapType);

        [DllImport("user32.dll", CharSet = CharSet.Auto, CallingConvention = CallingConvention.StdCall)]
        private static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
        
    }

    
}
