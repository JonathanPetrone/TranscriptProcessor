# TranscriptProcessor

## Prerequisites

### Required Tools

1. **yt-dlp** - YouTube downloader
2. **jq** - JSON processor (for playlist handling)
3. **Standard Unix tools** - grep, sed, awk (included on macOS/Linux)

### Installation Commands

**macOS (using Homebrew):**

```bash
# Install Homebrew if you don't have it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install yt-dlp jq
```

**Ubuntu/Debian Linux:**

```bash
sudo apt update
sudo apt install yt-dlp jq
```

**Other Linux distributions:**

```bash
# Install yt-dlp via pip
pip install yt-dlp

# Install jq (varies by distro)
# Fedora: sudo dnf install jq
# Arch: sudo pacman -S jq
# CentOS: sudo yum install jq
```

## Installation

### Step 1: Download the Script

Save the batch processor script to a file called `youtube-transcripts.sh`:

```bash
# Create the script file
touch ~/youtube-transcripts.sh
chmod +x ~/youtube-transcripts.sh

# Copy the script content into the file using your preferred editor
# (The script content is provided in the previous artifact)
```

### Step 2: Add to Your Shell

**For Zsh (default on macOS):**

```bash
# Add to your .zshrc
echo "source ~/youtube-transcripts.sh" >> ~/.zshrc

# Reload your shell
source ~/.zshrc
```

**For Bash:**

```bash
# Add to your .bashrc or .bash_profile
echo "source ~/youtube-transcripts.sh" >> ~/.bashrc

# Reload your shell
source ~/.bashrc
```

### Step 3: Verify Installation

```bash
# Test that commands are available
batch-transcripts
# Should show usage information

## Commands:
 
### Single Video Processing

bash

```bash
process-single-video <youtube-url> [output-dir]
```

**What it does:** Downloads and cleans transcript for one video  
**Example:** `process-single-video "https://youtube.com/watch?v=ABC123" transcripts`

### Batch Processing from URL File

bash

```bash
batch-transcripts <url-file> [output-dir]
```

**What it does:** Processes multiple URLs from a text file  
**Example:** `batch-transcripts my_videos.txt transcripts`

### Playlist/Channel Processing

bash

```bash
process-playlist <playlist/channel-url> [output-dir] [max-videos]
```

**What it does:** Downloads transcripts from entire playlist or channel  
**Examples:**

- `process-playlist "https://youtube.com/playlist?list=PLxxx" transcripts 20`
- `process-playlist "https://youtube.com/@channelname" transcripts 15`

### Recent Channel Videos

bash

```bash
process-channel-recent <channel-url> [days-back] [output-dir]
```

**What it does:** Gets transcripts from recent videos (last X days)  
**Example:** `process-channel-recent "https://youtube.com/@channelname" 30 transcripts`

## Other Utility Commands

### Create URL File

bash

```bash
create-url-file [filename]
```

**What it does:** Interactive creation of URL list file  
**Example:** `create-url-file my_videos.txt`

### Clean Existing VTT Files

bash

```bash
batch-clean-vtt <input-dir> [output-dir]
clean-all-here                              # Clean VTTs in current directory
batch-clean-vtt-preserve <input-dir> [output-dir]  # Preserve folder structure
```

## Quick Start Workflows

### For Individual Videos

1. `create-url-file my_videos.txt` (add URLs interactively)
2. `batch-transcripts my_videos.txt transcripts`

### For Playlists/Channels

- **Small playlist:** `process-playlist "playlist-url" transcripts 10`
- **Recent videos:** `process-channel-recent "channel-url" 7 transcripts`
- **Large batch:** `batch-download-vtt urls.txt vtt_files` → `batch-clean-vtt vtt_files transcripts`

## File Formats

- **Input:** YouTube URLs (videos, playlists, channels)
- **Output:** Clean `.txt` files with video title and ID in filename
- **Intermediate:** `.vtt` subtitle files (auto-removed unless using two-step workflow)

## Default Locations

- **Output directory:** `transcripts` (if not specified)
- **Max videos:** 50 (for playlists/channels)
- **Days back:** 30 (for recent videos)
