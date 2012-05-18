require 'rubygems'
require 'open-uri'
require 'nokogiri'
require 'active_record'

# need to have a seed for it to start from

ActiveRecord::Base.establish_connection(
  :adapter => "mysql2",
  :host => "localhost",
  :username => "root",
  :database => "search_local")

class Yelp < ActiveRecord::Base
  has_many :yelp_reviews
end

class YelpReview < ActiveRecord::Base
  belongs_to :yelp
end

def process_site(url)
      
  doc = Nokogiri::HTML(open(url))
  page_links = []
    doc.css("a").each do |link|
      if link.attributes.include?("id")
        if link.attributes["id"].text.include?("bizTitleLink")
          page_links << link.attributes["href"]
        end
      end
    end
    
    next_location = doc.at_css('#pager_page_next').attributes["href"]
    
    puts page_links
    puts "%" * 10
    puts next_location
    
    return next_location
  
end  

def process_info_page(url)
  doc = Nokogiri::HTML(open(url))

  category = doc.at_css('#bookableMain').to_html
  main_info = doc.at_css('#biz-vcard').to_html
  
  reviews = []
  doc.css('div.media-block-no-margin').each do |review|
    reviews << review.to_html
  end
  
end


base_url = "http://www.yelp.com"
ext_url = "/search?find_desc=&find_loc=washington%2C+dc&ns=1&ls=895134b7efd7a9e1"

while !ext_url.nil?
  prev_url = ext_url
  ext_url = process_site(base_url + ext_url)
  if ext_url == "failure"
    ext_url = prev_url
  end
end  


