require 'rexml/document'
require 'open-uri'

class Nicovideo
  def initialize(video_id)
    xml = open("http://ext.nicovideo.jp/api/getthumbinfo/sm#{video_id}").read
    @doc = REXML::Document.new(xml)
  end
  def title
    return '' if deleted?
    @doc.elements['/nicovideo_thumb_response/thumb/title'].text
  end
  def deleted?
    return @doc.elements['/nicovideo_thumb_response/error/code'] ? true : false
  end
end
