//
//  NSString+RHNumberAdditions.m
//
//  Created by Richard Heard on 13/11/12.
//  Copyright (c) 2012 Richard Heard. All rights reserved.
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

#import "NSString+RHNumberAdditions.h"

@implementation NSString (sk_RHNumberAdditions)

-(char)sk_charValue{
    return (char)[self characterAtIndex:0];
}

-(unsigned char)sk_unsignedCharValue{
    return (unsigned char)[self characterAtIndex:0];
}

-(short)sk_shortValue{
    return (short)[self sk_longValue];
}

-(unsigned short)sk_unsignedShortValue{
    return (unsigned short)[self sk_unsignedLongValue];
}

-(unsigned int)sk_unsignedIntValue{
    return (unsigned int)[self sk_unsignedLongValue];
}

-(long)sk_longValue{
    return (long)strtol([self cStringUsingEncoding:NSASCIIStringEncoding], NULL, 10);
}

-(unsigned long)sk_unsignedLongValue{
    return (unsigned long)strtoul([self cStringUsingEncoding:NSASCIIStringEncoding], NULL, 10);
}

-(unsigned long long)sk_unsignedLongLongValue{
    return (unsigned long long)strtoull([self cStringUsingEncoding:NSASCIIStringEncoding], NULL, 10);
}

-(NSUInteger)sk_unsignedIntegerValue{
#if __LP64__ || (TARGET_OS_EMBEDDED && !TARGET_OS_IPHONE) || TARGET_OS_WIN32 || NS_BUILD_32_LIKE_64
    typedef unsigned long NSUInteger;
    return [self sk_unsignedLongValue];
#else
    return [self sk_unsignedIntValue];
#endif
}

@end

//include an implementation in this file so we don't have to use -load_all for this category to be included in a static lib
@interface sk_RHFixCategoryBugClassNSSRHNA : NSObject @end @implementation sk_RHFixCategoryBugClassNSSRHNA @end

