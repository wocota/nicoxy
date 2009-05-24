require 'rexml/document'
require 'open-uri'

class Nicovideo < VideoSitePlugin
  def uri_match_to?(uri)
    @uri = uri
    if @uri =~ /smile-.*?\.nicovideo\.jp\/smile\?([a-z])=(\d*)\.\d*$/
      @smile, @video_id = $1, $2
    end
  end
  def title
    @doc ||= REXML::Document.new(open("http://ext.nicovideo.jp/api/getthumbinfo/#{prefix}#{@video_id}").read)
    elem = @doc.elements['/nicovideo_thumb_response/thumb/title']
    elem ? elem.text.gsub(/[\\\/\,\;\:\*\?\"\<\>\|]/,'_') : 'no_title'
  end
  def id
    @video_id
  end
  def prefix
    @smile == 's' ? 'nm' : 'sm'
  end
  def extension
    case @smile
    when 'm' then 'mp4'
    when 'v' then 'flv'
    when 's' then 'swf'
    end
  end  
end

Nicovideo.new
