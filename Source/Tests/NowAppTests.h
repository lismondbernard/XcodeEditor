//
//  NowAppTests.h
//  xcode-editor
//
//  Created by Lismond Bernard on 5/13/13.
//  Copyright (c) 2013 EXPANZ. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "XCProject.h"
#import "XCSourceFile.h"
#import "XCTarget.h"
#import "XCGroup.h"

@interface NowAppTests : SenTestCase

@property (nonatomic, strong) XCProject *project;

@end
