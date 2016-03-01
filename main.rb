# URLにアクセスするためのライブラリを読み込む
require 'open-uri'
# HTMLをパースするためのライブラリを読み込む
require 'nokogiri'
# 日付ライブラリの読み込み
require "date"
# Parseライブラリの読み込み
require 'parse-ruby-client'

require "uri"

# http://qiita.com/yoshioota/items/4a58d977b4f89078d7d4
#サムネイルURLにスペースが入っているので回避するためのGem
require 'addressable/uri'

Parse.init :application_id => ENV['PARSE_APP_ID'],
           :api_key        => ENV['PARSE_API_KEY']

BaseUrl = "http://www.keyakizaka46.com/mob/news/diarKijiShw.php?cd=report"
ReportClassName = "KeyakizakaReport"

def get_all_report
  fetch_report { |data|
    save_data(data) { |result|
      push_notification result, data
    } if is_new? data
  }
end

def fetch_report
  page = Nokogiri::HTML(open(BaseUrl))
  page.css('.box-newReport').css('.slider').css('a').each do |a|
    data = {}
    data[:url] = url_normalize a[:href]
    data[:published] = normalize a.css('.box-txt > time').text
    data[:published] = Parse::Date.new(data[:published])
    data[:title] = normalize a.css('.box-txt > .ttl').text
    data[:thumbnail_url] = thumbnail_url_normalize a.css('.box-img > img')[0][:src]

    data[:image_url_list] = Array.new()
    article = Nokogiri::HTML(open(data[:url]))
    article.css('.box-content').css('img').each do |img|
      image_url = thumbnail_url_normalize img[:src]
      data[:image_url_list].push image_url
    end
    yield(data) if block_given?
  end
end

def save_data data
  entry = Parse::Object.new(ReportClassName)
  data.each { |key, val|
    entry[key] = val
  }
  result = entry.save
  yield(result) if block_given?
end

def push_notification result, data
  pushdata = { :action => "jp.shts.android.keyakifeed.REPORT_UPDATED",
           :_entryObjectId => result['objectId'],
           :_title => data[:title],
           :_url => data[:url],
           :_thumbnail_url => data[:thumbnail_url],
          }
  push = Parse::Push.new(pushdata)
  push.where = { :deviceType => "android" }
  puts pushdata
  puts push.save
end

def is_new? data
  Parse::Query.new(ReportClassName).tap do |q|
    q.eq("url", data[:url])
  end.get.first == nil
end

def normalize str
  str.gsub(/(\r\n|\r|\n|\f)/,"").strip
end

def thumbnail_url_normalize url
  uri = Addressable::URI.parse(url)
  if uri.scheme == nil || uri.host == nil then
    "http://www.keyakizaka46.com" + url
  else
    url
  end
end

def url_normalize url
  # before
  # http://www.keyakizaka46.com/mob/news/diarKijiShw.php?site=k46o&ima=1900&id=1820&cd=report
  # after
  # http://www.keyakizaka46.com/mob/news/diarKijiShw.php?id=1820&cd=report
  uri = URI.parse(url)
  q_array = URI::decode_www_form(uri.query)
  q_hash = Hash[q_array]
  "http://www.keyakizaka46.com/mob/news/diarKijiShw.php?id=#{q_hash['id']}&cd=report"
end

get_all_report
