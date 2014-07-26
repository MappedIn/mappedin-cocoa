//
//  MIAPI.m
//  MappedInCocoa
//
//  Created by Dan Lichty on 2013-10-21.
//  Copyright (c) 2013 MappedIn, Inc. All rights reserved.
//

#import "MIAPI.h"
#import "MIMethod.h"
#import <AFHTTPRequestOperationManager.h>
#import <AFNetworkReachabilityManager.h>

#define MSEC_PER_SEC 1000.0

#define StoredManifestKey @"MappedInCocoaManifest"
#define StoredAccessTokenKey @"MappedInCocoaAccessToken"
#define StoredTokenExpiryKey @"MappedInCocoaTokenExpiry"

@interface MIAPI ()
{
  AFNetworkReachabilityManager *_reachabilityManager;
  AFHTTPRequestOperationManager *_requestManager;
  NSMutableDictionary *_methodManifest;
  NSMutableDictionary *_requestOperations;
  BOOL _initializing;
  BOOL _awaitingNetworkReachability;
  
  NSString *_accessToken;
  NSDate *_accessTokenExpiry;
}

@property (nonatomic) BOOL ready;
@property (nonatomic, strong) NSString *host, *index, *port, *version, *identifier;
@property (nonatomic, strong) NSString *clientKey, *secretKey;

@end

@implementation MIAPI

- (id)initWithVersion:(NSString *)version
{
  return [self initWithVersion:version clientKey:nil secretKey:nil];
}

- (id)initWithVersion:(NSString *)version clientKey:(NSString *)clientKey secretKey:(NSString *)secretKey
{
  self = [super init];
  
  NSString *domain = @"api.mappedin.com";
  
  _reachabilityManager = [AFNetworkReachabilityManager managerForDomain:domain];
  _requestManager = [AFHTTPRequestOperationManager manager];
  _methodManifest = [NSMutableDictionary dictionary];
  _requestOperations = [NSMutableDictionary dictionary];
  
  self.host = [NSString stringWithFormat:@"https://%@", domain];
  self.index = @"/manifest";
  self.port = @"443";
  self.version = version;
  self.identifier = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
  
  self.clientKey = clientKey;
  self.secretKey = secretKey;
  
  [self usePreferredLanguage];
  
  return self;
}

#pragma mark - Errors

- (NSString *)errorDomain
{
  static NSString *domain = @"MIAPIErrorDomain";
  return domain;
}

- (NSError *)errorForCode:(MIAPIErrorCode)code
{
  return [self errorForCode:code userInfo:nil];
}

- (NSError *)errorForCode:(MIAPIErrorCode)code userInfo:(NSDictionary *)info
{
  NSString *description = @"Unknown error.";
  
  if (code == MIAPIErrorAlreadyInitializing)
  {
    description = @"API is already initializing.";
  }
  else if (code == MIAPIErrorMalformedResponse)
  {
    description = @"API returned malformed response.";
  }
  else if (code == MIAPIErrorManifest)
  {
    description = @"API manifest could not be retrieved.";
  }
  else if (code == MIAPIErrorMethodName)
  {
    description = @"API does not include specified method.";
  }
  else if (code == MIAPIErrorUnauthorized)
  {
    description = @"Missing or invalid credentials.";
  }
  else if (code == MIAPIErrorForbidden)
  {
    description = @"Not authorized to access method.";
  }
  else if (code == MIAPIErrorNetworkNotReachable)
  {
    description = @"Unable to access internet.";
  }
  
  NSMutableDictionary *userInfo = info ? [NSMutableDictionary dictionaryWithDictionary:info] : [NSMutableDictionary dictionary];
  
  if (!userInfo[NSLocalizedDescriptionKey])
    [userInfo setObject:NSLocalizedString(description, nil) forKey:NSLocalizedDescriptionKey];
  
  return [NSError errorWithDomain:[self errorDomain] code:code userInfo:userInfo];
}

#pragma mark - Caching

+ (void)clearCachedAccessTokenAndManifest
{
  NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
  
  [prefs removeObjectForKey:StoredManifestKey];
  [prefs removeObjectForKey:StoredAccessTokenKey];
  [prefs removeObjectForKey:StoredTokenExpiryKey];
}

- (void)storeAccessTokenAndManifest
{
  if (_accessToken)
  {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSData *encodedManifest = [NSKeyedArchiver archivedDataWithRootObject:_methodManifest];
    [prefs setObject:encodedManifest forKey:StoredManifestKey];
    [prefs setObject:_accessToken forKey:StoredAccessTokenKey];
    [prefs setObject:_accessTokenExpiry forKey:StoredTokenExpiryKey];
  }
}

