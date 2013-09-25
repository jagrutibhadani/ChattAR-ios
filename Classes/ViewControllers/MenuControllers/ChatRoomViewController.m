//
//  ChatRoomViewController.m
//  ChattAR
//
//  Created by Igor Alefirenko on 11/09/2013.
//  Copyright (c) 2013 Stefano Antonelli. All rights reserved.
//
#import "ChatViewController.h"
#import "ChatRoomViewController.h"
#import "ChatRoomCell.h"
#import "QuotedChatRoomCell.h"
#import "DataManager.h"
#import "FBService.h"
#import <CoreLocation/CoreLocation.h>


@interface ChatRoomViewController ()
@property (strong, nonatomic) CLLocationManager *currentLocation;
@property (assign, nonatomic) CLLocationCoordinate2D myCoordinates;
@property (strong, nonatomic) IBOutlet UIButton *backButton;
@property (strong, nonatomic) NSMutableDictionary *quote;
@property (strong, nonatomic) QBChatRoom *currentRoom;
@property (strong, nonatomic) QBChatMessage *userMessage;
@property (strong, nonatomic) IBOutlet UIView *inputTextView;
@property (strong, nonatomic) IBOutlet UITextField *inputMessageField;
@property (strong, nonatomic) NSMutableArray *chatHistory;
@property (strong, nonatomic) NSIndexPath *cellPath;
@property CGFloat cellSize;


-(IBAction)textEditDone:(id)sender;
- (IBAction)backToRooms:(id)sender;
- (IBAction)sendMessageButton:(id)sender;

//parsing...
- (NSString *)gettingLocationFromString:(NSString *)string;
- (CLLocationCoordinate2D)stringToCoordinates:(NSString *)subString;

@end

@implementation ChatRoomViewController
@synthesize cellPath;
@synthesize quote;

#pragma mark LifeCycle

- (void)viewDidLoad
{
    
    [super viewDidLoad];
    self.title = @"Default";
    self.chatHistory = [[NSMutableArray alloc] init];
    self.inputTextView.layer.shadowColor = [[UIColor blackColor] CGColor];
    self.inputTextView.layer.shadowRadius = 7.0f;
    self.inputTextView.layer.masksToBounds = NO;
    self.inputTextView.layer.shadowOffset = CGSizeMake(0.0f, 4.0f);
    self.inputTextView.layer.shadowOpacity = 1.0f;
    self.inputTextView.layer.borderWidth = 0.1f;

    self.cashedUser = [[CachedUser alloc] init];
    // getting my location...
    self.currentLocation = [[CLLocationManager alloc] init];
    self.currentLocation.delegate = self;
    [self.currentLocation setDistanceFilter:1];
    [self.currentLocation setDesiredAccuracy:kCLLocationAccuracyBest];
    [self.currentLocation startUpdatingLocation];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidUnload {
    [self setChatRoomTable:nil];
    [self setBackButton:nil];
    [self setInputTextView:nil];
    [self setInputMessageField:nil];
    [super viewDidUnload];
}

-(void)viewWillAppear:(BOOL)animated{
    self.title = [FBService shared].roomName;
    [self creatingOrJoiningRoom];
    [_chatRoomTable reloadData];
    [super viewWillAppear:animated];
}

#pragma mark -
#pragma mark Table View Data Source

static CGFloat padding = 20.0;

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return [_chatHistory count];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell;
    
    QBChatMessage *qbMessage = [_chatHistory objectAtIndex:[indexPath row]];
    NSString *string = [NSString stringWithFormat:@"%@", qbMessage.text];
    // JSON parsing
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    
    if ([jsonDict objectForKey:@"quote"] == nil) {
       cell = [self configureSimpleCellForTableView:tableView andIndexPath:indexPath];
    } else {
        cell = [self configureQuotedCellForTableView:tableView andIndexPath:indexPath];
    }
    return cell;
}

// There are Two different cells: "Simple" and "Quoted"

