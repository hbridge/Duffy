//
//  DFBrowseViewController.m
//  Duffy
//
//  Created by Henry Bridge on 1/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFBrowseViewController.h"
#import "DFPhotoStore.h"
#import "DFPhotoAlbum.h"
#import "DFPhotoViewCell.h"
#import "DFPhotosGridViewController.h"

@interface DFBrowseViewController ()

@end

@implementation DFBrowseViewController

- (id)initWithCollectionViewLayout:(UICollectionViewLayout *)layout
{
    self = [super initWithCollectionViewLayout:layout];
    if (self) {
        UINavigationItem *n = [self navigationItem];
        [n setTitle:@"Browse"];

        [self.tabBarItem setTitle:@"Browse"];
        self.tabBarItem.image = [UIImage imageNamed:@"Browse"];
        
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [self.collectionView registerNib:[UINib nibWithNibName:@"DFPhotoViewCell" bundle:nil] forCellWithReuseIdentifier:@"DFPhotoViewCell"];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(assetsEnumerated)
                                                 name:@"com.duffysoft.DFAssetsEnumerated"
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


- (void)assetsEnumerated
{
    [self.collectionView reloadData];
}

@end
