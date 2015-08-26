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

cimport cython
from numpy import array
from numpy cimport ndarray
from libc.math cimport fabs
from raysect.core.math.affinematrix cimport AffineMatrix
from raysect.core.math.point cimport Point
from raysect.core.math.vector cimport Vector, new_vector
from raysect.core.math.normal cimport Normal
from raysect.core.scenegraph.primitive cimport Primitive
from raysect.core.scenegraph.world cimport World
from raysect.optical.spectralfunction cimport InterpolatedSF
from raysect.optical.spectrum cimport Spectrum
from raysect.optical.ray cimport Ray

# GOLD TEST

gold_wavelength = array(
    [0.2066, 0.2108950832, 0.2152794584, 0.2197549821, 0.224323549, 0.2289870936, 0.2337475903, 0.2386070547,
     0.2435675442, 0.2486311593, 0.2538000437, 0.2590763859, 0.2644624199, 0.2699604262, 0.2755727325, 0.2813017151,
     0.2871497997, 0.2931194622, 0.2992132302, 0.3054336838, 0.3117834567, 0.3182652374, 0.3248817702, 0.3316358565,
     0.3385303559, 0.3455681877, 0.3527523315, 0.3600858291, 0.3675717855, 0.3752133702, 0.3830138186, 0.3909764334,
     0.3991045859, 0.4074017175, 0.4158713413, 0.4245170432, 0.4333424837, 0.4423513996, 0.4515476051, 0.4609349939,
     0.4705175406, 0.4802993023, 0.4902844207, 0.5004771234, 0.5108817259, 0.5215026335, 0.5323443431, 0.5434114449,
     0.5547086248, 0.5662406659, 0.5780124508, 0.5900289637, 0.6022952923, 0.6148166301, 0.6275982785, 0.6406456494,
     0.6539642668, 0.6675597698, 0.6814379148, 0.6956045776, 0.7100657563, 0.7248275738, 0.7398962801, 0.7552782553,
     0.770980012, 0.7870081983, 0.8033696005, 0.8200711458, 0.8371199057, 0.8545230985, 0.8722880927, 0.8904224098,
     0.908933728, 0.9278298847, 0.9471188805, 0.9668088824, 0.9869082269, 1.0074254241, 1.0283691608, 1.0497483045,
     1.0715719071, 1.0938492086, 1.116589641, 1.1398028327, 1.1634986119, 1.1876870114, 1.2123782724, 1.237582849,
     1.2633114129, 1.2895748573, 1.316384302, 1.3437510982, 1.3716868327, 1.4002033335, 1.4293126742, 1.4590271797,
     1.489359431, 1.5203222706, 1.551928808, 1.5841924253, 1.6171267828, 1.6507458247, 1.6850637852, 1.7200951944,
     1.7558548844, 1.7923579957, 1.8296199836, 1.8676566246, 1.9064840233, 1.9461186191, 1.9865771929, 2.027876875,
     2.0700351512, 2.1130698714, 2.1569992561, 2.2018419049, 2.247616804, 2.2943433343, 2.3420412795, 2.3907308348,
     2.4404326152, 2.4911676641, 2.5429574625, 2.595823938, 2.6497894741, 2.7048769196, 2.7611095981, 2.8185113185,
     2.8771063842, 2.9369196043, 2.9979763033, 3.0603023325, 3.1239240803, 3.188868484, 3.2551630407, 3.3228358193,
     3.3919154721, 3.4624312472, 3.5344130005, 3.607891209, 3.6828969828, 3.7594620793, 3.8376189156, 3.917400583,
     3.9988408608, 4.0819742304, 4.1668358901, 4.25346177, 4.3418885471, 4.4321536609, 4.5242953292, 4.6183525645,
     4.7143651902, 4.8123738576, 4.9124200631, 5.0145461659, 5.1187954057, 5.2252119211, 5.3338407686, 5.444727941,
     5.5579203875, 5.6734660334, 5.7914138, 5.911813626, 6.0347164882, 6.1601744231, 6.288240549, 6.4189690885,
     6.5524153917, 6.6886359589, 6.8276884656, 6.9696317858, 7.1145260177, 7.262432509, 7.4134138826, 7.5675340634,
     7.7248583051, 7.8854532182, 8.0493867979, 8.2167284529, 8.387549035, 8.5619208687, 8.7399177826, 8.9216151395,
     9.1070898695, 9.2964205017, 9.4896871978, 9.6869717862, 9.8883577962, 10.0939304939, 10.3037769178, 10.517985916,
     10.7366481837, 10.9598563014, 11.1877047746, 11.4202900733, 11.6577106731, 11.9000670968, 12.1474619572,
     12.4]) * 1000

