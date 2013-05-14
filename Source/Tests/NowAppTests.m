//
//  NowAppTests.m
//  xcode-editor
//
//  Created by Lismond Bernard on 5/13/13.
//  Copyright (c) 2013 EXPANZ. All rights reserved.
//

#import "NowAppTests.h"

@implementation NowAppTests


- (void)setUp {
    self.project = [[XCProject alloc] initWithFilePath:@"/Users/lbernard/Code/ios_nowapp.git/NowApp.xcodeproj"];
}

- (void)test_demo_target {
    XCTarget *demoTarget = [_project targetWithName:@"demo"];
    assertThat(demoTarget, notNilValue());
}

- (void)test_demo_target_copy {
    XCTarget *demoTarget = [_project targetWithName:@"demo"];
    XCTarget *copyTarget = [_project copyTarget:demoTarget withName:@"demo-copy"];
    assertThat(copyTarget, notNilValue());
}

- (void)test_save_demo_target {
    [_project save];
}

- (void)test_list_targets_project {
    
    NSArray* targets = [_project targets];
    for (XCTarget* target in [_project targets]) {
        NSLog(@"%@", target);
    }
    assertThat(targets, notNilValue());
}


@end
