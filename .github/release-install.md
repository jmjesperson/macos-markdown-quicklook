## Install

This build is not signed with an Apple Developer ID or notarized, so macOS blocks it the first time.

1. Download `MarkdownQuicklook-<version>.zip` below and unzip it.
2. Move `MarkdownQuicklook.app` to `/Applications`.
3. Clear the quarantine: `xattr -dr com.apple.quarantine /Applications/MarkdownQuicklook.app`, or open the app, dismiss the warning, and choose **Open Anyway** in **System Settings › Privacy & Security**.
4. Open MarkdownQuicklook once. Its window says whether the preview extension is enabled and where to turn it on.
5. Select a markdown file in Finder and press space.

Full steps, including how to turn off another markdown previewer: [README](https://github.com/jmjesperson/macos-markdown-quicklook#install). Requires macOS 15 or later.
