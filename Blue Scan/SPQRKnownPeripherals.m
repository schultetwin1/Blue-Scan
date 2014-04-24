//
//  SPQRKnownPeripherals.m
//  Blue Scan
//
//  Created by Matt Schulte on 4/12/14.
//  Copyright (c) 2014 SPQR. All rights reserved.
//

#import "SPQRKnownPeripherals.h"

@interface SPQRKnownPeripherals()

@property NSString* path;
@property NSMutableDictionary* knownPeriphs;

@end

@implementation SPQRKnownPeripherals

- (SPQRKnownPeripherals*) init {
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* documentsDirectory = [paths objectAtIndex:0];
    self.path = [documentsDirectory stringByAppendingPathComponent:@"known_periphs.plist"];
    
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:self.path];
    if (!fileExists) {
        [[NSFileManager defaultManager] createFileAtPath:self.path contents:nil attributes:nil];
        self.knownPeriphs = [[NSMutableDictionary alloc] init];
        [self.knownPeriphs writeToFile:self.path atomically:YES];
    } else {
        self.knownPeriphs = [[NSMutableDictionary alloc] initWithContentsOfFile:self.path];
    }
    return self;
}

- (NSString *) getMAC:(NSUUID*) uuid {
    return [self.knownPeriphs objectForKey:[uuid UUIDString]];
}

- (void) addMAC:(NSUUID*) uuid mac:(NSString*) MAC {
    [self.knownPeriphs setObject:MAC forKey:[uuid UUIDString]];
    [self.knownPeriphs writeToFile:self.path atomically:YES];
}

- (void) clear {
    [self.knownPeriphs removeAllObjects];
    [self.knownPeriphs writeToFile:self.path atomically:YES];
}
@end
