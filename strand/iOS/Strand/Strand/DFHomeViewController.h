//
//  DFHomeViewController.h
//  Strand
//
//  Created by Henry Bridge on 12/9/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFFriendsViewController.h"
#import <LKBadgeView/LKBadgeView.h>
#import "DFImageDataSource.h"
#import "DFNotificationsViewController.h"

@interface DFHomeViewController : UIViewController <UICollectionViewDelegate, DFImageDataSourceDelegate, DFNotificationsViewControllerDelegate>
@property (weak, nonatomic) IBOutlet UIButton *reviewButton;
@property (weak, nonatomic) IBOutlet UIButton *sendButton;
- (IBAction)reviewButtonPressed:(id)sender;
- (IBAction)sendButtonPressed:(id)sender;
@property (weak, nonatomic) IBOutlet LKBadgeView *reviewBadgeView;
@property (weak, nonatomic) IBOutlet LKBadgeView *sendBadgeView;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UICollectionViewFlowLayout *flowLayout;
@property (nonatomic) NSUInteger numPhotosPerRow;
@property (weak, nonatomic) IBOutlet UIView *buttonBar;

@end
