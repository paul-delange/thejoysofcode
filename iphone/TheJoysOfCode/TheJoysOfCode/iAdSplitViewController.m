//
//  iAdSplitViewController.m
//  TheJoysOfCode
//
//  Created by Bob on 06/11/12.
//  Copyright (c) 2012 Tall Developments. All rights reserved.
//

#import "iAdSplitViewController.h"

#import <iAd/iAd.h>

@interface iAdSplitViewController () <ADBannerViewDelegate> {
    BOOL hasAdvertisement;
}

@property (weak, nonatomic) UIView* contentView;
@property (weak, nonatomic) ADBannerView* adView;

@end

@implementation iAdSplitViewController

#if BUILD_WITH_ADS
- (void) loadView {
    [super loadView];
    
    UIView* contentView = self.view;
    
    self.view = [[UIView alloc] initWithFrame: contentView.frame];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.view.backgroundColor = [UIColor clearColor];
    
    CGRect contentRect = contentView.frame;
    contentRect.origin = CGPointZero;
    contentView.frame = contentRect;
    
    [self.view addSubview: contentView];
    
    ADBannerView* banner = [[ADBannerView alloc] initWithFrame: CGRectZero];
    banner.requiredContentSizeIdentifiers = [NSSet setWithObjects: ADBannerContentSizeIdentifierLandscape, ADBannerContentSizeIdentifierPortrait, nil];
    banner.delegate = self;
    banner.center = CGPointMake(CGRectGetMidX(self.view.frame), CGRectGetHeight(self.view.frame) + CGRectGetMidY(banner.frame));
    [self.view addSubview: banner];
    
    self.contentView = contentView;
    self.adView = banner;
}
#endif

- (void) viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    NSString* required = UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation) ? ADBannerContentSizeIdentifierLandscape : ADBannerContentSizeIdentifierPortrait;
    
    if( ![self.adView.currentContentSizeIdentifier isEqualToString: required] ) {
        self.adView.currentContentSizeIdentifier = required;
    }
    
    [self updateAdvertisement: YES];
}

- (void) updateAdvertisement: (BOOL) animated {
    CGSize adSize = self.adView.frame.size;
    
    const float contentWidth = self.view.bounds.size.width;
    float contentHeight = 0.f;
    
    if( hasAdvertisement ) {
        contentHeight = self.view.bounds.size.height-adSize.height;
    }
    else {
        contentHeight = self.view.bounds.size.height;
    }
    
    const CGRect contentFrame = CGRectMake(0, 0, contentWidth, contentHeight);
    const CGRect adFrame = CGRectMake((self.view.bounds.size.width-adSize.width)/2.f,
                                      contentHeight,
                                      adSize.width,
                                      adSize.height);
    
    if( CGRectEqualToRect(contentFrame, self.contentView.frame) &&
       CGRectEqualToRect(adFrame, self.adView.frame) )
        return;
    
    void(^animationBlock)(void) = ^() {
        
        self.contentView.frame = contentFrame;
        self.adView.frame = adFrame;
    };
    
    void (^finishBlock)(BOOL) = ^(BOOL finished) {
    };
    
    if( animated ) {
        const NSTimeInterval duration = animated ? [UIApplication sharedApplication].statusBarOrientationAnimationDuration : 0.f;
        
        [UIView animateWithDuration: duration
                              delay: 0.f
                            options: 0
                         animations: animationBlock
                         completion: finishBlock];
    }
    else {
        self.contentView.frame = contentFrame;
        self.adView.frame = adFrame;
    }
}

#pragma mark - ADBannerViewDelegate
- (void) bannerViewDidLoadAd:(ADBannerView *)banner {
    hasAdvertisement = YES;
    [self updateAdvertisement: YES];
}

- (void) bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)error {
    hasAdvertisement = NO;
    [self updateAdvertisement: YES];
}

@end
