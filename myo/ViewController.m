//
//  ViewController.m
//  myo
//
//  Created by Larry Wang on 3/11/15.
//  Copyright (c) 2015 Larry Wang. All rights reserved.
//

#import "ViewController.h"
#import "MyoKit/MyoKit.h"
#import "F53OSC.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UILabel *helloLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *accelerationProgressBar;
@property (weak, nonatomic) IBOutlet UILabel *accelerationLabel;
@property (weak, nonatomic) IBOutlet UILabel *armLabel;
@property (weak, nonatomic) IBOutlet UILabel *lockLabel;
@property (strong, nonatomic) TLMPose *currentPose;
@property (nonatomic) NSInteger currentlyAttaching;
@property (strong, nonatomic) NSUUID *leftMyoID;
@property (strong, nonatomic) NSUUID *rightMyoID;
@property (strong, nonatomic) F53OSCClient *oscClient;
@property (nonatomic) BOOL leftConnected;
@property (nonatomic) BOOL rightConnected;
@property (strong, nonatomic) NSString *performerId;
@property (strong, nonatomic) NSString *serverIP;
@property (nonatomic) int portNumber;
@property (nonatomic) BOOL moreReconnectNeeded;


- (IBAction)didTapConnectLeft:(id)sender;
- (IBAction)didTapConnectRight:(id)sender;


- (IBAction)didTapSettings:(id)sender;
- (IBAction)didTapReset:(id)sender;



@end

@implementation ViewController


//OSC Values
const double LEFT=0;
const double RIGHT=1;
const double NONE = -1;

//OSC Addresses

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    // Data notifications are received through NSNotificationCenter.
    // Posted whenever a TLMMyo connects
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didConnectDevice:)
                                                 name:TLMHubDidConnectDeviceNotification
                                               object:nil];
    
    
    
    
    // Posted whenever a TLMMyo disconnects.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didDisconnectDevice:)
                                                 name:TLMHubDidDisconnectDeviceNotification
                                               object:nil];
    // Posted whenever the user does a successful Sync Gesture.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didSyncArm:)
                                                 name:TLMMyoDidReceiveArmSyncEventNotification
                                               object:nil];
    // Posted whenever Myo loses sync with an arm (when Myo is taken off, or moved enough on the user's arm).
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didUnsyncArm:)
                                                 name:TLMMyoDidReceiveArmUnsyncEventNotification
                                               object:nil];
    // Posted whenever Myo is unlocked and the application uses TLMLockingPolicyStandard.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didUnlockDevice:)
                                                 name:TLMMyoDidReceiveUnlockEventNotification
                                               object:nil];
    // Posted whenever Myo is locked and the application uses TLMLockingPolicyStandard.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didLockDevice:)
                                                 name:TLMMyoDidReceiveLockEventNotification
                                               object:nil];
    // Posted when a new orientation event is available from a TLMMyo. Notifications are posted at a rate of 50 Hz.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveOrientationEvent:)
                                                 name:TLMMyoDidReceiveOrientationEventNotification
                                               object:nil];
    // Posted when a new accelerometer event is available from a TLMMyo. Notifications are posted at a rate of 50 Hz.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveAccelerometerEvent:)
                                                 name:TLMMyoDidReceiveAccelerometerEventNotification
                                               object:nil];
    // Posted when a new pose is available from a TLMMyo.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceivePoseChange:)
                                                 name:TLMMyoDidReceivePoseChangedNotification
                                               object:nil];
    
    //OSC client
    self.oscClient = [[F53OSCClient alloc]init];
    
    
    self.serverIP = @"18.111.17.94";
    self.portNumber = 9000;
    
    //Initialize
    self.leftConnected = false;
    self.rightConnected = false;
    self.moreReconnectNeeded = false;
    
}


