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
        requestQueue.maxConcurrentOperationCount = 1;
        
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
                       completed: (kGIF2MP4ConversionCompleted) handler {
    
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
    
    kGIF2MP4ConversionCompleted completionHandler = ^(NSString* path, NSError* error) {
        [self removeRequest: request];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(path, error);
        });
    };
    
    [self addRequest: request];
    
    [[self requestQueue] addOperationWithBlock: ^{

        NSURLResponse* response = nil;
        NSError* error = nil;
        NSData* data = [NSURLConnection sendSynchronousRequest: request
                                             returningResponse: &response
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
            
            [self processGIFData: data toFilePath: outFilePath completed: completionHandler];
            
        }

    }];
}

+ (BOOL) processGIFData: (NSData*) data
             toFilePath: (NSURL*) outFilePath
              completed: (kGIF2MP4ConversionCompleted) completionHandler {
    
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    unsigned char *bytes = (unsigned char*)data.bytes;
    NSError* error = nil;
    
    if( !CGImageSourceGetStatus(source) == kCGImageStatusComplete ) {
        error = [NSError errorWithDomain: kGIF2MP4ConversionErrorDomain
                                    code: kGIF2MP4ConversionErrorInvalidGIFImage
                                userInfo: nil];
        completionHandler(outFilePath.absoluteString, error);
        return NO;
    }
    
    size_t sourceWidth = bytes[6] + (bytes[7]<<8), sourceHeight = bytes[8] + (bytes[9]<<8);
    size_t sourceFrameCount = CGImageSourceGetCount(source);
    __block size_t currentFrameNumber = 0;
    __block Float64 totalFrameDelay = 0.f;
    
    AVAssetWriter* videoWriter = [[AVAssetWriter alloc] initWithURL: outFilePath
                                                           fileType: AVFileTypeQuickTimeMovie
                                                              error: &error];
    if( error ) {
        completionHandler(outFilePath.absoluteString, error);
         return NO;
    }
    
    if( sourceWidth > 640 || sourceWidth < 10)
        sourceWidth = 640;
    
    if( sourceHeight > 480 || sourceHeight < 10 )
        sourceHeight = 480;
    
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
    
    AVAssetWriterInputPixelBufferAdaptor* adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput: videoWriterInput
                                                                                                                     sourcePixelBufferAttributes: nil];
    
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime: CMTimeMakeWithSeconds(totalFrameDelay, FPS)];
    
    void (^videoWriterReadyForData)(void) = ^{
        if( currentFrameNumber < sourceFrameCount ) {
            CGImageRef imgRef = CGImageSourceCreateImageAtIndex(source, currentFrameNumber, NULL);
               
            CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, currentFrameNumber, NULL);
            CFDictionaryRef gifProperties = CFDictionaryGetValue(properties, kCGImagePropertyGIFDictionary);
            
            if( !gifProperties ) {
                completionHandler(outFilePath.absoluteString, [NSError errorWithDomain: kGIF2MP4ConversionErrorDomain
                                                                                  code: kGIF2MP4ConversionErrorInvalidGIFImage
                                                                              userInfo: nil]);
                return;
            }
            
            NSNumber* delayTime = CFDictionaryGetValue(gifProperties, kCGImagePropertyGIFDelayTime);

            totalFrameDelay += delayTime.floatValue;
            
            CFRelease(properties);
            
            CVPixelBufferRef pxBuffer = [self newBufferFrom: imgRef];
  
            CMTime time = CMTimeMakeWithSeconds(totalFrameDelay, FPS);
            
            @try {
                [adaptor appendPixelBuffer: pxBuffer withPresentationTime: time];
            }
            @catch (NSException *exception) {
                completionHandler(outFilePath.absoluteString, [NSError errorWithDomain: kGIF2MP4ConversionErrorDomain code: kGIF2MP4ConversionErrorBufferingFailed userInfo:nil]);
                return;
            }
            @finally {
                CVPixelBufferRelease(pxBuffer);
                CGImageRelease(imgRef);
            }

            currentFrameNumber++;
        }
        else {
            CFRelease(source);
            [videoWriterInput markAsFinished];
            
            void (^videoSaveFinished)(void) = ^{
                completionHandler(outFilePath.absoluteString, nil);
            };
            
            if( [videoWriter respondsToSelector: @selector(finishWritingWithCompletionHandler:)]) {
                [videoWriter finishWritingWithCompletionHandler: videoSaveFinished];
            }
            else {
                [videoWriter finishWriting];
                videoSaveFinished();
            }
        }
    };
    
    [videoWriterInput requestMediaDataWhenReadyOnQueue: dispatch_get_current_queue()
                                            usingBlock: videoWriterReadyForData];
    
    return YES;
};

+ (CVPixelBufferRef) newBufferFrom: (CGImageRef) frame {
    NSParameterAssert(frame);
    
    size_t width = CGImageGetWidth(frame);
    size_t height = CGImageGetHeight(frame);
    size_t bpc = 8;
    CGColorSpaceRef colorSpace =  CGColorSpaceCreateDeviceRGB();
    
    NSDictionary* options = @{(NSString*)kCVPixelBufferCGImageCompatibilityKey : @YES, (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES};
    
    CVPixelBufferRef pxBuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef)options, &pxBuffer);
    
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
