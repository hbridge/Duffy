//
//  DFPeanutRestEndpointAdapter.h
//  Strand
//
//  Created by Henry Bridge on 9/1/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <RKHTTPUtilities.h>
#import "DFNetworkAdapter.h"
#import "DFPeanutObject.h"

typedef void (^DFPeanutRestFetchSuccess)(NSArray *resultObjects);
typedef void (^DFPeanutRestFetchFailure)(NSError *error);

@interface DFPeanutRestEndpointAdapter : NSObject

+ (NSArray *)responseDescriptorsForPeanutObjectClass:(Class<DFPeanutObject>)peanutObjectClass
                                            basePath:(NSString *)pathString;
+ (NSArray *)requestDescriptorsForPeanutObjectClass:(Class<DFPeanutObject>)peanutObjectClass
                                        rootKeyPath:(NSString *)rootKeyPath;

- (void)performRequest:(RKRequestMethod)requestMethod
              withPath:(NSString *)path
               objects:(NSArray *)objects
       forceCollection:(BOOL)forceCollection
               success:(DFPeanutRestFetchSuccess)success
               failure:(DFPeanutRestFetchFailure)failure;




@end
