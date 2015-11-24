//
//  DPHueLightGroup.h
//  DPHue
//
//  This class is in the public domain.
//  Created by James Reichley on 6/2/15.
//
//  https://github.com/danparsons/DPHue

#import <Foundation/Foundation.h>


@interface DPHueLightGroup : NSObject <NSCoding>


#pragma mark - Properties you may be interested in setting
// Setting these values does not actually update the Hue
// controller until [DPHueLightGroup write] is called
// (unless self.holdUpdates is set to NO, then changes are
// immediate).

/// Lamp brightness, valid values are 0 - 255.
@property (nonatomic, strong) NSNumber *brightness;

/// Lamp hue, in degrees*182, valid values are 0 - 65535.
@property (nonatomic, strong) NSNumber *hue;

/// Lamp saturation, valid values are 0 - 255.
@property (nonatomic, strong) NSNumber *saturation;

/** 
 Lamp on (or off). When a lamp is told to turn on,
 it returns to its last state, in terms of color,
 brightness, etc. Unless mains power was lost,
 then it returns to factory state, which is a warm color.
 */
@property (nonatomic, assign) BOOL on;

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
 If set to YES, changes are held until [DPHueLightGroup write] is called.
 
 @note Set to YES by default.
 */
@property (nonatomic, assign) BOOL holdUpdates;


#pragma mark - Properties you may be interested in reading

/// Group name, as returned by the controller, or as set during group creation.
@property (nonatomic, readonly, copy) NSString *name;

/**
 The API does not allow changing this value directly. Rather, the color
 mode of a lamp is determined by the last color value type it was given.
 For example, if you last set a lamp's colorTemperature value, then
 colormode would be "ct". If you set hue or saturation, it would be "hs".
 */
@property (nonatomic, readonly, copy) NSString *colorMode; // "xy", "ct" or "hs"

/// The group id, assigned by the controller.
@property (nonatomic, strong) NSNumber *number;

/// @[ NSNumbers ]
@property (nonatomic, copy) NSArray *lightIds;


#pragma mark - Properties you can probably ignore

@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *host;


#pragma mark - Methods

/// Re-download & parse controller's state for this particular group
- (void)read;

/// Write only pending changes to controller
- (void)write;

/// Write entire state to controller, regardless of changes
- (void)writeAll;

@end


@interface DPHueLightGroup (HueAPIRequestGeneration)

- (NSURLRequest *)requestForCreatingWithName:(NSString *)groupName lightIds:(NSArray *)lightIds;
- (NSURLRequest *)requestForUpdatingWithName:(NSString *)groupName lightIds:(NSArray *)lightIds;
- (NSURLRequest *)requestForGettingGroupState;
- (NSURLRequest *)requestForSettingGroupState:(NSDictionary *)state;

@end


@interface DPHueLightGroup (HueAPIJsonParsing)

// POST /groups
- (instancetype)parseGroupCreation:(id)json;

// PUT /groups/{id}
- (instancetype)parseGroupUpdate:(id)json;

// GET /groups/{id}
- (instancetype)parseGroupStateGet:(id)json;

// PUT /groups/{id}/action
- (instancetype)parseGroupStateSet:(id)json;

@end
