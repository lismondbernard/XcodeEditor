////////////////////////////////////////////////////////////////////////////////
//
//  JASPER BLUES
//  Copyright 2012 - 2013 Jasper Blues
//  All Rights Reserved.
//
//  NOTICE: Jasper Blues permits you to use, modify, and distribute this file
//  in accordance with the terms of the license agreement accompanying it.
//
////////////////////////////////////////////////////////////////////////////////




#import "XCProject.h"
#import "XCGroup.h"
#import "XCSourceFile.h"
#import "XCTarget.h"
#import "XCFileOperationQueue.h"
#import "XCBuildConfiguration.h"
#import "Utils/XCMemoryUtils.h"
#import "XCKeyBuilder.h"


@implementation XCProject


@synthesize fileOperationQueue = _fileOperationQueue;

/* =========================================================== Class Methods ============================================================ */
+ (XCProject*)projectWithFilePath:(NSString*)filePath
{
    return XCAutorelease([[XCProject alloc] initWithFilePath:filePath])}


/* ============================================================ Initializers ============================================================ */
- (id)initWithFilePath:(NSString*)filePath
{
    if ((self = [super init]))
    {
        _filePath = [filePath copy];
        _dataStore = [[NSMutableDictionary alloc] initWithContentsOfFile:[_filePath stringByAppendingPathComponent:@"project.pbxproj"]];

        if (!_dataStore)
        {
            [NSException raise:NSInvalidArgumentException format:@"Project file not found at file path %@", _filePath];
        }

        _fileOperationQueue = [[XCFileOperationQueue alloc] initWithBaseDirectory:[_filePath stringByDeletingLastPathComponent]];

    }
    return self;
}

/* ====================================================================================================================================== */
- (void)dealloc
{
    XCRelease(_filePath)
    XCRelease(_fileOperationQueue)
    XCRelease(_dataStore)
    XCRelease(_targets)
    XCRelease(_groups)
    XCRelease(_rootObjectKey)
    XCRelease(_defaultConfigurationName)

    XCSuperDealloc
}

/* ========================================================== Interface Methods ========================================================= */

#pragma mark Files

- (NSArray*)files
{
    NSMutableArray* results = [NSMutableArray array];
    [[self objects] enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSDictionary* obj, BOOL* stop)
    {
        if ([[obj valueForKey:@"isa"] asMemberType] == PBXFileReferenceType)
        {
            XcodeSourceFileType fileType = [[obj valueForKey:@"lastKnownFileType"] asSourceFileType];
            NSString* path = [obj valueForKey:@"path"];
            NSString* sourceTree = [obj valueForKey:@"sourceTree"];
            [results addObject:[XCSourceFile sourceFileWithProject:self key:key type:fileType name:path
                                                        sourceTree:(sourceTree ? sourceTree : @"<group>") path:nil]];
        }
    }];
    return results;
}

- (XCSourceFile*)fileWithKey:(NSString*)key
{
    NSDictionary* obj = [[self objects] valueForKey:key];
    if (obj && ([[obj valueForKey:@"isa"] asMemberType] == PBXFileReferenceType || [[obj valueForKey:@"isa"] asMemberType] ==
            PBXReferenceProxyType))
    {
        XcodeSourceFileType fileType = [[obj valueForKey:@"lastKnownFileType"] asSourceFileType];

        NSString* name = [obj valueForKey:@"name"];
        NSString* sourceTree = [obj valueForKey:@"sourceTree"];

        if (name == nil)
        {
            name = [obj valueForKey:@"path"];
        }
        return [XCSourceFile sourceFileWithProject:self key:key type:fileType name:name sourceTree:(sourceTree ? sourceTree : @"<group>")
                                              path:[obj valueForKey:@"path"]];
    }
    return nil;
}

- (XCSourceFile*)fileWithName:(NSString*)name
{
    for (XCSourceFile* projectFile in [self files])
    {
        if ([[projectFile name] isEqualToString:name])
        {
            return projectFile;
        }
    }
    return nil;
}


- (NSArray*)headerFiles
{
    return [self projectFilesOfType:SourceCodeHeader];
}

- (NSArray*)objectiveCFiles
{
    return [self projectFilesOfType:SourceCodeObjC];
}

- (NSArray*)objectiveCPlusPlusFiles
{
    return [self projectFilesOfType:SourceCodeObjCPlusPlus];
}


- (NSArray*)xibFiles
{
    return [self projectFilesOfType:XibFile];
}