- (BOOL)retrieveAccessTokenAndManifest
{
  NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
  NSString *token = [prefs objectForKey:StoredAccessTokenKey];
  NSDate *expiry = [prefs objectForKey:StoredTokenExpiryKey];
  NSData *manifestData = [prefs objectForKey:StoredManifestKey];
  
  if (manifestData && token && [expiry timeIntervalSinceNow] > 300)
  {
    NSDictionary *manifest = [NSKeyedUnarchiver unarchiveObjectWithData:manifestData];
    
    [_methodManifest addEntriesFromDictionary:manifest];
    [self setAccessToken:token expiry:expiry];
    
    return YES;
  }
  
  return NO;
}

#pragma mark - Parsing

- (BOOL)parseManifest:(NSArray *)manifest
{
  if (![manifest isKindOfClass:[NSArray class]])
  {
    return NO;
  }
  
  [_methodManifest removeAllObjects];
  
  for (NSDictionary *methodInfo in manifest)
  {
    MIMethod *method = [[MIMethod alloc] initWithName:methodInfo[@"name"]
                                                 path:methodInfo[@"url"]
                                               method:methodInfo[@"method"]
                                            arguments:methodInfo[@"args"]];
    _methodManifest[method.name] = method;
  }
  
  return YES;
}

#pragma mark - Connecting

- (void)connectWithCallback:(void (^)(void))success failure:(MIAPIFailureCallback)failure
{
  if (_reachabilityManager.networkReachabilityStatus == AFNetworkReachabilityStatusUnknown)
  {
    __weak MIAPI *weakSelf = self;
    __weak AFNetworkReachabilityManager *weakReachabilityManager = _reachabilityManager;
    
    [_reachabilityManager startMonitoring];
    [_reachabilityManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
      [weakSelf connectWithCallback:success failure:failure];
      [weakReachabilityManager setReachabilityStatusChangeBlock:NULL];
    }];
    return;
  }
  
  if (!_reachabilityManager.isReachable)
  {
    if (failure)
      failure([self errorForCode:MIAPIErrorNetworkNotReachable]);
    return;
  }
  
  if (self.ready || [self retrieveAccessTokenAndManifest])
  {
    self.ready = YES;
    if (success)
      success();
    return;
  }
  
  if (_initializing)
  {
    if (failure)
      failure([self errorForCode:MIAPIErrorAlreadyInitializing]);
    return;
  }
  
  _initializing = YES;
  
  if (self.clientKey && self.secretKey)
    [self getAccessToken:success failure:failure];
  else
    [self getManifest:success failure:failure];
}

- (void)getManifest:(void (^)(void))success failure:(MIAPIFailureCallback)failure
{
  [self fetchPath:self.index
        arguments:nil
           method:@"GET"
          success:^(NSDictionary *data) {
            if ([data[@"success"] boolValue])
            {
              if ([self parseManifest:data[@"result"]])
              {
                self.ready = YES;
                if (success)
                  success();
              }
              else
              {
                if (failure)
                  failure([self errorForCode:MIAPIErrorMalformedResponse]);
              }
            }
            else
            {
              if (failure)
                failure([self errorForCode:MIAPIErrorManifest]);
            }
          }
          failure:failure];
}

- (void)getAccessToken:(void (^)(void))success failure:(MIAPIFailureCallback)failure
{
  if (!self.clientKey || !self.secretKey)
  {
    failure([self errorForCode:MIAPIErrorUnauthorized]);
    return;
  }
  
  [_requestManager POST:[NSString stringWithFormat:@"%@/token", self.host]
             parameters:@{
                          @"grant_type": @"client_credentials",
                          @"client_id": self.clientKey,
                          @"client_secret": self.secretKey
                          }
                success:^(AFHTTPRequestOperation *operation, id responseObject) {
                  _initializing = NO;
                  if ([responseObject isKindOfClass:[NSDictionary class]])
                  {
                    id token = responseObject[@"access_token"];
                    id expires = responseObject[@"expires_in"];
                    
                    if ([token isKindOfClass:[NSString class]] && [expires isKindOfClass:[NSNumber class]])
                    {
                      NSDate *expiryDate = [NSDate dateWithTimeIntervalSince1970:[((NSNumber *)expires) longLongValue] / MSEC_PER_SEC];
                      
                      if ([expiryDate timeIntervalSinceNow] > 0)
                      {
                        [self setAccessToken:token expiry:expiryDate];
                      }
                    }
                    
                    if ([self parseManifest:responseObject[@"manifest"]])
                    {
                      [self storeAccessTokenAndManifest];
                      
                      self.ready = YES;
                      if (success)
                        success();
                      return;
                    }
                  }
                  
                  if (failure)
                    failure([self errorForCode:MIAPIErrorManifest]);
                }
                failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                  _initializing = NO;
                  MIAPIErrorCode code = operation.response.statusCode == 401 ? MIAPIErrorUnauthorized : MIAPIErrorInternal;
                  if (failure)
                    failure([self errorForCode:code]);
                }];
}

- (void)setAccessToken:(NSString *)token expiry:(NSDate *)expiryDate
{
  _accessToken = token;
  _accessTokenExpiry = expiryDate;
  [_requestManager.requestSerializer setValue:[NSString stringWithFormat:@"Bearer %@", _accessToken] forHTTPHeaderField:@"Authorization"];
}

