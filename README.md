Sinatra app ready to be run as a docker container.

```sh
docker build -t hi-sinatra github.com/cambridge-healthcare/hi-sinatra-docker
docker run -d -p 4567 hi-sinatra
```
