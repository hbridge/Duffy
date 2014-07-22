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
#import "DFImageStore.h"
#import "DFPeanutPhoto.h"
#import "DFPhotoFeedCell.h"
#import "DFPeanutSearchResponse.h"
#import "DFPeanutSearchObject.h"
#import "NSString+DFHelpers.h"
#import "DFPeanutActionAdapter.h"
#import "DFSettingsViewController.h"
#import "DFFeedSectionHeaderView.h"
#import "DFNavigationController.h"
#import "DFPhotoStore.h"
#import "DFPhotoMetadataAdapter.h"
#import "UIAlertView+DFHelpers.h"

const CGFloat DefaultRowHeight = 467;
const NSTimeInterval FeedChangePollFrequency = 1.0;

@interface DFPhotoFeedController ()

@property (nonatomic, retain) NSArray *sectionObjects;
@property (nonatomic, retain) NSDictionary *indexPathsByID;
@property (nonatomic, retain) NSDictionary *objectsByID;
@property (atomic, retain) NSMutableDictionary *imageCache;
@property (atomic, retain) NSMutableDictionary *rowHeightCache;
@property (nonatomic) DFPhotoIDType actionSheetPhotoID;

@property (readonly, nonatomic, retain) DFPeanutGalleryAdapter *galleryAdapter;
@property (readonly, nonatomic, retain) DFPhotoMetadataAdapter *photoAdapter;

@property (nonatomic, retain) NSData *lastResponseHash;
@property (nonatomic, retain) NSTimer *autoRefreshTimer;

@end

@implementation DFPhotoFeedController

@synthesize galleryAdapter = _galleryAdapter;
@synthesize photoAdapter = _photoAdapter;

- (id)initWithStyle:(UITableViewStyle)style
{
  self = [super initWithStyle:style];
  if (self) {
    self.navigationItem.title = @"Shared";
    [self setNavigationButtons];
    self.imageCache = [[NSMutableDictionary alloc] init];
    self.rowHeightCache = [[NSMutableDictionary alloc] init];
    [self observeNotifications];
  }
  return self;
}

- (void)setNavigationButtons
{
  if (!(self.navigationItem.rightBarButtonItems.count > 0)) {
    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc]
                                       initWithImage:[[UIImage imageNamed:@"Assets/Icons/SettingsBarButton.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                                       style:UIBarButtonItemStylePlain
                                       target:self
                                       action:@selector(settingsButtonPressed:)];
    UIBarButtonItem *cameraButton = [[UIBarButtonItem alloc]
                                     initWithImage:[[UIImage imageNamed:@"Assets/Icons/CameraBarButton.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                                     style:UIBarButtonItemStylePlain
                                     target:self
                                     action:@selector(cameraButtonPressed:)];
    
    self.navigationItem.leftBarButtonItems = @[settingsButton];
    self.navigationItem.rightBarButtonItems = @[cameraButton];
  }
}

- (void)observeNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(applicationDidBecomeActive:)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(applicationDidEnterBackground:)
                                               name:UIApplicationDidEnterBackgroundNotification
                                             object:nil];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self.tableView registerNib:[UINib nibWithNibName:@"DFPhotoFeedCell" bundle:nil]
       forCellReuseIdentifier:@"cell"];
  [self.tableView registerNib:[UINib nibWithNibName:@"DFFeedSectionHeaderView" bundle:nil] forHeaderFooterViewReuseIdentifier:@"sectionHeader"];
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  self.navigationController.navigationBar.tintColor = [UIColor orangeColor];
  self.tableView.rowHeight = DefaultRowHeight;
  
  self.refreshControl = [[UIRefreshControl alloc] init];
  [self.refreshControl addTarget:self action:@selector(reloadFeed) forControlEvents:UIControlEventValueChanged];
  [self.tableView addSubview:self.refreshControl];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self reloadFeedIsSilent:NO];
  
  [(RootViewController *)self.view.window.rootViewController setHideStatusBar:NO];
}

- (void)reloadFeedIsSilent:(BOOL)isSilent
{
  if (!isSilent)
    [self.refreshControl beginRefreshing];
  [self.galleryAdapter fetchGalleryWithCompletionBlock:^(DFPeanutSearchResponse *response,
                                                         NSData *hashData) {
    if (response.objects.count > 0 && ![hashData isEqual:self.lastResponseHash]) {
      DDLogInfo(@"New feed data detected. Re-rendering feed.");
      dispatch_async(dispatch_get_main_queue(), ^{
        [self setSectionObjects:response.topLevelSectionObjects];
      });
      self.lastResponseHash = hashData;
    }
    if (!isSilent) {
      [self.refreshControl endRefreshing];
    }
  }];
}

