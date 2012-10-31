//
//  GIFDownloader.m
//  TheJoysOfCode
//
//  Created by Bob on 29/10/12.
//  Copyright (c) 2012 Tall Developments. All rights reserved.
//

#import "GIFDownloader.h"

#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>

typedef enum {
    GIFDecodeStateInitialized = 0,
    GIFDecodeStateReadingHeader,
    GIFDecodeStateReadingGlobalColorTable,
    GIFDecodeStateReadingSegment,
    GIFDecodeStateFinished,
    GIFDecodeStateErrorOccured
} GIFDecodeState;

#define FPS 30
NSString * const GIFDelayInHundredsOfASecondKey = @"GIFDelayAfterLastFrame";
NSString * const GIFDisposalMethodKey = @"GIFDisplosalMethodForLastFrame";
NSString * const GIFFrameHasTransparencyKey = @"GIFFrameHasTransparency";
NSString * const GIFFrameHeaderKey = @"GIFFrameHeaderKey";

@interface GIFDownloader () <NSURLConnectionDelegate> {
    unsigned char dataPointer;
    unsigned char frameWidth, frameHeight, colorResolution;
    NSUInteger numberOfFrames;
    GIFDecodeState state;
    __strong NSData* globalColorTable;
    boolean_t gctSorted;
    NSUInteger globalColorIndex, globalColorTableSize;
    __strong NSMutableDictionary* frameProperties;
    CGImageSourceRef decoder;
}

@property (nonatomic, strong) NSMutableData* responseData;
@property (strong, nonatomic) AVAssetWriter* videoWriter;
@property (strong, nonatomic) AVAssetWriterInput* videoWriterInput;
@property (strong, nonatomic) AVAssetWriterInputPixelBufferAdaptor* videoWriterAdaptor;

@end

static UIImage *animatedImageWithAnimatedGIFImageSource(CGImageSourceRef source, NSTimeInterval duration) {
    if (!source)
        return nil;
    
    size_t count = CGImageSourceGetCount(source);
    NSMutableArray *images = [NSMutableArray arrayWithCapacity:count];
    for (size_t i = 0; i < count; ++i) {
        CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, i, NULL);
        if (!cgImage)
            return nil;
        [images addObject:[UIImage imageWithCGImage:cgImage]];
        CGImageRelease(cgImage);
    }
    
    return [UIImage animatedImageWithImages:images duration: count * 1 / 30.f];
}

static UIImage *animatedImageWithAnimatedGIFReleasingImageSource(CGImageSourceRef source, NSTimeInterval duration) {
    UIImage *image = animatedImageWithAnimatedGIFImageSource(source, duration);
    CFRelease(source);
    return image;
}

@implementation GIFDownloader

+ (UIImage *)animatedImageWithAnimatedGIFURL:(NSURL *)url duration:(NSTimeInterval)duration {
    return animatedImageWithAnimatedGIFReleasingImageSource(CGImageSourceCreateWithURL((__bridge CFTypeRef)url, NULL), duration);
}

+ (id) GIFDownloader: (void(^)(GIFDownloader* downloader)) block {
    NSParameterAssert(block);
    GIFDownloader* downloader = [GIFDownloader new];
    block(downloader);
    
    [self animatedImageWithAnimatedGIFURL: [NSURL URLWithString: downloader.sourceFilePath]
                                 duration: 0];
    
    /*
    //Delete any old data or the video writer will fail
    if([[NSFileManager defaultManager] fileExistsAtPath: downloader.outputFilePath]) {
        [[NSFileManager defaultManager] removeItemAtPath: downloader.outputFilePath
                                                   error: nil];
    }
    
    NSURL* url = [NSURL URLWithString: downloader.sourceFilePath];
    NSURLRequest* request = [NSURLRequest requestWithURL: url];
    NSURLConnection* conn = [NSURLConnection connectionWithRequest: request delegate: downloader];
    [conn scheduleInRunLoop: [NSRunLoop mainRunLoop] forMode: NSDefaultRunLoopMode];
    [conn start];
    return downloader;
     */
}

