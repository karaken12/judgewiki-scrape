#!/usr/bin/env ruby

require 'json'
require 'open-uri'

MTR_PAGE_NAME = "Magic Tournament Rules"

def get_json(page_name)
  url = "http://wiki.magicjudges.org/en/api.php?action=query&titles=#{page_name}&prop=revisions&rvprop=content&format=json"
  return JSON.parse(open(url).read)
end

def get_text(result)
  return result['query']['pages'].values[0]['revisions'][0]['*']
end

def get_includes(text)
  regex = /\{\{:(.+?)\}\}/
  return text.scan(regex).map{|x| x[0]}
end

#sections.select{|x| x.start_with?(":MTR:")}.each do |section|
#  puts section
#  puts get_json(section)
#  puts "==="
#end

def go
  unprocessed = [MTR_PAGE_NAME]
  data = {}

  while(unprocessed.length > 0) do
    # There's a limit of 50 pages per query, so abide by that
    unprocessed = unprocessed[0,50]
puts "unprocessed: #{unprocessed.join('|')}"
    new_data = get_json(unprocessed.join('|'))
puts new_data.keys
puts new_data['query'].keys
    # assert!
    if new_data['query']['normalized']
      puts "Normalized! #{new_data['query']['normalized']}"
      exit
    end

    new_data['query']['pages'].values.each do |page|
      data[page['title']] = page
    end

    # This is a bit inefficient, as we keep getting the includes for
    # previously processed pages, but it doesn't hit the network
    # so it doesn't slow us down much.
    unprocessed = get_all_includes(data) - data.keys
  end

  puts data.keys
  puts "==="

  # Clean out 'noinclude' sections.
  data.values.each do |page|
    page['revisions'][0]['*'].gsub!(/<noinclude>.+?<\/noinclude>/m,'')
    puts page['revisions'][0]['*']
    puts "---"
    IO.popen('pandoc -f mediawiki', 'r+') {|f|
      f.puts(page['revisions'][0]['*'])
      f.close_write
      puts f.read
    }
    puts "==="
  end
end

def get_all_includes(data)
  data.values.map{|page| get_includes(page['revisions'][0]['*'])}.flatten
end

go