- (NSArray*)imagePNGFiles
{
    return [self projectFilesOfType:ImageResourcePNG];
}

// need this value to construct relative path in XcodeprojDefinition
- (NSString*)filePath
{
    return _filePath;
}

/* ====================================================================================================================================== */
#pragma mark Groups

- (NSArray*)groups
{

    NSMutableArray* results = [[NSMutableArray alloc] init];
    [[_dataStore objectForKey:@"objects"] enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSDictionary* obj, BOOL* stop)
    {

        if ([[obj valueForKey:@"isa"] asMemberType] == PBXGroupType || [[obj valueForKeyPath:@"isa"] asMemberType] == PBXVariantGroupType)
        {
            [results addObject:[self groupWithKey:key]];
        }
    }];
    return XCAutorelease(results)}

//TODO: Optimize this implementation.
- (XCGroup*)rootGroup
{
    for (XCGroup* group in [self groups])
    {
        if ([group isRootGroup])
        {
            return group;
        }
    }
    return nil;
}

- (NSArray*)rootGroups
{
    XCGroup* group = [self rootGroup];
    if (group)
    {
        return [NSArray arrayWithObject:group];
    }

    NSMutableArray* results = [NSMutableArray array];
    for (XCGroup* group in [self groups])
    {
        if ([group parentGroup] == nil)
        {
            [results addObject:group];
        }
    }

    return XCAutorelease([results copy])}

- (XCGroup*)groupWithKey:(NSString*)key
{
    XCGroup* group = [_groups objectForKey:key];
    if (group)
    {
        return XCRetainAutorelease(group)}

    NSDictionary* obj = [[self objects] objectForKey:key];
    if (obj && ([[obj valueForKey:@"isa"] asMemberType] == PBXGroupType || [[obj valueForKey:@"isa"] asMemberType] == PBXVariantGroupType))
    {

        NSString* name = [obj valueForKey:@"name"];
        NSString* path = [obj valueForKey:@"path"];
        NSArray* children = [obj valueForKey:@"children"];
        XCGroup* group = [XCGroup groupWithProject:self key:key alias:name path:path children:children];

        [_groups setObject:group forKey:key];

        return group;
    }
    return nil;
}

- (XCGroup*)groupForGroupMemberWithKey:(NSString*)key
{
    for (XCGroup* group in [self groups])
    {
        if ([group memberWithKey:key])
        {
            return XCRetainAutorelease(group)}
    }
    return nil;
}

- (XCGroup*)groupWithSourceFile:(XCSourceFile*)sourceFile
{
    for (XCGroup* group in [self groups])
    {
        for (id <XcodeGroupMember> member in [group members])
        {
            if ([member isKindOfClass:[XCSourceFile class]] && [[sourceFile key] isEqualToString:[member key]])
            {
                return group;
            }
        }
    }
    return nil;
}

//TODO: This could fail if the path attribute on a given group is more than one directory. Start with candidates and
//TODO: search backwards.
- (XCGroup*)groupWithPathFromRoot:(NSString*)path
{
    NSArray* pathItems = [path componentsSeparatedByString:@"/"];
    XCGroup* currentGroup = [self rootGroup];
    for (NSString* pathItem in pathItems)
    {
        id <XcodeGroupMember> group = [currentGroup memberWithDisplayName:pathItem];
        if ([group isKindOfClass:[XCGroup class]])
        {
            currentGroup = group;
        }
        else
        {
            return nil;
        }
    }
    return currentGroup;
}


/* ====================================================================================================================================== */
#pragma mark targets

- (NSArray*)targets
{
    if (_targets == nil)
    {
        _targets = [[NSMutableArray alloc] init];
        [[self objects] enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSDictionary* obj, BOOL* stop)
        {
            if ([[obj valueForKey:@"isa"] asMemberType] == PBXNativeTargetType)
            {
                XCTarget* target =
                        [XCTarget targetWithProject:self key:key name:[obj valueForKey:@"name"] productName:[obj valueForKey:@"productName"]
                                   productReference:[obj valueForKey:@"productReference"]];
                [_targets addObject:target];
            }
        }];
    }
    return _targets;
}

- (XCTarget*)targetWithName:(NSString*)name
{
    for (XCTarget* target in [self targets])
    {
        if ([[target name] isEqualToString:name])
        {
            return target;
        }
    }
    return nil;
}

