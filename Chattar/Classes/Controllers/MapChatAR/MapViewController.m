//
//  MapViewController.m
//  ChattAR for Facebook
//
//  Created by QuickBlox developers on 3/27/12.
//  Copyright (c) 2012 QuickBlox. All rights reserved.
//

#import "MapViewController.h"
#import "MapChatARViewController.h"
#import "UserAnnotation.h"

@interface MapViewController ()

@end

@implementation MapViewController

@synthesize mapView;
@synthesize delegate;
@synthesize compass;
@synthesize mapPoints = _mapPoints;
@synthesize mapPointsIDs;
@synthesize allFriendsSwitch;
@synthesize allCheckins;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
		self.title = NSLocalizedString(@"Map", nil);
		self.tabBarItem.image = [UIImage imageNamed:@"Around_toolbar_icon.png"];
        
        // logout
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logoutDone) name:kNotificationLogout object:nil];
    }
    return self;
}

-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [mapView setUserInteractionEnabled:NO];
	mapView.userInteractionEnabled = YES;

	MKCoordinateRegion region;
	//Set Zoom level using Span
	MKCoordinateSpan span;  
	region.center=mapView.region.center;
	span.latitudeDelta=150;
	span.longitudeDelta=150;
	region.span=span;
	[mapView setRegion:region animated:YES];
    
    canRotate = NO;
    
    //add rotation gesture 
    UIGestureRecognizer *rotationGestureRecognizer;
    rotationGestureRecognizer = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(spin:)];
    [rotationGestureRecognizer setDelegate:self];
    [self.view addGestureRecognizer:rotationGestureRecognizer];
    [rotationGestureRecognizer release];
    
    
    count     = 0;
    lastCount = 0;
    
    annotationsViewCount = 0;
    
    //add frames for change zoom map
    mapFrameZoomOut.size.width  = 320.0f;
    mapFrameZoomOut.size.height = 387.0f;
    
    mapFrameZoomOut.origin.y = 0;
    mapFrameZoomOut.origin.x = 0;
    
    mapFrameZoomIn.size.width  = 503.0f;
    mapFrameZoomIn.size.height = 503.0f;
    
    mapFrameZoomIn.origin.x = -91.5f;
    mapFrameZoomIn.origin.y = -58.0f;
    
    if(IS_HEIGHT_GTE_568){
        mapFrameZoomOut.size.height = 475.0f;
        
        mapFrameZoomIn.size.height  = 573.0f;
        mapFrameZoomIn.size.width   = 573.0f;
        
        mapFrameZoomIn.origin.x = -126.5f;
        mapFrameZoomIn.origin.y = -49.0f;
    }
    
    //add compass image
    compass = [[UIImageView alloc] init];
    
    CGRect compassFrame;
    compassFrame.size.height = 40;
    compassFrame.size.width  = 40;
    
    compassFrame.origin.x = 260;
    compassFrame.origin.y = 15;
    
    initialRegion = self.mapView.region;
    
    [self.compass setImage:[UIImage imageNamed:@"Compass.png" ]];
    [self.compass setAlpha:0.0f];
    [self.compass setFrame:compassFrame];
    [self.view addSubview:compass];
    [compass release];
    
    annotationsForClustering = [[NSMutableArray alloc] init];
    
    previousRect = mapView.visibleMapRect;
    
    allFriendsSwitch = [CustomSwitch customSwitch];
    [allFriendsSwitch setAutoresizingMask:(UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin)];
    
    if(IS_HEIGHT_GTE_568){
        [allFriendsSwitch setCenter:CGPointMake(280, 448)];
    }else{
        [allFriendsSwitch setCenter:CGPointMake(280, 360)];
    }
    
    [allFriendsSwitch setValue:worldValue];
    [allFriendsSwitch scaleSwitch:0.9];
    [allFriendsSwitch addTarget:self action:@selector(allFriendsSwitchValueDidChanged:) forControlEvents:UIControlEventValueChanged];
	[allFriendsSwitch setBackgroundColor:[UIColor clearColor]];
	[self.view addSubview:allFriendsSwitch];
    
//    _loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
//    _loadingIndicator.center = self.view.center;
//    _loadingIndicator.tag = 1101;
//    [self.view addSubview:_loadingIndicator];
//    [_loadingIndicator startAnimating];

    
}