gold_index = array(
    [1.2522332082, 1.2886050167, 1.3205398635, 1.3488833625, 1.3746284289, 1.3988261142, 1.422485501, 1.4464756204,
     1.4714431288, 1.4977566889, 1.5254834111, 1.5543962912, 1.5840063932, 1.6136108117, 1.6423473309, 1.6692485833,
     1.6932916613, 1.71344306, 1.7287031661, 1.7381586456, 1.741053695, 1.73689001, 1.7255577949, 1.7074840795,
     1.6837605099, 1.6561869611, 1.6271556387, 1.5993263363, 1.5751208198, 1.5561662549, 1.5428732988, 1.5342880299,
     1.5282356392, 1.5216660278, 1.5110762108, 1.4929122606, 1.4639038179, 1.4213287413, 1.3632372234, 1.2886853064,
     1.1980312816, 1.0933056197, 0.9785231659, 0.8595750635, 0.7432888821, 0.635790656, 0.5410933501, 0.4607391554,
     0.3943739182, 0.3405930248, 0.2976056028, 0.2636210572, 0.2370280091, 0.2164538353, 0.2007654748, 0.1890453416,
     0.1805592808, 0.1747243908, 0.1710799794, 0.1692627284, 0.1689861321, 0.1700238372, 0.1721963538, 0.1753605823,
     0.179401637, 0.184226512, 0.189759203, 0.1959369687, 0.2027074754, 0.2100266216, 0.217856883, 0.2261660544,
     0.2349262936, 0.2441133942, 0.2537062323, 0.2636863451, 0.2740376092, 0.2847459955, 0.2957993818, 0.3071874097,
     0.3189013744, 0.3309341418, 0.3432800834, 0.3559350278, 0.368896223, 0.3821623073, 0.3957332875, 0.4096105218,
     0.4237967071, 0.4382958688, 0.4531133538, 0.4682558246, 0.483731256, 0.4995489323, 0.5157194466, 0.5322547005,
     0.549167906, 0.5664735878, 0.5841875876, 0.6023270691, 0.6209105252, 0.6399577862, 0.6594900305, 0.6795297957,
     0.7001009936, 0.7212289252, 0.7429402995, 0.7652632533, 0.7882273745, 0.8118637266, 0.8362048764, 0.8612849246,
     0.8871395381, 0.913805986, 0.9413231776, 0.9697317035, 0.99907388, 1.029393796, 1.0607373625, 1.0931523662,
     1.1266885249, 1.1613975472, 1.1973331941, 1.2345513447, 1.2731100644, 1.3130696767, 1.3544928382, 1.3974446162,
     1.4419925702, 1.4882068365, 1.5361602152, 1.5859282619, 1.6375893813, 1.6912249245, 1.7469192892, 1.8047600238,
     1.8648379336, 1.9272471906, 1.9920854462, 2.0594539469, 2.1294576528, 2.2022053588, 2.2778098186, 2.3563878714,
     2.4380605705, 2.5229533148, 2.6111959817, 2.702923063, 2.7982738011, 2.897392328, 3.000427804, 3.1075345593,
     3.218872234, 3.3346059198, 3.4549063009, 3.5799497948, 3.709918691, 3.8450012896, 3.9853920363, 4.1312916558,
     4.2829072813, 4.4404525801, 4.6041478744, 4.7742202567, 4.9509036985, 5.134439152, 5.3250746438, 5.5230653585,
     5.728673713, 5.9421694191, 6.1638295332, 6.3939384928, 6.6327881373, 6.8806777138, 7.1379138633, 7.4048105897,
     7.6816892069, 7.9688782652, 8.266713453, 8.5755374748, 8.8956999019, 9.2275569959, 9.5714715023, 9.927812414,
     10.296954702, 10.6792790132, 11.0751713331, 11.4850226129, 11.9092283598, 12.3481881894, 12.8023053398,
     13.2719861468, 13.7576394791, 14.2596761352, 14.7785082, 15.3145483628, 15.8682091977, 16.4399024059,
     17.0300380225, 17.6390235898])

