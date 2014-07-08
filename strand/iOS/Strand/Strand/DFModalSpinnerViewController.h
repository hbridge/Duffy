//
//  DFModalSpinnerViewController.h
//  Strand
//
//  Created by Henry Bridge on 7/7/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFModalSpinnerViewController : UIViewController

@property (weak, nonatomic) IBOutlet UILabel *messageLabel;
@property (nonatomic, retain) NSString *message;

- (id)initWithMessage:(NSString *) message;

@end
