//
//  DFSelectPhotosViewController.h
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFImageDataSource.h"
#import "DFSelectablePhotoViewCell.h"

@class DFSelectPhotosController;

@protocol DFSelectPhotosControllerDelegate <NSObject>

- (void)selectPhotosController:(DFSelectPhotosController *)selectPhotosController
    selectedFeedObjectsChanged:(NSArray *)newSelectedFeedObjects;

@end


@interface DFSelectPhotosController : DFImageDataSource <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, DFSelectablePhotoViewCellDelegate>

@property (nonatomic, retain) NSMutableArray *selectedFeedObjects;
@property (nonatomic, weak) UICollectionView *collectionView;
@property (nonatomic, weak) id<DFSelectPhotosControllerDelegate> delegate;
@property (nonatomic) BOOL areImagesRemote;

- (NSArray *)selectedPhotoIDs;
- (void)toggleSectionSelection:(NSUInteger)section;
- (NSSet *)selectedItemsFromSection:(NSUInteger)section;
- (NSArray *)collectionFeedObjectsWithSelectedObjects;

@end
