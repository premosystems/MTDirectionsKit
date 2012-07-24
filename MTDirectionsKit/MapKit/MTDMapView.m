#import "MTDMapView.h"
#import "MTDAddress.h"
#import "MTDWaypoint.h"
#import "MTDDistance.h"
#import "MTDDirectionsDelegate.h"
#import "MTDDirectionsRequest.h"
#import "MTDDirectionsOverlay.h"
#import "MTDDirectionsOverlayView.h"
#import "MTDFunctions.h"


@interface MTDMapView () <MKMapViewDelegate> {
    // flags for methods implemented in the delegate
    struct {
        unsigned int willStartLoadingDirections:1;
        unsigned int didFinishLoadingOverlay:1;
        unsigned int didFailLoadingOverlay:1;
        unsigned int colorForOverlay:1;
        unsigned int lineWidthFactorForOverlay:1;
	} _directionsDelegateFlags;
}

@property (nonatomic, strong, readwrite) MTDDirectionsOverlayView *directionsOverlayView; // re-defined as read/write

/** The delegate that was set by the user, we forward all delegate calls */
@property (nonatomic, mtd_weak, setter = mtd_setTrueDelegate:) id<MKMapViewDelegate> mtd_trueDelegate;
/** The request object for retreiving directions from the specified API */
@property (nonatomic, strong, setter = mtd_setRequest:) MTDDirectionsRequest *mtd_request;

/** Common initialize method for initializing from code or from a NIB */
- (void)mtd_setup;

- (void)mtd_updateUIForDirectionsDisplayType:(MTDDirectionsDisplayType)displayType;

/**
 Sets the region that is displayed on the map to show all the given waypoints within a rect with 
 the specified edgePadding.
 
 @param waypoints array of MTDWaypoint objects
 @param edgePadding the padding used to outset/inset the computed rect to show all waypoints at once
 @param animated flag whether the region gets updated in an animated fashion or not
 */
- (void)mtd_setRegionFromWaypoints:(NSArray *)waypoints edgePadding:(UIEdgeInsets)edgePadding animated:(BOOL)animated;

/**
 Returns an instance of MTDDirectionsOverlayView used to display the given overlay
 
 @param overlay an instance of MTDDirectionsOverlay
 @return an instance of MTDDirectionsOverlayView if overlay is an instance of MTDDirectionsOverlay, nil otherwise
 */
- (MKOverlayView *)mtd_viewForDirectionsOverlay:(id<MKOverlay>)overlay;

/**
 Internal helper method that performs the work needed to load directions, depending on the set parameter.
 
 @param alternativeDirections this flag determines whether alternative directions are used or not
 */
- (void)mtd_loadAlternativeDirections:(BOOL)alternativeDirections
                                 from:(MTDWaypoint *)from
                                   to:(MTDWaypoint *)to
                            routeType:(MTDDirectionsRouteType)routeType
                 zoomToShowDirections:(BOOL)zoomToShowDirections
                    intermediateGoals:(NSArray *)intermediateGoals
                        optimizeRoute:(BOOL)optimizeRoute
          maximumNumberOfAlternatives:(NSUInteger)maximumNumberOfAlternatives;

// delegate encapsulation methods
- (void)mtd_notifyDelegateWillStartLoadingDirectionsFrom:(MTDWaypoint *)from to:(MTDWaypoint *)to routeType:(MTDDirectionsRouteType)routeType;
- (MTDDirectionsOverlay *)mtd_notifyDelegateDidFinishLoadingOverlay:(MTDDirectionsOverlay *)overlay;
- (void)mtd_notifyDelegateDidFailLoadingOverlayWithError:(NSError *)error;
- (UIColor *)mtd_askDelegateForColorOfOverlay:(MTDDirectionsOverlay *)overlay;
- (CGFloat)mtd_askDelegateForLineWidthFactorOfOverlay:(MTDDirectionsOverlay *)overlay;

@end


@implementation MTDMapView

@synthesize directionsDelegate = _directionsDelegate;
@synthesize directionsOverlay = _directionsOverlay;
@synthesize directionsOverlayView = _directionsOverlayView;
@synthesize directionsDisplayType = _directionsDisplayType;
@synthesize mtd_trueDelegate = _mtd_trueDelegate;
@synthesize mtd_request = _mtd_request;

