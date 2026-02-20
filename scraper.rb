require 'open-uri'
require 'nokogiri'
require 'sqlite3'
require 'time'

URL = "https://www.dlsite.com/maniax/new/=/work_type_category/illust"
DB_FILE = "dlsite.db"

db = SQLite3::Database.new(DB_FILE)

db.execute <<-SQL
CREATE TABLE IF NOT EXISTS works (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fetched_at TEXT,
  product_id TEXT UNIQUE,
  title TEXT,
  url TEXT
);
SQL

html = URI.open(URL).read
doc = Nokogiri::HTML(html)

items = doc.css(".n_worklist_item")

items.each do |item|
  title = item.css(".work_name").text.strip
  link = item.css(".work_name a").attr("href")&.value
  next unless link

  product_id = link.match(/RJ\d+/)&.to_s
  next unless product_id

  begin
    db.execute(
      "INSERT INTO works (fetched_at, product_id, title, url) VALUES (?, ?, ?, ?)",
      [Time.now.iso8601, product_id, title, link]
    )
  rescue SQLite3::ConstraintException
  end
end

puts "DB updated"
