//
//  DeviceObject.m
//  SmartPenCore
//
//  Created by Xiaoz on 15/7/16.
//  Copyright (c) 2015年 Xiaoz. All rights reserved.
//

#import "DeviceObject.h"

#define VALUE_A4_WIDTH 10000;
#define VALUE_A4_HEIGHT 14500;

//#define VALUE_A5_WIDTH 7000;
//#define VALUE_A5_HEIGHT 9500;
#define VALUE_A5_WIDTH 8191;
#define VALUE_A5_HEIGHT 14335;

#define VALUE_SIZE10_WIDTH 8191;
#define VALUE_SIZE10_HEIGHT 14335;

@implementation DeviceObject


@synthesize peripheral;
@synthesize sceneType;
@synthesize uuID;
-(NSString *)getName{
    NSString *showName;
    
    //指定规则的名字过滤
    NSRange range = [peripheral.name rangeOfString:@"Pen"];
    if (range.location == 0 && range.length == 3) {
        int index = peripheral.name.length-6;
        //只显示最后6位识别码
        showName = [NSString stringWithFormat:@"Pen%@",[peripheral.name substringFromIndex:index]];
    }else{
        showName = peripheral.name;
    }
    return showName;
}

-(NSInteger)getSceneWidth{
    switch(sceneType){
        case A4:
            return VALUE_A4_WIDTH;
        case A4_horizontal:
            return VALUE_A4_HEIGHT;
        case A5:
            return VALUE_A5_WIDTH;
        case A5_horizontal:
            return VALUE_A5_HEIGHT;
        case SIZE_10:
            return VALUE_SIZE10_WIDTH;
        default:
            return sceneWidth;
    }
}

-(NSInteger)getSceneHeight{
    switch(sceneType){
        case A4:
            return VALUE_A4_HEIGHT;
        case A4_horizontal:
            return VALUE_A4_WIDTH;
        case A5:
            return VALUE_A5_HEIGHT;
        case A5_horizontal:
            return VALUE_A5_WIDTH;
        case SIZE_10:
            return VALUE_SIZE10_HEIGHT;
        default:
            return sceneHeight;
    }
}
- (void)encodeWithCoder:(NSCoder *)aCoder{
  
    [aCoder encodeInteger:self.sceneType forKey:@"sceneType"];
    [aCoder encodeObject:self.uuID forKey:@"peripheral"];
    
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder{
    self = [super init];
    if (self) {
        
        self.sceneType = [aDecoder decodeIntegerForKey:@"sceneType"];
        self.uuID = [aDecoder decodeObjectForKey:@"peripheral"];
        
    }
    return self;
}

@end