////////////////////////////////////////////////////////////////////////
#pragma mark - Lifecycle
////////////////////////////////////////////////////////////////////////

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self mtd_setup];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder])) {
        [self mtd_setup];
    }
    
    return self;
}

- (void)dealloc {
    [self cancelLoadOfDirections];
}

////////////////////////////////////////////////////////////////////////
#pragma mark - UIView
////////////////////////////////////////////////////////////////////////

- (void)willMoveToSuperview:(UIView *)newSuperview {
    if (newSuperview == nil) {
        [self cancelLoadOfDirections];
    }
    
    [super willMoveToSuperview:newSuperview];
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
    if (newWindow == nil) {
        [self cancelLoadOfDirections];
    }
    
    [super willMoveToWindow:newWindow];
}

////////////////////////////////////////////////////////////////////////
#pragma mark - Directions
////////////////////////////////////////////////////////////////////////

- (void)loadDirectionsFrom:(CLLocationCoordinate2D)fromCoordinate
                        to:(CLLocationCoordinate2D)toCoordinate
                 routeType:(MTDDirectionsRouteType)routeType
      zoomToShowDirections:(BOOL)zoomToShowDirections {
    [self loadDirectionsFrom:[MTDWaypoint waypointWithCoordinate:fromCoordinate]
                          to:[MTDWaypoint waypointWithCoordinate:toCoordinate]
           intermediateGoals:nil
               optimizeRoute:NO
                   routeType:routeType
        zoomToShowDirections:zoomToShowDirections];
}

- (void)loadDirectionsFromAddress:(NSString *)fromAddress
                        toAddress:(NSString *)toAddress
                        routeType:(MTDDirectionsRouteType)routeType
             zoomToShowDirections:(BOOL)zoomToShowDirections {
    [self loadDirectionsFrom:[MTDWaypoint waypointWithAddress:[[MTDAddress alloc] initWithAddressString:fromAddress]]
                          to:[MTDWaypoint waypointWithAddress:[[MTDAddress alloc] initWithAddressString:toAddress]]
           intermediateGoals:nil
               optimizeRoute:NO
                   routeType:routeType
        zoomToShowDirections:zoomToShowDirections];
}

- (void)loadDirectionsFrom:(MTDWaypoint *)from
                        to:(MTDWaypoint *)to
         intermediateGoals:(NSArray *)intermediateGoals
             optimizeRoute:(BOOL)optimizeRoute
                 routeType:(MTDDirectionsRouteType)routeType
      zoomToShowDirections:(BOOL)zoomToShowDirections {
    
   [self mtd_loadAlternativeDirections:NO
                                  from:from
                                    to:to
                             routeType:routeType
                  zoomToShowDirections:zoomToShowDirections
                     intermediateGoals:intermediateGoals
                         optimizeRoute:optimizeRoute
           maximumNumberOfAlternatives:1];
}

- (void)loadAlternativeDirectionsFrom:(MTDWaypoint *)from
                                   to:(MTDWaypoint *)to
          maximumNumberOfAlternatives:(NSUInteger)maximumNumberOfAlternatives
                            routeType:(MTDDirectionsRouteType)routeType
                 zoomToShowDirections:(BOOL)zoomToShowDirections {
    
    [self mtd_loadAlternativeDirections:YES
                                   from:from
                                     to:to
                              routeType:routeType
                   zoomToShowDirections:zoomToShowDirections
                      intermediateGoals:nil
                          optimizeRoute:NO
            maximumNumberOfAlternatives:maximumNumberOfAlternatives];
}

- (void)cancelLoadOfDirections {
    [self.mtd_request cancel];
    self.mtd_request = nil;
}

- (void)removeDirectionsOverlay {
    [self removeOverlay:_directionsOverlay];
    
    _directionsOverlay = nil;
    _directionsOverlayView = nil;
}

////////////////////////////////////////////////////////////////////////
#pragma mark - Region
////////////////////////////////////////////////////////////////////////

- (void)setRegionToShowDirectionsAnimated:(BOOL)animated {
    [self mtd_setRegionFromWaypoints:self.directionsOverlay.waypoints edgePadding:UIEdgeInsetsZero animated:animated];
}

////////////////////////////////////////////////////////////////////////
#pragma mark - Properties
////////////////////////////////////////////////////////////////////////

