//
//  SDCAlertView.m
//  SDCAlertView
//
//  Created by Scott Berrevoets on 9/20/13.
//  Copyright (c) 2013 Scotty Doesn't Code. All rights reserved.
//

#import "SDCAlertView.h"

#import "SDCAlertViewController.h"
#import "SDCAlertViewCoordinator.h"
#import "SDCAlertViewBackgroundView.h"
#import "SDCAlertViewContentView.h"

#import "UIView+SDCAutoLayout.h"

CGFloat const SDCAlertViewWidth = 270;
static UIEdgeInsets const SDCAlertViewPadding = {3, 0, 3, 0};
static CGFloat const SDCAlertViewCornerRadius = 7;

static UIOffset const SDCAlertViewParallaxSlideMagnitude = {15.75, 15.75};

#pragma mark - SDCAlertView

@interface SDCAlertView () <SDCAlertViewContentViewDelegate>
@property (nonatomic, strong) id <SDCAlertViewTransitioning> transitionCoordinator;
@property (nonatomic, strong) SDCAlertViewBackgroundView *alertBackgroundView;
@property (nonatomic, strong) SDCAlertViewContentView *alertContentView;
@end

@implementation SDCAlertView

#pragma mark - UIAppearance

+ (void)initialize {
	[super initialize];
	
	SDCAlertView *appearance = [self appearance];
	
	[appearance setTitleLabelFont:[UIFont boldSystemFontOfSize:17]];
	[appearance setMessageLabelFont:[UIFont systemFontOfSize:14]];
	[appearance setTextFieldFont:[UIFont systemFontOfSize:13]];
	[appearance setSuggestedButtonFont:[UIFont boldSystemFontOfSize:17]];
	[appearance setNormalButtonFont:[UIFont systemFontOfSize:17]];
	[appearance setButtonTextColor:[UIColor colorWithRed:0/255.0 green:122/255.0 blue:255/255.0 alpha:1]];
	[appearance setTextFieldTextColor:[UIColor darkTextColor]];
	[appearance setTitleLabelTextColor:[UIColor darkTextColor]];
	[appearance setMessageLabelTextColor:[UIColor darkTextColor]];
}

#pragma mark - Getters

- (SDCAlertViewBackgroundView *)alertBackgroundView {
	if (!_alertBackgroundView) {
		_alertBackgroundView = [[SDCAlertViewBackgroundView alloc] init];
		[_alertBackgroundView setTranslatesAutoresizingMaskIntoConstraints:NO];
	}
	
	return _alertBackgroundView;
}

- (SDCAlertViewContentView *)alertContentView {
	if (!_alertContentView) {
		_alertContentView = [[SDCAlertViewContentView alloc] initWithDelegate:self];
		[_alertContentView setTranslatesAutoresizingMaskIntoConstraints:NO];
	}
	
	return _alertContentView;
}

- (id <SDCAlertViewTransitioning>)transitionCoordinator {
	if (!_transitionCoordinator)
		return [SDCAlertViewCoordinator sharedCoordinator];
	else
		return _transitionCoordinator;
}

#pragma mark - Initialization

- (instancetype)initWithTitle:(NSString *)title
					  message:(NSString *)message
					 delegate:(id)delegate
			cancelButtonTitle:(NSString *)cancelButtonTitle
			otherButtonTitles:(NSString *)otherButtonTitles, ... {
	self = [super init];
	
	if (self) {
		_delegate = delegate;
		
		[self createContentViewWithTitle:title message:message];
		self.alertContentView.cancelButtonTitle = cancelButtonTitle;
		
		va_list argumentList;
		va_start(argumentList, otherButtonTitles);
		for (NSString *buttonTitle = otherButtonTitles; buttonTitle != nil; buttonTitle = va_arg(argumentList, NSString *))
			[self.alertContentView addButtonWithTitle:buttonTitle];
		
		[self addParallaxEffect];
		
		[self setTranslatesAutoresizingMaskIntoConstraints:NO];
		
		self.layer.masksToBounds = YES;
		self.layer.cornerRadius = SDCAlertViewCornerRadius;
	}
	
	return self;
}

