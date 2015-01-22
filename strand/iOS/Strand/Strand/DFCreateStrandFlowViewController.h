//
//  DFCreateStrandFlowViewController.h
//  Strand
//
//  Created by Henry Bridge on 10/24/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFNavigationController.h"
#import "DFSelectPhotosViewController.h"
#import "DFRecipientPickerViewController.h"

@class DFCreateStrandFlowViewController;

typedef NS_ENUM(NSInteger, DFCreateStrandResult) {
  DFCreateStrandResultAborted = 0,
  DFCreateStrandResultSuccess,
  DFCreateStrandResultFailure,
};

@protocol DFCreateStrandFlowViewControllerDelegate <NSObject>

- (void)createStrandFlowController:(DFCreateStrandFlowViewController *)controller
               completedWithResult:(DFCreateStrandResult)result
                            photos:(NSArray *)photos
                          contacts:(NSArray *)contacts;

@end


@interface DFCreateStrandFlowViewController : DFNavigationController <DFSelectPhotosViewControllerDelegate, DFPeoplePickerDelegate>

@property (nonatomic, retain) DFSelectPhotosViewController *selectPhotosController;
@property (nonatomic, retain) DFRecipientPickerViewController *peoplePickerController;
@property (nonatomic, retain) DFPeanutFeedObject *highlightedCollection;
@property (nonatomic, retain) NSDictionary *extraAnalyticsInfo;
@property (nonatomic, weak) id<DFCreateStrandFlowViewControllerDelegate> delegate;

- (instancetype)initWithHighlightedPhotoCollection:(DFPeanutFeedObject *)highlightedCollection;
- (void)refreshFromServer;
+ (void)presentFeedObject:(DFPeanutFeedObject *)feedObject modallyInViewController:(UIViewController *)viewController;
@end
