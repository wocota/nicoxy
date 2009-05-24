MOFOSEX_TITLE_HASH = {}

class Mofosex < VideoSitePlugin
  def uri_match_to?(uri)
    @uri = uri
    if @uri =~ %r{http://www\.mofosex\.com/videos/\d+/.*?\.html}
      html = open(@uri).read.to_s
      html =~ /flashvars\.id = "(\w+)";.*?flashvars\.url="\d+\/(.*?)";/m
      MOFOSEX_TITLE_HASH[$1] =  $2
      return false
    end
    if @uri =~ %r{/cds/media/flvs/(\w+?)\.flv\?dopvhost=media\.mofosex\.com}
      @video_id = $1
    end
  end
  def title
    MOFOSEX_TITLE_HASH[@video_id]
  end
  def id
    @video_id
  end
  def prefix
    'ms'
  end
  def extension
    'flv'
  end
end

Mofosex.new