- (void) initializeVideoWriter {
    
    //CFDictionaryRef options = (__bridge CFDictionaryRef)@{ (__bridge NSString*)kCGImageSourceTypeIdentifierHint : (__bridge NSString*)kUTTypeGIF};
    decoder = CGImageSourceCreateIncremental(0);
    
    //Start saving video
    NSURL* srcURL = [NSURL fileURLWithPath: self.outputFilePath];
    NSError* error = nil;
    self.videoWriter = [[AVAssetWriter alloc] initWithURL: srcURL
                                                 fileType: AVFileTypeQuickTimeMovie
                                                    error: &error];
    // http://stackoverflow.com/questions/3741323/how-do-i-export-uiimage-array-as-a-movie
    NSAssert(!error, @"%@ occurred while creating video writer", error);
    
    NSDictionary *videoSettings = @{AVVideoCodecKey : AVVideoCodecH264, AVVideoWidthKey : @(640), AVVideoHeightKey : @(480)};
    self.videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType: AVMediaTypeVideo
                                                               outputSettings: videoSettings];
    
    NSAssert(self.videoWriterInput, @"Could not initiate a video writer input");
    NSAssert([self.videoWriter canAddInput: self.videoWriterInput], @"Video writer can not add video writer input");
    
    [self.videoWriter addInput: self.videoWriterInput];
    
    self.videoWriterAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput: self.videoWriterInput sourcePixelBufferAttributes: nil];
    
    //self.videoWriter.movieFragmentInterval = CMTimeMake(FPS*.5, FPS);
    
    [self.videoWriter startWriting];
    [self.videoWriter startSessionAtSourceTime: CMTimeMake(0, FPS)];
    
    frameProperties = [NSMutableDictionary new];
}

- (void) finalizeVideoWriter {
    [self.videoWriterInput markAsFinished];
    [self.videoWriter endSessionAtSourceTime: CMTimeMake(numberOfFrames, FPS)];
    if( [self.videoWriter respondsToSelector: @selector(finishWritingWithCompletionHandler:)]) {
        [self.videoWriter finishWritingWithCompletionHandler: ^{
            
        }];
    }
    else {
        [self.videoWriter finishWriting];
    }
}

