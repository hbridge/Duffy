//
//  DFTopBarController.h
//  Strand
//
//  Created by Henry Bridge on 8/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFNavigationBar.h"

@interface DFTopBarController : UIViewController <UIScrollViewDelegate>

@property (readonly, nonatomic, retain) DFNavigationBar *navigationBar;
@property (nonatomic, retain) UIView *contentView;

@end
