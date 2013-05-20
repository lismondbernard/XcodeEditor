//
//  KeyBuilder.h
//  xcode-editor
//
//  Created by Lismond Bernard on 5/20/13.
//  Copyright (c) 2013 EXPANZ. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>

#define HASH_VALUE_STORAGE_SIZE 48

typedef struct {
    char value[CC_MD5_DIGEST_LENGTH];
} HashValueMD5Hash;

@interface KeyBuilder : NSObject {
    unsigned char _value[HASH_VALUE_STORAGE_SIZE];
}

+ (KeyBuilder *) forItemNamed:(NSString *)name;
+ (KeyBuilder *) forDictionary:(NSDictionary*)dict;
- (id) initHashValueMD5HashWithBytes:(const void *)bytes length:(NSUInteger)length;
- (NSString *) build;

@end
