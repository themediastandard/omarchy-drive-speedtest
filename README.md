# Drive Speed Test for Omarchy

A compact Omarchy bar widget for measuring practical read and write performance on mounted local disks and network shares.

Created by [The Media Standard](https://themediastandard.com/).

Click the disk icon in the bar, choose a drive, and watch the result update in MB/s. The plugin discovers local block devices as well as mounted CIFS/SMB, NFS, SSHFS, WebDAV, and Files/GVFS shares.

## Features

- Drive picker integrated into the Omarchy top bar
- Sequential read and write results in MB/s
- Local disks, removable storage, and mounted network shares
- Individual discovery of shares connected through Files/GVFS
- Keyboard navigation with arrow keys or `j`/`k`, Enter to test, `r` to refresh, and Escape to close
- Automatic cleanup when a test completes, fails, or is cancelled
- Theme-aware Quickshell interface with no background service or telemetry

## Requirements

- Omarchy Quattro with shell plugin support
- Omarchy's `omarchy-disk-speedtest` command for local-disk testing
- Standard Omarchy command-line tools: Bash, `jq`, `findmnt`, `lsblk`, `df`, `dd`, `awk`, `sed`, and `find`
- A mounted, writable target with enough free space

The plugin does not mount drives or request credentials. Connect removable or network drives in Files before opening the picker.

## Installation

Install and enable the plugin from its public GitHub repository:

```bash
omarchy plugin add https://github.com/themediastandard/omarchy-drive-speedtest.git --enable
```

The manifest requests the right side of the bar by default. You can move it later using Omarchy's normal bar controls.

## Usage

1. Click the disk icon in the Omarchy bar.
2. Select a mounted drive or network share.
3. Wait for both measurements to finish.

Use the refresh button after connecting a new drive. Closing the panel cancels the active test and removes its temporary files.

## What the tests do

### Local drives

Local tests use Omarchy's built-in direct-I/O benchmark. It creates four temporary 256 MB files, for approximately 1 GB total, and requires at least 2 GB free as a safety margin. The read and write phases take roughly 20 seconds altogether.

### Network shares

Network tests transfer one temporary 256 MB incompressible file. They require at least 512 MB free as a safety margin and request cache eviction before the read phase when the remote filesystem supports it.

A network result measures the complete path between the workstation and share, including the client, network, protocol, NAS, and storage. It is practical transfer performance rather than an isolated server-disk benchmark.

## Safety and privacy

- Test filenames are randomly generated and hidden.
- Existing files are never selected or overwritten.
- Cleanup is registered before transfer work begins and runs on normal completion, errors, and cancellation.
- The plugin makes no web requests and collects no analytics.
- Network testing writes only to the share explicitly selected by the user.
- Like all Omarchy shell plugins, this code runs unsandboxed as the current user. Review third-party plugin code before enabling it.

## Removal

Remove the plugin through Omarchy:

```bash
omarchy plugin remove themediastandard.drive-speedtest
```

Removal deletes the plugin checkout and its bar entry. It does not unmount drives or alter files on tested storage. Test files are removed at the end of each run rather than retained as plugin data.

## Development

Validate a checkout with the same manifest checks used by Omarchy:

```bash
omarchy plugin validate .
```

The plugin consists of a QML bar widget and two Bash helpers. No build step is required.

## License

[MIT](LICENSE)
