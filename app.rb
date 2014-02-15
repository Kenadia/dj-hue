require 'sinatra'
require 'slim'
require './midi.rb'

controller = Controller.new

# controller.init_lights()
Thread.new() { controller.midi_hue_loop() }

get '/' do
    @control_names = Hash[controller.get_control_names().collect { |v| [v, true] }]
    slim :index
end

post '/changemode' do
    controller.change_control_mode(request["name"], request["value"])
end
