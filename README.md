We have been using [Docker](http://www.docker.io/) in our staging
environment for a month now and are planning to make it part of our
production setup once the first stable version gets released.

Whenever a new github branch gets started, Jenkins, our Continuous
Integration server, automatically attempts to build a new Docker
container from it. If all tests pass, this container becomes available
on our office network and we receive a Campfire notification. If tests
fail, we leave a Docker image for our engineers to examine. For Service
Oriented Architectures (SOA), this approach saves a lot of time when
working on features that span multiple services and cannot be isolated
to a particular component. The extra confidence that we get from
integrating features at a platform level means that we are more
effective and don't need to wait on one another.

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
[Vagrantfile](https://github.com/cambridge-healthcare/hi_sinatra-docker/blob/master/Vagrantfile)
will get everything setup for you. Cloning the repository and running
**vagrant up** inside it will create a VM with the latest stable Docker and
Jenkins services running side-by-side.

There will also be a running version of **hi_sinatra** inside a Docker
container using a Redis server running in a separate container for
tracking requests. Use the IP address and port displayed at the end of
the Vagrant run to access the **hi_sinatra** app in your browser.

<pre>
git clone https://github.com/cambridge-healthcare/hi_sinatra-docker.git
cd hi_sinatra-docker
vagrant up
</pre>

### 3. Setup Jenkins job

As the jenkins user belongs to the docker group, it can run Docker
commands directly. Combined with [Dockerize][dockerize], setting a job
that integrates with Docker couldn't be easier:

<pre>
| Job name | hi_sinatra                          |
| Job type | Build a free-style software project |
| Build    | Execute shell                       |
</pre>

This is the shell command which you will need to use for the build execution:

<pre>
/bin/bash -c "source $HOME/.profile && dockerize boot cambridge-healthcare/hi_sinatra-docker hi_sinatra"
</pre>

Every successful Jenkins build will now result in a Docker container
running **hi_sinatra** and a Redis server container for each git branch.

### 4. Successful build results in a running Docker container

Building the project for the first time (truncated output):

<pre>
Building in workspace /home/jenkins/.jenkins/workspace/hi_sinatra
[hi_sinatra] $ /bin/sh -xe /tmp/hudson8824124682277145403.sh
+ /bin/bash -c source /home/jenkins/.profile && dockerize boot cambridge-healthcare/hi_sinatra-docker hi_sinatra
HEAD is now at b054795... @dawson ready for review
Uploading context 528384 bytes
Uploading context 1085440 bytes
Uploading context 1611776 bytes
Uploading context 2162688 bytes
Uploading context 2334720 bytes

Step 1 : FROM howareyou/ruby:2.0.0-p247
 ---> b712db79101d
Step 2 : ADD ./ /var/apps/hi_sinatra
 ---> 442707553694
Step 3 : RUN . /.profile ;  rm -fr /var/apps/hi_sinatra/.git ;  cd /var/apps/hi_sinatra ;  bundle install --local ;# END RUN
 ---> Running in 747a7653af9f
Installing diff-lcs (1.2.4) 
Installing rack (1.5.2) 
Installing rack-protection (1.5.0) 
Installing rack-test (0.6.2) 
Installing redis (3.0.5) 
Installing rspec-core (2.14.5) 
Installing rspec-expectations (2.14.3) 
Installing rspec-mocks (2.14.3) 
Installing rspec (2.14.1) 
Installing tilt (1.4.1) 
Installing sinatra (1.4.3) 
Using bundler (1.3.5) 
Updating files in vendor/cache
Your bundle is complete!
Use `bundle show [gemname]` to see where a bundled gem is installed.
 ---> 5439e797487a
Step 4 : CMD . /.profile && cd /var/apps/hi_sinatra && bin/test && bin/boot
 ---> Running in 8282ba047a40
 ---> 1cf5ae0c0cbc
Step 5 : EXPOSE 8000
 ---> Running in 54b5a5d26b28
 ---> 0d07513f4e63
Successfully built 0d07513f4e63
Removing intermediate container b4a2da6aa89a
Removing intermediate container 747a7653af9f
Removing intermediate container 8282ba047a40
Removing intermediate container 54b5a5d26b28
Uploading context 557056 bytes
Uploading context 1114112 bytes
Uploading context 1660928 bytes
Uploading context 2217984 bytes
Uploading context 2334720 bytes

Step 1 : FROM hi_sinatra:master
 ---> 0d07513f4e63
Step 2 : ADD ./ /var/apps/hi_sinatra
 ---> 8fd588d1629b
Step 3 : RUN . /.profile ;  rm -fr /var/apps/hi_sinatra/.git ;  cd /var/apps/hi_sinatra ;  bundle install --local ;# END RUN
 ---> Running in bebf708f0c8a
Using diff-lcs (1.2.4) 
Using rack (1.5.2) 
Using rack-protection (1.5.0) 
Using rack-test (0.6.2) 
Using redis (3.0.5) 
Using rspec-core (2.14.5) 
Using rspec-expectations (2.14.3) 
Using rspec-mocks (2.14.3) 
Using rspec (2.14.1) 
Using tilt (1.4.1) 
Using sinatra (1.4.3) 
Using bundler (1.3.5) 
Updating files in vendor/cache
Your bundle is complete!
Use `bundle show [gemname]` to see where a bundled gem is installed.
 ---> 1b91e7998014
Step 4 : CMD . /.profile && cd /var/apps/hi_sinatra && bin/test && bin/boot
 ---> Running in 28987e90ee13
 ---> f16d718c59d5
Step 5 : EXPOSE 8000
 ---> Running in b540dec6a80a
 ---> f7980a764c57
Successfully built f7980a764c57
Removing intermediate container 2e8635a04a6e
Removing intermediate container bebf708f0c8a
Removing intermediate container 28987e90ee13
Removing intermediate container b540dec6a80a
c21ec0d7c419
293ffdc2e66c
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

[dockerize]: https://github.com/cambridge-healthcare/dockerize
