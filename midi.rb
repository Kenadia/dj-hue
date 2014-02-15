$:.unshift File.dirname(__FILE__)

require 'unimidi'
require './tf-control'
require 'hue'

class Controller

    MAX_HUE = 65535
    MAX_SATURATION = 254
    MAX_BRIGHTNESS = 255

    PULSE_TIME = 0.3

    ##################
    # Light controls #
    ##################

    def init_lights()
        @bulbs.each do |b|
            b.brightness = 0
            b.on
        end
    end

    def bulbs()
        return @bulbs
    end

    def send_pulse(ids, color)
        if color
            ids.each do |id|
                Thread.new {
                    bulb = @bulbs[id - 1]
                    bulb.transition_time = PULSE_TIME
                    bulb.color = Hue::Colors::RGB.new(color[0], color[1], color[2])
                    sleep PULSE_TIME
                    bulb.transition_time = PULSE_TIME
                    bulb.brightness = 0
                }
            end
        else
            ids.each do |id|
                Thread.new {
                    bulb = @bulbs[id - 1]
                    bulb.transition_time = PULSE_TIME
                    bulb.brightness = 255
                    sleep PULSE_TIME
                    bulb.brightness = 0
                }
            end
        end
    end

    def set_param(ids, param, value)
        ids.each do |id|
            bulb = @bulbs[id - 1]
            bulb.transition_time = 0.25
            case param
            when "hue"
                bulb.update_state hue: (value * MAX_HUE).to_i
            when "sat"
                bulb.update_state sat: (value * MAX_SATURATION).to_i
            when "bri"
                bulb.update_state bri: (value * MAX_BRIGHTNESS).to_i
            end
        end
    end

    def update_color(bulb, color, transition)
        bulb = @bulbs[bulb - 1]
        hsb = (bulb.rgb = color)
        bulb.update hue: hsb[0], sat: hsb[1], transition: transition
        # bulb.update hue: (MAX_HUE * percentage).to_i, transition: transition, sat: MAX_SATURATION
    end

    def update_state(bulb, state)
        bulb = @bulbs[bulb - 1]
        bulb.update state
    end

    def toggle_light(bulb)
        update_state(bulb, !@on[bulb])
    end

    def toggle_party_mode()

        if @party_thread != nil

            puts "Exiting party mode :/"
            
            Thread.kill(@party_thread)
            @party_thread = nil
        else
            
            puts "Entering party mode!"
            @party_thread = Thread.new(){
                
                rainbow = []
                rainbow << [H_RED, H_GREEN, H_BLUE]
                rainbow << [H_BLUE, H_RED, H_GREEN]
                rainbow << [H_GREEN, H_BLUE, H_RED]

                # just loop through the party colours
                i = 0
                loop do

                    for j in 0..@bulbs.length - 1
                        update_color(j, rainbow[i][j], 0)
                    end

                    i += 1
                    if i >= rainbow.length
                        i = 0
                    end

                    sleep 0.1
                end
            }
        end

    end

    def initialize

        # Controller selection
        case UniMIDI::Input.all.length
        when 0
            abort("Cannot find a MIDI controller, aborting")
        when 1
            @input = UniMIDI::Input.first.open
            puts "MIDI controller found: #{@input.pretty_name}"
        else
            @input = UniMIDI::Input.gets
        end

        # Initial state
        
        bridge = Hue.application
        @bulbs = []
        (1..3).each{|i| @bulbs << Hue::Bulb.new(bridge, i)}
        @on = [false, false, false]
        @party_thread = nil
        init_lights()

        # Controls and actions
        @control_names = []
        (0..15).each{|i| @control_names.push("button_#{i}")}
        (0..3).each{|i| @control_names.push("slider_#{i}")}
        (0..7).each{|i| @control_names.push("knob_#{i}")}
        @a=1
        @control_actions = Hash.new

        # Regexes
        @pulse_regex = /^\s*(\d(?:,\d)*|all)\s+pulse\s+(red|green|blue|#[0-9a-fA-F]{6})\s*$/
        @level_regex = /^\s*(\d(?:,\d)*|all)\s+(h|s|b|H|S|B|hue|sat|bri|saturation|brightness)\s*$/

    end

    def parse_ids(s)
        if s == "all"
            [1,2,3]
        else
            s.split(",").map(&:to_i)
        end
    end

    def parse_color(s)
        if s[0] == "#"
            m = s.match /#(..)(..)(..)/
            if m != nil
                [m[1].hex, m[2].hex, m[3].hex]
            end
        else
            case s
            when "red"
                [255, 0, 0]
            when "green"
                [0, 255, 0]
            when "blue"
                [0, 0, 255]
            end
        end
    end

    def parse_action(action, value)
        print "execute\taction #{action}\tvalue #{value}\n"
        if pulse = @pulse_regex.match(action)
            light_ids = parse_ids(pulse.captures[0])
            color = parse_color(pulse.captures[1])
            print "Pulse color #{color}.\n"
            send_pulse(light_ids, color)
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
            print "Level change #{param} #{value}.\n"
            set_param(light_ids, param, value)
        else
            print "Invalid action.\n"
        end
    end

    def get_control_names()
        return @control_names
    end

    def change_control_mode(name, action)
        print "registered\tname #{name}\taction #{action}\n"
        @control_actions[name] = action
    end

    def midi_hue_loop()
        print "Listening for MIDI input...\n"
        loop do
            
            # Parse MIDI data from Trigger Finger
            data = @input.gets[0][:data]
            type = data[0]
            id = data[1]
            value = data[2]
            control = TFControl.new(type, id, value)

            if control != nil and control.id != nil
                print "#{control.kind}_#{control.id} (#{control.value})\n"
                parse_action(@control_actions["#{control.kind}_#{control.id}"], control.percentage)
            end
                    # # toggle party mode
                    # when Control::DECK_A_CUE
                    #   if control.value == 0
                    #       toggle_party_mode()
                    #   end

                    # # turns on all the lights
                    # when Control::DECK_A_PLAY
                    #   if control.value == 0
                    #       for i in 0..@bulbs.length - 1
                    #           update_state(i, true)
                    #           update_color(i, H_RED, 0)
                    #       end
                    #   end

                    # # turns off all the lights
                    # when Control::DECK_A_SCRATCH
                    #   if control.value == 0
                    #       for i in 0..@bulbs.length - 1
                    #           update_state(i, false)
                    #       end
                    #   end             

                    # # pass % of the knob to calculate the colour
                    # when Control::DECK_A_LOW_KNOB
                    #   update_color(0, control.percentage, 0)

                    # when Control::DECK_A_MID_KNOB
                    #   update_color(1, control.percentage, 0)

                    # when Control::DECK_A_HIGH_KNOB
                    #   update_color(2, control.percentage, 0)

                    # # toggle on/off individual lights
                    # when Control::DECK_A_KILL_LOW
                    #   if control.value == 0
                    #       toggle_light(0)
                    #   end

                    # when Control::DECK_A_KILL_MID
                    #   if control.value == 0
                    #       toggle_light(1)
                    #   end

                    # when Control::DECK_A_KILL_HIGH
                    #   if control.value == 0
                    #       toggle_light(2)
                    #   end
        end
    end
end