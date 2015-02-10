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
#import <SAMGradientView/SAMGradientView.h>
#import <MMPopLabel/MMPopLabel.h>
#import <FBLikeLayout/FBLikeLayout.h>


@interface DFHomeViewController : UIViewController <UICollectionViewDelegate, DFImageDataSourceDelegate, DFNotificationsViewControllerDelegate, MMPopLabelDelegate, UICollectionViewDelegateFlowLayout>
@property (weak, nonatomic) IBOutlet UIButton *sendButton;
- (IBAction)sendButtonPressed:(id)sender;
@property (weak, nonatomic) IBOutlet LKBadgeView *sendBadgeView;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (strong, nonatomic) FBLikeLayout *photoLayout;
@property (nonatomic) NSUInteger numPhotosPerRow;
@property (weak, nonatomic) IBOutlet SAMGradientView *buttonBar;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *buttonBarHeightConstraint;
@property (weak, nonatomic) IBOutlet UILabel *buttonBarLabel;
@property (nonatomic) BOOL hasShownSuggestionsNux;

@end
