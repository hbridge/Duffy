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

@interface DFPhotosGridViewController ()

@end

@implementation DFPhotosGridViewController

@synthesize photos;

- (id)init
{
    self = [super initWithCollectionViewLayout:[[UICollectionViewFlowLayout alloc] init]];
    if (self) {
        self.tabBarItem.title = @"Photos";
        self.tabBarItem.image = [UIImage imageNamed:@"Timeline"];
        
        UINavigationItem *n = [self navigationItem];
        [n setTitle:@"Photos"];
        
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
    [cell.textLabel setText:[NSString stringWithFormat:@"Photo %d", indexPath.row+1]];
    
    return cell;
}



#pragma mark - Notification responders

- (void)assetsEnumerated
{
    [self.collectionView reloadData];
}



@end
