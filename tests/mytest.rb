require './midi.rb'
c=Controller.new
c.change_control_mode("button_0", "1 flash")
c.change_control_mode("knob_0", "1 brightness")
c.change_control_mode("knob_1", "2 s")
c.midi_hue_loop
