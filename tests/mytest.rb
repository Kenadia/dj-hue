require './midi.rb'
c=Controller.new
c.change_control_mode("button_0", "1 on")
c.change_control_mode("slider_0", "1 strobe")
c.change_control_mode("knob_0", "1 h")
c.change_control_mode("knob_1", "1 s")
c.change_control_mode("knob_2", "1 b")
c.select_controller("M")
c.midi_hue_loop()
# Thread.new() { c.midi_hue_loop }
# c.midi_poll_loop()
