//
//  SPQRBTLEDevicesTableViewController.h
//  Blue Scan
//
//  Created by Matt Schulte on 4/10/14.
//  Copyright (c) 2014 SPQR. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreLocation/CoreLocation.h>

@interface SPQRBTLEPeripheralsTableViewController : UITableViewController <CBCentralManagerDelegate, CLLocationManagerDelegate, CBPeripheralDelegate>

@property (weak, nonatomic) IBOutlet UIBarButtonItem *startStopScanBtn;
@property (strong, nonatomic) IBOutlet UITableView *peripheralsTableView;

@property (strong, nonatomic) NSMutableArray *peripherals;
@property CBCentralManager *cbCentralManager;
@property CLLocationManager *locManager;
@property CLLocation *curLocation;
- (IBAction)startStopPushed:(id)sender;
- (IBAction)refreshPressed:(id)sender;

@end
