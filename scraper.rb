require 'open-uri'
require 'nokogiri'
require 'sqlite3'
require 'time'

URL = "https://www.dlsite.com/maniax/new/=/work_type_category/illust"
DB_FILE = "dlsite.db"
CATEGORY = "illust"

def column_exists?(db, table, col)
  cols = db.execute("PRAGMA table_info(#{table})")
  cols.any? { |row| row[1] == col }
end

def normalize_title(raw)
  t = raw.dup

  # 改行/タブ/連続空白を1スペースへ
  t = t.gsub(/\s+/, ' ').strip

  # セール終了系ノイズ除去（例：2026年03月05日 23時59分 割引終了）
  t = t.gsub(/\d{4}年\d{2}月\d{2}日\s*\d{2}時\d{2}分\s*割引終了/, '')

  # 「専売」ノイズ除去（単独でも混入でも消す）
  t = t.gsub(/\b専売\b/, '')

  # 仕上げ：空白整形
  t = t.gsub(/\s+/, ' ').strip

  t
end

db = SQLite3::Database.new(DB_FILE)

# 既存互換：まずテーブルが無ければ作る（raw_title/clean_title/category 付き）
db.execute <<-SQL
CREATE TABLE IF NOT EXISTS works (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fetched_at TEXT,
  product_id TEXT UNIQUE,
  title TEXT,
  url TEXT,
  raw_title TEXT,
  clean_title TEXT,
  category TEXT
);
SQL

# 既存DBへの追記：カラムが無ければ追加（後方互換）
unless column_exists?(db, "works", "raw_title")
  db.execute("ALTER TABLE works ADD COLUMN raw_title TEXT;")
end
unless column_exists?(db, "works", "clean_title")
  db.execute("ALTER TABLE works ADD COLUMN clean_title TEXT;")
end
unless column_exists?(db, "works", "category")
  db.execute("ALTER TABLE works ADD COLUMN category TEXT;")
end

html = URI.open(URL).read
doc = Nokogiri::HTML(html)

items = doc.css(".n_worklist_item")
items = items.first(100)

inserted = 0

items.each do |item|
  raw_title = item.css(".work_name a").text.to_s
  link = item.css(".work_name a").attr("href")&.value
  next unless link

  product_id = link.match(/RJ\d+/)&.to_s
  next unless product_id

  clean_title = normalize_title(raw_title)

  begin
    db.execute(
      inserted += 1
      "INSERT INTO works (fetched_at, product_id, title, url, raw_title, clean_title, category)
       VALUES (?, ?, ?, ?, ?, ?, ?)",
      [Time.now.iso8601, product_id, raw_title.strip, link, raw_title, clean_title, CATEGORY]
    )
  rescue SQLite3::ConstraintException
    # 既に登録済みならスキップ（必要ならUPDATEに拡張可）
  end
end

puts "items_count=#{items.size}"
puts "DB updated successfully: inserted=#{inserted}"
