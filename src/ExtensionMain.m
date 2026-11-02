#import <Foundation/Foundation.h>
#import <QuickLookUI/QuickLookUI.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <fcntl.h>
#import <unistd.h>

@interface PCraftPreviewProvider : QLPreviewProvider <QLPreviewingController>
@end

@implementation PCraftPreviewProvider

static NSData *extractPreviewFromZip(NSURL *url, uint32_t *outW, uint32_t *outH) {
    int fd = open(url.path.fileSystemRepresentation, O_RDONLY);
    if (fd < 0) return nil;
    
    void *previewData = NULL;
    size_t previewSize = 0;
    void *thumbData = NULL;
    size_t thumbSize = 0;
    
    while (1) {
        uint32_t sig = 0;
        if (read(fd, &sig, 4) != 4) break;
        if (sig != 0x04034b50) break; // PK\x03\x04
        
        uint8_t header[26];
        if (read(fd, header, 26) != 26) break;
        
        uint16_t compression = *(uint16_t *)(header + 4);
        uint32_t compSize = *(uint32_t *)(header + 14);
        uint16_t nameLen = *(uint16_t *)(header + 22);
        uint16_t extraLen = *(uint16_t *)(header + 24);
        
        char name[1024];
        if (nameLen >= sizeof(name)) break;
        if (read(fd, name, nameLen) != nameLen) break;
        name[nameLen] = '\0';
        
        if (extraLen > 0) {
            lseek(fd, extraLen, SEEK_CUR);
        }
        
        // Prioritize full composite/preview.png over thumb.png
        if (strcmp(name, "composite/preview.png") == 0) {
            if (compression == 0) {
                previewData = malloc(compSize);
                if (previewData && read(fd, previewData, compSize) == compSize) {
                    previewSize = compSize;
                    break; // Optimal high-res preview found
                }
            }
        } else if (strcmp(name, "thumb.png") == 0) {
            if (compression == 0) {
                thumbData = malloc(compSize);
                if (thumbData && read(fd, thumbData, compSize) == compSize) {
                    thumbSize = compSize;
                } else {
                    free(thumbData);
                    thumbData = NULL;
                }
            }
        } else {
            lseek(fd, compSize, SEEK_CUR);
        }
    }
    close(fd);
    
    void *chosen = previewData ? previewData : thumbData;
    size_t chosenSize = previewData ? previewSize : thumbSize;
    if (previewData && thumbData) free(thumbData);
    if (!chosen) return nil;
    
    // Parse PNG IHDR dimensions from header
    if (chosenSize >= 24) {
        const uint8_t *b = (const uint8_t *)chosen;
        if (b[0] == 0x89 && b[1] == 'P' && b[2] == 'N' && b[3] == 'G') {
            *outW = (b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19];
            *outH = (b[20] << 24) | (b[21] << 16) | (b[22] << 8) | b[23];
        }
    }
    return [NSData dataWithBytesNoCopy:chosen length:chosenSize freeWhenDone:YES];
}

- (void)providePreviewForFileRequest:(QLFilePreviewRequest *)request completionHandler:(void (^)(QLPreviewReply * _Nullable, NSError * _Nullable))handler {
    uint32_t w = 765, h = 1024;
    NSData *pngData = extractPreviewFromZip(request.fileURL, &w, &h);
    if (!pngData) {
        handler(nil, [NSError errorWithDomain:@"PCraftPreview" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Preview image not found in .pcraft archive"}]);
        return;
    }
    
    // Write temporary image to return via initWithFileURL for full native Quick Look rendering (zoom, pan, resize)
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"pcraft_preview_%@.png", [NSUUID UUID].UUIDString]];
    [pngData writeToFile:tempPath atomically:NO];
    NSURL *tempURL = [NSURL fileURLWithPath:tempPath];
    
    QLPreviewReply *reply = [[QLPreviewReply alloc] initWithFileURL:tempURL];
    handler(reply, nil);
}

@end
