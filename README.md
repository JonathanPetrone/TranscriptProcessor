# TranscriptProcessor

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
