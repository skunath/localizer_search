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
  
  begin  
    poi_name = doc.at_css('h1.poiName')
  
    poi_info_container = doc.at_css('#poiInfoContainer')
    lp_review = doc.at_css('div.lpReview')
    
    bookable_content = doc.at_css('#bookableMain')
    bookable_info = doc.at_css('#bookableSidebar')
    
    poi_good_for = doc.at_css('div.poiGoodFor')
    
    poi_bad_for = doc.at_css('div.poiBadFor')
    
    poi_bread_crumb = doc.at_css('#sub-breadcrumb')
    
    begin
      latitude = doc.content.match(/latitude..[0-9\.\-]+/)[0].split(":")[1]
      longitude = doc.content.match(/longitude..[0-9\.\-]+/)[0].split(":")[1]
    rescue
      latitude = "0.0"
      longitude = "0.0"
    end  
    next_location = doc.at_css('span.nextPoi').at_css("a").attributes["href"]
    
    yelp = Yelp.new
    yelp.name = poi_name.to_html
    yelp.latitude = latitude
    yelp.longitude = longitude
    yelp.breadcrumb = poi_bread_crumb.to_html
   
    yelp.url = url
    
    if !poi_info_container.nil?
      yelp.information = poi_info_container.to_html
      yelp.info_container = poi_info_container.to_html
     yelp.review = lp_review.to_html
    else
      yelp.information = bookable_content.to_html
      yelp.info_container = bookable_info.to_html
    yelp.review = bookable_content.to_html
    end
    
    
    yelp.good_for = poi_good_for.to_html
    yelp.bad_for = poi_bad_for.to_html
    yelp.save
      
    # get reviews
    #reviews = []
    
    doc.css('li.hreview').each do |review|
      #reviews << review
      new_review = yelp.yelp_reviews.new
      new_review.review = review.to_html
      new_review.save
      
    end
    
    
    
    return next_location
  rescue
    puts "!" * 50
    puts doc
    puts "*" * 50
    return "failure"
  end
end  

base_url = "http://www.lonelyplanet.com"
#ext_url = "/usa/washington-dc/restaurants/american/afterwords-cafe-kramerbooks"
ext_url = "/usa/washington-dc/sights/outdoors/east-potomac-park"

while !ext_url.nil?
  prev_url = ext_url
  ext_url = process_site(base_url + ext_url)
  if ext_url == "failure"
    ext_url = prev_url
  end
end  


