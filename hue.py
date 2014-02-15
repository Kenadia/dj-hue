import json
import random
import requests
import threading
import time


### ------ CONSTANTS ------ ###


url = 'http://192.168.1.134/api/1234567890/'
light_ids = [1, 2, 3]
all = light_ids
red = [6.7500E-01, 3.2200E-01]
yellow = [5.4200E-01, 4.2000E-01]
lime = [4.0900E-01, 5.1800E-01]
pale = [2.8800E-01, 2.7900E-01]
blue = [1.6700E-01, 4.0000E-02]
pink = [4.2100E-01, 1.8100E-01]
violet = [2.75E-01, 1E-01]
rainbow = [red, yellow, lime, blue, pink]
# HSB
bright_red = [62630, 124, 254]
low_red = [62630, 255, 50]
rainbow2 = [[64000, 255, 255],
           [47000, 255, 255],
           [20500, 255, 1],
           [51000, 255, 255],
           [48000, 255, 255]]

### ------ QUERIES ------ ###
# Function get_state is used internally to query data.
# Functions get, get_hsb are used to print info.


def tuplify(lights):
    if not isinstance(lights, (list, tuple)):
        return (lights,)
    return lights


def get_state(light_id):
    r = requests.get(url + 'lights/%d' % light_id)
    return json.loads(r.text)['state']


def get(lights=all):
    lights = tuplify(lights)
    for i in lights:
        print "%d:" % i, json.dumps(get_state(i), indent=2)


def get_hsb(lights=all):
    lights = tuplify(lights)
    for i in lights:
        s = get_state(i)
        print 'H: %d\tS: %d\tB: %d' % (s['hue'], s['sat'], s['bri'])


### ------ CONTROLS ------ ###
# put is used internally to send data.
# set turns lights on, and can set color by xy or hsb.
# hsb sets hsb values.
# boost sets brightness, defaulting to full.
# off turns lights off and stops sequences.


def put(lights, data):
    # data['transitiontime'] = 0
    lights = tuplify(lights)
    for i in lights:
        requests.put(url + 'lights/%d/state' % i, data=json.dumps(data))


def set(lights=all, color=None, hue=None, sat=None, bri=None):
    data = {
        'on': True,
        'xy': color if color and len(color) == 2 else None,
        'hue': color[0] if color and len(color) == 3 else hue,
        'sat': color[1] if color and len(color) == 3 else sat,
        'bri': color[2] if color and len(color) == 3 else bri}
    put(lights, data)
on = set


def off(lights=all):
    stop()
    put(lights, {'on': False})


def boost(lights=all, bri=255):
    set(lights, bri=bri)


# r is the distance of the interpolated color between two source colors
def interpolate(colors, r):
    rr = 1 - r
    new_color = [rr * colors[0][0] + r * colors[1][0],
                 rr * colors[0][1] + r * colors[1][1]]
    if len(colors[0]) == 2:
        return new_color
    else:
        return map(int,
                   new_color + [rr * colors[0][2] + r * colors[1][2]])


def rand_color(source=None, hue=None, sat=None, bri=None):
    if source:
        return interpolate(source, random.random())
    else:
        return [(random.randint(hue[0], hue[2]) if len(hue) == 2 else hue)
                if hue else int(random.random() * 65536),
                (random.randint(sat[0], sat[2]) if len(sat) == 2 else sat)
                if sat else int(random.random() * 256),
                (random.randint(bri[0], bri[2]) if len(bri) == 2 else bri)
                if bri else int(random.random() * 256)
                ]


### ------ SEQUENCES ------ ###
# Internal functions used to define sequences


def sequence(lights, bri, gen_light, stagger=0.0):
    global seqs
    stop(lights)
    boost(lights, bri)
    for i in tuplify(lights):
        seqs[i] = gen_light(i)
    start(lights)


def seqlight(init, step, rate, finish=None):
    params = {'active': False}
    init(params)

    def start(offset):
        if not params['active']:
            params['active'] = True
            threading.Timer(offset, loop).start()

    def loop():
        if not params['active']:
            return
        step(params)
        threading.Timer(rate, loop).start()

    def stop():
        params['active'] = False
        if finish:
            finish()

    def mod(new_params):
        for k, v in new_params.iteritems():
            if not k == 'active':
                params[k] = v

    return {'start': start, 'stop': stop, 'mod': mod}


