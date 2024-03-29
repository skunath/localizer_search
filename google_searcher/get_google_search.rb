#!/usr/bin/env ruby
# encoding: utf-8
require 'nokogiri'
require 'cgi'
require 'yaml'
require 'uri'
require 'optparse'

$vimscript_file = File.expand_path(File.join(File.dirname(__FILE__), '..', 'plugin', 'goog.vim'))
orig_query = "query: #{ARGV.join(' ')}\n\n"
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: goog [options] [query]"
  opts.on("-h", "--help", "Show this message") { 
    require 'goog'
    puts <<END
#{opts}
DATE RANGE options for -d option:
    h   last hour
    d   last day (24 hours)
    w   last week
    m   last month
    y   last year

VIM KEY MAPPINGS
    <leader>o       open URL on or after cursor in default external web browser
    <leader>O       open URL on or after cursor in split Vim window using elinks, links, or lynx

VIM PLUGIN COMMANDS

    :Goog [query]

      where query is any of the flags and arguments you can pass to the command
      line version, except for -v.

goog will run the Google search and print matches with syntax coloring in a
split Vim buffer.

In the GoogSearchResults buffer:

    CTRL-j          jumps to the next URL
    CTRL-k          jumps to the previous URL
    <leader>o       open URL on or after cursor in default external web browser
    <leader>O       open URL on or after cursor in split Vim window using elinks, links, or lynx

goog #{Goog::VERSION}
http://github.com/danchoi/goog
Author: Daniel Choi <dhchoi@gmail.com>
END
    exit 
  }
  opts.on("-d", '--date-range [DATE RANGE]', 'Show results for date range. See below for options.') {|dr| options[:date_range] = dr }
  opts.on("-n", '--num-pages [NUM PAGES]', 'Show NUM PAGES pages of results') {|pages| options[:pages] = pages.to_i }
  opts.on("-c", '--color', 'Force color output') {options[:color] = true}
  opts.on("-v", '--vim', 'Open results in Vim and bind <leader>o to open URL on or after cursor') {
    require 'tempfile'
    options[:vim] = true
    $tempfile = Tempfile.new('goog')
    $stdout = $tempfile
  }
  opts.on("-i", '--install-plugin', 'Install Goog as a Vim plugin') {
    puts "Installing goog.vim into your ~/.vim/plugin directory."
    `cp #{$vimscript_file} #{ENV['HOME']}/.vim/plugin/`
    puts "Done. Type goog -h for Vim commands."
    exit
  }
  opts.on('--version', 'Show version') {|dr| 
    require 'goog'
    puts <<END
goog #{Goog::VERSION}
http://github.com/danchoi/goog
Author: Daniel Choi <dhchoi@gmail.com>
END
    exit
  }
end.parse!
query = ARGV.join(' ')
unless query
  abort "Please provide a search query"
end

$stdout.puts orig_query
if RUBY_VERSION !~ /^1.9/
  abort "Requires Ruby 1.9"
end

query = "/search?q=#{CGI.escape query}"
if options[:date_range]
  query += "&as_qdr=#{options[:date_range]}"
end
(1..(options[:pages] || 1)).each do |page| 
  if query.nil?
    exit
  end
  curl = "curl -s -A Mozilla 'http://www.google.com#{query}'"
  resp = %x{#{curl}}
  doc = Nokogiri::HTML resp, nil, 'iso-8859-1'
  
  puts doc
  puts "-^-" * 20
  
  doc.search('ol li.g').each_with_index {|li, index|
    next unless li.at('h3 a')
    
    #
    # actual data grab portion
    #
    
    href = li.at('h3 a')['href']
    link = ((h = href[/^\/url\?q=([^&]+)/, 1]) && URI.unescape(h)) || href
    if link !~ /^https?:/
      link = "http://google.com#{link}"
    end
    title = li.at('h3 a').inner_text
    description = li.at('div.s')
    excerpt = if description
                description.search('span').remove 
                excerpt = begin 
                  s = description.inner_text.strip
                  s.gsub(/\s{2,}/, ' ')
                rescue
                  puts "ERROR"
                  puts description
                  puts $!
                end
              end
    number = (page - 1) * 10 + (index + 1)
    
    #
    # get review and location information... 
    #
    
    if li.at('table')
      address_stuff = nil
      review_counts = nil
      stars = nil
      address_stuff = li.at('table').at('td[2]').at('span').inner_text
      
      review_counts = li.at('table').at('td[3]').at('a').inner_text if li.at('table').at('td[3]')
      
      stars = li.at("div.star").at("div") if li.at("div.star")
      if !stars.nil?
        stars = stars["style"]
        stars = stars.gsub("width:", "").gsub("px","")
        stars = stars.to_i / 10
      end

      

    end
    
    res = if !options[:vim] && (STDOUT.tty? || options[:color])
      ["#{number}. \e[36m#{title}\e[0m", excerpt, "\e[35m#{link }\e[0m"]
    else
      ["#{number}. #{title}", excerpt, link]
    end
    $stdout.puts res.compact
    $stdout.puts
    puts address_stuff if !address_stuff.nil?
    puts review_counts if !review_counts.nil?
    puts "Stars: " + stars.to_s if !stars.nil?
  }

  # find next page link
  # <a href="/search?q=why+the+lucky+stiff&amp;hl=en&amp;ie=UTF-8&amp;prmd=ivns&amp;ei=K6akT9bRBeaM6QHjifmwBA&amp;start=10&amp;sa=N" style="text-align:left"><span style="display:block;margin-left:53px">Next</span></a>

  next_page_href = (nextspan = doc.at("//span[contains(child::text(),'Next')]")) && nextspan.parent[:href]
  query = next_page_href
end

if options[:vim]
  $stdout.close
  exec "vim -S #$vimscript_file -c 'call g:Goog_set_up_search_results_buffer()' #{$tempfile.path}"
end
