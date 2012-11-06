//
//  DetailViewController.h
//  TheJoysOfCode
//
//  Created by Bob on 29/10/12.
//  Copyright (c) 2012 Tall Developments. All rights reserved.
//

#import <UIKit/UIKit.h>

@class Post;

@interface DetailViewController : UIViewController <UISplitViewControllerDelegate>

@property (strong, nonatomic) Post* detailItem;

@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;

@end