#pragma mark - NSNotificationCenter Methods
- (void)didConnectDevice:(NSNotification *)notification {
    // Align our label to be in the center of the view.
    [self.helloLabel setCenter:self.view.center];
    // Set the text of the armLabel to "Perform the Sync Gesture".
    self.armLabel.text = @"Perform the Sync Gesture";
    // Set the text of our helloLabel to be "Hello Myo".
    self.helloLabel.text = @"Hello Myo";
    // Show the acceleration progress bar
    [self.accelerationProgressBar setHidden:NO];
    [self.accelerationLabel setHidden:NO];
    
    
    
    if(self.currentlyAttaching == RIGHT){
        NSLog(@"RIGHT DETECTED");
        NSArray* myoIds = [self getConnectedMyoIds];
        for(int i = 0; i < myoIds.count; i++){
            if(myoIds[i] != self.leftMyoID){
                self.rightMyoID = myoIds[i];
                self.rightConnected = true;
                NSLog(@"RIGHT CONNECTED");
            }
        }
        if(!self.rightConnected){
            NSLog(@"CANNOT CONNECT LEFT TO RIGHT MYO");
            [[TLMHub sharedHub] detachFromMyo:[self getMyoWithId:self.leftMyoID]];
        }
        self.currentlyAttaching = NONE;
        
    }
    else if(self.currentlyAttaching == LEFT){
        NSLog(@"LEFT DETECTED");
        NSArray* myoIds = [self getConnectedMyoIds];
        for(int i = 0; i < myoIds.count; i++){
            if(myoIds[i] != self.rightMyoID){
                self.leftMyoID = myoIds[i];
                self.leftConnected = true;
                NSLog(@"LEFT CONNECTED");
            }
        }
        if(!self.leftConnected){
            NSLog(@"CANNOT CONNECT RIGHT TO LEFT MYO");
            [[TLMHub sharedHub] detachFromMyo:[self getMyoWithId:self.rightMyoID]];
        }
        
        self.currentlyAttaching = NONE;
    }
    if(self.rightConnected == true && self.leftConnected == true){
        [self everythingReady];
    }
    
    if(self.moreReconnectNeeded){
        [self reconnect];
        self.moreReconnectNeeded = false;
    }
}
- (void)didDisconnectDevice:(NSNotification *)notification {
    // Remove the text from our labels when the Myo has disconnected.
    self.helloLabel.text = @"";
    self.armLabel.text = @"";
    self.lockLabel.text = @"";
    // Hide the acceleration progress bar.
    [self.accelerationProgressBar setHidden:YES];
    [self.accelerationLabel setHidden:YES];
    
    NSLog(@"DISCONNECTED DEVICE");
    
    NSArray *myoIds = [self getConnectedMyoIds];
    
    
    if(self.leftConnected && ![myoIds containsObject:self.leftMyoID]){
        self.leftConnected = false;
        NSLog(@"LEFT WAS DISCONNECTED:%@",self.leftMyoID);
        [self reconnect];
        
    }
    if(self.rightConnected && ![myoIds containsObject:self.rightMyoID]){
        self.rightConnected = false;
        NSLog(@"RIGHT WAS DISCONNECTED:%@",self.rightMyoID);
        [self reconnect];
    }
}
- (void)didUnlockDevice:(NSNotification *)notification {
    // Update the label to reflect Myo's lock state.
    self.lockLabel.text = @"Unlocked";
}
- (void)didLockDevice:(NSNotification *)notification {
    // Update the label to reflect Myo's lock state.
    self.lockLabel.text = @"Locked";
}
- (void)didSyncArm:(NSNotification *)notification {
    // Retrieve the arm event from the notification's userInfo with the kTLMKeyArmSyncEvent key.
    TLMArmSyncEvent *armEvent = notification.userInfo[kTLMKeyArmSyncEvent];
    // Update the armLabel with arm information.
    NSString *armString = armEvent.arm == TLMArmRight ? @"Right" : @"Left";
    NSString *directionString = armEvent.xDirection == TLMArmXDirectionTowardWrist ? @"Toward Wrist" : @"Toward Elbow";
    self.armLabel.text = [NSString stringWithFormat:@"Arm: %@ X-Direction: %@", armString, directionString];
    self.lockLabel.text = @"Locked";
    
    //DON'T USE ANYMORE
    //    //Register as left or right
    //    if(self.currentlyAttaching == LEFT){
    //        self.leftMyoID = armEvent.myo.identifier;
    //        NSLog(@"Succesfully registered LEFT:@%@", self.leftMyoID);
    //    }
    //    else if(self.currentlyAttaching == RIGHT){
    //        self.rightMyoID = armEvent.myo.identifier;
    //        NSLog(@"Succesfully registered RIGHT:@%@", self.leftMyoID);
    //    }
    
    //    NSLog(@"notification received: %@", notification);
    
    
    
}
- (void)didUnsyncArm:(NSNotification *)notification {
    // Reset the labels.
    self.armLabel.text = @"Perform the Sync Gesture";
    self.helloLabel.text = @"Hello Myo";
    self.lockLabel.text = @"";
    self.helloLabel.font = [UIFont fontWithName:@"Helvetica Neue" size:50];
    self.helloLabel.textColor = [UIColor blackColor];
}
- (void)didReceiveOrientationEvent:(NSNotification *)notification {
    // Retrieve the orientation from the NSNotification's userInfo with the kTLMKeyOrientationEvent key.
    TLMOrientationEvent *orientationEvent = notification.userInfo[kTLMKeyOrientationEvent];
    // Create Euler angles from the quaternion of the orientation.
    TLMEulerAngles *angles = [TLMEulerAngles anglesWithQuaternion:orientationEvent.quaternion];
    // Next, we want to apply a rotation and perspective transformation based on the pitch, yaw, and roll.
    CATransform3D rotationAndPerspectiveTransform = CATransform3DConcat(CATransform3DConcat(CATransform3DRotate (CATransform3DIdentity, angles.pitch.radians, -1.0, 0.0, 0.0), CATransform3DRotate(CATransform3DIdentity, angles.yaw.radians, 0.0, 1.0, 0.0)), CATransform3DRotate(CATransform3DIdentity, angles.roll.radians, 0.0, 0.0, -1.0));
    // Apply the rotation and perspective transform to helloLabel.
    
    float w = orientationEvent.quaternion.w;
    float x = orientationEvent.quaternion.x;
    float y = orientationEvent.quaternion.y;
    float z = orientationEvent.quaternion.z;
    
    NSInteger leftOrRight = [self getLeftOrRightInteger:orientationEvent.myo.identifier];
    NSString *leftOrRightString = [self getLeftOrRightString:orientationEvent.myo.identifier];
    
    if(leftOrRight != NONE){
        NSString *address = [self oscAddressWithId:@"id" withDataType:@"ori" withHand:leftOrRightString];
        [self sendOrientationOSC:address :x :y :z :w];
    }
    
    self.helloLabel.layer.transform = rotationAndPerspectiveTransform;
}