gold_absorption = array(
    [1.9859165645, 1.9753477923, 1.9659777786, 1.9585371853, 1.9534747986, 1.9509205495, 1.9506797942, 1.9522622682,
     1.9549427281, 1.9578442088, 1.9600311228, 1.9605992287, 1.9587524104, 1.9538608396, 1.9454998604, 1.9334727808,
     1.9178232127, 1.8988434893, 1.8770847023, 1.8533704822, 1.8288102492, 1.8047984931, 1.7829765227, 1.7651262926,
     1.7529693573, 1.7478663143, 1.7504582283, 1.7603512156, 1.7759826166, 1.7947745423, 1.8135693006, 1.8292161791,
     1.8391292723, 1.8416845654, 1.8364165148, 1.824046326, 1.8064036105, 1.7863003221, 1.7673956537, 1.7540572953,
     1.7511719833, 1.7637847158, 1.7963979969, 1.8518919228, 1.9304677151, 2.0294158426, 2.1440829091, 2.2693910627,
     2.400972842, 2.5355999192, 2.6711277547, 2.8062568867, 2.9402833086, 3.0728980896, 3.204042941, 3.3338114301,
     3.4623834285, 3.5899826181, 3.7168496361, 3.8432256893, 3.9693430957, 4.0954203379, 4.2216599933, 4.3482484372,
     4.4753565835, 4.6031411808, 4.7317463551, 4.8613052076, 4.9919413569, 5.1237703632, 5.2569010096, 5.3914364314,
     5.5274750988, 5.6651116655, 5.8044376944, 5.9455422781, 6.0885125664, 6.2334342138, 6.3803917599, 6.5294689524,
     6.6807490205, 6.8343149079, 6.9902494705, 7.1486356453, 7.3095565942, 7.4730958275, 7.63933731, 7.8083655521,
     7.9802656895, 8.1551235526, 8.3330257273, 8.5140596094, 8.6983134531, 8.8858764151, 9.0768385951, 9.2712910733,
     9.4693259459, 9.6710363584, 9.876516538, 10.085861825, 10.2991687034, 10.5165348313, 10.7380590705, 10.9638415166,
     11.1939835286, 11.4285877588, 11.6677581822, 11.9116001269, 12.1602203034, 12.4137268346, 12.6722292853,
     12.9358386922, 13.2046675927, 13.4788300544, 13.7584417033, 14.0436197522, 14.3344830281, 14.6311519989,
     14.9337487993, 15.242397256, 15.557222911, 15.8783530446, 16.205916696, 16.5400446837, 16.8808696226,
     17.2285259404, 17.5831498916, 17.9448795695, 18.3138549153, 18.6902177253, 19.0741116548, 19.4656822198,
     19.8650767947, 20.2724446074, 20.6879367303, 21.1117060677, 21.5439073394, 21.9846970594, 22.4342335112,
     22.8926767167, 23.3601884018, 23.8369319549, 24.3230723814, 24.818776251, 25.3242116392, 25.8395480625,
     26.3649564062, 26.9006088451, 27.4466787567, 28.0033406265, 28.5707699445, 29.1491430937, 29.738637229,
     30.3394301469, 30.9517001453, 31.5756258729, 32.2113861689, 32.8591598904, 33.5191257296, 34.191462019,
     34.8763465244, 35.5739562259, 36.2844670861, 37.0080538055, 37.7448895647, 38.4951457535, 39.2589916857,
     40.0365943015, 40.8281178548, 41.633723588, 42.4535693921, 43.2878094535, 44.1365938879, 45.0000683603,
     45.8783736927, 46.7716454592, 47.6800135698, 48.6036018426, 49.5425275664, 50.4969010538, 51.4668251858,
     52.4523949503, 53.4536969744, 54.4708090531, 55.5037996756, 56.5527275519, 57.6176411403, 58.6985781795,
     59.7955652274, 60.9086172084, 62.0377369732, 63.1829148725, 64.3441283502, 65.5213415561, 66.7145049842,
     67.923555139, 69.1484142333, 70.388989921, 71.6451750702, 72.9168475779])

