# XWorm C2 — Pre-Auth RCE (v3.0–v7.4)

Four-bug chain against the XWorm C2 Panel. 0click RCE.
Tested across v3.0 through v7.4, covering both XOR-era and AES-era protocol variants.

Full writeup: Coming Soon

---

A Python exploit that walks an unauthenticated TCP peer through four packets and ends up running arbitrary code inside the C2 panel process.

The four bugs, in chain order:

1. **No client authentication** — `INFO` opcode accepts any TCP peer.
2. **Auto-opening UI forms** — `FileM` and `Compiler` opcodes call `new Form().Show()` from the receive path.
3. **Path traversal in `downloadedfile`** — the filter blocks `\` and `/` but not `..`. `Path.Combine` collapses the `..` to the panel root.
4. **Lazy-loaded DLL hijack** — `FastColoredTextBox.dll` is only loaded when the VBCode form opens. Overwrite it on disk first, then trigger the form.

## Usage

Build the payload DLL (Windows, requires .NET Framework SDK):

```bat
build.bat
```

Run the exploit (any OS, requires Python 3.8+):

```bash
pip install -r requirements.txt
python3 exploit.py <C2_IP> <C2_PORT> FastColoredTextBox.dll --zero-click \
    --key <BASE64_AES_KEY> --spl <BASE64_SPL> --mutex <MUTEX_VALUE>
```

The `--key`, `--spl`, and `--mutex` values are extractable from any compiled XWorm victim binary via dnSpy / ILSpy. The mutex is used by the exploit to derive the AES config key via the same overlapping-MD5 KDF the XWorm builder uses.

## Disclaimer/Legal
This repository contains a proof-of-concept (PoC) for educational and security research purposes only.
Intended Use:

- Academic research and learning
- Threat intelligence analysis
- Security awareness and defensive research
- Understanding adversary infrastructure weaknesses

Important Notice:

This PoC is provided for educational purposes only
Unauthorized access to computer systems is illegal
Users are responsible for ensuring their use complies with all applicable laws and regulations
The author assumes no liability for misuse of this information
This research targets known malicious infrastructure and is not intended for use against legitimate systems

Responsible Use:
By using this code, you agree to use it solely for lawful security research, education, and defensive purposes. Any malicious or unauthorized use is strictly prohibited and violates the intended purpose of this research.
