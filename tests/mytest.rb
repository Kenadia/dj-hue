require './midi.rb'
c=Controller.new
c.change_control_mode("button_0", "1 on, 1 off")
c.change_control_mode("slider_0", "1 strobe")
c.change_control_mode("knob_0", "1 brightness")
c.change_control_mode("knob_1", "2 s")
# c.select_controller("M")
c.midi_hue_loop()
# Thread.new() { c.midi_hue_loop }
# c.midi_poll_loop()
