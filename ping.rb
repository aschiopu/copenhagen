require 'sinatra'

get '/' do
  erb :index
end

get '/player' do
  erb :player
end

post '/player' do
  "hello #{params['name']} and #{params['email']}"
end