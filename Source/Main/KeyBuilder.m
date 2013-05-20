//
//  KeyBuilder.m
//  xcode-editor
//
//  Created by Lismond Bernard on 5/20/13.
//  Copyright (c) 2013 StepLeader Inc. All rights reserved.
//

#import "KeyBuilder.h"

@implementation KeyBuilder

/* ================================================= Class Methods ================================================== */
+ (KeyBuilder *) forItemNamed:(NSString *)name {
    NSString *salt = [[NSDate date] description];
    NSData *data = [[name stringByAppendingString:salt] dataUsingEncoding:NSUTF8StringEncoding];
    return [[KeyBuilder alloc] initHashValueMD5HashWithBytes:[data bytes] length:[data length]];
}

+ (KeyBuilder *) forDictionary:(NSDictionary *)dict {
    NSString *salt = [[NSDate date] description];
	NSMutableData *data = [[NSMutableData alloc] init];
    [data appendData:[salt dataUsingEncoding:NSUTF8StringEncoding]];
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
	[archiver encodeObject:dict forKey:@"NSDictionary"];
	[archiver finishEncoding];
    return [[KeyBuilder alloc] initHashValueMD5HashWithBytes:[data bytes] length:[data length]];
}


/* ================================================== Initializers ================================================== */
- (id) initHashValueMD5HashWithBytes:(const void *)bytes length:(NSUInteger)length {
    self = [super init];
    if (self != nil) {
        CC_MD5(bytes, (int) length, _value);
    }
    return self;
}

/* ================================================ Interface Methods =============================================== */
- (NSString *) build {
    NSInteger byteLength = sizeof(HashValueMD5Hash);
    NSMutableString *stringValue = [NSMutableString stringWithCapacity:byteLength * 2];
    NSInteger i;
    for (i = 0; i < byteLength; i++) {
        [stringValue appendFormat:@"%02x", _value[i]];
    }
    return [stringValue substringToIndex:24];
}

@end
