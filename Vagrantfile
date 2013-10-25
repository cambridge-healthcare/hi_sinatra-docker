# -*- mode: ruby -*-
# vi: set ft=ruby :

BOX_NAME = ENV.fetch("BOX_NAME", "ubuntu")
BOX_URI = ENV.fetch("BOX_URI", "http://files.vagrantup.com/precise64.box")
BOX_IP = ENV.fetch("BOX_IP", "11.11.11.2")
BOX_MEM = ENV.fetch("BOX_MEM", "1024")
BOX_CPUS = ENV.fetch("BOX_CPUS", "2")
VF_BOX_URI = ENV.fetch("BOX_URI", "http://files.vagrantup.com/precise64_vmware_fusion.box")
SHARED_DIRS = ENV.fetch("BOX_SHARED_DIRS", "").strip.split(" ")

def share_dirs
  lambda { |config|
    if SHARED_DIRS.any?
      SHARED_DIRS.each do |shared_dir|
        config.vm.synced_folder(
          File.expand_path(shared_dir),
          "/mnt/#{File.basename(shared_dir)}",
          :nfs => true
        )
      end
    end
  }
end

Vagrant::Config.run do |config|
  # Setup virtual machine box. This VM configuration code is always executed.
  config.vm.box = BOX_NAME
  config.vm.box_url = BOX_URI
  provisioning_script = ["export DEBIAN_FRONTEND=noninteractive"]

  provision_docker = [
    "apt-get update -qq",
    "apt-get install -qq -y linux-image-generic-lts-raring",
    "wget -q -O - https://get.docker.io/gpg | apt-key add -",
    "echo deb http://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list",
    "apt-get update -qq; apt-get install -qq -y --force-yes lxc-docker",
  ]

  provision_dockerize = [
    %{apt-get install -qq -y git-core},
    %{export dockerize_version="0.1.0"},
    %{dockerize_source="https://github.com/cambridge-healthcare/dockerize/archive/v${dockerize_version}"},
    %{dockerize_dir="/usr/local/src/dockerize-${dockerize_version}"},
    %{dockerize_bin="${dockerize_dir}/bin/dockerize"},
    %{if [[ ! -e $dockerize_bin ]]; then wget -q -O - "${dockerize_source}.tar.gz" | tar -C /usr/local/src -zxv; fi},
    %{if [[ $(sudo grep -c "$dockerize_bin init" /root/.profile) == 0 ]]; then sudo echo 'eval \"$(/usr/local/src/dockerize-0.1.0/bin/dockerize init -)\"' >> /root/.profile; fi},
    %{if [[ $(sudo grep -c "$dockerize_bin init" /home/jenkins/.profile) == 0 ]]; then sudo echo 'eval \"$(/usr/local/src/dockerize-0.1.0/bin/dockerize init -)\"' >> /home/jenkins/.profile; fi},
  ]

  provision_hi_sinatra = [
    "sudo touch /root/.no_prompting_for_git_credentials",
    "sudo touch /home/jenkins/.no_prompting_for_git_credentials",
    "sudo -i dockerize boot cambridge-healthcare/hi_sinatra-docker:continuos-delivery-2 hi_sinatra",
    "if [[ $? = 0 ]]; then sudo -i echo \"hi_sinatra successfully started, available on http://#{BOX_IP}:$(sudo -i dockerize show hi_sinatra Tcp | awk '{ print $2 }')\"; fi",
  ]

  provision_jenkins = [
    "useradd jenkins -s /bin/bash -m -G docker",
    "passwd -l jenkins",
    "apt-get install -qq -y openjdk-7-jre-headless git-core",
    "cd /home/jenkins",
    "sudo -Hu jenkins git config --global user.name Jenkins",
    "sudo -Hu jenkins git config --global user.email jenkins@$(hostname)",
    "wget -q -O - http://mirrors.jenkins-ci.org/war-stable/latest/jenkins.war > /home/jenkins/jenkins.war",
    %{cat << EOF > /etc/init/jenkins.conf
description "Jenkins Server"

start on filesystem
stop on runlevel [!2345]

respawn limit 10 5

script
  sudo -Hu jenkins java -jar /home/jenkins/jenkins.war -Djava.awt.headless=true --httpPort=8080
end script
EOF},
  ]

  if Dir.glob("#{File.dirname(__FILE__)}/.vagrant/machines/default/*/id").empty?
    provisioning_script += provision_docker
    provisioning_script += provision_jenkins
    provisioning_script += provision_dockerize
    provisioning_script += provision_hi_sinatra
    provisioning_script << %{echo "\nVM ready!\n"}
  end

  config.vm.provision :shell, :inline => provisioning_script.join("\n")
end

# Providers were added on Vagrant >= 1.1.0
Vagrant::VERSION >= "1.1.0" and Vagrant.configure("2") do |config|
  config.vm.provider :vmware_fusion do |f, override|
    override.vm.box = BOX_NAME
    override.vm.box_url = VF_BOX_URI
    # Sharing dirs over NFS requires a private network
    config.vm.network(:private_network, :ip => BOX_IP)
    override.vm.synced_folder(".", "/vagrant", :disabled => true)
    f.vmx["displayName"] = "hi_sinatra"
  end

  config.vm.provider :virtualbox do |vb|
    config.vm.box = BOX_NAME
    config.vm.box_url = BOX_URI
    # Sharing dirs over NFS requires a private network
    config.vm.network(:private_network, :ip => BOX_IP)
    config.vm.synced_folder(".", "/vagrant", :disabled => true)
    share_dirs.call(config)
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
    vb.customize ["modifyvm", :id, "--memory", BOX_MEM]
    vb.customize ["modifyvm", :id, "--cpus", BOX_CPUS]
  end
end
