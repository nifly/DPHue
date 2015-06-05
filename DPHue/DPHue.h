//
//  DPHue.h
//  DPHue
//
//  This class is in the public domain.
//  Originally created by Dan Parsons in 2012.
//
//  https://github.com/danparsons/DPHue

#import <Foundation/Foundation.h>

@class DPHueLight;
@class DPHueLightGroup;


@interface DPHue : NSObject <NSCoding>


#pragma mark - Properties you may be interested in setting

/**
 The API username DPHue will use when communicating with the Hue controller.
 The Hue API requires this be an MD5 hash of something.
 */
@property (nonatomic, copy) NSString *username;

/// The hostname (or IP address) that DPHue will talk to.
@property (nonatomic, copy) NSString *host;


#pragma mark - Properties you may be interested in reading

/**
 The "name" of the Hue controller, as returned by the API.
 
 This can actually be changed via the Hue API if necessary,
 but I didn't implement that feature.
 */
@property (nonatomic, readonly, copy) NSString *name;

/// Firmware version
@property (nonatomic, readonly, copy) NSString *swversion;

/**
 An array of DPHueLight objects representing all the lights
 that the controller is aware of.
 */
@property (nonatomic, readonly, copy) NSArray *lights;

/**
 An array of DPHueLightGroup objects representing all the groups
 that the controller is aware of.
 */
@property (nonatomic, readonly, copy) NSArray *groups;

/// Whether or not we have been fully registered with the controller.
@property (nonatomic, readonly, assign) BOOL authenticated;


#pragma mark - Methods

/**
 Utility method for generating a username that Hue will like. It requires
 usernames to be MD5 hashes.
 
 This method returns a md5 hash of the system's hostname.
 */
+ (NSString *)generateUsername;

/**
 Generate a DPHue object with the given parameters.
 
 @param host
          The hostname or IP of the Hue controller you want to talk to.
 @param username
          An md5 string. Use @p [DPHue generateUsername] to
          create one if you don't have one already. In that case, you'll also
          have to register the username with the controller, using
          @p [DPHue registerUsername].
 */
- (id)initWithHueHost:(NSString *)host username:(NSString *)username;

/**
 Download the complete state of the Hue controller, including the state
 of all lights and groups. @p block is called when the operation is complete.
 This normally takes only 1 to 3 seconds.
 */
- (void)readWithCompletion:(void (^)(DPHue *hue, NSError *err))block;

/**
 This will attempt to register @p self.username with the Hue controller.
 This will fail unless the physical button on the Hue controller has
 been pressed within the last 30 seconds. The workflow for this method
 is a loop: tell the user to press the button on their controller, call
 this method, then check self.authenticated. If NO, keep calling this
 method. See @p DPQuickHue for implementation example.
 */
- (void)registerUsername;

/**
 Triggers the Touchlink feature in a Hue controller, which causes it to
 pair with all lamps it can find, even thoughs that belong to another
 controller. To limit the possibility of "stealing" someone else's lamps,
 the range of this function is limited (by Philips, in the controller firmware)
 to a short distance from the controller.
 
 Calls block when a response is received from the controller.
 */
- (void)triggerTouchlinkWithCompletion:(void (^)(BOOL success, NSString *result))block;

/**
 Search for the light with given @p lightId in @p self.lights
 
 @return The found light, or nil
 */
- (DPHueLight *)lightWithId:(NSNumber *)lightId;

/**
 Search for the light with given @p lightName in @p self.lights
 
 @return The found light, or nil
 */
- (DPHueLight *)lightWithName:(NSString *)lightName;

/**
 Search for the group with given @p groupId in @p self.groups
 
 @return The found group, or nil
 */
- (DPHueLightGroup *)groupWithId:(NSNumber *)groupId;

/**
 Search for the group with given @p groupName in @p self.groups
 
 @return The found group, or nil
 */
- (DPHueLightGroup *)groupWithName:(NSString *)groupName;

// lightIds = @[ NSNumber ]
- (void)createGroupWithName:(NSString *)name lightIds:(NSArray *)lightIds onCompletion:(void (^)(BOOL success, DPHueLightGroup *group))onCompletionBlock;

@end


@interface DPHue (HueAPIRequestGeneration)

- (NSURLRequest *)requestForRegisteringUsername:(NSString *)username withDeviceType:(NSString *)deviceType;
- (NSURLRequest *)requestForReadingControllerState;

@end


@interface DPHue (HueAPIJsonParsing)

// POST /
- (instancetype)parseUsernameRegistration:(id)json;
// GET /
- (instancetype)parseControllerState:(id)json;

@end
