//
//  DFPhotoWebViewController.h
//  Duffy
//
//  Created by Henry Bridge on 4/4/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFPhotoWebViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIWebView *webView;

@property (nonatomic, retain) NSURL *currentPhotoURL;


- (id)initWithPhotoURL:(NSURL *)photoURL;

@end
