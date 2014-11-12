//
//  DFPhotoFeedCell.m
//  Strand
//
//  Created by Henry Bridge on 7/20/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhotoFeedCell.h"
#import <Slash/Slash.h>
#import "DFPhotoViewCell.h"
#import "DFStrandConstants.h"
#import "DFPeanutAction.h"


@interface DFPhotoFeedCell()

@property (nonatomic, retain) NSMutableDictionary *savedConstraints;
@property (nonatomic, retain) NSMutableDictionary *imagesForObjects;
@property (nonatomic, retain) id selectedObject;
@property (nonatomic) DFPhotoFeedCellStyle style;
@property (nonatomic) DFPhotoFeedCellAspect aspect;

@end

@implementation DFPhotoFeedCell

- (void)awakeFromNib
{
  [super awakeFromNib];
  [self configureView];
  UITapGestureRecognizer *doubleTapRecognizer = [[UITapGestureRecognizer alloc]
                                                initWithTarget:self
                                                action:@selector(favoriteButtonPressed:)];
  doubleTapRecognizer.numberOfTapsRequired = 2;
  [self.photoImageView addGestureRecognizer:doubleTapRecognizer];
}

- (void)configureView
{
  self.imageView.contentMode = UIViewContentModeScaleAspectFill;
  self.favoritersButton.titleEdgeInsets = UIEdgeInsetsMake(0, 4, 0, 0);
  [self.favoritersButton setTitleColor:[DFStrandConstants weakFeedForegroundTextColor]
                              forState:UIControlStateNormal];
  
  self.collectionView.scrollsToTop = NO;
  self.collectionView.delegate = self;
  self.collectionView.dataSource = self;
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoViewCell" bundle:nil]
        forCellWithReuseIdentifier:@"cell"];
  self.collectionView.backgroundColor = [UIColor clearColor];
}

- (void)configureWithStyle:(DFPhotoFeedCellStyle)style aspect:(DFPhotoFeedCellAspect)aspect
{
  _style = style;
  _aspect = aspect;
  
  if (!(style & DFPhotoFeedCellStyleCollectionVisible)) {
    [self.collectionView removeFromSuperview];
  }
  
  if (!(style & DFPhotoFeedCellStyleHasLikes)) {
    [self.likesLabel removeFromSuperview];
    [self.likesIconImageView removeFromSuperview];
  }
  
  if (!(style & DFPhotoFeedCellStyleHasComments)) {
    [self.commentsLabel removeFromSuperview];
    [self.commentsIconImageView removeFromSuperview];
  }
}

+ (DFPhotoFeedCell *)createCellWithStyle:(DFPhotoFeedCellStyle)style
                                  aspect:(DFPhotoFeedCellAspect)aspect
{
  DFPhotoFeedCell *cell =
  [[[UINib nibWithNibName:NSStringFromClass([DFPhotoFeedCell class]) bundle:nil]
    instantiateWithOwner:nil options:nil]
   firstObject];
  [cell configureWithStyle:style aspect:aspect];
  return cell;
}

#pragma mark - Set Cell Properties

- (void)setObjects:(NSArray *)objects
{
  [super setObjects:objects];
  self.selectedObject = [objects firstObject];
}

- (void)setSelectedObject:(id)selectedObject
{
  _selectedObject = selectedObject;
  [self setLargeImage:self.imagesForObjects[selectedObject]];
}

- (void)setImage:(UIImage *)image forObject:(id)object
{
  [super setImage:image forObject:object];
  if ([object isEqual:self.selectedObject]) [self setLargeImage:image];
}

- (void)setLargeImage:(UIImage *)image
{
  self.photoImageView.image = image;
  if (image.size.height < self.photoImageView.frame.size.height * .75) {
    [self.loadingActivityIndicator startAnimating];
    self.photoImageView.alpha = 0.5;
  } else {
    [self.loadingActivityIndicator stopAnimating];
    self.photoImageView.alpha = 1.0;
  }
}

