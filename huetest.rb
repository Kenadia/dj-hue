$:.unshift File.dirname(__FILE__)

(@bulbs = []) << Hue::Bulb.new(1) << Hue::Bulb.new(2) << Hue::Bulb.new(3)
@bulbs[0].update on: false
