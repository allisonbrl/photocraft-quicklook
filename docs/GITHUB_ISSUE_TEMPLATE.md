# macOS Quick Look & Finder Thumbnail Support for `.pcraft` Documents

### Problem Description
Currently, on macOS (tested on macOS 14 Sonoma and macOS 15+ Sequoia), `.pcraft` documents do not show previews or thumbnails in Finder, and pressing **Spacebar (Quick Look)** causes an immediate crash (`SIGABRT` with exit code 134 in `qlmanage` / `quicklookd`).

### Root Causes

1. **UTI Conformance Conflict in `Info.plist`**:
   In `packaging/macos/Info.plist` (and the built `PhotoCraft.app/Contents/Info.plist`):
   ```xml
   <key>UTTypeIdentifier</key>
   <string>ai.storyteller.photocraft.document</string>
   <key>UTTypeConformsTo</key>
   <array>
     <string>public.data</string>
     <string>public.image</string>
   </array>
   ```
   Declaring conformance to `public.image` directs macOS to invoke `/System/Library/QuickLook/Image.qlgenerator`.
   However, `.pcraft` is a structured ZIP container (`PK\x03\x04`), not a raw image format stream. macOS ImageIO fails to decode it (`imageTypeSupportsSubsampling - 'imgType' is nil`), throwing an uncaught Objective-C exception that triggers `abort()` inside `QuickLook.framework`.

2. **Cloud Storage Compatibility (OneDrive / iCloud / Dropbox)**:
   In cloud-synced folders (which use Apple's modern `FileProvider` architecture), custom icon metadata (`com.apple.FinderInfo` / `com.apple.ResourceFork`) cannot be persisted. Previews must be generated dynamically via Apple's Quick Look framework.

### Proposed Solution

Since the `.pcraft` format already brilliantly bundles `composite/preview.png` and `thumb.png` inside the root of the ZIP container, adding native macOS App Extensions solves this completely and with near-zero overhead:

1. **Quick Look Preview Extension (`com.apple.quicklook.preview`)**:
   Implement a `QLPreviewProvider` (`QuickLookUI.framework`) that handles `ai.storyteller.photocraft.document`. It reads the local file header from the ZIP archive (taking < 5ms), extracts `composite/preview.png`, and returns `[QLPreviewReply initWithFileURL:tempURL]` or `[QLPreviewReply initWithDataOfContentType:...]`.
   - Enables native spacebar previews with zoom, pan, and full retina resolution.

2. **Quick Look Thumbnail Extension (`com.apple.quicklook.thumbnail`)**:
   Implement a `QLThumbnailProvider` (`QuickLookThumbnailing.framework`) that renders `composite/preview.png` (or `thumb.png`) directly into the `QLThumbnailReply` context requested by Finder.
   - Provides live thumbnails in Finder's Column View, Icon View, and Preview Pane.

### Reference Implementation
We have implemented and verified this as a standalone companion app and extension. The complete C / Objective-C reader fits in under 100 lines of code with zero external dependencies, reading the uncompressed ZIP entries directly without extracting the rest of the document.

Would you be open to a PR integrating this into `packaging/macos/`?