#pragma mark - API fetching

- (NSString *)fetchPath:(NSString *)path
              arguments:(NSDictionary *)args
                 method:(NSString *)method
                success:(MIAPISuccessCallback)success
                failure:(MIAPIFailureCallback)failure
{
  NSDate *timingDate = [NSDate date];
  
  NSMutableDictionary *argsWithLanguage = [NSMutableDictionary dictionary];
  if (self.language)
    argsWithLanguage[@"lang"] = self.language;
  
  [argsWithLanguage addEntriesFromDictionary:args];
  
  if (self.version.length)
  {
    path = [NSString stringWithFormat:@"/%@%@", self.version, path];
  }
  
  NSString *uuid = [[NSUUID UUID] UUIDString];
  NSString *url = [NSString stringWithFormat:@"%@:%@%@", self.host, self.port, path];
  
  void(^logTime)(AFHTTPRequestOperation *) = ^(AFHTTPRequestOperation *operation)
  {
    if (!self.loggingEnabled)
      return;
    
    NSLog(@"%@ (%ld): %dms", url, (long)operation.response.statusCode, (int)(MSEC_PER_SEC * [[NSDate date] timeIntervalSinceDate:timingDate]));
  };
  
  void(^removeRequest)() = ^
  {
    [_requestOperations removeObjectForKey:uuid];
  };
  
  void (^requestSuccess)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id responseObject)
  {
    logTime(operation);
    removeRequest();
    if ([responseObject isKindOfClass:[NSDictionary class]])
    {
      if (success)
        success(responseObject);
    }
    else
    {
      if (failure)
        failure([self errorForCode:MIAPIErrorMalformedResponse]);
    }
  };
  
  void (^requestFailure)(AFHTTPRequestOperation *, NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error)
  {
    logTime(operation);
    removeRequest();
    
    if (operation.response.statusCode == 401)
    {
      // 401 Unauthorized - get new token and retry call
      [self getAccessToken:^{
        [self fetchPath:path arguments:argsWithLanguage method:method success:success failure:failure];
      } failure:^(NSError *error) {
        if (failure)
          failure([self errorForCode:MIAPIErrorInternal]);
      }];
    }
    else if (operation.response.statusCode == 403)
    {
      // 403 Forbidden - client is not authorized for call
      if (failure)
        failure([self errorForCode:MIAPIErrorForbidden]);
    }
    else
    {
      if (failure)
        failure([self errorForCode:MIAPIErrorInternal]);
    }
  };
  
  if (!_reachabilityManager.isReachable)
  {
    if (failure)
      failure([self errorForCode:MIAPIErrorNetworkNotReachable]);
    return nil;
  }
  
  AFHTTPRequestOperation *request;
  
  if ([method isEqualToString:@"GET"])
  {
    request = [_requestManager GET:url parameters:argsWithLanguage success:requestSuccess failure:requestFailure];
  }
  else if ([method isEqualToString:@"POST"])
  {
    request = [_requestManager POST:url parameters:argsWithLanguage success:requestSuccess failure:requestFailure];
  }
  
  if (!request)
  {
    return nil;
  }
  
  _requestOperations[uuid] = request;
  return uuid;
}

- (NSString *)fetchMethod:(NSString *)name
                     args:(NSDictionary *)args
                  success:(MIAPISuccessCallback)success
                  failure:(MIAPIFailureCallback)failure
{
  MIMethod *method = _methodManifest[name];
  if (!method)
  {
    if (failure)
      failure([self errorForCode:MIAPIErrorMethodName userInfo:@{@"MIAPIErrorName": name}]);
    return nil;
  }
  
  MIAPISuccessCallback fetchSuccess = ^(id data)
  {
    if (![data[@"success"] boolValue])
    {
      if (failure)
      {
        NSString *errorMessage;
        if (!(errorMessage = data[@"message"]))
        {
          errorMessage = @"Something went wrong.";
        }
        failure([NSError errorWithDomain:[self errorDomain] code:MIAPIErrorInternal userInfo:@{NSLocalizedDescriptionKey: errorMessage}]);
      }
    }
    else if (!data[@"result"])
    {
      if (failure)
        failure([self errorForCode:MIAPIErrorMalformedResponse]);
    }
    else
    {
      if (success)
        success(data[@"result"]);
    }
  };
  
  return [self fetchPath:method.path arguments:[method requestArgumentsForData:args] method:method.method success:fetchSuccess failure:failure];
}

- (void)cancelRequest:(NSString *)requestID
{
  if (!requestID)
    return;
  
  AFHTTPRequestOperation *request = _requestOperations[requestID];
  [request cancel];
  [_requestOperations removeObjectForKey:requestID];
}

#pragma mark - Language

- (void)usePreferredLanguage
{
  self.language = [NSLocale preferredLanguages][0];
}

@end