- (void)setDirectionsOverlay:(MTDDirectionsOverlay *)directionsOverlay {
    if (directionsOverlay != _directionsOverlay) {    
        // remove old overlay and annotations
        if (_directionsOverlay != nil) {
            [self removeDirectionsOverlay];
        }
        
        _directionsOverlay = directionsOverlay;
        
        // add new overlay
        if (directionsOverlay != nil) {
            [self addOverlay:directionsOverlay];
        }
    }
}

- (void)setDirectionsDisplayType:(MTDDirectionsDisplayType)directionsDisplayType {
    if (directionsDisplayType != _directionsDisplayType) {
        _directionsDisplayType = directionsDisplayType;
        
        [self mtd_updateUIForDirectionsDisplayType:directionsDisplayType];
    }
}

- (void)setDirectionsDelegate:(id<MTDDirectionsDelegate>)directionsDelegate {
    if (directionsDelegate != _directionsDelegate) {
        _directionsDelegate = directionsDelegate;
        
        // update delegate flags
        _directionsDelegateFlags.willStartLoadingDirections = (unsigned int)[_directionsDelegate respondsToSelector:@selector(mapView:willStartLoadingDirectionsFrom:to:routeType:)];
        _directionsDelegateFlags.didFinishLoadingOverlay = (unsigned int)[_directionsDelegate respondsToSelector:@selector(mapView:didFinishLoadingDirectionsOverlay:)];
        _directionsDelegateFlags.didFailLoadingOverlay = (unsigned int)[_directionsDelegate respondsToSelector:@selector(mapView:didFailLoadingDirectionsOverlayWithError:)];
        _directionsDelegateFlags.colorForOverlay = (unsigned int)[_directionsDelegate respondsToSelector:@selector(mapView:colorForDirectionsOverlay:)];
        _directionsDelegateFlags.lineWidthFactorForOverlay = (unsigned int)[_directionsDelegate respondsToSelector:@selector(mapView:lineWidthFactorForDirectionsOverlay:)];
    }
}

- (void)setDelegate:(id<MKMapViewDelegate>)delegate {
    if (delegate != _mtd_trueDelegate) {
        _mtd_trueDelegate = delegate;
        
        // if we haven't set a directionsDelegate and our delegate conforms to the protocol
        // MTDDirectionsDelegate, then we automatically set our directionsDelegate
        if (self.directionsDelegate == nil && [delegate conformsToProtocol:@protocol(MTDDirectionsDelegate)]) {
            self.directionsDelegate = (id<MTDDirectionsDelegate>)delegate;
        }
    }
}

- (id<MKMapViewDelegate>)delegate {
    return _mtd_trueDelegate;
}

- (CLLocationCoordinate2D)fromCoordinate {
    if (self.directionsOverlay != nil) {
        return self.directionsOverlay.fromCoordinate;
    }
    
    return MTDInvalidCLLocationCoordinate2D;
}

- (CLLocationCoordinate2D)toCoordinate {
    if (self.directionsOverlay != nil) {
        return self.directionsOverlay.toCoordinate;
    }
    
    return MTDInvalidCLLocationCoordinate2D;
}

- (double)distanceInMeter {
    return [self.directionsOverlay.distance distanceInMeter];
}

- (NSTimeInterval)timeInSeconds {
    return self.directionsOverlay.timeInSeconds;
}

- (MTDDirectionsRouteType)routeType {
    return self.directionsOverlay.routeType;
}

////////////////////////////////////////////////////////////////////////
#pragma mark - Inter-App
////////////////////////////////////////////////////////////////////////

- (BOOL)openDirectionsInMapApp {
    if (self.directionsOverlay != nil) {
        return MTDDirectionsOpenInMapsApp(self.fromCoordinate, self.toCoordinate, self.directionsOverlay.routeType);
    }
    
    return NO;
}

////////////////////////////////////////////////////////////////////////
#pragma mark - MKMapViewDelegate Proxies
////////////////////////////////////////////////////////////////////////

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated {
    if ([self.mtd_trueDelegate respondsToSelector:@selector(mapView:regionWillChangeAnimated:)]) {
        [self.mtd_trueDelegate mapView:mapView regionWillChangeAnimated:animated];
    }
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    if ([self.mtd_trueDelegate respondsToSelector:@selector(mapView:regionDidChangeAnimated:)]) {
        [self.mtd_trueDelegate mapView:mapView regionDidChangeAnimated:animated];
    }
}

