#!/bin/bash

# Batch YouTube Transcript Processor
# Usage: batch-transcripts urls.txt [output_dir]

batch-transcripts() {
    local url_file="$1"
    local output_dir="${2:-transcripts}"

    if [ -z "$url_file" ]; then
        echo "Usage: batch-transcripts <url-file> [output-dir]"
        echo "  url-file: Text file containing YouTube URLs (one per line)"
        echo "  output-dir: Directory to save transcripts (default: transcripts)"
        return 1
    fi

    if [ ! -f "$url_file" ]; then
        echo "Error: URL file '$url_file' not found"
        return 1
    fi

    mkdir -p "$output_dir"

    echo "Processing YouTube URLs from: $url_file"
    echo "Output directory: $output_dir"
    echo "----------------------------------------"

    local count=0
    local total=$(grep -cv '^[[:space:]]*$' "$url_file")

    while IFS= read -r url; do
        # Skip empty lines and comments
        [[ -z "$url" || "$url" =~ ^[[:space:]]*# ]] && continue

        count=$((count + 1))
        echo "[$count/$total] Processing: $url"

        # Get video ID robustly with yt-dlp
        local video_id
        video_id=$(yt-dlp --get-id "$url" 2>/dev/null)
        if [ -z "$video_id" ]; then
            echo "  ✗ Could not extract video ID, skipping..."
            continue
        fi
        echo "  Video ID: $video_id"

        # Download subtitle with video ID in filename
        local temp_file="${output_dir}/temp_${video_id}.%(ext)s"

        echo "  Downloading subtitle..."
        if yt-dlp --write-auto-subs --sub-langs en --skip-download --sub-format vtt -o "$temp_file" "$url" 2>/dev/null; then

            local vtt_file="${output_dir}/temp_${video_id}.en.vtt"

            if [ -f "$vtt_file" ]; then
                # Get video title for filename
                local title
                title=$(yt-dlp --get-title "$url" 2>/dev/null | tr -d '\n' | sed 's/[^a-zA-Z0-9 ]//g' | sed 's/  */ /g' | cut -c1-50)
                if [ -z "$title" ]; then
                    title="Unknown_Title"
                fi
                local clean_filename="${title// /_}_${video_id}.txt"
                local output_file="${output_dir}/${clean_filename}"

                echo "  Cleaning transcript..."
                clean-vtt-auto "$vtt_file" "$output_file"

                rm -f "$vtt_file"
                echo "  ✓ Saved: $clean_filename"
            else
                echo "  ✗ No subtitle file found for this video"
            fi
        else
            echo "  ✗ Failed to download subtitle"
        fi

        echo ""
    done < "$url_file"

    echo "Batch processing complete!"
    echo "Transcripts saved in: $output_dir"
}


# Enhanced clean-vtt function that auto-generates output filename
clean-vtt-auto() {
    local input="$1"
    local output="$2"
    
    if [ -z "$input" ]; then
        echo "Usage: clean-vtt-auto <vtt-file> [output-file]"
        return 1
    fi
    
    # Auto-generate output filename if not provided
    if [ -z "$output" ]; then
        output="${input%.*}.txt"
    fi
    
    # Remove VTT formatting and deduplicate lines
    grep -v "^WEBVTT" "$input" | \
    grep -v "^Kind:" | \
    grep -v "^Language:" | \
    grep -v "^$" | \
    grep -v "^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]" | \
    grep -v "align:start" | \
    sed 's/<[^>]*>//g' | \
    sed '/^$/d' | \
    awk '!seen[$0]++' > "$output"
    
    echo "Cleaned transcript saved to: $output"
}

# Single video processor with improved naming
process-single-video() {
    local url="$1"
    local output_dir="${2:-transcripts}"

    if [ -z "$url" ]; then
        echo "Usage: process-single-video <youtube-url> [output-dir]"
        return 1
    fi

    mkdir -p "$output_dir"

    local video_id
    video_id=$(yt-dlp --get-id "$url" 2>/dev/null)
    if [ -z "$video_id" ]; then
        video_id="unknown_$(date +%s)"
    fi

    local title
    title=$(yt-dlp --get-title "$url" 2>/dev/null | tr -d '\n' | sed 's/[^a-zA-Z0-9 ]//g' | sed 's/  */ /g' | cut -c1-50)
    title="${title// /_}"
    local clean_filename="${title}_${video_id}.txt"

    local temp_file="${output_dir}/temp_${video_id}.%(ext)s"

    echo "Processing: $url"
    echo "Title: $title"
    echo "Video ID: $video_id"

    if yt-dlp --write-auto-subs --sub-langs en --skip-download --sub-format vtt -o "$temp_file" "$url" 2>/dev/null; then
        local vtt_file="${output_dir}/temp_${video_id}.en.vtt"

        if [ -f "$vtt_file" ]; then
            clean-vtt-auto "$vtt_file" "${output_dir}/${clean_filename}"
            rm -f "$vtt_file"
            echo "✓ Saved: $clean_filename"
        else
            echo "✗ No subtitle file found"
        fi
    else
        echo "✗ Failed to download subtitle"
    fi
}


# Process entire playlist or channel
process-playlist() {
    local url="$1"
    local output_dir="${2:-transcripts}"
    local max_videos="${3:-50}"  # Default limit to prevent huge downloads
    
    if [ -z "$url" ]; then
        echo "Usage: process-playlist <playlist/channel-url> [output-dir] [max-videos]"
        echo "Examples:"
        echo "  process-playlist 'https://youtube.com/playlist?list=PLxxx' transcripts 20"
        echo "  process-playlist 'https://youtube.com/@channelname' transcripts 10"
        return 1
    fi
    
    mkdir -p "$output_dir"
    
    echo "Processing playlist/channel: $url"
    echo "Max videos: $max_videos"
    echo "Output directory: $output_dir"
    echo "----------------------------------------"
    
    # Get list of video URLs from playlist/channel
    local video_urls_file="${output_dir}/temp_playlist_urls.txt"
    
    echo "Getting video list..."
    yt-dlp --flat-playlist --get-id --playlist-end "$max_videos" "$url" 2>/dev/null | \
    while IFS= read -r video_id; do
        # Handle both full URLs and video IDs
        if [[ "$video_id" =~ ^https?:// ]]; then
            echo "$video_id"
        else
            echo "https://youtube.com/watch?v=$video_id"
        fi
    done > "$video_urls_file"
    
    if [ ! -s "$video_urls_file" ]; then
        echo "No videos found or error occurred"
        rm -f "$video_urls_file"
        return 1
    fi
    
    local video_count=$(wc -l < "$video_urls_file")
    echo "Found $video_count videos"
    echo ""
    
    # Process each video
    batch-transcripts "$video_urls_file" "$output_dir"
    
    # Clean up temp file
    rm -f "$video_urls_file"
}

# Process channel with date filtering
process-channel-recent() {
    local channel_url="$1"
    local days_back="${2:-30}"
    local output_dir="${3:-transcripts}"
    
    if [ -z "$channel_url" ]; then
        echo "Usage: process-channel-recent <channel-url> [days-back] [output-dir]"
        echo "Example: process-channel-recent 'https://youtube.com/@channelname' 30 transcripts"
        return 1
    fi
    
    local date_after=$(date -v-"${days_back}d" +%Y%m%d)
    
    echo "Processing channel: $channel_url"
    echo "Videos from last $days_back days (after $date_after)"
    
    mkdir -p "$output_dir"
    
    # Get recent videos
    local video_urls_file="${output_dir}/temp_recent_urls.txt"
    
    yt-dlp --flat-playlist --print-json --dateafter "$date_after" "$channel_url" 2>/dev/null | \
    jq -r 'select(.url != null) | .url' | \
    while IFS= read -r video_id; do
        # Handle both full URLs and video IDs
        if [[ "$video_id" =~ ^https?:// ]]; then
            echo "$video_id"
        else
            echo "https://youtube.com/watch?v=$video_id"
        fi
    done > "$video_urls_file"
    
    if [ ! -s "$video_urls_file" ]; then
        echo "No recent videos found"
        rm -f "$video_urls_file"
        return 1
    fi
    
    local video_count=$(wc -l < "$video_urls_file")
    echo "Found $video_count recent videos"
    echo ""
    
    batch-transcripts "$video_urls_file" "$output_dir"
    rm -f "$video_urls_file"
}

# Quick function to create URL file from clipboard or manual input
create-url-file() {
    local filename="${1:-video_urls.txt}"
    
    echo "Creating URL file: $filename"
    echo "Enter YouTube URLs (one per line). Press Ctrl+D when finished:"
    echo "# YouTube URLs for batch processing" > "$filename"
    echo "# Add your URLs below (one per line)" >> "$filename"
    echo "# Supports individual videos, playlists, and channels" >> "$filename"
    echo "" >> "$filename"
    
    while IFS= read -r line; do
        echo "$line" >> "$filename"
    done
    
    echo "URL file created: $filename"
}

echo "Batch YouTube Transcript Processor loaded!"
echo ""
echo "Available commands:"
echo "  batch-transcripts <url-file> [output-dir]     - Process multiple URLs from file"
echo "  process-single-video <url> [output-dir]       - Process single video"
echo "  process-playlist <playlist-url> [output-dir] [max-videos] - Process entire playlist/channel"
echo "  process-channel-recent <channel-url> [days-back] [output-dir] - Process recent channel videos"
echo "  clean-vtt-auto <vtt-file> [output-file]       - Clean VTT with auto-naming"
echo "  create-url-file [filename]                    - Create URL file interactively"
echo ""
echo "Example usage:"
echo "  # Individual videos"
echo "  create-url-file my_videos.txt"
echo "  batch-transcripts my_videos.txt transcripts"
echo ""
echo "  # Playlists and channels"
echo "  process-playlist 'https://youtube.com/playlist?list=PLxxx' transcripts 20"
echo "  process-playlist 'https://youtube.com/@channelname' transcripts 15"
echo "  process-channel-recent 'https://youtube.com/@channelname' 30 transcripts"

# Clean all VTT files in a directory
batch-clean-vtt() {
    local input_dir="${1:-.}"
    local output_dir="${2:-cleaned_transcripts}"
    
    if [ ! -d "$input_dir" ]; then
        echo "Error: Input directory '$input_dir' not found"
        return 1
    fi
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Find all .vtt files
    local vtt_files=($(find "$input_dir" -name "*.vtt" -type f))
    
    if [ ${#vtt_files[@]} -eq 0 ]; then
        echo "No .vtt files found in '$input_dir'"
        return 1
    fi
    
    echo "Found ${#vtt_files[@]} VTT files to process"
    echo "Input directory: $input_dir"
    echo "Output directory: $output_dir"
    echo "----------------------------------------"
    
    local count=0
    local total=${#vtt_files[@]}
    
    for vtt_file in "${vtt_files[@]}"; do
        count=$((count + 1))
        
        # Get filename without path and extension
        local filename=$(basename "$vtt_file" .vtt)
        local output_file="$output_dir/${filename}.txt"
        
        echo "[$count/$total] Processing: $(basename "$vtt_file")"
        
        # Clean the VTT file
        if clean-vtt-silent "$vtt_file" "$output_file"; then
            echo "  ✓ Saved: ${filename}.txt"
        else
            echo "  ✗ Failed to process: $(basename "$vtt_file")"
        fi
    done
    
    echo ""
    echo "Batch cleaning complete!"
    echo "Processed $count files in: $output_dir"
}

# Silent version of clean-vtt for batch processing
clean-vtt-silent() {
    local input="$1"
    local output="$2"
    
    if [ -z "$input" ] || [ ! -f "$input" ]; then
        return 1
    fi
    
    # Auto-generate output filename if not provided
    if [ -z "$output" ]; then
        output="${input%.*}.txt"
    fi
    
    # Remove VTT formatting and deduplicate lines
    grep -v "^WEBVTT" "$input" | \
    grep -v "^Kind:" | \
    grep -v "^Language:" | \
    grep -v "^$" | \
    grep -v "^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]" | \
    grep -v "align:start" | \
    sed 's/<[^>]*>//g' | \
    sed '/^$/d' | \
    awk '!seen[$0]++' > "$output" 2>/dev/null
    
    return $?
}

# Clean VTT files in current directory (shortcut)
clean-all-here() {
    batch-clean-vtt . cleaned_transcripts
}

# Clean VTT files and keep directory structure
batch-clean-vtt-preserve() {
    local input_dir="${1:-.}"
    local output_dir="${2:-cleaned_transcripts}"
    
    if [ ! -d "$input_dir" ]; then
        echo "Error: Input directory '$input_dir' not found"
        return 1
    fi
    
    echo "Processing VTT files from: $input_dir"
    echo "Preserving directory structure in: $output_dir"
    echo "----------------------------------------"
    
    local count=0
    
    # Use find to process files while preserving directory structure
    while IFS= read -r -d '' vtt_file; do
        count=$((count + 1))
        
        # Get relative path from input directory
        local rel_path="${vtt_file#$input_dir/}"
        local rel_dir="$(dirname "$rel_path")"
        local filename="$(basename "$rel_path" .vtt)"
        
        # Create output directory structure
        mkdir -p "$output_dir/$rel_dir"
        
        local output_file="$output_dir/$rel_dir/${filename}.txt"
        
        echo "[$count] Processing: $rel_path"
        
        if clean-vtt-silent "$vtt_file" "$output_file"; then
            echo "  ✓ Saved: $rel_dir/${filename}.txt"
        else
            echo "  ✗ Failed: $rel_path"
        fi
        
    done < <(find "$input_dir" -name "*.vtt" -type f -print0)
    
    echo ""
    echo "Batch cleaning complete! Processed $count files."
}

# Download many subtitles as VTT only (no cleaning)
batch-download-vtt() {
    local url_file="$1"
    local output_dir="${2:-vtt_files}"
    
    if [ -z "$url_file" ]; then
        echo "Usage: batch-download-vtt <url-file> [output-dir]"
        echo "Downloads VTT files only (no cleaning) for later batch processing"
        return 1
    fi
    
    if [ ! -f "$url_file" ]; then
        echo "Error: URL file '$url_file' not found"
        return 1
    fi
    
    mkdir -p "$output_dir"
    
    echo "Downloading VTT files only from: $url_file"
    echo "Output directory: $output_dir"
    echo "----------------------------------------"
    
    local count=0
    local total=$(wc -l < "$url_file")
    
    while IFS= read -r url; do
        # Skip empty lines and comments
        [[ -z "$url" || "$url" =~ ^[[:space:]]*# ]] && continue
        
        count=$((count + 1))
        echo "[$count/$total] Downloading: $url"
        
        # Extract video ID for filename
        local video_id
        if [[ "$url" =~ youtube\.com/watch.*v=([a-zA-Z0-9_-]+) ]]; then
            video_id="${BASH_REMATCH[1]}"
        elif [[ "$url" =~ youtu\.be/([^?]+) ]]; then
            video_id="${BASH_REMATCH[1]}"
        elif [[ "$url" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            # Handle raw video IDs
            video_id="$url"
            url="https://youtube.com/watch?v=$url"
        else
            video_id="unknown_$(date +%s)"
        fi
        
        # Download only the VTT file
        local temp_file="${output_dir}/${video_id}.%(ext)s"
        
        if yt-dlp --write-auto-subs --sub-langs en --skip-download --sub-format vtt -o "$temp_file" "$url" 2>/dev/null; then
            echo "  ✓ Downloaded: ${video_id}.en.vtt"
        else
            echo "  ✗ Failed to download subtitle"
        fi
        
    done < "$url_file"
    
    echo ""
    echo "VTT download complete!"
    echo "Use 'batch-clean-vtt $output_dir cleaned_transcripts' to convert them to TXT"
}

echo ""
echo "Batch VTT cleaning functions added:"
echo "  batch-clean-vtt <input-dir> [output-dir]        - Clean all VTT files in directory"
echo "  clean-all-here                                  - Clean all VTT files in current directory"
echo "  batch-clean-vtt-preserve <input-dir> [output-dir] - Clean VTT files preserving folder structure"
echo "  batch-download-vtt <url-file> [output-dir]      - Download VTT files only (for later batch cleaning)"
echo ""
echo "Example workflow:"
echo "  1. batch-download-vtt urls.txt vtt_files        # Download many VTT files"
echo "  2. batch-clean-vtt vtt_files cleaned_transcripts # Convert all to TXT at once"