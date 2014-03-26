//
//  DFTimelineViewController.m
//  Duffy
//
//  Created by Henry Bridge on 1/29/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPhotosGridViewController.h"
#import "DFPhoto.h"
#import "DFPhotoViewCell.h"
#import "DFPhotoViewController.h"
#import "DFPhotoNavigationControllerViewController.h"

@interface DFPhotosGridViewController ()

@end

@implementation DFPhotosGridViewController

@synthesize photoSpacing;
@synthesize photoSquareSize;

static const CGFloat DEFAULT_PHOTO_SQUARE_SIZE = 77;
static const CGFloat DEFAULT_PHOTO_SPACING = 4;


@synthesize photos;

- (id)init
{
    self = [super initWithNibName:@"DFPhotosGridViewController" bundle:[NSBundle mainBundle]];
    if (self) {
        self.tabBarItem.title = @"Photos";
        self.tabBarItem.image = [UIImage imageNamed:@"Timeline"];
        
        UINavigationItem *n = [self navigationItem];
        [n setTitle:@"Photos"];
        
        photoSquareSize = DEFAULT_PHOTO_SQUARE_SIZE;
        photoSpacing = DEFAULT_PHOTO_SPACING;
        
        self.photos = [[NSArray alloc] init];
    }
    return self;
}

- (id)initWithPhotos:(NSArray *)newPhotos
{
    self = [self init];
    if (self) {
        self.photos = newPhotos;
    }
    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // configure our flow layout
    self.flowLayout = [[UICollectionViewFlowLayout alloc] init];
    self.flowLayout.itemSize =CGSizeMake(self.photoSquareSize, self.photoSquareSize);
    self.flowLayout.minimumInteritemSpacing = self.photoSpacing;
    self.flowLayout.minimumLineSpacing = self.photoSpacing;
    [self.collectionView setCollectionViewLayout:self.flowLayout];
    self.collectionView.contentInset = UIEdgeInsetsMake(self.photoSpacing, 0, 0, 0);
    
    // register cell type
    [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoViewCell" bundle:nil] forCellWithReuseIdentifier:@"DFPhotoViewCell"];
    
    // set background
    self.collectionView.backgroundColor = [UIColor whiteColor];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setPhotos:(NSArray *)newPhotos
{
    photos = newPhotos;
    [self.collectionView reloadData];
}


#pragma mark - UICollectionView datasource/delegate methods

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.photos.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    DFPhoto *photo = [self.photos objectAtIndex:indexPath.row];
    
    DFPhotoViewCell *cell = (DFPhotoViewCell *)[self.collectionView
                                  dequeueReusableCellWithReuseIdentifier:@"DFPhotoViewCell" forIndexPath:indexPath];
    
    
    [photo createCGImageForThumbnail:^(CGImageRef imageRef) {
        if ([[self.collectionView indexPathsForVisibleItems] containsObject:indexPath]) {
            DFPhotoViewCell* correctCell = (DFPhotoViewCell*)[self.collectionView
                                                              cellForItemAtIndexPath:indexPath];
            correctCell.imageView.image = [UIImage imageWithCGImage:imageRef];
            [correctCell setNeedsLayout];
            CGImageRelease(imageRef);
        }
    } failureBlock:^(NSError *error) {
        NSLog(@"image load failed");
    }];
    [cell.imageView setImage:[photo thumbnail]];
    
    return cell;
}

#pragma mark - Notification responders

- (void)assetsEnumerated
{
    [self.collectionView reloadData];
}


#pragma mark - Action Handlers

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    DFPhoto *photo = [self.photos objectAtIndex:indexPath.row];
    UICollectionViewCell __block *cell = [collectionView cellForItemAtIndexPath:indexPath];
    NSLog(@"Photo tapped: %@", photo.metadataDictionary);
    
    
    [photo createCGImageForFullImage:^(CGImageRef imageRef) {
        UIImage *image = [UIImage imageWithCGImage:imageRef];
        CGImageRelease(imageRef);
        
        [self pushPhotoViewWithCell:cell image:image];
    } failureBlock:^(NSError *error) {
        NSLog(@"Could not load photo for picture tapped: %@", error.localizedDescription);
    }];
    
    
//    [UIView transitionFromView:self.view
//                        toView:pvc.view
//                      duration:0.75
//                       options:UIViewAnimationOptionTransitionCrossDissolve
//                    completion:^(BOOL finished) {
//                        [self.navigationController pushViewController:pvc animated:NO];
//                    }];

   
}

- (void)pushPhotoViewWithCell:(UICollectionViewCell *)cell image:(UIImage *)image
{
    DFPhotoViewController *pvc = [[DFPhotoViewController alloc] init];
    pvc.image = image;
    
    DFPhotoNavigationControllerViewController *photoNavController = (DFPhotoNavigationControllerViewController *)self.navigationController;
    
    [photoNavController pushPhotoViewController:pvc fromCellView:cell];
}

@end