def start(lights=all, stagger=0.0):
    lights = tuplify(lights)
    for i in lights:
        seqs[i]['start'](stagger)


def stop(lights=all):
    lights = tuplify(lights)
    for i in lights:
        if i in seqs:
            seqs[i]['stop']()
seqs = {}


### ------ STATIC ------ ###
# warm is a preset with an optional boost parameter


def warm(boost=0):
    set(1, [5000, 255, 1 + boost])
    set(2, [0, 255, 50 + boost])
    set(3, [9600, 255, 1 + boost])


def light():
    put(1, {'on': True, 'ct': 346, 'bri': 255})
    put(2, {'on': True, 'ct': 384, 'bri': 255})
    put(3, {'on': True, 'ct': 319, 'bri': 255})


### ------ DYNAMIC ------ ###
# strobe
# rave takes four optional params: lights, bri, delay, stagger
# club takes four optional params: lights, bri, p, line


def strobelight(light_id, high, delay):

    def init(params):
        params['high'] = False

    def step(params):
        set(light_id, bri=(high if params['high'] else 0))
        params['high'] = not params['high']

    return seqlight(init, step, delay)


def clublight(light_id, p, line):

    def init(params):
        None

    def step(params):
        if random.random() < p:
            set(light_id, rand_color(line))

    return seqlight(init, step, 0.25)


def pulselight(light_id, delay, spectrum, offset=0):

    def init(params):
        params['color'] = offset

    def step(params):
        color = params['color']
        set(light_id, spectrum[color])
        params['color'] = (color + 1) % len(spectrum)

    return seqlight(init, step, delay)


# Pulses lights in their current colors
# def strobe(lights=all, high=255, delay=0.45, stagger=0):
#     sequence(lights, 0, lambda (i): strobelight(i, high, delay), stagger)


# Lights shift randomly.
# A line of two color points can be specified as the source for colors.
def club(lights=all, bri=255, p=0.25, line=None):
    sequence(lights, bri, lambda (i): clublight(i, p, line))


# Lights cycle rapidly through the rainbow.
# Lights are divided evenly along the spectrum.
def rave(lights=all, bri=255, delay=0.25, stagger=None, colors=rainbow):
    stagger = stagger if stagger \
        else len(rainbow) * float(delay) / len(light_ids)
    sequence(lights, bri, lambda (i): pulselight(i, delay, colors), stagger)


# Lights cycle smoothly between the specified colors.
# The factor is the number of colors to interpolate per color specified.
# Lights are divided evenly along the spectrum.
def slow(lights=all, bri=255, factor=25, colors=rainbow):
    colors.append(colors[0])
    spectrum = []
    for i in xrange(len(colors) - 1):
        start = colors[i]
        end = colors[i + 1]
        for j in xrange(factor):
            spectrum.append(interpolate((start, end), float(j) / factor))
    spacing = float(len(spectrum)) / len(lights) \
        if isinstance(lights, (list, tuple)) else 0
    sequence(lights, bri,
             lambda (i): pulselight(i, 0.25, spectrum, int((i - 1) * spacing)))


### ------ LIGHTS AND MUSIC ------ ###


def n_set(lights=all, color=None, hue=None, sat=None, bri=None, t=0):
    data = {
        'on': True,
        'xy': color if color and len(color) == 2 else None,
        'hue': color[0] if color and len(color) == 3 else hue,
        'sat': color[1] if color and len(color) == 3 else sat,
        'bri': color[2] if color and len(color) == 3 else bri,
        'transitiontime': t}
    # print "Sent", data
    put(lights, data)


# def stars(level, colors, strobe=False, measure=0):

#     def stars_inner(playlist, next, bpm):
#         state = {'id': 1, 'count': 0 - measure}
#         limit = 64 / 2 ** (2 - level)
#         if strobe:
#             limit += 7

#         def stars_inner2():
#             L = state['id']
#             if state['count'] >= 56:
#                 if strobe:
#                     if state['count'] == 56:
#                         put((2, 3), {'on': False, 'transitiontime': 0})
#                     put(1, {'on': True, 'xy': pale,
#                             'bri': 255, 'transitiontime': 0})
#                     put(1, {'on': False, 'transitiontime': 0})
#             else:
#                 n_set(L, rand_color(source=colors), bri=255)
#                 n_set(L, bri=0, t=(10 if level < 2 else 7))
#                 new_L = random.randint(1, 2)
#                 state['id'] = L + 1 if L == new_L else new_L
#             state['count'] += 1
#             # -----
#             delay = 30.0 / bpm * 2 ** (2 - level)
#             if strobe and state['count'] >= 56:
#                 delay = 15.0 / bpm
#             if state['count'] == limit:
#                 threading.Timer(delay,
#                                 lambda: playlist[next]
#                                 (playlist, next + 1, bpm)).start()
#                 return
#             # -----
#             if random.random() < 0.5 and state['count'] != limit - 1:
#                 state['count'] += 1
#                 delay *= 2
#             threading.Timer(delay, stars_inner2).start()
#         stars_inner2()
#     return stars_inner


