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

#define FPS 30

NSString * const kGIF2MP4ConversionErrorDomain = @"GIF2MP4ConversionError";

@implementation GIFDownloader

+ (NSOperationQueue*) requestQueue {
    static NSOperationQueue* requestQueue = nil;
    if( !requestQueue ) {
        requestQueue = [NSOperationQueue new];
        requestQueue.maxConcurrentOperationCount = 5;
        
    }
    return requestQueue;
}

static __strong NSMutableArray* requests = nil;
+ (BOOL) queueContainsRequest: (NSURLRequest*) request {
    if( !requests ) {
        requests = [NSMutableArray new];
    }
    
    return [requests containsObject: request.URL.absoluteString];
}

+ (void) removeRequest: (NSURLRequest*) request {
    [requests removeObject: request.URL.absoluteString];
}

+ (void) addRequest: (NSURLRequest*) request {
    [requests addObject: request.URL.absoluteString];
}

+ (void) sendAsynchronousRequest: (NSString*) srcURLPath
                downloadFilePath: (NSString*) filePath
               thumbnailFilePath: (NSString *)thumbFilePath
                       completed: (kGIF2MP4ConversionCompleted)handler {
    
    if( !srcURLPath )
        return;
    
    if( !filePath )
        return;
    
    if( !handler )
        return;
    
    NSParameterAssert(srcURLPath);
    NSParameterAssert(filePath);
    NSParameterAssert(handler);
    
    NSURL* URL = [NSURL URLWithString: srcURLPath];
    NSURLRequest* request = [NSURLRequest requestWithURL: URL];
    
    if( [self queueContainsRequest: request] ) {
        NSError* error = [NSError errorWithDomain: kGIF2MP4ConversionErrorDomain
                                             code: kGIF2MP4ConversionErrorAlreadyProcessing
                                         userInfo: nil];
        handler(filePath, error);
        return;
    }
    
    [self addRequest: request];
    
    [[self requestQueue] addOperationWithBlock: ^{
        
#if DEBUG
        NSLog(@"Start writing: %@", filePath.lastPathComponent);
#endif
        //NSURLResponse* response = nil;
        NSError* error = nil;
        NSData* data = [NSURLConnection sendSynchronousRequest: request
                                             returningResponse: NULL
                                                         error: &error];
        
        if( error ) {
            handler(filePath, error);
        }
        else {
            if( [[NSFileManager defaultManager] fileExistsAtPath: filePath] ) {
                [[NSFileManager defaultManager] removeItemAtPath: filePath
                                                           error: &error];
                if( error ) {
                    handler(filePath, error);
                }
            }
            
            NSURL* outFilePath = [NSURL fileURLWithPath: filePath];
            
            kGIF2MP4ConversionCompleted completionHandler = ^(NSString* path, NSError* error) {
                [self removeRequest: request];
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler(path, error);
                });
                
            };
            
            [self processGIFData: data toFilePath: outFilePath thumbFilePath: thumbFilePath completed: completionHandler];
        }
#if DEBUG
        NSLog(@"Finish writing: %@", filePath.lastPathComponent);
#endif
    }];
}

