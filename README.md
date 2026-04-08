# TigerReddit

A complete rewrite in Native-C, that's dependency free! Features a nice simple GUI that lets you quickly load browse reddit much faster than you can do with any web browser. Just punch in a subreddit it'll instantly pull the text and load the images ASAP. Each post is double clickable. 

Preferences allow you to set the amount of comments, and there's even basic video support using Mplayer so you can surf and watch videos on Reddit. Currently, this only a reader thus doesn't have the ability to post, or search.

Right click to save images. It's pretty useable and good demo application to show off the modern internet on retro Macs.   


# Version 1.0 (prefork) 

A Vibe-coded native Reddit client for Mac OS X 10.4 Tiger, built with Objective-C and Python 3.11. Features image viewing, video downloading, comment browsing, and modern Reddit API support on vintage PowerPC and Intel Macs.


## Features

- 🐅 **Tiger Compatible** - Built specifically for Mac OS X 10.4 Tiger
- 📱 **Modern Reddit** - Browse any subreddit with current Reddit API
- 🖼️ **Image Support** - View thumbnails and download full images
- 🎥 **Video Downloads** - Download videos from Reddit, YouTube, and more
- 💬 **Comments** - Read post comments with optimized parsing
- 🔗 **Article Links** - Open external articles in your browser
- 📦 **Gallery Support** - Handle Reddit image galleries

## System Requirements

- Mac OS X 10.4 Tiger (PowerPC G4/G5)
- GCC 4.0 (included with Xcode 2.5 or Developer Tools)
- Python 3.11
- Internet connection

## Prerequisites

### 1. TenFourFox/Leopard.sh/Tiger.sh Setup

For modern TLS support and package management:

**Option B: leopard.sh (Leopard users)**
```bash
# Install leopard.sh package manager
curl -L https://github.com/leopardsh/leopardsh/raw/main/install.sh | bash
```

**Option C: tiger.sh (Tiger users)**
```bash
# Install tiger.sh package manager  
curl -L https://github.com/tigersh/tigersh/raw/main/install.sh | bash
```

### 2. Python 3.11 Installation

**Using tiger.sh (Recommended):**
```bash
# Install tiger.sh package manager  
curl -L https://github.com/tigersh/tigersh/raw/main/install.sh | bash
tiger.sh install python3.11
```

**Manual Installation:**
```bash
# Download Python 3.11 source from python.org
# Compile with Tiger-compatible flags
./configure --enable-optimizations
make
sudo make install
```

### 3. FFmpeg (for video support)

**Using tiger.sh:**
```bash
tiger.sh install ffmpeg
```

**Manual Installation:**
```bash
# Download and compile FFmpeg from source
# Follow FFmpeg Tiger compilation guides
```

## Building from Source

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/reddit-viewer-tiger.git
cd reddit-viewer-tiger
```

### 2. Install Dependencies

Dependencies are automatically downloaded and bundled during the build process. You only need to ensure Python 3.11 is installed on your system.

### 3. Build with Makefile

```bash
# Build for your architecture
make

# Or specify architecture explicitly:
make ARCH=ppc      # For PowerPC
make ARCH=i386     # For Intel (haven't tested)
make ARCH=universal # For Universal Binary (haven't tested)
```

The Makefile will (attempt to) automatically:
- Download cJSON source files
- Download yt-dlp
- Bundle Python scripts into the app
- Create a complete .app bundle

cJSON and yt-dlp will likely fail to download on Tiger due to TLS issues. Download the files from source and uncompress to the folder you're building in.

Run the app in a folder alongside the files it builds in the process - this is a current bug that needs fixing

## Configuration

### Python Path Detection

The app automatically searches for Python 3.11 in these locations:
- `/usr/local/bin/python3.11`
- `/usr/local/bin/python3`
- `/opt/local/bin/python3.11` (MacPorts)
- `/opt/local/bin/python3`
- `python3` (system PATH)

### Bundling Resources

To include Python script and yt-dlp in your app bundle:

## Usage

### Basic Navigation

1. **Launch the app**
2. **Enter subreddit name** (e.g., "programming", "pics")
3. **Select sort order** (Hot, New, Top, Rising)
4. **Click Refresh**

### Content Types

- **🖼️ Images** - Click "View Image" to download to Desktop
- **🎥 Videos** - Click "View Image" → Choose download or browser
- **🔗 Articles** - **Note: Cannot be opened directly from app - This should be fixed**
- **💬 Text Posts** - Click "View Image" to read content
- **📦 Galleries** - **Note: Only downloads first image, not entire gallery**

### Comments

1. **Select a post**
2. **Click "Comments"**
3. **View in popup window**

**⚠️ Known Limitation:** Comments only work reliably on posts with fewer than 20 comments. Posts with more comments may fail to load or cause the app to hang.

## Known Limitations/ Bugs

### Comments System
- **Only works reliably on posts with <20 comments**
- Posts with 20+ comments may timeout or hang the app
- Large comment threads can overwhelm Tiger's memory management
- **Workaround:** Stick to smaller subreddits or newer posts with fewer comments

### Article Links  
- **Cannot open articles directly from the app**
- Article URLs are displayed but not clickable
- **Workaround:** Copy the URL manually and paste into TenFourFox or your preferred browser

### Gallery Support
- **Only downloads the first image from Reddit galleries**
- Multi-image galleries are not fully supported
- **Workaround:** Individual gallery images can be accessed by visiting the post in a browser

### General Performance
- Image downloading may be slow on PowerPC systems
- Large subreddits (r/all, r/popular) may take time to load
- Computer's limited memory may cause issues with image-heavy posts

## Troubleshooting

### Common Issues

**"Python not found"**
- Install Python 3.11 using one of the methods above
- Check that `python3 --version` shows 3.11.x

**"Script not found in app bundle"**
- Ensure `reddit_fetcher.py` is in the project directory during build
- Check bundle contents: Right-click app → Show Package Contents → Contents/Resources
- Try rebuilding: `make clean && make`

**"Video download fails"**
- Ensure `ffmpeg` is installed and in PATH
- Check that `yt-dlp` is executable: `chmod +x yt-dlp`
- For PowerPC, may need to compile yt-dlp dependencies

**"Comments won't load"**
- **Most common cause:** Post has too many comments (20+)
- Try posts with fewer comments first
- Check Console.app for Python timeout errors
- **Solution:** None right now, would like to fix this

**"Can't open article links"**
- This is expected behavior - articles cannot be opened directly
- Copy the URL shown and paste into TenFourFox or other browser
- This needs to be fixed

**"Gallery only shows one image"**
- This is a known limitation
- Only the first gallery image downloads

## Development

### Adding Features

The app uses a hybrid architecture:
- **Objective-C frontend** - Native Tiger UI and controls
- **Python backend** - Modern HTTPS and Reddit API support

### Key Files

- `RedditViewer.m` - Main application logic
- `reddit_fetcher.py` - Reddit API interface
- `cJSON` - JSON parsing for comment data

### Tiger Compatibility Notes

- Built with Makefile and GCC 4.0 for maximum Tiger compatibility
- Uses manual memory management (no ARC)
- No blocks or modern Objective-C features
- NSTimer for async operations instead of GCD
- Universal binary support for both PowerPC and Intel Macs
1. 

## License

MIT License - See LICENSE file for details

## Acknowledgments

- TenFourFox team for modern web support on PowerPC
- tiger.sh/leopard.sh communities for package management
- cJSON library for fast JSON parsing
- yt-dlp project for video downloading
- Reddit API for content access

---

**Note:** This project is not affiliated with Reddit Inc. It's an independent client for educational and personal use on vintage Mac systems.
