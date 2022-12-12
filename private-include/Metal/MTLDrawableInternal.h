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

#ifndef _METAL_MTLDRAWABLEINTERNAL_H_
#define _METAL_MTLDRAWABLEINTERNAL_H_

#import <Metal/MTLDrawable.h>

#include <indium/indium.hpp>

@protocol MTLDrawableInternal <MTLDrawable>

@property(readonly) std::shared_ptr<Indium::Drawable> drawable;

@end

@interface MTLDrawableInternal : NSObject <MTLDrawableInternal>

- (instancetype)initWithDrawable: (std::shared_ptr<Indium::Drawable>)drawable;

@end

#endif // _METAL_MTLDRAWABLEINTERNAL_H_
