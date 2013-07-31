//
//  RHSQLiteObjectPlaceholder.m
//  RHSQLiteKit
//
//  Created by Richard Heard on 29/07/2013.
//  Copyright (c) 2013 Richard Heard. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions
//  are met:
//  1. Redistributions of source code must retain the above copyright
//  notice, this list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright
//  notice, this list of conditions and the following disclaimer in the
//  documentation and/or other materials provided with the distribution.
//  3. The name of the author may not be used to endorse or promote products
//  derived from this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
//  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
//  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
//  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
//  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
//  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "RHSQLiteObjectPlaceholder.h"
#import "RHSQLiteDataStore.h"

@implementation RHSQLiteObjectPlaceholder

@synthesize className=_className;
@synthesize tableName=_tableName;
@synthesize objectID=_objectID;

+(id)placeholderWithObject:(RHSQLiteObject*)object{
    return [self placeholderWithClassName:NSStringFromClass([object class]) tableName:[object tableName] objectID:[object objectID]];
}

+(id)placeholderWithClassName:(NSString*)className tableName:(NSString*)tableName objectID:(RHSQLiteObjectID)objectID{
    return [[self alloc] initWithClassName:className tableName:tableName objectID:objectID];
}

-(id)initWithClassName:(NSString*)className tableName:(NSString*)tableName objectID:(RHSQLiteObjectID)objectID{
    self = [super init];
    if (self){
        _className = className;
        _tableName = tableName;
        _objectID = objectID;
    }
    return self;
}

#pragma mark - NSCoding
- (id)initWithCoder:(NSCoder *)coder{
    self = [super init];
    if (self) {
        _className = [coder decodeObjectForKey:@"className"];
        _tableName = [coder decodeObjectForKey:@"tableName"];
        _objectID = [coder decodeInt64ForKey:@"objectID"];
    }
    return self;
}

-(void)encodeWithCoder:(NSCoder *)coder{
    [coder encodeObject:_className forKey:@"className"];
    [coder encodeObject:_tableName forKey:@"tableName"];
    [coder encodeInt64:_objectID forKey:@"objectID"];
}

#pragma mark - lookup
-(RHSQLiteObject*)representedObjectInDataStore:(RHSQLiteDataStore*)dataStore{
    return [dataStore objectFromTable:self.tableName withID:self.objectID];
}


-(NSString*)description{
    return [NSString stringWithFormat:@"<%@: %p, className:%@ tableName:%@, objectID:%lld >", NSStringFromClass(self.class), self, _className, _tableName, _objectID];
}

@end