- (void)setComments:(NSArray *)comments
{
  NSMutableString *slashFormat = [NSMutableString new];
  [slashFormat appendString:@"<feedText>"];
  for (DFPeanutAction *action in comments) {
    [slashFormat appendFormat:@"<name>%@</name> %@", action.user_display_name, action.text];
    if (action != comments.lastObject) [slashFormat appendString:@"\n"];
  }
  [slashFormat appendString:@"</feedText>"];
  
  NSError *error;
  NSAttributedString *commentsString = [SLSMarkupParser attributedStringWithMarkup:slashFormat
                                                                             style:[DFStrandConstants defaultTextStyle]
                                                                             error:&error];
  if (error) {
    DDLogError(@"Error parsing format:%@", error);
  }
  
  self.commentsLabel.attributedText = commentsString;
}

- (void)setLikes:(NSArray *)likes
{
  NSMutableString *slashFormat = [NSMutableString new];
  for (DFPeanutAction *action in likes) {
    [slashFormat appendFormat:@"<name>%@</name>", action.user_display_name];
    if (action != likes.lastObject) [slashFormat appendString:@", "];
  }
  
  NSError *error;
  NSAttributedString *likesString = [SLSMarkupParser attributedStringWithMarkup:slashFormat
                                                                             style:[DFStrandConstants defaultTextStyle]
                                                                             error:&error];
  if (error) {
    DDLogError(@"Error parsing format:%@", error);
  }
  
  self.likesLabel.attributedText = likesString;
}


#pragma mark - UICollectionView Delegate

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
  id oldObject = self.selectedObject;
  id object = self.objects[indexPath.row];
  [self setLargeImage:self.imagesForObjects[object]];
  self.selectedObject = object;
  if (self.delegate) {
    [self.delegate feedCell:self selectedObjectChanged:object fromObject:oldObject];
  }
}

#pragma mark - Action handlers

- (IBAction)favoriteButtonPressed:(id)sender
{
  if (self.delegate) {
    [self.delegate favoriteButtonPressedForObject:self.selectedObject sender:sender];
  }
}
- (IBAction)commentButtonPressed:(UIButton *)sender {
  [self.delegate commentButtonPressedForObject:self.selectedObject sender:self];
}

- (IBAction)moreOptionsButtonPressed:(id)sender
{
  if (self.delegate) {
    [self.delegate moreOptionsButtonPressedForObject:self.selectedObject sender:sender];
  }
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  self.imageView.clipsToBounds = YES;
  
  self.imageViewHeightConstraint.constant =
    [self imageViewHeightForReferenceWidth:self.frame.size.width];
  
  if (self.commentsLabel.preferredMaxLayoutWidth != self.commentsLabel.frame.size.width) {
    self.commentsLabel.preferredMaxLayoutWidth = self.commentsLabel.frame.size.width;
    [self setNeedsLayout];
  }
  
  if (self.likesLabel.preferredMaxLayoutWidth != self.likesLabel.frame.size.width) {
    self.likesLabel.preferredMaxLayoutWidth = self.likesLabel.frame.size.width;
    [self setNeedsLayout];
  }
}

- (CGFloat)imageViewHeightForReferenceWidth:(CGFloat)referenceWidth
{
  CGFloat height = 0.0;
  if (self.aspect == DFPhotoFeedCellAspectSquare) {
    height = referenceWidth;
  } else if (self.aspect == DFPhotoFeedCellAspectPortrait) {
    height = referenceWidth * (4.0/3.0);
  } else if (self.aspect == DFPhotoFeedCellAspectLandscape) {
    height = referenceWidth * (3.0/4.0);
  }
  return height;
}

- (CGSize)commentAreaSize
{
  CGSize size = [self.commentsLabel sizeThatFits:self.commentsLabel.frame.size];
  return size;
}

- (CGFloat)rowHeight
{
  CGFloat height = [self.contentView
                    systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height + 1.0;
  
  return height;
}

@end