- (ChatRoomCell *)configureSimpleCellForTableView:(UITableView *)tableView andIndexPath:(NSIndexPath *)indexPath {
    static NSString *roomCellIdentifier = @"RoomCellIdentifier";
    ChatRoomCell *roomCell = [tableView dequeueReusableCellWithIdentifier:roomCellIdentifier];
    if (roomCell == nil)
    {
        roomCell = [[ChatRoomCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:roomCellIdentifier];
        
        [roomCell.contentView addSubview:roomCell.userPhoto];
        [roomCell.contentView addSubview:roomCell.colorBuble];
        [roomCell.contentView addSubview:roomCell.message];
        [roomCell.contentView addSubview:roomCell.userName];
        [roomCell.contentView addSubview:roomCell.postMessageDate];
        [roomCell.contentView addSubview:roomCell.distance];
    }
    
    // Buble
    if ([indexPath row] % 2 == 0) {
        roomCell.bubleImage = [UIImage imageNamed:@"01_green_chat_bubble.png"];
    } else {
        roomCell.bubleImage = [UIImage imageNamed:@"01_blue_chat_bubble.png"];
    }
    UIImage *img = [roomCell.bubleImage resizableImageWithCapInsets:UIEdgeInsetsMake(10, 10, 10, 10) resizingMode:UIImageResizingModeStretch];
    
    // user message
    QBChatMessage *currentMessage = [self.chatHistory objectAtIndex:[indexPath row]];
    // getting dictionary from JSON
    NSData *dictData = [currentMessage.text dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary *tempDict = [NSJSONSerialization JSONObjectWithData:dictData options:NSJSONReadingAllowFragments error:nil];
    
    //getting Avatar from url
    NSString *urlString = [tempDict objectForKey:kUserPhotoUrl];
    NSURL *url = [NSURL URLWithString:urlString];

    //getting location of a message sender
    CGFloat latitude = [[tempDict objectForKey:kLatitude] floatValue];
    CGFloat longitude = [[tempDict objectForKey:kLongitude] floatValue];
    CLLocation *userLocation = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
    CLLocationDistance distanceToMe = [self.currentLocation.location distanceFromLocation:userLocation];

    // post message date
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"HH:mm"];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"..."]];
    NSString *time = [dateFormatter stringFromDate:currentMessage.datetime];
    
    // putting data to fields
    [roomCell.userPhoto loadImageFromURL:url];
    roomCell.colorBuble.image = img;
    roomCell.distance.text = [self distanceFormatter:distanceToMe];
    roomCell.message.text = [tempDict objectForKey:kMessage];
    roomCell.userName.text = [tempDict objectForKey:kUserName];
    roomCell.postMessageDate.text = time;
    
    
    //changing hight
    CGSize textSize = { 225.0, 10000.0 };
    CGSize size = [[roomCell.message text] sizeWithFont:[UIFont systemFontOfSize:17.0f] constrainedToSize:textSize lineBreakMode:NSLineBreakByWordWrapping];
    
    [roomCell.message setFrame:CGRectMake(75, 43, 225, size.height)];
    [roomCell.colorBuble setFrame:CGRectMake(55, 10, 255, size.height+padding*2)];
    
    return roomCell;

}

