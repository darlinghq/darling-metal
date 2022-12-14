/*
 * This file is part of Darling.
 *
 * Copyright (C) 2022 Darling developers
 *
 * Darling is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Darling is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Darling.  If not, see <http://www.gnu.org/licenses/>.
 */

#import <Metal/MTLDrawableInternal.h>
#import <Metal/stubs.h>

@implementation MTLDrawableInternal

#if DARLING_METAL_ENABLED

@synthesize drawable = _drawable;

- (instancetype)initWithDrawable: (std::shared_ptr<Indium::Drawable>)drawable
{
	self = [super init];
	if (self != nil) {
		_drawable = drawable;
	}
	return self;
}

- (NSUInteger)drawableID
{
	NSLog(@"STUB: drawableID");
	return 0;
}

- (CFTimeInterval)presentedTime
{
	NSLog(@"STUB: presentedTime");
	return 0;
}

- (void)present
{
	_drawable->present();
}

- (void)presentAfterMinimumDuration: (CFTimeInterval)duration
{
	NSLog(@"STUB: presentAfterMinimumDuration");
	abort();
}

- (void)presentAtTime: (CFTimeInterval)presentationTime
{
	NSLog(@"STUB: presentAtTime");
	abort();
}

- (void)addPresentedHandler: (MTLDrawablePresentedHandler)block
{
	NSLog(@"STUB: addPresentedHandler");
	abort();
}

#else

@dynamic drawableID;
@dynamic presentedTime;

MTL_UNSUPPORTED_CLASS

#endif

@end
