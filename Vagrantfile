# -*- mode: ruby -*-
# vi: set ft=ruby :

BOX_NAME = ENV['BOX_NAME'] || "ubuntu"
BOX_URI = ENV['BOX_URI'] || "http://files.vagrantup.com/precise64.box"
VF_BOX_URI = ENV['BOX_URI'] || "http://files.vagrantup.com/precise64_vmware_fusion.box"

DOCKER_PORTS = (49_153..50_000)
JENKINS_PORT = 8080

Vagrant::Config.run do |config|
  # Setup virtual machine box. This VM configuration code is always executed.
  config.vm.box = BOX_NAME
  config.vm.box_url = BOX_URI

  # Provision docker and new kernel if deployment was not done.
  # It is assumed Vagrant can successfully launch the provider instance.
  if Dir.glob("#{File.dirname(__FILE__)}/.vagrant/machines/default/*/id").empty?
    # Add lxc-docker package
    pkg_cmd = [
      "wget -q -O - https://get.docker.io/gpg | apt-key add -",
      "echo deb http://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list",
      "apt-get update -qq; apt-get install -q -y --force-yes lxc-docker",
    ]
    # Add Ubuntu raring backported kernel
    pkg_cmd += [
      "apt-get update -qq",
      "apt-get install -q -y linux-image-generic-lts-raring",
    ]
    # Add guest additions if local vbox VM. As virtualbox is the default provider,
    # it is assumed it won't be explicitly stated.
    if ENV["VAGRANT_DEFAULT_PROVIDER"].nil? && ARGV.none? { |arg| arg.downcase.start_with?("--provider") }
      pkg_cmd += [
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
    pkg_cmd += [
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
  sudo -Hu jenkins java -jar ~jenkins/jenkins.war -Djava.awt.headless=true --httpPort=#{JENKINS_PORT}
end script
EOF},
    ]
    # Activate kernel & ensure everything starts correctly by rebooting
    pkg_cmd << %{echo -e "\nSETUP SUCCESSFUL, rebooting VM...\n"}
    pkg_cmd << "shutdown -r now"
    config.vm.provision :shell, :inline => pkg_cmd.join("\n")
  end
end

# Providers were added on Vagrant >= 1.1.0
Vagrant::VERSION >= "1.1.0" and Vagrant.configure("2") do |config|
  config.vm.provider :vmware_fusion do |f, override|
    override.vm.box = BOX_NAME
    override.vm.box_url = VF_BOX_URI
    override.vm.synced_folder ".", "/vagrant", :disabled => true
    f.vmx["displayName"] = "hi_sinatra"
  end

  config.vm.provider :virtualbox do |vb|
    config.vm.box = BOX_NAME
    config.vm.box_url = BOX_URI
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
    vb.customize ["modifyvm", :id, "--memory", "1024"]
    vb.customize ["modifyvm", :id, "--cpus", "2"]
  end
end

Vagrant::VERSION < "1.1.0" and Vagrant::Config.run do |config|
  (DOCKER_PORTS.to_a << JENKINS_PORT).each do |port|
    config.vm.forward_port port, port
  end
end

Vagrant::VERSION >= "1.1.0" and Vagrant.configure("2") do |config|
  (DOCKER_PORTS.to_a << JENKINS_PORT).each do |port|
    config.vm.network :forwarded_port, :host => port, :guest => port
  end
end