- (void) parseData: (NSData*) data parsedLength: (NSUInteger*) length {
    
    const NSInteger dataLength = data.length;
    const unsigned char* bytes = data.bytes;
    
    //NSLog(@"Processing data with length: %d", dataLength);
    
    switch (state) {
        case GIFDecodeStateInitialized:
        {
            if( dataLength < 6 ) {
                *length = 0;
                return;
            }
            
            NSData* header = [data subdataWithRange: NSMakeRange(0, 6)];
            
            //Look for GIF header
            const char gifSignature[2] = {71, 73};
            
            if( memcmp(gifSignature, bytes, 2) == 0 ) {
                //This was a GIF file
                
                //Must be GIF89a for animations
                NSAssert(strcmp("GIF89a", header.bytes) == 0, @"This GIF file does not include an animation, Header: %@", header.bytes);
                
                *length = 6;
                state = GIFDecodeStateReadingHeader;
            }
            else {
                state = GIFDecodeStateErrorOccured;
            }
            break;
        }
        case GIFDecodeStateReadingHeader:
        {
            //Look for width and height of image
            if( dataLength < 7 ) {
                *length = 0;
                return;
            }
            
            //Best explanation:
            // http://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp
            
            boolean_t hasGCT;
            NSUInteger N;
            
            frameWidth = bytes[0] + bytes[1];
            frameHeight = bytes[2] + bytes[3];
            
            hasGCT = bytes[4] & 0x80 ? 1 : 0;
            colorResolution = bytes[4] & 0x70;
            gctSorted = bytes[4] & 0x08 ? 1 : 0;
            N = bytes[4] & 0x07;
            globalColorTableSize = 2 << N;
            
            NSLog(@"Image size: %dx%d", frameWidth, frameHeight);
            
            NSAssert(frameWidth, @"Could not read Screen width Descriptor");
            NSAssert(frameHeight, @"Could not read Screen height Descriptor");
            
            if( hasGCT ) {
                state = GIFDecodeStateReadingGlobalColorTable;
                globalColorIndex = bytes[5];
            }
            else {
                NSAssert(globalColorIndex==0, @"With no Global Color Table, the background color should be empty");
                NSLog(@"Strange, this GIF has not Global Color Table");
                
                state = GIFDecodeStateReadingSegment;
            }
            
            [frameProperties removeAllObjects];
            *length = 7;
            break;
        }
        case GIFDecodeStateReadingGlobalColorTable:
        {
            NSUInteger tableLength = 3*globalColorTableSize;
            
            NSLog(@"GCT is %d bytes long and %@", tableLength, (gctSorted)?@"sorted":@"not sorted");
            NSRange gctRange = NSMakeRange(0, tableLength);
            
            if(dataLength < tableLength+1) {
                *length = 0;
                return;
            }
            
            globalColorTable = [data subdataWithRange: gctRange];
            
            /*
             for(NSUInteger j =0;j<tableLength;j += 3) {
             NSLog(@"Next %d: %x %x %x", j / 3,  ((char*)[globalColorTable bytes])[j], ((char*)[globalColorTable bytes])[j+1], ((char*)[globalColorTable bytes])[j+2]);
             }
             */
            
            unsigned char nextChar = ((char*)[data bytes])[gctRange.length];
            NSAssert(nextChar == 0x21, @"There should be a GCE after the color table, not %x", nextChar);
            state = GIFDecodeStateReadingSegment;
            *length = tableLength;
            break;
        }
        case GIFDecodeStateReadingSegment:
        {
            NSUInteger offset = 0;
            while (offset < dataLength) {
                unsigned char byte = bytes[offset];
                
                switch (byte) {
                    case 0x3b:
                    {
                        //Finish byte
                        *length = 0;
                        state = GIFDecodeStateFinished;
                        return;
                    }
                    case 0x21:
                    {
                        //Graphic Control Extension
                        if( dataLength < 11 ) {
                            *length = 0;
                            return;
                        }
                        else {
                            unsigned char cur = bytes[2], prev = bytes[1];
                            if( cur == 0x04 && prev == 0xF9 ) {
                                NSData* extension = [data subdataWithRange: NSMakeRange(offset, 8)];
                                unsigned char* extensionBytes = (unsigned char*)extension.bytes;
                            
                                //NSLog(@"GCE: %x %x %x %x %x %x %x %x", extensionBytes[0], extensionBytes[1], extensionBytes[2], extensionBytes[3], extensionBytes[4], extensionBytes[5], extensionBytes[6], extensionBytes[7]);
                                
                                NSUInteger frameDelay = extensionBytes[4] + extensionBytes[5];
                                NSUInteger disposalMethod = extensionBytes[3] & 0x1C;
                                boolean_t hasTransparency = extensionBytes[3] & 0x01;
                                
                                unsigned char board[8] = {
                                    0x21,               //GCE
                                    0xF9,               //GCL
                                    0x04,               //Byte size
                                    extensionBytes[3],
                                    extensionBytes[4],
                                    extensionBytes[5],
                                    extensionBytes[6],
                                    extensionBytes[7]
                                };
                                
                                //NSAssert(disposalMethod==1, @"Disposal method %d is not supported", disposalMethod);
                                NSAssert(extensionBytes[7] == 0x00, @"Block terminator was not correct %x", extensionBytes[7]);
                                
                                NSDictionary* properties = @{ GIFDelayInHundredsOfASecondKey : @(frameDelay), GIFDisposalMethodKey : @(disposalMethod), GIFFrameHasTransparencyKey : @(hasTransparency), GIFFrameHeaderKey : [NSData dataWithBytes: &board length: 8]};
                                
                                [frameProperties setObject: properties forKey: @(numberOfFrames)];
                                
                                //NSLog(@"Added animation delay: %fs (disposal method: %d)", frameDelay/100.f, disposalMethod);
                                *length = 8;
                            }
                            else if( cur == 0x0B && prev == 0xFF ) {
                                NSData* extension = [data subdataWithRange: NSMakeRange(3, 11)];
                                unsigned char* extensionBytes = (unsigned char*)extension.bytes;
                                unsigned char applicationIdentifier[12] = {extensionBytes[0], extensionBytes[1], extensionBytes[2], extensionBytes[3], extensionBytes[4], extensionBytes[5], extensionBytes[6], extensionBytes[7], extensionBytes[8], extensionBytes[9], extensionBytes[10], '\0'};
                                
                                NSLog(@"Found Application Extension: %s", applicationIdentifier);
                                
                                NSAssert(extensionBytes[11] == 0x00, @"Invalid Application Extension block termination character %x", extensionBytes[11]);
                                
                                *length = 19;
                            }
                            else if( prev == 0xFE ) {
                                NSUInteger dataBlockLength = bytes[3] + 1;
                                if( dataLength < dataBlockLength + 3 ) {
                                    *length = 0;
                                    return;
                                }
                                
                                NSData* extension = [data subdataWithRange: NSMakeRange(3, dataBlockLength)];
                                unsigned char* extensionBytes = (unsigned char*)extension.bytes;
                                
                                NSLog(@"Found Comment: %s", extensionBytes);
                                
                                NSUInteger l = offset+3;
                                while (l < dataLength) {
                                    unsigned char c = ((char*)[data bytes])[l];
                                    if( c == 0x2C || c== 0x21 ) {
                                        *length = l;
                                        return;
                                    }
                                    
                                    l++;
                                }
                                return;
                            }
                            else {
                                NSLog(@"Skipped Graphic Extension Header with Graphic Control Label %x", prev);
                            }
                        
                        
                        return;
                    }
                        break;
                }
            case 0x2C:
                {
                    //Image Descriptor
                    if( dataLength < 10 ) {
                        *length = 0;
                        return;
                    }
                    else {
                        if( offset + 12 > dataLength ) {
                            *length = 0;
                            return;
                        }
                        
                        NSData* descriptor = [data subdataWithRange: NSMakeRange(offset, 10)];
                        unsigned char* descriptorBytes = (unsigned char*)descriptor.bytes;
                        
                        offset += descriptor.length;
                        unsigned char lzwSize = bytes[offset++];            //Get compression size
                        unsigned char dataBlockLength = bytes[offset++];    //Get first data block length
                        
                        if( offset + dataBlockLength + 1 > dataLength ) {
                            *length = 0;
                            return;
                        }
                        
                        //NSLog(@"ID: %x %x %x %x %x %x %x %x %x %x", descriptorBytes[0], descriptorBytes[1], descriptorBytes[2], descriptorBytes[3], descriptorBytes[4], descriptorBytes[5], descriptorBytes[6], descriptorBytes[7], descriptorBytes[8], descriptorBytes[9]);

                        NSUInteger sizeOfLCT = globalColorTable.length;
                        boolean_t sorted = gctSorted, hasLCT = descriptorBytes[9] & 0x80;
                        NSData* colorTable = globalColorTable;
                        
                        NSAssert(!hasLCT, @"We do not support frame specific color tables");
                        
                        /*
                        if( hasLCT ) {
                            sizeOfLCT = 2 << (descriptorBytes[9] & 0x07);
                            sorted = descriptorBytes[9] & 0x20;
                            NSRange colorTableRange = NSMakeRange(offset+10, sizeOfLCT);
                            colorTable = [data subdataWithRange: colorTableRange];
                            
                            NSLog(@"Frame %d has %@ color table of size: %d", numberOfFrames, sorted?@"a sorted":@"an unsorted", sizeOfLCT);
                        }
                        else {
                            //NSLog(@"This frame has no color table attached -> use global values");
                        }*/
                        
                        unsigned char packed = 0x80;    //Has global color table
                        packed |= colorResolution;      //Use global color resolution
                        packed |= (sizeOfLCT >> 2);     //Add color table size
                        if( sorted )
                            packed |= 0x08;             //Color table sorting
                        
                        unsigned char lsd[7] = {
                            descriptorBytes[5], descriptorBytes[6],     //Width
                            descriptorBytes[7], descriptorBytes[8],     //Height
                            packed,                                     //Color table description
                            globalColorIndex,                           //Background color index
                            0x00                                        //Always zero
                        };
                        
                        NSDictionary* info = [frameProperties objectForKey: @(numberOfFrames)];
                        NSData* header = info[GIFFrameHeaderKey];
                        
                        NSString* gif = @"GIF89a";
                        NSMutableData* frame = [NSMutableData dataWithData: [gif dataUsingEncoding: NSUTF8StringEncoding]];
                        
                        //Add Logical Screen Descriptor
                        [frame appendBytes: &lsd length: 7];
                        
                        //Add color table
                        [frame appendData: colorTable];
                        
                        //Add GCE
                        NSAssert(header, @"No header for frame %d", numberOfFrames);
                        NSAssert(header.length == 8, @"%d is not a valid GCE", header.length);
                        
                        [frame appendData: header];
                        
                        //Add Descriptor
                        descriptorBytes[9] &= 0x40; // Clear local color table settings but keep interlace flag
                        
                        NSAssert(descriptor.length == 10, @"%d is a bad image descriptor length", descriptor.length);
                        
                        [frame appendData: descriptor];
                        
                        //We might not have enough data to record the image
                        
                        //Append lzw minimum code size
                        [frame appendBytes: &lzwSize length: 1];
                        
                        //Append data block
                        NSUInteger dataBlockCount = 0;
                        while( dataBlockLength > 0 ) {
                            //NSLog(@"This data block is %d bytes long", dataBlockLength);
                            
                            if( offset + dataBlockLength + 1 > dataLength ) {
                                *length = 0;
                                return;
                            }
                            
                            NSRange dataBlockRange = NSMakeRange(offset, dataBlockLength);
                            NSData* dataBlock = [data subdataWithRange: dataBlockRange];
                            
                            [frame appendBytes: &dataBlockLength length: 1];
                            [frame appendData: dataBlock];
                            
                            offset += dataBlockLength;
                            
                            dataBlockLength = bytes[offset++];
                            dataBlockCount++;
                        }
                        
                        unsigned char lastChar = bytes[offset-1];

                        NSAssert(lastChar == 0x00, @"%x is not a good image data terminator", lastChar);
                        
                        unsigned char endC[2] = {0x00, 0x3b};
                        [frame appendBytes: &endC length: 2];
                        
                        /*
                        unsigned char* fc = (unsigned char*)[frame bytes];
                        NSLog(@"Frame Tag: %c%c%c%c%c%c", fc[0], fc[1], fc[2], fc[3], fc[4], fc[5]);
                        NSLog(@"Frame LSD: %02x %02x %02x %02x %02x %02x %02x", fc[6], fc[7], fc[8], fc[9], fc[10], fc[11], fc[12]);
                        NSLog(@"Frame CT is %d bytes", colorTable.length);
                        
                        NSInteger fo = 13 + colorTable.length;
                        NSLog(@"Frame GCE: %02x %02x %02x %02x %02x %02x %02x %02x", fc[fo++], fc[fo++], fc[fo++], fc[fo++], fc[fo++], fc[fo++], fc[fo++], fc[fo++]);
                        
                        NSLog(@"Frame ID: %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x", fc[fo++], fc[fo++], fc[fo++], fc[fo++], fc[fo++], fc[fo++], fc[fo++], fc[fo++], fc[fo++], fc[fo++]);
                        NSLog(@"Frame LZW size: %d", fc[fo++]);
                        NSMutableArray* blocks = [NSMutableArray new];
                        NSUInteger bl = fc[fo];
                        while( bl  ) {
                            [blocks addObject: @(bl)];
                            fo += bl + (bl==255?1:0);
                            bl = fc[fo];
                        }
                        
                        NSLog(@"Frame has %d data blocks", blocks.count);
                        NSLog(@"Frame termination character: %x", fc[fo+2]);
                        fo += 3;
                        
                        NSAssert(blocks.count == dataBlockCount, @"%d does not match the extracted block count of %d", blocks.count, dataBlockCount);
                        NSAssert(fo == frame.length, @"GIF length (%d) is not correct (%d)", frame.length, fo);
                        */
                        
                        [self writeFrameFromGIFData: frame];
                        
                        *length = offset;
                        return;
                    }
                }
            default:
                NSAssert(0, @"You should not be here with a value of %x", byte);
                break;
            }
        }
        default:
            break;
    }
}
}

