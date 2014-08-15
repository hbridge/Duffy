//
//  DFSocketsManager.m
//  Strand
//
//  Created by Derek Parham on 8/15/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSocketsManager.h"
#import "DFUser.h"
#import "DFStrandConstants.h"
#import "DFNetworkingConstants.h"

@interface DFSocketsManager()

@property (nonatomic, retain) NSInputStream *inputStream;
@property (nonatomic, retain) NSOutputStream *outputStream;
@property (nonatomic) BOOL sentUserId;

@end

@implementation DFSocketsManager

// We want a singleton
static DFSocketsManager *defaultManager;
+ (DFSocketsManager *)sharedManager {
  if (!defaultManager) {
    defaultManager = [super new];
  }
  return defaultManager;
}

- (void) initNetworkCommunication {
	CFReadStreamRef readStream;
	CFWriteStreamRef writeStream;
	CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef) DFServerBaseHost, DFSocketPort, &readStream, &writeStream);
	
  self.inputStream = (__bridge NSInputStream *)readStream;
	self.outputStream = (__bridge NSOutputStream *)writeStream;
	[self.inputStream setDelegate:self];
	[self.outputStream setDelegate:self];
	[self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[self.inputStream open];
	[self.outputStream open];
}

- (void) sendMessage:(NSString *)message {
  DDLogInfo(@"Socket sending message: %@", message);
	NSData *data = [[NSData alloc] initWithData:[message dataUsingEncoding:NSASCIIStringEncoding]];
	[self.outputStream write:[data bytes] maxLength:[data length]];
}

- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
  switch (streamEvent) {
      
		case NSStreamEventOpenCompleted:
			DDLogInfo(@"Successfully opened stream to server");
      self.sentUserId = NO;
			break;
      
		case NSStreamEventHasBytesAvailable:
			if (theStream == self.inputStream) {
				uint8_t buffer[1024];
				int len;
				
				while ([self.inputStream hasBytesAvailable]) {
					len = [self.inputStream read:buffer maxLength:sizeof(buffer)];
					if (len > 0) {
						
						NSString *output = [[NSString alloc] initWithBytes:buffer length:len encoding:NSASCIIStringEncoding];
						
						if (nil != output) {
							DDLogInfo(@"Socket received message: %@", output);
							[self messageReceived:output];
						}
					}
				}
			}
			break;
      
    case NSStreamEventHasSpaceAvailable:
      if (!self.sentUserId) {
        [self sendMessage:[NSString stringWithFormat:@"user_id:%llu",[[DFUser currentUser] userID]]];
        self.sentUserId = YES;
      }
      break;
      
		case NSStreamEventErrorOccurred:
			DDLogInfo(@"Stream error occured.  Maybe can't connect to the host");
			break;
			
		case NSStreamEventEndEncountered:
      [theStream close];
      [theStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
      theStream = nil;
			break;
      
		default:
			DDLogInfo(@"Unknown socket event");
	}
}

/*
 * Deals with incoming messages.  They should be of the format command:value (colon delimited)
 * Right now, only supports "refresh" command, where we then send of an internal notification to refresh all our info.
 */
- (void) messageReceived:(NSString *)message {
  NSArray *a = [message componentsSeparatedByString:@":"];
  NSString *command = a[0];
  NSString *value = a[1];
  
  if ([command isEqualToString:@"refresh"]) {
    DDLogInfo(@"Was told to refresh my feed, with id %@", value);
    [[NSNotificationCenter defaultCenter]
     postNotificationName:DFStrandRefreshRemoteUIRequestedNotificationName
     object:self];
    
    [self sendMessage:[NSString stringWithFormat:@"ack:%@",value]];
  }
}

@end