gold_n = InterpolatedSF(gold_wavelength, gold_index)
gold_k = InterpolatedSF(gold_wavelength, gold_absorption)


cdef class Conductor(Material):

    def __init__(self, SpectralFunction index, SpectralFunction extinction):

        self.index = index
        self.extinction = extinction

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef Spectrum evaluate_surface(self, World world, Ray ray, Primitive primitive, Point hit_point,
                                    bint exiting, Point inside_point, Point outside_point,
                                    Normal normal, AffineMatrix to_local, AffineMatrix to_world):

        cdef:
            Vector incident, reflected
            double temp, ci
            ndarray n, k, reflection_coefficient
            Ray reflected_ray
            Spectrum spectrum
            double[::1] s_view, n_view, k_view
            int i

        # convert ray direction normal to local coordinates
        incident = ray.direction.transform(to_local)

        # ensure vectors are normalised for reflection calculation
        incident = incident.normalise()
        normal = normal.normalise()

        # calculate cosine of angle between incident and normal
        ci = normal.dot(incident)

        # sample refractive index and absorption
        n = self.index.sample_multiple(ray.get_min_wavelength(), ray.get_max_wavelength(), ray.get_num_samples())
        k = self.extinction.sample_multiple(ray.get_min_wavelength(), ray.get_max_wavelength(), ray.get_num_samples())

        # reflection
        temp = 2 * ci
        reflected = new_vector(incident.x - temp * normal.x,
                               incident.y - temp * normal.y,
                               incident.z - temp * normal.z)

        # convert reflected ray direction to world space
        reflected = reflected.transform(to_world)

        # spawn reflected ray and trace
        # note, we do not use the supplied exiting parameter as the normal is
        # not guaranteed to be perpendicular to the surface for meshes
        if ci > 0.0:

            # incident ray is pointing out of surface, reflection is therefore inside
            reflected_ray = ray.spawn_daughter(inside_point.transform(to_world), reflected)

        else:

            # incident ray is pointing in to surface, reflection is therefore outside
            reflected_ray = ray.spawn_daughter(outside_point.transform(to_world), reflected)

        spectrum = reflected_ray.trace(world)

        # calculate reflection coefficients at each wavelength and apply
        ci = fabs(ci)
        s_view = spectrum.samples
        n_view = n
        k_view = k
        for i in range(spectrum.num_samples):
            s_view[i] *= self._fresnel(ci, n_view[i], k_view[i])

        return spectrum

    @cython.cdivision(True)
    cdef inline double _fresnel(self, double ci, double n, double k) nogil:

        cdef double c12, k0, k1, k2, k3

        ci2 = ci * ci
        k0 = n * n + k * k
        k1 = k0 * ci2 + 1
        k2 = 2 * n * ci
        k3 = k0 + ci2

        return 0.5 * ((k1 - k2) / (k1 + k2) + (k3 - k2) / (k3 + k2))


    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef Spectrum evaluate_volume(self, Spectrum spectrum, World world,
                                   Ray ray, Primitive primitive,
                                   Point start_point, Point end_point,
                                   AffineMatrix to_local, AffineMatrix to_world):

        # do nothing!
        # TODO: make it solid - return black?
        return spectrum
