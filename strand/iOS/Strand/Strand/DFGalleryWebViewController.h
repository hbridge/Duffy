//
//  DFGalleryWebViewController.h
//  Strand
//
//  Created by Henry Bridge on 6/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFGalleryWebViewController : UIViewController <UIWebViewDelegate, UIPageViewControllerDataSource>

@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic)  UIButton *cameraButton;
@property (nonatomic, retain) UIRefreshControl *refreshControl;

- (void)cameraButtonPressed:(UIButton *)sender;

@end
