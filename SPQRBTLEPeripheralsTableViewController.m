//
//  SPQRBTLEDevicesTableViewController.m
//  Blue Scan
//
//  Created by Matt Schulte on 4/10/14.
//  Copyright (c) 2014 SPQR. All rights reserved.
//

#import "SPQRKnownPeripherals.h"

#import "SPQRBTLEPeripheral.h"
#import "SPQRBTLEPeripheralsTableViewController.h"

@interface SPQRBTLEPeripheralsTableViewController ()
@property BOOL isBluetoothEnabled;
@property BOOL isScanning;

@property SPQRKnownPeripherals *knownPeripherals;
@end

@implementation SPQRBTLEPeripheralsTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Load know peripherals
    self.knownPeripherals = [[SPQRKnownPeripherals alloc] init];
    
    // Set up Location
    self.locManager = [[CLLocationManager alloc] init];
    [self.locManager setDelegate:self];
    // And SUCK battery
    [self.locManager setDesiredAccuracy:kCLLocationAccuracyBest];
    [self.locManager setDistanceFilter:kCLDistanceFilterNone];
    [self startLocating];
    
    // Set up Bluetooth
    self.cbCentralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    
    // Set Up Scan Button
    [self enableStartStopBtn];
    self.isScanning = NO;
    [self.startStopScanBtn setTitle:@"Start"];
    
    // Set Up array
    self.peripherals = [[NSMutableArray alloc] init];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)startStopPushed:(id)sender {
    if (self.isScanning) {
        [self stopScanning];
    } else {
        [self startScanning];
    }
}

- (IBAction)refreshPressed:(id)sender {
    [self cleanupPeripherals];
}

- (void) enableStartStopBtn {
    BOOL enable = [self canLocate] && self.isBluetoothEnabled && (self.curLocation != nil);
    [self.startStopScanBtn setEnabled:enable];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.peripherals count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PeripheralPrototypeCell" forIndexPath:indexPath];
    
    // Configure the cell...
    SPQRBTLEPeripheral* periph = [self.peripherals objectAtIndex:indexPath.row];
    cell.textLabel.text = periph.cb.name;
    if (periph.MAC) {
        cell.textLabel.text = [NSString stringWithFormat:@"%@ (%@)", periph.cb.name, periph.MAC];
    }
    cell.textLabel.textColor = periph.isScanned ? [UIColor blackColor] : [UIColor grayColor];
    cell.accessoryType = periph.isUploaded ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    return cell;
}

- (void) startScanning {
    assert(self.isBluetoothEnabled);
    assert([self canLocate]);
    self.isScanning = YES;
    [self startLocating];
    [self.cbCentralManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @YES}];
    [self.startStopScanBtn setTitle:@"Stop"];
}

- (void) stopScanning {
    self.isScanning = NO;
    [self.cbCentralManager stopScan];
    // Get rid of all connections and remove all peripherals
    for (int i = 0; i < self.peripherals.count; i++) {
        CBPeripheral* periph = [[self.peripherals objectAtIndex:i] cb];
        if (periph.state == CBPeripheralStateConnected) {
            [self.cbCentralManager cancelPeripheralConnection:periph];
        }
    }
    [self.peripherals removeAllObjects];
    [self.startStopScanBtn setTitle:@"Start"];
    [self.peripheralsTableView reloadData];
}

- (void) removePeripheral:(CBPeripheral*) periph {
    for (int i = 0; i < [self.peripherals count]; i++) {
        if ([[periph.identifier UUIDString] isEqualToString:[[self.peripherals objectAtIndex:i] cb].identifier.UUIDString]) {
            [self.peripherals removeObjectAtIndex:i];
        }
    }
}

- (BOOL) canLocate {
    if (![CLLocationManager locationServicesEnabled]) return NO;
    if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorized) return NO;
    return YES;
}

- (void) startLocating {
    // Check for location services and that we are authorized
    if (![self canLocate]) {
        return;
    }
    [self.locManager startUpdatingLocation];
}

- (void) stopLocating {
    [self.locManager stopUpdatingLocation];
}

- (void) cleanupPeripherals {
    NSMutableArray *cleanUpItems = [NSMutableArray array];
    for (SPQRBTLEPeripheral* p in self.peripherals) {
        if (!p.isScanned) {
            if (p.cb.state == CBPeripheralStateConnected || p.cb.state == CBPeripheralStateConnecting) {
                [self.cbCentralManager cancelPeripheralConnection:p.cb];
            }
            [cleanUpItems addObject:p];
        }
    }
    [self.peripherals removeObjectsInArray:cleanUpItems];
    [self.peripheralsTableView reloadData];
}

