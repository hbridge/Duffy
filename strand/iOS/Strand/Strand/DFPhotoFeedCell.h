//
//  DFPhotoFeedCell.h
//  Strand
//
//  Created by Henry Bridge on 7/20/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFCollectionViewTableViewCell.h"

@class DFPhotoFeedCell;

@protocol DFPhotoFeedCellDelegate <NSObject>
@required

- (void)favoriteButtonPressedForObject:(id)object sender:(id)sender;
- (void)commentButtonPressedForObject:(id)object sender:(id)sender;
- (void)moreOptionsButtonPressedForObject:(id)object sender:(id)sender;
- (void)feedCell:(DFPhotoFeedCell *)feedCell selectedObjectChanged:(id)newObject fromObject:(id)oldObject;

@end


@interface DFPhotoFeedCell : DFCollectionViewTableViewCell <UICollectionViewDelegate, UICollectionViewDataSource>

// Views
@property (strong, nonatomic) IBOutlet UIButton *favoritersButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *loadingActivityIndicator;
@property (weak, nonatomic) IBOutlet UIButton *favoriteButton;
@property (weak, nonatomic) IBOutlet UIButton *moreOptionsButton;
@property (weak, nonatomic) IBOutlet UIImageView *photoImageView;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *imageViewHeightConstraint;
@property (weak, nonatomic) IBOutlet UILabel *commentsLabel;
@property (weak, nonatomic) IBOutlet UILabel *likesLabel;
@property (weak, nonatomic) IBOutlet UIImageView *likesIconImageView;
@property (weak, nonatomic) IBOutlet UIImageView *commentsIconImageView;

// Delegate
@property (nonatomic, weak) NSObject <DFPhotoFeedCellDelegate> *delegate;

- (IBAction)favoriteButtonPressed:(id)sender;
- (IBAction)moreOptionsButtonPressed:(id)sender;


typedef NS_OPTIONS(NSInteger, DFPhotoFeedCellStyle) {
  DFPhotoFeedCellStyleNone =              0,
  DFPhotoFeedCellStyleCollectionVisible = 1 << 1,
  DFPhotoFeedCellStyleHasLikes    =       1 << 2,
  DFPhotoFeedCellStyleHasComments =       1 << 3,
};

typedef NS_ENUM(NSInteger, DFPhotoFeedCellAspect) {
  DFPhotoFeedCellAspectSquare,
  DFPhotoFeedCellAspectPortrait,
  DFPhotoFeedCellAspectLandscape,
};

- (void)configureWithStyle:(DFPhotoFeedCellStyle)style aspect:(DFPhotoFeedCellAspect)aspect;
+ (DFPhotoFeedCell *)createCellWithStyle:(DFPhotoFeedCellStyle)style aspect:(DFPhotoFeedCellAspect) aspect;
- (void)setComments:(NSArray *)comments;
- (void)setLikes:(NSArray *)likes;

- (CGFloat)imageViewHeightForReferenceWidth:(CGFloat)referenceWidth;
- (CGFloat)rowHeight;


@end
