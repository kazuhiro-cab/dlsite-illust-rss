require 'open-uri'
require 'nokogiri'
require 'sqlite3'
require 'time'

BASE_URL = "https://www.dlsite.com/maniax/new/=/work_type_category/illust"
DB_FILE = "dlsite.db"
CATEGORY = "illust"

MAX_PAGES = 5   # ← 最大5ページまで取得（調整可）

def normalize_title(raw)
  t = raw.to_s.gsub(/\s+/, ' ').strip
  t = t.gsub(/\d{4}年\d{2}月\d{2}日\s*\d{2}時\d{2}分\s*割引終了/, '')
  t = t.gsub(/専売/, '')
  t.gsub(/\s+/, ' ').strip
end

db = SQLite3::Database.new(DB_FILE)

db.execute <<-SQL
CREATE TABLE IF NOT EXISTS works (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fetched_at TEXT,
  product_id TEXT UNIQUE,
  title TEXT,
  url TEXT,
  clean_title TEXT,
  category TEXT
);
SQL

inserted = 0
total_items = 0

(1..MAX_PAGES).each do |page|
  url = "#{BASE_URL}?p=#{page}"
  html = URI.open(url).read
  doc = Nokogiri::HTML(html)

  items = doc.css(".n_worklist_item")
  break if items.empty?

  items.each do |item|
    total_items += 1

    raw_title = item.css(".work_name a").text.to_s
    link = item.css(".work_name a").attr("href")&.value
    next unless link

    product_id = link.match(/RJ\d+/)&.to_s
    next unless product_id

    clean_title = normalize_title(raw_title)

    begin
      db.execute(
        "INSERT INTO works (fetched_at, product_id, title, url, clean_title, category)
         VALUES (?, ?, ?, ?, ?, ?)",
        [Time.now.iso8601, product_id, raw_title.strip, link, clean_title, CATEGORY]
      )
      inserted += 1
    rescue SQLite3::ConstraintException
    end
  end
end

puts "total_items=#{total_items}"
puts "inserted=#{inserted}"
