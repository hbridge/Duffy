//
//  DFNUXViewController.h
//  Strand
//
//  Created by Henry Bridge on 1/23/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DFNUXViewController;

extern NSString *const DFPhoneNumberNUXUserInfoKey;
extern NSString *const DFDisplayNameNUXUserInfoKey;

@protocol DFNUXViewControllerDelegate <NSObject>

@required
- (void)NUXController:(DFNUXViewController *)nuxController
completedWithUserInfo:(NSDictionary *)userInfo;

@end

@interface DFNUXViewController : UIViewController

@property (nonatomic, retain) NSDictionary *inputUserInfo;
@property (nonatomic, weak) id<DFNUXViewControllerDelegate> delegate;

- (void)completedWithUserInfo:(NSDictionary *)userInfo;

@end
