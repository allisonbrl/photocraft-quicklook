#import <Foundation/Foundation.h>
#import <QuickLookThumbnailing/QuickLookThumbnailing.h>
#import <fcntl.h>
#import <unistd.h>

@interface PCraftThumbnailProvider : QLThumbnailProvider
@end

@implementation PCraftThumbnailProvider

static NSData *extractThumbnailFromZip(NSURL *url) {
    int fd = open(url.path.fileSystemRepresentation, O_RDONLY);
    if (fd < 0) return nil;
    
    void *previewData = NULL;
    size_t previewSize = 0;
    void *thumbData = NULL;
    size_t thumbSize = 0;
    
    while (1) {
        uint32_t sig = 0;
        if (read(fd, &sig, 4) != 4) break;
        if (sig != 0x04034b50) break;
        
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
        
        if (strcmp(name, "composite/preview.png") == 0) {
            if (compression == 0) {
                previewData = malloc(compSize);
                if (previewData && read(fd, previewData, compSize) == compSize) {
                    previewSize = compSize;
                    break;
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
    
    return [NSData dataWithBytesNoCopy:chosen length:chosenSize freeWhenDone:YES];
}

- (void)provideThumbnailForFileRequest:(QLFileThumbnailRequest *)request completionHandler:(void (^)(QLThumbnailReply * _Nullable, NSError * _Nullable))handler {
    NSData *data = extractThumbnailFromZip(request.fileURL);
    if (!data) {
        handler(nil, [NSError errorWithDomain:@"PCraftThumbnail" code:1 userInfo:nil]);
        return;
    }
    
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"pcraft_thumb_%@.png", [NSUUID UUID].UUIDString]];
    [data writeToFile:tempPath atomically:NO];
    NSURL *tempURL = [NSURL fileURLWithPath:tempPath];
    
    QLThumbnailReply *reply = [QLThumbnailReply replyWithImageFileURL:tempURL];
    handler(reply, nil);
}

@end
