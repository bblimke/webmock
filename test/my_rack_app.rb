require 'sinatra'

class MyRackApp < Sinatra::Base
  # debug
  # def self.call(env)
  #   p env

  #   [200, {'Content-Length' => 13}, ['Hello, World!']]
  # end

  get '/' do
    'This is my root!'
  end

  get '/greet' do
    "Hello, #{params[:name] || 'World'}"
  end

  # not something you'd really use a post request for, but hey.
  post '/greet' do
    "Good to meet you, #{params[:name]}!"
  end
end
