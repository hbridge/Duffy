//
//  DFPhotoFeedController.m
//  Strand
//
//  Created by Henry Bridge on 7/4/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhotoFeedController.h"
#import "DFPeanutGalleryAdapter.h"
#import "DFPhoto.h"
#import "DFPhotoCollection.h"
#import "DFMultiPhotoViewController.h"
#import "RootViewController.h"
#import "DFCGRectHelpers.h"
#import "DFStrandConstants.h"
#import "DFAnalytics.h"

@interface DFPhotoFeedController ()

@property (nonatomic, retain) NSArray *sectionNames;
@property (nonatomic, retain) NSDictionary *itemsBySection;
@property (readonly, nonatomic, retain) DFPeanutGalleryAdapter *galleryAdapter;
@property (atomic, retain) NSMutableDictionary *imageCache;
@property (atomic, retain) NSMutableDictionary *rowHeightCache;

@end

@implementation DFPhotoFeedController

@synthesize galleryAdapter = _galleryAdapter;

- (id)initWithStyle:(UITableViewStyle)style
{
  self = [super initWithStyle:style];
  if (self) {
    self.navigationItem.title = @"Shared";
    UIBarButtonItem *cameraButton = [[UIBarButtonItem alloc]
                                     initWithImage:[[UIImage imageNamed:@"Assets/Icons/CameraBarButton.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                                     style:UIBarButtonItemStylePlain
                                     target:self
                                     action:@selector(cameraButtonPressed:)];
    self.navigationItem.rightBarButtonItem = cameraButton;
    self.imageCache = [[NSMutableDictionary alloc] init];
    self.rowHeightCache = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  self.navigationController.navigationBar.tintColor = [UIColor orangeColor];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self.galleryAdapter fetchGalleryWithCompletionBlock:^(DFPeanutSearchResponse *response) {
    if (response.objects.count > 0) {
      // We need to do this work on the main thread because the DFPhoto objects that get created
      // have to be on the main thread so they can be accessed by colleciton view datasource methods
      dispatch_async(dispatch_get_main_queue(), ^{
        NSArray *peanutObjects = response.objects;
        NSArray *sectionNames = response.topLevelSectionNames;
        NSDictionary *itemsBySection = [DFPeanutSearchResponse
                                        photosBySectionForSearchObjects:peanutObjects];
        
        [self setSectionNames:sectionNames itemsBySection:itemsBySection];
      });
    }
  }];
  
  [(RootViewController *)self.view.window.rootViewController setHideStatusBar:NO];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [(RootViewController *)self.view.window.rootViewController setSwipingEnabled:YES];
  [(RootViewController *)self.view.window.rootViewController setHideStatusBar:NO];
  [[NSNotificationCenter defaultCenter] postNotificationName:DFStrandGalleryAppearedNotificationName
                                                      object:self
                                                    userInfo:nil];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
  self.imageCache = [[NSMutableDictionary alloc] init];
}

#pragma mark - Table view data source: sections

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  return self.sectionNames[section];
}

#pragma mark - Table view data source: rows

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return self.sectionNames.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  NSArray *items = [self itemsForSectionIndex:section];
  return items.count;
}

- (NSArray *)itemsForSectionIndex:(NSInteger)index
{
  if (index >= self.sectionNames.count) return nil;
  NSString *sectionName = self.sectionNames[index];
  NSArray *items = self.itemsBySection[sectionName];
  return items;
}

- (DFPhoto *)representativePhotoForIndexPath:(NSIndexPath *)indexPath
{
  NSArray *itemsForSection = [self itemsForSectionIndex:indexPath.section];
  id item = itemsForSection[indexPath.row];
  DFPhoto *representativePhoto;
  if ([[item class] isSubclassOfClass:[DFPhoto class]]) {
    representativePhoto = item;
  } else if ([[item class] isSubclassOfClass:[DFPhotoCollection class]]) {
    DFPhotoCollection *photoCollection = item;
    representativePhoto = [[photoCollection photosByDateAscending:YES] firstObject];
  }
  
  return representativePhoto;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"
                                                          forIndexPath:indexPath];
  
  cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
  UIImage *image = self.imageCache[indexPath];
  
  if (image) {
    cell.imageView.image = image;
  } else {
    cell.imageView.image = nil;
    cell.imageView.backgroundColor = [UIColor grayColor];
    
    DFPhoto *representativePhoto = [self representativePhotoForIndexPath:indexPath];
    if (representativePhoto) {
      [representativePhoto.asset loadFullScreenImage:^(UIImage *image) {
        self.imageCache[[self keyForIndexPath:indexPath]] = image;
        dispatch_async(dispatch_get_main_queue(), ^{
          [self.tableView reloadData];
        });
      } failureBlock:^(NSError *error) {
      }];
    }
  }
  
  return cell;
}

- (id)keyForIndexPath:(NSIndexPath *)indexPath
{
  if ([indexPath class] == [NSIndexPath class]) {
    return indexPath;
  }
  return [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  id key = [self keyForIndexPath:indexPath];
  NSNumber *cachedHeight = self.rowHeightCache[key];
  if (cachedHeight) return cachedHeight.floatValue;

  UIImage *image = self.imageCache[key];
  if (image) {
    CGFloat height = [DFCGRectHelpers
                      aspectFittedSize:image.size max:CGRectMake(0,0,290, 640)].size.height;
    self.rowHeightCache[key] = @(height);
    return height;
  }
  
  return 200;
}

- (void)setSectionNames:(NSArray *)sectionNames itemsBySection:(NSDictionary *)photosBySection
{
  _sectionNames = sectionNames;
  _itemsBySection = photosBySection;
  
  [self.tableView reloadData];
}

#pragma mark - Actions

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSArray *items = [self itemsForSectionIndex:indexPath.section];
  DDLogVerbose(@"item tapped at [%d, %d]", (int)indexPath.section, (int)indexPath.row);
  id item = items[indexPath.row];
  if ([[item class] isSubclassOfClass:[DFPhoto class]]) {
    DFMultiPhotoViewController *mpvc = [[DFMultiPhotoViewController alloc] init];
    [mpvc setActivePhoto:item inPhotos:items];
    [self.navigationController pushViewController:mpvc animated:YES];
  } else if ([[item class] isSubclassOfClass:[DFPhotoCollection class]]) {
    [self expandCollection:item atIndexPath:indexPath];
  }
}

- (void)expandCollection:(DFPhotoCollection *)collection atIndexPath:(NSIndexPath *)indexPath
{
  // get the photos to replace the collection with
  NSArray *photos = [collection photosByDateAscending:YES];
  
  NSMutableArray *newItemsForSection = [self itemsForSectionIndex:indexPath.section].mutableCopy;
  [newItemsForSection replaceObjectsInRange:(NSRange){indexPath.row, 1}
                       withObjectsFromArray:photos];
  NSMutableDictionary *newSections = self.itemsBySection.mutableCopy;
  newSections[self.sectionNames[indexPath.section]] = newItemsForSection;
  _itemsBySection = newSections;
  [UIView animateWithDuration:0.3 animations:^{
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section]
                  withRowAnimation:UITableViewRowAnimationTop];
  }];
}

- (void)cameraButtonPressed:(id)sender
{
  [(RootViewController *)self.view.window.rootViewController showCamera];
}

#pragma mark - Adapters

- (DFPeanutGalleryAdapter *)galleryAdapter
{
  if (!_galleryAdapter) {
    _galleryAdapter = [[DFPeanutGalleryAdapter alloc] init];
  }
  
  return _galleryAdapter;
}


@end
