# cython: language_level=3

# Copyright (c) 2014, Dr Alex Meakins, Raysect Project
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#     1. Redistributions of source code must retain the above copyright notice,
#        this list of conditions and the following disclaimer.
#
#     2. Redistributions in binary form must reproduce the above copyright
#        notice, this list of conditions and the following disclaimer in the
#        documentation and/or other materials provided with the distribution.
#
#     3. Neither the name of the Raysect Project nor the names of its
#        contributors may be used to endorse or promote products derived from
#        this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

from raysect.core.math.point cimport Point3D, Point2D
from raysect.core.classes cimport Ray

cdef class BoundingBox:

    cdef Point3D lower
    cdef Point3D upper

    cpdef bint hit(self, Ray ray)

    cpdef tuple full_intersection(self, Ray ray)

    cdef inline bint intersect(self, Ray ray, double *front_intersection, double *back_intersection)

    cdef inline void _slab(self, double origin, double direction, double lower, double upper, double *front_intersection, double *back_intersection)

    cpdef bint contains(self, Point3D point)

    cpdef object union(self, BoundingBox box)

    cpdef object extend(self, Point3D point, double padding=*)

    cpdef double surface_area(self)

    cpdef double volume(self)

    cpdef list vertices(self)

    cpdef double extent(self, axis) except *

    cpdef int largest_axis(self)

    cpdef double largest_extent(self)

    cpdef object pad(self, double padding)


cdef inline BoundingBox new_boundingbox(Point3D lower, Point3D upper):
    """
    BoundingBox factory function.

    Creates a new BoundingBox object with less overhead than the equivalent
    Python call. This function is callable from cython only.
    """

    cdef BoundingBox v
    v = BoundingBox.__new__(BoundingBox)
    v.lower = lower
    v.upper = upper
    return v


cdef class BoundingBox2D:

    cdef Point2D lower
    cdef Point2D upper

    cpdef bint contains(self, Point2D point)

    cpdef object union(self, BoundingBox2D box)

    cpdef object extend(self, Point2D point, double padding=*)

    cpdef double surface_area(self)

    cpdef list vertices(self)

    cpdef double extent(self, axis) except *

    cpdef int largest_axis(self)

    cpdef double largest_extent(self)

    cpdef object pad(self, double padding)


cdef inline BoundingBox2D new_boundingbox2d(Point2D lower, Point2D upper):
    """
    BoundingBox2D factory function.

    Creates a new BoundingBox2D object with less overhead than the equivalent
    Python call. This function is callable from cython only.
    """

    cdef BoundingBox2D b
    b = BoundingBox2D.__new__(BoundingBox2D)
    b.lower = lower
    b.upper = upper
    return b
