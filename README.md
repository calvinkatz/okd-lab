# OKD Lab Playbook

Lab deployment of OKD using basic options.

Based on v4.19.0-okd-scos.0

https://github.com/okd-project/okd

https://docs.okd.io/latest/installing/installing_bare_metal/upi/installing-bare-metal.html

Host layout:

* 3x control plane
* 3x compute
* 1x bootstrap
* 1x bastion

Run playbooks against bastion host.

Playbook assumes Fedora OS for bastion/ansible host.

## Playbook Pre-flight

Create bootstrap/bastion virtual machines:

* 4 CPU
* 8G RAM
* 50G disk
* Fedora Server OS

Create control plane virtual machines:

* 4 CPU
* 8+G RAM
* 100G disk

Create compute virtual machines:

* 4 CPU
* 8+G RAM
* 100G os disk
* 200G data disk, ssd emulation

Update hostnames/addresses in all config files.

Modify the HAProxy `stats.cfg` admin password.

### Install Config

Modify `install-config.yaml` as needed. Add SSH public key to remote nodes.

`clusterNetwork` refers to the network used for cluster/pod services. It is divided into multiple subnets and assigned to each node according to the `hostPrefix` property. Can leave default.

`serviceNetwork` refers to the network used for service endpoints. Can leave default.

`name` under `meta` is the cluster name and must match the DNS subdomain for the cluster.

To SSH nodes the username is `core`

## Bastion

This host will provide multiple services: DNS, DHCP, TFTP, NGINX, and HAProxy.

Create ansible user and setup to allow passwordless sudo:

```bash
sudo useradd -m -s /bin/bash ansible
sudo -u ansible mkdir /home/ansible/.ssh
echo "< ssh public key >" | sudo -u ansible tee /home/ansible/.ssh/authorized_keys
sudo -u ansible chmod 600 /home/ansible/.ssh/authorized_keys

echo "ansible  ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ansible
sudo chmod 440 /etc/sudoers.d/ansible
```

## Bootstrap Deployment

Run the bootstrap playbook from ansible host:

```bash
ansible-playbook -i hosts.yml bootstrap.yml
```

After playbook completes the cluster is ready to deploy.

### Post-Deployment

Boot servers in order and select reletive install from PXE boot menu.

1. Bootstrap
2. Control Plane
3. Worker

Start the bootstrap node first and monitor deployment from the bastion host.

```bash
sudo su - ansible
openshift-install --dir /opt/okd wait-for bootstrap-complete --log-level=debug
```

#### Bootstrap Node

After deployment of the bootstrap node, the `openshift-install` task will show similar:

```text
INFO API v1.31.7-dirty up                         
DEBUG Loading Install Config...                    
DEBUG   Loading SSH Key...                         
DEBUG   Loading Base Domain...                     
DEBUG     Loading Platform...                      
DEBUG   Loading Cluster Name...                    
DEBUG     Loading Base Domain...                   
DEBUG     Loading Platform...                      
DEBUG   Loading Pull Secret...                     
DEBUG   Loading Platform...                        
DEBUG Using Install Config loaded from state file  
INFO Waiting up to 45m0s (until 7:08PM CDT) for bootstrapping to complete... 
```

At this point continue booting the rest of the nodes, starting with the control plane.

### Deployment Tasks

Check node status:

```bash
oc get nodes
```

Check operator status:

```bash
oc get clusteroperators
```

Check for CSR's when worker nodes get added:

```bash
oc get csr
```

Sign all pending CSR's:

```bash
oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs --no-run-if-empty oc adm certificate approve
```

After nodes are bootstrapped and the `openshift-install` task from earlier finishes, remove the bootstrap node from HAProxy config:

```bash
sudo sed -i 's/: "server  bootstrap"/: "#server  bootstrap"/' /etc/haproxy/conf.d/machine.cfg
sudo sed -i 's/: "server  bootstrap"/: "#server  bootstrap"/' /etc/haproxy/conf.d/api.cfg
```

### Finally

After all operators are deployed, login to the console using the url: https://console-openshift-console.apps.okd.example.com

The username is `kubeadmin`. Password is in the `auth` folder of `/opt/okd`

```bash
cat /opt/okd/auth/kubeadmin-password
```

Expand Ingress replicas:

```bash
oc patch -n openshift-ingress-operator ingresscontroller/default --patch '{"spec":{"replicas": 3}}' --type=merge
```

Monitor HAProxy via url: http://okd-boot.example.com:1936/stats

Username and password defined in `stats.cfg`

## NOTES

Gathering logs for troubleshooting:

```bash
openshift-install gather bootstrap \
  --dir /opt/okd \
  --bootstrap bootstrap.okd.example.com \
  --master con01.okd.example.com \
  --master con02.okd.example.com \
  --master con03.okd.example.com \
  --log-level debug
```

## TODO

* Template configs to use vars
* Pull ssh public key from source
* Automate deployment tasks
* Automate post-config
* LetsEncrypt via cert-manager
