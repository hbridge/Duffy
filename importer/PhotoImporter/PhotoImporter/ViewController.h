//
//  ViewController.h
//  PhotoImporter
//
//  Created by Henry Bridge on 9/15/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController
@property (weak, nonatomic) IBOutlet UITextField *pathTextField;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;

- (IBAction)importButtonPressed:(id)sender;

@end

