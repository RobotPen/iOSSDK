
#import "RobotPenService.h"
#import "BlePenUtil.h"



#define deviceServiceUUID @"6E400001-B5A3-F393-E0A9-E50E24DCCA9E"//@"测试板"//
#define deviceInfoCharacteristicUUID @"0000FFD0-0000-1000-8000-00805F9B34FB"
#define deviceNotifyCharacteristicUUID @"0x6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
#define deviceWriteCharacteristicUUID @"0x6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
typedef enum{
    
    KEY_PEN_DATA_ID = 0xAA,
    KEY_PEN_DATA = 0x81,
    KEY_SWITCH_OTA = 0xB0,
    KEY_SWITCH_DEVICE = 0xB5,
    KEY_GET_FILE_INFO = 0xB1,
    KEY_GET_FILE_DATA = 0xB2,
    KEY_GET_CHECKSUM = 0xB3,
    KEY_GET_RESULT = 0xB4,
    KEY_GET_VERSION = 0x84,
    KEY_SET_NAME = 0x82,
    
}PEN_STATE;



@interface RobotPenService()
{
    NSData *mFirmwareData;
    NSString *mFirmwarePath ;
    NSUInteger mFirmwareNumber ;
    NSUInteger mFirmwareOffset ;
    NSUInteger mFirmwareCheckNum ;
    
}


@end

@implementation RobotPenService
@synthesize lastData = _lastData;
@synthesize foundPeripherals;
@synthesize characteristicDict;
@synthesize scanDeviceDelegate;
@synthesize connectStateDelegate;
@synthesize pointChangeDelegate;
@synthesize currConnectDevice;

static RobotPenService *_this = nil;

+ (id)sharePenService{
    if (_this == nil)
        _this = [[RobotPenService alloc] init];
    
    
    return _this;
}

+(NSString *)test{
    return @"test";
}

- (NSMutableData *)lastData{
    if (nil == _lastData) {
        _lastData = [[NSMutableData alloc] init];
    }
    return _lastData;
}

#pragma mark private method
- (id)init{
    if(self = [super init]){
        [self initBlutoothManager];
        currConnectDevice = nil;
    }
    return self;
}

-(void)initBlutoothManager{
    
    self.foundPeripherals = [[NSMutableDictionary alloc] init];
    self.characteristicDict = [[NSMutableDictionary alloc] init];
    dispatch_queue_t aQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    bluetoothManager = [[CBCentralManager alloc] initWithDelegate:self queue:aQueue];
}