- (void)mapViewWillStartLoadingMap:(MKMapView *)mapView {
    if ([self.mtd_trueDelegate respondsToSelector:@selector(mapViewWillStartLoadingMap:)]) {
        [self.mtd_trueDelegate mapViewWillStartLoadingMap:mapView];
    }
}

- (void)mapViewDidFinishLoadingMap:(MKMapView *)mapView {
    if ([self.mtd_trueDelegate respondsToSelector:@selector(mapViewDidFinishLoadingMap:)]) {
        [self.mtd_trueDelegate mapViewDidFinishLoadingMap:mapView];
    }
}

- (void)mapViewDidFailLoadingMap:(MKMapView *)mapView withError:(NSError *)error {
    if ([self.mtd_trueDelegate respondsToSelector:@selector(mapViewDidFailLoadingMap:withError:)]) {
        [self.mtd_trueDelegate mapViewDidFailLoadingMap:mapView withError:error];
    }
}

- (void)mapViewWillStartLocatingUser:(MKMapView *)mapView {
    if ([self.mtd_trueDelegate respondsToSelector:@selector(mapViewWillStartLocatingUser:)]) {
        [self.mtd_trueDelegate mapViewWillStartLocatingUser:mapView];
    }
}

- (void)mapViewDidStopLocatingUser:(MKMapView *)mapView {
    if ([self.mtd_trueDelegate respondsToSelector:@selector(mapViewDidStopLocatingUser:)]) {
        [self.mtd_trueDelegate mapViewDidStopLocatingUser:mapView];
    }
}

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation {
    if ([self.mtd_trueDelegate respondsToSelector:@selector(mapView:didUpdateUserLocation:)]) {
        [self.mtd_trueDelegate mapView:mapView didUpdateUserLocation:userLocation];
    }
}