# def down(level, colors, select, reverse=False, measure=0):
#     def down_inner(playlist, next, bpm):
#         state = {'count': 0 - measure}
#         limit = 64 / 2 ** (2 - level)
#         for i in [1, 2, 3]:
#             if i != select:
#                 put(i, {'on': False})

#         def down_inner2():
#             progress = float(state['count']) / limit
#             c = interpolate(colors, progress)
#             br = int(200 * progress + 56)
#             if reverse:
#                 n_set(select, bri=0)
#                 n_set(select, c, bri=br, t=(4 if level < 2 else 1))
#             if not reverse:
#                 n_set(select, c, bri=br)
#                 n_set(select, bri=0, t=(4 if level < 2 else 1))
#             state['count'] += 1
#             # -----
#             delay = 30.0 / bpm * 2 ** (2 - level)
#             if state['count'] == limit:
#                 threading.Timer(delay,
#                                 lambda: playlist[next]
#                                 (playlist, next + 1, bpm)).start()
#                 return
#             # -----
#             threading.Timer(delay, down_inner2).start()
#         down_inner2()
#     return down_inner


# def dance(colors, reverse=False):
#     def dance_inner(playlist, next, bpm):
#         put(all, {'on': False, 'transitiontime': 0})
#         state = {'id': 1, 'count': 0}
#         limit = 124

#         def dance_inner2():
#             L = state['id']
#             if state['count'] % 4 == 3:
#                 if reverse:
#                     state['id'] = ((L + 1) % 3) + 1
#                 else:
#                     state['id'] = (L % 3) + 1
#             else:
#                 n_set(L, rand_color(source=colors), bri=255)
#                 put(L, {'on': False, 'transitiontime': 0})
#             state['count'] += 1
#             # -----
#             delay = 15.0 / bpm
#             if state['count'] == limit:
#                 threading.Timer(delay,
#                                 lambda: playlist[next]
#                                 (playlist, next + 1, bpm)).start()
#                 return
#             # -----
#             threading.Timer(delay, dance_inner2).start()
#         dance_inner2()
#     return dance_inner


def music(bpm, playlist):

    # Init
    put(all, {'on': False, 'bri': 0, 'transitiontime': 0})
    state = {'active': False}

    def start():
        if not state['active']:
            state['active'] = True
            threading.Timer(0, loop).start()

    def stop():
        state['active'] = False

    def loop():
        if not state['active']:
            return
        playlist[0](playlist, 1, bpm)

    def end(ignore1=None, ignore2=None, ignore3=None):
        pass
    playlist.append(end)

    # def start_strobe():
    #     put(state['cur']['left']['id'],
    #         {'on': False, 'transitiontime': 0})
    #     put(state['cur']['right']['id'],
    #         {'on': False, 'transitiontime': 0})
    #     strobe_loop()

    # def strobe_loop():
    #     if not state['active']:
    #         return
    #     # where the magic happens
    #     cur = state['cur']
    #     light = cur['id']
    #     put(light, {'on': True, 'xy': pale,
    #                 'bri': 255, 'transitiontime': 0})
    #     put(light, {'on': False, 'transitiontime': 0})
    #     # -----
    #     print state['strobe_count']
    #     if state['strobe_count'] == 16:
    #         state['strobe_count'] = 0
    #         state['cur'] = \
    #             cur['left' if random.random() < 0.5 else 'right']
    #         delay = 60.0 / bpm
    #         loop()
    #     else:
    #         state['strobe_count'] += 1
    #         delay = 15.0 / bpm
    #         threading.Timer(delay, strobe_loop).start()

    return {'start': start, 'stop': stop}


### ------ LIGHTS AND MUSIC VERSION 2 ------ ###


def wait():
    pass


def cur_time():
    return time.time()


