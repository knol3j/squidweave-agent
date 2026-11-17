# SQUIDWEAVE provider agent

Open-source scripts that let you rent out an idle **NVIDIA GPU** on [SQUIDWEAVE](https://gputestnet.squidweave.com/testnet?src=github), a peer-to-peer GPU marketplace that pays providers in **USDC on Base**. Renter payments sit in escrow until the job is done.

> **Testnet is open.** We're looking for the first 20 provider nodes. The testnet runs on **Base Sepolia with free test USDC**: no real money, no wallet funding needed.
>
> **Join here:** https://gputestnet.squidweave.com/testnet?src=github

Every script here is short, plain, and has no dependencies, so you can read exactly what runs on your machine before you start it.

## What's in this repo

| File | What it does |
| --- | --- |
| `squidweave-verify.sh` / `.ps1` / `_verify.py` | **One-time hardware check.** Reads GPU name, VRAM, and UUID from `nvidia-smi`, plus CPU cores and RAM, and sends them once so your listing shows verified specs. |
| `squidweave-agent.sh` / `.ps1` / `_agent.py` | **Heartbeat agent.** Every 60 seconds it sends GPU utilization and temperature so renters can see the machine is online. |

What the scripts **do not** do: they don't open ports, install anything, read your files, or send anything other than the fields above. Check the source yourself.

## Requirements

- An **NVIDIA GPU** with the driver installed (`nvidia-smi` must work). AMD and Apple GPUs aren't supported yet.
- One of: bash + curl (Linux/macOS), PowerShell 5+ (Windows 10/11), or Python 3.8+.
- An always-on internet connection.

## Quick start

1. **Sign up** at https://gputestnet.squidweave.com/testnet?src=github and connect a wallet (any Base wallet works; testnet uses test USDC).
2. In the **Provider** page, add a machine. You'll get a **scan code** and a **machine key**.
3. **Verify the hardware.** Download the verify script for your system, replace `PASTE_YOUR_SCAN_CODE`, and run it:

   ```bash
   bash squidweave-verify.sh                                   # Linux / macOS
   powershell -ExecutionPolicy Bypass -File .\squidweave-verify.ps1   # Windows
   python3 squidweave_verify.py                                # any OS
   ```

4. **Start the agent.** Replace `PASTE_YOUR_MACHINE_KEY` in the agent script and run it:

   ```bash
   chmod +x squidweave-agent.sh && ./squidweave-agent.sh       # Linux / macOS
   powershell -ExecutionPolicy Bypass -File .\squidweave-agent.ps1    # Windows
   python3 squidweave_agent.py                                 # any OS
   ```

5. Set your hourly price on the website. Your node shows as **live** on the marketplace.

### Keep it running on Linux (optional)

```ini
# /etc/systemd/system/squidweave-agent.service
[Unit]
Description=SQUIDWEAVE agent
After=network-online.target

[Service]
ExecStart=/opt/squidweave/squidweave-agent.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable --now squidweave-agent
```

## Security notes

- Your **machine key** identifies only this machine. Treat it like a password and don't commit it anywhere. You can revoke it from the Provider page at any time.
- The **scan code** is single-use and expires.
- All traffic goes over HTTPS to the SQUIDWEAVE backend (`impressive-orca-501.convex.site`).

## Feedback

Testnet testers shape the product. Open an issue here, or use the feedback button inside the app. Bug reports, pricing opinions, and "this step confused me" are all useful.

## License

MIT
