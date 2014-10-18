from raysect.core import World, translate, rotate, Point, Vector, Ray
from raysect.optical.observer.pinholecamera import PinholeCamera
from raysect.optical.material.emitter import UniformVolumeEmitter, UniformSurfaceEmitter, Checkerboard
from raysect.optical.material.glass import Glass, BK7, Sellmeier
from raysect.primitive import Sphere, Box, Cylinder
from raysect.primitive.csg import Union, Intersect, Subtract
from raysect.optical.colour import d65_white
from raysect.optical.spectralfunction import ConstantSF, SampledSF
from matplotlib.pyplot import *
from raysect.core.acceleration import Unaccelerated
from numpy import array

# kludge to fix matplotlib 1.4 ion() idiocy
import sys
sys.ps1 = 'SOMETHING'

world = World()
#sphere = Sphere(world, translate(0, 0, 0) * rotate(0, 0, 0), UniformVolumeEmitter(), 1.5)
#box = Box(world, translate(0, -2, 0) * rotate(35, 230, 8), UniformVolumeEmitter(), Point(-1, -1, -1), Point(1, 1, 1))

rota = 45
rotb = 0

# csg_u = Union(world, translate(0, 2, 0) * rotate(rota, 0, rotb), UniformVolumeEmitter(),
#               primitive_a=Sphere(transform=translate(0, 0, 0), radius=1.0),
#               primitive_b=Box(transform=translate(0, 0, 0), lower=Point(-1.5, -0.5, -0.5), upper=Point(1.5, 0.5, 0.5)))

# csg_i = Intersect(world, translate(0, 0, 0) * rotate(rota, 0, rotb), UniformVolumeEmitter(),
#               primitive_a=Sphere(transform=translate(0, 0, 0), radius=1.0),
#               primitive_b=Box(transform=translate(0, 0, 0), lower=Point(-1.5, -0.5, -0.5), upper=Point(1.5, 0.5, 0.5)))

# csg_i = Intersect(world, translate(0,-2, 0) * rotate(rot, 0, rot), UniformVolumeEmitter(),
#               primitive_a=Sphere(transform=translate(2.8, 0, 0), radius=3.0),
#               primitive_b=Sphere(transform=translate(-2.8, 0, 0), radius=3.0))

# csg_s = Subtract(world, translate(0, -2, 0) * rotate(rota, 0, rotb), UniformVolumeEmitter(),
#             primitive_a=Sphere(transform=translate(0, 0, 0), radius=1.0),
#             primitive_b=Box(transform=translate(0, 0, 0), lower=Point(-1.5, -0.5, -0.5), upper=Point(1.5, 0.5, 0.5)))

# box_x = Box(Point(-1.6, -0.75, -0.75), Point(1.6, 0.75, 0.75))
# box_y = Box(Point(-0.75, -1.6, -0.75), Point(0.75, 1.6, 0.75))
# box_z = Box(Point(-0.75, -0.75, -1.6), Point(0.75, 0.75, 1.6))
# cube = Box(Point(-1.5, -1.5, -1.5), Point(1.5, 1.5, 1.5))
# sphere = Sphere(2.0)
# compound = Intersect(sphere, Subtract(cube, Union(Union(box_x, box_y), box_z)), world, rotate(30, 20, 0), UniformVolumeEmitter())

#cylinder = Cylinder(0.5, 10.0, world, translate(2, 0, 0) * rotate(90, 0, 0), UniformVolumeEmitter())

red_glass = Glass(index=Sellmeier(1.03961212, 0.231792344, 1.01046945, 6.00069867e-3, 2.00179144e-2, 1.03560653e2),
                  transmission=SampledSF([300, 490, 510, 590, 610, 800], array([0.0, 0.0, 0.0, 0.0, 1.0, 1.0])*0.7),
                  cutoff=1e-4)

green_glass = Glass(index=Sellmeier(1.03961212, 0.231792344, 1.01046945, 6.00069867e-3, 2.00179144e-2, 1.03560653e2),
                    transmission=SampledSF([300, 490, 510, 590, 610, 800], array([0.0, 0.0, 1.0, 1.0, 0.0, 0.0])*0.7),
                    cutoff=1e-4)