def new_seq(bpm, sub, speed_factor, limit, params=None):
    delay = 60.0 / bpm / speed_factor  # Seconds per beat

    def seq(start):
        count = 0
        while True:
            sub(count, params)
            count += 1
            if count == limit:
                start += delay
                while cur_time() < start:
                    wait()
                return start
            else:
                start += delay
                while cur_time() < start:
                    wait()

    return seq


def black():
    speed_factor = 1000000000
    limit = 1

    def sub(count, params):
        put(all, {'on': False, 'transitiontime': 0})
    return new_seq(60, sub, speed_factor, limit)


def stars(bpm, level, colors, measure=1.0):
    transition = 10 - 2 * level
    speed_factor = 2.0 ** (level - 1)
    limit = int(32 * measure * speed_factor)
    params = {'light': 1, 'skipped_last': False}

    def sub(count, params):
        if count == limit - 1 or params['skipped_last'] \
                or random.random() < 0.5:
            params['skipped_last'] = False
            light = params['light']
            n_set(light, rand_color(source=colors), bri=255)
            n_set(light, bri=0, t=transition)
            new_light = random.randint(1, 2)
            params['light'] = light + 1 if light == new_light else new_light
        else:
            params['skipped_last'] = True
    return new_seq(bpm, sub, speed_factor, limit, params)


def down(bpm, level, colors, measure=1.0, select=1, reverse=False):
    transition = 2 ** (2 - level) * 4
    speed_factor = 2.0 ** (level - 2)
    limit = int(32 * measure * speed_factor)

    def sub(count, params):
        progress = float(count) / limit
        c = interpolate(colors, progress)
        br = int(200 * progress + 56)
        if reverse:
            n_set(select, bri=0)
            n_set(select, c, bri=br, t=transition)
        else:
            n_set(select, c, bri=br)
            n_set(select, bri=0, t=transition)
    return new_seq(bpm, sub, speed_factor, limit)


def down2(bpm, level, colors, measure=1.0, select=1, reverse=False):
    transition = 2 ** (2 - level) * 4
    speed_factor = 2.0 ** (level - 2)
    limit = int(32 * measure * speed_factor)
    other = [i for i in all if i != select]

    def sub(count, params):
        progress = float(count) / limit
        c = interpolate(colors, progress)
        br = int(200 * progress + 56)
        if reverse:
            n_set(select, bri=0)
            n_set(select, c, bri=br, t=transition)
        else:
            n_set(select, c, bri=br)
            n_set(select, bri=0, t=transition)
        put(other[0], {'on': True, 'xy': pale,
                       'bri': 255, 'transitiontime': 0})
        put(other[0], {'on': False, 'transitiontime': 0})
        other.reverse()
    return new_seq(bpm, sub, speed_factor, limit)


def dance(bpm, colors, measure=1.0, reverse=False):
    speed_factor = 4
    limit = int(32 * measure * speed_factor)
    params = {'light': 1}

    def sub(count, params):
        light = params['light']
        if count % 4 == 3:
            if reverse:
                new_light = ((light + 1) % 3) + 1
            else:
                new_light = (light % 3) + 1
            params['light'] = new_light
        else:
            n_set(light, rand_color(source=colors), bri=255)
            put(light, {'on': False, 'transitiontime': 0})
    return new_seq(bpm, sub, speed_factor, limit, params)


def dance2(bpm, colors, measure=1.0, reverse=False):
    speed_factor = 4
    limit = int(32 * measure * speed_factor)
    params = {'light': 1}

    def sub(count, params):
        light = params['light']
        if reverse:
            new_light = ((light + 1) % 3) + 1
        else:
            new_light = (light % 3) + 1
        params['light'] = new_light
        n_set(light, rand_color(), bri=255)
        put(light, {'on': False, 'transitiontime': 0})
    return new_seq(bpm, sub, speed_factor, limit, params)


def strobe(bpm, measure, select):
    speed_factor = 4
    limit = int(32 * measure * speed_factor)
    put(all, {'on': False})

    def sub(count, params):
        put(select, {'on': True, 'xy': pale,
                     'bri': 255, 'transitiontime': 0})
        put(select, {'on': False, 'transitiontime': 0})
    return new_seq(bpm, sub, speed_factor, limit)


def play(song):
    playlist = song()
    start = cur_time()
    for seq in playlist:
        start = seq(start)