-(void)scanDevice:(id<ScanDeviceDelegate>)delegate{
    if(!isBluetoothReady)return;
    if(isScanning)return;
    
    self.scanDeviceDelegate = delegate;
    [foundPeripherals removeAllObjects];
    
    NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
    [options setValue:[NSNumber numberWithBool:NO] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
    
    [bluetoothManager scanForPeripheralsWithServices:nil options:options];
}

/**
 停止扫描
 **/
-(void)stopScanDevice{
    if(!isBluetoothReady)return;
    if(!isScanning)return;
    isScanning = false;
    [bluetoothManager stopScan];
}

/**
 连连接蓝牙设备
 **/
- (void)connectDevice:(CBPeripheral *)peripheral{
    if (peripheral) {
        [bluetoothManager connectPeripheral:peripheral options:nil];
    }
}

/**
 连连接蓝牙设备
 **/
-(void)connectDevice:(DeviceObject *)device delegate:(id<ConnectStateDelegate>)delegate{
    if(!isBluetoothReady)return;
    if(isScanning)[self stopScanDevice];
    self.connectStateDelegate = delegate;
    self.currConnectDevice = device;
    [self sendConnectState:CONNECTING];
    [bluetoothManager connectPeripheral:device.peripheral options:nil];
    
}

/*
 断开蓝牙连接
 */
- (void)disconnectDevice {
    if ([self isConnectingPeripheral]) {
        if (curCBPeripheral != nil) {
            [bluetoothManager cancelPeripheralConnection:curCBPeripheral];
        }
    }
}

-(DeviceObject *)getCurrDevice{
    return self.currConnectDevice;
}

- (BOOL)isConnectingPeripheral{
    if ([[characteristicDict allKeys] count] > 0) {
        return YES;
    }else{
        return NO;
    }
}

#pragma mark CBCentralManagerDelegate
-(void)centralManagerDidUpdateState:(CBCentralManager *)central{
    switch (central.state) {
        case CBCentralManagerStatePoweredOff:{
            isBluetoothReady = FALSE;
        }
            break;
        case CBCentralManagerStatePoweredOn:{
            isBluetoothReady = TRUE;
        }
            break;
        case CBCentralManagerStateResetting:
            
            break;
        case CBCentralManagerStateUnauthorized:
            
            break;
        case CBCentralManagerStateUnknown:
            
            break;
        case CBCentralManagerStateUnsupported:{
            isBluetoothReady = FALSE;
        }
            break;
        default:
            break;
    }
}

- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals{
    NSLog(@"didRetrievePeripherals  %@",peripherals);
    
}
- (void)centralManager:(CBCentralManager *)central didRetrieveConnectedPeripherals:(NSArray *)peripherals{
    
    NSLog(@"didRetrieveConnectedPeripherals  %@",peripherals);
}

/*
 发现蓝牙设备
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI{
    
    
    id kCBAdvDataManufacturerData = [advertisementData objectForKey:@"kCBAdvDataManufacturerData"];
    if ([kCBAdvDataManufacturerData isKindOfClass:[NSData class]]) {
        //        根据广播包判断是否是数码笔
        const char *bytes = [kCBAdvDataManufacturerData bytes];
        UInt8 oneByte =bytes[0];
        UInt8 twoByte =bytes[1];
        UInt8 threeByte = bytes[2];
        if (oneByte == 0x60 || oneByte == 0x61) {
            //发现智能笔设备
            DeviceObject *device = [[DeviceObject alloc] init];
            device.peripheral = peripheral;
            device.uuID = [peripheral.identifier UUIDString];
            //判断是否已添加到集合列队
            if (![foundPeripherals objectForKey:[device getName]]) {
                [foundPeripherals setObject:peripheral forKey:[device getName]];
                
                if(scanDeviceDelegate){
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [scanDeviceDelegate find:device];
                    });
                }
                
            }
        }
    }
}


- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    if (peripheral.state == CBPeripheralStateConnected) {
        //连接成功
        isConnected = true;
        curCBPeripheral = peripheral;
        curCBPeripheral.delegate = self;    //添加代理
        //发现服务
        [curCBPeripheral discoverServices:nil];

        //通知连接状态
        [self sendConnectState:CONNECTED];
        
        
    }else{
        isConnected = false;
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    curCBPeripheral = nil;
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    
    [self.characteristicDict removeAllObjects];
    self.currConnectDevice = nil;
    
    //通知已断开
    [self sendConnectState:DISCONNECTED];
}

-(void)sendConnectState:(ConnectState)state{
    if(connectStateDelegate){
        dispatch_async(dispatch_get_main_queue(), ^{
            [connectStateDelegate stateChange:state];
        });
    }
}

#pragma mark CBPeripheralDelegate
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    
    for (CBService *s in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:s];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    if(error){
        NSLog(@"didDiscoverCharacteristicsForService error:%@",error);
        return ;
    }
    
    //如果还没有连接
    if(![self isConnectingPeripheral]){
        for (CBService *service in peripheral.services) {
            for (CBCharacteristic *characteristic in service.characteristics) {
                if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:deviceInfoCharacteristicUUID]]) {
                    [characteristicDict setObject:characteristic forKey:deviceInfoCharacteristicUUID];
                    
                }else if([characteristic.UUID isEqual:[CBUUID UUIDWithString:deviceNotifyCharacteristicUUID]]){
                    if(!characteristic.isNotifying){
                        [curCBPeripheral setNotifyValue:TRUE forCharacteristic:characteristic];
                        
                    }
                    [characteristicDict setObject:characteristic forKey:deviceNotifyCharacteristicUUID];
                    
                }else if([characteristic.UUID isEqual:[CBUUID UUIDWithString:deviceWriteCharacteristicUUID]]){
                    [characteristicDict setObject:characteristic forKey:deviceWriteCharacteristicUUID];
                }
            }
        }
        
        //通知服务准备完成
        [self sendConnectState:SERVICES_READY];
        
        //开始初始化笔数据
        for (int i=0; i<10; i++) {
            
            [peripheral readValueForCharacteristic:[characteristicDict objectForKey:deviceNotifyCharacteristicUUID]];
            [NSThread sleepForTimeInterval:0.1];
        }
        NSString *isAuto = [[NSUserDefaults standardUserDefaults] objectForKey:@"isAutoConnect"];
        if (isAuto == nil) {
            isAuto = @"1";
            [[NSUserDefaults standardUserDefaults] setObject:isAuto forKey:@"isAutoConnect"];
        }
        int mark = [isAuto intValue];
        if (mark == 1) {
            [self saveUUID];
        } else{
            [self deleteUUID];
        }
        [self getVersion];
        
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    
    if (error) {
        NSLog(@"error");
    }
    
    NSLog(@"write value:%@",characteristic.UUID.description);
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    
    NSLog(@"didUpdateNotificationStateForCharacteristic %@ %@",characteristic,error);
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    
    
    
    const char *bytes = [characteristic.value bytes];
    
    NSLog(@"receive == %@",characteristic.value);
    
    if (bytes != NULL && sizeof(bytes) >= 6) {
        UInt8 oneByte =bytes[0];
        UInt8 twoByte =bytes[1];
        UInt8 threeByte = bytes[2];
        if (oneByte == KEY_PEN_DATA_ID) {
            
            switch (twoByte){
                case KEY_PEN_DATA:{
                    
                    BlePenUtil *blePenUtil = [[BlePenUtil alloc] init];
                    NSMutableArray *pointList = [blePenUtil getPointList:currConnectDevice bleData:characteristic.value];
                    
                    PointObject *item;
                    if(pointList.count > 0){
                        for (int i = 0;i < pointList.count; i++) {
                            item = [pointList objectAtIndex:i];
                            item.sceneType = SIZE_10;
                            
                            item.width = [self.currConnectDevice getSceneWidth];
                            item.height = [self.currConnectDevice getSceneHeight];
                            
                            [self sendPotinInfoHandler:item];
                        }
                    }
                }
                    break;
                case KEY_GET_FILE_INFO:{
                    [self sendFirmwareInfo];
                }
                    break;
                case KEY_GET_FILE_DATA:{
                    
                    int len = [[NSString stringWithFormat:@"%lu",strtoul([[NSString stringWithFormat:@"%lx",threeByte] UTF8String], 0, 16)] intValue];
                    
                    uint8_t number = bytes[2+len];
                    [self sendFirmwareData:number];
                    
                    
                }
                    break;
                case KEY_GET_CHECKSUM:{
                    NSLog(@"%@",characteristic.value);
                    [self sendFirmwareChecknum];
                    
                }
                    break;
                case KEY_GET_RESULT:{
                    NSLog(@"%@",characteristic.value);
                    
                    uint8_t result = bytes [3];
                    [self checkFirmwareResult:result];
                    
                }
                    break;
                case KEY_SWITCH_DEVICE:
                    if ([self.OTADelegate respondsToSelector:@selector(OTAUpdateState:)]) {
                        [self.OTADelegate OTAUpdateState:RESET];
                    }
                    break;
                case KEY_SET_NAME:
                    
                    break;
                case KEY_GET_VERSION:{
                 
                    uint8_t hw1 = bytes[4];
                    uint8_t hw2 = bytes[3];
                    uint8_t sw4 = bytes[5];
                    uint8_t sw3 = bytes[6];
                    uint8_t sw2 = bytes[7];
                    uint8_t sw1 = bytes[8];
                  
                    NSString *HWStr = [NSString stringWithFormat:@"%d.%d",hw1,hw2];
                    NSString *SWStr = [NSString stringWithFormat:@"%d.%d.%d.%d",sw1,sw2,sw3,sw4];
                   
                    NSString *path = @"http://upgrade.robotpen.cn";
                    NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/%@",path,@"P7_svrupdate.txt"]] options:NSDataReadingMappedAlways error:&error];
                    
                    NSString *MStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    
                    mFirmwarePath = [path stringByAppendingString:[NSString stringWithFormat:@"/P7_%@.bin",MStr]];
                    
                    NSArray *array = [MStr componentsSeparatedByString:@"."];
                  
                    int mark = 0;
                    
                    if ([array[0] intValue] >= sw1) {
                        if ([array[0] intValue] == sw1) {
                            if ([array[1] intValue] >= sw2) {
                                if ([array[1] intValue] == sw2) {
                                    if ([array[2] intValue] >= sw3) {
                                        if ([array[2] intValue] == sw3) {
                                            if ([array[3] intValue] >= sw4) {
                                                mark = 1;
                                                 NSLog(@"mark ===  %d",mark);
                                            }
                                        } else{
                                            mark = 1;
                                        }
                                    }
                                } else{
                                    mark = 1;
                                }
                            }

                        } else{
                            mark = 1;
                        }
                    }
                    
                    [self getCurrDevice].HWStr = HWStr;
                    [self getCurrDevice].SWStr = SWStr;
                    [self getCurrDevice].update = [NSNumber numberWithInteger:mark];

                    [self sendConnectState:PEN_INIT_COMPLETE];
                    
                    
                }
                    break;
                default:
                    break;
            }
            
        }
        
    }
    
    return;
    
    
}



- (void)sendPotinInfoHandler:(PointObject*)point{
    if (pointChangeDelegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [pointChangeDelegate change:point];
        });
    }
}


- (void)writeChar:(NSData *)data{
    
    
    [curCBPeripheral writeValue:data forCharacteristic:characteristicDict[deviceWriteCharacteristicUUID] type:CBCharacteristicWriteWithResponse];
}



- (void)startOTAWithDelegate:(id<OTADelegate>)delegate{
    
    self.OTADelegate = delegate;
    mFirmwareNumber = 0;
    mFirmwareOffset = 0;
    mFirmwareCheckNum = 0;
    NSLog(@"---%@",mFirmwarePath);
    NSError *error;
    if ([self.OTADelegate respondsToSelector:@selector(OTAUpdateState:)]) {
        [self.OTADelegate OTAUpdateState:DATA];
    }
    mFirmwareData = [NSData dataWithContentsOfURL:[NSURL URLWithString:mFirmwarePath] options:NSDataReadingMappedAlways error:&error];
    
    if (mFirmwareData!= nil && mFirmwareData.length > 0) {
        unsigned char penStr[3] = {0};
        penStr[0] = KEY_PEN_DATA_ID;
        *(penStr +1) = KEY_SWITCH_OTA;
        *(penStr +2) = 0x00;
        NSData *data = [NSData dataWithBytes:penStr length:sizeof(char)*3];
        NSLog(@"send === %@",data);
        [self writeChar:data];
    }
    
    
    
}

- (void)sendFirmwareInfo{
    
    if (mFirmwarePath && mFirmwareData && mFirmwareData.length > 0) {
        NSString *ePath = [[[mFirmwarePath lastPathComponent] stringByDeletingPathExtension] stringByReplacingOccurrencesOfString:@"_" withString:@"."];
        NSLog(@"%@",ePath);
        NSArray *array = [ePath componentsSeparatedByString:@"."];
        
        if (array.count != 5) {
            return;
        }
        unsigned char data[11] = {0};
        data[0] = KEY_PEN_DATA_ID;
        data[1] = KEY_GET_FILE_INFO;
        data[2] = 0x08;

        *(data + 3) = ([array[4] intValue] & 0xff);
        *(data + 4) = (([array[3] intValue] & 0xff00) >> 8);
        *(data + 5) = (([array[2] intValue] & 0xff0000) >> 16);
        *(data + 6) = (([array[1] intValue] & 0xff000000) >> 24);
        
        *(data + 7) = (mFirmwareData.length & 0xff);
        *(data + 8) = ((mFirmwareData.length & 0xff00) >> 8);
        *(data + 9) = ((mFirmwareData.length & 0xff0000) >> 16);
        *(data + 10) = ((mFirmwareData.length & 0xff000000) >> 24);
        
        NSData *datas = [NSData dataWithBytes:data length:sizeof(char)*11];
        [self writeChar:datas];
        if ([self.OTADelegate respondsToSelector:@selector(OTAUpdateState:)]) {
            [self.OTADelegate OTAUpdateState:UPDATE];
        }
    }
}


- (void)sendFirmwareData:(uint8_t) number{
    
    
    if (mFirmwareData && mFirmwareData.length > 0) {
        if (number > mFirmwareNumber || (mFirmwareNumber == 255 && number == 0)) {
            mFirmwareNumber = number;
            mFirmwareOffset ++;
            NSLog(@"offset=%d",mFirmwareOffset);
            
        }
        int len = 16;
        int offset = mFirmwareOffset * len;
        int dataLen = (mFirmwareData.length - offset) >= len ? len : (mFirmwareData.length - offset);
        CGFloat progess = offset * 1.0f / (CGFloat)mFirmwareData.length;
        
        if ([self.OTADelegate respondsToSelector:@selector(OTAUpdateState:)]) {
            [self.OTADelegate OTAUpdateProgress:progess];
        }
        unsigned char otaData[4 + dataLen] ;
        
        otaData[0] = KEY_PEN_DATA_ID;
        *(otaData + 1) = KEY_GET_FILE_DATA;
        *(otaData + 3) = number;
        
        if (dataLen <= 0) {
            otaData[2] = 0x02;
            otaData[4] = 0x00;
        } else{
            * (otaData + 2) = dataLen + 1;
            const char *bytes = [mFirmwareData bytes];
            for (int i = 0; i < dataLen; i ++) {
                uint8_t value = bytes[offset + i];
                otaData [4 + i] = value;
                mFirmwareCheckNum += (value & 0xff);
            }
        }
        NSData *data = [NSData dataWithBytes:otaData length:sizeof(char)*(dataLen + 4)];
        NSLog(@"%@",data);
        [self writeChar:data];
    }
    
}

- (void)sendFirmwareChecknum{
    
    if (mFirmwareData && mFirmwareData.length > 0) {
        unsigned char checkData[7];
        * (checkData + 0) = KEY_PEN_DATA_ID;
        * (checkData + 1) = KEY_GET_CHECKSUM;
        * (checkData + 2) = 0x04;
        * (checkData + 3) = mFirmwareCheckNum & 0xff;
        * (checkData + 4) = ((0xff00 & mFirmwareCheckNum) >> 8);
        * (checkData + 5) = ((0xff0000 & mFirmwareCheckNum) >> 16);
        * (checkData + 6) = ((0xff000000 & mFirmwareCheckNum) >> 24);
        
        NSData *data = [NSData dataWithBytes:checkData length:sizeof(char) * 7];
        NSLog(@"check %@",data);
        [self writeChar:data];
    }
}

- (void)checkFirmwareResult:(int)result{
    if (result == 0x00) {
        
        [self endOTA];
        if ([self.OTADelegate respondsToSelector:@selector(OTAUpdateState:)]) {
            [self.OTADelegate OTAUpdateState:SUCCESS];
        }
    } else{
        if ([self.OTADelegate respondsToSelector:@selector(OTAUpdateState:)]) {
            [self.OTADelegate OTAUpdateState:ERROR];
        }
    }
}
- (void)endOTA{
    unsigned char endData[3];
    * (endData + 0) = KEY_PEN_DATA_ID;
    * (endData + 1) = KEY_SWITCH_DEVICE;
    * (endData + 2) = 0x00;
    NSData *data = [NSData dataWithBytes:endData length:sizeof(char) * 3];
    NSLog(@"end %@",data);
    [self writeChar:data];
}



- (void)changeName:(NSString *)name{
    if (name == nil) {
        name = @"Default";
    }
    unsigned char sendData[3 + name.length];
    * (sendData + 0) = KEY_PEN_DATA_ID;
    * (sendData + 1) = KEY_SET_NAME;
    * (sendData + 2) = name.length & 0xff;
    NSLog(@"%@",name);
    for (int i = 0; i < name.length; i ++) {
        NSUInteger asciiCode = [name characterAtIndex:i];
        * (sendData + 3 + i) = asciiCode & 0xff;
    }
    NSData *data = [NSData dataWithBytes:sendData length:sizeof(char) * (3 + name.length)];
    NSLog(@"send %@",data);
    [self writeChar:data];
}


- (void)getVersion{
  
    unsigned char sendData[3];
    * (sendData + 0) = KEY_PEN_DATA_ID;
    * (sendData + 1) = KEY_GET_VERSION;
    * (sendData + 2) = 0x00;
    NSData *data = [NSData dataWithBytes:sendData length:sizeof(char) * 3];
    NSLog(@"send %@",data);
    [self writeChar:data];
}

- (void)saveUUID{
    [[NSUserDefaults standardUserDefaults] setObject:self.currConnectDevice.uuID forKey:@"device_UUID"];
    
}
- (void)deleteUUID{
    [[NSUserDefaults standardUserDefaults] setObject:@"11" forKey:@"device_UUID"];
}

- (void)setAutoConnet:(int)isOpen{
    if (isOpen == 1) {
        [self saveUUID];
        [[NSUserDefaults standardUserDefaults] setObject:@"1" forKey:@"isAutoConnect"];
        NSLog(@"1");
    } else{
        [self deleteUUID];
        [[NSUserDefaults standardUserDefaults] setObject:@"0 " forKey:@"isAutoConnect"];
    }
}
- (void)AutoConntect:(DeviceObject *)device delegate:(id<ConnectStateDelegate>)delegate{
    NSString *isAuto = [[NSUserDefaults standardUserDefaults] objectForKey:@"isAutoConnect"];
    NSString *uuid = [[NSUserDefaults standardUserDefaults] objectForKey:@"device_UUID"];
    if ([device.uuID isEqualToString:uuid] && [isAuto intValue] == 1) {
        [self connectDevice:device delegate:delegate];
        NSLog(@"%@",uuid);
        return;
    }
}

@end
