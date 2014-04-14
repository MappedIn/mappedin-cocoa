//
//  MIMethod.h
//  MappedInCocoa
//
//  Created by Dan Lichty on 2013-10-21.
//  Copyright (c) 2013 MappedIn, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MIMethod : NSObject <NSCoding>

@property (nonatomic, strong, readonly) NSString *name, *path, *method;
@property (nonatomic, strong, readonly) NSArray *arguments;

- (id)initWithName:(NSString *)name path:(NSString *)path method:(NSString *)method arguments:(NSArray *)args;

- (NSDictionary *)requestArgumentsForData:(NSDictionary *)args;

@end
