//
//  DFStrandsViewController.h
//  Strand
//
//  Created by Henry Bridge on 8/15/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFNotificationsViewController.h"
#import "WYPopoverController.h"

@class DFTopBarController;
@class DFStrandsViewController;
@protocol DFStrandViewControllerDelegate <NSObject>

- (void)strandsViewController:(DFStrandsViewController *)strandsViewController
           didUpdateData:(BOOL)newData;
- (void)strandsViewController:(DFStrandsViewController *)strandsViewController
didFinishServerFetchWithError:(NSError *)error;

@end

@interface DFStrandsViewController : UIViewController <DFNotificationsViewControllerDelegate, WYPopoverControllerDelegate>

@property (nonatomic, weak) DFTopBarController *topBarController;

// Strand data
@property (nonatomic, retain) NSArray *sectionObjects;
@property (nonatomic, retain) NSDictionary *indexPathsByID;
@property (nonatomic, retain) NSDictionary *objectsByID;
@property (nonatomic, retain) NSArray *uploadingPhotos;
@property (nonatomic, retain) NSError *uploadError;

// Delegate
@property (nonatomic, weak) id<DFStrandViewControllerDelegate> delegate;

// Notifications popover
@property (nonatomic, retain) DFNotificationsViewController *notificationsViewController;


- (void)reloadFeed;

- (void)settingsButtonPressed:(id)sender;

// asbtract method, subclasses should implement
- (void)showPhoto:(DFPhotoIDType)photoId;

@end
