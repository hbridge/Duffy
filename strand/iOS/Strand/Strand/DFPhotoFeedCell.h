//
//  DFPhotoFeedCell.h
//  Strand
//
//  Created by Henry Bridge on 7/20/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DFPhotoFeedCell;

@protocol DFPhotoFeedCellDelegate <NSObject>
@required

- (void)favoriteButtonPressedForObject:(id)object sender:(id)sender;
- (void)moreOptionsButtonPressedForObject:(id)object sender:(id)sender;
- (void)feedCell:(DFPhotoFeedCell *)feedCell selectedObjectChanged:(id)newObject fromObject:(id)oldObject;

@end


@interface DFPhotoFeedCell : UITableViewCell <UICollectionViewDelegate, UICollectionViewDataSource>

// Views
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (strong, nonatomic) IBOutlet UIButton *favoritersButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *loadingActivityIndicator;
@property (weak, nonatomic) IBOutlet UIButton *favoriteButton;
@property (weak, nonatomic) IBOutlet UIButton *moreOptionsButton;
@property (weak, nonatomic) IBOutlet UIImageView *photoImageView;
@property (strong, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UILabel *photoDateLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *imageViewHeightConstraint;

// Delegate
@property (nonatomic, weak) NSObject <DFPhotoFeedCellDelegate> *delegate;

// Objects that the cell represents
@property (strong, nonatomic) NSArray *objects;
- (void)setImage:(UIImage *)image forObject:(id)clusterObject;

- (void)setFavoritersListHidden:(BOOL)hidden;

- (IBAction)favoriteButtonPressed:(id)sender;
- (IBAction)moreOptionsButtonPressed:(id)sender;


typedef NS_OPTIONS(NSInteger, DFPhotoFeedCellStyle) {
  DFPhotoFeedCellStyleSquare = 1 << 0,
  DFPhotoFeedCellStylePortrait = 1 << 1,
  DFPhotoFeedCellStyleLandscape = 1 << 2,
  DFPhotoFeedCellStyleCollectionVisible = 1 << 3,
};

- (void)configureWithStyle:(DFPhotoFeedCellStyle)style;
+ (DFPhotoFeedCell *)createCellWithStyle:(DFPhotoFeedCellStyle)style;


- (CGFloat)imageViewHeightForReferenceWidth:(CGFloat)referenceWidth;


@end