- (void)addParallaxEffect {
	UIInterpolatingMotionEffect *horizontalParallax;
	UIInterpolatingMotionEffect *verticalParallax;
	
	horizontalParallax = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.x" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
	horizontalParallax.minimumRelativeValue = @(-SDCAlertViewParallaxSlideMagnitude.horizontal);
	horizontalParallax.maximumRelativeValue = @(SDCAlertViewParallaxSlideMagnitude.horizontal);
	
	verticalParallax = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
	verticalParallax.minimumRelativeValue = @(-SDCAlertViewParallaxSlideMagnitude.vertical);
	verticalParallax.maximumRelativeValue = @(SDCAlertViewParallaxSlideMagnitude.vertical);
	
	UIMotionEffectGroup *groupMotionEffect = [[UIMotionEffectGroup alloc] init];
	groupMotionEffect.motionEffects = @[horizontalParallax, verticalParallax];
	[self addMotionEffect:groupMotionEffect];
}

#pragma mark - Visibility

- (BOOL)isVisible {
	return self.transitionCoordinator.visibleAlert == self;
}

#pragma mark - Presenting

- (void)show {
	[self updateFirstButtonEnabledStatus];
	[self monitorChangesForTextFields:self.alertContentView.textFields];
	
	[self.alertContentView prepareForShowing];
	
	[self addSubview:self.alertBackgroundView];
	[self addSubview:self.alertContentView];
	
	[self.transitionCoordinator presentAlert:self];
}

- (void)willBePresented {
	if ([self.delegate respondsToSelector:@selector(willPresentAlertView:)])
		[self.delegate willPresentAlertView:self];
}

- (void)wasPresented {
	if ([self.delegate respondsToSelector:@selector(didPresentAlertView:)])
		[self.delegate didPresentAlertView:self];
}

#pragma mark - Dismissing

- (void)dismissWithClickedButtonIndex:(NSInteger)buttonIndex animated:(BOOL)animated {
	[self.transitionCoordinator dismissAlert:self withButtonIndex:buttonIndex animated:animated];
}

- (void)willBeDismissedWithButtonIndex:(NSInteger)buttonIndex {
	if ([self.delegate respondsToSelector:@selector(alertView:willDismissWithButtonIndex:)])
		[self.delegate alertView:self willDismissWithButtonIndex:buttonIndex];
    
    if (self.willDismissHandler)
        self.willDismissHandler(buttonIndex);
}

- (void)wasDismissedWithButtonIndex:(NSInteger)buttonIndex {
	if ([self.delegate respondsToSelector:@selector(alertView:didDismissWithButtonIndex:)])
		[self.delegate alertView:self didDismissWithButtonIndex:buttonIndex];
	
	if (self.didDismissHandler)
		self.didDismissHandler(buttonIndex);
}

#pragma mark - First Responder

- (BOOL)becomeFirstResponder {
	[super becomeFirstResponder];
	[self.alertContentView becomeFirstResponder];
	
	return YES;
}

- (BOOL)resignFirstResponder {
	[super resignFirstResponder];
	[self.alertContentView resignFirstResponder];
	
	return YES;
}

#pragma mark - Content

- (void)setAlertViewStyle:(SDCAlertViewStyle)alertViewStyle {
	_alertViewStyle = alertViewStyle;
	[self.alertContentView updateContentForStyle:alertViewStyle];
}

- (NSString *)title {
	return self.alertContentView.title;
}

- (void)setTitle:(NSString *)title {
	self.alertContentView.title = title;
}

- (NSString *)message {
	return self.alertContentView.message;
}

- (void)setMessage:(NSString *)message {
	self.alertContentView.message = message;
}

- (UIView *)contentView {
	return self.alertContentView.customContentView;
}

- (void)createContentViewWithTitle:(NSString *)title message:(NSString *)message {
	self.alertContentView.title = title;
	self.alertContentView.message = message;
	[self.alertContentView updateContentForStyle:self.alertViewStyle];
}

- (void)monitorChangesForTextFields:(NSArray *)textFields {
	[textFields enumerateObjectsUsingBlock:^(UITextField *textField, NSUInteger idx, BOOL *stop) {
		[textField addTarget:self action:@selector(updateFirstButtonEnabledStatus) forControlEvents:UIControlEventEditingChanged];
	}];
}