- (void)reloadFeed
{
  [self reloadFeedIsSilent:NO];
}

- (void)autoReloadFeed
{
  [self reloadFeedIsSilent:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [(RootViewController *)self.view.window.rootViewController setSwipingEnabled:YES];
  [(RootViewController *)self.view.window.rootViewController setHideStatusBar:NO];
  [[NSNotificationCenter defaultCenter] postNotificationName:DFStrandGalleryAppearedNotificationName
                                                      object:self
                                                    userInfo:nil];
  self.autoRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:FeedChangePollFrequency
                                                           target:self
                                                         selector:@selector(autoReloadFeed)
                                                         userInfo:nil
                                                          repeats:YES];
  
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [self.autoRefreshTimer invalidate];
  self.autoRefreshTimer = nil;
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
  self.imageCache = [[NSMutableDictionary alloc] init];
}

#pragma mark - Table view data source: sections



- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
  DFFeedSectionHeaderView *headerView =
  [self.tableView dequeueReusableHeaderFooterViewWithIdentifier:@"sectionHeader"];
 
  DFPeanutSearchObject *sectionObject = self.sectionObjects[section];
  headerView.titleLabel.text = sectionObject.title;
  headerView.subtitleLabel.text = sectionObject.subtitle;
  
  return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
  return 58.0;
}

#pragma mark - Table view data source: rows

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return self.sectionObjects.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  NSArray *items = [self itemsForSectionIndex:section];
  return items.count;
}

- (NSArray *)itemsForSectionIndex:(NSInteger)index
{
  if (index >= self.sectionObjects.count) return nil;
  DFPeanutSearchObject *sectionObject = self.sectionObjects[index];
  NSArray *items = sectionObject.objects;
  return items;
}

- (DFPeanutSearchObject *)representativePhotoForIndexPath:(NSIndexPath *)indexPath
{
  NSArray *itemsForSection = [self itemsForSectionIndex:indexPath.section];
  DFPeanutSearchObject *object = itemsForSection[indexPath.row];
  
  if ([object.type isEqual:DFSearchObjectPhoto]) {
    return object;
  } else if ([object.type isEqual:DFSearchObjectCluster]) {
    return [object.objects firstObject];
  }
  
  return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  DFPhotoFeedCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"
                                                          forIndexPath:indexPath];

  UIImage *image = self.imageCache[indexPath];
  
  DFPeanutSearchObject *representativeObject = [self representativePhotoForIndexPath:indexPath];
  //DDLogVerbose(@"cellForRowAtIndexPath: [%d, %d] photoID: %llu", (int)indexPath.section, (int)indexPath.row, representativeObject.id);
  [self addCellButtonActions:cell object:representativeObject];
  
  if (image) {
    cell.imageView.image = image;
  } else {
    cell.imageView.image = nil;
    [cell.loadingActivityIndicator startAnimating];
    
    if (representativeObject) {
      [[DFImageStore sharedStore]
       imageForID:representativeObject.id
       preferredType:DFImageFull
       thumbnailPath:representativeObject.thumb_image_path
       fullPath:representativeObject.full_image_path
       completion:^(UIImage *image) {
         if (image) {
           self.imageCache[indexPath] = image;
         }
         dispatch_async(dispatch_get_main_queue(), ^{
           if (![tableView.visibleCells containsObject:cell]) return;
           cell.imageView.image = image;
           [cell.loadingActivityIndicator stopAnimating];
           [cell setNeedsLayout];
         });
       }];
    }
  }
  
  [DFPhotoFeedController configureNonImageAttributesForCell:cell
                                               searchObject:representativeObject];
  [cell setNeedsLayout];
  return cell;
}

