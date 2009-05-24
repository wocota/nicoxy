class Youtube < VideoSitePlugin
  def uri_match_to?(uri)
    @uri = uri
    # 問題が複雑になるので，途中からの再生はキャッシュしない^^;
    if @uri !~ /begin/ and @uri =~ %r{http://www\.youtube\.com/get_video\?video_id=([\-0-9A-Za-z]+)}
      @video_id = $1
    end
  end
  def title
    open("http://www.youtube.com/watch?v=#{@video_id}").read  =~ /<h1[^>]*>([^<]*)/
    $1
  end
  def id
    @video_id
  end
  def prefix
    'yt'
  end
  def extension
    'flv'
  end
end

Youtube.new