- (NSString *) duplicateBuildConfWithKey:(NSString *)key {
    NSDictionary *baseConfigList = [[self objects] objectForKey:key];
    NSMutableDictionary *dupBuildConf = [baseConfigList mutableCopy];
    NSMutableDictionary *buildSettings = [[dupBuildConf objectForKey:@"buildSettings"] mutableCopy];
    NSMutableArray *searchPaths = [[buildSettings objectForKey:@"FRAMEWORK_SEARCH_PATHS"] mutableCopy];
    
    if (searchPaths == nil) {
        searchPaths = [NSMutableArray arrayWithCapacity:2];
    }
    if ([searchPaths isKindOfClass:[NSString class]]) {
        searchPaths = [NSMutableArray arrayWithObject:searchPaths];
    }
    if (![searchPaths containsObject:@"$(inherited)"]) {
        [searchPaths addObject:@"$(inherited)"];
    }
    if (![searchPaths containsObject:@"$(SRCROOT)"] && ![searchPaths containsObject:@"\"$(SRCROOT)\""]) {
        [searchPaths addObject:@"\"$(SRCROOT)\""];
    }
    [buildSettings setObject:searchPaths forKey:@"FRAMEWORK_SEARCH_PATHS"];
    
    id flags = [buildSettings objectForKey:@"OTHER_LDFLAGS"];
    if (flags == nil) {
        flags = [NSMutableArray arrayWithCapacity:4];
    }
    if ([flags isKindOfClass:[NSString class]]) {
        flags = [NSArray arrayWithObject:(NSString*)flags];
    }
    
    NSMutableArray *lflags = [flags mutableCopy];
    
    if (![lflags containsObject:@"$(inherited)"]) {
        [lflags addObject:@"$(inherited)"];
    }
    if (![lflags containsObject:@"-force_load"]) {
        [lflags addObject:@"-force_load"];
    }
    if (![lflags containsObject:@"-lstdc++"]) {
        [lflags addObject:@"-lstdc++"];
    }
    
    [buildSettings setObject:lflags forKey:@"OTHER_LDFLAGS"];
    
    
    [dupBuildConf setObject:buildSettings forKey:@"buildSettings"];
    XCKeyBuilder *builtKey = [XCKeyBuilder forDictionary:dupBuildConf];
    NSString *dupKey = [builtKey build];
    [[self objects] setObject:dupBuildConf forKey:dupKey];
    return dupKey;
}

- (NSString *) duplicateBuildConfListWithKey:(NSString*)key {
    NSDictionary *baseConfigList = [[self objects] objectForKey:key];
    NSMutableDictionary *dupBuildConfList = [baseConfigList mutableCopy];
    NSMutableArray *buildConfs = [NSMutableArray array];
    for (NSString *buildConf in [dupBuildConfList objectForKey:@"buildConfigurations"]) {
        [buildConfs addObject:[self duplicateBuildConfWithKey:buildConf]];
    }
    
    [dupBuildConfList setObject:buildConfs forKey:@"buildConfigurations"];
    XCKeyBuilder *builtKey = [XCKeyBuilder forDictionary:dupBuildConfList];
    NSString *dupKey = [builtKey build];
    [[self objects] setObject:dupBuildConfList forKey:dupKey];
    return dupKey;
}