-(NSString*)oscAddressWithId:(NSString *)playerId withDataType:(NSString *)dataType withHand:(NSString *)hand{
    return [NSString stringWithFormat:@"/%@/%@/%@/%@", playerId, @"myo", dataType, hand];
}

-(void)sendOrientationOSC:(NSString *)address :(float)x :(float)y :(float)z :(float)w{
    F53OSCMessage *message =
    [F53OSCMessage messageWithAddressPattern:address
                                   arguments:@[
                                               [NSNumber numberWithFloat:x],
                                               [NSNumber numberWithFloat:y],
                                               [NSNumber numberWithFloat:z],
                                               [NSNumber numberWithFloat:w]]
     ];
    [self.oscClient sendPacket:message toHost:self.serverIP onPort:self.portNumber];
}

- (void)didReceiveAccelerometerEvent:(NSNotification *)notification {
    // Retrieve the accelerometer event from the NSNotification's userInfo with the kTLMKeyAccelerometerEvent.
    TLMAccelerometerEvent *accelerometerEvent = notification.userInfo[kTLMKeyAccelerometerEvent];
    
    
    // DON'T USE, DONE IN ATTACH NOW
    //    //Register as left or right
    //    if(self.currentlyAttaching == LEFT){
    //
    //        if(accelerometerEvent.myo.identifier != self.rightMyoID){
    //            self.leftMyoID = accelerometerEvent.myo.identifier;
    //            NSLog(@"Succesfully registered LEFT:@%@", self.leftMyoID);
    //            self.leftConnected = true;
    //            self.currentlyAttaching = NONE;
    //        }
    //
    //    }
    //    else if(self.currentlyAttaching == RIGHT){
    //        if(accelerometerEvent.myo.identifier != self.leftMyoID){
    //            self.rightMyoID = accelerometerEvent.myo.identifier;
    //            NSLog(@"Succesfully registered RIGHT:@%@", self.rightMyoID);
    //            self.rightConnected = false;
    //            self.currentlyAttaching = NONE;
    //        }
    //    }
    //
    
    // Get the acceleration vector from the accelerometer event.
    TLMVector3 accelerationVector = accelerometerEvent.vector;
    // Calculate the magnitude of the acceleration vector.
    float magnitude = TLMVector3Length(accelerationVector);
    // Update the progress bar based on the magnitude of the acceleration vector.
    self.accelerationProgressBar.progress = magnitude / 8;
    /* Note you can also access the x, y, z values of the acceleration (in G's) like below
     float x = accelerationVector.x;
     float y = accelerationVector.y;
     float z = accelerationVector.z;
     */
    //    float x = accelerationVector.x;
    //    float y = accelerationVector.y;
    //    float z = accelerationVector.z;
    //
    //    NSInteger leftOrRight = [self getLeftOrRightInteger:accelerometerEvent.myo.identifier];
    //
    //SEND OSC
    //
    //    if(leftOrRight != NONE){
    //        F53OSCMessage *message =
    //        [F53OSCMessage messageWithAddressPattern:@"/leftOrRight/x/y/z"
    //                                       arguments:@[[NSNumber numberWithInt:leftOrRight],[NSNumber numberWithFloat:x],[NSNumber numberWithFloat:y],[NSNumber numberWithFloat:z]]];
    //        [self.oscClient sendPacket:message toHost:@"18.111.15.21" onPort:8000];
    //    }
}
- (void)didReceivePoseChange:(NSNotification *)notification {
    // Retrieve the pose from the NSNotification's userInfo with the kTLMKeyPose key.
    TLMPose *pose = notification.userInfo[kTLMKeyPose];
    self.currentPose = pose;
    // Handle the cases of the TLMPoseType enumeration, and change the color of helloLabel based on the pose we receive.
    switch (pose.type) {
        case TLMPoseTypeUnknown:
        case TLMPoseTypeRest:
        case TLMPoseTypeDoubleTap:
            // Changes helloLabel's font to Helvetica Neue when the user is in a rest or unknown pose.
            self.helloLabel.text = @"Hello Myo";
            self.helloLabel.font = [UIFont fontWithName:@"Helvetica Neue" size:50];
            self.helloLabel.textColor = [UIColor blackColor];
            break;
        case TLMPoseTypeFist:
            // Changes helloLabel's font to Noteworthy when the user is in a fist pose.
            self.helloLabel.text = @"Fist";
            self.helloLabel.font = [UIFont fontWithName:@"Noteworthy" size:50];
            self.helloLabel.textColor = [UIColor greenColor];
            break;
        case TLMPoseTypeWaveIn:
            // Changes helloLabel's font to Courier New when the user is in a wave in pose.
            self.helloLabel.text = @"Wave In";
            self.helloLabel.font = [UIFont fontWithName:@"Courier New" size:50];
            self.helloLabel.textColor = [UIColor greenColor];
            break;
        case TLMPoseTypeWaveOut:
            // Changes helloLabel's font to Snell Roundhand when the user is in a wave out pose.
            self.helloLabel.text = @"Wave Out";
            self.helloLabel.font = [UIFont fontWithName:@"Snell Roundhand" size:50];
            self.helloLabel.textColor = [UIColor greenColor];
            break;
        case TLMPoseTypeFingersSpread:
            // Changes helloLabel's font to Chalkduster when the user is in a fingers spread pose.
            self.helloLabel.text = @"Fingers Spread";
            self.helloLabel.font = [UIFont fontWithName:@"Chalkduster" size:50];
            self.helloLabel.textColor = [UIColor greenColor];
            break;
    }
    //    // Unlock the Myo whenever we receive a pose
    //    if (pose.type == TLMPoseTypeUnknown || pose.type == TLMPoseTypeRest) {
    //        // Causes the Myo to lock after a short period.
    //        [pose.myo unlockWithType:TLMUnlockTypeTimed];
    //    } else {
    //        // Keeps the Myo unlocked until specified.
    //        // This is required to keep Myo unlocked while holding a pose, but if a pose is not being held, use
    //        // TLMUnlockTypeTimed to restart the timer.
    //        [pose.myo unlockWithType:TLMUnlockTypeHold];
    //        // Indicates that a user action has been performed.
    //        [pose.myo indicateUserAction];
    //    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Presenting modally
- (void)modalPresentMyoSettings {
    UINavigationController *settings = [TLMSettingsViewController settingsInNavigationController];
    
    [self presentViewController:settings animated:YES completion:nil];
}

- (IBAction)didTapSettings:(id)sender {
    // Note that when the settings view controller is presented to the user, it must be in a UINavigationController.
    UINavigationController *controller = [TLMSettingsViewController settingsInNavigationController];
    // Present the settings view controller modally.
    [self presentViewController:controller animated:YES completion:nil];
}


- (IBAction)didTapConnectLeft:(id)sender {
    NSLog(@"ATTEMTPING TO CONNECT LEFT");
    if(self.leftConnected){
        NSLog(@"ALREADY CONNECTED TO LEFT");
    }else{
        self.currentlyAttaching = LEFT;
        [[TLMHub sharedHub] attachToAdjacent];
    }
}

- (IBAction)didTapConnectRight:(id)sender {
    NSLog(@"ATTEMTPING TO CONNECT RIGHT");
    if(self.rightConnected){
        NSLog(@"ALREADY CONNECTED TO RIGHT");
    }else{
        self.currentlyAttaching = RIGHT;
        [[TLMHub sharedHub] attachToAdjacent];
    }
}
- (IBAction)didTapReset:(id)sender {
    [self hard_reset];
}

- (BOOL) isLeftConnected{
    return self.leftConnected;
}
- (BOOL) isRightConnected{
    return self.rightConnected;
}
- (NSUUID *) getLeftMyoID{
    return self.leftMyoID;
}

- (NSUUID *) getRightMyoID{
    return self.rightMyoID;
}

- (NSMutableArray *)getConnectedMyoIds{
    NSArray *myos = [[TLMHub sharedHub] myoDevices];
    NSMutableArray *myoIds = [NSMutableArray arrayWithCapacity:2];
    
    for (int i=0; i<myos.count; i++) {
        TLMMyo *myo = myos[i];
        [myoIds addObject:myo.identifier];
    }
    return myoIds;
}

- (TLMMyo *)getMyoWithId:(NSUUID*)myoId{
    NSArray *myos = [[TLMHub sharedHub] myoDevices];
    
    for (int i=0; i<myos.count; i++) {
        TLMMyo *myo = myos[i];
        if(myo.identifier == myoId){
            return myo;
        }
    }
    return nil;
}


//Called when everything is setup
- (void) everythingReady{
    NSLog(@"Everything Ready");
}

- (void) rightDisconnected{
    //try to reconnect
}

- (void) leftDisconnected{
    //try to reconnect
}


- (void) reconnect{
    //can only reconnect one at a time. Always attach left first
    if(self.leftMyoID != nil && !self.leftConnected){
        NSLog(@"ATTEMPTING TO RECONNECT LEFT");
        [[TLMHub sharedHub] attachByIdentifier:self.leftMyoID];
        self.currentlyAttaching=LEFT;
        self.moreReconnectNeeded = self.rightMyoID != nil && !self.rightConnected;
    }
    
    else if(self.rightMyoID != nil && !self.rightConnected){
        NSLog(@"ATTEMPTING TO RECONNECT RIGHT");
        self.currentlyAttaching=RIGHT;
        [[TLMHub sharedHub] attachByIdentifier:self.rightMyoID];
    }
}


- (void) hard_reset{
    self.leftConnected = false;
    self.rightConnected = false;
    self.currentlyAttaching=NONE;
    
    self.leftMyoID = Nil;
    self.rightMyoID = Nil;
    
    NSArray *myos = [[TLMHub sharedHub] myoDevices];
    
    for(int i = 0; i < myos.count; i++){
        [[TLMHub sharedHub] detachFromMyo:myos[i]];
    }
}


- (NSInteger)getLeftOrRightInteger:(NSUUID*) myoId{
    if(myoId == self.leftMyoID){
        return LEFT;
    }
    else if (myoId == self.rightMyoID){
        return RIGHT;
    }
    else{
        return -1;
    }
}


- (NSString*)getLeftOrRightString:(NSUUID*) myoId{
    if(myoId == self.leftMyoID){
        return @"left";
    }
    else if (myoId == self.rightMyoID){
        return @"right";
    }
    else{
        return @"error";
    }
}








@end
