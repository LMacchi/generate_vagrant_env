#!/opt/puppetlabs/puppet/bin/ruby
# Script that generates:
# - Vagrantfile
# - site.pp
# - metadata.json
# - Puppetfile

require 'optparse'
require 'erb'
require 'pathname'
require 'fileutils'
require 'yaml'
require 'json'

# Get arguments from CLI
options = {}
o = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0}"
  opts.on('-p [/path/to/module/project]', '--proj_dir [/path/to/module/project]', "Required: Path to project containing modules under development. Ex: ~/workspace/project1") do |o|
    options[:proj_dir] = o
  end
  opts.on('-b [vagrant_box]', '--box [vagrant_box]', "Required: Vagrant box title. Ex: puppetlabs/centos-7.2-64-puppet") do |o|
    options[:box] = o
  end
  opts.on('-v [vagrant_box_version]', '--box_ver [vagrant_box_version]', "Optional: Vagrant box version. Ex: 1.0.1") do |o|
    options[:box_ver] = o
  end
  opts.on('-u [vagrant_box_url]', '--box_url [vagrant_box_url]', "Optional: Vagrant box url. Ex: https://vagrantcloud.com/puppetlabs/boxes/centos-7.2-64-puppet") do |o|
    options[:box_url] = o
  end
  opts.on('-d [/path/to/disk]', '--disk [/path/to/disk]', "Optional: Secondary disk name. Ex: rhelSecondDisk.vdi") do |o|
    options[:disk] = o
  end
  opts.on('-n [node_name]', '--node_name [node_name]', "Optional: Name for the node to be created. Ex: test.puppetlabs.vm") do |o|
    options[:node_name] = o
  end
  opts.on('-i [install_script_template]', '--install_script [install_script_template]', "Optional: Template for Puppet install script. Defaults to install_puppet_el7.sh.erb") do |o|
    options[:install_script] = o
  end
  opts.on('-h', '--help', 'Display this help') do
    puts opts
    exit 0 
  end
end

o.parse!

# Create vars to use
proj_dir = Pathname.new(options[:proj_dir])
box = options[:box]
box_ver = options[:box_ver]
box_url = options[:box_url]
if options[:disk]
  disk = Pathname.new(options[:disk])
end
node_name = options[:node_name]
master = options[:server]

mod_dir = proj_dir + 'modules'
vag_dir = proj_dir + 'vagrant'
puppet = '4'

if options[:install_script]
  install_script = Pathname(__FILE__).dirname + 'templates' + options[:install_script]
else
  install_script = Pathname(__FILE__).dirname + 'templates' + 'install_puppet_el7.sh.erb'
end

# Validate vars
unless proj_dir
  puts "ERROR: proj_dir is a required argument"
  puts o
  exit 2
end

unless proj_dir.directory?
  puts "ERROR: #{proj_dir.to_s} does not exist"
  puts o
  exit 2
end

unless mod_dir.directory?
  puts "ERROR: #{mod_dir.to_s} does not exist"
  puts o
  exit 2
end

unless box
  puts "ERROR: box is a required argument"
  puts o
  exit 2
end

unless install_script.file?
  puts "ERROR: #{install_script} does not exist"
  puts o
  exit 2
end

# These values are for the Puppet provisioner in Vagrant
# we won't use them in this script
code_dir = '/vagrant/puppet'
global_mod_dir = '/etc/puppet/modules'
puppet_bin = '/opt/puppetlabs/puppet/bin'

# Generate Vagrant Structure
vag_dirs = ['environments', 'modules', 'manifests']
vag_dirs.each do |vd|
  d = vag_dir + 'puppet' + vd
  puts "Creating #{d.to_s}"
  d.mkpath
end

# Generate Vagrantfile
vf_template = Pathname(__FILE__).dirname + 'templates' + 'Vagrantfile.erb'
unless vf_template.file?
  puts "Vagrantfile template not found. Make sure it is in #{vf_template_to.s} to continue."
  exit 2
end

vf_out = vag_dir + 'Vagrantfile'
vf_out.write(ERB.new(vf_template.read, nil, '-').result())

# Read all directories in proj_dir
dirs = mod_dir.children.select {|f| f.directory? }.collect { |p| File.basename(p.to_s) }

# Generate site.pp
site_template = Pathname(__FILE__).dirname + 'templates'  + 'site.pp.erb'
unless site_template.file?
  puts "Site.pp template not found. Make sure it is in #{site_template.to_s} to continue."
  exit 2
end

site_out = vag_dir + 'puppet' + 'manifests' + 'site.pp'
site_out.write(ERB.new(site_template.read, nil, '-').result())

# Generate project metadata.json
dependencies = Array.new()
met_out = vag_dir + 'metadata.json'

# Collect metadata.json and save in array
Pathname.glob(mod_dir + '*' + 'metadata.json').map do |met|
  data = YAML.load_file(met)
  data['dependencies'].each do |dep|
    name = dep['name']
    ver = dep['version_requirement']
    if ! dependencies.include?(dep)
      dependencies.push(dep)
    end
  end
end

text = { "dependencies" => dependencies }

# Save collected text
met_out.write(JSON.pretty_generate(text))

# Generate Puppetfile
pf_template = Pathname(__FILE__).dirname + 'templates' + 'Puppetfile.erb'
unless pf_template.file?
  puts "Puppetfile template not found. Make sure it is in #{pf_template.to_s} to continue."
  exit 2
end

pf_out = vag_dir + 'Puppetfile'
pf_out.write(ERB.new(pf_template.read, nil, '-').result())

unless install_script.file?
  puts "Puppet install script template not found. Make sure it is in #{is_template.to_s} to continue."
  exit 2
end

is_out = vag_dir + 'install.sh'
is_out.write(ERB.new(install_script.read, nil, '-').result())
is_out.chmod(0755)

puts "Generated Vagrant environment in #{vag_dir.to_s}"
