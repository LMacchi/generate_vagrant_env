# Generate Vagrant Environment
Script that generates a Vagrant environment to test Puppet code using Puppet apply

## Pre-requirements

- Virtualbox and Vagrant installed
- Puppet Enterprise 4+ installed
- Project directory with the following structure:

```
project1/
└── modules
    └── new
        ├── Gemfile
        ├── manifests
        │   ├── init.pp
        │   ├── params.pp
        ├── metadata.json
        └── spec
            ├── acceptance
            │   └── class_spec.rb
            ├── classes
            │   └── example_spec.rb
            ├── spec_helper.rb
            └── spec_helper_acceptance.rb
```

## Result
After running the generate script, a vagrant folder will be created under the project with the following structure:

```
vagrant
├── Puppetfile
├── Vagrantfile
├── metadata.json
└── puppet
    ├── environments
    │   └── production
    ├── manifests
    │   └── site.pp
    └── modules
```

The Vagrant shell provisioner will install all of the modules listed in metadata.json using [Librarian-puppet](https://github.com/voxpupuli/librarian-puppet).
Librarian-puppet was chosen over R10k because it can resolve dependencies by different means, including metadata.json files.

In order to get the dependencies from the modules metadata.json, the generate files script reads them and consolidates them into a
metadata.json inside the vagrant directory. That metadata.json file is called by the Puppetfile in the vagrant directory.

Finally site.pp includes all of the modules found inside the modules directory.

## Usage

```
★ lmacchi@Titere 14:39:15 ~/puppet/Repos/generate_vagrant_env> ./gen_files.rb
Usage: ./gen_files.rb
    -p [/path/to/module/project],    Required: Path to project containing modules under development. Ex: ~/workspace/project1
        --proj_dir
    -b, --box [vagrant_box]          Required: Vagrant box title. Ex: puppetlabs/centos-7.2-64-puppet
    -v [vagrant_box_version],        Optional: Vagrant box version. Ex: 1.0.1
        --box_ver
    -u, --box_url [vagrant_box_url]  Optional: Vagrant box url. Ex: https://vagrantcloud.com/puppetlabs/boxes/centos-7.2-64-puppet
    -d, --disk [vagrantboxurl]       Optional: Secondary disk name. Ex: rhelSecondDisk.vdi
    -n, --node_name [node_name]      Optional: Name for the node to be created. Ex: test.puppetlabs.vm
    -s, --server [puppet_version]    Optional: URL/IP of the Puppet Master server
    -h, --help                       Display this help
```

Once the files have been generated:

- From the vagrant folder run `vagrant up`
- Wait for box to be provisioned
- Puppet will run and apply the module

```
==> node: Running Puppet with environment production...
==> node: Info: Loading facts
==> node: Info: Loading facts
==> node: Info: Loading facts
==> node: Info: Loading facts
==> node: Notice: Compiled catalog for test.lmacchi.vm in environment production in 0.17 seconds
==> node: Info: Applying configuration version '1498066369'
==> node: Notice: This is the class new
==> node: Notice: /Stage[main]/New/Notify[This is the class new]/message: defined 'message' as 'This is the class new'
==> node: Notice: /Stage[main]/Main/Node[default]/File[/tmp/new.txt]/ensure: created
==> node: Notice: /Stage[main]/Main/Node[default]/File_line[test]/ensure: created
==> node: Notice: Applied catalog in 0.02 seconds
```

If there are errors, you modify your module directory in your workstation, save changes and run Puppet again:

```
★ lmacchi@Titere 11:32:42 ~> vagrant provision --provision-with puppet
==> node: Running provisioner: puppet...
==> node: Running Puppet with environment production...
```

Once you're done testing, destroy the vm:
- vagrant destroy -f

## Notes
- The Vagrant Puppet provisioner maps Puppet module directories in the guest to a host directory, so all your dependencies will be stored in your
host machine
- Puppet agent hardcoded to RHEL7 since I was in a bit of rush to deliver this project. Will re-do Puppet agent installation.
- Contributions welcome