- (void)updateFirstButtonEnabledStatus {
	if ([self.delegate respondsToSelector:@selector(alertViewShouldEnableFirstOtherButton:)])
		self.alertContentView.firstOtherButtonEnabled = [self.delegate alertViewShouldEnableFirstOtherButton:self];
}

#pragma mark - SDCAlertViewContentViewDelegate

- (BOOL)alertContentView:(SDCAlertViewContentView *)sender shouldDeselectButtonAtIndex:(NSUInteger)index {
	if ([self.delegate respondsToSelector:@selector(alertView:shouldDeselectButtonAtIndex:)])
		return [self.delegate alertView:self shouldDeselectButtonAtIndex:index];
	else if (self.shouldDeselectButtonHandler)
		return self.shouldDeselectButtonHandler(index);

	return YES;
}

- (void)alertContentView:(SDCAlertViewContentView *)sender didTapButtonAtIndex:(NSUInteger)index {
	[self tappedButtonAtIndex:index];
}

#pragma mark - Buttons & Text Fields

- (NSInteger)cancelButtonIndex {
	return self.alertContentView.cancelButtonIndex;
}

- (void)setCancelButtonIndex:(NSInteger)cancelButtonIndex {
	self.alertContentView.cancelButtonIndex = cancelButtonIndex;
}

- (NSInteger)firstOtherButtonIndex {
	return self.alertContentView.firstOtherButtonIndex;
}

- (NSInteger)numberOfButtons {
	return self.alertContentView.numberOfButtons;
}

- (void)tappedButtonAtIndex:(NSInteger)index {
	if ([self.delegate respondsToSelector:@selector(alertView:clickedButtonAtIndex:)])
		[self.delegate alertView:self clickedButtonAtIndex:index];
	
	if (self.clickedButtonHandler)
		self.clickedButtonHandler(index);
	
	if ([self.delegate respondsToSelector:@selector(alertView:shouldDismissWithButtonIndex:)]) {
		if ([self.delegate alertView:self shouldDismissWithButtonIndex:index])
			[self dismissWithClickedButtonIndex:index animated:YES];
	} else if (self.shouldDismissHandler) {
		if (self.shouldDismissHandler(index))
			[self dismissWithClickedButtonIndex:index animated:YES];
	} else {
		[self dismissWithClickedButtonIndex:index animated:YES];
	}
}

- (NSInteger)addButtonWithTitle:(NSString *)title {
	return [self.alertContentView addButtonWithTitle:title];
}

- (NSString *)buttonTitleAtIndex:(NSInteger)index {
	return [self.alertContentView buttonTitleAtIndex:index];
}

- (UITextField *)textFieldAtIndex:(NSInteger)textFieldIndex {
	return self.alertContentView.textFields[textFieldIndex];
}

#pragma mark - Layout

- (void)willMoveToSuperview:(UIView *)newSuperview {
	if (newSuperview)
		[self setNeedsUpdateConstraints]; // Recalculate the alert's dimensions based on the alert's new superview
}

- (void)layoutSubviews {
	[super layoutSubviews];
	self.alertContentView.maximumSize = CGSizeMake(SDCAlertViewWidth, CGRectGetHeight(self.superview.bounds) - SDCAlertViewPadding.top - SDCAlertViewPadding.bottom);
	[self.alertContentView setNeedsUpdateConstraints];
}

- (void)updateConstraints {
	[self removeConstraints:[self constraints]];
	
	[self.alertBackgroundView sdc_centerInSuperview];
	[self.alertBackgroundView sdc_pinWidthToWidthOfView:self];
	[self.alertBackgroundView sdc_pinHeightToHeightOfView:self];
	
	[self.alertContentView sdc_centerInSuperview];
	[self.alertContentView sdc_pinWidthToWidthOfView:self];
	[self.alertContentView sdc_pinHeightToHeightOfView:self];
	
	[self positionSelf];
	
	[super updateConstraints];
}

- (void)positionSelf {
	[self sdc_pinWidth:SDCAlertViewWidth];
	[self sdc_centerInSuperview];
}

@end

@implementation SDCAlertView (Convenience)

- (void)showWithDismissHandler:(void (^)(NSInteger))dismissHandler {
	self.didDismissHandler = dismissHandler;
	[self show];
}