- (void)viewDidUnload
{
    self.mapView = nil;
    
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


#pragma mark -
#pragma mark Rotation methods

- (void)spin:(UIRotationGestureRecognizer *)gestureRecognizer {
    if(canRotate){
        if(gestureRecognizer.state == UIGestureRecognizerStateBegan){
            lastCount = 0;
        }
    
        count += gestureRecognizer.rotation - lastCount;
        lastCount = gestureRecognizer.rotation;
        [self.mapView setTransform:CGAffineTransformMakeRotation(count)];
        [self.compass setTransform:CGAffineTransformMakeRotation(count)];
        [self rotateAnnotations:(-count)];
    }
}

- (void)rotateAnnotations:(CGFloat) angle{
                        // rotate ALL annotations, all annotations are stored in displayedAnnotations array
    [[self.mapView displayedAnnotations] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
            MKAnnotationView * view = [self.mapView viewForAnnotation:obj];
            [view setTransform:CGAffineTransformMakeRotation(angle)];
        
        }];
}


- (void)refreshWithNewPoints:(NSArray *)mapPoints{
    // remove old
	[mapView removeAnnotations:mapView.annotations];
	
    // add new
	[self addPoints:mapPoints];
    [mapView doClustering];
}

#pragma mark -
#pragma mark Internal data methods
- (void)addPoints:(NSArray *)mapPoints{
    // add new
    for (UserAnnotation* ann in mapPoints) {
        [self.mapView addAnnotation:ann];
    }
    
    [annotationsForClustering addObjectsFromArray:mapPoints];
}

- (void)addPoint:(UserAnnotation *)mapPoint{
    [self.mapView addAnnotation:mapPoint];
}

- (void)clear{
    
    [self.mapView setRegion:initialRegion animated:NO];
    
    [mapView setUserInteractionEnabled:NO];
    [mapView removeAnnotations:mapView.annotations];
	mapView.userInteractionEnabled = YES;
}

-(void)updateStatus:(UserAnnotation*)point{
    NSArray *currentMapAnnotations = [self.mapView.annotations copy];
    
    // Check for Map
    BOOL isExistPoint = NO;
    for (UserAnnotation *annotation in currentMapAnnotations)
	{
        // already exist, change status
        if([point.fbUserId isEqualToString:annotation.fbUserId])
		{
            if ([point.userStatus length] < 6 || ([point.userStatus length] >= 6 && ![[point.userStatus substringToIndex:6] isEqualToString:fbidIdentifier])){
                MapMarkerView *marker = (MapMarkerView *)[self.mapView viewForAnnotation:annotation];
                [marker updateStatus:point.userStatus];// update status
            }
            
            isExistPoint = YES;
            
            break;
        }
    }
    
    [currentMapAnnotations release];

}

#pragma mark -
#pragma mark MKMapViewDelegate

