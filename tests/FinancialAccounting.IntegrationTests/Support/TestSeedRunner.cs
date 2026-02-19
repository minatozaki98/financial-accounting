using System.Diagnostics;

namespace FinancialAccounting.IntegrationTests.Support;

public static class TestSeedRunner
{
    public static int RunScript(string repoRoot, int periodId = 202601, int accountCount = 120, int journalEntryCount = 30000, int minimumPostedEntries = 5000)
    {
        var scriptPath = Path.Combine(repoRoot, "scripts", "phase4", "seed-test-data.ps1");
        if (!File.Exists(scriptPath))
        {
            throw new FileNotFoundException("Seed script not found.", scriptPath);
        }

        var arguments = $"-NoProfile -ExecutionPolicy Bypass -File \"{scriptPath}\" -PeriodId {periodId} -AccountCount {accountCount} -JournalEntryCount {journalEntryCount} -MinimumPostedEntries {minimumPostedEntries}";
        var startInfo = new ProcessStartInfo
        {
            FileName = "powershell",
            Arguments = arguments,
            WorkingDirectory = repoRoot,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        using var process = Process.Start(startInfo) ?? throw new InvalidOperationException("Failed to start seed process.");
        process.WaitForExit();
        return process.ExitCode;
    }
}
