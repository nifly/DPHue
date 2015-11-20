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

// Conforming to this protocol allows a UI to be informed if a
// Hue controller was found.
@protocol DPHueDiscoverDelegate <NSObject>
- (void)foundHueAt:(NSString *)host discoveryLog:(NSString *)log;
@end

@interface DPHueDiscover : NSObject

@property (nonatomic, weak) id<DPHueDiscoverDelegate> delegate;

- (instancetype)init NS_UNAVAILABLE;
- (id)initWithDelegate:(id<DPHueDiscoverDelegate>)delegate NS_DESIGNATED_INITIALIZER;

// Start discovery process, stopping after specified seconds, calling block when done.
- (void)discoverForDuration:(int)seconds withCompletion:(void (^)(NSMutableString *log))block;

// Stop discovery process early
- (void)stopDiscovery;

@end