+ (BOOL) processGIFData: (NSData*) data
             toFilePath: (NSURL*) outFilePath
          thumbFilePath: (NSString*) thumbFilePath
              completed: (kGIF2MP4ConversionCompleted) completionHandler {
    
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    unsigned char *bytes = (unsigned char*)data.bytes;
    NSError* error = nil;
    
    if( !CGImageSourceGetStatus(source) == kCGImageStatusComplete ) {
        error = [NSError errorWithDomain: kGIF2MP4ConversionErrorDomain
                                    code: kGIF2MP4ConversionErrorInvalidGIFImage
                                userInfo: nil];
        CFRelease(source);
        completionHandler(outFilePath.absoluteString, error);
        return NO;
    }
    
    size_t sourceWidth = bytes[6] + (bytes[7]<<8), sourceHeight = bytes[8] + (bytes[9]<<8);
    //size_t sourceFrameCount = CGImageSourceGetCount(source);
    __block size_t currentFrameNumber = 0;
    __block Float64 totalFrameDelay = 0.f;
    
    AVAssetWriter* videoWriter = [[AVAssetWriter alloc] initWithURL: outFilePath
                                                           fileType: AVFileTypeQuickTimeMovie
                                                              error: &error];
    if( error ) {
        CFRelease(source);
        completionHandler(outFilePath.absoluteString, error);
        return NO;
    }
    
    if( sourceWidth > 640 || sourceWidth == 0) {
        CFRelease(source);
        error = [NSError errorWithDomain: kGIF2MP4ConversionErrorDomain
                                    code: kGIF2MP4ConversionErrorInvalidResolution
                                userInfo: nil];
        completionHandler(outFilePath.absoluteString, error);
        return NO;
    }
    
    if( sourceHeight > 480 || sourceHeight == 0 ) {
        CFRelease(source);
        error = [NSError errorWithDomain: kGIF2MP4ConversionErrorDomain
                                    code: kGIF2MP4ConversionErrorInvalidResolution
                                userInfo: nil];
        completionHandler(outFilePath.absoluteString, error);
        return NO;
    }
    
    size_t totalFrameCount = CGImageSourceGetCount(source);
    size_t thumbnailFrameCount = floorf( totalFrameCount * 0.05 );
    
    if( totalFrameCount <= 0 ) {
        CFRelease(source);
        error = [NSError errorWithDomain: kGIF2MP4ConversionErrorDomain
                                    code: kGIF2MP4ConversionErrorInvalidGIFImage
                                userInfo: nil];
        completionHandler(outFilePath.absoluteString, error);
        return NO;
    }
    
    NSAssert(sourceWidth <= 640, @"%lu is too wide for a video", sourceWidth);
    NSAssert(sourceHeight <= 480, @"%lu is too tall for a video", sourceHeight);
    
    NSDictionary *videoSettings = @{
    AVVideoCodecKey : AVVideoCodecH264,
    AVVideoWidthKey : @(sourceWidth),
    AVVideoHeightKey : @(sourceHeight)
    };
    
    AVAssetWriterInput* videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType: AVMediaTypeVideo
                                                                              outputSettings: videoSettings];
    NSAssert([videoWriter canAddInput: videoWriterInput], @"Video writer can not add video writer input");
    [videoWriter addInput: videoWriterInput];
    
    NSDictionary* attributes = @{
    (NSString*)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32ARGB),
    (NSString*)kCVPixelBufferWidthKey : @(sourceWidth),
    (NSString*)kCVPixelBufferHeightKey : @(sourceHeight),
    (NSString*)kCVPixelBufferCGImageCompatibilityKey : @YES,
    (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES
    };
    
    AVAssetWriterInputPixelBufferAdaptor* adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput: videoWriterInput
                                                                                                                     sourcePixelBufferAttributes: attributes];
    
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime: CMTimeMakeWithSeconds(totalFrameDelay, FPS)];
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    void (^videoWriterReadyForData)(void) = ^{
        
        NSError* error = nil;
        
        while ([videoWriterInput isReadyForMoreMediaData] ) {
#if DEBUG
            //NSLog(@"Drawing frame %lu/%lu", currentFrameNumber, totalFrameCount);
#endif
            NSDictionary* options = @{(NSString*)kCGImageSourceTypeIdentifierHint : (id)kUTTypeGIF};
            CGImageRef imgRef = CGImageSourceCreateImageAtIndex(source, currentFrameNumber, (__bridge CFDictionaryRef)options);
            if( imgRef ) {
                CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, currentFrameNumber, NULL);
                CFDictionaryRef gifProperties = CFDictionaryGetValue(properties, kCGImagePropertyGIFDictionary);
                
                if( thumbnailFrameCount == currentFrameNumber ) {
                    if( [[NSFileManager defaultManager] fileExistsAtPath: thumbFilePath] ) {
                        [[NSFileManager defaultManager] removeItemAtPath: thumbFilePath error: nil];
                    }
                    
                    UIImage* img = [UIImage imageWithCGImage: imgRef];
                    [UIImagePNGRepresentation(img) writeToFile: thumbFilePath atomically: YES];
                    
                }
                
                if( gifProperties ) {
                    NSNumber* delayTime = CFDictionaryGetValue(gifProperties, kCGImagePropertyGIFDelayTime);
                    
                    totalFrameDelay += delayTime.floatValue;
                    
                    CVPixelBufferRef pxBuffer = [self newBufferFrom: imgRef
                                                withPixelBufferPool: adaptor.pixelBufferPool];
                    
                    CMTime time = CMTimeMakeWithSeconds(totalFrameDelay, FPS);
                    
                    if( pxBuffer ) {
                        if( !videoWriterInput.isReadyForMoreMediaData ) {
                            CVBufferRelease(pxBuffer);
                            CFRelease(properties);
                            CGImageRelease(imgRef);
                            break;
                        }
                        if( ![adaptor appendPixelBuffer: pxBuffer withPresentationTime: time] ) {
                            //Could not write to buffers
                            [videoWriterInput markAsFinished];
                            error = [NSError errorWithDomain: kGIF2MP4ConversionErrorDomain
                                                        code: kGIF2MP4ConversionErrorBufferingFailed
                                                    userInfo: nil];
                            CVBufferRelease(pxBuffer);
                            CFRelease(properties);
                            CGImageRelease(imgRef);
                            break;
                        }
                        
                        CVBufferRelease(pxBuffer);
                    }
                    else {
                        CFRelease(properties);
                        CGImageRelease(imgRef);
                        break;
                    }
                }
                else {
                    //Did not have a GIF image
                    [videoWriterInput markAsFinished];
                    error = [NSError errorWithDomain: kGIF2MP4ConversionErrorDomain
                                                code: kGIF2MP4ConversionErrorInvalidGIFImage
                                            userInfo: nil];
                    if( properties ) CFRelease(properties);
                    CGImageRelease(imgRef);
                    break;
                }
                
                if( properties ) CFRelease(properties);
                CGImageRelease(imgRef);
            }
            else {
                //Did not have a valid image returned -> input is finished
                [videoWriterInput markAsFinished];
                
                CFRelease(source);
                
                void (^videoSaveFinished)(void) = ^{
                    completionHandler(outFilePath.absoluteString, error);
                };
                
                if( [videoWriter respondsToSelector: @selector(finishWritingWithCompletionHandler:)]) {
                    [videoWriter finishWritingWithCompletionHandler: videoSaveFinished];
                }
                else {
                    [videoWriter finishWriting];
                    videoSaveFinished();
                }
                
                dispatch_semaphore_signal(sema);
                
                break;
            }
            
            currentFrameNumber++;
        }
    };
    
    [videoWriterInput requestMediaDataWhenReadyOnQueue: dispatch_get_current_queue()
                                            usingBlock: videoWriterReadyForData];
    
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 120 * NSEC_PER_SEC);
    if( dispatch_semaphore_wait(sema, timeout) ) {
        //Timed out
        error = [NSError errorWithDomain: kGIF2MP4ConversionErrorDomain
                                    code: kGIF2MP4ConversionErrorTimedOut
                                userInfo: nil];
        [videoWriterInput markAsFinished];
        CFRelease(source);
        
        completionHandler(outFilePath.absoluteString, error);
    }
    
    dispatch_release(sema);
    
    return YES;
};

