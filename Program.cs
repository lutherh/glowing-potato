using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading;
namespace AntiLogoffConsoleApp
{
    class Program
    {
        static bool disableWarningMessage = false;
        static bool disableSounds = false;
        static bool disableNotifications = false;

        static void Main(string[] args)
        {
            // Load settings from config file
            LoadSettings();

            // Create named pipe server
            CreateNamedPipeServer();

            // Extract icons from DLL
            ExtractIcons();

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

        static void CreateNamedPipeServer()
        {
            // Implement named pipe server logic here
        }

        static void ExtractIcons()
        {
            // Implement icon extraction logic here
        }

        static void AntiLogoff()
        {
            var monitoringDuration = 500; // 500 seconds
            var minDelayLoop = 1;
            var maxDelayLoop = 30;

            Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] LOOP - Anti-Logoff started with monitoring duration: {monitoringDuration} secs");

            while (true)
            {
                // Starting Parameters
                bool? starCitizenRunning = null;
                bool? starCitizenFocussed = null;
                Process starCitizenProcess = null;
                bool? keystrokesSentToSC = null;
                string keystroke = null;

                var endTime = DateTime.Now.AddSeconds(monitoringDuration + new Random().Next(minDelayLoop, maxDelayLoop));
                Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] INFO - total cycle duration: {monitoringDuration + new Random().Next(minDelayLoop, maxDelayLoop)} secs (randomized)");

                var lastMousePosition = Cursor.Position;
                bool activityDetected = false;

                while (DateTime.Now < endTime)
                {
                    // Detect if Star Citizen is running
                    starCitizenProcess = Process.GetProcessesByName("StarCitizen").FirstOrDefault();
                    if (starCitizenProcess != null)
                    {
                        if (starCitizenRunning != true)
                        {
                            // Trigger notification only once until StarCitizen window is detected
                            Console.WriteLine("StarCitizen detected");
                        }
                        starCitizenRunning = true;
                    }
                    else
                    {
                        if (starCitizenRunning != false)
                        {
                            // Trigger notification only once until StarCitizen window is detected
                            Console.WriteLine("StarCitizen is not running");
                        }
                        starCitizenRunning = false;
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
                    if (currentMousePosition != lastMousePosition)
                    {
                        Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] INFO - Mouse movement detected!");
                        lastMousePosition = currentMousePosition;
                        keystroke = "Mouse";
                        activityDetected = true;
                    }

                    // Detect if any keys were pressed and sent to Star Citizen
                    if (activityDetected)
                    {
                        IntPtr handleForKeystrokes = GetForegroundWindow();
                        if (starCitizenProcess.MainWindowHandle == handleForKeystrokes)
                        {
                            keystrokesSentToSC = true;
                            Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] INFO - Activity detected within StarCitizen");
                        }
                        else if (keystrokesSentToSC == null)
                        {
                            keystrokesSentToSC = false;
                        }
                    }

                    // Exit loop early if activity detected
                    activityDetected = false;
                    Thread.Sleep(10);
                }

                Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] INFO - LastKey: {keystroke}, Sent to SC: {keystrokesSentToSC}");

                if (keystrokesSentToSC != true)
                {
                    keystrokesSentToSC = false;
                    Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] LOOP - No activity detected within the monitoring period");
                }

                if (starCitizenRunning == true && keystrokesSentToSC != true)
                {
                    Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] ACTION - Starting AntiLogoff Procedure");

                    // Play sound to indicate to user that antilogoff mechanism is going to start
                    if (!disableWarningMessage)
                    {
                        Console.WriteLine("___StartingAntiLogoff___");
                    }

                    // Focus Star Citizen
                    if (starCitizenFocussed != true)
                    {
                        Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] ACTION - Focusing Star Citizen");
                        SetForegroundWindow(starCitizenProcess.MainWindowHandle);
                        ShowWindow(starCitizenProcess.MainWindowHandle, 3);
                        Thread.Sleep(500);
                    }

                    // Send keystrokes to Star Citizen
                    var randomDelay = new Random().Next(30, 60);
                    Thread.Sleep(300 + randomDelay);
                    if (!disableSounds) Console.Beep(659, 250);
                    HoldKey(0x7B, 100); // Press F12
                    Thread.Sleep(400 + randomDelay / 2);
                    HoldKey(0x7B, 100); // Press F12
                    if (!disableSounds) Console.Beep(587, 250);
                    Thread.Sleep(300 + randomDelay);

                    Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] ACTION - Keystrokes sent to SC");
                }

                if (keystrokesSentToSC == true)
                {
                    Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] LOOP - Activity detected in the past {monitoringDuration} secs");
                }
                if (starCitizenRunning != true)
                {
                    Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] LOOP - StarCitizen is not running");
                }
                keystrokesSentToSC = false;
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
        }

        [DllImport("user32.dll", SetLastError = true)]
        private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);

        [DllImport("user32.dll")]
        private static extern byte MapVirtualKey(uint uCode, uint uMapType);
    }
}
