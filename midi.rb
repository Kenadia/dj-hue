$:.unshift File.dirname(__FILE__)

require 'unimidi'
require './tf-control'
require "net/http"


class Controller

    PORT = 80
    URL = "http://192.168.1.134/api/1234567890/"
    @http = Net::HTTP.new(URL, PORT)

    BULB_COUNT = 3
    THROTTLE = 200  # ms

    MAX_HUE = 65535
    MAX_SATURATION = 254
    MAX_BRIGHTNESS = 255


    # Simple fucking Hue
    def put(id, data)
        print "put (#{id}) #{data}\n"
        # response = @http.send_request('PUT', "/lights/#{id}/state", data.to_json)
    end

    def send_pulse(ids, color, t)
        tenths = (t * 10).to_i
        if color
            ids.each do |id|
                Thread.new {
                    put(id, {hue: color[0], sat: color[1], bri: 255, transitiontime: tenths})
                    sleep t
                    put(id, {bri: 0, transitiontime: tenths})
                }
            end
        else
            ids.each do |id|
                Thread.new {
                    put(id, {bri: 255, transitiontime: tenths})
                    sleep t
                    put(id, {bri: 0, transitiontime: tenths})
                }
            end
        end
    end

    def set_param(ids, param, value)
        ids.each do |id|
            data = {transitiontime: THROTTLE / 100}
            data[param] = value
            put(id, data)
        end
    end

    def init_lights()
        for i in 0..BULB_COUNT-1
            put(i, {hue: 0, sat: 255, bri: 0, on: true})
        end
    end

    def init_controller()
        case UniMIDI::Input.all.length
        when 0
            abort("Cannot find a MIDI controller, aborting")
        when 1
            @input = UniMIDI::Input.first.open
            puts "MIDI controller found: #{@input.pretty_name}"
        else
            @input = UniMIDI::Input.gets
        end
    end

    def initialize

        init_lights()
        init_controller()

        # Controls and actions
        @control_names = []
        (0..15).each{|i| @control_names.push("button_#{i}")}
        (0..3).each{|i| @control_names.push("slider_#{i}")}
        (0..7).each{|i| @control_names.push("knob_#{i}")}
        @control_actions = Hash.new

        @last_midi_input = Hash.new

        # Regexes
        @pulse_regex = /^\s*(\d(?:,\d)*|all)\s+(pulse|flash)(?:\s+(red|green|blue|#[0-9a-fA-F]{6}))?\s*$/
        @level_regex = /^\s*(\d(?:,\d)*|all)\s+(h|s|b|H|S|B|hue|sat|bri|saturation|brightness)\s*$/

    end

    def parse_ids(s)
        return (s == "all" && (1..BULB_COUNT).to_a) || s.split(",").map(&:to_i)
    end

    # Parses a hex or word and returns hsb.
    def parse_color(s)
        if s && s[0] == "#"
            m = s.match /#(..)(..)(..)/
            if m != nil
                r, g, b = m[1].hex, m[2].hex, m[3].hex
                max = [r, g, b].max
                min = [r, g, b].min
                h, s, l = 0, 0, ((max + min) / 2 * 255)
                d = max - min
                s = max == 0? 0 : (d / max * 255)
                h = case max
                when min
                    0
                when r
                    (g - b) / d + (g < b ? 6 : 0)
                when g
                    (b - r) / d + 2
                when b
                    (r - g) / d + 4
                end * 60
                [(h * 65536.0 / 360).to_i, s, l]
            end
        else
            case s
            when "red"
                [0, 255, 255]
            when "green"
                [26214, 255, 255]
            when "blue"
                [45875, 255, 255]
            end
        end
    end

    def parse_action(action, value)
        print "execute\taction #{action}\tvalue #{value}\n"
        if pulse = @pulse_regex.match(action)
            light_ids = parse_ids(pulse.captures[0])
            t = (pulse.captures[1][0] == "p" && 0.3) || 0
            color = parse_color(pulse.captures[2])
            print "Pulse color #{color}.\n"
            send_pulse(light_ids, color, t)
        elsif level = @level_regex.match(action)
            light_ids = parse_ids(level.captures[0])
            case level.captures[1][0]
            when "h"
                param = "hue"
            when "s"
                param = "sat"
            when "b"
                param = "bri"
            end
            # print "Level change #{param} #{value}.\n"
            set_param(light_ids, param, value)
        else
            # print "Invalid action.\n"
        end
    end

    def get_control_names()
        return @control_names
    end

    def change_control_mode(name, action)
        # print "registered\tname #{name}\taction #{action}\n"
        @control_actions[name] = action
    end

    def midi_hue_loop()
        print "Listening for MIDI input...\n"
        loop do
            
            # Parse MIDI data from Trigger Finger
            input = @input.gets[0]
            data, t = input[:data], input[:timestamp]
            type, id, value = data
            if !@last_midi_input[id] || t - @last_midi_input[id] > THROTTLE
                @last_midi_input[id] = t
                control = TFControl.new(type, id, value)
                if control and control.id
                    # print "#{control.kind}_#{control.id} (#{control.value})\n"
                    parse_action(@control_actions["#{control.kind}_#{control.id}"], control.percentage)
                end
            end

        end
    end
end