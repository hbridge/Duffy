//
//  DFOverlayViewController.h
//  Strand
//
//  Created by Henry Bridge on 7/27/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFOverlayViewController : UIViewController

- (void)animateIn:(void(^)(BOOL finished))completion;

@end
