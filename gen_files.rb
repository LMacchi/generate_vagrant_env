#!/opt/puppetlabs/puppet/bin/ruby
# Script that generates:
# - Vagrantfile
# - site.pp

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
  opts.on('-d [/path/to/disk]', '--disk [vagrantboxurl]', "Optional: Secondary disk name. Ex: rhelSecondDisk.vdi") do |o|
    options[:disk] = o
  end
  opts.on('-n [node_name]', '--node_name [node_name]', "Optional: Name for the node to be created. Ex: test.puppetlabs.vm") do |o|
    options[:node_name] = o
  end
  opts.on('-s [puppet_server_host]', '--server [puppet_version]', "Optional: URL/IP of the Puppet Master server") do |o|
    options[:server] = o
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

# Assign internal vars
if puppet =~ /^3/
  puppet_bin = Pathname.new('/opt/puppet/bin')
elsif puppet =~ /^4/ || puppet =~ /^2/
  puppet_bin = Pathname.new('/opt/puppetlabs/puppet/bin')
end

# These values come from the Puppet provisioner in Vagrant
code_dir = Pathname.new('/vagrant/puppet')
global_mod_dir = Pathname.new('/etc/puppet/modules')

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

vf = vf_template.read
vf_out = vag_dir + 'Vagrantfile'
vf_out.write(ERB.new(vf, nil, '-').result())

# Read all directories in proj_dir
dirs = mod_dir.children.select {|f| f.directory? }.collect { |p| File.basename(p.to_s) }

# Generate site.pp
site_template = Pathname(__FILE__).dirname + 'templates'  + 'site.pp.erb'
unless site_template.file?
  puts "Site.pp template not found. Make sure it is in #{site_template.to_s} to continue."
  exit 2
end

site = site_template.read
site_out = vag_dir + 'puppet' + 'manifests' + 'site.pp'
site_out.write(ERB.new(site, nil, '-').result())

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

pf = pf_template.read
pf_out = vag_dir + 'Puppetfile'
pf_out.write(ERB.new(pf, nil, '-').result())

puts "Generated Vagrant environment in #{vag_dir.to_s}"
