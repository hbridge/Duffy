//
//  DFURLProtocol.m
//  Duffy
//
//  Created by Henry Bridge on 5/23/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFURLProtocol.h"
#import "DFPhotoStore.h"
#import "DFPhoto.h"


@interface DFURLProtocol()

// We need to store the managed object context so it sticks around between functions
@property (nonatomic, retain) NSManagedObjectContext *managedObjectContext;
@property (atomic) BOOL isCancelled;

@end

@implementation DFURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest*)theRequest
{
  if ([theRequest.URL.scheme caseInsensitiveCompare:@"duffyapp"] == NSOrderedSame) {
    return YES;
  }
  return NO;
}

+ (NSURLRequest*)canonicalRequestForRequest:(NSURLRequest*)theRequest
{
  return theRequest;
}

- (void)startLoading
{
  NSArray *pathComponents = self.request.URL.absoluteString.pathComponents;
  
  if (self.isCancelled) return;
  if (pathComponents.count != 3) {
    NSError *error = [NSError errorWithDomain:@"com.duffyapp.DFURLProtocol"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Path components for request don't match expected lenth of 3.",
                                                NSLocalizedRecoverySuggestionErrorKey : pathComponents.description
                                                }];
    [self.client URLProtocol:self didFailWithError:error];
    return;
  }
  
    if (self.isCancelled) return;
  DFPhoto *photo = [self photoForPathComponents:pathComponents];
  if (!photo) {
    NSError *error = [NSError errorWithDomain:@"com.duffyapp.DFURLProtocol"
                                         code:-2
                                     userInfo:@{NSLocalizedDescriptionKey: @"No local photo found for ID",
                                                NSLocalizedRecoverySuggestionErrorKey : [NSString stringWithFormat:@"Request url: %@", self.request.URL.description]
                                                }];
    [self.client URLProtocol:self didFailWithError:error];
    return;
  }
  
  if (self.isCancelled) return;
  NSData *data = [self imageDataForPathComponents:pathComponents photo:photo];
  
  if (!data){
    NSError *error = [NSError errorWithDomain:@"com.duffyapp.DFURLProtocol"
                                         code:-3
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid phototype in path",
                                                NSLocalizedRecoverySuggestionErrorKey : [NSString stringWithFormat:@"Request url: %@", self.request.URL.description]
                                                }];
    [self.client URLProtocol:self didFailWithError:error];
    return;
  }
  
  if (self.isCancelled) return;
  NSURLResponse *response = [[NSURLResponse alloc] initWithURL:self.request.URL
                                                      MIMEType:@"image/jpg"
                                         expectedContentLength:-1
                                              textEncodingName:nil];
  
  if (self.isCancelled) return;
  [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
  [[self client] URLProtocol:self didLoadData:data];
  [[self client] URLProtocolDidFinishLoading:self];
}

- (DFPhoto *)photoForPathComponents:(NSArray *)pathComponents
{
  NSString *photoIDString = pathComponents[2];
  DFPhotoIDType photoID = [photoIDString longLongValue];
  self.managedObjectContext = [DFPhotoStore createBackgroundManagedObjectContext];
  return [DFPhotoStore photoWithPhotoID:photoID inContext:self.managedObjectContext];
}

- (NSData *)imageDataForPathComponents:(NSArray *)pathComponents photo:(DFPhoto*)photo
{
  if ([pathComponents[1] isEqualToString:@"t"]) {
    return photo.thumbnailJPEGData;
  }
  
  return nil;
}

- (void)stopLoading
{
  self.isCancelled = YES;
}


@end
