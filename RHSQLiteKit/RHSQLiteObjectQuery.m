//
//  RHSQLiteObjectQuery.m
//  RHSQLiteKit
//
//  Created by Richard Heard on 14/07/13.
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

#import "RHSQLiteObjectQuery.h"
#import "RHSQLiteObject.h"

@implementation RHSQLiteObjectQuery
@synthesize objectClass=_objectClass;

+(id)queryForObjectClass:(Class)objClass where:(NSString*)where orderedBy:(NSString*)columnName ascending:(BOOL)ascending{
    RHSQLiteObjectQuery *new = [[self alloc] init];
    new.objectClass = objClass;
    [new setWhere:where];
    [new setOrderedBy:columnName ascending:ascending];
    return new;
}

-(void)setWhere:(NSString*)whereSQL{
    _where = whereSQL;
}

-(void)setOrderedBy:(NSString*)columnName ascending:(BOOL)ascending{
    _orderedBy = [NSString stringWithFormat:@" ORDERED BY %@ %@", columnName, ascending ? @"ASC" : @"DESC"];
}

-(NSString*)sql{
    NSString *tableName = [_objectClass tableName];
    NSString *primaryKeyName = [_objectClass primaryKeyName];

    NSString *orderBy = _orderedBy ?: @"";
    return [NSString stringWithFormat:@"SELECT %@ FROM '%@' WHERE %@ %@;", primaryKeyName, tableName, _where, orderBy];
}

#pragma mark - description
-(NSString*)description{
    return [NSString stringWithFormat:@"<%@: %p, sql: %@>", NSStringFromClass([self class]), self, [self sql]];
}

@end
