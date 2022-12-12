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

#ifndef _METAL_MTLDEFINES_H_
#define _METAL_MTLDEFINES_H_

#include <sys/cdefs.h>

#define METAL_DECLARATIONS_BEGIN __BEGIN_DECLS
#define METAL_DECLARATIONS_END __END_DECLS

#define MTL_EXPORT __attribute__((visibility("default")))

#if __cplusplus
	#define MTL_EXTERN extern "C"
#else
	#define MTL_EXTERN extern
#endif

#endif // _METAL_MTLDEFINES_H_
