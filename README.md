We have been using [Docker](http://www.docker.io/) in our staging
environment for a month now and are planning to make it part of our
production setup once the first stable version gets released.

Docker is a utility for creating virtualized Linux containers for
shipping self-contained applications. As oppossed to a traditional VM
which runs a full-blown operating system on top of the host, Docker
leverages LinuX Containers (LXC) which run on the same operating system.
This results in a more efficient usage of system resource by trading
some of the isolation specific to hypervisors. What makes Docker
appealing is that applications can be packaged as self-contained
containers, shipped around as small data blobs and brought up as fully
independent hosts in a matter of seconds. If an Amazon Machine Image
(AMI) takes a few minutes to boot, the equivalent Docker images take a
few seconds at most (normally ~1s). To find out more about Docker
internals, see [Docker, The Whole Story](http://www.docker.io/the_whole_story/).

We have converted our entire staging environment from a handful of AMIs
to a single bare metal host running Docker. We have made it more
efficient and faster to bring up versions of services which undergo
rigorous testing before they get shipped into production.

Whenever a new
github branch gets started, Jenkins, our Continuous Integration server,
automatically attempts to build a new Docker container from it. If all
tests pass, this container becomes available on our office network and we receive a
Campfire notification. If tests fail, we leave a Docker image for our
engineers to examine. For Service Oriented Architectures (SOA), this
approach saves a lot of time when working on features that span multiple
services and cannot be isolated to a particular component. The extra
confidence that we get from integrating features at a platform level
means that we are more effective and don't need to wait on one another.

We couldn't find any clear guide on integrating Docker with Jenkins so
we've decided to contribute one. We have included a Vagrantfile which
automates the entire setup except creating Jenkins jobs.

### 1. Install VirtualBox, Vagrant & git

Either install using your package manager or use the official downloads:

* [install virtualbox](https://www.virtualbox.org/)
* [install vagrant](http://www.vagrantup.com/)
* [install git](http://git-scm.com/downloads)

### 2. Create Vagrant VM

The
[Vagrantfile](https://github.com/cambridge-healthcare/hi_sinatra-/blob/master/Vagrantfile)
will get everything setup for you. Cloning the repository and running
**vagrant up** inside it will create a VM with the latest stable Docker and
Jenkins services running side-by-side. Jenkins belongs to the docker group and
can run Docker commands directly.

<pre>
git clone https://github.com/cambridge-healthcare/hi_sinatra-docker.git
cd hi_sinatra-docker
vagrant up
</pre>

### 3. Setup Jenkins job

Find the Jenkins Server running at http://localhost:8080/, install the [Git
plugin](https://wiki.jenkins-ci.org/display/JENKINS/Git+Plugin).

Once this is successfully installed and Jenkins is restarted, add the following job:

<pre>
| Job name               | hi_sinatra                                                    |
| Job type               | Build a free-style software project                           |
| Source Code Management | Git                                                           |
| Repository URL         | https://github.com/cambridge-healthcare/hi_sinatra-docker.git |
| Build                  | Execute shell                                                 |
</pre>

This is the shell command which will run the build:

<pre>
set -e
service=$JOB_NAME
service_port=8000
branch=$(echo $GIT_BRANCH | cut -d/ -f 2)

docker build -t $service:$branch $WORKSPACE

container_id=$(docker run -d -p $service_port $service:$branch)
container_port=$(docker inspect $container_id | awk 'BEGIN { FS = "\"" } ; /"'$service_port'":/ { print $4 }')

echo "App running on http://localhost:$container_port"
</pre>

The app includes a Dockerfile which builds a Docker image.
The first Docker build will take longer (depending on your internet
connection), but as Docker caches build steps (pro tip: apart from
**ADD**), subsequent builds will be significantly quicker.

### 4. Successful build results in a running Docker container

Building the project for the first time (truncated output):

<pre>
Building in workspace /home/jenkins/.jenkins/jobs/hi_sinatra/workspace
Cloning repository https://github.com/cambridge-healthcare/hi_sinatra-docker.git
Commencing build of Revision bbb5383939cf719745c232c67f0dffe99b639d91 (origin/master, origin/HEAD)
.
.
.
Step 1 : FROM howareyou/ruby_2.0.0-p247
Pulling repository howareyou/ruby_2.0.0-p247
.
.
.
Step 9 : RUN cd /var/apps/$SERVICE && bin/test
 ---> Running in bbaaf476e848
Run options: include {:focus=>true}

All examples were filtered out; ignoring {:focus=>true}
.

Finished in 0.02125 seconds
1 example, 0 failures
.
.
App running on http://localhost:49153

Finished: SUCCESS
</pre>

While the first build takes 2 mins and 26 secs, the second one takes a
mere 5 secs. That is **5 seconds** to install all the ruby gems, run all
the tests, build a Docker image and start a new Docker container that
makes that app version available for further testing (eg. integration
tests, stress tests). The resulting app image is a mere **12.29kB**.
That's the only new content which needs deploying into production.

### github service hooks

For integrating github with a Jenkins server not accessible from the
outside world, we have found Amazon SQS to be an elegant solution.
There is a [Github SQS
plugin](https://wiki.jenkins-ci.org/display/JENKINS/GitHub+SQS+Plugin)
that is installable from within Jenkins, setup is straightforward.

The only gotcha is that the SQS must be setup in the **us-east-1**
region. We had set it up initially in eu-west-1 and were puzzled as to
why it wasn't working.

### "How are you?" base Docker images

During our use of Docker, we have made public a few [Docker
images](https://index.docker.io/u/howareyou/) on the public Docker
index. The app which we have given as an example makes use of
[howareyou/ruby_2.0.0-p247](https://index.docker.io/u/howareyou/ruby_2.0.0-p247/)
and all its dependencies.

If you have found this tutorial useful, please help us to improve it by adding
your contributions via pull requests.
