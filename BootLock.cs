using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

internal static class BootLock {
    [DllImport("ntdll.dll")]
    private static extern int NtQuerySystemInformation(int informationClass, IntPtr buffer, int size, out int returned);
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool LockWorkStation();

    private static int Main(string[] args) {
        string directory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "BootIdleLock");
        Directory.CreateDirectory(directory);
        string log = Path.Combine(directory, "boot-lock.log");
        try {
            IntPtr buffer = Marshal.AllocHGlobal(128);
            string boot;
            try {
                int returned;
                int status = NtQuerySystemInformation(3, buffer, 48, out returned);
                if (status < 0) throw new Exception("Boot identifier query failed: " + status);
                boot = Marshal.ReadInt64(buffer).ToString();
            } finally { Marshal.FreeHGlobal(buffer); }
            string marker = Path.Combine(directory, "locked-boot-time.txt");
            if (args.Length == 1 && args[0] == "--check") {
                File.AppendAllText(log, DateTime.Now.ToString("o") + " Check OK; boot=" + boot + Environment.NewLine);
                return 0;
            }
            if (File.Exists(marker) && File.ReadAllText(marker).Trim() == boot) return 0;
            for (int attempt = 0; attempt < 50; attempt++) {
                if (LockWorkStation()) {
                    File.WriteAllText(marker, boot);
                    File.AppendAllText(log, DateTime.Now.ToString("o") + " Lock accepted; boot=" + boot + Environment.NewLine);
                    return 0;
                }
                Thread.Sleep(100);
            }
            throw new Exception("Windows rejected the lock request.");
        } catch (Exception error) {
            File.AppendAllText(log, DateTime.Now.ToString("o") + " ERROR " + error + Environment.NewLine);
            return 1;
        }
    }
}


