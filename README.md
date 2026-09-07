# Emm Remote — MVP

Emm Remote is a consent-first remote desktop prototype for devices you own or
are explicitly authorized to support. It provides screen streaming, mouse and
keyboard control, clipboard exchange, and file transfer over WebRTC.

## Security model

- The host starts every session and displays a short-lived pairing code.
- The host must approve the controller after seeing its name and fingerprint.
- WebRTC protects media and data with DTLS-SRTP/SCTP encryption. A TURN relay,
  when configured, forwards ciphertext and cannot read session content.
- Pairing codes expire after five minutes and are consumed after approval.
- A persistent red session banner and an emergency **Stop session** button are
  shown on the host. Closing the agent ends control immediately.
- File writes are confined to the user-selected download directory.
- The signaling service stores no credentials, recordings, clipboard contents,
  or transferred files. It keeps only ephemeral session state in memory.
- There is no unattended access, hidden process, autostart, privilege elevation,
  or persistence in this MVP.

WebRTC transport encryption is end-to-end between the two peers. Identity is
confirmed out of band by comparing the fingerprint shown on both devices. For a
production deployment, add account/device public-key registration, signed SDP,
certificate pinning, rate limiting, audit retention controls, and an audited
TURN deployment before calling the system production-ready.

## Architecture

```text
Controller browser  <-- encrypted WebRTC media + data -->  Python host agent
        |                       (direct or TURN)                    |
        +---------- WebSocket signaling service ------------------+
                    (pairing + SDP/ICE only)
```

The `control` data channel carries bounded JSON events and clipboard messages.
The `files` data channel carries metadata plus 64 KiB binary chunks. Screen
frames use the WebRTC video track, allowing browser-native low-latency decoding.

## Repository

```text
apps/
  signal/          aiohttp signaling service and browser controller
  host/            visible Python desktop agent
tests/              protocol and security-boundary tests
docs/               architecture and phased delivery plan
```

## Run locally (Windows, macOS, or Linux)

Python 3.11+ is recommended.

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m apps.signal.server
```

In a second terminal:

```powershell
.venv\Scripts\Activate.ps1
python -m apps.host.agent --server ws://127.0.0.1:8765/ws
```

Open `http://127.0.0.1:8765`, enter the host's code, and approve the request on
the host. Browsers allow screen capture only in secure contexts; localhost is
accepted for development. Deploy behind TLS (`https`/`wss`) for Internet use.

On macOS, grant Screen Recording and Accessibility permission to Python. On
Linux/Wayland, global input injection is intentionally unavailable unless the
desktop portal grants it; X11 works through `pynput`.

## Build the Windows executable

Install Python 3.11 from python.org (including the `py` launcher), then run:

```powershell
.\build-windows.ps1
```

The portable application is created at `dist\EmmRemote\EmmRemote.exe`. Keep
the complete `EmmRemote` directory together; the one-folder build starts faster
and is easier to inspect than a self-extracting executable. It does not request
administrator rights. Windows SmartScreen may warn until releases are signed
with an Authenticode certificate.

Double-click the executable on both computers. On the host choose **Share this
computer**; on the other choose **Control another computer**, then enter the
host address and temporary code shown by Emm Remote. No browser is required.
Windows Firewall may ask whether to allow private-network access.

The executable reads `EMM_SIGNAL_URL` when no `--server` argument is supplied.
For example, a shortcut can target `EmmRemote.exe --server
wss://remote.example.com/ws`. Use only a TLS-protected signaling endpoint that
you operate and trust.

## Internet deployment

Put the signal service behind a TLS reverse proxy and configure a TURN server
(for example coturn) with short-lived credentials. Set `EMM_ICE_SERVERS` in the
host and matching ICE configuration in the controller. Never expose the local
development server directly to the Internet.

## Tests

```powershell
python -m unittest discover -s tests -v
```

