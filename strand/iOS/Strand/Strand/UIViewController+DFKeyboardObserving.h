//
//  UIViewController+DFKeyboardObserving.h
//  Strand
//
//  Created by Henry Bridge on 12/31/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIViewController (DFKeyboardObserving)

- (void)updateFrameFromKeyboardNotif:(NSNotification *)notification
                otherAnimationsBlock:(DFVoidBlock)otherAnimationsBlock;
@end
