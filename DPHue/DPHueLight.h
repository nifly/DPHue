//
//  DPHueLight.h
//  DPHue
//
//  This class is in the public domain.
//  Originally created by Dan Parsons in 2012.
//
//  https://github.com/danparsons/DPHue

#import <Foundation/Foundation.h>

@class DPHueBridge;

@interface DPHueLight : NSObject <NSCoding>

- (id)initWithBridge:(DPHueBridge *)aBridge;

#pragma mark - Properties you may be interested in setting
// Setting these values does not actually update the Hue
// controller until [DPHueLight write] is called
// (unless self.holdUpdates is set to NO, then changes are
// immediate).

/// Lamp brightness, valid values are 0 - 255.
@property (nonatomic, strong) NSNumber *brightness;

/// Lamp hue, in degrees*182, valid valuse are 0 - 65535.
@property (nonatomic, strong) NSNumber *hue;

/// Lamp saturation, valid values are 0 - 255.
@property (nonatomic, strong) NSNumber *saturation;

/**
 Lamp on (or off). When a lamp is told to turn on,
 it returns to its last state, in terms of color,
 brightness, etc. Unless mains power was lost,
 then it returns to factory state, which is a warm color.
 */
@property (nonatomic) BOOL on;

/**
 Color in (x,y) CIE 1931 coordinates. See below URL for details:<br />
 <a href="http://en.wikipedia.org/wiki/CIE_1931" >http://en.wikipedia.org/wiki/CIE_1931</a>
 */
@property (nonatomic, copy) NSArray *xy;

/// Color temperature in mireds, valid values are 154 - 500.
@property (nonatomic, strong) NSNumber *colorTemperature;

/**
 Specifies how quickly a lamp should change from its old state
 to new state. Supposedly a setting of 0 allows for instant
 changes, but this hasn't worked well for me.
 */
@property (nonatomic, strong) NSNumber *transitionTime;

/**
 Current alert state.
 
 Possible values: ["none", "select", "lselect"]
 */
@property (nonatomic, copy) NSString *alert;

/**
 If set to YES, changes are held until [DPHueLight write] is called.
 
 @note Set to YES by default.
 */
@property (nonatomic, assign) BOOL holdUpdates;


#pragma mark - Properties you may be interested in reading

/// Lamp name, as returned by the controller.
@property (nonatomic, readonly, copy) NSString *name;

/**
 The API does not allow changing this value directly. Rather, the color
 mode of a lamp is determined by the last color value type it was given.
 For example, if you last set a lamp's colorTemperature value, then
 colormode would be "ct". If you set hue or saturation, it would be "hs".
 */
@property (nonatomic, readonly, copy) NSString *colorMode; // "xy", "ct" or "hs"

/**
 This returns the controller's best guess as to whether the lamp is
 reachable by the controller or not.
 */
@property (nonatomic, readonly, assign) BOOL reachable;

/// Firmware version of the lamp.
@property (nonatomic, readonly, copy) NSString *swversion;

/// Lamp model type.
@property (nonatomic, readonly, copy) NSString *type;

/// The number of the lamp, assigned by the controller.
@property (nonatomic, strong) NSNumber *number;

/// Lamp model ID.
@property (nonatomic, readonly, copy) NSString *modelid;


#pragma mark - Properties you can probably ignore

@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *host;
@property (nonatomic, readonly) NSString* address;

@property (nonatomic, weak) DPHueBridge *bridge;

#pragma mark - Methods

- (void)alertLight;

/// Re-download & parse controller's state for this particular light
- (void)readWithSuccess:(void(^)(BOOL success))onCompleted;

/// Re-download & parse controller's state for this particular light
- (void)read;

/// Write only pending changes to controller
- (void)write;

/// Write entire state to controller, regardless of changes
- (void)writeAll;

@end


@interface DPHueLight (HueAPIRequestGeneration)

- (NSURLRequest *)requestForGettingLightState;
- (NSURLRequest *)requestForSettingLightState:(NSDictionary *)state;

@end


@interface DPHueLight (HueAPIJsonParsing)

// GET /lights/{id}
- (instancetype)parseLightStateGet:(id)json;

// PUT /lights/{id}/state
- (instancetype)parseLightStateSet:(id)json;

@end
