# require 'rexml/document'
# require 'open-uri'

# class Nicovideo
#   def initialize(video_id)
#     xml = open("http://ext.nicovideo.jp/api/getthumbinfo/#{video_id}").read
#     @doc = REXML::Document.new(xml)
#   end
#   def title
#     elem = @doc.elements['/nicovideo_thumb_response/thumb/title']
#     # sanitize title for windows because title is used filename
#     elem ? elem.text.gsub(/[\\\/\,\;\:\*\?\"\<\>\|]/,'_') : nil
#   end
#   def deleted?
#     elem = @doc.elements['/nicovideo_thumb_response/error/code']
#     return true if elem and elem.text == 'DELETED'
#     false
#   end
# end
