' Hidden launcher for the Health Command Center daily refresh (scheduled task).
' The task used to start pwsh.exe directly, which showed a console window every morning.
' 0 = hidden, True = wait; WScript.Quit hands daily-refresh.ps1's exit code to the task.
' Arguments after the script path (-GarminRoot ... -PythonPath ...) are passed through.
Dim shell, here, cmd, i
Set shell = CreateObject("WScript.Shell")
here = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
cmd = """" & shell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Microsoft\WindowsApps\pwsh.exe"" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File """ & here & "\daily-refresh.ps1"""
For i = 0 To WScript.Arguments.Count - 1
    cmd = cmd & " """ & WScript.Arguments(i) & """"
Next
WScript.Quit shell.Run(cmd, 0, True)
