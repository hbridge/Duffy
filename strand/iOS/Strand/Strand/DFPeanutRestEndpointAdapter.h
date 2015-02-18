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
                                            basePath:(NSString *)pathString
                                         bulkKeyPath:(NSString *)bulkKeyPath;
+ (NSArray *)requestDescriptorsForPeanutObjectClass:(Class<DFPeanutObject>)peanutObjectClass
                                        bulkPostKeyPath:(NSString *)bulkPostKeyPath;

- (void)performRequest:(RKRequestMethod)requestMethod
              withPath:(NSString *)path
               objects:(NSArray *)objects
            parameters:(NSDictionary *)parameters
       forceCollection:(BOOL)forceCollection
               success:(DFPeanutRestFetchSuccess)success
               failure:(DFPeanutRestFetchFailure)failure;

+ (NSError *)NotFoundError;



@end
