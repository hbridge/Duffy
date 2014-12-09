//
//  DFNavigationController.h
//  Strand
//
//  Created by Henry Bridge on 7/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DFNavigationController : UINavigationController

// Defaults back butotn title to "Cancel"
+ (void)presentWithRootController:(UIViewController *)rootController inParent:(UIViewController *)parent;
+ (void)presentWithRootController:(UIViewController *)rootController
                         inParent:(UIViewController *)parent
              withBackButtonTitle:(NSString *)backButtonTitle;

@end
