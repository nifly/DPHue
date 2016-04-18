//
//  DPHueSchedule.h
//  Pods
//
//  Created by Jason Dreisbach on 5/12/13.
//
//

#import "DPHueObject.h"

@class DPHueBridge;

@interface DPHueSchedule : NSObject<NSCoding>

- (instancetype)initWithBridge:(DPHueBridge*)aBridge;
- (void)write;

@property (strong) NSString *identifier;
@property (strong) NSString *name;
@property (strong) NSString *scheduleDescription;
@property (strong) NSDictionary *command;
@property (strong) NSDate *date;

@property (nonatomic, copy) NSString* username;
@property (nonatomic, copy) NSString* host;
@property (weak) DPHueBridge* bridge;

@end

