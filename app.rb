require 'sinatra'
require 'slim'


get '/' do
    @control_names = {"button_1" => true, "button_2" => true}
    @items = ["test"]
    slim :index
end

post '/change' do
    name = request["name"]
    value = request["value"]
end