- (UITableViewCell *)configureQuotedCellForTableView:(UITableView *)tableView andIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *cellIdentifier = @"CellIdentifier";
    QuotedChatRoomCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[QuotedChatRoomCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        // putting all subviews
        [cell.contentView addSubview:cell.qUserPhoto];
        [cell.contentView addSubview:cell.replyImg];
        [cell.contentView addSubview:cell.qColorBuble];
        [cell.contentView addSubview:cell.qUserName];
        [cell.contentView addSubview:cell.qMessage];
        [cell.contentView addSubview:cell.qDateTime];
        
        [cell.contentView addSubview:cell.rUserPhoto];
        [cell.contentView addSubview:cell.rDistance];
        [cell.contentView addSubview:cell.rColorBuble];
        [cell.contentView addSubview:cell.rUserName];
        [cell.contentView addSubview:cell.rMessage];
        [cell.contentView addSubview:cell.rDateTime];
    }
    
    QBChatMessage *currentMessage = [_chatHistory objectAtIndex:[indexPath row]];
    NSData *data = [currentMessage.text dataUsingEncoding:NSUTF8StringEncoding];
    // parsing JSON to dictionary
    NSDictionary *quoteDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    // getting quote from message
    NSDictionary *quoted = [quoteDict objectForKey:kQuote];
    
    //QUOTE:
    //getting Avatar from url
    NSString *urlString = [quoted objectForKey:kUserPhotoUrl];
    NSURL *url = [NSURL URLWithString:urlString];
    [cell.qUserPhoto loadImageFromURL:url];
    // getting data from dictionary
    cell.qUserName.text = [quoted objectForKey:kUserName];
    cell.qMessage.text = [quoted objectForKey:kMessage];
    cell.qDateTime.text = [quoted objectForKey:kDateTime];
    
    
    // REPLY
    //buble( Offset: y:50)
    if ([indexPath row] % 2 == 0) {
        cell.rColorBuble.image = [[UIImage imageNamed:@"01_green_chat_bubble.png"]resizableImageWithCapInsets:UIEdgeInsetsMake(10, 10, 10, 10) resizingMode:UIImageResizingModeStretch];
    } else {
        cell.rColorBuble.image = [[UIImage imageNamed:@"01_blue_chat_bubble.png"]resizableImageWithCapInsets:UIEdgeInsetsMake(10, 10, 10, 10) resizingMode:UIImageResizingModeStretch];
    }
    // getting avatar url
    NSString *uStr = [quoteDict objectForKey:kUserPhotoUrl];
    NSURL *urlImg = [NSURL URLWithString:uStr];
    
    // date formatter
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"HH:mm"];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"..."]];
    NSString *time = [dateFormatter stringFromDate:currentMessage.datetime];
    
    // getting location
    CGFloat latutude = [[quoteDict objectForKey:kLatitude] floatValue];
    CGFloat longitude = [[quoteDict objectForKey:kLongitude] floatValue];
    CLLocation *userLocation = [[CLLocation alloc] initWithLatitude:latutude longitude:longitude];
    CLLocationDistance distanceToMe = [self.currentLocation.location distanceFromLocation:userLocation];
    NSString *distance = [self distanceFormatter:distanceToMe];
    
    //changing hight
    CGSize textSize = { 225.0, 10000.0 };
    CGSize size = [[quoteDict objectForKey:kMessage] sizeWithFont:[UIFont systemFontOfSize:17.0f] constrainedToSize:textSize lineBreakMode:NSLineBreakByWordWrapping];
    
    [cell.rMessage setFrame:CGRectMake(75, 43+50, 225, size.height)];
    [cell.rColorBuble setFrame:CGRectMake(55, 10+50, 255, size.height+padding*2)];
    
    [cell.rUserPhoto loadImageFromURL:urlImg];
    cell.rUserName.text = [quoteDict objectForKey:kUserName];
    cell.rMessage.text = [quoteDict objectForKey:kMessage];
    cell.rDateTime.text = time;
    cell.rDistance.text = distance;
    
    return cell;
    
}



