//
//  SPQRBTLEPeripheral.h
//  Blue Scan
//
//  Created by Matt Schulte on 4/10/14.
//  Copyright (c) 2014 SPQR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface SPQRBTLEPeripheral : NSObject

@property CBPeripheral *cb;
@property BOOL isUploaded;
@property BOOL isScanned;
@property NSTimeInterval timestamp;
@property NSNumber* RSSI;
@property NSString* MAC;
@property CLLocation* location;

@end
