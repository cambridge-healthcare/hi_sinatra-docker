Sinatra app ready to be run as a docker container.

```sh
docker build -t hi_sinatra github.com/cambridge-healthcare/hi_sinatra-docker
docker run -d -p 8000 hi_sinatra
```
