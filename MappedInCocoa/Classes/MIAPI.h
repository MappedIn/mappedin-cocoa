//
//  MIAPI.h
//  MappedInCocoa
//
//  Created by Dan Lichty on 2013-10-21.
//  Copyright (c) 2013 MappedIn, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AFHTTPRequestOperationManager;

typedef void (^MIAPIFailureCallback)(NSError *error);
typedef void (^MIAPISuccessCallback)(id result);

typedef NS_ENUM(NSInteger, MIAPIErrorCode)
{
  MIAPIErrorAlreadyInitializing,
  MIAPIErrorMalformedResponse,
  MIAPIErrorManifest,
  MIAPIErrorMethodName,
  MIAPIErrorInternal,
  MIAPIErrorUnauthorized,
  MIAPIErrorForbidden,
  MIAPIErrorNetworkNotReachable
};

@interface MIAPI : NSObject

+ (void)clearCachedAccessTokenAndManifest;

- (id)initWithVersion:(NSString *)version;
- (id)initWithVersion:(NSString *)version clientKey:(NSString *)clientKey secretKey:(NSString *)secretKey;
- (void)connectWithCallback:(void (^)(void))success failure:(MIAPIFailureCallback)failure;
- (NSString *)fetchMethod:(NSString *)name args:(NSDictionary *)args success:(MIAPISuccessCallback)success failure:(MIAPIFailureCallback)failure;
- (void)cancelRequest:(NSString *)requestID;
- (void)usePreferredLanguage;

@property (nonatomic, strong) NSString *language;
@property (nonatomic) BOOL loggingEnabled;
@property (nonatomic, readonly) BOOL ready;

@end
