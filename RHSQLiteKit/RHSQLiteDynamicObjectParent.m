//
//  RHSQLiteDynamicObjectParent.m
//  RHSQLiteKit
//
//  Created by Richard Heard on 13/07/13.
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

#import "RHSQLiteDynamicObjectParent.h"
#import "RHSQLiteDataStore_Private.h"
#import <objc/runtime.h>

static dispatch_once_t _RHSQLiteDynamicObjectClassToTableNameMap_onceToken;
static NSMutableDictionary *_RHSQLiteDynamicObjectClassToTableNameMap;

@interface RHSQLiteDynamicObjectParent ()
//private

//object subclass registration lookup
+(BOOL)_associateTableName:(NSString*)tableName withSQLiteDynamicObjectSubclass:(Class)subclass;
+(NSString*)_tableNameForSQLiteObjectSubclass:(Class)subclass;

@end

@implementation RHSQLiteDynamicObjectParent

#pragma mark - init
+(void)initialize{
    //setup our class lookup storage
    dispatch_once(&_RHSQLiteDynamicObjectClassToTableNameMap_onceToken, ^{
        RHLog(@"Created _RHSQLiteDynamicObjectClassToTableNameMap.");
        _RHSQLiteDynamicObjectClassToTableNameMap = [[NSMutableDictionary alloc] init];
    });
}

#pragma mark - table name specific class generation lookup
+(BOOL)registerTableName:(NSString*)tableName{
    return [self _associateTableName:tableName withSQLiteDynamicObjectSubclass:self];
}

+(NSString*)tableName{
    NSString *tableName = [self _tableNameForSQLiteObjectSubclass:self];
    if (!tableName){
        RHErrorLog(@"Error: This class has never had +registerTableName: called on it.");
        [NSException raise:NSInternalInconsistencyException format:@"Error: Class:%@ has never had +registerTableName: called on it.", NSStringFromClass(self)];
        return nil;
    }
    
    return tableName;
}

#pragma mark - private
#pragma mark - object subclass registration lookup
+(BOOL)_associateTableName:(NSString*)tableName withSQLiteDynamicObjectSubclass:(Class)subclass{
    NSString *classExistingTableName = [self _tableNameForSQLiteObjectSubclass:subclass];
    if (classExistingTableName && ![classExistingTableName isEqualToString:tableName]){
        RHErrorLog(@"Error: Class:%@ has already had table name '%@' registered. Failed to register with name %@.", NSStringFromClass(subclass), classExistingTableName, tableName);
        [NSException raise:NSInternalInconsistencyException format:@"Error: Class:%@ has already had table name '%@' registered. Failed to register with name %@.", NSStringFromClass(subclass), classExistingTableName, tableName];
        return NO;
    }
    
    [_RHSQLiteDynamicObjectClassToTableNameMap setObject:tableName forKey:NSStringFromClass(subclass)];
    return YES;
}
+(NSString*)_tableNameForSQLiteObjectSubclass:(Class)subclass{
    return [_RHSQLiteDynamicObjectClassToTableNameMap objectForKey:NSStringFromClass(subclass)];
}

@end


#pragma mark - subclass creation 
Class RHSQLiteDynamicObjectParentCreateNewSubclassWithName(NSString *name){
    if ([NSClassFromString(name) class] != nil){
        return [NSClassFromString(name) class];
    }
    RHLog(@"Creating  RHSQLiteDynamicObjectParent subclass with name %@", name);
    Class newClass = objc_allocateClassPair([RHSQLiteDynamicObjectParent class], [name UTF8String], 0);
    //Class newMetaClass = object_getClass(newClass);
    objc_registerClassPair(newClass);
        
    return newClass;
}

Class RHSQLiteDynamicObjectParentCreateNewSubclassWithNameAndTableName(NSString *name, NSString *tableName){
    Class result = RHSQLiteDynamicObjectParentCreateNewSubclassWithName(name);
    if (result){
        [NSClassFromString(name) registerTableName:tableName];
    }
    
    return result;
}