+ (CVPixelBufferRef) newBufferFrom: (CGImageRef) frame withPixelBufferPool: (CVPixelBufferPoolRef) pixelBufferPool {
    NSParameterAssert(frame);
    
    size_t width = CGImageGetWidth(frame);
    size_t height = CGImageGetHeight(frame);
    size_t bpc = 8;
    CGColorSpaceRef colorSpace =  CGColorSpaceCreateDeviceRGB();
    
    CVPixelBufferRef pxBuffer = NULL;
    CVReturn status = kCVReturnSuccess;
    
    if( pixelBufferPool )
        status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pxBuffer);
    else {
        NSDictionary* options = @{(NSString*)kCVPixelBufferCGImageCompatibilityKey : @YES, (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES};
        
        status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef)options, &pxBuffer);
    }
    
    NSAssert(status == kCVReturnSuccess, @"Could not create a pixel buffer");
    
    CVPixelBufferLockBaseAddress(pxBuffer, 0);
    void *pxData = CVPixelBufferGetBaseAddress(pxBuffer);
    
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pxBuffer);
    
    
    CGContextRef context = CGBitmapContextCreate(pxData,
                                                 width,
                                                 height,
                                                 bpc,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGImageAlphaNoneSkipFirst);
    NSAssert(context, @"Could not create a context");
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), frame);
    
    CVPixelBufferUnlockBaseAddress(pxBuffer, 0);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    return pxBuffer;
}

@end