- (MKAnnotationView *)mapView:(MKMapView *)_mapView viewForAnnotation:(id < MKAnnotation >)annotation{
    
                        // if this is cluster 
    if ([annotation isKindOfClass:[OCAnnotation class]]) {

        OCAnnotation* clusterAnnotation = (OCAnnotation*) annotation;
        ClusterMarkerView* clusterView = (ClusterMarkerView*)[mapView dequeueReusableAnnotationViewWithIdentifier:@"ClusterView"];
        [clusterView retain];
        
        UserAnnotation* closest = (UserAnnotation*)[OCAlgorithms calculateClusterCenter:clusterAnnotation];
       
        if (!clusterView) {
            
            // find annotation which is closest to cluster center
            clusterView = [[ClusterMarkerView alloc] initWithAnnotation:closest reuseIdentifier:@"ClusterView"];
            [clusterView setCanShowCallout:YES];

            // if it is photo
            if (closest.photoId) {
                NSString* photoOwner = [closest findAndFriendNameForPhoto:closest];
                [clusterView.userName setText:photoOwner];
                [clusterView.userPhotoView loadImageFromURL:[NSURL URLWithString:closest.thumbnailURL]];
                [clusterView.userStatus setText:closest.locationName];
            }
            
                        
            UITapGestureRecognizer* tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapToZoom:)];
            [clusterView addGestureRecognizer:tap];
            
            [tap release];
        }
        
        if (IS_IOS_6) {
            [clusterView setTransform:CGAffineTransformMakeRotation(0.001)];
            if(count){
                [clusterView setTransform:CGAffineTransformMakeRotation(-count)];
            }
        }
        else{
            double delayInSeconds = 0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^{
                [clusterView setTransform:CGAffineTransformMakeRotation(-count)];
            });
            
        }
        
        [clusterView updateAnnotation:closest];
        
        clusterView.clusterCenter = closest.coordinate;
        
        [clusterView setNumberOfAnnotations:clusterAnnotation.annotationsInCluster.count];
      
        return [clusterView autorelease];
    }
    
    else if([annotation isKindOfClass:[UserAnnotation class]])
    {
        UserAnnotation* ann = (UserAnnotation*)annotation;
                    // if this is photo annotation
        
        
        if (ann.photoId) {
            PhotoMarkerView* photoMarker = (PhotoMarkerView*)[_mapView dequeueReusableAnnotationViewWithIdentifier:@"photoView"];
            if (!photoMarker) {
                photoMarker = [[[PhotoMarkerView alloc] initWithAnnotation:ann reuseIdentifier:@"photoView"] autorelease];
            }
            else{
                [photoMarker updateAnnotation:ann];
            }
            [photoMarker setDelegate:self];
            return photoMarker;
        }
        else
        {
            MapMarkerView *marker = (MapMarkerView *)[_mapView dequeueReusableAnnotationViewWithIdentifier:@"pinView"];
            if(marker == nil){
                marker = [[[MapMarkerView alloc] initWithAnnotation:annotation 
                                            reuseIdentifier:@"pinView"] autorelease];
            }else{
                [marker updateAnnotation:(UserAnnotation *)annotation];
            }
            
            // set touch action
            marker.target = delegate;
            marker.action = @selector(touchOnMarker:);

            if (IS_IOS_6) {
                [marker setTransform:CGAffineTransformMakeRotation(0.001)];
                if(count){
                    [marker setTransform:CGAffineTransformMakeRotation(-count)];
                }
            } else{
                double delayInSeconds = 0;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
                dispatch_after(popTime, dispatch_get_main_queue(), ^{
                    [marker setTransform:CGAffineTransformMakeRotation(-count)];
                });
            }
            return marker;
        }
    }
    
    return nil;
}

-(void)tapToZoom:(UITapGestureRecognizer*) tap{
    
    ClusterMarkerView* clusterView = (ClusterMarkerView*)[tap view];
    MKCoordinateRegion region = self.mapView.region;

    region.span.longitudeDelta = self.mapView.region.span.longitudeDelta/4;
    region.span.latitudeDelta = self.mapView.region.span.latitudeDelta/4;
    
    CLLocationCoordinate2D location = clusterView.clusterCenter;
    region.center.latitude = location.latitude;
    region.center.longitude = location.longitude;
    
    region = [self.mapView regionThatFits:region];

    [self.mapView setRegion:region animated:YES];
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated{
    
    float longitudeDeltaZoomOut = 255.0f;
    float longitudeDeltaZoomIn  = 353.671875f;
    
    float zoomOun = 0.38f;
    float zoomIn  = 0.43f;
    
    if(IS_HEIGHT_GTE_568){
        longitudeDeltaZoomOut = 112.5;
        longitudeDeltaZoomIn  = 180.0f;
    }
    
    if( ((self.mapView.region.span.longitudeDelta / longitudeDeltaZoomOut) < zoomOun) && !canRotate ){
        
        [self.mapView setFrame:mapFrameZoomIn];
        canRotate = YES;
        
        [self.compass setAlpha:1.0f];
    }
        
    
    // rotate map to init state
    if(((self.mapView.region.span.longitudeDelta / longitudeDeltaZoomIn) > zoomIn) && canRotate){
        
        [self.compass setAlpha:0.0f];
        
        count = 0;
        
        double delayInSeconds = 0.3;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^{
            [self.mapView setFrame:mapFrameZoomOut];
            canRotate = NO;
        });
        
        [UIView animateWithDuration:0.3f
                         animations:^{
                             [self.mapView setTransform:CGAffineTransformMakeRotation(count)];
                             [self.compass setTransform:CGAffineTransformMakeRotation(count)];
                             [self rotateAnnotations:(count)];
                         }
         ];
    }
               
    [self.mapView doClustering];
    
}



#pragma mark -
#pragma mark UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
    
    return YES;
}

