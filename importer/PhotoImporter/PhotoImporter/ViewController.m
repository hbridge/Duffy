//
//  ViewController.m
//  PhotoImporter
//
//  Created by Henry Bridge on 9/15/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "ViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface ViewController ()

@property (readonly, nonatomic, retain) ALAssetsLibrary *library;

@end

@implementation ViewController

@synthesize library = _library;

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view, typically from a nib.
  NSArray * paths = NSSearchPathForDirectoriesInDomains (NSDesktopDirectory, NSUserDomainMask, YES);
  if (paths.firstObject) {
    NSArray *pathComponents = [(NSString *)paths.firstObject pathComponents];
    if ([pathComponents[1] isEqualToString:@"Users"]) {
      self.pathTextField.text = [NSString stringWithFormat:@"/Users/%@/Pictures/Simulator",
                                 pathComponents[2]];
      
    }
  }
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (IBAction)importButtonPressed:(id)sender {
  NSFileManager *fm = [[NSFileManager alloc] init];
  
  NSError *error;
  NSString *directoryPath = self.pathTextField.text;
  NSArray *files = [fm contentsOfDirectoryAtPath:directoryPath error:&error];
  if (error) {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:error.description
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    [alertView show];
    return;
  }
  
  dispatch_semaphore_t writeSemaphore = dispatch_semaphore_create(0);
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    NSUInteger i = 0;
    int __block errors = 0;
    int __block successfulImports = 0;
    for (NSString *path in files) {
      NSLog(@"Saving image at: %@", path);
      
      NSData *imageData = [NSData dataWithContentsOfFile:[directoryPath stringByAppendingPathComponent:path]];
      [self.library
       writeImageDataToSavedPhotosAlbum:imageData
       metadata:nil
       completionBlock:^(NSURL *assetURL, NSError *error) {
         if (error) {
           NSLog(@"Error saving image:%@", error);
           errors++;
         } else {
           successfulImports++;
         }
         dispatch_semaphore_signal(writeSemaphore);
       }];
      
      dispatch_semaphore_wait(writeSemaphore, DISPATCH_TIME_FOREVER);
      i++;
      dispatch_async(dispatch_get_main_queue(), ^{
        self.progressView.progress = (float)i/(float)files.count;
      });
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
      UIAlertView *doneAlert = [[UIAlertView alloc]
                                initWithTitle:@"Import Complete"
                                message:[NSString stringWithFormat:@"Successfully imported: %d \nFailed: %d",
                                         successfulImports, errors]
                                delegate:nil cancelButtonTitle:@"OK"
                                otherButtonTitles:nil];
      [doneAlert show];
    });
  });
}

- (ALAssetsLibrary *)library
{
  if (!_library) _library = [[ALAssetsLibrary alloc] init];
  
  return _library;
}

@end
