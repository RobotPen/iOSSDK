//
//  PointObject.m
//  SmartPenCore
//
//  Created by Xiaoz on 15/7/22.
//  Copyright (c) 2015年 Xiaoz. All rights reserved.
//

#import "PointObject.h"

@implementation PointObject

@synthesize originalX;
@synthesize originalY;
@synthesize width;
@synthesize height;
@synthesize isRoute;
@synthesize isSw1;
@synthesize isMove;
@synthesize battery;
@synthesize sceneType;

-(NSString *)toString{
    NSString* string = [NSString stringWithFormat:@"x:%d,y:%d",originalX, originalY];
    return string;
}

-(short)getSceneX{
    return [self getSceneX:0];
}
-(float)getSceneX:(int)showWidth{

    short value = (short)originalX ;
    if(value < 0){
        value = 0;
    }else if(value > width){
        value = width;
    }
    CGFloat result;

    if(showWidth > 0){
        //按显示宽度等比缩放
       result =   (float)value * ((float)showWidth / (float)width);
   
    }
    return result;
}

-(short)getSceneY{
    return [self getSceneY:0];
}
-(float)getSceneY:(int)showHeight{
    //计算偏移量
    short value = originalY ;
    CGFloat result;
    if(showHeight > 0){
        //按显示宽度等比缩放
        result = (float)showHeight - ((CGFloat)value * ((float)showHeight / (float)height));
    }
    return result;
}

@end