- (void) writeFrameFromGIFData: (NSData*) frame {
    
    NSLog(@"Write frame %d", numberOfFrames);
    
    UIImage* img = [UIImage imageWithData: frame];
    
    NSAssert(img, @"Could not create an image");
    
    CVPixelBufferRef pxBuffer = NULL;
    NSDictionary* options = @{(NSString*)kCVPixelBufferCGImageCompatibilityKey : @YES, (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES};
    
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, img.size.width, img.size.height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef)options, &pxBuffer);
    
    NSAssert(status == kCVReturnSuccess, @"Could not create a pixel buffer");
    
    CVPixelBufferLockBaseAddress(pxBuffer, 0);
    
    void *pxData = (void*)frame.bytes;
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxData,
                                                 frameWidth,
                                                 frameHeight,
                                                 8,
                                                 4*frameWidth,
                                                 rgbColorSpace,
                                                 kCGImageAlphaNoneSkipFirst);
    NSAssert(context, @"Could not create a context");
    
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(img.CGImage), CGImageGetHeight(img.CGImage)), img.CGImage);
    
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxBuffer, 0);
    
    CMTime time = CMTimeMake(numberOfFrames++, FPS);
    [self.videoWriterAdaptor appendPixelBuffer: pxBuffer withPresentationTime: time];
    
    CVPixelBufferRelease(pxBuffer);
}

