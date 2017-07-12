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
# Win has no gsub. Thanks win.
proj_dir = options[:proj_dir].split('\\').join('/')
box = options[:box]
box_ver = options[:box_ver]
box_url = options[:box_url]
disk = options[:disk].split('\\').join('/')
node_name = options[:node_name]
master = options[:server]

mod_dir = "#{proj_dir}/modules"
vag_dir = "#{proj_dir}/vagrant"
puppet = '4'

# Validate vars
unless proj_dir
  puts "ERROR: proj_dir is a required argument"
  puts o
  exit 2
end

unless File.directory?(proj_dir)
  puts "ERROR: #{proj_dir} does not exist"
  puts o
  exit 2
end

unless File.directory?(mod_dir)
  puts "ERROR: #{mod_dir} does not exist"
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
  puppet_bin = '/opt/puppet/bin'
elsif puppet =~ /^4/ || puppet =~ /^2/
  puppet_bin = '/opt/puppetlabs/puppet/bin'
end

# These values come from the Puppet provisioner in Vagrant
code_dir = '/vagrant/puppet'
global_mod_dir = '/etc/puppet/modules'

# Generate Vagrant Structure
vag_dirs = ['puppet','puppet/environments', 'puppet/modules', 'puppet/manifests']
FileUtils::mkdir_p vag_dir unless File.directory?(vag_dir)
vag_dirs.each do |d|
  puts "creating #{vag_dir}/#{d}"
  FileUtils::mkdir_p "#{vag_dir}/#{d}" unless File.directory?("#{vag_dir}/#{d}")
end

# Generate Vagrantfile
vf_template = "#{File.expand_path(File.dirname(__FILE__))}/templates/Vagrantfile.erb"
unless File.exists?(vf_template)
  puts "Vagrantfile template not found. Make sure it is in #{vf_template} to continue."
  exit 2
end

vf = File.read(vf_template)
vf_out = "#{vag_dir}/Vagrantfile"

file_out = File.open(vf_out, "w") do |fh|
  fh.puts ERB.new(vf, nil, '-').result()
end

# Read all directories in proj_dir
dirs = Pathname.new(mod_dir).children.select {|f| f.directory? }.collect { |p| File.basename(p.to_s) }

# Generate site.pp
site_template = "#{File.expand_path(File.dirname(__FILE__))}/templates/site.pp.erb"
unless File.exists?(site_template)
  puts "Site.pp template not found. Make sure it is in #{site_template} to continue."
  exit 2
end

site = File.read(site_template)
site_out = "#{vag_dir}/puppet/manifests/site.pp"

file_out = File.open(site_out, "w") do |fh|
  fh.puts ERB.new(site, nil, '-').result()
end

# Generate project metadata.json
dependencies = Array.new()
met_out = "#{vag_dir}/metadata.json"

# Collect metadata.json and save in array
Dir.glob("#{mod_dir}/*/metadata.json").map do |met|
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
metadata = File.open(met_out, "w") do |fh|
  fh.puts JSON.pretty_generate(text)
end

# Generate Puppetfile
pf_template = "#{File.expand_path(File.dirname(__FILE__))}/templates/Puppetfile.erb"
unless File.exists?(pf_template)
  puts "Puppetfile template not found. Make sure it is in #{pf_template} to continue."
  exit 2
end

pf = File.read(pf_template)
pf_out = "#{vag_dir}/Puppetfile"

file_out = File.open(pf_out, "w") do |fh|
  fh.puts ERB.new(pf, nil, '-').result()
end

puts "Generated Vagrant environment in #{vag_dir}"