+ (instancetype)alertWithTitle:(NSString *)title message:(NSString *)message {
	return [self alertWithTitle:title message:message buttons:nil];
}

+ (instancetype)alertWithTitle:(NSString *)title message:(NSString *)message buttons:(NSArray *)buttons {
	return [self alertWithTitle:title message:message subview:nil buttons:buttons];
}

+ (instancetype)alertWithSubview:(UIView *)subview {
	return [self alertWithTitle:nil message:nil subview:subview];
}

+ (instancetype)alertWithTitle:(NSString *)title subview:(UIView *)subview {
	return [self alertWithTitle:title message:nil subview:subview];
}

+ (instancetype)alertWithTitle:(NSString *)title message:(NSString *)message subview:(UIView *)subview {
	return [self alertWithTitle:title message:message subview:subview buttons:nil];
}

+ (instancetype)alertWithTitle:(NSString *)title message:(NSString *)message subview:(UIView *)subview buttons:(NSArray *)buttons {
	SDCAlertView *alert = [[SDCAlertView alloc] initWithTitle:title
													  message:message
													 delegate:nil
											cancelButtonTitle:[buttons firstObject]
											otherButtonTitles:nil];
	
	for (int i = 1; i < [buttons count]; i++)
		[alert addButtonWithTitle:buttons[i]];
	
	if (subview)
		[alert.contentView addSubview:subview];
	
	[alert show];
	return alert;		
}

@end

@implementation SDCAlertView (UIAppearance)

- (UIFont *)titleLabelFont {
	return self.alertContentView.titleLabelFont;
}

- (void)setTitleLabelFont:(UIFont *)titleLabelFont {
	self.alertContentView.titleLabelFont = titleLabelFont;
}

- (UIColor *)titleLabelTextColor {
	return self.alertContentView.titleLabelTextColor;
}

- (void)setTitleLabelTextColor:(UIColor *)titleLabelTextColor {
	self.alertContentView.titleLabelTextColor = titleLabelTextColor;
}

- (UIFont *)messageLabelFont {
	return self.alertContentView.messageLabelFont;
}

- (void)setMessageLabelFont:(UIFont *)messageLabelFont {
	self.alertContentView.messageLabelFont = messageLabelFont;
}

- (UIColor *)messageLabelTextColor {
	return self.alertContentView.messageLabelTextColor;
}

- (void)setMessageLabelTextColor:(UIColor *)messageLabelTextColor {
	self.alertContentView.messageLabelTextColor = messageLabelTextColor;
}

- (UIFont *)textFieldFont {
	return self.alertContentView.textFieldFont;
}

- (void)setTextFieldFont:(UIFont *)textFieldFont {
	self.alertContentView.textFieldFont = textFieldFont;
}

- (UIColor *)textFieldTextColor {
	return self.alertContentView.textFieldTextColor;
}

- (void)setTextFieldTextColor:(UIColor *)textFieldTextColor {
	self.alertContentView.textFieldTextColor = textFieldTextColor;
}

- (UIFont *)suggestedButtonFont {
	return self.alertContentView.suggestedButtonFont;
}

- (void)setSuggestedButtonFont:(UIFont *)suggestedButtonFont {
	self.alertContentView.suggestedButtonFont = suggestedButtonFont;
}

- (UIFont *)normalButtonFont {
	return self.alertContentView.normalButtonFont;
}

- (void)setNormalButtonFont:(UIFont *)normalButtonFont {
	self.alertContentView.normalButtonFont = normalButtonFont;
}

- (UIColor *)buttonTextColor {
	return self.alertContentView.buttonTextColor;
}

- (void)setButtonTextColor:(UIColor *)buttonTextColor {
	self.alertContentView.buttonTextColor = buttonTextColor;
}

@end

@implementation UIColor (SDCAlertViewColors)

+ (UIColor *)sdc_alertSeparatorColor {
	return [UIColor colorWithWhite:0.5 alpha:0.5];
}

+ (UIColor *)sdc_textFieldBackgroundViewColor {
	return [UIColor colorWithWhite:0.5 alpha:0.5];
}

+ (UIColor *)sdc_dimmedBackgroundColor {
	return [UIColor colorWithWhite:0 alpha:.4];
}

@end
