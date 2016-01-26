# cython: language_level=3

# Copyright (c) 2016, Dr Alex Meakins, Raysect Project
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

from math import tan, pi, ceil
from multiprocessing import Process, cpu_count, Queue
from time import time

import numpy as np
from matplotlib.pyplot import imshow, imsave, show, clf, draw, pause
from numpy import zeros

from raysect.core import World, AffineMatrix3D, Observer
from raysect.core.math import random
from raysect.optical.colour import resample_ciexyz, spectrum_to_ciexyz, ciexyz_to_srgb
from raysect.optical import Ray


# todo: add scheme to evenly subdivide spectral_samples across specified spectral_rays
class Camera(Observer):
    """
    The abstract base class for Camera observers.

    This class holds all the generic options for 2D cameras. It defines all the interface
    methods that user cameras must implement.

    :param tuple pixels: A tuple specification of the cameras pixel dimensions, the default is pixels=(512, 512).
    :param float sensitivity: The cameras sensitivity coefficient, all samples collected be this camera will by
    multiplied by this number.
    :param int spectral_samples: The number of wavelength bins to collect over the wavelength range min_wavelength to
    max_wavelength. For example, if the wavelength range is 400nm to 500nm and spectral_samples=100, each wavelength bin
    would be 1nm wide. Default is spectral_samples=20.
    :param int spectral_rays: The number of rays to sample over this wavelength range. For example, if the wavelength
    range is 400nm to 500nm, spectral_samples=100 and spectral_rays=5, their would be five rays launched each with 20
    spectral samples. The first ray would have the range 400nm-420nm, 420nm-440nm for the second ray, etc. This
    behaviour is needed when dispersion effects are important. For example, when light passes through a prism and is
    separated into different paths. For scenes where dispersion effects are important, rays >> 10. The default
    spectral_rays = 1.
    :param int pixel_samples: The number of rays to launch per pixel. Real pixels collect light over a solid angle. To
    prevent aliasing effects and compute a more realistic pixel response, pixel_samples >> 10. The default
    pixel_samples=100.
    :param int process_count: The number of parallel processes to use. Defaults to the number of cpu cores available.
    :param parent: The parent node in the scenegraph. All camera observers must be parented to a World object.
    :param AffineMatrix3D transform: A transform matrix describing the location and orientation of this camera in world
    space.
    :param name: An optional name for this camera.
    """

    def __init__(self, pixels=(512, 512), sensitivity=1.0, spectral_samples=21, spectral_rays=1, pixel_samples=100,
                 process_count=0, parent=None, transform=None, name=None):

        super().__init__(parent, transform, name)

        if spectral_samples < 1:
            raise ValueError("Number of spectral sample bins cannot be less than 1.")

        if spectral_rays < 1:
            raise ValueError("Number of rays cannot be less than 1.")

        if spectral_rays > spectral_samples:
            raise ValueError("Number of rays cannot exceed the number of spectral sample bins.")

        # ray configuration
        self.spectral_rays = spectral_rays
        self.spectral_samples = spectral_samples
        self.min_wavelength = 375.0
        self.max_wavelength = 740.0
        self.ray_extinction_prob = 0.1
        self.ray_min_depth = 3
        self.ray_max_depth = 100

        # progress information
        self.display_progress = True
        self.display_update_time = 10.0

        # concurrency configuration
        if process_count < 1:
            process_count = cpu_count()
        self.process_count = process_count

        # camera configuration
        self._pixels = pixels
        self.sensitivity = sensitivity
        self.pixel_samples = pixel_samples
        self.accumulate = False
        self.accumulated_samples = 0

        # output from last call to Observe()
        self.xyz_frame = zeros((pixels[1], pixels[0], 3))
        self.frame = zeros((pixels[1], pixels[0], 3))

        self._point_generator = None
        self._vector_generator = None

    @property
    def pixels(self):
        return self._pixels

    @pixels.setter
    def pixels(self, pixels):
        if len(pixels) != 2:
            raise ValueError("Pixel dimensions of camera frame-buffer must be a tuple "
                             "containing the x and y pixel counts.")
        self._pixels = pixels

        # reset frames
        self.xyz_frame = zeros((self._pixels[1], self._pixels[0], 3))
        self.frame = zeros((self._pixels[1], self._pixels[0], 3))
        self.accumulated_samples = 0

    def observe(self):
        """ Ask this Camera to Observe its world. """

        # must be connected to a world node to be able to perform a ray trace
        if not isinstance(self.root, World):
            raise TypeError("Observer is not connected to a scene graph containing a World object.")

        if self.min_wavelength >= self.max_wavelength:
            raise RuntimeError("Min wavelength is superior to max wavelength!")

        # create intermediate and final frame-buffers
        if not self.accumulate:
            self.xyz_frame = zeros((self._pixels[0], self._pixels[1], 3))
            self.frame = zeros((self._pixels[0], self._pixels[1], 3))
            self.accumulated_samples = 0

        # generate spectral data
        ray_templates = self._generate_ray_templates()

        # trace
        if self.process_count == 1:
            self._observe_single(self.xyz_frame, ray_templates)
        else:
            self._observe_parallel(self.xyz_frame, ray_templates)

        # update sample accumulation statistics
        self.accumulated_samples += self.pixel_samples * self.spectral_rays

    def _observe_single(self, xyz_frame, ray_templates):

        # initialise user interface
        display_timer = self._start_display()
        statistics_data = self._start_statistics()

        # generate weightings for accumulation
        total_samples = self.accumulated_samples + self.pixel_samples * self.spectral_rays
        previous_weight = self.accumulated_samples / total_samples
        added_weight = self.spectral_rays * self.pixel_samples / total_samples

        # scale previous state to account for additional samples
        xyz_frame[:, :, :] = previous_weight * xyz_frame[:, :, :]

        # render
        for i_channel, ray_template in enumerate(ray_templates):

            # generate resampled XYZ curves for channel spectral range
            resampled_xyz = resample_ciexyz(
                ray_template.min_wavelength,
                ray_template.max_wavelength,
                ray_template.num_samples
            )

            ny, nx = self._pixels
            for iy in range(ny):
                for ix in range(nx):

                    # load selected pixel and trace rays
                    spectrum, ray_count = self._sample_pixel(ix, iy, self.root, ray_template)

                    # convert spectrum to CIE XYZ
                    xyz = spectrum_to_ciexyz(spectrum, resampled_xyz)

                    xyz_frame[iy, ix, 0] += added_weight * xyz[0]
                    xyz_frame[iy, ix, 1] += added_weight * xyz[1]
                    xyz_frame[iy, ix, 2] += added_weight * xyz[2]

                    # convert to sRGB colour-space
                    self.frame[iy, ix, :] = ciexyz_to_srgb(*xyz_frame[iy, ix, :])

                    # update users
                    pixel = ix + self._pixels[0] * iy
                    statistics_data = self._update_statistics(statistics_data, i_channel, pixel, ray_count)
                    display_timer = self._update_display(display_timer)

        # final update for users
        self._final_statistics(statistics_data)
        self._final_display()

    def _observe_parallel(self, xyz_frame, ray_templates):

        world = self.root

        # initialise user interface
        display_timer = self._start_display()
        statistics_data = self._start_statistics()

        total_pixels = self._pixels[0] * self._pixels[1]

        # generate weightings for accumulation
        total_samples = self.accumulated_samples + self.pixel_samples * self.spectral_rays
        previous_weight = self.accumulated_samples / total_samples
        added_weight = self.spectral_rays * self.pixel_samples / total_samples

        # scale previous state to account for additional samples
        xyz_frame[:, :, :] = previous_weight * xyz_frame[:, :, :]

        # render
        for channel, ray_template in enumerate(ray_templates):

            # generate resampled XYZ curves for channel spectral range
            resampled_xyz = resample_ciexyz(
                ray_template.min_wavelength,
                ray_template.max_wavelength,
                ray_template.num_samples
            )

            # establish ipc queues using a manager process
            task_queue = Queue()
            result_queue = Queue()

            # start process to generate image samples
            producer = Process(target=self._producer, args=(task_queue, ))
            producer.start()

            # start worker processes
            workers = []
            for pid in range(self.process_count):
                p = Process(target=self._worker,
                            args=(world, ray_template,
                                  resampled_xyz, task_queue, result_queue))
                p.start()
                workers.append(p)

            # collect results
            for pixel in range(total_pixels):

                # obtain result
                location, xyz, sample_ray_count = result_queue.get()
                x, y = location

                xyz_frame[y, x, 0] += added_weight * xyz[0]
                xyz_frame[y, x, 1] += added_weight * xyz[1]
                xyz_frame[y, x, 2] += added_weight * xyz[2]

                # convert to sRGB colour-space
                self.frame[y, x, :] = ciexyz_to_srgb(*xyz_frame[y, x, :])

                # update users
                display_timer = self._update_display(display_timer)
                statistics_data = self._update_statistics(statistics_data, channel, pixel, sample_ray_count)

            # shutdown workers
            for _ in workers:
                task_queue.put(None)

        # final update for users
        self._final_statistics(statistics_data)
        self._final_display()

    def _producer(self, task_queue):
        # task is simply the pixel location
        nx, ny = self._pixels
        for y in range(ny):
            for x in range(nx):
                task_queue.put((x, y))

    def _worker(self, world, ray_template, resampled_xyz, task_queue, result_queue):

        # re-seed the random number generator to prevent all workers inheriting the same sequence
        random.seed()

        while True:

            # request next pixel
            pixel_id = task_queue.get()

            # have we been commanded to shutdown?
            if pixel_id is None:
                break

            ix, iy = pixel_id

            # load selected pixel and trace rays
            spectrum, ray_count = self._sample_pixel(ix, iy, self.root, ray_template)

            # convert spectrum to CIE XYZ
            xyz = spectrum_to_ciexyz(spectrum, resampled_xyz)

            # encode result and send
            result = (pixel_id, xyz, ray_count)
            result_queue.put(result)

    def _generate_ray_templates(self):

        # split spectral bins across rays - non-integer division is handled by
        # rounding up or down the non-integer boundaries between the ray ranges,
        # this means that some rays will have more samples than others
        current = 0
        start = 0
        ranges = []
        while start < self.spectral_samples:
            current += self.spectral_samples / self.spectral_rays
            end = round(current)
            ranges.append((start, end))
            start = end

        # build template rays
        rays = []
        delta_wavelength = (self.max_wavelength - self.min_wavelength) / self.spectral_samples
        for start, end in ranges:
            rays.append(
                Ray(min_wavelength=self.min_wavelength + delta_wavelength * start,
                    max_wavelength=self.min_wavelength + delta_wavelength * end,
                    num_samples=end - start,
                    extinction_prob=self.ray_extinction_prob,
                    min_depth=self.ray_min_depth,
                    max_depth=self.ray_max_depth)
            )

        return rays

    def _sample_pixel(self, ix, iy, world, ray_template):

        # generate rays
        rays = self._generate_rays(ix, iy, ray_template)

        # create spectrum and calculate sample weighting
        spectrum = ray_template.new_spectrum()
        weight = 1 / self.pixel_samples

        # initialise ray statistics
        ray_count = 0

        # launch rays and accumulate spectral samples
        for ray in rays:

            # convert ray from local space to world space
            ray.origin = ray.origin.transform(self.to_root())
            ray.direction = ray.direction.transform(self.to_root())

            sample = ray.trace(world)
            spectrum.samples += weight * sample.samples

            # accumulate statistics
            ray_count += ray.ray_count

        # apply camera sensitivity
        spectrum.samples *= self.sensitivity

        return spectrum, ray_count

    def _generate_rays(self, ix, iy, ray_template):
        raise NotImplementedError("To be defined in subclass.")

    def _start_display(self):
        """
        Display live render.
        """

        display_timer = 0
        if self.display_progress:
            self.display()
            display_timer = time()
        return display_timer

    def _update_display(self, display_timer):
        """
        Update live render.
        """

        # update live render display
        if self.display_progress and (time() - display_timer) > self.display_update_time:

            print("Refreshing display...")
            self.display()
            display_timer = time()

        return display_timer

    def _final_display(self):
        """
        Display final frame.
        """

        if self.display_progress:
            self.display()

    def _start_statistics(self):
        """
        Initialise statistics.
        """

        total_pixels = self._pixels[0] * self._pixels[1]
        total_work = total_pixels * self.spectral_rays
        ray_count = 0
        start_time = time()
        progress_timer = time()
        return total_work, total_pixels, ray_count, start_time, progress_timer

    def _update_statistics(self, statistics_data, index, pixel, sample_ray_count):
        """
        Display progress statistics.
        """

        total_work, total_pixels, ray_count, start_time, progress_timer = statistics_data
        ray_count += sample_ray_count

        if (time() - progress_timer) > 1.0:

            current_work = total_pixels * index + pixel
            completion = 100 * current_work / total_work
            print("{:0.2f}% complete (channel {}/{}, line {}/{}, pixel {}/{}, {:0.1f}k rays)".format(
                completion, index + 1, self.spectral_rays,
                ceil((pixel + 1) / self._pixels[0]), self._pixels[1],
                pixel + 1, total_pixels, ray_count / 1000))
            ray_count = 0
            progress_timer = time()

        return total_work, total_pixels, ray_count, start_time, progress_timer

    def _final_statistics(self, statistics_data):
        """
        Final statistics output.
        """
        _, _, _, start_time, _ = statistics_data
        elapsed_time = time() - start_time
        print("Render complete - time elapsed {:0.3f}s".format(elapsed_time))

    def display(self):
        clf()
        imshow(self.frame, aspect="equal", origin="upper")
        draw()
        show()

        # workaround for interactivity for QT backend
        pause(0.1)

    def save(self, filename):
        """
        Save the collected samples in the camera frame to file.

        :param str filename: Filename and path for camera frame output file.
        """
        imsave(filename, self.frame)

