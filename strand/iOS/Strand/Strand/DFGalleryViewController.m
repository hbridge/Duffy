//
//  DFGalleryViewController.m
//  Strand
//
//  Created by Henry Bridge on 7/4/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFGalleryViewController.h"
#import "DFPeanutGalleryAdapter.h"
#import "DFPeanutSearchObject.h"
#import "DFPhotoStore.h"

@interface DFGalleryViewController ()

@property (readonly, nonatomic, retain) DFPeanutGalleryAdapter *galleryAdapter;

@end

@implementation DFGalleryViewController

@synthesize galleryAdapter = _galleryAdapter;


- (void)viewDidLoad
{
  [super viewDidLoad];
  self.navigationItem.title = @"Shared";
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
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
