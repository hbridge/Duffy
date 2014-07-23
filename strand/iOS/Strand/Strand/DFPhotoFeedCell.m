//
//  DFPhotoFeedCell.m
//  Strand
//
//  Created by Henry Bridge on 7/20/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhotoFeedCell.h"
#import "DFPhotoViewCell.h"

@interface DFPhotoFeedCell()

@property (nonatomic, retain) NSMutableDictionary *savedConstraints;
@property (nonatomic, retain) NSMutableDictionary *imagesForObjects;
@property (nonatomic, retain) id selectedObject;

@end

@implementation DFPhotoFeedCell

- (void)awakeFromNib
{
  self.imageView.contentMode = UIViewContentModeScaleAspectFill;
  self.favoritersButton.titleEdgeInsets = UIEdgeInsetsMake(0, 4, 0, 0);
  self.savedConstraints = [NSMutableDictionary new];
  [self saveConstraints];
  
  self.collectionView.delegate = self;
  self.collectionView.dataSource = self;
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoViewCell" bundle:nil]
        forCellWithReuseIdentifier:@"cell"];
  self.collectionView.backgroundColor = [UIColor clearColor];
  
  [self configureButtonActions];
}

- (void)configureButtonActions
{
  [self.favoriteButton addTarget:self
                          action:@selector(favoriteButtonPressed:)
                forControlEvents:UIControlEventTouchUpInside];
  [self.moreOptionsButton addTarget:self
                          action:@selector(moreOptionsButtonPressed:)
                forControlEvents:UIControlEventTouchUpInside];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  //self.imageView.frame = self.imageViewPlaceholder.frame;
  self.imageView.clipsToBounds = YES;
}

- (void)setFavoritersListHidden:(BOOL)hidden
{
  if (hidden) {
    [self.favoritersButton removeFromSuperview];
  } else {
    if (!self.favoritersButton.superview || !self.favoritersButton) {
      DDLogVerbose(@"Re adding favoriters button: %@", self.favoritersButton);
      [self.contentView addSubview:self.favoritersButton];
      [self loadConstraintsForView:self.favoritersButton];
    }
  }
}

- (void)setClusterViewHidden:(BOOL)hidden
{
  if (hidden) {
    [self.collectionView removeFromSuperview];
  } else {
    [self.contentView addSubview:self.collectionView];
    [self loadConstraintsForView:self.collectionView];
  }
}

- (void)setObjects:(NSArray *)objects
{
  _objects = objects;
  self.imagesForObjects = [NSMutableDictionary new];
  self.selectedObject = [objects firstObject];
  [self.collectionView reloadData];
}

- (void)setImage:(UIImage *)image forObject:(id)object
{
  self.imagesForObjects[object] = image;
  [self.collectionView reloadData];
  if ([object isEqual:self.selectedObject]) self.photoImageView.image = image;
}

- (void)saveConstraints
{
  NSArray *viewsToSave = @[self.favoritersButton, self.collectionView];
  for (UIView *view in viewsToSave) {
    NSMutableArray *viewConstraints = [NSMutableArray new];
    for (NSLayoutConstraint *con in self.contentView.constraints) {
      if (con.firstItem == view || con.secondItem == view) {
        [viewConstraints addObject:con];
      }
    }
    self.savedConstraints[view.restorationIdentifier] = viewConstraints;
  }
}

- (void)loadConstraintsForView:(UIView *)view
{
  NSArray *constraints = self.savedConstraints[view.restorationIdentifier];
  for (NSLayoutConstraint *constraint in constraints) {
    // Ensure that both items that the constraint is referring to are in the view
    UIView *firstItem = constraint.firstItem;
    UIView *secondItem = constraint.secondItem;
    if ([firstItem superview] && [secondItem superview]) {
      [self.contentView addConstraint:constraint];
    }
  }
}

- (UIImageView *)imageView
{
  return self.photoImageView;
}


#pragma mark - UICollectionView methods

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  return self.objects.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  DFPhotoViewCell *cell = [self.collectionView
                           dequeueReusableCellWithReuseIdentifier:@"cell"
                           forIndexPath:indexPath];
  
  id object = self.objects[indexPath.row];
  cell.imageView.image = self.imagesForObjects[object];
  cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
  cell.imageView.clipsToBounds = YES;
  cell.imageView.backgroundColor = [UIColor grayColor];
  
  return cell;
}

- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
  id object = self.objects[indexPath.row];
  self.imageView.image = self.imagesForObjects[object];
  self.selectedObject = object;
}

#pragma mark - Action handlers

- (void)favoriteButtonPressed:(UIButton *)sender
{
  if (self.delegate) {
    [self.delegate favoriteButtonPressedForObject:self.selectedObject];
  }
}

- (void)moreOptionsButtonPressed:(UIButton *)sender
{
  if (self.delegate) {
    [self.delegate moreOptionsButtonPressedForObject:self.selectedObject];
  }
}


@end