- (void)mapView:(MKMapView *)mapView didFailToLocateUserWithError:(NSError *)error {
    if ([self.mtd_trueDelegate respondsToSelector:@selector(mapView:didFailToLocateUserWithError:)]) {
        [self.mtd_trueDelegate mapView:mapView didFailToLocateUserWithError:error];
    }
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation {
    if ([self.mtd_trueDelegate respondsToSelector:@selector(mapView:viewForAnnotation:)]) {
        return [self.mtd_trueDelegate mapView:mapView viewForAnnotation:annotation];
    }
    
    return nil;
}

- (void)mapView:(MKMapView *)mapView didAddAnnotationViews:(NSArray *)views {
    if ([self.mtd_trueDelegate respondsToSelector:@selector(mapView:didAddAnnotationViews:)]) {
        [self.mtd_trueDelegate mapView:mapView didAddAnnotationViews:views];
    }
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control {
    if ([self.mtd_trueDelegate respondsToSelector:@selector(mapView:annotationView:calloutAccessoryControlTapped:)]) {
        [self.mtd_trueDelegate mapView:mapView annotationView:view calloutAccessoryControlTapped:control];
    }
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)annotationView didChangeDragState:(MKAnnotationViewDragState)newState fromOldState:(MKAnnotationViewDragState)oldState {
    if ([self.mtd_trueDelegate respondsToSelector:@selector(mapView:annotationView:didChangeDragState:fromOldState:)]) {
        [self.mtd_trueDelegate mapView:mapView annotationView:annotationView didChangeDragState:newState fromOldState:oldState];
    }
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
    if ([self.mtd_trueDelegate respondsToSelector:@selector(mapView:didSelectAnnotationView:)]) {
        [self.mtd_trueDelegate mapView:mapView didSelectAnnotationView:view];
    }
}

- (void)mapView:(MKMapView *)mapView didDeselectAnnotationView:(MKAnnotationView *)view {
    if ([self.mtd_trueDelegate respondsToSelector:@selector(mapView:didDeselectAnnotationView:)]) {
        [self.mtd_trueDelegate mapView:mapView didDeselectAnnotationView:view];
    }
}

- (MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id<MKOverlay>)overlay {
    // first check if the delegate provides a custom annotation
    if ([self.mtd_trueDelegate respondsToSelector:@selector(mapView:viewForOverlay:)]) {
        MKOverlayView *delegateResult = [self.mtd_trueDelegate mapView:mapView viewForOverlay:overlay];
        
        if (delegateResult != nil) {
            return delegateResult;
        }
    } 
    
    // otherwise provide a default overlay for directions
    if ([overlay isKindOfClass:[MTDDirectionsOverlay class]]) {
        return [self mtd_viewForDirectionsOverlay:overlay];
    }
    
    return nil;
}

- (void)mapView:(MKMapView *)mapView didAddOverlayViews:(NSArray *)overlayViews {
    if ([self.mtd_trueDelegate respondsToSelector:@selector(mapView:didAddOverlayViews:)]) {
        [self.mtd_trueDelegate mapView:mapView didAddOverlayViews:overlayViews];
    }
}

////////////////////////////////////////////////////////////////////////
#pragma mark - Private
////////////////////////////////////////////////////////////////////////

- (void)mtd_setup {
    // we set ourself as the delegate
    [super setDelegate:self];
    
    _directionsDisplayType = MTDDirectionsDisplayTypeNone;
}

- (void)mtd_setRegionFromWaypoints:(NSArray *)waypoints edgePadding:(UIEdgeInsets)edgePadding animated:(BOOL)animated {
    if (waypoints != nil) {
        CLLocationDegrees maxX = -DBL_MAX;
        CLLocationDegrees maxY = -DBL_MAX;
        CLLocationDegrees minX = DBL_MAX;
        CLLocationDegrees minY = DBL_MAX;
        
        for (NSUInteger i=0; i<waypoints.count; i++) {
            MTDWaypoint *currentLocation = [waypoints objectAtIndex:i];
            MKMapPoint mapPoint = MKMapPointForCoordinate(currentLocation.coordinate);
            
            if (mapPoint.x > maxX) {
                maxX = mapPoint.x;
            }
            if (mapPoint.x < minX) {
                minX = mapPoint.x;
            }
            if (mapPoint.y > maxY) {
                maxY = mapPoint.y;
            }
            if (mapPoint.y < minY) {
                minY = mapPoint.y;
            }
        }
        
        MKMapRect mapRect = MKMapRectMake(minX,minY,maxX-minX,maxY-minY);
        [self setVisibleMapRect:mapRect edgePadding:edgePadding animated:animated];
    }
}

- (void)mtd_updateUIForDirectionsDisplayType:(MTDDirectionsDisplayType) __unused displayType {    
    if (_directionsOverlay != nil) {
        [self removeOverlay:_directionsOverlay];
        _directionsOverlayView = nil;
        
        [self addOverlay:_directionsOverlay];
    }
}

- (MKOverlayView *)mtd_viewForDirectionsOverlay:(id<MKOverlay>)overlay {
    // don't display anything if display type is set to none
    if (self.directionsDisplayType == MTDDirectionsDisplayTypeNone) {
        return nil;
    }
    
    if (![overlay isKindOfClass:[MTDDirectionsOverlay class]] || self.directionsOverlay == nil) {
        return nil;
    }
    
    self.directionsOverlayView = [[MTDDirectionsOverlayView alloc] initWithOverlay:self.directionsOverlay];    
    self.directionsOverlayView.overlayColor = [self mtd_askDelegateForColorOfOverlay:self.directionsOverlay];
    self.directionsOverlayView.overlayLineWidthFactor = [self mtd_askDelegateForLineWidthFactorOfOverlay:self.directionsOverlay];
    
    return self.directionsOverlayView;
}

- (void)mtd_loadAlternativeDirections:(BOOL)alternativeDirections
                                 from:(MTDWaypoint *)from
                                   to:(MTDWaypoint *)to
                            routeType:(MTDDirectionsRouteType)routeType
                 zoomToShowDirections:(BOOL)zoomToShowDirections
                    intermediateGoals:(NSArray *)intermediateGoals
                        optimizeRoute:(BOOL)optimizeRoute
          maximumNumberOfAlternatives:(NSUInteger)maximumNumberOfAlternatives {

    if (alternativeDirections) {
        MTDAssert(intermediateGoals.count == 0, @"Intermediate goals mustn't be specified when requesting alternative routes.");
    } else {
        MTDAssert(maximumNumberOfAlternatives == 1, @"There can only be one route requested, when we don't search for alterantives.");
    }

    __mtd_weak MTDMapView *weakSelf = self;
    
    [self.mtd_request cancel];
    
    if (from.valid && to.valid) {
        mtd_parser_block parserCompletion = ^(MTDDirectionsOverlay *overlay, NSError *error) {
            __strong MTDMapView *strongSelf = weakSelf;
            
            if (overlay != nil) {
                overlay = [self mtd_notifyDelegateDidFinishLoadingOverlay:overlay];
                
                strongSelf.directionsDisplayType = MTDDirectionsDisplayTypeOverview;
                strongSelf.directionsOverlay = overlay;
                
                if (zoomToShowDirections) {
                    [strongSelf setRegionToShowDirectionsAnimated:YES];
                } 
            } else {
                [self mtd_notifyDelegateDidFailLoadingOverlayWithError:error];
            }
        };

        self.mtd_request = [MTDDirectionsRequest requestFrom:from
                                                      to:to
                                       intermediateGoals:intermediateGoals
                                           optimizeRoute:optimizeRoute
                                               routeType:routeType
                                              completion:parserCompletion];

        if (alternativeDirections) {
            // TODO: Implement some fancy stuff here to make this work
        }
        
        [self mtd_notifyDelegateWillStartLoadingDirectionsFrom:from to:to routeType:routeType];
        [self.mtd_request start];
    }
}

////////////////////////////////////////////////////////////////////////
#pragma mark - Private Delegate Helper
////////////////////////////////////////////////////////////////////////

- (void)mtd_notifyDelegateWillStartLoadingDirectionsFrom:(MTDWaypoint *)from 
                                                  to:(MTDWaypoint *)to
                                           routeType:(MTDDirectionsRouteType)routeType {
    if (_directionsDelegateFlags.willStartLoadingDirections) {
        [self.directionsDelegate mapView:self willStartLoadingDirectionsFrom:from to:to routeType:routeType];
    }
    
    // post corresponding notification
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              from, MTDDirectionsNotificationKeyFrom,
                              to, MTDDirectionsNotificationKeyTo,
                              [NSNumber numberWithInt:routeType], MTDDirectionsNotificationKeyRouteType,
                              nil];
    NSNotification *notification = [NSNotification notificationWithName:MTDMapViewWillStartLoadingDirections
                                                                 object:self
                                                               userInfo:userInfo];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
}

- (MTDDirectionsOverlay *)mtd_notifyDelegateDidFinishLoadingOverlay:(MTDDirectionsOverlay *)overlay {
    MTDDirectionsOverlay *overlayToReturn = overlay;
    
    if (_directionsDelegateFlags.didFinishLoadingOverlay) {
        overlayToReturn = [self.directionsDelegate mapView:self didFinishLoadingDirectionsOverlay:overlay];
    }
    
    // post corresponding notification
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              overlay, MTDDirectionsNotificationKeyOverlay,
                              nil];
    NSNotification *notification = [NSNotification notificationWithName:MTDMapViewDidFinishLoadingDirectionsOverlay
                                                                 object:self
                                                               userInfo:userInfo];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
    
    // sanity check if delegate returned a valid overlay
    if ([overlayToReturn isKindOfClass:[MTDDirectionsOverlay class]]) {
        return overlayToReturn;
    } else {
        return overlay;
    }
}

