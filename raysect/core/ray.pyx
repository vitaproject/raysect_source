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

from raysect.core.math cimport new_point3d
cimport cython

# cython doesn't have a built-in infinity constant, this compiles to +infinity
DEF INFINITY = 1e999


@cython.freelist(256)
cdef class Ray:
    """
    Describes a line in space with an origin and direction.

    :param Point3D origin: Point defining origin (default is Point3D(0, 0, 0)).
    :param Vector3D direction: Vector defining direction (default is Vector3D(0, 0, 1)).
    :param double max_distance: The terminating distance of the ray.
    """

    def __init__(self, Point3D origin=None, Vector3D direction=None, double max_distance=INFINITY):

        if origin is None:
            origin = Point3D(0, 0, 0)

        if direction is None:
            direction = Vector3D(0, 0, 1)

        self.origin = origin
        """Point3D defining origin (default is Point3D(0, 0, 0))."""
        self.direction = direction
        """Vector3D defining direction (default is Vector3D(0, 0, 1))."""
        self.max_distance = max_distance
        """The terminating distance of the ray."""

    def __repr__(self):

        return "Ray({}, {}, {})".format(self.origin, self.direction, self.max_distance)

    def __getstate__(self):
        """Encodes state for pickling."""

        return self.origin, self.direction, self.max_distance

    def __setstate__(self, state):
        """Decodes state for pickling."""

        self.origin, self.direction, self.max_distance = state

    cpdef Point3D point_on(self, double t):
        """
        Returns the point on the ray at the specified parametric distance from the ray origin.

        Positive values correspond to points forward of the ray origin, along the ray direction.

        :param t: The distance along the ray.
        :return: A point at distance t along the ray direction measured from its origin.
        """
        cdef:
            Point3D origin = self.origin
            Vector3D direction = self.direction

        return new_point3d(origin.x + t * direction.x,
                           origin.y + t * direction.y,
                           origin.z + t * direction.z)

    cpdef Ray copy(self, Point3D origin=None, Vector3D direction=None):

        if origin is None:
            origin = self.origin.copy()

        if direction is None:
            direction =self.direction.copy()

        return new_ray(origin, direction, self.max_distance)
