A few weeks ago I started talking about how we use [Docker and Jenkins
for Continuous Delivery][part1] in our staging environment. Today, we
are open-sourcing a simple bash utility for managing inter-container
dependencies: [Dockerize][dockerize] that makes Docker and Jenkins
integration straightforward.

Before I go into specifics, I want to describe our workflow with
Jenkins and Docker from a high-level perspective:

* let's take the [hi_sinatra][hi_sinatra-docker] Ruby example app. It
  has its own Github repository and we have a simple, non-git Jenkins
job for it.

* every commit pushed to Github, regardless of the branch, triggers a
  Jenkins build (via Amazon SQS). All Jenkins builds will result in a
Docker image. A successful build will produce a running Docker
container. A failed build will produce a stopped container which can be
investigated by either looking at the logs or starting it with a tty
attached.

* if Docker doesn't have a **hi_sinatra:master** pre-built image,
  a new one will be created from the master branch. This master image
gets re-built every time there's a commit against the master branch.
Having a master image speeds up image builds considerably (eg.
installing Ruby gems, installing node modules, C extensions etc). The
resulting image won't use any caching and all intermediary images will
be removed. Just to clarify, this image will not be shipped into
production.

* if a Docker image with that app's name, branch name and git commit sha
  doesn't exist, we want Docker to build it for us. At this point, we're
interested to have the eg. **hi_sinatra:second-blog-post.a8e8e83**
Docker image available.

* before a new container can be started from the image that we've just
  built, all services that the app requires must be running in their own
independent containers. Our **hi_sinatra** example app requires a
running Redis server.

* when all dependent services are running in their own containers, we
  start a container from the newly built app image (in our example,
**hi_sinatra:second-blog-post.a8e8e83**). All dependent containers will
have their IPs exposed via env options, eg. `docker run -e
REDIS_HOST=172.17.0.8 -d ...`

* before our **hi_sinatra** app starts in its new Docker container, all
  tests must pass - both unit, integration and acceptance. Full stack
tests (also known as acceptance tests) use sandbox services, but they
are setup via the same Docker containers that will be made available in
production. Code portability is Docker's strongest point, we're making
full use of it.

* if everything worked as expected, including interactions with all
  external services, this Docker image will be tagged as
production. The service responsible for bringing up new Docker
containers from the latest production images will take it from here.

Docker containers running on the CI are available only on
our office network, anyone inside it can connect to them. All that it
takes to get an instance for a specific app (and all its dependencies)
is to push a new branch to Github.

### Dockerize

[Dockerize][dockerize] acts as a Docker proxy, meaning that all commands
which it does not understand get forwarded to the docker binary.
Dockerize has just 2 dependencies: bash & git.

The previously described workflow as a single shell command:

<pre>
dockerize boot cambridge-healthcare/hi_sinatra-docker hi_sinatra
</pre>

The **hi_sinatra** app comes with 2 files that Dockerize picks
up on:

* `.dockerize.containers` which defines dependencies on other containers
  (another service such as Redis server or another app)

* `.dockerize.envs` which will forward specific environment variables
  from the Docker host into the container

The Vagrantfile that comes with [hi_sinatra][hi_sinatra-docker] will
get you up and running with Docker, Jenkins and now Dockerize. The
quickest way to try the whole setup ([provided you have Vagrant
installed][part1]):

<pre>
git clone https://github.com/cambridge-healthcare/hi_sinatra-docker.git
cd hi_sinatra-docker
vagrant up
</pre>

By the time the VM gets provisioned, there will be a running version of
**hi_sinatra** inside a Docker container using a Redis server running in
a separate container for tracking requests. Use the IP address and port
displayed at the end of the Vagrant run to access the **hi_sinatra** app
in your browser.

### Jenkins + Dockerize

Dockerize makes Jenkins integration with Docker incredibly simple. In
the Jenkins instance running on the Vagrant VM that we have just built,
add the following job through the Jenkins web interface:

<pre>
| Job name | hi_sinatra                          |
| Job type | Build a free-style software project |
| Build    | Execute shell                       |
</pre>

This is the shell command which you will need to use for the build execution:

<pre>
/bin/bash -c "source $HOME/.profile && dockerize boot cambridge-healthcare/hi_sinatra-docker hi_sinatra"
</pre>

Every successful Jenkins build will now result in a running Docker container.

CI setups are always opinionated. We have a few more additions such as
Campfire notifications, Amazon SQS integration with Github and a few
others which are specific to our infrastructure. The above Jenkins
integration example with Docker is meant to be a most conservative
starting point for your own setup.

Until next time!

[part1]: http://blog.howareyou.com/post/62157486858/continuous-delivery-with-docker-and-jenkins-part-i
[hi_sinatra-docker]: https://github.com/cambridge-healthcare/hi_sinatra-docker/tree/v0.2.0
[dockerize]: https://github.com/cambridge-healthcare/dockerize
