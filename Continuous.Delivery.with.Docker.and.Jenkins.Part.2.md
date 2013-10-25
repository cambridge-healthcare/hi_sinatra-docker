A few weeks ago I started talking about how we use [Docker and Jenkins
for Continuous Delivery][part1] in our staging environment. I will end
the two-part series by explaining how we handle Docker multi-container
dependencies.

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

* if a Docker image with that app's name, branch name and git SHA tag
  doesn't exist, we want Docker to build it for us. At this point, we're
interested to have the eg. **hi_sinatra:second-blog-post.a8e8e83**
Docker image available.

* before a new container can be started from the image that we've just
  built, all services that the app requires must be running in their own
independent containers. Our **hi_sinatra** example app needs a running Redis
server, it won't work without one.

* when all dependent services are running in their own containers, we
  start a container from the newly built app image (eg.
**hi_sinatra:second-blog-post.a8e8e83**) and expose the IPs of the
dependent containers as env options eg. `docker run -e REDIS_HOST=172.17.0.8 -d ...`

* before our **hi_sinatra** app starts in its new Docker container, all
  tests must pass - both unit, integration and acceptance. At this
point, we want to catch any integration bugs.

* if everything worked as expected, including interactions with all
  external services, this Docker image will be made available to
production. The service that is responsible for bringing up new Docker
containers from the latest production images will take it from here.

Our CI environment, with the help of Docker, is actually a staging
environment. Docker containers running on the CI are available only on
our office network, anyone inside it can connect to them. All that it
takes to get an instance for a specific app (and all its dependencies)
is to push a new branch to Github.

### Dockerize

Today, we are open-sourcing a simple bash utility for managing
inter-container dependencies: [Dockerize][dockerize].

It acts as a Docker proxy, meaning that all commands which it does not
understand get forwarded to the docker binary. Dockerize has just 2
dependencies: bash & git.

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
vagrant reload
</pre>

By the time the VM finishes reloading, there will be a running
version of **hi_sinatra** inside a Docker container using a
Redis server running in a separate container for tracking requests. The
IP address and port displayed after Vagrant ends up provisioning the VM
can be used to access the **hi_sinatra** app in your browser.

### Jenkins + Dockerize

Dockerize makes Jenkins integration with Docker incredibly simple. I
will be assuming that you are running Jenkins in the Vagrant VM built
from [this Vagrantfile][hi_sinatra-Vagrantfile].

Add the following job through the Jenkins web interface:

<pre>
| Job name | hi_sinatra                          |
| Job type | Build a free-style software project |
| Build    | Execute shell                       |
</pre>

This is the shell command which you will need to use for the build execution:

<pre>
source $HOME/.profile && dockerize boot cambridge-healthcare/hi_sinatra-docker hi_sinatra
</pre>

Every successful Jenkins build will now result in a running Docker container.

CI setups are always opinionated. We have a few more additions such as
Campfire notifications, Amazon SQS integration with Github and a few
others which are specific to our infrastructure. The above Jenkins
integration example with Docker is meant to be a most conservative
starting point for your own setup.

In a future blog post, I will be talking about some Docker limitations
that we came across and our solutions to them. More importantly, I will
also talk about our Docker production setup. Until next time!

[part1]: http://blog.howareyou.com/post/62157486858/continuous-delivery-with-docker-and-jenkins-part-i
[hi_sinatra-docker]: https://github.com/cambridge-healthcare/hi_sinatra-docker/tree/v0.2.0
[dockerize]: https://github.com/cambridge-healthcare/dockerize
[hi_sinatra-Vagrantfile]: https://github.com/cambridge-healthcare/hi_sinatra-docker/blob/v0.2.0/Vagrantfile
