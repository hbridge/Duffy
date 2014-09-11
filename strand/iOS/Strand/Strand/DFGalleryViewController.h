//
//  DFGalleryViewController.h
//  Strand
//
//  Created by Henry Bridge on 8/15/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFStrandsViewController.h"
#import "DFTopBarController.h"

@interface DFGalleryViewController : DFStrandsViewController <DFStrandViewControllerDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>

@property (nonatomic, retain) UICollectionView *collectionView;
@property (nonatomic, retain) UIRefreshControl *refreshControl;


@end
