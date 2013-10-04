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
  provisioning_script = []

  provision_dockerize = [
    %{dockerize_version="0.1.0.rc1"},
    %{dockerize_source="https://github.com/cambridge-healthcare/dockerize/archive/v${dockerize_version}"},
    %{dockerize_dir="/usr/local/src/dockerize-${dockerize_version}"},
    %{dockerize_bin="${dockerize_dir}/bin/dockerize"},
    %{if [[ ! -e $dockerize_bin ]]; then wget -q -O - "${dockerize_source}.tar.gz" | tar -C /usr/local/src -zxv; fi},
    %{if [[ $(sudo grep -c "$dockerize_bin init" /root/.profile) == 0 ]]; then sudo echo "eval \"$($dockerize_bin init -)\"" >> /root/.profile; fi},
  ]

  # Provision docker and new kernel if deployment was not done.
  # It is assumed Vagrant can successfully launch the provider instance.
  if Dir.glob("#{File.dirname(__FILE__)}/.vagrant/machines/default/*/id").empty?
    # Add lxc-docker package
    provisioning_script += [
      "wget -q -O - https://get.docker.io/gpg | apt-key add -",
      "echo deb http://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list",
      "apt-get update -qq; apt-get install -q -y --force-yes lxc-docker",
    ]
    # Add Ubuntu raring backported kernel
    provisioning_script += [
      "apt-get update -qq",
      "apt-get install -q -y linux-image-generic-lts-raring",
    ]
    # Add guest additions if local vbox VM. As virtualbox is the default provider,
    # it is assumed it won't be explicitly stated.
    if ENV["VAGRANT_DEFAULT_PROVIDER"].nil? && ARGV.none? { |arg| arg.downcase.start_with?("--provider") }
      provisioning_script += [
        "apt-get install -q -y linux-headers-generic-lts-raring dkms",
        "echo 'Downloading VBox Guest Additions...'",
        "wget -q http://dlc.sun.com.edgesuite.net/virtualbox/4.2.12/VBoxGuestAdditions_4.2.12.iso",
        # Prepare the VM to add guest additions after reboot
        %{cat << EOF > /root/guest_additions.sh
mount -o loop,ro /home/vagrant/VBoxGuestAdditions_4.2.12.iso /mnt
echo yes | /mnt/VBoxLinuxAdditions.run
umount /mnt
rm /root/guest_additions.sh
EOF},
        "chmod 700 /root/guest_additions.sh",
        "sed -i -E 's#^exit 0#[ -x /root/guest_additions.sh ] \\&\\& /root/guest_additions.sh#' /etc/rc.local",
        "echo 'Installation of VBox Guest Additions is proceeding in the background.'",
        "echo '\"vagrant reload\" can be used in about 2 minutes to activate the new guest additions.'",
      ]
    end
    provisioning_script += [
      "groupadd docker",
      "useradd jenkins -m -G docker",
      "passwd -l jenkins",
      "apt-get install -y openjdk-7-jre-headless git-core",
      "cd ~jenkins",
      "sudo -Hu jenkins git config --global user.name Jenkins",
      "sudo -Hu jenkins git config --global user.email jenkins@$(hostname)",
      "wget -q -O - http://mirrors.jenkins-ci.org/war-stable/latest/jenkins.war > ~jenkins/jenkins.war",
      %{cat << EOF > /etc/init/jenkins.conf
description "Jenkins Server"

start on filesystem
stop on runlevel [!2345]

respawn limit 10 5

script
  sudo -Hu jenkins java -jar ~jenkins/jenkins.war -Djava.awt.headless=true --httpPort=8080
end script
EOF},
    ]
    # Activate kernel & ensure everything starts correctly by rebooting
    provisioning_script += provision_dockerize
    provisioning_script << %{echo -e "\nVM needs to reboot...\n"}
    provisioning_script << "shutdown -r now"
  else
  # Already provisioned, just need to add a few other dependencies
    # Ensure dockerize is provisioned
    provisioning_script += provision_dockerize
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
    share_dirs.call(config)
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
    vb.customize ["modifyvm", :id, "--memory", BOX_MEM]
    vb.customize ["modifyvm", :id, "--cpus", BOX_CPUS]
  end
end
