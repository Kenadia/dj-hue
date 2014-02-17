$:.unshift File.dirname(__FILE__)

require 'json'
require 'unimidi'
require './tf-control'
require './nk-control'
require "net/http"
require 'rest_client'

class Controller

    # PORT = 80
    # HOST = '10.136.210.117'
    # PATH = 'api/newdeveloper/'
    # @http = Net::HTTP.new(URL, PORT)

    BULB_COUNT = 3
    THROTTLE = 200  # ms
    STROBE_MAX = 300

    MAX_HUE = 65535
    MAX_SATURATION = 254
    MAX_BRIGHTNESS = 255

    URL1 = :'http://10.214.59.124/api/1234567890/lights/1/state'

    URL2 = :'http://10.214.59.124/api/1234567890/lights/2/state'

    URL3 = :'http://10.214.59.124/api/1234567890/lights/3/state'


    # Simple fucking Hue
    def put(id, data)

        case id
        when 1
            RestClient.put URL1, data.to_json, {:content_type => :json}
        when 2
            RestClient.put URL2, data.to_json, {:content_type => :json}
        when 3
            RestClient.put URL3, data.to_json, {:content_type => :json}
        end

        print "put (#{id}) #{data}\n"
        # req = Net::HTTP::Put.new("#{PATH}/lights/#{id}/state", initheader = {'Content-Type' => 'text/json'})
        # req.body = data.to_json
        # response = Net::HTTP.new(HOST, PORT).start {|http| http.request(req)}
        # puts response.code
        # response = @http.send_request('PUT', "/lights/#{id}/state", data.to_json)
    end

    def set_on(ids)
        ids.each do |id|
            put(id, {on: true})
        end
    end

    def set_off(ids)
        ids.each do |id|
            put(id, {on: false})
        end
    end

    def start_strobe(ids, color, rate)
        print "strobe with rate #{rate}\n"
        ids.each do |id|
            if @seq_key && (k = @seq_key[id])
                @seq_hash[k] = false  # stop current thread running on this light
            end
            if not @seq_key
                @seq_key = {}
                @seq_hash = {}
                @seq_rate = {}
            end
            @seq_key[id] = (r = rand())
            @seq_hash[r] = true
            @seq_rate[r] = rate
            Thread.new {
                while @seq_hash[r]
                    if color
                        put(id, {hue: color[0], sat: color[1], bri: 255, transitiontime: 0})
                        put(id, {bri: 0, transitiontime: 0})
                    else
                        put(id, {bri: 255, transitiontime: 0})
                        put(id, {bri: 0, transitiontime: 0})
                    end
                    sleep 60 / @seq_rate[r].to_f
                end
            }
        end
    end

    def strobe_rate(ids, color, rate)
        print "modifying strobe with rate #{rate}\n"
        ids.each do |id|
            if !@seq_key || !@seq_key[id] || @seq_rate[@seq_key[id]] < 10
                start_strobe([id], color, rate)
            else
                @seq_rate[@seq_key[id]] = rate
            end
        end
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

    def set_color(ids, color)
        ids.each do |id|
            put(id, {hue: color[0], sat: color[1]})
        end
    end

    def interpolate(colors, r)
        rr = 1 - r
        [rr * colors[0][0] + r * colors[1][0],
         rr * colors[0][1] + r * colors[1][1],
         255].map(&:to_i)
    end

    def random(source)
        if source
            interpolate(source, rand())
        else
            [rand() * 65536, rand() * 255, 255].map(&:to_i)
        end
    end

    def set_param(ids, param, value)
        ids.each do |id|
            data = {transitiontime: THROTTLE / 100}
            if param == "hue"
                data[param] = (value * 65536).to_i
            else
                data[param] = (value * 255).to_i
            end
            put(id, data)
        end
    end

    def init_lights()
        for i in 1..BULB_COUNT
            put(i, {hue: 0, sat: 255, bri: 0, on: true})
        end
    end

    def available_controllers()
        @inputs = UniMIDI::Input.all
        devices = @inputs[1..@inputs.length-1]
        if devices
            devices.map{ |i| i.pretty_name[3]}
        end
    end


    #     devices = UniMIDI::Input.all
    #     if devices.length >= 2
    #         @input = UniMIDI::Input[1].open
    #         puts "Selected controller: #{@input.pretty_name}"
    #         @selected = @input.pretty_name[3]
    #         if devices.length == 3
    #             @available = "KM"
    #         else
    #             @available = @selected
    #         end
    #     end
    #     # @input = UniMIDI::Input.gets
    # end

    def select_controller(s)
        @available = available_controllers()
        if (index = @available.index(s[0]))
            @input = @inputs[index + 1].open
            puts "Selected controller: #{@input.pretty_name}"
            @selected = s[0]
        end
    end

    # M for M-Audio Trigger Finger, K for Korg Nano
    def get_selected()
        return @selected
    end

    def get_available()
        return @available
    end

    def initialize

        init_lights()
        @available = available_controllers()
        if @available
            @inputs = UniMIDI::Input.all
            @input = @inputs[-1].open
            puts "Selected controller: #{@input.pretty_name}"
            @selected = @available[0]
        end

        # Controls and actions
        @control_names1 = []
        (0..15).each{|i| @control_names1.push("button_#{i}")}
        (0..3).each{|i| @control_names1.push("slider_#{i}")}
        (0..7).each{|i| @control_names1.push("knob_#{i}")}
        @control_names2 = []
        (0..24).each{|i| @control_names2.push("key_#{i}")}
        @control_actions = Hash.new

        @last_midi_input = Hash.new
        # @calibration_mode = false
        # @signal_flag = false

        # Regexes
        simple_color_expr = /red|yellow|green|blue|violet|pink|#[0-9a-fA-F]{6}/
        color_expr = /(#{simple_color_expr}|(?:rand|random)(?:\(#{simple_color_expr}\s+#{simple_color_expr}\))?)/
        @on_regex = /^\s*(\d(?:,\d)*|all)\s+on\s*$/
        @off_regex = /^\s*(\d(?:,\d)*|all)\s+off\s*$/
        @color_regex = /^\s*(\d(?:,\d)*|all)\s+#{color_expr}\s*$/
        @pulse_regex = /^\s*(\d(?:,\d)*|all)\s+(pulse|flash)(?:\s+(#{color_expr}))?\s*$/
        @level_regex = /^\s*(\d(?:,\d)*|all)\s+(h|s|b|H|S|B|hue|sat|bri|saturation|brightness)(?:\s+(\d+))?\s*$/
        @strobe_regex = /^\s*(\d(?:,\d)*|all)\s+strobe(?:\s+(\d+))?(?:\s+(#{color_expr}))?\s*$/

    end

    def parse_ids(s)
        return (s == "all" && (1..BULB_COUNT).to_a) || s.split(",").map(&:to_i)
    end

    # Parses a hex or word and returns hsb.
    def parse_color(s)
        if s
            if s[0] == "#"
                m = s.match /#(..)(..)(..)/
                if m
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
            elsif s[0] == "r"
                m = s.match /.+\((.*)\s+(.*)\)/
                if m
                    source = [parse_color(m[1]), parse_color(m[2])]
                    random(source)
                else
                    random(nil)
                end
            else
                case s
                when "red"
                    [0, 255, 255]
                when "yellow"
                    [5279, 255, 255]
                when "green"
                    [26214, 255, 255]
                when "blue"
                    [45875, 255, 255]
                when "violet"
                    [53340, 255, 255]
                when "pink"
                    [56070, 255, 255]
                end
            end
        end
    end

    def validate(action)
        action =~ @on_regex || action =~ @off_regex || action =~ @color_regex || action =~ @pulse_regex || action =~ @level_regex || action =~ @strobe_regex
    end

    def parse_action(action, value)
        if not action
            return
        end
        actions = action.split(", ")
        actions.each do |a|
            print "execute\taction #{a}\tvalue #{value}\n"
            if strobe = @strobe_regex.match(a)
                light_ids = parse_ids(strobe.captures[0])
                color = parse_color(strobe.captures[2])
                given_rate = strobe.captures[1] && strobe.captures[1].to_i
                if given_rate
                    start_strobe(light_ids, color, given_rate)
                else
                    strobe_rate(light_ids, color, (value * STROBE_MAX).to_i)
                end
            elsif pulse = @pulse_regex.match(a)
                light_ids = parse_ids(pulse.captures[0])
                first = pulse.captures[1][0]
                t = (first == "p" && 0.3) || 0  # pulse or flash
                color = parse_color(pulse.captures[2])
                print "Pulse color #{color}.\n"
                send_pulse(light_ids, color, t)
            elsif level = @level_regex.match(a)
                light_ids = parse_ids(level.captures[0])
                case level.captures[1][0]
                when "h"
                    param = "hue"
                when "s"
                    param = "sat"
                when "b"
                    param = "bri"
                end
                value = level.captures[2] || value
                print "Level change #{param} #{value}.\n"
                set_param(light_ids, param, value)
            elsif color = @color_regex.match(a)
                light_ids = parse_ids(color.captures[0])
                set_color(light_ids, color)
            elsif on = @on_regex.match(a)
                light_ids = parse_ids(on.captures[0])
                set_on(light_ids)
            elsif off = @off_regex.match(a)
                light_ids = parse_ids(off.captures[0])
                set_off(light_ids)
            else
                print "Invalid action.\n"
            end
        end
    end

    def get_control_names(a)
        if a
            case a
            when 1
                @control_names1
            when 2
                @control_names2
            end
        else
            @control_names1.concat @control_names2
        end
    end

    def change_control_mode(name, action)
        print "registered\tname #{name}\taction #{action}\n"
        @control_actions[name] = action
    end

    # def query_signal()
    #     print "CALIBRATION MODE ON\n"
    #     @calibration_mode = true
    #     if @signal_flag
    #         @signal_flag = false
    #         return true
    #     else
    #         return false
    #     end
    # end

    # def query_signal_stop()
    #     print "NO MORE CALIBRATION\n"
    #     @calibration_mode = false
    # end

    def midi_hue_loop()
        print "Listening for MIDI input...\n"
        Thread.new() { nk_loop() }
        tf_loop()
    end

    def tf_loop()
        loop do
            while @selected == "M" do
                # Parse MIDI data from Trigger Finger
                
                # begin
                input = @input.gets[0]
                    # print "SIGNAL!\n"
                    # @signal_flag ||= (input[:data][2] > 0)
                # end while @calibration_mode

                if @selected == "M"
                    data, t = input[:data], input[:timestamp]
                    type, id, value = data
                    if !@last_midi_input[id] || t - @last_midi_input[id] > THROTTLE
                        @last_midi_input[id] = t
                        control = TFControl.new(type, id, value)
                        if control and control.id
                            print "TF\t#{control.kind}_#{control.id} (#{control.value})\n"
                            parse_action(@control_actions["#{control.kind}_#{control.id}"], control.percentage)
                        end
                    end
                end
                sleep 0.05
            end
            sleep 0.5
        end
    end

    def nk_loop()
        loop do
            while @selected == "K" do
                # Parse MIDI data from Korg Nano

                # begin
                input = @input.gets[0]
                    # print "SIGNAL!\n"
                    # @signal_flag ||= (input[:data][2] > 0)
                # end while @calibration_mode

                if @selected == "K"
                    data = input[:data]
                    type, id, value = data
                    control = NKControl.new(type, id, value)
                    if control and control.id
                        print "NK\t#{control.kind}_#{control.id} (#{control.value})\n"
                        parse_action(@control_actions["#{control.kind}_#{control.id}"], control.percentage)
                    end
                end
                sleep 0.05
            end
            sleep 0.5
        end
    end

    # def midi_poll_loop()
    #     loop do
    #         @available = available_controllers()
    #         if not @available.include? @selected
    #             @selected = nil
    #         end
    #         sleep 0.5
    #     end
    # end
end