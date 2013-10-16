A few weeks ago I started talking about how we use [Docker and Jenkins
for Continuous
Delivery](http://blog.howareyou.com/post/62157486858/continuous-delivery-with-docker-and-jenkins-part-i)
in our staging environment. I will end the two-part series by talking
about how we handle Docker containers with dependencies on other
containers and the shell utility that we have built to automate the
manual and time-consuming docker commands.

Before I go into any specifics, I want to describe our Continuous
Delivery workflow with Jenkins and Docker from a high-level perspective.
Let's imagine that we have a Ruby app called **snomed** that we have
setup a Github repository and Jenkins job for.

* every commit pushed to Github, regardless of the branch, triggers a
  Jenkins build (via Amazon SQS). All Jenkins builds will result in a
Docker image. A successful build will produce a running Docker
container. A failed build will produce a stopped container which can be
investigated by either looking at the logs or starting it with a
terminal attached to it

* if Docker doesn't have a **snomed/master** pre-built image, a new one
  will be created from the master branch. This master image gets
re-built every time there's a commit against the master branch. Having a
master image speeds up all branch builds (think initial setup for gems,
modules, C extensions etc.). The resulting image won't use any caching
and all intermediary images will be removed.

* only if a Docker image with that app's name, branch name and git sha
  doesn't exist, go ahead and build one. The end result that we're
interested in is to have the following Docker image available: eg
**snomed/master:a8e8e83**

* before a new container can be started from the image that we've just
  built, all services that the app requires at that point in time must
be running in their own independent containers. Our app might need a
Redis server, a MySQL server, RabbitMQ broker etc. Every branch will
have it's own set of service dependencies, so if there are 5 branches,
there will be 5 sets of Redis servers, MySQL servers, RabbitMQ servers
etc.

* when all dependent services are running in their own containers, start
  a new container from the app image that we've just built and expose
IPs for all dependent containers as envs

* before the app processes start in the new container, ensure all tests
  pass - both unit, integration and acceptance. At this point, we want
to catch any integration bugs. Our CI environment, with the help of
Docker, is actually a sandbox, the last check before code gets shipped
into production. Containers must be fully working, all tests must pass,
even those that are interfacing with real services and are
time-consuming to run in development.

### Docker containers with dependencies on other containers

There are a few utilities which already integrate with Docker and are
capable of orchestrating multi-container deploys such as
[Dokku](https://github.com/progrium/dokku),
[Deis](https://github.com/opdemand/deis) and
[Maestro](https://github.com/toscanini/maestro). The reason why we
chose to build our own utility was the 

### Efficient Docker containers

**Docker has a hard limit of 42 AUFS layers**. Every time a command in
your Dockerfile gets executed (except the `FROM` command), the result is
a Docker image which is the equivalent to 1 AUFS layer. This sounds
great in theory as one can stack all those images to build complex
containers similar to how git trees get stacked within git commits.  The
speed boost from using images vs executing the same system commands over
and over again is immense, but there is one caveat. The `ADD` command
cannot be cached, so as soon as Docker comes across this command, it
stops using the pre-built images and will start creating new ones. This
is true for all commands that follow the `ADD` command. Furthermore,
this also continues in all inheriting Dockerfiles. In our [Ruby 2.0
Dockerfile](#xxx), where we were inheriting from [ruby-build](#xxx) ,
Ruby compilation would not be cached because `ADD` was used in the
ruby-build Dockerfile.


Many atomic commands (and thus images) results in a nice logical model
and is easier to understand when reading a Dockerfile. 

The flip-side of using many atomic commands (and thus images) is the 42
AUFS layers limit that I've mentioned. It might sound like a lot, but
I've hit it in the first implementation of this fairly simple
[dockerized Sinatra app](https://github.com/cambridge-healthcare/hi_sinatra-docker/tree/v0.1.0).

The error manifests itself through a rather vague error message:

<pre>
Error build: Unable to mount using aufs
Unable to mount using aufs
</pre>

This [docker github
issue](https://github.com/dotcloud/docker/issues/2028) goes into more
detail about it.


[Merging all
commands](https://github.com/cambridge-healthcare/dockerfiles/pull/1)
results in a single Docker image per Dockerfile. One clear advantage is
that now we can see exactly how much disk space each layer uses:

<pre>
REPOSITORY             TAG                 ID                  CREATED             SIZE
howareyou/ruby         2.0.0-p247          b712db79101d        3 hours ago         131.7 MB (virtual 613 MB)
howareyou/ruby-build   20130806            fb9df8396ee4        4 hours ago         203.4 MB (virtual 481.3 MB)
howareyou/ubuntu       12.04               a6bc0c7e68ea        4 hours ago         146.4 MB (virtual 277.9 MB)
ubuntu                 12.04               8dbd9e392a96        5 months ago        131.5 MB (virtual 131.5 MB)
</pre>

Docker ubuntu:12.04 image uses 131.5 MB. Our customized ubuntu:12.04
takes a further 146.4 MB and result in a combined total of 277.9 MB.  To
run ruby 2.0.0-p247 we need a further 2 Docker images: ruby-build and
the ruby image itself. A full ruby 2.0.0-p247 Docker image requires 4
images in total using 613 MB. Before combining commands across various
Dockerfiles, this same image used to be made of about 30+ Docker images,
bringing us very close to the 42 AUFS layers limit.

[Flat Docker images](http://3ofcoins.net/2013/09/22/flat-docker-images/)
by Maciej Pasternacki is a great post which talks about this same
problem more and offers a Perl script as a solution to the above
problem.

785