- (void)sendPeripheral:(SPQRBTLEPeripheral *)peripheral {
    if ([peripheral isUploaded]) {
        return;
    }
    
    BOOL useTestSite = [[NSUserDefaults standardUserDefaults] boolForKey:@"use_test_site"];
    NSString* user = [[NSUserDefaults standardUserDefaults] stringForKey:@"user_name"];
    NSString *bodyData = [
                          NSString stringWithFormat:@"timestamp=%d&MAC=%@&rand_mac=%@&name=%@&latitude=%f&longitude=%f&device=%@&passcode=%@&fitbitid=%@",
                          (int)round(peripheral.timestamp),
                          peripheral.MAC,
                          @"1",
                          user,
                          peripheral.location.coordinate.latitude,
                          peripheral.location.coordinate.longitude,
                          @"ios",
                          useTestSite ? @"test_site" : @"eecs588isalright",
                          peripheral.MAC
                          ];
    
    NSString* url;
    
    if (useTestSite) {
        url = @"https://track-dev.schultetwins.com/api/v1.0/spot";
    } else {
        url = @"https://track.schultetwins.com/api/v1.0/spot";
    }
    
    NSMutableURLRequest *postRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    
    [postRequest setHTTPMethod:@"POST"];
    
    [postRequest setHTTPBody:[NSData dataWithBytes:[bodyData UTF8String] length:strlen([bodyData UTF8String])]];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:postRequest queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
     {
         if ([data length] > 0 && error == nil) {
             NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
             if (httpResponse.statusCode == 200) {
                 peripheral.isUploaded = YES;
                 dispatch_async(dispatch_get_main_queue(), ^{
                     
                     // Back on the main thread, ask the tableview to reload itself.
                     [self.peripheralsTableView reloadData];
                     
                 });
             }
         } else if ([data length] == 0 && error == nil) {
             [self.peripherals removeObject:peripheral];
             NSLog(@"ERRORL EMPTY REPLY");
         } else if (error != nil) {
             [self.peripherals removeObject:peripheral];
             NSLog(@"Error On POST: %@", error);
         } else {
             [self.peripherals removeObject:peripheral];
             NSLog(@"Failed to upload data");
         }
     }];
}

- (void) connected:(CBPeripheral*)peripheral service:(CBService*)mainService {
    
    CBUUID *receiveCharacteristicUUID = [CBUUID UUIDWithString:@"ADABFB02-6E7D-4601-BDA2-BFFAA68956BA"];
    unsigned char bytes[13] = {0};
    
    bytes[0] = 0xC0;
    bytes[1] = 0x0A;
    bytes[2] = 0x1;
    bytes[4] = 0x08; /* 08 for iOS6? 0x10 for iOS 5? */
    bytes[6] = 0x10;
    bytes[10] = 0xc8;
    bytes[12] = 0x01;
    
    NSData *packet = [NSData dataWithBytes:bytes length:13];
    CBCharacteristic* c = [self findCharacteristicFromUUID:receiveCharacteristicUUID service:mainService];
    assert(c);
    
    if (mainService) {
        [peripheral writeValue:packet forCharacteristic:c type:CBCharacteristicWriteWithoutResponse];
    } else {
        [self removePeripheral:peripheral];
        NSLog(@"Unable to find main service");
    }
}

-(CBCharacteristic *) findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service {
    for(int i=0; i < service.characteristics.count; i++) {
        CBCharacteristic *c = [service.characteristics objectAtIndex:i];
        if ([c.UUID.UUIDString isEqualToString:UUID.UUIDString]) return c;
    }
    return nil;
}

#pragma mark - Bluetooth Manager Delegate
- (void) centralManagerDidUpdateState:(CBCentralManager *)central {
    if ([central state] == CBCentralManagerStatePoweredOn) {
        self.isBluetoothEnabled = YES;
    } else {
        [self stopScanning];
        self.isBluetoothEnabled = NO;
    }
    [self enableStartStopBtn];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    
    if (self.curLocation == nil) return;
    
    if ([@[@"Force", @"Flex", @"One"] indexOfObject:peripheral.name] == NSNotFound) return;

    SPQRBTLEPeripheral *periph = [[SPQRBTLEPeripheral alloc] init];
    periph.cb = peripheral;
    periph.isUploaded = NO;
    periph.RSSI = RSSI;
    periph.location = self.curLocation;
    periph.timestamp = [[NSDate date] timeIntervalSince1970];
    
    NSInteger dup = -1;
    
    for (int i = 0; i < [self.peripherals count]; ++i) {
        SPQRBTLEPeripheral* p = [self.peripherals objectAtIndex:i];
        if ([peripheral.identifier.UUIDString isEqualToString:p.cb.identifier.UUIDString]) {
            // If we recently found it, let it go
            if ([[NSDate date] timeIntervalSince1970] - p.timestamp < 5) {
                NSLog(@"Device was found recently");
                return;
                // Otherwise kick it out of its connecting state
            } else if (p.cb.state == CBPeripheralStateConnecting) {
                [self.cbCentralManager cancelPeripheralConnection:p.cb];
                dup = i;
                break;
                // Or if its been too long, upload it again
            } else if ([[NSDate date] timeIntervalSince1970] - p.timestamp > 10 * 60) {
                dup = i;
                break;
                // If its connected let, it too its thing
            } else if (p.cb.state == CBPeripheralStateConnected) {
                NSLog(@"Device is connected");
                return;
            } else {
                return;
            }
        }
    }
    
    // Check if we already know this ID
    if ([self.knownPeripherals getMAC:peripheral.identifier]) {
        if (dup != -1) {
            [self.peripherals replaceObjectAtIndex:dup withObject:periph];
        } else {
            [self.peripherals addObject:periph];
        }
        [self.peripheralsTableView reloadData];
        periph.MAC = [self.knownPeripherals getMAC:peripheral.identifier];
        periph.isScanned = YES;
        [self sendPeripheral:periph];
        return;
    }
    
    if (dup != -1) {
        [self.peripherals replaceObjectAtIndex:dup withObject:periph];
    } else {
        [self.peripherals addObject:periph];
    }
    
    [self.peripheralsTableView reloadData];
    NSLog(@"Connecting to peripheral with UUID: %@", peripheral.identifier.UUIDString);
    [self.cbCentralManager connectPeripheral:peripheral options:nil];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Connecting to peripheral with UUID: %@ successful", peripheral.identifier.UUIDString);
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self removePeripheral:peripheral];
    NSLog(@"Failed to connect to peripheral with UUID: %@", peripheral.identifier.UUIDString);
}