- (void)mtd_notifyDelegateDidFailLoadingOverlayWithError:(NSError *)error {
    if (_directionsDelegateFlags.didFailLoadingOverlay) {
        [self.directionsDelegate mapView:self didFailLoadingDirectionsOverlayWithError:error];
    }
    
    // post corresponding notification
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              error, MTDDirectionsNotificationKeyError,
                              nil];
    NSNotification *notification = [NSNotification notificationWithName:MTDMapViewDidFailLoadingDirectionsOverlay
                                                                 object:self
                                                               userInfo:userInfo];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
}

- (UIColor *)mtd_askDelegateForColorOfOverlay:(MTDDirectionsOverlay *)overlay {
    if (_directionsDelegateFlags.colorForOverlay) {
        UIColor *color = [self.directionsDelegate mapView:self colorForDirectionsOverlay:overlay];
        
        // sanity check if delegate returned valid color
        if ([color isKindOfClass:[UIColor class]]) {
            return color;
        }
    }
    
    // nil doesn't get set as overlay color
    return nil;
}

- (CGFloat)mtd_askDelegateForLineWidthFactorOfOverlay:(MTDDirectionsOverlay *)overlay {
    if (_directionsDelegateFlags.lineWidthFactorForOverlay) {
        CGFloat lineWidthFactor = [self.directionsDelegate mapView:self lineWidthFactorForDirectionsOverlay:overlay];
        return lineWidthFactor;
    }
    
    // doesn't get set as line width
    return -1.f;
}

@end