-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    CGFloat cellHeight;
    QBChatMessage *chatMessage = [_chatHistory objectAtIndex:indexPath.row];
    NSString *chatString = chatMessage.text;
    NSData *data = [chatString dataUsingEncoding:NSUTF8StringEncoding];
    // all message (with quote)
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    if ([dictionary objectForKey:kQuote] == nil) {
        CGSize textSize = { 225.0, 10000.0 };
        NSString *currentMessage = [dictionary objectForKey:kMessage];
        //changing hight
        CGSize size = [currentMessage sizeWithFont:[UIFont systemFontOfSize:17.0f] constrainedToSize:textSize lineBreakMode:NSLineBreakByWordWrapping];
        size.height += padding*2;
        cellHeight = size.height+10.0f;
    } else {
        CGSize textSize = { 225.0, 10000.0 };
        NSString *currentMessage = [dictionary objectForKey:kMessage];
        //changing hight
        CGSize size = [currentMessage sizeWithFont:[UIFont systemFontOfSize:17.0f] constrainedToSize:textSize lineBreakMode:NSLineBreakByWordWrapping];
        size.height += padding*2;
        cellHeight = size.height + 10.0f + 50.0f;
    }
    
    return cellHeight;
}


#pragma mark -
#pragma mark CoreLocationDelegate

- (void) locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error{
    NSLog(@"Error: %@", error);
}

-(void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations{
    CLLocation *lastLocation = [locations lastObject];
    self.myCoordinates = lastLocation.coordinate;
}


#pragma mark -
#pragma mark Table View Delegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [self.chatRoomTable deselectRowAtIndexPath:indexPath animated:YES];
    QBChatMessage *chatMsg = [_chatHistory objectAtIndex:[indexPath row]];
    if (![chatMsg.senderNick isEqual:[[DataManager shared].currentFBUser objectForKey:kId]]) {
        cellPath = indexPath;
        NSString *title = [[NSString alloc] initWithFormat:@"What do you want?"];
        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:title delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Reply", nil];
    [actionSheet showInView:self.view];
    }
}

#pragma mark -
#pragma mark UIActionSheetDelegate

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
    NSLog(@"Button whith number %i was clicked", buttonIndex);
    switch (buttonIndex) {
        case 0:
            // do something
            NSLog(@"REPLY");
            QBChatMessage *msg = [_chatHistory objectAtIndex:[cellPath row]];
            
            
            NSString *string = msg.text;
            cellPath = nil;
            // JSON parsing
            NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
            
            //saving user...
            if (quote == nil) {
                quote = [[NSMutableDictionary alloc] init];
            }
            
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"HH:mm"];
            [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"..."]];
            NSString *time = [dateFormatter stringFromDate:msg.datetime];
            
            [quote setValue:[jsonDict objectForKey:kUserPhotoUrl] forKey:kUserPhotoUrl];
            [quote setValue:[jsonDict objectForKey:kUserName] forKey:kUserName];
            [quote setValue:[jsonDict objectForKey:kMessage] forKey:kMessage];
            [quote setValue:time forKey:kDateTime];
            
            [self.inputMessageField becomeFirstResponder];
            break;
    }
}

#pragma mark -
#pragma mark ChatRoom

-(void)creatingOrJoiningRoom{
    if ([QBChat instance].delegate == self) {
        //nothing
    } else {
    [QBChat instance].delegate = self;
    }
    [[QBChat instance] createOrJoinRoomWithName:[FBService shared].roomName nickname:[[DataManager shared].currentFBUser objectForKey:kId] membersOnly:NO persistent:NO];
    [_chatRoomTable reloadData];
}


#pragma mark -
#pragma mark QBActionStatusDelegate

-(void)completedWithResult:(Result *)result{
    if (result.success) {
        if ([result isKindOfClass:[QBUUserResult class]]) {
            QBUUserResult *activeResult = (QBUUserResult *)result;
            QBUUser *user = activeResult.user;
            [DataManager shared].currentQBUser = user;
            [[DataManager shared].fbUsersLoggedIn setObject:user forKey:[NSString stringWithFormat:@"%i", user.ID]];
        }
    }
}

#pragma mark -
#pragma mark QBChatDelegate

// if chat room is created or user is joined
-(void)chatRoomDidEnter:(QBChatRoom *)room{
    NSLog(@"Chat Room is opened");
    //get room
    self.currentRoom = room;
}

- (void)chatRoomDidNotEnter:(NSString *)roomName error:(NSError *)error{
    NSLog(@"Error:%@", error);
}
// back button
- (IBAction)backToRooms:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