- (void)addCellButtonActions:(DFPhotoFeedCell *)cell object:(DFPeanutSearchObject *)object
{
  if (![cell.favoriteButton actionsForTarget:self forControlEvent:UIControlEventTouchUpInside]) {
    [cell.favoriteButton addTarget:self action:@selector(favoriteButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
  }
  cell.favoriteButton.tag = (NSInteger)object.id;

  if (![cell.moreOptionsButton actionsForTarget:self forControlEvent:UIControlEventTouchUpInside]) {
    [cell.moreOptionsButton addTarget:self action:@selector(moreOptionsButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
  }
  cell.moreOptionsButton.tag = (NSInteger)object.id;
}

+ (void)configureNonImageAttributesForCell:(DFPhotoFeedCell *)cell
                              searchObject:(DFPeanutSearchObject *)searchObject
{
  cell.titleLabel.text = searchObject.user_display_name;
  
  if (searchObject.actions.count > 0) {
    [cell setFavoritersListHidden:NO];
    NSArray *likerNames = [DFPeanutAction arrayOfLikerNamesFromActions:searchObject.actions];
    NSString *likerNamesString = [NSString stringWithCommaSeparatedStrings:likerNames];
    [cell.favoritersButton setTitle:likerNamesString forState:UIControlStateNormal];
    cell.favoriteButton.selected = (searchObject.userFavoriteAction != nil);
  } else {
    cell.favoriteButton.selected = NO;
    [cell setFavoritersListHidden:YES];
  }
}


- (id)keyForIndexPath:(NSIndexPath *)indexPath
{
  if ([indexPath class] == [NSIndexPath class]) {
    return indexPath;
  }
  return [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section];
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return DefaultRowHeight;
}

- (void)setSectionObjects:(NSArray *)sectionObjects
{
  NSMutableDictionary *objectsByID = [NSMutableDictionary new];
  NSMutableDictionary *indexPathsByID = [NSMutableDictionary new];
  
  for (NSUInteger sectionIndex = 0; sectionIndex < sectionObjects.count; sectionIndex++) {
    NSArray *objectsForSection = [sectionObjects[sectionIndex] objects];
    for (NSUInteger objectIndex = 0; objectIndex < objectsForSection.count; objectIndex++) {
      DFPeanutSearchObject *object = objectsForSection[objectIndex];
      NSIndexPath *indexPath = [NSIndexPath indexPathForRow:objectIndex inSection:sectionIndex];
      if ([object.type isEqual:DFSearchObjectPhoto]) {
        objectsByID[@(object.id)] = object;
        indexPathsByID[@(object.id)] = indexPath;
      } else if ([object.type isEqual:DFSearchObjectCluster]) {
        for (DFPeanutSearchObject *subObject in object.objects) {
          objectsByID[@(subObject.id)] = subObject;
          indexPathsByID[@(subObject.id)] = indexPath;
        }
      }
    }
  }
  
  _objectsByID = objectsByID;
  _indexPathsByID = indexPathsByID;
  _sectionObjects = sectionObjects;
  _imageCache = [NSMutableDictionary new];
  
  [self.tableView reloadData];
}

#pragma mark - Actions

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  DDLogVerbose(@"Row tapped");
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)cameraButtonPressed:(id)sender
{
  [(RootViewController *)self.view.window.rootViewController showCamera];
}

- (void)settingsButtonPressed:(id)sender
{
  DFSettingsViewController *svc = [[DFSettingsViewController alloc] init];
  [self presentViewController:[[DFNavigationController alloc] initWithRootViewController:svc]
                     animated:YES
                   completion:nil];
}

- (void)favoriteButtonPressed:(UIButton *)sender
{
  DDLogVerbose(@"Favorite button pressed");

  DFPhotoIDType photoID = sender.tag;
  DFPeanutSearchObject *object = self.objectsByID[@(photoID)];
  DFPeanutAction *oldFavoriteAction = [[object actionsOfType:DFActionFavorite
                                             forUser:[[DFUser currentUser] userID]]
                               firstObject];
  DFPeanutAction *newAction;
  if (!oldFavoriteAction) {
    newAction = [[DFPeanutAction alloc] init];
    newAction.user = [[DFUser currentUser] userID];
    newAction.action_type = DFActionFavorite;
    newAction.photo = photoID;
  } else {
    newAction = nil;
  }
  
  [object setUserFavoriteAction:newAction];
  
  [self reloadRowForPhotoID:photoID];
  
  DFPeanutActionResponseBlock responseBlock = ^(DFPeanutAction *action, NSError *error) {
    if (!error) {
      if (action) {
        [object setUserFavoriteAction:action];
      } // no need for the else case, it was already removed optimistically
      
      [DFAnalytics logPhotoLikePressedWithNewValue:(newAction != nil) result:DFAnalyticsValueResultSuccess];
    } else {
      [object setUserFavoriteAction:oldFavoriteAction];
      [self reloadRowForPhotoID:photoID];
      UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                      message:error.localizedDescription
                                                     delegate:nil
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:nil];
      [alert show];
      [DFAnalytics logPhotoLikePressedWithNewValue:(newAction != nil) result:DFAnalyticsValueResultFailure];
    }
  };
  
  DFPeanutActionAdapter *adapter = [[DFPeanutActionAdapter alloc] init];
  if (!oldFavoriteAction) {
    [adapter postAction:newAction withCompletionBlock:responseBlock];
  } else {
    [adapter deleteAction:oldFavoriteAction withCompletionBlock:responseBlock];
  }
}

- (void)moreOptionsButtonPressed:(UIButton *)sender
{
  DDLogVerbose(@"More options button pressed");
  DFPhotoIDType objectId = sender.tag;
  self.actionSheetPhotoID = objectId;
  
  DFPeanutSearchObject *object = self.objectsByID[@(objectId)];
  NSString *deleteTitle = [self isObjectDeletableByUser:object] ? @"Delete" : nil;

  UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                           delegate:self
                                                  cancelButtonTitle:@"Cancel"
                                             destructiveButtonTitle:deleteTitle
                                                  otherButtonTitles:@"Save", nil];
  
 
  [actionSheet showInView:sender.superview];
}

- (BOOL)isObjectDeletableByUser:(DFPeanutSearchObject *)object
{
  return object.user == [[DFUser currentUser] userID];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
  NSString *buttonTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
  DDLogVerbose(@"The %@ button was tapped.", buttonTitle);
  if ([buttonTitle isEqualToString:@"Delete"]) {
    [self confirmDeletePhoto];
  } else if ([buttonTitle isEqualToString:@"Save"]) {
    [self savePhotoToCameraRoll];
  }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
  if (buttonIndex == 1) {
    [self deletePhoto];
  }
}

- (void)confirmDeletePhoto
{
  UIAlertView *alertView = [[UIAlertView alloc]
                            initWithTitle:@"Delete Photo?"
                            message:@"You and other strand users will no longer be able to see it."
                            delegate:self
                            cancelButtonTitle:@"Cancel"
                            otherButtonTitles:@"Delete", nil];
  [alertView show];
}

- (void)deletePhoto
{
  [self.photoAdapter deletePhoto:self.actionSheetPhotoID completionBlock:^(NSError *error) {
    if (!error) {
      [self reloadFeed];
      
      // remove it from the db
      [[DFPhotoStore sharedStore] deletePhotoWithPhotoID:self.actionSheetPhotoID];
      [DFAnalytics logPhotoDeletedWithResult:DFAnalyticsValueResultSuccess];
    } else {
      UIAlertView *alertView = [[UIAlertView alloc]
                                initWithTitle:@"Error"
                                message:[[NSString stringWithFormat:@"Sorry, an error occurred: %@",
                                          error.localizedRecoverySuggestion ?
                                          error.localizedRecoverySuggestion : error.localizedDescription] substringToIndex:200]
                                delegate:nil
                                cancelButtonTitle:@"OK"
                                otherButtonTitles:nil];
      [alertView show];
      [DFAnalytics logPhotoDeletedWithResult:DFAnalyticsValueResultFailure];
    }
  }];
}

- (void)savePhotoToCameraRoll
{
  @autoreleasepool {
    [self.photoAdapter getPhoto:self.actionSheetPhotoID withImageDataTypes:DFImageFull
                completionBlock:^(DFPeanutPhoto *peanutPhoto, NSDictionary *imageData, NSError *error) {
                  if (!error) {
                    UIImage *image = [UIImage imageWithData:imageData[@(DFImageFull)]];
                    [[DFPhotoStore sharedStore]
                     saveImageToCameraRoll:image
                     withMetadata:peanutPhoto.metadataDictionary
                     completion:^(NSError *error) {
                       if (error) {
                         [UIAlertView showSimpleAlertWithTitle:@"Error"
                                                       message:error.localizedDescription];
                         [DFAnalytics logPhotoSavedWithResult:DFAnalyticsValueResultFailure];
                       } else {
                         DDLogInfo(@"Photo saved.");
                         [UIAlertView showSimpleAlertWithTitle:nil
                                                       message:@"Photo saved to your camera roll"];
                         [DFAnalytics logPhotoSavedWithResult:DFAnalyticsValueResultSuccess];
                       }
                     }];
                  } else {
                    [UIAlertView showSimpleAlertWithTitle:@"Error" message:error.localizedDescription];
                  }
                }];
  }
}

- (void)reloadRowForPhotoID:(DFPhotoIDType)photoID
{
  NSIndexPath *indexPath = self.indexPathsByID[@(photoID)];
  if (indexPath) {
    [self.tableView reloadData];
  }
}

#pragma mark - Adapters

- (DFPeanutGalleryAdapter *)galleryAdapter
{
  if (!_galleryAdapter) {
    _galleryAdapter = [[DFPeanutGalleryAdapter alloc] init];
  }
  
  return _galleryAdapter;
}

- (DFPhotoMetadataAdapter *)photoAdapter
{
  if (!_photoAdapter) {
    _photoAdapter = [[DFPhotoMetadataAdapter alloc] init];
  }
  
  return _photoAdapter;
}


#pragma mark - Notification handlers

- (void)applicationDidBecomeActive:(NSNotification *)note
{
  if (self.isViewLoaded && self.view.window) {
    [self viewDidAppear:YES];
  }
}

- (void)applicationDidEnterBackground:(NSNotification *)note
{
  if (self.isViewLoaded && self.view.window) {
    [self viewDidDisappear:YES];
  }
}

@end
