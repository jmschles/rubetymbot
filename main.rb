require 'sinatra'
require 'rest-client'
require 'nokogiri'

set :port, 4222

ETYMONLINE_BASE_URL = 'http://www.etymonline.com/word'
VALID_TOKENS = [
  ENV['SM_SLACK_ETYM_TOKEN'],
  ENV['TS_SLACK_ETYM_TOKEN']
]

get '/' do
  "Etymbot is running!"
end

get '/etym' do
  content_type :json

  token = params['token']
  text = params['text']&.downcase&.gsub(/\s+/, '+')

  if authenticate!(token)
    generate_response(text)
  else
    halt 401, 'YOU SHALL NOT PASS'
  end
end

get '/*' do
  "WAT, ain't no #{params['splat'].first} here"
end

def authenticate!(token)
  !token.nil? && VALID_TOKENS.include?(token)
end

def generate_response(text)
  raw_response = make_request_to_etymonline(text)
  response_text = parse_response(raw_response)
  format_response(response_text)
end

def make_request_to_etymonline(text)
  begin
    RestClient.get("#{ETYMONLINE_BASE_URL}/#{text}")
  rescue
    "NOPE"
  end
end

def parse_response(raw_response)
  if raw_response == "NOPE"
    not_found_response
  else
    parsed_response = Nokogiri::HTML(raw_response)
    successful_response(parsed_response)
  end
end

def successful_response(parsed_response)
  title_markup = parsed_response.css('.word__name--TTbAA').first
  title_text = title_markup.text

  etymology_markup = parsed_response.css('.word__defination--2q7ZH').first # this hurts my soul
  etymology_markup.css('blockquote').each { |bq| format_blockquote(bq) }
  etymology_text = etymology_markup.text

  "*#{title_text}*\n\n#{etymology_text}"
end

def not_found_response
  "No matching terms found :failboat:"
end

def format_response(raw_response_text)
  {text: raw_response_text, response_type: "in_channel"}.to_json
end

def format_blockquote(blockquote_node)
  target_node = blockquote_node.children.detect { |child| child.text != "\n" }
  return if target_node.nil?
  if target_node.is_a?(Nokogiri::XML::Text)
    target_node.content = "\n> #{target_node.content}\n"
  else
    target_node&.prepend_child('> ')
  end
end
