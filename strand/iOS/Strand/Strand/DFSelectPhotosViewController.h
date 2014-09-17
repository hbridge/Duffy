//
//  DFSelectPhotosViewController.h
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutFeedObject.h"
#import "VENTokenField.h"
#import "DFPeoplePickerViewController.h"
#import <MessageUI/MessageUI.h>

@interface DFSelectPhotosViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate,UIScrollViewDelegate, DFPeoplePickerDelegate, MFMessageComposeViewControllerDelegate>

@property (nonatomic, retain) DFPeanutFeedObject *suggestedSectionObject;
@property (nonatomic, retain) DFPeanutFeedObject *sharedSectionObject;
@property (nonatomic, retain) DFPeanutFeedObject *inviteObject;

@property (weak, nonatomic) IBOutlet UIView *searchBarWrapperView;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UICollectionViewFlowLayout *flowLayout;
@property (nonatomic, retain) VENTokenField *tokenField;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic) BOOL showsToField;

- (instancetype)initWithTitle:(NSString *)title
                 showsToField:(BOOL)showsToField
       suggestedSectionObject:(DFPeanutFeedObject *)suggestedSectionObject
          sharedSectionObject:(DFPeanutFeedObject *)sharedSectionObject
                 inviteObject:(DFPeanutFeedObject *)inviteObject;
- (IBAction)collectionViewTapped:(id)sender;

@end