// action message button
- (IBAction)sendMessageButton:(id)sender {
    if ([self.inputMessageField.text isEqual:@""]) {
        //don't send
    } else {
        NSString *myLatitude = [[NSString alloc] initWithFormat:@"%f",self.myCoordinates.latitude];
        NSString *myLongitude = [[NSString alloc] initWithFormat:@"%f", self.myCoordinates.longitude];
        NSString *userName =  [NSString stringWithFormat:@"%@ %@",[[DataManager shared].currentFBUser objectForKey:kFirstName], [[DataManager shared].currentFBUser objectForKey:kLastName]];
        
        NSString *urlString = [[NSString alloc] initWithFormat:@"https://graph.facebook.com/%@/picture?access_token=%@", [[DataManager shared].currentFBUser objectForKey:kId], [DataManager shared].accessToken];
        
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setValue:myLatitude forKey:kLatitude];
        [dict setValue:myLongitude forKey:kLongitude];
        [dict setValue:urlString forKey:kUserPhotoUrl];
        [dict setValue:userName forKey:kUserName];
        if (quote != nil) {
            [dict setValue:quote forKey:kQuote];
            quote = nil;
        }
        [dict setValue:self.inputMessageField.text forKey:kMessage];
        // formatting to JSON:
        NSError *error = nil;
        NSData* nsdata = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
        
        NSString* jsonString =[[NSString alloc] initWithData:nsdata encoding:NSUTF8StringEncoding];
        
        [[QBChat instance] sendMessage:jsonString toRoom:self.currentRoom];
        self.inputMessageField.text = @"";
    }
    [self.chatRoomTable reloadData];
    [self.inputMessageField resignFirstResponder];
}

//  receiving messages
-(void)chatRoomDidReceiveMessage:(QBChatMessage *)message fromRoom:(NSString *)roomName{
    QBDLogEx(@"message %@", message);
    
    self.userMessage = message;
    [self.chatHistory addObject:message];
    [self.chatRoomTable reloadData];
    [self.chatRoomTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:[_chatHistory count]-1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    
}
#pragma mark -
#pragma mark Show/Hide Keyboard

-(void)showKeyboard{
    CGRect tableViewFrame = self.chatRoomTable.frame;
    CGRect inputPanelFrame = _inputTextView.frame;
    tableViewFrame.origin.y -= 215;
    inputPanelFrame.origin.y -= 215;
    //animation
    [UIView animateWithDuration:0.25f animations:^{
        [self.chatRoomTable setFrame:tableViewFrame];
        [_inputTextView setFrame:inputPanelFrame];
    }];
}

-(void)hideKeyboard{
    CGRect tableViewFrame = self.chatRoomTable.frame;
    CGRect inputPanelFrame = _inputTextView.frame;
    tableViewFrame.origin.y += 215;
    inputPanelFrame.origin.y += 215;
    //animation
    [UIView animateWithDuration:0.25f animations:^{
        [self.chatRoomTable setFrame:tableViewFrame];
        [_inputTextView setFrame:inputPanelFrame];
    }];    
}

#pragma mark -
#pragma mark UITextField

-(IBAction)textEditDone:(id)sender{
    [sender resignFirstResponder];
}

-(void)textFieldDidBeginEditing:(UITextField *)textField{
    [self showKeyboard];
}

-(void)textFieldDidEndEditing:(UITextField *)textField{
    [self hideKeyboard];
}


#pragma mark -
#pragma mark Converter


-(NSString *)distanceFormatter:(CLLocationDistance)distance{
    NSString *formatedDistance;
    NSInteger dist = round(distance);
    if (distance <=999) {
        formatedDistance = [NSString stringWithFormat:@"%d m", dist];
    } else{
        dist = round(dist) / 1000;
        formatedDistance = [NSString stringWithFormat:@"%d km",dist];
    }
    return formatedDistance;
}



@end
