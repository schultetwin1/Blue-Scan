//
//  SPQRKnownPeripherals.h
//  Blue Scan
//
//  Created by Matt Schulte on 4/12/14.
//  Copyright (c) 2014 SPQR. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SPQRKnownPeripherals : NSObject

- (SPQRKnownPeripherals*) init;

- (NSString *) getMAC:(NSUUID*) uuid;
- (void) addMAC:(NSUUID*) uuid mac:(NSString*) MAC;
- (void) clear;

@end
