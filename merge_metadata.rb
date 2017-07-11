#!/opt/puppetlabs/puppet/bin/ruby
require 'yaml'
require 'json'
require 'optparse'

# Get arguments from CLI
options = {}
o = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0}"
  opts.on('-p [/path/to/project/dir]', '--proj_dir [/path/to/project/dir]', "Required: Path to project containing modules under development. Ex: ~/workspace/project1") do |o|
    options[:proj_dir] = o
  end
  opts.on('-o [/path/to/output/metadata.json]', '--out_file [/path/to/output/metadata.json]', "Optional: Where to write the output file. Defaults proj_dir/metadata.json") do |o|
    options[:out_file] = o
  end
  opts.on('-f', '--force', "Optional: If out_file exists, overwrite it.") do |o|
    options[:force] = true
  end
  opts.on('-h', '--help', 'Display this help') do
    puts opts
    exit 0 
  end
end

o.parse!

# Create vars to use
proj_dir = options[:proj_dir]
out_file = options[:out_file]
dependencies = Array.new()
out_file = "#{proj_dir}/metadata.json" unless out_file

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

unless File.exists?(out_file) and options[:force]
  puts "ERROR: File #{out_file} already exists. Delete it or use force option."
  puts o
  exit 2
end

# Collect metadata.json and save in array
Dir.glob("#{proj_dir}/*/metadata.json").map do |met|
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
metadata = File.open(out_file, "w") do |fh|
  fh.puts JSON.pretty_generate(text)
end

