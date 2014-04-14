//
//  MappedInCocoaTests.m
//  MappedInCocoaTests
//
//  Created by Dan Lichty on 2013-10-18.
//  Copyright (c) 2013 MappedIn, Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Block-KVO/MTKObserving.h>

#import "MIAPI.h"

#define kAPIVersion @"0"

@interface MappedInCocoaTests : XCTestCase

@end

@implementation MappedInCocoaTests

- (void)setUp
{
  [super setUp];
}

- (void)tearDown
{
  [super tearDown];
}

- (void)testReadyStates
{
  MIAPI *api = [[MIAPI alloc] initWithVersion:kAPIVersion];
  
  XCTAssertFalse(api.ready, @"should not be ready immediately after initialization");
  
  __block BOOL hasCalledBack = NO;
  __block BOOL hasChangedReadyProperty = NO;
  
  [api observeProperty:@"ready"
             withBlock:^(__weak id self, id old, id new) {
               if (old != nil)
                 hasChangedReadyProperty = YES;
             }];
  
  [api connectWithCallback:^{
    hasCalledBack = YES;
    XCTAssertTrue(api.ready, @"should be ready after connecting");
  } failure:^(NSError *error) {
    hasCalledBack = YES;
    XCTAssertFalse(api.ready, @"should not be ready if connection fails");
  }];
  
  NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:10];
  while (!(hasCalledBack && (!api.ready || hasChangedReadyProperty)) && [loopUntil timeIntervalSinceNow] > 0)
  {
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:loopUntil];
  }
  
  XCTAssertTrue(hasCalledBack, @"should have called back after connection attempt");
  XCTAssertTrue(!api.ready || hasChangedReadyProperty, @"should have changed ready property");
  
  [api removeAllObservations];
}

@end
