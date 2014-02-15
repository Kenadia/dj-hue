require './midi.rb'
c=Controller.new
c.send_pulse([1], [255, 0, 255])
