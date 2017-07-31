# cython: language_level=3

# Copyright (c) 2014-2017, Dr Alex Meakins, Raysect Project
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

import numpy as np
cimport numpy as np
from libc.math cimport M_PI
from numpy cimport float32_t, int32_t

from raysect.core.math.random cimport uniform, point_triangle
from raysect.core.math.sampler cimport HemisphereCosineSampler
from raysect.core.math.cython cimport find_index
from raysect.optical cimport Ray, Point3D, new_point3d, new_vector3d, Vector3D, AffineMatrix3D, new_affinematrix3d
from raysect.optical.observer.base cimport Observer0D
from raysect.optical.observer.pipeline.spectral import SpectralPipeline0D
from raysect.primitive.mesh.mesh cimport Mesh
cimport cython

# convenience defines
DEF X = 0
DEF Y = 1
DEF Z = 2

DEF V1 = 0
DEF V2 = 1
DEF V3 = 2


cdef class MeshPixel(Observer0D):
    """
    Uses a supplied mesh surface as a pixel.

    Warning: you must be careful when using this camera to not double count radiance. For example,
    if you have a concave mesh its possible for two surfaces to see the same emission. In cases
    like this, the mesh should have an absorbing surface to prevent double counting.

    This observer samples over the surface defined by a triangular mesh. At each point on the surface
    the incoming radiance over a hemisphere is sampled.

    A mesh surface offset can be set to ensure sample don't collide with a coincident primitive. When set,
    the surface offset specifies the distance along the surface normal that the ray launch origin is shifted.

    :param list pipelines: The list of pipelines that will process the spectrum measured
      by this pixel (default=SpectralPipeline0D()).
    :param float surface_offset: The offset from the mesh surface (default=0).
    :param kwargs: **kwargs from Observer0D and _ObserverBase
    """

    cdef:
        double _surface_offset, _solid_angle, _collection_area
        float32_t[:, ::1] _vertices_mv
        float32_t[:, ::1] _face_normals_mv
        int32_t[:, ::1] _triangles_mv
        np.ndarray _cdf
        double [::1] _cdf_mv
        HemisphereCosineSampler _vector_sampler

    def __init__(self, Mesh mesh not None, surface_offset=None, pipelines=None, parent=None, transform=None, name=None,
                 render_engine=None, pixel_samples=None, samples_per_task=None, spectral_rays=None, spectral_bins=None,
                 min_wavelength=None, max_wavelength=None, ray_extinction_prob=None, ray_extinction_min_depth=None,
                 ray_max_depth=None, ray_importance_sampling=None, ray_important_path_weight=None):

        pipelines = pipelines or [SpectralPipeline0D()]

        super().__init__(pipelines, parent=parent, transform=transform, name=name, render_engine=render_engine,
                         pixel_samples=pixel_samples, samples_per_task=samples_per_task, spectral_rays=spectral_rays,
                         spectral_bins=spectral_bins, min_wavelength=min_wavelength, max_wavelength=max_wavelength,
                         ray_extinction_prob=ray_extinction_prob, ray_extinction_min_depth=ray_extinction_min_depth,
                         ray_max_depth=ray_max_depth, ray_importance_sampling=ray_importance_sampling,
                         ray_important_path_weight=ray_important_path_weight)

        surface_offset = surface_offset or 0.0
        if surface_offset < 0:
            raise ValueError("Surface offset must be greater than or equal to zero.")

        self._surface_offset = surface_offset

        # TODO - replace this with access to Mesh public methods when implemented, this breaks encapsulation, yuck!
        self._vertices_mv = mesh._data.vertices
        self._face_normals_mv = mesh._data.face_normals
        self._triangles_mv = mesh._data.triangles

        self._vector_sampler = HemisphereCosineSampler()
        self._solid_angle = 2 * M_PI
        self._calculate_areas()

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.initializedcheck(False)
    cdef object _calculate_areas(self):
        cdef:
            int32_t i, v1i, v2i, v3i

        # initialise area attributes
        self._collection_area = 0.0
        self._cdf = np.zeros(self._triangles_mv.shape[0])
        self._cdf_mv = self._cdf
        
        # calculate cumulative and total area simultaneously 
        for i in range(self._triangles_mv.shape[0]):

            # obtain vertex indices
            v1i = self._triangles_mv[i, V1]
            v2i = self._triangles_mv[i, V2]
            v3i = self._triangles_mv[i, V3]

            # obtain area and accumulate
            triangle_area = self._triangle_area(
                new_point3d(self._vertices_mv[v1i, X], self._vertices_mv[v1i, Y], self._vertices_mv[v1i, Z]),
                new_point3d(self._vertices_mv[v2i, X], self._vertices_mv[v2i, Y], self._vertices_mv[v2i, Z]),
                new_point3d(self._vertices_mv[v3i, X], self._vertices_mv[v3i, Y], self._vertices_mv[v3i, Z])
            )
            self._collection_area += triangle_area
            self._cdf_mv[i] = self._collection_area
        
        # normalise cumulative area to make cdf
        self._cdf /= self._collection_area

    cdef double _triangle_area(self, Point3D v1, Point3D v2, Point3D v3):
        cdef Vector3D e1 = v1.vector_to(v2)
        cdef Vector3D e2 = v1.vector_to(v3)
        return 0.5 * e1.cross(e2).get_length()

    @property
    def collection_area(self):
        """
        The pixel's collection area in m^2.

        :rtype: float
        """
        return self._collection_area

    @property
    def solid_angle(self):
        """
        The pixel's solid angle in steradians str.

        :rtype: float
        """
        return self._solid_angle

    @property
    def etendue(self):
        """
        The pixel's etendue measured in units of per area per solid angle (m^-2 str^-1).

        :rtype: float
        """
        return self._pixel_etendue()

    @cython.boundscheck(False)
    @cython.wraparound(False)
    @cython.initializedcheck(False)
    cpdef list _generate_rays(self, Ray template, int ray_count):

        cdef:
            list rays, origins, directions
            Point3D origin
            Vector3D normal, direction
            int n
            double weight
            AffineMatrix3D surface_to_local
            int32_t triangle, v1i, v2i, v3i

        directions = self._vector_sampler(ray_count)

        rays = []
        for n in range(ray_count):

            # pick triangle
            triangle = self._pick_triangle()

            # unpack vertex indices
            v1i = self._triangles_mv[triangle, V1]
            v2i = self._triangles_mv[triangle, V2]
            v3i = self._triangles_mv[triangle, V3]

            # obtain face normal
            normal = new_vector3d(
                self._face_normals_mv[triangle, X],
                self._face_normals_mv[triangle, Y],
                self._face_normals_mv[triangle, Z]
            )

            # sample triangle surface to get origin point in local space
            origin = point_triangle(
                new_point3d(self._vertices_mv[v1i, X], self._vertices_mv[v1i, Y], self._vertices_mv[v1i, Z]),
                new_point3d(self._vertices_mv[v2i, X], self._vertices_mv[v2i, Y], self._vertices_mv[v2i, Z]),
                new_point3d(self._vertices_mv[v3i, X], self._vertices_mv[v3i, Y], self._vertices_mv[v3i, Z])
            )

            # shift origin point forward along normal by distance in surface_offset
            origin = origin.add(normal.mul(self._surface_offset))

            # generate the transform from the triangle surface normal to local (z-axis aligned)
            surface_to_local = self._surface_to_local(normal)

            # rotate direction sample so z aligned with face normal
            direction = (<Vector3D> directions[n]).transform(surface_to_local)

            # cosine weighted distribution
            # projected area cosine is implicit in distribution
            # weight = (1 / 2*pi) * (pi / cos(theta)) * cos(theta) = 0.5
            rays.append((template.copy(origin, direction), 0.5))

        return rays

    @cython.initializedcheck(False)
    cdef inline int32_t _pick_triangle(self):
        """
        Pick a triangle such that sample points are uniform across the surface area.
        """

        # due to the CDF not starting at zero, using find_index means that the result is offset by 1 index point.
        return find_index(self._cdf_mv, uniform()) + 1

    cdef inline AffineMatrix3D _surface_to_local(self, Vector3D normal):
        """
        Calculates the surface to local space transform.

        :param Vector3D normal: Local space surface normal.
        :return: AffineMatrix3D surface to local transform.
        """

        cdef:
            Vector3D tangent, bitangent
            AffineMatrix3D surface_to_primitive

        tangent = normal.orthogonal()
        bitangent = normal.cross(tangent)

        surface_to_primitive = new_affinematrix3d(
            tangent.x, bitangent.x, normal.x, 0.0,
            tangent.y, bitangent.y, normal.y, 0.0,
            tangent.z, bitangent.z, normal.z, 0.0,
            0.0, 0.0, 0.0, 1.0
        )

        return surface_to_primitive

    cpdef double _pixel_etendue(self):
        return self._solid_angle * self._collection_area