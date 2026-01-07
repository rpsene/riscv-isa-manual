#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'optparse'
require 'fileutils'

options = {
  update_reference: false
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [--update-reference] <reference.json> <generated.json>"
  opts.on('--update-reference', 'Update the reference file when differences are found') do
    options[:update_reference] = true
  end
  opts.on('-h', '--help', 'Show this help message') do
    puts opts
    exit 0
  end
end

paths = parser.parse(ARGV)
if paths.length != 2
  warn parser.to_s
  exit 2
end

ref_path, new_path = paths

unless File.exist?(ref_path)
  warn "Reference file not found: #{ref_path}"
  exit 2
end

unless File.exist?(new_path)
  warn "Generated file not found: #{new_path}"
  exit 2
end

def load_json(path)
  JSON.parse(File.read(path))
rescue JSON::ParserError => e
  warn "Failed to parse JSON in #{path}: #{e.message}"
  exit 2
end

ref_data = load_json(ref_path)
new_data = load_json(new_path)

ref_tags = (ref_data['tags'] || {})
new_tags = (new_data['tags'] || {})

added_tags = new_tags.keys - ref_tags.keys
removed_tags = ref_tags.keys - new_tags.keys
changed_tags = new_tags.keys.select do |key|
  ref_tags.key?(key) && ref_tags[key] != new_tags[key]
end


def collect_sections(node, out)
  return if node.nil?

  id = node['id'].to_s
  title = node['title'].to_s
  tags = (node['tags'] || []).map(&:to_s).sort
  out[id] = { title: title, tags: tags }

  (node['children'] || []).each do |child|
    collect_sections(child, out)
  end
end

ref_sections = {}
new_sections = {}
collect_sections(ref_data['sections'], ref_sections)
collect_sections(new_data['sections'], new_sections)

added_sections = new_sections.keys - ref_sections.keys
removed_sections = ref_sections.keys - new_sections.keys

section_changes = []
new_sections.each do |id, info|
  ref_info = ref_sections[id]
  next if ref_info.nil?

  added = info[:tags] - ref_info[:tags]
  removed = ref_info[:tags] - info[:tags]
  title_changed = info[:title] != ref_info[:title]

  next if added.empty? && removed.empty? && !title_changed

  section_changes << {
    id: id,
    title: info[:title],
    ref_title: ref_info[:title],
    added: added,
    removed: removed,
    title_changed: title_changed
  }
end

changes = [added_tags, removed_tags, changed_tags, added_sections, removed_sections, section_changes]
if changes.all?(&:empty?)
  puts 'No normative tag changes detected.'
  exit 0
end

puts 'Normative tag changes detected:'

unless added_tags.empty?
  puts "- Added tags (#{added_tags.size}): #{added_tags.sort.join(', ')}"
end

unless removed_tags.empty?
  puts "- Removed tags (#{removed_tags.size}): #{removed_tags.sort.join(', ')}"
end

unless changed_tags.empty?
  puts "- Updated tag text (#{changed_tags.size}): #{changed_tags.sort.join(', ')}"
end

unless added_sections.empty?
  puts "- Added sections (#{added_sections.size}): #{added_sections.sort.join(', ')}"
end

unless removed_sections.empty?
  puts "- Removed sections (#{removed_sections.size}): #{removed_sections.sort.join(', ')}"
end

unless section_changes.empty?
  puts "- Section tag changes (#{section_changes.size}):"
  section_changes.sort_by { |item| item[:id] }.each do |item|
    section_id = item[:id].empty? ? '<root>' : item[:id]
    title_info = item[:title].empty? ? '' : " (#{item[:title]})"
    puts "  - #{section_id}#{title_info}"
    unless item[:added].empty?
      puts "    - added: #{item[:added].join(', ')}"
    end
    unless item[:removed].empty?
      puts "    - removed: #{item[:removed].join(', ')}"
    end
    if item[:title_changed]
      puts "    - title: '#{item[:ref_title]}' -> '#{item[:title]}'"
    end
  end
end

if options[:update_reference]
  FileUtils.cp(new_path, ref_path)
  puts "Updated reference file: #{ref_path}"
end

exit 1