blue_glass = Glass(index=Sellmeier(1.03961212, 0.231792344, 1.01046945, 6.00069867e-3, 2.00179144e-2, 1.03560653e2),
                   transmission=SampledSF([300, 490, 510, 590, 610, 800], array([1.0, 1.0, 0.0, 0.0, 0.0, 0.0])*0.7),
                   cutoff=1e-4)


cyl_x = Cylinder(1, 4.2, transform=rotate(90, 0, 0)*translate(0, 0, -2.1))
cyl_y = Cylinder(1, 4.2, transform=rotate(0, 90, 0)*translate(0, 0, -2.1))
cyl_z = Cylinder(1, 4.2, transform=rotate(0, 0, 0)*translate(0, 0, -2.1))
cube = Box(Point(-1.5, -1.5, -1.5), Point(1.5, 1.5, 1.5))
sphere = Sphere(2.0)

#Subtract(sphere, Sphere(1.5), world, rotate(30, 23, 5), Glass(testindex, testindex))
Intersect(sphere, Subtract(cube, Union(Union(cyl_x, cyl_y), cyl_z)), world, rotate(30, 20, 0), green_glass)
#Union(Union(cyl_x, cyl_y), cyl_z, world, rotate(30, 20, 0), BK7())



#Intersect(sphere, cube, world, rotate(5, 0, 0), BK7())
#Intersect(sphere, cube, world, rotate(30, 25, 0), BK7())

#cube = Box(Point(-1.5, -1.5, -1.5), Point(1.5, 1.5, 1.5), world, rotate(30, 25, 0), BK7())

cube1 = Box(Point(-1.5, -1.5, -1.5), Point(1.5, 1.5, 1.5))#, transform=translate(0.25, 0.25, 0.25))
cube2 = Box(Point(-1.5, -1.5, -1.5), Point(1.5, 1.5, 1.5), transform=rotate(45, 45, 0))#, transform=translate(-0.25, -0.25, -0.25))
#Intersect(cube1, cube2, world, rotate(30, 25, 0), BK7())

#Box(Point(-1.5, -1.5, -1.5), Point(1.5, 1.5, 1.5), world, rotate(30, 23, 5), BK7())
#Sphere(2.0, world, material=red_glass)


#Cylinder(0.05, 20, world, transform=translate(10, 1.2, 7.1)*rotate(90, 0, 0), material=UniformSurfaceEmitter(1.0))
# Cylinder(2, 20, world, transform=translate(10, 1.2, 7.1)*rotate(90, 0, 0), material=UniformVolumeEmitter(0.1))
# Box(world, transform=translate(0, 0, 0), material=UniformVolumeEmitter(), lower=Point(-2,-0.2,-0.2), upper=Point(2,0.2,0.2))

s1 = Sphere(1.0, transform=translate(0, 0, 1.0-0.01))
s2 = Sphere(0.5, transform=translate(0, 0, -0.5+0.01))
#Intersect(s1, s2, world, translate(0,0,-7.6)*rotate(65,30,0), BK7())

Box(Point(-50, -50, 50), Point(50, 50, 50.1), world, material=Checkerboard(4, d65_white, d65_white, 0.4, 0.8))
#Box(Point(-50, -50, -50), Point(50, 50, 50), world, material=Checkerboard(4, d65_white, d65_white, 0.4, 0.8))
#Box(Point(-50, -50, -50), Point(50, 50, 50), world, material=UniformSurfaceEmitter(d65_white, 0.5))

ion()
camera = PinholeCamera(fov=45, parent=world, transform=translate(0, 0, -8) * rotate(0, 0, 0))
camera.ray_max_depth = 15
camera.rays = 15
camera.spectral_samples = 1
camera.pixels = (512, 512)
camera.display_progress = True
camera.display_update_time = 10


camera.observe()

ioff()
camera.save("render.png")
camera.display()
show()
