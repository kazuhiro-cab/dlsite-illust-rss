require 'open-uri'
require 'nokogiri'

URL = "https://www.dlsite.com/maniax/new/=/work_type_category/illust"

html = URI.open(URL).read
doc = Nokogiri::HTML(html)

items = doc.css(".n_worklist_item")

rss = <<~XML
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0">
<channel>
<title>DLsite Illust New</title>
<link>#{URL}</link>
<description>DLsite CG New Works</description>
XML

items.first(20).each do |item|
  title = item.css(".work_name").text.strip
  link = item.css(".work_name a").attr("href")&.value
  next unless link

  rss += <<~ITEM
  <item>
    <title>#{title}</title>
    <link>#{link}</link>
  </item>
  ITEM
end

rss += "</channel></rss>"

File.write("rss.xml", rss)
