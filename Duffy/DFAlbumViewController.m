//
//  DFBrowseViewController.m
//  Duffy
//
//  Created by Henry Bridge on 1/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFAlbumViewController.h"
#import "DFPhotoStore.h"
#import "DFPhotoAlbum.h"
#import "DFPhotoViewCell.h"
#import "DFPhotosGridViewController.h"

@interface DFAlbumViewController ()

@end

@implementation DFAlbumViewController

- (id)initWithCollectionViewLayout:(UICollectionViewLayout *)layout
{
    self = [super initWithCollectionViewLayout:layout];
    if (self) {
        UINavigationItem *n = [self navigationItem];
        [n setTitle:@"Albums"];

        [self.tabBarItem setTitle:@"Albums"];
        self.tabBarItem.image = [UIImage imageNamed:@"Albums"];
        
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoViewCell" bundle:nil] forCellWithReuseIdentifier:@"DFPhotoViewCell"];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(photoStoreChanged)
                                                 name:@"com.duffysoft.DFAssetsEnumerated"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(photoStoreChanged)
                                                 name:DFPhotoStoreReadyNotification
                                               object:nil];
    
    
    ((UICollectionViewFlowLayout *)self.collectionViewLayout).itemSize =CGSizeMake(150, 200);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - UICollection view datasource/delegate

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [[[DFPhotoStore sharedStore] allAlbumsByCount] count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    DFPhotoAlbum *album = [[[DFPhotoStore sharedStore] allAlbumsByCount] objectAtIndex:indexPath.row];
    
    DFPhotoViewCell *cell = (DFPhotoViewCell *)[self.collectionView
                                                dequeueReusableCellWithReuseIdentifier:@"DFPhotoViewCell" forIndexPath:indexPath];
    
    if (!album.thumbnail) {
        [album addObserver:self forKeyPath:@"thumbnail" options:NSKeyValueObservingOptionNew context:(__bridge_retained void *)indexPath];
    }
    [cell.imageView setImage:album.thumbnail];
	
    [cell.textLabel setText:[NSString stringWithFormat:@"%@ (%d)", album.name, (int)album.photos.count]];
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    DFPhotoAlbum *album = [[[DFPhotoStore sharedStore] allAlbumsByCount] objectAtIndex:indexPath.row];
    
    DFPhotosGridViewController *photosController = [[DFPhotosGridViewController alloc] init];
    photosController.photos = album.photos;
    [self.navigationController pushViewController:photosController animated:YES];
    
}

#pragma mark - Notifications and KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"thumbnail"]) {
        NSIndexPath *indexPath = (__bridge NSIndexPath *)context;
        NSLog(@"browse thumbnail change detected at [%d, %d]", indexPath.section, indexPath.row);
        if ([[self.collectionView indexPathsForVisibleItems] containsObject:indexPath]) {
            DFPhotoViewCell* correctCell = (DFPhotoViewCell*)[self.collectionView cellForItemAtIndexPath:indexPath];
            correctCell.imageView.image = [((DFPhotoAlbum *)object) thumbnail];
            [correctCell setNeedsLayout];
        }
    }
}

- (void)photoStoreChanged
{
    [self.collectionView reloadData];
}

@end