#pragma mark - Peripheral Delegate
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        [self.cbCentralManager cancelPeripheralConnection:peripheral];
        [self removePeripheral:peripheral];
        NSLog(@"Serivce discovery failed for peripheral %@", error);
        return;
    }
    NSLog(@"Services of peripheral with UUID: %@ found", peripheral.identifier.UUIDString);
    for (CBService* service in peripheral.services) {
        NSLog(@"Fetching characteristics for service with UUID %@", service.UUID.UUIDString);
        [peripheral discoverCharacteristics:nil forService:service];
    }
    
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        [self.cbCentralManager cancelPeripheralConnection:peripheral];
        [self removePeripheral:peripheral];
        NSLog(@"Characteristic discovery failed");
        return;
    }
    CBService *mainService = nil;
    for (CBCharacteristic* characteristic in service.characteristics) {
        // Basically we just need to scan all services and all characteristics...
        if([[characteristic UUID].UUIDString  isEqual: @"ADABFB01-6E7D-4601-BDA2-BFFAA68956BA"]) {

            mainService = service;
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            [self connected:peripheral service:mainService];
        }
    }
    
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        [peripheral setNotifyValue:NO forCharacteristic:characteristic];
        [self.cbCentralManager cancelPeripheralConnection:peripheral];
        [self removePeripheral:peripheral];
        NSLog(@"ERROR Updating packets");
    }
    NSLog(@"recv[%@] %lu bytes [%@]: %@", characteristic.UUID.UUIDString, (unsigned long)[[characteristic value] length], [[characteristic UUID] description], [characteristic value]);
    
    unsigned char *bytes = (unsigned char*)[[characteristic value] bytes];
    if ([[characteristic value] length] > 11) {
        NSString *mac = [NSString stringWithFormat:@"%.2X:%.2X:%.2X:%.2X:%.2X:%.2X", bytes[11], bytes[10], bytes[9], bytes[8], bytes[7], bytes[6]];
        NSLog(@"Successfully retrieved MAC %@ of device with UUID: %@", mac, peripheral.identifier.UUIDString);
        [peripheral setNotifyValue:NO forCharacteristic:characteristic];
        for (SPQRBTLEPeripheral* periph in self.peripherals) {
            if ([periph.cb.identifier.UUIDString isEqualToString:peripheral.identifier.UUIDString]) {
                periph.MAC = mac;
                periph.isScanned = YES;
                [self.knownPeripherals addMAC:peripheral.identifier mac:periph.MAC];
                [self sendPeripheral:periph];
                [self.cbCentralManager cancelPeripheralConnection:peripheral];
                break;
            }
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (!error) {
        NSLog(@"Updated notification state for characteristic with UUID %@ on service with  UUID %@ on peripheral with UUID %@",[characteristic.UUID UUIDString],[characteristic.service.UUID UUIDString],[peripheral.identifier UUIDString]);
    }
    else {
        [peripheral setNotifyValue:NO forCharacteristic:characteristic];
        [self.cbCentralManager cancelPeripheralConnection:peripheral];
        [self removePeripheral:peripheral];
        NSLog(@"Error in setting notification state for characteristic with UUID %@ on service with  UUID %@ on peripheral with UUID %@",[characteristic.UUID UUIDString],[characteristic.service.UUID UUIDString],[peripheral.identifier UUIDString]);
    }
    
}

#pragma mark - Location Manager Delegate
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusAuthorized) {
        [self startLocating];
    }
    [self enableStartStopBtn];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    self.curLocation = locations[0];
    [self enableStartStopBtn];
}
@end
