//
//  DPHueDiscover.h
//  DPHue
//
//  This class is in the public domain.
//  Originally created by Dan Parsons in 2012.
//
//  https://github.com/danparsons/DPHue

// DPHueDiscover provides a full Hue controller autodiscovery
// system, using two discovery methods: meethue.com's API
// and also SSDP.
// See QuickHue for implementation example:
// https://github.com/danparsons/QuickHue

#import <Foundation/Foundation.h>

@interface DPHueDiscover : NSObject

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)discoverWithDuration:(NSInteger)duration hueFound:(void(^_Nullable)(NSString* host, NSString* mac))hueFound completion:(void(^_Nullable)(NSDictionary* discovered, NSString* log, NSError* error))completion;

- (instancetype)initWithDuration:(NSInteger)duration hueFound:(void(^_Nullable)(NSString* host, NSString* mac))hueFound completion:(void(^_Nullable)(NSDictionary* discovered, NSString* log, NSError* error))completion;

- (void)stopDiscovery;

@end