- (XCTarget *)copyTarget:(XCTarget *)target withName:(NSString *)copyName {
    NSDictionary *dictTarget = [[self objects] objectForKey:target.key];
    
    NSMutableDictionary *copiedDict = [dictTarget mutableCopy];
    [copiedDict setObject:copyName forKey:@"name"];

    NSString *buildConfListKey = [copiedDict objectForKey:@"buildConfigurationList"];
    NSString *dupBuildConfListKey = [self duplicateBuildConfListWithKey:buildConfListKey];

    [copiedDict setObject:dupBuildConfListKey forKey:@"buildConfigurationList"];
    
    [copiedDict setObject:copyName forKey:@"productName"];

    NSString *productFileRefKey = [copiedDict objectForKey:@"productReference"];
    NSMutableDictionary *productFileRef = [[[self objects] objectForKey:productFileRefKey] mutableCopy];
    NSString *namePrefix = [NSString stringWithFormat:@"%@.app",copyName];
    [productFileRef setObject:namePrefix forKey:@"path"];
    
    NSString *dupProductFileRefKey = [[XCKeyBuilder forItemNamed:namePrefix] build];
    [[self objects] setObject:productFileRef forKey:dupProductFileRefKey];
    
    [copiedDict setObject:dupProductFileRefKey forKey:@"productReference"];

    NSMutableArray *buildPhases = [NSMutableArray arrayWithCapacity:3];
    for (NSString *buildFile in [copiedDict objectForKey:@"buildPhases"]) {
        NSMutableDictionary *buildCopyDict = [[[self objects] objectForKey:buildFile] mutableCopy];
        NSMutableArray *dupedFiles = [NSMutableArray array];
        for (NSString *fileID in [buildCopyDict objectForKey:@"files"]) {
            NSMutableDictionary *file = [[[self objects] objectForKey:fileID] mutableCopy];
            XCKeyBuilder *builder = [XCKeyBuilder forDictionary:file];
            NSString *fileKey = [builder build];
            [[self objects] setValue:file forKey:fileKey];
            [dupedFiles addObject:fileKey];
        }
        
        [buildCopyDict setObject:dupedFiles forKey:@"files"];
        XCKeyBuilder *builtKey = [XCKeyBuilder forDictionary:buildCopyDict];
        NSString *buildPhaseKey = [builtKey build];
        [[self objects] setObject:buildCopyDict forKey:buildPhaseKey];
        [buildPhases addObject:buildPhaseKey];
    }
    
    [copiedDict setObject:buildPhases forKey:@"buildPhases"];

    XCGroup *group = nil;
    NSArray *filteredGroups = [[self groups] filteredArrayUsingPredicate:
                               [NSPredicate predicateWithFormat:@"displayName == 'Products'"]];
    if ([filteredGroups count] > 0) {
        group = [filteredGroups objectAtIndex:0];
        [group performSelector:@selector(addMemberWithKey:) withObject:dupProductFileRefKey];
    }

    XCKeyBuilder *builtKey = [XCKeyBuilder forItemNamed:copyName];
    NSString *key = [builtKey build];
    [[self objects] setObject:copiedDict forKey:key];
    XCTarget *dupTarget = [[XCTarget alloc] initWithProject:self key:key name:copyName productName:copyName productReference:dupProductFileRefKey];
    [_targets addObject:dupTarget];

    NSString *rootKey = [_dataStore objectForKey:@"rootObject"];
    NSMutableDictionary *rootObj = [[[self objects] objectForKey:rootKey] mutableCopy];
    NSMutableArray *rootObjTargets = [[rootObj objectForKey:@"targets"] mutableCopy];
    [rootObjTargets addObject:dupTarget.key];
    [rootObj setObject:rootObjTargets forKey:@"targets"];
    
    [[self objects] setObject:rootObj forKey:rootKey];

    return dupTarget;
}

- (void)save
{
    [_fileOperationQueue commitFileOperations];
    [_dataStore writeToFile:[_filePath stringByAppendingPathComponent:@"project.pbxproj"] atomically:YES];

    NSLog(@"Saved project");
}

- (NSMutableDictionary*)objects
{
    return [_dataStore objectForKey:@"objects"];
}


- (NSDictionary*)configurations
{
    if (_configurations == nil)
    {
        NSString* buildConfigurationRootSectionKey =
                [[[self objects] objectForKey:[self rootObjectKey]] objectForKey:@"buildConfigurationList"];
        NSDictionary* buildConfigurationDictionary = [[self objects] objectForKey:buildConfigurationRootSectionKey];
        _configurations =
                [[XCBuildConfiguration buildConfigurationsFromDictionary:[buildConfigurationDictionary objectForKey:@"buildConfigurations"]
                                                               inProject:self] mutableCopy];
        _defaultConfigurationName = [[buildConfigurationDictionary objectForKey:@"defaultConfigurationName"] copy];
    }

    return XCAutorelease([_configurations copy])
}

- (NSDictionary*)configurationWithName:(NSString*)name
{
    return [[self configurations] objectForKey:name];
}

- (XCBuildConfiguration*)defaultConfiguration
{
    return [[self configurations] objectForKey:_defaultConfigurationName];
}

/* ====================================================================================================================================== */
#pragma mark Private

- (NSString*)rootObjectKey
{
    if (_rootObjectKey == nil)
    {
        _rootObjectKey = [[_dataStore objectForKey:@"rootObject"] copy];;
    }

    return _rootObjectKey;
}

- (NSArray*)projectFilesOfType:(XcodeSourceFileType)projectFileType
{
    NSMutableArray* results = [NSMutableArray array];
    for (XCSourceFile* file in [self files])
    {
        if ([file type] == projectFileType)
        {
            [results addObject:file];
        }
    }
    return results;
}

@end