A few weeks ago I started talking about how we use [Docker and Jenkins
for Continuous Delivery][part1] in our staging environment. I will end
the two-part series by explaining how we handle Docker containers
with dependencies on other containers and the shell utility that we have
built to automate the process.

Before I go into specifics, I want to describe our workflow with
Jenkins and Docker from a high-level perspective:

* let's take the [hi_sinatra][hi_sinatra-docker] Ruby example app. It
  has its own Github repository and we have a simple, non-git Jenkins
job for it.

* every commit pushed to Github, regardless of the branch, triggers a
  Jenkins build (via Amazon SQS). All Jenkins builds will result in a
Docker image. A successful build will produce a running Docker
container. A failed build will produce a stopped container which can be
investigated by either looking at the logs or starting it with a
terminal attached to it.

* if Docker doesn't have a **hi_sinatra/master** pre-built image,
  a new one will be created from the master branch. This master image
gets re-built every time there's a commit against the master branch.
Having a master image speeds up image builds considerably (eg.
installing Ruby gems, installing node modules, C extensions etc). The
resulting image won't use any caching and all intermediary images will
be removed. Just to clarify, this image will not be shipped into
production.

* if a Docker image with that app's name, branch and tagged with the git
  SHA doesn't exist, we want Docker to build it for us. At this point,
we're interested to have the eg.
**hi_sinatra/second-blog-post:a8e8e83** Docker image available.

* before a new container can be started from the image that we've just
  built, all services that the app requires at that point in time must
be running in their own independent containers. Our **hi_sinatra** app needs
a Redis server. If there are 5 branches, there will be 5 **hi_sinatra** app
instances using independent Redis server instances for a total of 10 Docker
containers.

* since all dependent services are running in their own containers, we start
  a new container from the app image that we've just built and expose
IPs for those containers as envs, eg `-e REDIS_HOST=172.17.0.8`.

* before our **hi_sinatra** app starts in its new Docker container, all
  tests must pass - both unit, integration and acceptance. At this
point, we want to catch any integration bugs. Our CI environment, with
the help of Docker, is actually a sandbox, the last check before code
gets shipped into production. Containers must be fully working, all
tests must pass, even those that are interfacing with real services and
are time-consuming to run in development.

### Dockerize

[Dockerize][dockerize] is a language-agnostic, Docker proxy utility,
meaning that all commands which it does not recognise will be passed
through to Docker.

The previously described workflow, as a single shell command:

<pre>
dockerize boot cambridge-healthcare/hi_sinatra-docker hi_sinatra
</pre>

The **hi_sinatra** app comes with 2 files that dockerize picks
up on:

* `.dockerize.containers` which defines service dependencies

* `.dockerize.envs` which will forward all specified environment
  variables on the Docker host into the container

The Vagrantfile that comes with [hi_sinatra][hi_sinatra-docker] will
get you up and running with Docker, Jenkins and now Dockerize. The
quickest way to try the whole setup ([provided you have Vagrant
installed][part1]):

<pre>
git clone https://github.com/cambridge-healthcare/hi_sinatra-docker.git
cd hi_sinatra-docker
vagrant up
vagrant reload
</pre>

As dockerize recognises **cambridge-healthcare/hi_sinatra-docker** as a
Github repository, it will ask you about your Github credentials. Since
this repository is a public one, it's safe to go with the third
option, **don't manage my credentials**.

If you find dockerize useful, show your appreciation by contributing back.

[part1]: http://blog.howareyou.com/post/62157486858/continuous-delivery-with-docker-and-jenkins-part-i
[hi_sinatra-docker]: https://github.com/cambridge-healthcare/hi_sinatra-docker/tree/v0.2.0
[dockerize]: https://github.com/cambridge-healthcare/dockerize