def jam():
    start = cur_time()
    bpm = 120
    while True:
        r = random.random()
        sp = 2 if random.random() < 0.75 else 1
        if r < 0.03:
            a = dance(bpm, [pale, pale])
        elif r < 0.08:
            a = dance2(bpm, None)
        elif r < 0.14:
            a = down2(bpm, sp, [blue, blue], select=1, reverse=True)
        elif r < 0.20:
            a = down2(bpm, sp, [yellow, red], select=1, reverse=True)
        elif r < 0.30:
            a = stars(bpm, sp, [red, yellow])
        elif r < 0.40:
            a = stars(bpm, sp, [red, pink])
        elif r < 0.50:
            a = stars(bpm, sp, [red, blue])
        elif r < 0.60:
            a = stars(bpm, sp, [blue, lime])
        elif r < 0.70:
            a = stars(bpm, sp, [blue, violet])
        elif r < 0.80:
            a = stars(bpm, sp, [blue, pink])
        elif r < 0.90:
            a = stars(bpm, sp, [blue, red])
        else:
            a = stars(bpm, sp, [lime, yellow])
        start = a(start)


### ------ PLAYLISTS ------ ###


test = [black(),
        dance(120, [pale, pale]),
        stars(120, 1, [yellow, red]),
        down(120, 1, [blue, blue], select=3),
        down(120, 2, [yellow, red], select=3),
        black()]


# Latch
def latch():
    bpm = 122
    return [black(),
            # off by a beat?
            down(bpm, 1, [blue, red], select=3),
            stars(bpm, 1, [pink, blue]),
            stars(bpm, 2, [yellow, red]),
            down(bpm, 1, [yellow, blue], select=1),
            down(bpm, 2, [yellow, red], select=1),
            dance(bpm, [pink, red]),
            dance(bpm, [violet, blue], reverse=True),
            stars(bpm, 2, [red, blue]),
            stars(bpm, 2, [blue, violet]),
            down(bpm, 1, [lime, yellow], select=1),
            black(),
            down(bpm, 0, [blue, blue], select=2, reverse=True),
            black(),
            down(bpm, 2, [yellow, red], select=3),
            dance(bpm, [pale, pale]),
            stars(bpm, 2, [yellow, violet]),
            stars(bpm, 1, [blue, violet]),
            stars(bpm, 1, [blue, red]),
            black()]


# Set It Off
def setitoff():
    bpm = 108
    return [black(),
            stars(bpm, 0, [lime, yellow]),
            stars(bpm, 1, [yellow, red]),
            stars(bpm, 2, [red, pink], 1.125),  #
            dance(bpm, [blue, blue]),
            dance(bpm, [violet, violet], 0.5, reverse=True),
            dance2(bpm, [violet, violet], 0.5, reverse=True),
            stars(bpm, 1, [blue, violet]),
            stars(bpm, 2, [blue, red]),  #
            black(),
            down(bpm, 2, [violet, red], select=1),
            black(),
            down2(bpm, 2, [red, blue], 0.5, select=1, reverse=True),
            stars(bpm, 2, [blue, blue]),
            stars(bpm, 1, [blue, lime]),
            stars(bpm, 1, [lime, yellow], 1.0625),
            black()]


# Baby's On Fire
def baby():
    bpm = 130
    return [black(),
            stars(bpm, 2, [red, yellow]),
            # strobe(bpm, 0.125, 1),
            # down(bpm, 1, [red, red], select=1, reverse=True),
            #
            stars(bpm, 1, [yellow, pale], 0.5),
            stars(bpm, 2, [red, pink]),
            stars(bpm, 2, [red, yellow]),
            black(),
            down(bpm, 1, [red, red], select=1, reverse=True),
            black(),
            dance2(bpm, [pale, pale]),
            down2(bpm, 1, [lime, blue], 0.75, select=3),
            stars(bpm, 2, [blue, pink]),
            stars(bpm, 1, [pink, red]),
            stars(bpm, 2, [red, yellow]),
            # strobe(bpm, 0.125, 1),
            black(),
            down(bpm, 2, [yellow, red], 1.75, select=3, reverse=True),
            black(),
            stars(bpm, 1, [red, red]),
            black(),
            down(bpm, 1, [yellow, red], select=1, reverse=True),
            black(),
            stars(bpm, 2, [blue, pink]),
            # strobe(bpm, 0.125, 1),
            dance(bpm, [red, red], reverse=True),
            stars(bpm, 2, [yellow, red]),
            black()]
