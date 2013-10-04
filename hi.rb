require 'sinatra'

redis_host = ENV.fetch('REDIS_HOST', false)
if redis_host
  require 'redis'
  redis = Redis.new(:host => redis_host)
end


get '/' do
 result = ["<p>Hi, I am a Sinatra app running inside a docker container</p>"]

 if redis_host
   hits = redis.incr("get_root_hits")
   result << "<p>I have been displayed #{hits} times</p>"
 end

 result
end