#pragma mark -
#pragma mark Photo Annotation Displaying Methods
-(void)showPhoto:(AsyncImageView*)photo{
    [photo loadImageFromURL:photo.linkedUrl];
    photo.center = self.view.center;
    [photo setTag:2008];

    UIButton* closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [closeButton setFrame:CGRectMake(photo.frame.size.width-18, -6, 29, 29)];
    [closeButton addTarget:self action:@selector(closeView) forControlEvents:UIControlEventTouchUpInside];
    [closeButton setImage:[UIImage imageNamed:@"FBDialog.bundle/images/close.png"] forState:UIControlStateNormal];
    [photo bringSubviewToFront:closeButton];

    [self.view setUserInteractionEnabled:YES];
    [self.view bringSubviewToFront:photo];
    [photo addSubview:closeButton];
    [photo bringSubviewToFront:closeButton];
    
    [self.view addSubview:photo];
}

-(void)closeView{
    [[self.view viewWithTag:2008] removeFromSuperview];
}


#pragma mark -
#pragma mark FBDataDelegate
-(void)willAddCheckin:(UserAnnotation*)checkin{
    [self.allCheckins addObject:checkin];
}

-(void)didReceiveCachedCheckins:(NSArray *)cachedCheckins{
    [self.allCheckins addObjectsFromArray:cachedCheckins];
}

#pragma mark -
#pragma mark DataDelegate
-(void)mapEndRetrievingData{
//    [activityIndicator removeFromSuperview];
    [self.allFriendsSwitch setEnabled:YES];

}

-(void)didReceiveError:(NSString*)errorMessage{
    
}

-(CLLocation*)sendLocationToBgWorker{
    CLLocationManager* locationManager = [[[CLLocationManager alloc] init] autorelease];
    [locationManager startMonitoringSignificantLocationChanges];
    
    return locationManager.location;
}


#pragma mark -
#pragma mark MapControllerDelegate
-(void) didReceiveCachedMapPoints:(NSArray*)cachedMapPoints{
    if (!_mapPoints) {
        _mapPoints = [[NSMutableArray alloc] init];
    }
    [_mapPoints addObjectsFromArray:cachedMapPoints];
}

-(void) didReceiveCachedMapPointsIDs:(NSArray*)cachedMapIDs{
    if (!mapPointsIDs) {
        mapPointsIDs = [[NSMutableArray alloc] init];
    }
    [mapPointsIDs addObjectsFromArray:cachedMapIDs];
}

-(void) willAddNewPoint:(UserAnnotation*)point isFBCheckin:(BOOL)isFBCheckin{
    NSArray *friendsIds = [[DataManager shared].myFriendsAsDictionary allKeys];
    
    NSArray *currentMapAnnotations = [self.mapView.annotations copy];

    
    BOOL isExistPoint = NO;
    for (UserAnnotation *annotation in currentMapAnnotations)
    {
        NSDate *newCreateDateTime = point.createdAt;
        NSDate *currentCreateDateTime = annotation.createdAt;
        // already exist, change status
        if([point.fbUserId isEqualToString:annotation.fbUserId])
        {
            if([newCreateDateTime compare:currentCreateDateTime] == NSOrderedDescending){
                if ([point.userStatus length] < 6 || ([point.userStatus length] >= 6 && ![[point.userStatus substringToIndex:6] isEqualToString:fbidIdentifier])){
                    MapMarkerView *marker = (MapMarkerView *)[self.mapView viewForAnnotation:annotation];
                    [marker updateStatus:point.userStatus];// update status
                    [marker updateCoordinate:point.coordinate];
                }
            }
            
            isExistPoint = YES;
            
            break;
        }
    }
    
    [currentMapAnnotations release];
    
    if(!isExistPoint){
        BOOL addedToCurrentMapState = NO;
        
        [self.mapPoints addObject:point];
        
        if(point.geoDataID != -1){
            [self.mapPointsIDs addObject:[NSString stringWithFormat:@"%d", point.geoDataID]];
        }
        
        if([self isAllShowed] || [friendsIds containsObject:point.fbUserId]){
            [self.mapPoints addObject:point];
            addedToCurrentMapState = YES;
        }
        //
        if(addedToCurrentMapState){
            [self addPoint:point];
        }
    }
}

- (BOOL)isAllShowed{
    if(allFriendsSwitch.value >= worldValue){
        return YES;
    }
    
    return NO;
}

-(void) willUpdatePointStatus:(UserAnnotation*)newPoint{
    [self updateStatus:newPoint];
}


-(void) willSaveMapARPoints:(NSArray*)newMapPoints{
    [[DataManager shared] addMapARPointsToStorage:newMapPoints];
}

@end
