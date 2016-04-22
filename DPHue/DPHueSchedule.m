//
//  DPHueSchedule.m
//  Pods
//
//  Created by Jason Dreisbach on 5/12/13.
//
//

#import "DPHueSchedule.h"
#import "DPHueBridge.h"
#import "DPJSONConnection.h"

@implementation DPHueSchedule

- (instancetype)initWithBridge:(DPHueBridge*)aBridge {
    self = [super init];
    if (self) {
        [self performCommonInit];
        _bridge = aBridge;
        _username = _bridge.generatedUsername;
        _host = _bridge.host;
    }
    return self;
}

- (void)performCommonInit {
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)coder
{
    if (self = [super init]) {
        [self performCommonInit];
        _name = [coder decodeObjectForKey:@"name"];
        _identifier = [coder decodeObjectForKey:@"identifier"];
        _scheduleDescription = [coder decodeObjectForKey:@"scheduleDescription"];
        _command = [coder decodeObjectForKey:@"command"];
        _date = [coder decodeObjectForKey:@"date"];
        _host = [coder decodeObjectForKey:@"host"];
        _username = [coder decodeObjectForKey:@"username"];
        
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (_name)
        [coder encodeObject:_name forKey:@"name"];
    if (_identifier)
        [coder encodeObject:_identifier forKey:@"identifier"];
    if (_scheduleDescription)
        [coder encodeObject:_scheduleDescription forKey:@"scheduleDescription"];
    if (_command)
        [coder encodeObject:_command forKey:@"command"];
    if (_date)
        [coder encodeObject:_date forKey:@"date"];
    if (_host)
        [coder encodeObject:_host forKey:@"host"];
    if (_username)
        [coder encodeObject:_username forKey:@"username"];
}

#pragma mark -

- (NSURL *)baseURL {
    NSAssert([self.host length], @"No host set");
    NSAssert([self.username length], @"No username set");
    return [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/api/%@/schedules", self.host, self.username]];
}

- (NSURLRequest *)requestForGettingSchedule {
    return [NSURLRequest requestWithURL:[self baseURL]];;
}

- (NSURLRequest *)requestForSettingSchedule:(NSDictionary*)aData {
    NSData *json = [NSJSONSerialization dataWithJSONObject:aData options:0 error:nil];
    NSMutableURLRequest *request = [NSMutableURLRequest new];
    request.URL = [self baseURL];
    request.HTTPMethod = _identifier.length > 0 ? @"PUT" : @"POST";
    request.HTTPBody = json;
    return [request copy];
}


- (void)write {
    NSMutableDictionary *scheduleData = [NSMutableDictionary dictionary];
    
    if (_name.length > 0)
        scheduleData[@"name"] = _name;
    
    if (_scheduleDescription.length > 0)
        scheduleData[@"description"] = _scheduleDescription.length > 64 ? [_scheduleDescription substringToIndex:64] : _scheduleDescription;
    
    // TODO: make sure this doesn't get past 90 characters
    if (_command.count > 0)
        scheduleData[@"command"] = _command;
    
    if (_date != nil) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
        [formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'"];
        scheduleData[@"time"] = [formatter stringFromDate:_date];
    }
    
    DPJSONConnection *connection = [[DPJSONConnection alloc] initWithRequest:[self requestForSettingSchedule:[NSDictionary dictionaryWithDictionary:scheduleData]] sender:self];
    connection.completionBlock = ^(DPHueSchedule *sender, id json, NSError *err) {
        if ( err )
            return;
        [sender readFromJSONDictionary:json];
    };
    
    if (_bridge) {
        [_bridge queueCommand:connection maxPerSecond:10];
    } else {
        [connection start];
    }
}

- (void)readFromJSONDictionary:(id)d {
    if (![d respondsToSelector:@selector(objectForKeyedSubscript:)]) {
        // We were given an array, not a dict, which means
        // the Hue is telling us the result of a PUT
        // Loop through all results, if any are not successful, error out
        BOOL errorFound = NO;
        
        for (NSDictionary *result in d) {
            if (result[@"error"]) {
                errorFound = YES;
                // NSLog(@"%@", result[@"error"]);
            }
            if (result[@"success"]) {
                // NSLog(@"%@", result[@"success"]);
            }
        }
    }
}

@end