//
//  DFPeanutContactAdapter.h
//  Strand
//
//  Created by Henry Bridge on 7/31/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <RKHTTPUtilities.h>
#import "DFNetworkAdapter.h"
#import "DFPeanutContact.h"

@interface DFPeanutContactAdapter : NSObject <DFNetworkAdapter>

typedef void (^DFPeanutContactFetchSuccess)(NSArray *peanutContacts);
typedef void (^DFPeanutContactFetchFailure)(NSError *error);

- (void)postPeanutContacts:(NSArray *)peanutContacts
                   success:(DFPeanutContactFetchSuccess)success
                   failure:(DFPeanutContactFetchFailure)failure;


@end
