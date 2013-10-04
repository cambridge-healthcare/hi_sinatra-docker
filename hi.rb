require 'sinatra'

require 'redis'
redis = Redis.new(:host => ENV.fetch('REDIS_HOST', "localhost"))

before do
  @hits = redis.incr("get_root_hits")
end

get '/' do
  "Hi, I am a Sinatra app running inside a docker container. " <<
  "I have been requested #{@hits} times."
end
