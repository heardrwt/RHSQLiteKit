//
//  NSArray+RHNumberAdditions.h
//
//  Created by Richard Heard on 15/07/13.
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

#import <Foundation/Foundation.h>

@interface NSArray (sk_RHNumberAdditions)

//primitive getters
-(BOOL)sk_boolAtIndex:(NSUInteger)index;
-(int)sk_intAtIndex:(NSUInteger)index;
-(long)sk_longAtIndex:(NSUInteger)index;
-(unsigned long)sk_unsignedLongAtIndex:(NSUInteger)index;
-(long long)sk_longLongAtIndex:(NSUInteger)index;
-(unsigned long long)sk_unsignedLongLongAtIndex:(NSUInteger)index;
-(double)sk_doubleAtIndex:(NSUInteger)index;
-(float)sk_floatAtIndex:(NSUInteger)index;
-(NSInteger)sk_integerAtIndex:(NSUInteger)index;
-(NSUInteger)sk_usignedIntegerAtIndex:(NSUInteger)index;

@end

@interface NSMutableArray (sk_RHNumberAdditions)

//primitive additions
-(void)sk_addBool:(BOOL)value;
-(void)sk_addInt:(int)value;
-(void)sk_addLong:(long int)value;
-(void)sk_addUnsignedLong:(unsigned long)value;
-(void)sk_addLongLong:(long long)value;
-(void)sk_addUnsignedLongLong:(unsigned long long)value;
-(void)sk_addDouble:(double)value;
-(void)sk_addFloat:(float)value;
-(void)sk_addInteger:(NSInteger)value;
-(void)sk_addUnsignedInteger:(NSUInteger)value;

//primitive insertions
-(void)sk_insertBool:(BOOL)value atIndex:(NSUInteger)index;
-(void)sk_insertInt:(int)value atIndex:(NSUInteger)index;
-(void)sk_insertLong:(long int)value atIndex:(NSUInteger)index;
-(void)sk_insertLongLong:(long long)value atIndex:(NSUInteger)index;
-(void)sk_insertUnsignedLongLong:(unsigned long long)value atIndex:(NSUInteger)index;
-(void)sk_insertDouble:(double)value atIndex:(NSUInteger)index;
-(void)sk_insertFloat:(float)value atIndex:(NSUInteger)index;
-(void)sk_insertInteger:(NSInteger)value atIndex:(NSUInteger)index;
-(void)sk_insertUnsignedInteger:(NSUInteger)value atIndex:(NSUInteger)index;

@end


