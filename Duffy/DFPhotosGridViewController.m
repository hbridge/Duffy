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
#import "DFMultiPhotoViewController.h"

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

    [photo loadUIImageForFullImage:^(UIImage *fullImage) {
        [self pushPhotoViewForPhoto:photo withFullImage:fullImage atIndexPath:indexPath];
    } failureBlock:^(NSError *error) {
        NSLog(@"Could not load photo for picture tapped: %@", error.localizedDescription);
    }];
}

- (void)pushPhotoViewForPhoto:(DFPhoto *)photo
                withFullImage:(UIImage *)fullImage
                  atIndexPath:(NSIndexPath *)indexPath
{
    
    DFPhotoViewController *pvc = [[DFPhotoViewController alloc] init];
    pvc.image = fullImage;
    pvc.indexPathInParent = indexPath;
    
    
    DFMultiPhotoViewController *multiPhotoController = [[DFMultiPhotoViewController alloc] init];
    multiPhotoController.dataSource = self;
    [multiPhotoController setViewControllers:[NSArray arrayWithObject:pvc] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:^(BOOL finished) {
        //
    }];
    
    DFPhotoNavigationControllerViewController *photoNavController = (DFPhotoNavigationControllerViewController *)self.navigationController;
    [photoNavController pushMultiPhotoViewController:multiPhotoController
                        withFrontPhotoViewController:pvc
                            fromPhotosGridController:self
                                     itemAtIndexPath:indexPath];
}


#pragma mark - DFMultiPhotoPageView datasource

- (UIViewController*)pageViewController:(UIPageViewController *)pageViewController
     viewControllerBeforeViewController:(UIViewController *)viewController
{
    NSIndexPath *indexPath = ((DFPhotoViewController*)viewController).indexPathInParent;
    
    if (indexPath.row == 0) return nil;
    
    DFPhoto *photo = [self.photos objectAtIndex:indexPath.row -1];
    DFPhotoViewController *pvc = [[DFPhotoViewController alloc] init];
    pvc.image = photo.fullImage;
    pvc.indexPathInParent = [NSIndexPath indexPathForRow:indexPath.row - 1 inSection:indexPath.section];
    return pvc;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
       viewControllerAfterViewController:(UIViewController *)viewController
{
    NSIndexPath *indexPath = ((DFPhotoViewController*)viewController).indexPathInParent;
    
    if (indexPath.row == self.photos.count -1) return nil;
    
    DFPhoto *photo = [self.photos objectAtIndex:indexPath.row + 1];
    DFPhotoViewController *pvc = [[DFPhotoViewController alloc] init];
    pvc.image = photo.fullImage;
    pvc.indexPathInParent = [NSIndexPath indexPathForRow:indexPath.row + 1 inSection:indexPath.section];
    return pvc;
}

- (CGRect)frameForCellAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewLayoutAttributes *layoutAttributes = [self.collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
    if (layoutAttributes) {
        CGRect frame = layoutAttributes.frame;
        return CGRectMake(frame.origin.x,
                                 frame.origin.y + self.topLayoutGuide.length - self.collectionView.contentOffset.y,
                                 frame.size.width,
                                 frame.size.height);
    }
    
    return CGRectZero;
}

@end