#pragma mark - NSURLConnectionDelegate
- (void) connection: (NSURLConnection*) connection didReceiveResponse:(NSURLResponse *)response {
    [self.responseData setLength: 0];    //Redirected => reset data
}

- (void) connection: (NSURLConnection*) connection didReceiveData:(NSData *)data {
    NSMutableData* receivedData = self.responseData;
    
    if( !receivedData ) {
        receivedData = [NSMutableData data];
        self.responseData = receivedData;
        
        [self initializeVideoWriter];
    }
    
    [receivedData appendData: data];
    
    //Parse metadata
    
    // 0 - AVAssetWriterStatusUnknown
    // 1 - AVAssetWriterStatusWriting
    // 2 - AVAssetWriterStatusCompleted
    // 3 - AVAssetWriterStatusFailed
    // 4 - AVAssetWriterStatusCancelled
    //NSLog(@"Status: %d", self.videoWriter.status);
    if( self.videoWriter.status == AVAssetWriterStatusFailed ) {
        NSLog(@"Error: %@", self.videoWriter.error);
    }
    
    CGImageSourceUpdateData(decoder, (__bridge CFDataRef)self.responseData, false);
    
    const unsigned numOptions = 1;
    const void* keys[numOptions] = { kCGImageSourceShouldCache };
    const void* values[numOptions] = { kCFBooleanFalse };
    CFDictionaryRef options = CFDictionaryCreate(NULL, keys, values, numOptions, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CGImageRef imgRef = CGImageSourceCreateImageAtIndex(decoder, numberOfFrames, options);
    CGImageSourceStatus status = CGImageSourceGetStatusAtIndex(decoder, numberOfFrames);
    
    if( status == kCGImageStatusComplete ) {
        NSLog(@"An image is ready");
    }
    else {
        NSLog(@"No image yet: %d", status);
    }
    
    CFRelease(imgRef);
    CFRelease(options);
    
    /*
    NSUInteger parsedLength = 0;
    NSUInteger segmentLength = NSUIntegerMax;
    while ( parsedLength < receivedData.length && segmentLength > 0) {
        NSData* subdata = [receivedData subdataWithRange: NSMakeRange(parsedLength, receivedData.length-parsedLength)];
        [self parseData: subdata parsedLength: &segmentLength];
        parsedLength += segmentLength;
        
        //NSLog(@"Read byte segment with length: %d", segmentLength);
    }
    
    //NSLog(@"Removing %d bytes from buffer", parsedLength);
    
    [self.responseData replaceBytesInRange: NSMakeRange(0, parsedLength) withBytes: NULL length:0];
     */
}

- (void) connection: (NSURLConnection*) connection didFailWithError:(NSError *)error {
    if( self.completionBlock )
        self.completionBlock(self.outputFilePath);
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    return cachedResponse;
}

- (void) connectionDidFinishLoading: (NSURLConnection *)connection {
    
    NSAssert(state == GIFDecodeStateFinished, @"GIF Decoder was in a strange state: %d", state);
    
    //Termination byte 0x3B is always remaining
    NSAssert(self.responseData.length == 1, @"GIF Decoder did not finish processing full GIF (%d bytes remaining)", self.responseData.length);
    
    if(!self.responseData.length) {
        self.responseData = nil;
    }
    else {
        //Finish saving video
        [self finalizeVideoWriter];
    }
    
    self.completionBlock(self.outputFilePath);
}

@end
