require 'sinatra'
require 'slim'
require './midi.rb'

controller = Controller.new

# controller.init_lights()
Thread.new() { controller.midi_hue_loop() }
# Thread.new() { controller.midi_poll_loop() }

get '/index.html' do
    # M for M-Audio Trigger Finger, K for NanoKorg
    @selected = controller.get_selected
    @control_names = Hash[controller.get_control_names(nil).collect { |v| [v, true] }]
    @control_names1 = controller.get_control_names(1)
    @pad_names = Hash[@control_names1[0..15].collect { |v| [v, true] }]
    @slider_names = Hash[@control_names1[16..19].collect { |v| [v, true] }]
    @knob_names = Hash[@control_names1[20..27].collect { |v| [v, true] }]
    @control_names2 = controller.get_control_names(2)
    @key_names = Hash[@control_names2[0..24].collect { |v| [v, true] }]
    slim :index
end

# post '/ajax/midi' do
#     available = controller.get_available
#     content_type :json
#     if available != request["available"]
#         {:changed => true, :available => available}.to_json
#     else
#         {:changed => false, :available => available}.to_json
#     end
# end

post '/ajax/setcontroller1' do
    controller.select_controller("M-Audio USB Trigger Finger")
end

post '/ajax/setcontroller2' do
    controller.select_controller("KORG INC. nanoKEY")
end

post '/ajax/changemode' do
    controller.change_control_mode(request["name"], request["value"])
end

post '/ajax/execute' do
    controller.parse_action(request["action"], nil)
end

# post '/ajax/signal' do
#     signal = controller.query_signal()
#     content_type :json
#     {:signal => signal}.to_json
# end

# post '/ajax/signalstop' do
#     controller.query_signal_stop()
# end
