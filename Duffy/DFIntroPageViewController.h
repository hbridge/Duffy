//
//  DFIntroPageViewController.h
//  Duffy
//
//  Created by Henry Bridge on 5/15/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFIntroContentViewController.h"

@interface DFIntroPageViewController : UIViewController



- (void)showNextContentViewController:(DFIntroContentType)contentType;
- (void)dismissIntro;


@end
