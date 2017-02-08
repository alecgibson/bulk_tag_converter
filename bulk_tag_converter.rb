#!/usr/bin/env ruby

require 'net/http'
require 'csv'

class TagError < StandardError
  attr_accessor :tag_number, :tag_name, :url

  def initialize(tag_number, tag_name, url)
    @tag_number = tag_number
    @tag_name = tag_name
    @url = url
  end

  def message
    "Invalid Tag#{@tag_number} ID for tag '#{@tag_name}'"
  end
end

class UrlError < StandardError
  def message
    "Invalid URL"
  end
end

SLUG_MATCHER = /gov.uk(?<slug>.+)/
UUID_MATCHER = /[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}/
BLANK_MATCHER = /^\s*$/
TAG_COLUMNS_START = 5 # Column number of the first tag entry in a row
NUMBER_OF_TAGS = 8 # Number of tag entries on a row
TAG_COLUMNS_END = TAG_COLUMNS_START + NUMBER_OF_TAGS - 1
TAG_ID_OFFSET = 9 # Number added to a tag column number to get the column number of its ID
LINK_TYPE = 'taxons'
URL_COLUMN = 1

$tag_errors = []
$url_errors = []

def validate_arguments
  throw "Expected 2 arguments. Please call: ./bulk_tag_converted <tsv_url> <output_file>" unless ARGV.length == 2
end

def get_spreadsheet
  uri = URI(ARGV[0])
  response = Net::HTTP.get_response(uri)
  throw "#{response.code}: #{response.message}" unless response.code == '200'
  puts "Successfully fetched spreadsheet"
  response.body
end

def to_rows(spreadsheet)
  Enumerator.new do |r|
    row_number = 1 # Start at 1 because of headers
    # quote_char hack is to get around speech marks being interpretted as
    # columns.
    # http://stackoverflow.com/questions/8073920/importing-csv-quoting-error-is-driving-me-nuts
    CSV.parse(spreadsheet, col_sep: "\t", headers: true, quote_char: "\x00") do |row|
      row_number += 1
      TAG_COLUMNS_START.upto(TAG_COLUMNS_END) do |tag_column|
        begin
          tag_id_column = tag_column + TAG_ID_OFFSET
          tag_number = tag_column - TAG_COLUMNS_START + 1

          next if row[tag_column].nil? || BLANK_MATCHER =~ row[tag_column]
          raise UrlError.new if row[URL_COLUMN].nil? || row[URL_COLUMN].empty?
          if row[tag_id_column].nil? || row[tag_id_column].empty? || UUID_MATCHER !~ row[tag_id_column]
            raise TagError.new(tag_number, row[tag_column], row[URL_COLUMN])
          end

          r << {
            content_base_path: row[URL_COLUMN].match(SLUG_MATCHER)[:slug],
            link_title: row[tag_column],
            link_content_id: row[tag_id_column],
            link_type: LINK_TYPE,
          }
        rescue TagError => e
          puts "ERROR on line #{row_number}: #{e.message}. Skipping line."
          $tag_errors << {
            row_number: row_number,
            url: e.url,
            tag_number: e.tag_number,
            tag_name: e.tag_name,
          }
        rescue UrlError => e
          $url_errors << {
            row_number: row_number,
          }
          puts "ERROR on line #{row_number}: #{e.message}. Skipping line."
        end
      end
    end
  end
end

def write_to_csv(rows)
  puts "Writing rows to '#{ARGV[1]}'"
  CSV.open(ARGV[1], "wb") do |csv|
    csv << ['content_base_path', 'link_title', 'link_content_id', 'link_type']
    rows.each do |row|
      csv << [row[:content_base_path], row[:link_title], row[:link_content_id], row[:link_type]]
    end
  end
  puts "FINISHED"
end

def write_errors_to_csv
  if $tag_errors.any?
    puts "Writing Tag errors to 'tag_errors.csv'"
    CSV.open('tag_errors.csv', "wb") do |csv|
      csv << ['row_number', 'url', 'tag_number', 'tag_name']
      $tag_errors.each do |row|
        csv << [row[:row_number], row[:url], row[:tag_number], row[:tag_name]]
      end
    end
  end

  if $url_errors.any?
    puts "Writing URL errors to 'url_errors.csv'"
    CSV.open('url_errors.csv', "wb") do |csv|
      csv << ['row_number']
      $url_errors.each do |row|
        csv << [row[:row_number]]
      end
    end
  end
end

validate_arguments
spreadsheet = get_spreadsheet
rows = to_rows spreadsheet
write_to_csv rows
write_errors_to_csv
